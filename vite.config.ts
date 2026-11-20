import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  const pagesPath = loadEnv(mode, '.', 'PAGES_').PAGES_BASE_PATH?.replace(/^\//, '');

  return {
    server: {
      host: 'localhost', port: 5173, strictPort: true,
      fs: {
        // Conserva las exclusiones de Vite y protege los archivos operativos del catálogo.
        deny: ['.env', '.env.*', '*.{crt,pem,key,p12,pfx,cer,der}', '.npmrc', '.yarnrc.yml', '**/.git/**',
          'smmun-registro-*.json', '**/outputs/**', '**/exports/**', '**/supabase/.temp/**']
      }
    },
    plugins: [
      sveltekit({
        adapter: adapter(),
        paths: { base: pagesPath ? `/${pagesPath}` : '' },
        preprocess: vitePreprocess()
      })
    ]
  };
});
