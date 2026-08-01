import type { Theme } from './index';

/**
 * "Emerald Prestige" — Atri Sangam.
 *
 * Deep emerald ground with a scarce gold accent. Dark only, and deliberately
 * not derived from the site's theme tokens: these pages are instrument
 * consoles, and the source design locks the palette (see
 * docs/DESIGN_atri_sangam_demos_index.md, rule 1).
 *
 * Gold is scarce on purpose — traces, kickers, one gradient — and never a
 * fill above ~8% opacity.
 */
export const emerald: Theme = {
  id: 'emerald',
  label: 'Emerald Prestige',

  bg: '#03251c',
  panel: '#0a3d2e',
  panelHi: '#0f5c46',

  accent: '#c9a84c',
  accentSoft: '#f0d78c',
  text: '#f5f0e0',

  mono: "'JetBrains Mono Variable', ui-monospace, monospace",
  sans: "'Work Sans Variable', ui-sans-serif, system-ui, sans-serif",

  gradient: 'linear-gradient(180deg, #f5f0e0 0%, #f0d78c 55%, #c9a84c 100%)',

  // Desaturated rust reads as alarm without fighting the gold; the amber is
  // separable from the accent at chip size. OK deliberately has no colour of
  // its own — on a page where six channels are usually fine, a green OK is the
  // loudest thing on screen and ALARM has to shout over it.
  alarm: '#e06c5a',
  stale: '#d9a441',
};
