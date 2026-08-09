import base64
import os
import secrets
import urllib.parse
import uuid
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path

import jwt
import requests as _http
from flask import Flask, has_request_context, jsonify, redirect, request, send_file
from flask_cors import CORS
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename
from werkzeug.middleware.proxy_fix import ProxyFix
from email_service import AudelaEmailService, sighting_email

db = SQLAlchemy()
migrate = Migrate()

def now(): return datetime.now(timezone.utc)

def parse_origins(value):
  if not value:
    return ['*']
  origins = [item.strip() for item in value.split(',') if item.strip()]
  return origins or ['*']

def normalize_database_url(value, root):
  raw = (value or '').strip()
  if not raw:
    return f"sqlite:///{root / 'audela.db'}"
  if raw.startswith('postgres://'):
    raw = raw.replace('postgres://', 'postgresql://', 1)
  # requirements.txt installs psycopg (v3), while SQLAlchemy's bare
  # postgresql:// URL selects the psycopg2 dialect by default.
  if raw.startswith('postgresql://'):
    return raw.replace('postgresql://', 'postgresql+psycopg://', 1)
  return raw

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(180), unique=True, nullable=False)
    name = db.Column(db.String(80), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    consent_version = db.Column(db.String(20), nullable=False, default='2026-08')
    created_at = db.Column(db.DateTime(timezone=True), default=now)

class Report(db.Model):
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    name = db.Column(db.String(80), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='Perdu')
    place = db.Column(db.String(180), nullable=False)
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    event_at = db.Column(db.DateTime(timezone=True), default=now)
    color = db.Column(db.String(80), default='Non précisé')
    sex = db.Column(db.String(20), default='Inconnu')
    description = db.Column(db.Text, default='')
    image_url = db.Column(db.String(500), default='')
    image_data = db.Column(db.LargeBinary)
    image_mime = db.Column(db.String(80), default='')
    public_contact = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime(timezone=True), default=now)
    expires_at = db.Column(db.DateTime(timezone=True), default=lambda: now() + timedelta(days=365))

class Sighting(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    report_id = db.Column(db.String(36), db.ForeignKey('report.id'), nullable=False)
    message = db.Column(db.Text, nullable=False)
    place = db.Column(db.String(180), default='')
    contact = db.Column(db.String(180), default='')
    created_at = db.Column(db.DateTime(timezone=True), default=now)
    expires_at = db.Column(db.DateTime(timezone=True), default=lambda: now() + timedelta(days=90))

class NotificationPreference(db.Model):
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), primary_key=True)
    in_app = db.Column(db.Boolean, default=True, nullable=False)
    email_sightings = db.Column(db.Boolean, default=True, nullable=False)
    email_status = db.Column(db.Boolean, default=True, nullable=False)
    email_reminders = db.Column(db.Boolean, default=True, nullable=False)

class Notification(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)
    kind = db.Column(db.String(40), nullable=False)
    title = db.Column(db.String(180), nullable=False)
    message = db.Column(db.Text, nullable=False)
    report_id = db.Column(db.String(36), db.ForeignKey('report.id'))
    read_at = db.Column(db.DateTime(timezone=True))
    created_at = db.Column(db.DateTime(timezone=True), default=now, index=True)

class EmailDelivery(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    kind = db.Column(db.String(40), nullable=False)
    status = db.Column(db.String(30), nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), default=now)

def report_json(item, image_url=None):
    return {'id': item.id, 'name': item.name, 'status': item.status, 'place': item.place,
      'latitude': item.latitude, 'longitude': item.longitude, 'date': item.event_at.isoformat() if item.event_at else None,
      'color': item.color, 'sex': item.sex, 'desc': item.description, 'image': image_url or item.image_url,
      'created_at': item.created_at.isoformat() if item.created_at else None}

def notification_json(item):
    return {'id':item.id,'kind':item.kind,'title':item.title,'message':item.message,
      'report_id':item.report_id,'read':item.read_at is not None,
      'created_at':item.created_at.isoformat() if item.created_at else None}

def create_app(test_config=None):
    # The standalone Audela deployment serves the Vite build from the same
    # Flask container.  The directory is optional so the API-only image and
    # the existing docker-compose stack keep working unchanged.
    frontend_dist = Path(__file__).parent / 'dist'
    app = Flask(__name__, static_folder=str(frontend_dist) if frontend_dist.is_dir() else None)
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1, x_prefix=1)
    root = Path(__file__).parent
    database_url = normalize_database_url(os.getenv('DATABASE_URL'), root)
    app.config.update(
      SQLALCHEMY_DATABASE_URI=database_url,
      SQLALCHEMY_TRACK_MODIFICATIONS=False, JWT_SECRET=os.getenv('JWT_SECRET', 'dev-change-me'),
      MAX_CONTENT_LENGTH=8 * 1024 * 1024, UPLOAD_FOLDER=str(root / 'uploads'),
      PUBLIC_API_URL=os.getenv('PUBLIC_API_URL', '').rstrip('/'),
      GOOGLE_CLIENT_ID=os.getenv('GOOGLE_CLIENT_ID', ''),
      GOOGLE_CLIENT_SECRET=os.getenv('GOOGLE_CLIENT_SECRET', ''),
      EMAIL_MODE=os.getenv('EMAIL_MODE','console'), EMAIL_FROM=os.getenv('EMAIL_FROM','Chat Perdu <notifications@example.fr>'),
      SMTP_HOST=os.getenv('SMTP_HOST','localhost'), SMTP_PORT=int(os.getenv('SMTP_PORT','587')),
      SMTP_USER=os.getenv('SMTP_USER',''), SMTP_PASSWORD=os.getenv('SMTP_PASSWORD',''),
      SMTP_STARTTLS=os.getenv('SMTP_STARTTLS','true').lower()=='true')
    if test_config: app.config.update(test_config)
    Path(app.config['UPLOAD_FOLDER']).mkdir(parents=True, exist_ok=True)
    db.init_app(app); CORS(app, resources={r'/api/*': {'origins': parse_origins(os.getenv('CORS_ORIGINS', '*'))}})
    migrate.init_app(app, db)
    email_service=AudelaEmailService(app)

    def public_api_url():
      configured = app.config.get('PUBLIC_API_URL', '').strip()
      if configured:
        return configured.rstrip('/')
      if has_request_context():
        return request.url_root.rstrip('/') + '/api'
      return ''

    def absolute_upload_url(value):
      if not value:
        return ''
      if value.startswith(('http://', 'https://')):
        return value
      if value.startswith('/api/'):
        base = public_api_url()
        return f"{base}{value[4:]}" if base else value
      return value

    def serialize_report(item):
      image = absolute_upload_url(item.image_url)
      if item.image_data:
        image = f"{public_api_url()}/reports/{item.id}/image"
      return report_json(item, image)

    def preferences(user_id):
      prefs=db.session.get(NotificationPreference,user_id)
      if not prefs:
        prefs=NotificationPreference(user_id=user_id);db.session.add(prefs);db.session.flush()
      return prefs

    def notify(user, kind, title, message, report_id=None, email_payload=None):
      prefs=preferences(user.id)
      if prefs.in_app:
        db.session.add(Notification(user_id=user.id,kind=kind,title=title,message=message,report_id=report_id))
      enabled={'sighting':prefs.email_sightings,'status':prefs.email_status,'reminder':prefs.email_reminders}.get(kind,False)
      if enabled and email_payload:
        try: result=email_service.send(user.email,*email_payload)
        except Exception:
          app.logger.exception('Échec email Audela');result='failed'
        db.session.add(EmailDelivery(user_id=user.id,kind=kind,status=result))

    def current_user(optional=False):
      raw = request.headers.get('Authorization', '').removeprefix('Bearer ').strip()
      if not raw: return None if optional else (_ for _ in ()).throw(PermissionError())
      try: payload = jwt.decode(raw, app.config['JWT_SECRET'], algorithms=['HS256'])
      except jwt.PyJWTError: raise PermissionError()
      return db.session.get(User, int(payload['sub']))

    def auth(fn):
      @wraps(fn)
      def wrapper(*args, **kwargs):
        try: user = current_user()
        except PermissionError: return jsonify(error='Authentification requise'), 401
        return fn(user, *args, **kwargs)
      return wrapper

    @app.get('/api/health')
    def health():
      return jsonify(
        status='ok',
        service='audela-chat-perdu',
        privacy='2026-08',
        database=app.config['SQLALCHEMY_DATABASE_URI'].split(':', 1)[0],
      )

    @app.get('/health')
    def health_alias():
      return health()

    @app.get('/ready')
    def ready():
      return jsonify(status='ready', service='audela-chat-perdu')

    @app.post('/api/auth/register')
    def register():
      data=request.get_json(silent=True) or {}; email=data.get('email','').strip().lower(); password=data.get('password','')
      if '@' not in email or len(password)<10 or not data.get('name'): return jsonify(error='Nom, email et mot de passe de 10 caractères requis'),400
      if User.query.filter_by(email=email).first(): return jsonify(error='Compte déjà existant'),409
      user=User(email=email,name=data['name'][:80],password_hash=generate_password_hash(password)); db.session.add(user);db.session.flush();preferences(user.id);db.session.commit()
      return jsonify(token=jwt.encode({'sub':str(user.id),'exp':now()+timedelta(days=7)},app.config['JWT_SECRET'],algorithm='HS256')),201

    @app.post('/api/auth/login')
    def login():
      data=request.get_json(silent=True) or {}; user=User.query.filter_by(email=data.get('email','').lower()).first()
      if not user or not check_password_hash(user.password_hash,data.get('password','')): return jsonify(error='Identifiants invalides'),401
      return jsonify(token=jwt.encode({'sub':str(user.id),'exp':now()+timedelta(days=7)},app.config['JWT_SECRET'],algorithm='HS256'))

    def _safe_redirect_to(value):
      fallback = request.url_root.rstrip('/')
      if not value:
        return fallback
      parsed = urllib.parse.urlparse(value)
      if parsed.scheme not in ('http', 'https') or not parsed.netloc:
        return fallback
      return value.rstrip('/')

    @app.get('/api/auth/google/start')
    def google_start():
      client_id = app.config.get('GOOGLE_CLIENT_ID', '')
      client_secret = app.config.get('GOOGLE_CLIENT_SECRET', '')
      if not client_id or not client_secret:
        return jsonify(error='Google OAuth non configuré'),503
      mode = request.args.get('mode', 'login')
      if mode not in ('login', 'signup'):
        mode = 'login'
      redirect_to = _safe_redirect_to(request.args.get('redirect_to', ''))
      callback_url = f"{request.url_root.rstrip('/')}/api/auth/google/callback"
      state = jwt.encode(
        {'nonce': secrets.token_hex(16), 'mode': mode, 'redirect_to': redirect_to, 'exp': now()+timedelta(minutes=15)},
        app.config['JWT_SECRET'],
        algorithm='HS256',
      )
      params = urllib.parse.urlencode({
        'client_id': client_id,
        'redirect_uri': callback_url,
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'access_type': 'online',
        'prompt': 'select_account',
      })
      return redirect(f"https://accounts.google.com/o/oauth2/v2/auth?{params}")

    @app.get('/api/auth/google/callback')
    def google_callback():
      error = request.args.get('error')
      code = request.args.get('code')
      state_token = request.args.get('state', '')
      try:
        state = jwt.decode(state_token, app.config['JWT_SECRET'], algorithms=['HS256'])
      except jwt.PyJWTError:
        return redirect('/#google_error=invalid_state')
      redirect_to = _safe_redirect_to(state.get('redirect_to', ''))
      if error or not code:
        return redirect(f"{redirect_to}/#google_error={urllib.parse.quote(error or 'cancelled')}")
      callback_url = f"{request.url_root.rstrip('/')}/api/auth/google/callback"
      try:
        tr = _http.post(
          'https://oauth2.googleapis.com/token',
          data={
            'code': code,
            'client_id': app.config['GOOGLE_CLIENT_ID'],
            'client_secret': app.config['GOOGLE_CLIENT_SECRET'],
            'redirect_uri': callback_url,
            'grant_type': 'authorization_code',
          },
          timeout=10,
        )
        tr.raise_for_status()
        access_token = tr.json()['access_token']
        ui = _http.get(
          'https://www.googleapis.com/oauth2/v3/userinfo',
          headers={'Authorization': f'Bearer {access_token}'},
          timeout=10,
        )
        ui.raise_for_status()
        info = ui.json()
      except Exception:
        app.logger.exception('Google OAuth failed')
        return redirect(f"{redirect_to}/#google_error=auth_failed")
      email = info.get('email', '').strip().lower()
      name = (info.get('name') or info.get('given_name') or email.split('@')[0])[:80]
      if not email:
        return redirect(f"{redirect_to}/#google_error=no_email")
      user = User.query.filter_by(email=email).first()
      if not user:
        user = User(email=email, name=name, password_hash=generate_password_hash(secrets.token_hex(32)))
        db.session.add(user); db.session.flush(); preferences(user.id); db.session.commit()
      token = jwt.encode({'sub':str(user.id),'exp':now()+timedelta(days=7)},app.config['JWT_SECRET'],algorithm='HS256')
      return redirect(f"{redirect_to}/#token={urllib.parse.quote(token)}")

    @app.get('/api/reports')
    def reports():
      query=Report.query.filter(Report.expires_at > now()); status=request.args.get('status'); q=request.args.get('q','').strip()
      if status and status!='Tous': query=query.filter_by(status=status)
      if q: query=query.filter(db.or_(Report.name.ilike(f'%{q}%'),Report.place.ilike(f'%{q}%')))
      return jsonify(items=[serialize_report(x) for x in query.order_by(Report.created_at.desc()).limit(100)], total=query.count())

    @app.get('/api/reports/<report_id>')
    def report_detail(report_id):
      item=db.get_or_404(Report,report_id); return jsonify(serialize_report(item))

    @app.post('/api/reports')
    def create_report():
      data=request.get_json(silent=True) or {}
      if not data.get('name') or not data.get('place'): return jsonify(error='Prénom et dernier lieu requis'),400
      try: user=current_user(optional=True)
      except PermissionError: return jsonify(error='Jeton invalide'),401
      image_url=data.get('image_url','')
      image_data=None; image_mime=''
      if image_url.startswith('data:image/') and ';base64,' in image_url:
        header, encoded=image_url.split(';base64,',1)
        image_mime=header[5:80]; image_data=base64.b64decode(encoded)
        image_url=''
      item=Report(owner_id=user.id if user else None,name=data['name'][:80],place=data['place'][:180],status=data.get('status','Perdu'),color=data.get('color','Non précisé'),sex=data.get('sex','Inconnu'),description=data.get('description','')[:3000],image_url=image_url[:500],image_data=image_data,image_mime=image_mime,latitude=data.get('latitude'),longitude=data.get('longitude'))
      db.session.add(item);db.session.commit();return jsonify(serialize_report(item)),201

    @app.patch('/api/reports/<report_id>')
    @auth
    def update_report(user,report_id):
      item=db.get_or_404(Report,report_id)
      if item.owner_id != user.id: return jsonify(error='Accès refusé'),403
      data=request.get_json(silent=True) or {}; previous_status=item.status
      for key in ('name','place','status','color','sex','description','image_url'):
        if key in data: setattr(item,key,data[key])
      if item.status != previous_status:
        notify(user,'status',f'{item.name} : statut mis à jour',f'Le statut est maintenant « {item.status} ».',item.id,
          (f'Statut de {item.name} mis à jour',f'Bonjour {user.name}, le statut de {item.name} est maintenant « {item.status} ».'))
      db.session.commit();return jsonify(serialize_report(item))

    @app.delete('/api/reports/<report_id>')
    @auth
    def delete_report(user, report_id):
      item = db.get_or_404(Report, report_id)
      if item.owner_id != user.id:
        return jsonify(error='Vous ne pouvez supprimer que vos propres signalements'), 403
      Sighting.query.filter_by(report_id=report_id).delete()
      Notification.query.filter_by(report_id=report_id).delete()
      db.session.delete(item); db.session.commit(); return '', 204

    @app.post('/api/reports/<report_id>/sightings')
    def sighting(report_id):
      report=db.get_or_404(Report,report_id); data=request.get_json(silent=True) or {}
      if len(data.get('message','').strip())<3:return jsonify(error='Message requis'),400
      item=Sighting(report_id=report_id,message=data['message'][:2000],place=data.get('place','')[:180],contact=data.get('contact','')[:180]);db.session.add(item)
      if report.owner_id:
        owner=db.session.get(User,report.owner_id);payload=sighting_email(owner.name,report.name,item.place,item.message)
        notify(owner,'sighting',f'Une nouvelle piste pour {report.name}',item.message,report.id,payload)
      db.session.commit()
      return jsonify(id=item.id,message='Témoignage transmis'),201

    @app.get('/api/notifications')
    @auth
    def notifications(user):
      items=Notification.query.filter_by(user_id=user.id).order_by(Notification.created_at.desc()).limit(100).all()
      return jsonify(items=[notification_json(x) for x in items],unread=sum(x.read_at is None for x in items))

    @app.post('/api/notifications/<int:notification_id>/read')
    @auth
    def notification_read(user,notification_id):
      item=db.get_or_404(Notification,notification_id)
      if item.user_id!=user.id:return jsonify(error='Accès refusé'),403
      item.read_at=now();db.session.commit();return jsonify(notification_json(item))

    @app.post('/api/notifications/read-all')
    @auth
    def notifications_read_all(user):
      count=Notification.query.filter_by(user_id=user.id,read_at=None).update({'read_at':now()});db.session.commit()
      return jsonify(updated=count)

    @app.get('/api/notification-preferences')
    @auth
    def get_notification_preferences(user):
      p=preferences(user.id);db.session.commit()
      return jsonify(in_app=p.in_app,email_sightings=p.email_sightings,email_status=p.email_status,email_reminders=p.email_reminders)

    @app.patch('/api/notification-preferences')
    @auth
    def update_notification_preferences(user):
      p=preferences(user.id);data=request.get_json(silent=True) or {}
      for key in ('in_app','email_sightings','email_status','email_reminders'):
        if key in data:setattr(p,key,bool(data[key]))
      db.session.commit();return jsonify(in_app=p.in_app,email_sightings=p.email_sightings,email_status=p.email_status,email_reminders=p.email_reminders)

    @app.post('/api/uploads')
    def upload():
      file=request.files.get('file')
      if not file or Path(file.filename).suffix.lower() not in {'.jpg','.jpeg','.png','.webp'}: return jsonify(error='Image JPG, PNG ou WebP requise'),400
      raw=file.read()
      if len(raw)>8*1024*1024: return jsonify(error='Image trop volumineuse'),413
      mime=file.mimetype or 'application/octet-stream'
      data_url=f'data:{mime};base64,{base64.b64encode(raw).decode()}'
      return jsonify(url=data_url, path=data_url),201

    @app.get('/api/uploads/<name>')
    def uploaded(name): return send_file(Path(app.config['UPLOAD_FOLDER'])/secure_filename(name))

    @app.get('/api/reports/<report_id>/image')
    def report_image(report_id):
      item=db.get_or_404(Report, report_id)
      if not item.image_data: return jsonify(error='Image introuvable'), 404
      return app.response_class(item.image_data, mimetype=item.image_mime or 'application/octet-stream')

    @app.get('/api/privacy/export')
    @auth
    def privacy_export(user):
      owned=Report.query.filter_by(owner_id=user.id).all()
      notes=Notification.query.filter_by(user_id=user.id).all()
      return jsonify(user={'email':user.email,'name':user.name,'created_at':user.created_at.isoformat()},reports=[serialize_report(x) for x in owned],notifications=[notification_json(x) for x in notes])

    @app.delete('/api/privacy/account')
    @auth
    def privacy_delete(user):
      Report.query.filter_by(owner_id=user.id).update({'owner_id':None});Notification.query.filter_by(user_id=user.id).delete();EmailDelivery.query.filter_by(user_id=user.id).delete();NotificationPreference.query.filter_by(user_id=user.id).delete();db.session.delete(user);db.session.commit();return '',204

    @app.post('/api/admin/purge')
    def purge():
      if request.headers.get('X-Purge-Key') != os.getenv('PURGE_KEY','dev-purge'): return jsonify(error='Accès refusé'),403
      sightings=Sighting.query.filter(Sighting.expires_at < now()).delete(); reports=Report.query.filter(Report.expires_at < now()).delete();db.session.commit()
      return jsonify(reports=reports,sightings=sightings)

    if frontend_dist.is_dir():
      @app.get('/')
      def frontend_index():
        return send_file(frontend_dist / 'index.html')

      @app.get('/<path:path>')
      def frontend_routes(path):
        requested = frontend_dist / path
        if requested.is_file():
          return send_file(requested)
        return send_file(frontend_dist / 'index.html')

    if app.config.get('TESTING', False) or app.config.get('AUTO_CREATE_DB', False):
      with app.app_context():
        db.create_all()
        if not Report.query.first():
          for data in [
            ('Moka','Perdu','Canal Saint-Martin, Paris 10e','Roux & blanc','https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=900&q=85'),
            ('Nala','Aperçu','Rue Oberkampf, Paris 11e','Écaille de tortue','https://images.unsplash.com/photo-1495360010541-f48722b34f7d?auto=format&fit=crop&w=900&q=85'),
            ('Simba','Perdu','Buttes-Chaumont, Paris 19e','Tigré brun','https://images.unsplash.com/photo-1533743983669-94fa5c4338ec?auto=format&fit=crop&w=900&q=85')]:
            db.session.add(Report(name=data[0],status=data[1],place=data[2],color=data[3],image_url=data[4],description='Aidez-nous à le retrouver. Approchez calmement et envoyez toute information utile.'))
        db.session.commit()
    return app

app=create_app()
if __name__=='__main__': app.run(host='0.0.0.0',port=int(os.getenv('PORT','5000')),debug=os.getenv('FLASK_DEBUG')=='1')
