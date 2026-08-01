# Page themes

**Live console:** [mambakkam.net/themes](https://mambakkam.net/themes) — every
registered theme with its swatches, and which product carries which.

A **theme** is the palette and type a branded page wears: dark ground, its own
accent, its own fonts. Themes are data, in `src/themes/`. Adding one is a file
plus a registry line; applying one is a frontmatter field or a page import.

---

## Changing which product uses which theme

The site is a static build — there is no admin that saves. A theme change is a
**file edit** that reaches production the way every change does: commit, CI,
merge.

```bash
npm run dev                 # → http://localhost:4321/themes
```

On that page in dev, each work entry has a dropdown. Changing it rewrites the
`theme:` field in `src/data/work/<slug>.md` — exactly the edit you would make
by hand.

```bash
git diff                    # review what changed
npm run theme:publish       # branch, commit, push, open a PR
```

Then merge the PR. **Merging deploys mambakkam.net**, so that step stays
manual.

`theme:publish` refuses to run if anything outside `src/data/work/` has
changed, so the PR carries theme assignments and nothing else. Use
`npm run theme:publish -- --dry-run` to see what it would do.

### Editing by hand instead

Nothing about the editor is required. Open the file and set the field:

```yaml
---
title: Pramana
status: in-progress
theme: emerald # ← any registered id, or delete the line for none
---
```

### Why not an admin that just saves

`theme:` is validated against the registry when the site builds —
`themeById()` throws on an unknown id — so a typo fails CI instead of
rendering a live page in the wrong palette. A database-backed admin would
apply the change instantly and find the problem in production. The commit is
what buys the check.

Two limits worth knowing: the editor only works where the repo is checked out,
and nothing is live until the PR is merged.

---

## Adding a theme

1. Copy an existing file in `src/themes/` — `emerald.ts` or `azure.ts`.
2. Register it in `src/themes/index.ts`:

```ts
import { azure } from './azure';
import { emerald } from './emerald';
import { midnight } from './midnight'; // ← new

export const themes = {
  azure,
  emerald,
  midnight, // ← new
  pine,
} satisfies Record<string, Theme>;
```

That is the whole change. `THEME_IDS` feeds the work-collection schema, so the
new id becomes selectable in frontmatter and in the console automatically. No
edit to `theme.css`, `ThemeStyle.astro`, or any page.

### Naming tokens

Tokens are named for **role**, not hue:

| Token        | Role                                            |
| ------------ | ----------------------------------------------- |
| `bg`         | page ground                                     |
| `panel`      | raised surface — cards, chips, chart plates     |
| `panelHi`    | hairlines, rules, dividers, card borders        |
| `accent`     | the scarce accent — traces, kickers, links      |
| `accentSoft` | secondary accent, current item                  |
| `text`       | primary text                                    |
| `mono`       | machine voice — headings, readouts, chips       |
| `sans`       | human prose                                     |
| `gradient`   | the H1 treatment, via `background-clip: text`   |
| `alarm`      | optional — something is wrong                   |
| `stale`      | optional — data is stale or a channel is silent |

This is what makes a second theme cheap. Azure inverts what `panelHi` _looks_
like — gold drawn lines where Emerald has a receding seam — and still needed no
change to any structural class, because the token means "hairlines and rules"
rather than "lighter green".

---

## Applying a theme to a page

Two ways, depending on what the page is.

**A work entry** (`/work/<slug>`) sets the field. `src/pages/work/[slug].astro`
switches to the bare layout when a theme is present.

**A branded page** imports it directly:

```astro
---
import Layout from '~/layouts/Layout.astro';
import ThemeStyle from '~/components/ThemeStyle.astro';
import ThemeNav from '~/components/ThemeNav.astro';
import { themes } from '~/themes';

const t = themes.emerald;
const { panel: PANEL, panelHi: PANEL_HI, accent: GOLD, text: TEXT } = t;
---

<Layout metadata={metadata}>
  <ThemeStyle theme={t} />
  <div class="th-page w-full px-6 py-12 md:px-10 md:py-16">
    <ThemeNav current="/your-page" />
    <h1 class="th-h1 text-5xl">Title</h1>
  </div>
</Layout>
```

`ThemeStyle` emits the tokens as `--th-*` custom properties and pulls in
`theme.css`. Inline `style={...}` can read the destructured values directly —
SVG attributes need real values, since they cannot read custom properties.

### Why themed pages use the bare layout

`PageLayout` supplies the site's cream header. A dark body beneath it reads as
a broken page rather than a deliberate one. The cost is losing the site nav,
which is why `ThemeNav` exists — it renders the header links from
`headerData`, styled from the active theme, so a change to the site nav reaches
themed pages too.

### Shared classes

From `src/themes/theme.css`, all driven by the active theme's tokens:

`th-page` · `th-h1` · `th-eyebrow` · `th-kicker` · `th-kicker-md` ·
`th-caption` · `th-chip` · `th-cite` · `th-readout` · `th-readout-stack` ·
`th-status` · `th-thead` · `th-card` · `th-navpill` · `th-nav`

Sizes under 12px and letter-spacing in `em` sit outside Tailwind's scale, which
is why these are CSS rather than utilities.

---

## Files

| Path                              | What                                        |
| --------------------------------- | ------------------------------------------- |
| `src/themes/index.ts`             | `Theme` type, registry, `themeById()`       |
| `src/themes/<id>.ts`              | one theme                                   |
| `src/themes/theme.css`            | structural classes on `var(--th-*)`         |
| `src/components/ThemeStyle.astro` | emits a theme's tokens                      |
| `src/components/ThemeNav.astro`   | site nav for pages with no header           |
| `src/pages/themes.astro`          | the console                                 |
| `integrations/theme-editor.ts`    | dev-only middleware that writes frontmatter |
| `scripts/themes/publish.sh`       | `npm run theme:publish`                     |

The editor is a Vite dev-server middleware, not a route. The site is
`output: 'static'` with no adapter, so a POST endpoint cannot exist in a build
— a route under `src/pages/` would either fail the build or ship a dead file.
Registered on `astro:server:setup`, it has no build-time existence at all: the
built page contains zero `<select>` elements, and `POST /__theme-editor` 404s
in production.

---

## Not yet migrated

`kaundinya.astro`, `mentible.astro`, `thittam.astro` and
`kathai-chithiram.astro` still carry their palettes inline. `pine` is
registered from Kaundinya's values but not applied, so those two are copies
until that page is migrated — the console's "Branded pages" table shows this.
Migrate a page when you next touch it, and drop the note in `src/themes/pine.ts`.
