# Design — Atri Sangam demos index, in Astro

**Date:** 2026-07-31
**Status:** Approved, ready for implementation
**Scope:** Phase 1 — reimplement `/demos/atri-sangam` (the index of the four
recorded replays) as an Astro page in the "Emerald Prestige" design, replacing
the generated static HTML. Phase 2 (the four replay pages, and dropping Plotly)
is sketched here but is not this change.

**Source design:** `~/Downloads/atri-sangam-demos-index-design.md` — a
typography and layout specification written for hand-off. It targets a stack
this project does not have; see [Stack translation](#stack-translation).

---

## Where the page comes from today

`/demos/atri-sangam` is not authored in this repository. All five pages are
**emitted by Python** in the `atri-sangam` repo and published here as build
output:

| Thing             | Location                                                       |
| ----------------- | -------------------------------------------------------------- |
| Generator         | `atri-sangam/src/atri_sangam/dashboard/export.py` (593 lines)  |
| OG card           | `atri-sangam/src/atri_sangam/dashboard/og_card.py` (232 lines) |
| Published output  | `mambakkam-net/public/demos/atri-sangam/`                      |
| Publishing commit | `d92f8cc deploy(atri-sangam): publish demo from main@3a64f46`  |

Editing `public/demos/atri-sangam/*.html` directly is therefore a trap: the
next `export_demo()` run overwrites it.

## Stack translation

The source design specifies React 19 + TanStack Start/Router + Tailwind v4,
with files at `src/routes/demos.atri-sangam.index.tsx`. Neither repository has
any of that — `atri-sangam` is Python emitting static HTML with Plotly, and
this repo is Astro 5 + Tailwind 3 with no React. Confirmed 2026-07-31 that no
React implementation exists to port from; the page is derived from the spec
text alone.

Three consequences:

1. **The page must live under `src/`.** `tailwind.config.js:6` scopes content
   to `./src/**/*`, so Tailwind never sees `public/`. A spec written entirely
   in Tailwind utilities renders unstyled there. This alone rules out patching
   the current file in place.
2. **No React.** The index is static; the interactive chart belongs to Phase 2
   and will be an Astro component with vanilla JS, not an island.
3. **Tailwind 3 is sufficient.** Every class in the spec exists in v3 —
   `md:col-span-8`, `animate-ping`, `border-l-2`, and the arbitrary values
   `text-[15px]` / `h-[55vh]`. Nothing is v4-only. The palette is inline hex by
   design, so the version gap barely touches this page.

### Contradiction in the source design

§4 links cards to `/work/atri-sangam/demos?scenario=clean`; §8 describes legacy
route files at `demos.atri-sangam.clean[.]html.tsx`. Two URL schemes in one
document. Resolved below in favour of the live URLs.

## Phase 1 — what changes

| Action     | Path                                                                    |
| ---------- | ----------------------------------------------------------------------- |
| New        | `src/pages/demos/atri-sangam/index.astro`                               |
| **Delete** | `public/demos/atri-sangam/index.html`                                   |
| New deps   | `@fontsource-variable/jetbrains-mono`, `@fontsource-variable/work-sans` |
| Other repo | `export.py` stops emitting `index.html`                                 |

The page uses `Layout.astro` — the bare layout (head plus slot, no site header
or footer) already used by `/kaundinya` and `/mentible`. The spec's shell is a
full-bleed `min-h-screen` dark page that supplies its own background, so any
layout with site chrome would fight it.

### Decisions

**1. The output collision must be resolved, not ignored.**
`public/demos/atri-sangam/index.html` and a page at
`src/pages/demos/atri-sangam/index.astro` both write
`dist/demos/atri-sangam/index.html`. One silently wins. The static file is
deleted here — **and `export_demo()` must stop producing it**, or the next
`atri-sangam` release republishes the old file over the new page. That is a
change in the other repo and is the single hard dependency of this plan. Until
it lands, this page is one deploy away from being clobbered.

**2. Fonts via `@fontsource`, not a Google `<link>`.**
The spec loads JetBrains Mono and Work Sans with a `<link>` in the route head.
This repo self-hosts every face (`@fontsource/merriweather`,
`@fontsource-variable/space-grotesk`); a Google Fonts link would be the only
third-party request on the site. The spec's real constraint — never `@import`
in CSS — is met.

Both faces use the **variable** packages (verified on npm 2026-07-31, both at
`5.3.0`). The spec calls for weights 300, normal, 500 and bold across the two
families; one variable file per family covers all of them, where the static
packages would need six separate weight files.

**3. Cards link to the existing `.html` replays.**
`/demos/atri-sangam/clean.html` and its three siblings are live and shareable
today. The `?scenario=` scheme arrives in Phase 2 alongside the pages that
serve it, at which point the `.html` paths redirect.

**4. `og:site_name` stays `Mambakkam`.**
The spec says `Kaundinya Labs`. `/kaundinya` overrides the site name
deliberately because that page is the company; a demo hosted on mambakkam.net
is not. The existing `og-card-v1.png` is kept — `og_card.py` generates it from
real alarm data, which beats a decorative card.

### What is preserved verbatim

Copy is unchanged from the live page — eyebrow, Rig Veda 5.40.9 epigraph and
translation, preamble, the four scenario blurbs, and all eleven glossary rows
already match the spec's §6 text exactly. **This is a visual and interaction
redesign, not a content change**, which keeps the factual risk near zero.

The spec's own §9 rules are adopted as written: hard-coded palette (no theme
tokens, dark-only), mono for machine voice and sans for prose, square borders
with hairline rules and no shadows, gold kept scarce and never filled above
~8% opacity, the "Recorded replay — simulated data only" chip mandatory, and
`preserveAspectRatio="none"` on every chart path.

## Phase 2 — not this change

`export.py` stops emitting HTML and emits **JSON per scenario** (residual
series per channel). The four replays become Astro pages rendering a
`ResidualChart` Astro component with vanilla JS — hover crosshair, tooltip and
expand modal, per spec §7. Then `plotly.min.js` and the four generated `.html`
files are deleted.

That is **4.7 MB of the 5.1 MB** currently in `public/demos/atri-sangam/`.

The split works because of a data dependency, not a page count: the index needs
no simulator output at all — spec §4 hardcodes every sparkline as a literal SVG
path — while the replays render real simulated residuals. The index is
therefore portable today and the replays are not, until the generator is
refactored from a page producer into a data producer.

## Risks

| Risk                                                          | Mitigation                                                                     |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Next `atri-sangam` release republishes `index.html`           | Land the `export.py` change before the next release; it is the hard dependency |
| Phase 1 ships a style seam — Emerald index, old-style replays | Accepted, and temporary. Phase 2 closes it                                     |
| Two font families added for one page                          | Self-hosted and scoped to this route; no effect on other pages' payload        |

## Verification

- `npm run check` — astro check, eslint, prettier all clean
- `npm run build` — page renders at `dist/demos/atri-sangam/index.html`
- Confirm exactly one file writes that path (no `public/` shadow remains)
- Confirm the four card links resolve 200 against the live `.html` replays
- Confirm `src/data/work/atri-sangam.md:174` (`/demos/atri-sangam/`) still lands
