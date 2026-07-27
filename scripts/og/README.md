# og:image cards

Link-preview cards for WhatsApp, iMessage, Slack and Facebook. Each card is an
HTML file; `render.mjs` shoots it with headless Chrome and writes a 1200x630 PNG
into `src/assets/`.

```
npm run og              # render every card
npm run og mentible     # render just cards/mentible.html
npm run og -- --check   # report drift, write nothing (exit 1 if any card differs)
```

## Why HTML and not an image editor

The cards have to use the site's own Merriweather and the village palette. Hand-
placed pixels cannot, they drift from the brand the moment a colour changes, and
every future edit means reopening a binary instead of reading a diff. `card.css`
holds the house style — dark ground, thin inset frame with a dot at each corner,
a rule with dots, a gradient statement line, a muted sub — lifted from
`src/pages/kaundinya.astro`, which is where the look actually originates.

A card overrides only its own custom properties: `--ground`, `--accent`,
`--wordmark`, `--statement`, `--sub`, the frame and rule colours, and optionally
`--mark-blur`.

## Adding a card

1. Copy `cards/mentible.html` and rewrite the `.card` custom properties, the
   brand block and the three lines of copy.
2. Point `<meta name="og-out">` at the destination under `src/assets/`. The HTML
   is self-describing on purpose — there is no second registry to fall out of
   sync with.
3. `npm run og <name>`.
4. Wire it into the page, importing the asset rather than referencing a
   `public/` path:

   ```js
   // in the page's frontmatter
   import ogImage from '~/assets/images/work/your-card.png';

   const metadata = {
     openGraph: { images: [{ url: ogImage }] },
   };
   ```

   `adaptOpenGraphImages()` in `src/components/common/Metadata.astro` runs the
   value through Astro's image service, which treats a bare public path as a
   remote image and then fails for want of intrinsic dimensions.

Pages without their own card inherit `default.png` via `openGraph.images` in
`src/config.yaml`.

## Things that will bite

**Re-rendering invalidates every cached preview.** Changing the PNG changes
Astro's content hash, which changes the `og:image` URL. WhatsApp does not crawl
the site — it reads Facebook's cache — so after any deploy that moves a card you
must re-scrape each affected URL in the
[Sharing Debugger](https://developers.facebook.com/tools/debug/) and click
**Scrape Again**. That needs a logged-in Facebook account. A second, separate
on-device WhatsApp cache survives even that; appending `?v=2` to the URL bypasses
both and is the fastest way to prove a change actually shipped.

Run `--check` before re-rendering. It tells you whether anything really moved,
so you do not invalidate live previews for a no-op.

**Fonts load over `file://`.** `card.css` reaches into `node_modules/@fontsource`
with relative paths, so `npm ci` must have run. The `--virtual-time-budget` flag
in `render.mjs` is what stops Chrome shooting the frame before the faces land and
silently baking in a fallback.

**Tamil needs naming.** Merriweather has no Tamil coverage. `default.html` sets
`font-family: 'Noto Serif Tamil'` on the Tamil line; without it the text falls
back to a sans and the pairing breaks with no error.

**Rendered at 2x, downscaled.** Chrome hints glyphs to the device pixel grid, so
a straight 1x shot of 25px text is visibly softer than a 2x shot resampled down.

## Requirements

Chrome or Chromium on `PATH` (`google-chrome`, `google-chrome-stable`,
`chromium`, `chromium-browser`), or `CHROME=/path/to/binary`. `sharp` is already
a project dependency.
