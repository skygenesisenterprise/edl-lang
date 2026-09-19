import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://edl-lang.github.io',
  base: process.env.ASTRO_BASE || '/',
  output: 'static',
  integrations: [sitemap()],
});
