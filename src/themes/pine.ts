import type { Theme } from './index';

/**
 * Pine and gold — Kaundinya Labs.
 *
 * Values taken verbatim from src/pages/kaundinya.astro, which still carries
 * them inline. DECLARED BUT NOT YET APPLIED: that page has not been migrated,
 * so this file and the page are two copies of the same palette until it is.
 *
 * It is registered anyway so the registry is genuinely multi-theme and the
 * token shape is proven against a second, quite different palette rather than
 * fitted to Emerald alone. Migrate kaundinya.astro to it when that page is
 * next touched, and delete this note.
 */
export const pine: Theme = {
  id: 'pine',
  label: 'Kaundinya Pine',

  bg: '#0b1f16',
  panel: '#123024',
  panelHi: '#1d4a37',

  accent: '#dca84b',
  accentSoft: '#f6dc9a',
  text: '#f4ecdd',

  mono: "'Space Grotesk Variable', ui-monospace, monospace",
  sans: "'Merriweather', Georgia, serif",

  gradient: 'linear-gradient(180deg, #f4ecdd 0%, #f6dc9a 55%, #dca84b 100%)',
};
