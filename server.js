const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const FLASK_API_URL = process.env.FLASK_API_URL || 'http://api:5000';

app.use(
  '/api',
  createProxyMiddleware({
    target: FLASK_API_URL,
    changeOrigin: true,
    onError: (err, _req, res) => {
      if (!res.headersSent) {
        res.writeHead(504, {'Content-Type': 'application/json'});
      }
      res.end(JSON.stringify({error: `API backend unavailable via ${FLASK_API_URL}`}));
    },
  })
);

// APK files are ZIP-based internally, so send the Android package MIME type
// explicitly to prevent browsers from presenting the download as a ZIP.
app.get('/download/chat-perdu.apk', (_req, res) => {
  res.type('application/vnd.android.package-archive');
  res.set('Content-Disposition', 'attachment; filename="chat-perdu.apk"');
  res.sendFile(path.join(__dirname, 'dist', 'download', 'chat-perdu.apk'));
});

app.use(express.static(path.join(__dirname, 'dist')));

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}, proxying /api to ${FLASK_API_URL}`);
});
