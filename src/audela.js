import {resolveApiUrl, resolveAssetUrl, resolveAudelaAuthUrl} from './config';

function authHeaders() {
  const token = localStorage.getItem('audela-token') || import.meta.env.VITE_AUDELA_API_TOKEN || '';
  return {
    'Content-Type': 'application/json',
    ...(token ? {Authorization: `Bearer ${token}`} : {}),
  };
}

async function readJson(response, fallbackMessage) {
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || fallbackMessage);
  }
  return data;
}

function relativeTime(value) {
  if (!value) {
    return 'À l’instant';
  }
  const delta = Date.now() - new Date(value).getTime();
  const minutes = Math.max(1, Math.round(delta / 60000));
  if (minutes < 60) {
    return `Il y a ${minutes} min`;
  }
  const hours = Math.round(minutes / 60);
  if (hours < 24) {
    return `Il y a ${hours} h`;
  }
  const days = Math.round(hours / 24);
  return days === 1 ? 'Hier' : `Il y a ${days} jours`;
}

function formatEventDate(value) {
  if (!value) {
    return 'Date non précisée';
  }
  return new Intl.DateTimeFormat('fr-FR', {
    dateStyle: 'long',
    timeStyle: 'short',
  }).format(new Date(value));
}

export function normalizeReport(report) {
  return {
    ...report,
    desc: report.desc || '',
    image: resolveAssetUrl(report.image),
    time: relativeTime(report.created_at || report.date),
    dateLabel: formatEventDate(report.date || report.created_at),
    distance: report.place || 'Lieu non précisé',
  };
}

export async function publishToAudela(report) {
  const response = await fetch(resolveApiUrl('reports'), {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(report),
  });
  return {synced: true, data: normalizeReport(await readJson(response, 'Publication impossible'))};
}

export async function uploadImage(file) {
  const formData = new FormData();
  formData.append('file', file);
  const token = localStorage.getItem('audela-token') || import.meta.env.VITE_AUDELA_API_TOKEN || '';
  const response = await fetch(resolveApiUrl('uploads'), {
    method: 'POST',
    headers: token ? {Authorization: `Bearer ${token}`} : undefined,
    body: formData,
  });
  return readJson(response, 'Téléversement impossible');
}

export async function authenticate(mode, values) {
  const response = await fetch(resolveApiUrl(`auth/${mode}`), {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(values),
  });
  const data = await readJson(response, 'Connexion impossible');
  localStorage.setItem('audela-token', data.token);
  return data;
}

export function audelaGoogleLoginUrl({mode = 'login'} = {}) {
  const safeMode = mode === 'signup' ? 'signup' : 'login';
  const appTarget = import.meta.env.VITE_AUDELA_GOOGLE_APP || 'tenant';
  const tenantSlug = (import.meta.env.VITE_AUDELA_TENANT_SLUG || '').trim();
  const params = new URLSearchParams({app: appTarget, mode: safeMode});
  if (tenantSlug) {
    params.set('tenant_slug', tenantSlug);
  }
  return `${resolveAudelaAuthUrl('login/google/start')}?${params.toString()}`;
}

export async function getNotifications() {
  const response = await fetch(resolveApiUrl('notifications'), {headers: authHeaders()});
  return readJson(response, 'Connexion requise');
}

export async function readAllNotifications() {
  const response = await fetch(resolveApiUrl('notifications/read-all'), {
    method: 'POST',
    headers: authHeaders(),
  });
  return readJson(response, 'Action impossible');
}

export async function getNotificationPreferences() {
  const response = await fetch(resolveApiUrl('notification-preferences'), {headers: authHeaders()});
  return readJson(response, 'Connexion requise');
}

export async function saveNotificationPreferences(data) {
  const response = await fetch(resolveApiUrl('notification-preferences'), {
    method: 'PATCH',
    headers: authHeaders(),
    body: JSON.stringify(data),
  });
  return readJson(response, 'Enregistrement impossible');
}

export async function getReports({q = '', status = 'Tous'} = {}) {
  const params = new URLSearchParams({q, status});
  const response = await fetch(`${resolveApiUrl('reports')}?${params.toString()}`);
  const data = await readJson(response, 'Le service est momentanément indisponible');
  return {...data, items: data.items.map(normalizeReport)};
}

export async function sendSighting(reportId, payload) {
  const response = await fetch(resolveApiUrl(`reports/${reportId}/sightings`), {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(payload),
  });
  return readJson(response, 'Envoi impossible');
}
