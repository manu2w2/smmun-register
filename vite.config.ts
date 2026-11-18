import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  const pagesPath = loadEnv(mode, '.', 'PAGES_').PAGES_BASE_PATH?.replace(/^\//, '');

  return {
    plugins: [
      sveltekit({
        adapter: adapter(),
        paths: { base: pagesPath ? `/${pagesPath}` : '' },
        preprocess: vitePreprocess()
      })
    ]
  };
});
