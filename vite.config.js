import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';

function apkHeaders() {
  return {
    name: 'apk-download-headers',
    configurePreviewServer(server) {
      server.middlewares.use('/download/chat-perdu.apk', (_req, res, next) => {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', 'attachment; filename="chat-perdu.apk"');
        next();
      });
    },
    configureServer(server) {
      server.middlewares.use('/download/chat-perdu.apk', (_req, res, next) => {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', 'attachment; filename="chat-perdu.apk"');
        next();
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), apkHeaders()],
});
