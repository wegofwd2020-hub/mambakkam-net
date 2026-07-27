#!/usr/bin/env node
/*
 * Render the og:image cards in scripts/og/cards/ to PNGs under src/assets/.
 *
 *   npm run og            # render every card
 *   npm run og mentible   # render just cards/mentible.html
 *   npm run og -- --check # render to a temp dir and report drift, write nothing
 *
 * Cards are HTML because the alternative — placing pixels by hand — cannot use
 * the site's own fonts and palette, and every future edit reopens an image
 * editor instead of a diff. Each card names its own destination in a
 * <meta name="og-out"> tag so there is no second registry to drift out of sync.
 *
 * Rendered at 2x and downscaled, which is what keeps the type crisp: Chrome
 * hints glyphs to the device pixel grid, so a straight 1x shot of 25px text is
 * visibly softer than a 2x shot resampled down.
 *
 * Regenerating changes the file, which changes Astro's content hash, which
 * changes the og:image URL — and a changed URL means every cached preview must
 * be re-scraped in Facebook's Sharing Debugger before WhatsApp shows it. Do not
 * re-render casually; --check tells you whether anything actually moved.
 */

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '../..');
const CARDS = join(HERE, 'cards');

// The shape WhatsApp, iMessage and Slack crop link previews to.
const WIDTH = 1200;
const HEIGHT = 630;
const SCALE = 2;

const CHROME_CANDIDATES = ['google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser'];

function findChrome() {
  for (const bin of CHROME_CANDIDATES) {
    try {
      execFileSync('which', [bin], { stdio: 'pipe' });
      return bin;
    } catch {
      // Not on PATH — try the next one.
    }
  }
  throw new Error(
    `No Chrome or Chromium found on PATH (looked for: ${CHROME_CANDIDATES.join(', ')}).\n` +
      `Install one, or point the script at a binary with CHROME=/path/to/chrome.`
  );
}

/** Each card declares where its PNG belongs, so the HTML stays self-describing. */
function outputPath(html, file) {
  const match = html.match(/<meta\s+name="og-out"\s+content="([^"]+)"/);
  if (!match) throw new Error(`${file} has no <meta name="og-out"> — cannot tell where to write it.`);
  return resolve(REPO, match[1]);
}

function shoot(chrome, htmlPath, pngPath) {
  execFileSync(
    chrome,
    [
      '--headless',
      '--disable-gpu',
      '--no-sandbox',
      '--hide-scrollbars',
      `--force-device-scale-factor=${SCALE}`,
      `--window-size=${WIDTH},${HEIGHT}`,
      `--screenshot=${pngPath}`,
      // Fonts and the logo load over file://; without a budget Chrome can shoot
      // the frame before they land and silently bake in a fallback face.
      '--virtual-time-budget=4000',
      `file://${htmlPath}`,
    ],
    { stdio: 'pipe' }
  );
}

const args = process.argv.slice(2);
const check = args.includes('--check');
const wanted = args.filter((a) => !a.startsWith('--'));

const chrome = process.env.CHROME || findChrome();
const scratch = mkdtempSync(join(tmpdir(), 'og-cards-'));
let drifted = 0;

try {
  const files = readdirSync(CARDS)
    .filter((f) => f.endsWith('.html'))
    .filter((f) => wanted.length === 0 || wanted.includes(basename(f, '.html')));

  if (files.length === 0) {
    throw new Error(
      `No cards matched${wanted.length ? ` (${wanted.join(', ')})` : ''}. Available: ${readdirSync(CARDS).join(', ')}`
    );
  }

  for (const file of files) {
    const htmlPath = join(CARDS, file);
    const dest = outputPath(readFileSync(htmlPath, 'utf8'), file);

    const shotPath = join(scratch, `${file}.2x.png`);
    shoot(chrome, htmlPath, shotPath);

    const png = await sharp(shotPath)
      .resize(WIDTH, HEIGHT, { fit: 'cover' })
      .png({ compressionLevel: 9, palette: true })
      .toBuffer();

    const rel = dest.slice(REPO.length + 1);
    const previous = existsSync(dest) ? readFileSync(dest) : null;
    const same = previous?.equals(png) ?? false;

    if (check) {
      if (!same) drifted++;
      console.log(`${same ? 'unchanged' : 'DRIFTED  '}  ${rel}`);
      continue;
    }

    writeFileSync(dest, png);
    console.log(`${same ? 'unchanged' : 'written  '}  ${rel}  ${WIDTH}x${HEIGHT}  ${Math.round(png.length / 1024)}KB`);
  }

  if (check && drifted > 0) {
    console.log(
      `\n${drifted} card(s) differ from what is committed. Re-render deliberately: regenerating changes the og:image URL and invalidates every cached link preview.`
    );
    process.exitCode = 1;
  }
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
