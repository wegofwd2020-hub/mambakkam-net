import path from 'path';
import { fileURLToPath } from 'url';

import { defineConfig } from 'astro/config';

import sitemap from '@astrojs/sitemap';
import tailwind from '@astrojs/tailwind';
import mdx from '@astrojs/mdx';
import partytown from '@astrojs/partytown';
import icon from 'astro-icon';
import compress from 'astro-compress';
import type { AstroIntegration } from 'astro';

import astrowind from './vendor/integration';

import { readingTimeRemarkPlugin, responsiveTablesRehypePlugin, lazyImagesRehypePlugin } from './src/utils/frontmatter';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const hasExternalScripts = false;
const whenExternalScripts = (items: (() => AstroIntegration) | (() => AstroIntegration)[] = []) =>
  hasExternalScripts ? (Array.isArray(items) ? items.map((item) => item()) : [items()]) : [];

export default defineConfig({
  output: 'static',

  // NOTE on trailing slashes. Locally, /kaundinya/ and /demos/atri-sangam/
  // 404 while /kaundinya and /demos/atri-sangam work; in production both
  // resolve, because nginx maps /page/ to page/index.html. `trailingSlash`
  // does NOT fix this: it governs the dev server and on-demand rendered
  // pages, and every page here is prerendered (output: 'static'), so Astro
  // leaves the question to the host. Tried 'ignore' explicitly — no effect.
  // A local trailing-slash 404 therefore says nothing about production;
  // check the deployed URL instead.

  redirects: {
    // StudyBuddy Q was rebranded and spun out as Mentible (2026-06).
    '/work/studybuddy-q': '/work/mentible',
    // The Atri Sangam replay .html URLs are preserved as real files in
    // public/demos/atri-sangam/. An Astro redirect emits them as directories
    // (clean.html/index.html), which only resolves if the server first
    // redirects /clean.html to /clean.html/ — a server behaviour worth not
    // depending on for URLs that are already public.
  },

  integrations: [
    tailwind({
      applyBaseStyles: false,
    }),
    sitemap(),
    mdx(),
    icon({
      include: {
        tabler: ['*'],
        'flat-color-icons': [
          'template',
          'gallery',
          'approval',
          'document',
          'advertising',
          'currency-exchange',
          'voice-presentation',
          'business-contact',
          'database',
        ],
      },
    }),

    ...whenExternalScripts(() =>
      partytown({
        config: { forward: ['dataLayer.push'] },
      })
    ),

    compress({
      CSS: true,
      HTML: {
        'html-minifier-terser': {
          removeAttributeQuotes: false,
        },
      },
      Image: false,
      JavaScript: true,
      SVG: false,
      Logger: 1,
    }),

    astrowind({
      config: './src/config.yaml',
    }),
  ],

  image: {
    domains: ['cdn.pixabay.com'],
  },

  markdown: {
    remarkPlugins: [readingTimeRemarkPlugin],
    rehypePlugins: [responsiveTablesRehypePlugin, lazyImagesRehypePlugin],
  },

  vite: {
    resolve: {
      alias: {
        '~': path.resolve(__dirname, './src'),
      },
    },
  },
});
