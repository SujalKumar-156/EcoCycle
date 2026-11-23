import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Build output goes to ../public, which server.js already serves statically.
// In dev (npm run dev) the proxy forwards /api calls to the Express server.
export default defineConfig({
  plugins: [react()],
  build: { outDir: '../public', emptyOutDir: true },
  server: { proxy: { '/api': 'http://localhost:3000' } },
});
