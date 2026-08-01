import type { Theme } from './index';

/**
 * Deep blue ground, gold lines — the products listing.
 *
 * The gold is the same family as Emerald's and Kaundinya's, deliberately: it
 * is the thread running through the whole portfolio. What changes is the
 * ground under it.
 *
 * `panelHi` is the one real departure. In Emerald the hairlines are a lighter
 * shade of the ground, so they recede; here they are gold, so the rules and
 * card edges read as drawn lines rather than as seams. That is the whole look
 * — blue field, gold lines — and it is why this is a separate theme rather
 * than Emerald with the hue rotated.
 */
export const azure: Theme = {
  id: 'azure',
  label: 'Azure & Gold',

  bg: '#071b2e',
  panel: '#0f2a45',
  panelHi: '#7a6630',

  accent: '#d4af4f',
  accentSoft: '#f2dc9b',
  // Cooler than Emerald's cream: a warm off-white goes muddy on navy.
  text: '#eef3f8',

  mono: "'JetBrains Mono Variable', ui-monospace, monospace",
  sans: "'Work Sans Variable', ui-sans-serif, system-ui, sans-serif",

  gradient: 'linear-gradient(180deg, #eef3f8 0%, #f2dc9b 55%, #d4af4f 100%)',
};
