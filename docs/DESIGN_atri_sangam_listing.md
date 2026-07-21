# Design — Atri Sangam on mambakkam.net

**Date:** 2026-07-21
**Status:** Approved, ready for implementation
**Scope:** Add Atri Sangam to the Products listing (`/work`), give it a product
profile page (`/work/atri-sangam`), and add it to Siva's profile
(`/people/siva-m`).

---

## Goal

`atri-sangam` is the eleventh repository in the WeGoFwd2020 portfolio and the
first one that is not an AI product. It is absent from mambakkam.net entirely.
This change lists it as a product, generates its profile page, and works it into
the personal page's "What I'm Building" section without breaking the
shared-engine narrative that section carries.

## Source of truth

Every factual claim on the page is derived from the **live repository at
`ba9c697` (v0.1.7)**, verified on 2026-07-21 — _not_ from
`project-critique/atri-sangam-critique.md`, which is anchored at v0.1.0
(2026-07-18) and is materially stale.

The critique's headline finding — "no runner / scheduler / daemon exists" — was
true at v0.1.0 and is **false today**. Writing the page from the critique would
have published an incorrect maturity claim. Facts verified directly:

| Claim                          | How verified                                                                                                                                 |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 294 tests pass                 | Ran `PYTHONPATH=src python3 -m pytest` → `294 passed in 3.52s`                                                                               |
| Stdlib-only core               | `pyproject.toml:23` → `dependencies = []`                                                                                                    |
| Alpha v0.1.7                   | `pyproject.toml:7,15`                                                                                                                        |
| Runner exists                  | `src/atri_sangam/runner/{cli,monitor,sources,config}.py`; console script `atri-sangam-run`; systemd unit `runner/deploy/atri-sangam.service` |
| Sources                        | `--source sim \| gpsd \| serial` (`runner/cli.py:56`)                                                                                        |
| Channels wired into the daemon | `runner/cli.py:18-26` imports Cn0, Holdover, Ntp, MultiNtp, Roughtime, MultiRoughtime, Wwvb collectors                                       |
| Solar NOT wired                | `runner/cli.py` imports no solar collector; `predictors/solar.py` is used by tests and `demo` only                                           |
| 12 OpenSpec contracts          | `openspec/specs/` directory listing                                                                                                          |
| Dashboard is live, read-only   | `dashboard/app.py:172,176` open the store with `read_only=True`; `dcc.Interval` polls                                                        |
| Repo is private                | `gh repo view wegofwd2020-hub/atri-sangam` → `"isPrivate": true`                                                                             |

## Decisions

1. **Framed as a WeGoFwd2020 product** (`type: product`), listed alongside the
   other products — with one explicit line stating it does _not_ share the
   content-generation engine, so `<SharedEngineDiagram />` is not read as
   covering it.
2. **Maturity stated up front**, in the excerpt itself, not buried in a Status
   section. Follows the Pramana precedent ("in active build — not yet
   deployed") and the site's standing rule against present-tense overselling.
3. **Profile page is the generated `/work/atri-sangam`**, from the single
   markdown file — same pattern as Pramana. No hand-built `.astro` one-pager.
4. **No outbound link.** The repo is private, so `url` is omitted and the body
   states "Source code is private." Nothing on the page 404s for a visitor.
5. **Name section leads with what is attested.** Wikipedia's Atri article
   covers the Saptarishi, the mānasputra origin, the tongue/wisdom symbolism,
   and Mandala 5 being the Atri Mandala — but has **no** Svarbhanu eclipse
   story and no RV 5.40 reference. The site copy therefore leads with the Atri
   Mandala and places hymn 5.40 _within_ it, rather than repeating the
   repository README's unattested "credits him with restoring the Sun".

## §1 — New file: `src/data/work/atri-sangam.md`

Frontmatter (validated by the `work` Zod schema in `src/content/config.ts`):

```yaml
title: Atri Sangam
excerpt: >
  A GPS/PNT integrity monitor for fixed sites. It cross-checks what a GPS
  receiver reports against independent time references and raises an
  explainable alarm when they stop agreeing — jamming, spoofing, or plain
  outage. Alpha: the monitor runs, but its thresholds have not been proven
  against real jamming hardware.
author: siva-m
type: product
status: in-progress
tags: [Python, GNSS, PNT, NMEA, NTP, Roughtime, WWVB, CUSUM, SQLite, Stdlib-only]
featured: false
comingSoon: false
publishDate: 2026-07-21
draft: false
```

`url` omitted (private repo). `image` omitted (no logo asset exists in
`src/assets/images/work/`; the card and detail templates both degrade to
text-only).

Body sections:

1. **What is Atri Sangam** — the sangam thesis: independent channels whose
   disagreement _is_ the signal.
2. **Why the name** — approved copy, leading with the Atri Mandala.
3. **The problem it solves** — a receiver cannot audit itself; a fixed site with
   a surveyed antenna makes position a known truth to check against.
4. **The channels** — table of the residual channels wired into the daemon and
   what each one catches (8 rows: GPS time/position/CN₀ spread, NTP time +
   consensus spread, Roughtime time, WWVB time, holdover residual), with the
   Roughtime consensus-spread and verify-failure channels covered in prose.
5. **How it decides** — step / CUSUM / staleness detector layers; alarms carry
   channel, detector, value, threshold, message.
6. **Architecture** — stdlib-only core, injectable everything, deterministic
   red-team simulator, SQLite or TimescaleDB behind one store interface,
   12 specs, 294 tests.
7. **Status** — alpha v0.1.7; daemon and systemd unit exist; solar and
   star-tracker channels are roadmap; thresholds are consumer-grade defaults
   never validated against real jamming or spoofing hardware; source private.
8. **Not the shared engine** — one line: no LLM anywhere in it.

## §2 — Edit: `src/data/people/siva-m.mdx`

Section "What I'm Building" currently hard-codes three products. Three edits:

- **Intro line** — "each one puts the shaping in the user's hands, not the
  model's" must be scoped, since Atri Sangam has no model.
- **New bullet** — Atri Sangam, linking `/work/atri-sangam`, marked alpha,
  describing it in one sentence.
- **Closing line** — "The products are not three separate builds. They share one
  content-generation engine" must be scoped to the first three, with Atri Sangam
  named as a separate line of work.

`<SharedEngineDiagram />` itself is unchanged; it now sits under copy that says
which three products it covers.

## Out of scope

- No navigation change. "Products" already points at `/work`
  (`src/navigation.ts:23,53`), and the home page only links to `/work`.
- No logo asset. Can be added later by dropping an SVG into
  `src/assets/images/work/` and setting `image:`.
- No dedicated `/atri-sangam` landing page. Revisit if the product reaches the
  visibility of Mentible or Thittam.
- No change to the repository's own README (the stale
  `README.md:287` "Current: **v0.1.0**" line vs `pyproject.toml` `0.1.7`) —
  tracked separately.
- No re-run of the four-lens critique against `ba9c697` — tracked separately.

## Verification

1. `npm run build` — Astro validates the frontmatter against the Zod schema; a
   bad `type`/`status` enum fails the build.
2. Confirm `/work` renders the new card with an amber "In Progress" badge and no
   broken image.
3. Confirm `/work/atri-sangam` renders, with no outbound link element.
4. Confirm `/people/siva-m` reads correctly around the new bullet and that the
   engine claim is scoped to three products.

## Deployment

Merging to `main` deploys mambakkam.net immediately — there is no separate gate.
This work ships as a PR from `feat/atri-sangam-work-entry` and is **not merged
without explicit operator confirmation**.
