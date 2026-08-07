import os
import smtplib
from email.message import EmailMessage


class AudelaEmailService:
    """Envoi transactionnel SMTP. Le mode console est le défaut sûr en développement."""

    def __init__(self, app):
        self.app = app

    def send(self, recipient, subject, text, html=None):
        mode = self.app.config['EMAIL_MODE']
        if mode == 'disabled':
            return 'disabled'
        message = EmailMessage()
        message['From'] = self.app.config['EMAIL_FROM']
        message['To'] = recipient
        message['Subject'] = subject
        message.set_content(text)
        if html:
            message.add_alternative(html, subtype='html')
        if mode == 'console':
            self.app.logger.info('AUDELA EMAIL recipient=%s subject=%s', recipient, subject)
            return 'console'
        with smtplib.SMTP(self.app.config['SMTP_HOST'], self.app.config['SMTP_PORT'], timeout=10) as smtp:
            if self.app.config['SMTP_STARTTLS']:
                smtp.starttls()
            if self.app.config['SMTP_USER']:
                smtp.login(self.app.config['SMTP_USER'], self.app.config['SMTP_PASSWORD'])
            smtp.send_message(message)
        return 'sent'


def sighting_email(owner_name, cat_name, place, message):
    subject = f'Nouvelle information pour {cat_name}'
    text = (f'Bonjour {owner_name},\n\nUne personne a envoyé une information concernant {cat_name}.\n'
            f'Lieu indiqué : {place or "non précisé"}\nMessage : {message}\n\n'
            'Connectez-vous à Chat Perdu pour consulter votre alerte. Ne répondez pas directement à cet email.')
    html = f'''<div style="font-family:Arial;color:#173c35;max-width:560px"><h2>Une nouvelle piste pour {cat_name} 🐾</h2><p>Bonjour {owner_name},</p><p>Une personne a transmis une information.</p><div style="background:#f7f4ed;padding:16px;border-radius:10px"><b>Lieu</b><br>{place or 'Non précisé'}<br><br><b>Message</b><br>{message}</div><p>Ouvrez Chat Perdu pour consulter votre alerte.</p></div>'''
    return subject, text, html
