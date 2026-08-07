from io import BytesIO

from app import create_app, db

def client(tmp_path):
    app=create_app({'TESTING':True,'SQLALCHEMY_DATABASE_URI':'sqlite://','UPLOAD_FOLDER':str(tmp_path)})
    return app.test_client()

def test_health_and_reports(tmp_path):
    c=client(tmp_path)
    assert c.get('/api/health').status_code==200
    assert c.get('/api/reports').get_json()['total']>=3

def test_uploads_and_report_urls_are_absolute_with_public_api_url(tmp_path):
    c=client(tmp_path)
    c.application.config['PUBLIC_API_URL']='https://api.chatperdu.example/api'
    upload=c.post('/api/uploads',data={'file':(BytesIO(b'fake-image'),'moka.png')},content_type='multipart/form-data')
    assert upload.status_code==201
    payload=upload.get_json()
    assert payload['url']=='https://api.chatperdu.example/api/uploads/' + payload['path'].split('/')[-1]
    report=c.post('/api/reports',json={'name':'Moka','place':'Paris','image_url':payload['path']}).get_json()
    assert report['image'].startswith('https://api.chatperdu.example/api/uploads/')

def test_create_report(tmp_path):
    c=client(tmp_path)
    res=c.post('/api/reports',json={'name':'Pixel','place':'Lyon 2e','status':'Perdu'})
    assert res.status_code==201 and res.get_json()['name']=='Pixel'

def test_privacy_lifecycle(tmp_path):
    c=client(tmp_path)
    token=c.post('/api/auth/register',json={'name':'Ana','email':'ana@example.fr','password':'motdepasse-solide'}).get_json()['token']
    headers={'Authorization':f'Bearer {token}'}
    assert c.get('/api/privacy/export',headers=headers).status_code==200
    assert c.delete('/api/privacy/account',headers=headers).status_code==204

def test_sighting_creates_notification_and_email_delivery(tmp_path):
    c=client(tmp_path)
    token=c.post('/api/auth/register',json={'name':'Léo','email':'leo@example.fr','password':'motdepasse-solide'}).get_json()['token']
    headers={'Authorization':f'Bearer {token}'}
    report=c.post('/api/reports',headers=headers,json={'name':'Olive','place':'Nantes'}).get_json()
    assert c.post(f"/api/reports/{report['id']}/sightings",json={'message':'Vu près du parc','place':'Parc central'}).status_code==201
    notes=c.get('/api/notifications',headers=headers).get_json()
    assert notes['unread']==1 and notes['items'][0]['kind']=='sighting'
    assert c.post('/api/notifications/read-all',headers=headers).get_json()['updated']==1
    prefs=c.patch('/api/notification-preferences',headers=headers,json={'email_sightings':False}).get_json()
    assert prefs['email_sightings'] is False
