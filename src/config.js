const browserOrigin = typeof window === 'undefined' ? 'http://localhost:5000' : window.location.origin;

function trimTrailingSlash(value) {
  return value.replace(/\/+$/, '');
}

function defaultApiUrl() {
  if (typeof window === 'undefined') {
    return 'http://localhost:5000/api';
  }
  return import.meta.env.DEV ? 'http://localhost:5000/api' : '/api';
}

const configuredApiUrl = import.meta.env.VITE_API_URL || import.meta.env.VITE_AUDELA_API_URL || defaultApiUrl();

export const apiBaseUrl = trimTrailingSlash(
  configuredApiUrl.startsWith('http') ? configuredApiUrl : new URL(configuredApiUrl, browserOrigin).toString()
);

export function resolveApiUrl(path = '') {
  const normalizedPath = path.replace(/^\//, '');
  return normalizedPath ? `${apiBaseUrl}/${normalizedPath}` : apiBaseUrl;
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