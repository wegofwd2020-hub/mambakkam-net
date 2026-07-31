# Design — Atri Sangam replay pages, in Astro (Phase 2)

**Date:** 2026-07-31
**Status:** Awaiting review
**Scope:** Move the four replay pages (`clean`, `time-walk`, `position-jump`,
`dropout`) from generated Plotly HTML to Astro pages in the "Emerald Prestige"
design, driven by real simulator output exported as JSON. Deletes
`plotly.min.js`.

Phase 1 (the index) shipped in
[`#102`](https://github.com/wegofwd2020-hub/mambakkam-net/pull/102); see
[DESIGN_atri_sangam_demos_index.md](DESIGN_atri_sangam_demos_index.md).

---

## Why this is not a restyle

The source design (`~/Downloads/atri-sangam-demos-index-design.md`) is titled
_Demos Index Page_. It specifies a `ResidualChart` **component** — props, hover
maths, expand modal — but no layout for the replay pages themselves. The
sections below are new design, not translation.

## What a replay page contains today

| Section                       | Source                                                         |
| ----------------------------- | -------------------------------------------------------------- |
| Replay banner                 | `_BANNER`                                                      |
| Scenario nav                  | `_NAV` — four scenarios plus Index                             |
| H1 + lede                     | scenario name, `_CAPTIONS`                                     |
| Status hero                   | `OK` / `ALARM`, and "last agreed _n_ s before the end"         |
| Six status pills              | one per channel, `channel: OK`                                 |
| "GPS vs the assembly"         | GPS trace against the consensus band                           |
| Six channel charts            | series, target line, dotted threshold bands                    |
| "What each chart shows"       | `doc_for(channel)` — Variable / Source / Description / Formula |
| "How every channel is judged" | `DETECTOR_DOCS` — step / cusum / staleness × Rule × Source     |

Channels: `gps_time_offset`, `ntp_time_offset`, `roughtime_time_offset`,
`gps_position_error`, `gps_cn0_spread`, `glonass_cn0_spread`.

## Decision: real series, not authored paths

Spec §7's chart takes `d` — an SVG path — and derives tooltip values from the
path's own y-coordinates (`(scale.base − point.y) * scale.scale`). That is a
hand-authored trace with a declared axis meaning. Adopting it literally would
put invented data on a page that says:

> Thresholds are per channel and are the ones the daemon **actually applied** —
> the dotted bands on each chart are **drawn from them**.

So the component is changed to take **data**, not a path, and the inverse
mapping disappears: the tooltip reads the sample it is pointing at.

This costs almost nothing. The 4.7 MB is Plotly the library, not the data — the
series is roughly 21 KB per page. Fidelity and the payload win are not in
tension.

## The JSON contract

`export.py` gains a JSON mode. One file per scenario, `<scenario>.json`:

```jsonc
{
  "scenario": "clean",
  "generatedAt": "2026-07-31T19:00:00Z",
  "caption": "This is what a healthy fixed site looks like…",
  "status": "OK",                    // OK | ALARM
  "lastAgreedS": 0,                  // seconds before the end
  "windowS": 300,
  "channels": [
    {
      "name": "gps_time_offset",
      "unit": "ms",
      "status": "OK",                // OK | ALARM | STALE
      "target": 0.0,
      "thresholds": { "upper": 0.05, "lower": -0.05 },
      "doc": { "variable": "…", "source": "…", "description": "…", "formula": "…" },
      "samples": [[t, v], …]         // t = seconds before the end, v = value
    }
  ],
  "consensus": { "samples": [[t, lo, hi], …], "gps": [[t, v], …] },
  "detectors": [["step", "alarm when …", "discrepancy/step.py:31"], …]
}
```

Notes:

- **`t` is seconds before the end, not a wall-clock timestamp.** A replay has no
  meaningful absolute time, and relative time is what the tooltip shows
  (`T−60s`). It also keeps the file stable between exports, so re-publishing
  does not churn the diff.
- **Thresholds and detector rows travel with the data**, so the sentence quoted
  above stays true without the page hard-coding anything.
- `doc` is inlined per channel rather than duplicated in the site, because
  `docs_registry.py` is the authority and a copy here would drift.

Standalone HTML export is unaffected. JSON is an additional mode, the same way
`--no-index` was an additional flag — a `--out <dir>` export still produces a
self-contained demo site for anyone not publishing to mambakkam.net.

## Page layout — Emerald Prestige

Reuses Phase 1's shell verbatim: `min-h-screen` on `BG`, `max-w-6xl`, `gap-12`
between sections, hairline `PANEL_HI` rules, square corners, mono for machine
voice and sans for prose.

1. **Top bar** — breadcrumb `Atri Sangam / Demos / Clean`, and the mandatory
   "Recorded replay — simulated data only" chip. Rule 5 of the source design.
2. **Scenario nav** — four pills plus Index, current one filled `PANEL_HI` with
   `GOLD_SOFT` text, the rest bordered. Replaces today's blue tab strip.
3. **Header** — eyebrow (scenario kind, e.g. `SLOW SPOOF`), H1 in the gradient,
   lede in sans at `CREAM e6`.
4. **Verdict band** — a bordered strip, not a coloured hero. Left: status word
   in mono at `text-4xl`. Right: `LAST_AGREED: T−0s` as a machine readout. Full
   width, `border` on `PANEL`.
5. **Channel status row** — six chips, mono `10px`, uppercase.
6. **Headline chart** — "GPS vs the assembly", `h-64` plate, consensus band as a
   filled region at 8 % `GOLD`, GPS trace at 1.5 stroke.
7. **Channel grid** — `md:grid-cols-2`, one card per channel: name + status chip,
   `h-40` plate with target line and dotted threshold bands, and the
   Variable / Source / Description / Formula block beneath as a `dl`.
8. **Detectors** — the three-row table, styled like Phase 1's glossary.
9. **Footer** — About / Source code, matching Phase 1.

"What each chart shows" stops being a separate section: each channel's
documentation moves into that channel's own card, next to the chart it
explains. Today they are far apart and the reader has to hold six chart shapes
in their head while scrolling to the prose.

### Status colour — a sanctioned exception

Source design rule 4 keeps gold scarce and forbids gold fills above ~8 %. It
says nothing about alarm states, because the index has none.

An integrity monitor cannot signal `ALARM` in the same colour as `OK`. Two
semantic colours are added and used **only** for status words, chips and the
verdict band:

```
ALARM #e06c5a   (desaturated rust — reads as alarm without fighting the gold)
STALE #d9a441   (amber, distinct from GOLD's #c9a84c at chip size)
```

`OK` stays `CREAM`, not green: on a page where six chips are usually all fine,
green would be the loudest thing on screen and alarm would have to shout over
it. Absence of colour reads as nominal; colour means attention. This inverts
today's page, where `OK` is bright green.

## Chart component

`src/components/atri-sangam/ResidualChart.astro`. Props:

| Prop             | Meaning                                         |
| ---------------- | ----------------------------------------------- |
| `samples`        | `[t, v]` pairs                                  |
| `band`           | optional `[t, lo, hi]` for the consensus region |
| `target`         | horizontal reference line                       |
| `thresholds`     | `{upper, lower}`, drawn dotted                  |
| `unit`, `digits` | tooltip formatting                              |
| `height`         | plate height class                              |
| `label`          | plate caption, bottom-right                     |

Rendering is server-side SVG — the polyline is computed at build time, so the
page paints with no JavaScript. A single small inline script per page adds
hover: nearest-sample snap, vertical crosshair, dot, and a mono tooltip reading
`«value unit» · T−«n»s`. Values come from `samples`; nothing is derived from
drawing coordinates.

`preserveAspectRatio="none"` is kept, per rule 6.

The expand modal from spec §7 is **deferred**. It is the only part needing real
interaction state, it doubles the script, and a `h-40` plate on a `max-w-6xl`
page is already legible. Revisit if the charts prove too small in use.

## URLs

Canonical becomes extension-less:

| Old                             | New                        |
| ------------------------------- | -------------------------- |
| `/demos/atri-sangam/clean.html` | `/demos/atri-sangam/clean` |

The `.html` paths are live and shareable, and the OG card points at them, so
they must not 404. `astro.config` `redirects` emits meta-refresh stubs at the
old paths. The Phase 1 index is updated to link the new URLs.

`?scenario=` from source design §4 is **not** adopted — four static pages are
simpler than one page branching on a query string, and they let each replay
carry its own OG metadata.

## Deletions

Once the pages render from JSON:

| File                                          | Size    |
| --------------------------------------------- | ------- |
| `public/demos/atri-sangam/plotly.min.js`      | 4.7 MB  |
| `public/demos/atri-sangam/{4 scenarios}.html` | ~290 KB |

`og-card-v1.png` stays — the four new pages reference it until per-scenario
cards exist.

## Risks

| Risk                                                     | Mitigation                                                                                                     |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Hand-rolled charts lose Plotly's zoom and pan            | Accepted. These are fixed-window replays, not exploratory plots; hover readout is the affordance that mattered |
| JSON committed to this repo can drift from the simulator | `generatedAt` in each file, and the export command documented in the README beside `--no-index`                |
| Six charts per page in SVG could be heavy                | ~21 KB of series per page against 4.7 MB removed; server-rendered, no client charting library                  |
| Two new semantic colours weaken the locked palette       | Confined to status words, chips and the verdict band; never applied to traces, rules or type                   |

## Verification

- `npm run check`, `npm run build`
- Each of the four pages renders every channel present in its JSON
- Threshold bands on the page match `thresholds` in the JSON
- `.html` redirect stubs resolve to the new URLs
- `plotly.min.js` absent from `dist`
- Total `dist/demos/atri-sangam/` size reported before and after
