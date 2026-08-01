/**
 * Page themes for branded product pages.
 *
 * A branded page (/atri-sangam, /mentible, /kaundinya…) renders through the
 * bare layout with no site chrome and supplies its own palette. Before this
 * module each page carried that palette inline, which was fine for one page
 * and became five copies of the same six colours once the Atri Sangam family
 * grew to a pitch page, a demos index, four replays and a themed work entry.
 *
 * A theme is data. Adding one is a new file here plus a line in `themes`;
 * nothing else changes.
 *
 * Tokens are named for their role, not their hue — `bg`, `accent`, `text` —
 * so a different palette drops into the same slots without renaming anything.
 * `scripts/og/card.css` names its variables the same way and for the same
 * reason.
 */

export interface Theme {
  /** Registry key, and the value a work entry puts in its `theme` field. */
  id: string;
  /** Human name, for documentation and error messages. */
  label: string;

  /** Page background. */
  bg: string;
  /** Raised surface — cards, chips, plates. */
  panel: string;
  /** Hairline borders, rules, dividers. */
  panelHi: string;

  /** The scarce accent: traces, kickers, links. */
  accent: string;
  /** Softer accent, for the current item and secondary emphasis. */
  accentSoft: string;
  /** Primary text. */
  text: string;

  /** Machine voice — headings, readouts, chips. */
  mono: string;
  /** Human prose. */
  sans: string;

  /** The H1 treatment, painted through background-clip: text. */
  gradient: string;

  /* Status colours, for themes whose pages report health. Optional: a theme
     with nothing to alarm about does not need them, and a page that shows
     status falls back to `text` when they are absent. Kept out of the palette
     proper because they are the one place a theme is allowed a second hue —
     an integrity monitor cannot signal ALARM in the same colour as OK. */
  /** Something is wrong and the reader must notice. */
  alarm?: string;
  /** Data is stale or a channel has gone quiet. */
  stale?: string;
}

import { emerald } from './emerald';
import { pine } from './pine';

export const themes = {
  emerald,
  pine,
} satisfies Record<string, Theme>;

export type ThemeId = keyof typeof themes;

/** Every registered id — the work collection validates its `theme` against this. */
export const THEME_IDS = Object.keys(themes) as ThemeId[];

/**
 * Look a theme up by id.
 *
 * Throws rather than falling back to a default: a typo in frontmatter should
 * fail the build, not silently render a page in the wrong palette.
 */
export function themeById(id: string): Theme {
  const theme = (themes as Record<string, Theme>)[id];
  if (!theme) {
    throw new Error(`Unknown theme "${id}". Registered: ${THEME_IDS.join(', ')}.`);
  }
  return theme;
}
