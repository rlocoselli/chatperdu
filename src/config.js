const AUDELA_ORIGIN = 'https://audeladedonnees.fr';
const browserOrigin = typeof window === 'undefined' ? AUDELA_ORIGIN : window.location.origin;

function trimTrailingSlash(value) {
  return value.replace(/\/+$/, '');
}

function defaultApiUrl() {
  return '/api';
}

const configuredApiUrl = import.meta.env.VITE_API_URL || import.meta.env.VITE_AUDELA_API_URL || defaultApiUrl();
const configuredAuthUrl = import.meta.env.VITE_AUDELA_AUTH_URL || AUDELA_ORIGIN;

export const apiBaseUrl = trimTrailingSlash(
  configuredApiUrl.startsWith('http') ? configuredApiUrl : new URL(configuredApiUrl, browserOrigin).toString()
);

export const audelaAuthBaseUrl = trimTrailingSlash(
  configuredAuthUrl.startsWith('http') ? configuredAuthUrl : new URL(configuredAuthUrl, browserOrigin).toString()
);

export function resolveApiUrl(path = '') {
  const normalizedPath = path.replace(/^\//, '');
  return normalizedPath ? `${apiBaseUrl}/${normalizedPath}` : apiBaseUrl;
}

export function resolveAudelaAuthUrl(path = '') {
  const normalizedPath = path.replace(/^\//, '');
  return normalizedPath ? `${audelaAuthBaseUrl}/${normalizedPath}` : audelaAuthBaseUrl;
}

export function resolveAssetUrl(value) {
  if (!value) {
    return '';
  }
  if (/^https?:\/\//i.test(value)) {
    return value;
  }
  return new URL(value, `${apiBaseUrl}/`).toString();
}