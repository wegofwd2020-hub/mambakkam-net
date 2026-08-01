import type { AstroIntegration } from 'astro';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

/**
 * Dev-only endpoint that rewrites the `theme:` field of a work entry.
 *
 * This is a Vite dev-server middleware rather than a route under src/pages/,
 * and deliberately so. The site is `output: 'static'` with no adapter, so a
 * POST endpoint cannot exist in a build — putting one in src/pages/ would
 * either fail the build or ship a dead file. A middleware registered on
 * `astro:server:setup` runs only under `astro dev` and has no build-time
 * existence at all, which is the honest shape for a local-only tool.
 *
 * It writes the same file you would edit by hand. The change shows up in
 * `git status` and reaches production the same way every other change does —
 * commit, PR, CI, merge. Nothing here writes to a database or touches a
 * deployed site.
 */

const WORK_DIR = 'src/data/work';

/** Rewrite (or insert) the `theme:` line in a markdown file's frontmatter. */
export function setThemeInFrontmatter(source: string, theme: string | null): string {
  const match = source.match(/^---\n([\s\S]*?)\n---/);
  if (!match) throw new Error('no frontmatter block');

  let block = match[1];
  const hasTheme = /^theme:.*$/m.test(block);

  if (theme === null) {
    if (!hasTheme) return source;
    block = block.replace(/^theme:.*\n?/m, '');
  } else if (hasTheme) {
    block = block.replace(/^theme:.*$/m, `theme: ${theme}`);
  } else {
    // Sit next to landingUrl when there is one, else after status — both are
    // "how this entry presents itself", and grouping them keeps the diff
    // readable rather than appending to whatever happens to be last.
    if (/^landingUrl:.*$/m.test(block)) {
      block = block.replace(/^(landingUrl:.*)$/m, `$1\ntheme: ${theme}`);
    } else if (/^status:.*$/m.test(block)) {
      block = block.replace(/^(status:.*)$/m, `$1\ntheme: ${theme}`);
    } else {
      block = `${block}\ntheme: ${theme}`;
    }
  }

  return source.replace(match[0], `---\n${block}\n---`);
}

export default function themeEditor(): AstroIntegration {
  return {
    name: 'theme-editor',
    hooks: {
      'astro:server:setup': ({ server, logger }) => {
        logger.info('theme editor available at /themes (dev only)');

        server.middlewares.use('/__theme-editor', async (req, res) => {
          if (req.method !== 'POST') {
            res.statusCode = 405;
            res.end('POST only');
            return;
          }

          try {
            const chunks: Buffer[] = [];
            for await (const chunk of req) chunks.push(chunk as Buffer);
            const { slug, theme } = JSON.parse(Buffer.concat(chunks).toString() || '{}');

            if (!slug || typeof slug !== 'string') throw new Error('slug is required');

            // Never let a slug escape the work directory.
            const files = await readdir(WORK_DIR);
            const file = files.find((f) => f.replace(/\.mdx?$/, '') === slug);
            if (!file) throw new Error(`no work entry "${slug}"`);

            const full = path.join(WORK_DIR, file);
            const source = await readFile(full, 'utf8');
            const next = setThemeInFrontmatter(source, theme || null);

            if (next !== source) await writeFile(full, next, 'utf8');

            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ ok: true, file: full, changed: next !== source }));
          } catch (error) {
            res.statusCode = 400;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ ok: false, error: (error as Error).message }));
          }
        });
      },
    },
  };
}
