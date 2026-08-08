const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const FLASK_API_URL = process.env.FLASK_API_URL || 'http://127.0.0.1:5000';

app.use(
  '/api',
  createProxyMiddleware({
    target: FLASK_API_URL,
    changeOrigin: true,
  })
);

app.use(express.static(path.join(__dirname, 'dist')));

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}, proxying /api to ${FLASK_API_URL}`);
});
