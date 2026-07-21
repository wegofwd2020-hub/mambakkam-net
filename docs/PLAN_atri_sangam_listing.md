# Atri Sangam Site Listing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** List Atri Sangam as a WeGoFwd2020 product on mambakkam.net — a card on `/work`, a generated profile page at `/work/atri-sangam`, and a bullet on `/people/siva-m` — without breaking the shared-engine narrative the personal page carries.

**Architecture:** Astro content collections. A single markdown file in `src/data/work/` is the source for BOTH the listing card (`src/pages/work/index.astro`) and the detail page (`src/pages/work/[slug].astro`). The personal page (`src/data/people/siva-m.mdx`) is hand-written prose and is edited separately. No new components, no new routes, no navigation change.

**Tech Stack:** Astro 5, content collections with Zod schema validation (`src/content/config.ts`), Tailwind, MDX for the people collection.

**Spec:** `docs/DESIGN_atri_sangam_listing.md`

## Global Constraints

- **Source of truth is the live `atri-sangam` repo at `ba9c697` (v0.1.7), verified 2026-07-21.** Do NOT take facts from `project-critique/atri-sangam-critique.md` — it is anchored at v0.1.0 and its headline finding ("no runner or daemon exists") is false as of v0.1.7.
- **No outbound link to the code.** `gh repo view wegofwd2020-hub/atri-sangam` → `"isPrivate": true`. Omit the `url:` frontmatter field entirely. The body states "Source code is private."
- **No `image:` field.** No logo asset exists in `src/assets/images/work/`. Both the card and the detail template degrade to text-only.
- **No present-tense overselling.** Anything not wired into the daemon (solar channel, star-tracker) must be described as roadmap, not capability.
- **Frontmatter `type` and `status` must be schema enum values** — `type: product`, `status: in-progress`. Any other string fails the build.
- **Verbatim copy blocks below are approved wording.** Use them exactly; do not paraphrase, re-order, or "improve" them.
- **Do NOT merge to `main`.** Merging deploys mambakkam.net immediately with no separate gate. Push the branch and stop.

---

## File Structure

| File                           | Responsibility                                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `src/data/work/atri-sangam.md` | **Create.** Frontmatter drives the `/work` card; body renders as `/work/atri-sangam`.                                                |
| `src/data/people/siva-m.mdx`   | **Modify** lines 142–157 only. Adds the product bullet; scopes two claims that currently hard-code "three products" and "the model". |

Both tasks are independently reviewable: Task 1 can ship without Task 2 (the product is listed, the profile just doesn't mention it), and a reviewer could reject the profile copy while accepting the product page.

---

### Task 1: Product entry and profile page

**Files:**

- Create: `mambakkam-net/src/data/work/atri-sangam.md`
- Test: no unit-test framework for content; verification is `npm run build` (Zod schema validation) plus assertions against the generated HTML in `dist/`.

**Interfaces:**

- Consumes: the `work` collection schema at `src/content/config.ts:154-178` — required fields are `title`, `excerpt`, `author`, `type`; `status` defaults to `live`, `featured`/`comingSoon`/`listed`/`draft` are booleans.
- Produces: route `/work/atri-sangam` and collection id `atri-sangam`, which Task 2's profile bullet links to. The `author: siva-m` value must match the people-collection file id `siva-m`, or the card is filtered out of `/work` entirely (`src/pages/work/index.astro:13`).

- [ ] **Step 1: Write the file**

Create `src/data/work/atri-sangam.md` with exactly this content:

```markdown
---
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
tags:
  - Python
  - GNSS
  - PNT
  - NMEA
  - NTP
  - Roughtime
  - WWVB
  - CUSUM
  - SQLite
  - Stdlib-only
featured: false
comingSoon: false
publishDate: 2026-07-21
draft: false
---

## What is Atri Sangam?

**Atri Sangam** is a GPS/PNT integrity monitor for a fixed site — a building,
a tower, a substation — whose antenna position has been surveyed once and is
thereafter treated as truth.

A GPS receiver cannot audit itself. Asked what time it is and where it is, it
answers confidently whether or not anyone is lying to it. So Atri Sangam does
not ask one source. It runs several independent channels — satellite, network
time, cryptographically signed time, radio time, the drift of the local clock
itself — and watches for the moment they stop agreeing. The disagreement is
the signal.

## Why the name

Atri (अत्रि) is one of the Saptarishi, born of Brahma's mind; the
Brihadaranyaka Upanishad has him symbolize the tongue — wisdom, and knowledge
of the Vedas. The fifth Mandala of the Rigveda is called the Atri Mandala in
his honour, and it is there, in hymn 5.40, that the sky's most trusted
reference goes dark — the eclipse of Svarbhanu — and is understood rather
than merely feared.

Sangam (சங்கம்) is confluence and assembly: rivers meeting, and the classical
Tamil academies where independent voices reached consensus by collective
judgment. That is the architecture — a sangam of independent channels
deliberating over what the sky and the clocks are really saying.

## The problem it solves

GPS is infrastructure that almost everything else quietly depends on, and it
is easy to attack. Jamming drowns the signal. Spoofing is worse: the receiver
keeps reporting a confident fix, and the fix is a lie. Both are cheap. Neither
announces itself.

The defence is not a better receiver — it is a second opinion that does not
come from the same sky. Atri Sangam's premise is that a site which already
knows where it is can check what it is being told.

## The channels

Each channel is a residual — an observed value minus what it should be — fed
into one engine. Only the GPS channels come from the satellite constellation;
the rest are deliberately independent of it.

| Channel                 | What it measures                                        | What it catches                                                       |
| ----------------------- | ------------------------------------------------------- | --------------------------------------------------------------------- |
| `gps_time_offset`       | GPS-reported UTC minus the local clock                  | Time spoofing, receiver faults                                        |
| `gps_position_error`    | Distance of the reported fix from the surveyed site     | Position spoofing, multipath                                          |
| `gps_cn0_spread`        | Spread of per-satellite signal strength                 | Spoofing tell — a single transmitter collapses the spread toward zero |
| `ntp_time_offset`       | Network time minus the local clock                      | Independent time cross-check                                          |
| `ntp_consensus_spread`  | Widest disagreement among several NTP servers           | A minority of lying time servers                                      |
| `roughtime_time_offset` | Ed25519-signed time minus the local clock               | Time reference an attacker cannot forge without the key               |
| `wwvb_time_offset`      | WWVB 60 kHz radio time minus the local clock            | Terrestrial time, no network needed                                   |
| `holdover_residual`     | Observed offset minus the local clock's own drift model | Slow manipulation that tracks nothing real                            |

NTP consensus uses Marzullo interval intersection, so a Byzantine minority of
servers is both out-voted and flagged. Roughtime consensus works the same way,
and additionally reports how many servers failed cryptographic verification.

## How it decides

Three detector layers, because the attacks come in three shapes:

- **Step** catches jumps — crude spoofing, receiver glitches.
- **CUSUM** catches slow walks that never trip a step threshold — the patient
  version of the same attack.
- **Staleness** catches silence — jamming, an outage, a dead feed.

Every alarm carries its provenance: which channel, which detector, the value,
the threshold it crossed, and a message. An operator sees an explainable
event, not a red light.

A monitor that invents readings is worse than none, so a failed collector
raises a typed exception and a void GPS fix produces nothing at all — the
silence is then caught by the staleness detector rather than papered over with
a fabricated zero.

## Architecture

The core has **no third-party dependencies** — `dependencies = []`, standard
library only. Everything external is injected: sockets, clocks, serial ports
and stores are constructor parameters, which is what makes the whole suite
deterministic and runnable offline.

- **Daemon:** `atri-sangam-run`, reading from a simulator, `gpsd`, or a serial
  port, with a systemd unit for deployment
- **Storage:** SQLite by default, TimescaleDB behind the same interface
- **Dashboard:** an optional Dash app that opens the store read-only — health
  pills, residual strips, event log
- **Red-team simulator:** deterministic by seed, generating jamming, spoofing
  and drift scenarios, so thresholds can be tested against the attack they are
  meant to catch
- **Specification:** 12 contracts with concrete numeric scenarios, mirrored by
  the tests — 294 of them, all passing

## Status

Alpha, `v0.1.7`. The monitor runs: the daemon, the detection layers, the
storage and the dashboard are built and tested, and the independent time
channels — NTP consensus, Roughtime, WWVB — are wired in and opt-in per site.

What is honestly not done: the solar channel exists as a predictor but is not
yet wired into the daemon, and the star-tracker channel is a roadmap idea. The
default thresholds are consumer-grade starting points, meant to be overridden,
and have not been validated against real jamming or spoofing hardware. Treat
them as a place to begin tuning, not as a calibrated defence.

Source code is private.

## A different line of work

Atri Sangam shares no code and no thesis with the other products here. There
is no language model anywhere in it — nothing is generated, nothing is
inferred. It is arithmetic on residuals, and the reason it can be trusted is
that you can read every step of it.
```

- [ ] **Step 2: Run the build — this is the schema test**

```bash
cd mambakkam-net && npm run build
```

Expected: build succeeds. Astro validates the frontmatter against the `work`
Zod schema at build time, so a bad `type`/`status` enum, a missing `excerpt`,
or a malformed date fails here with a `[InvalidContentEntryDataError]` naming
`atri-sangam`.

- [ ] **Step 3: Assert the page was generated and says the right things**

```bash
cd mambakkam-net
test -f dist/work/atri-sangam/index.html && echo "PAGE OK"
grep -c "Atri Mandala" dist/work/atri-sangam/index.html
grep -c "Source code is private" dist/work/atri-sangam/index.html
grep -c "atri-sangam" dist/work/index.html
grep -o "github.com/wegofwd2020-hub/atri-sangam" dist/work/atri-sangam/index.html | wc -l
```

Expected: `PAGE OK`; the three `grep -c` calls each return `1` or more; the
final count is **`0`** — there must be no link to the private repo.

- [ ] **Step 4: Assert the card renders as In Progress with no broken image**

```bash
cd mambakkam-net && npm run preview
```

Open `http://localhost:4321/work`. Expected: an "Atri Sangam" card with a
`PRODUCT` type label and an amber **In Progress** badge, no image placeholder
or broken-image icon, linking to `/work/atri-sangam`. Then open that page and
confirm it renders with no logo block and no outbound link button. Stop the
preview server.

- [ ] **Step 5: Formatting gate**

```bash
cd mambakkam-net && npm run check:prettier
```

Expected: pass. If it flags `src/data/work/atri-sangam.md`, run
`npx prettier -w src/data/work/atri-sangam.md` and re-run the check. Do not
run the repo-wide `npm run fix` — it would reformat unrelated files into this
commit.

- [ ] **Step 6: Commit**

```bash
cd mambakkam-net
git add src/data/work/atri-sangam.md
git commit -m "feat(work): add Atri Sangam product entry and profile page

Lists atri-sangam on /work and generates its profile page at
/work/atri-sangam from the work content collection — the same
single-markdown-file pattern Pramana uses.

Every claim is derived from the live repo at v0.1.7 (verified
2026-07-21), not from the project-critique review, which is anchored
at v0.1.0 and whose headline finding (no runner or daemon) is now
false. Status copy is explicit about what is genuinely not done: the
solar channel is unwired, the star-tracker is roadmap, and the default
thresholds have never met real jamming hardware.

No url field — the repo is private, so nothing on the page 404s for a
visitor. No image field — no logo asset exists yet."
```

---

### Task 2: Profile bullet and scoped engine claim

**Files:**

- Modify: `mambakkam-net/src/data/people/siva-m.mdx:142-157`
- Test: verification is `npm run build` plus assertions against `dist/people/siva-m/index.html`.

**Interfaces:**

- Consumes: route `/work/atri-sangam`, produced by Task 1. If Task 1 has not landed, this bullet links to a 404.
- Produces: nothing other tasks depend on. This is the last task.

**Why two lines must change, not just an addition:** the section currently
hard-codes the product count and assumes every product has a model in it.
Line 142 says "each one puts the shaping in the user's hands, **not the
model's**" — Atri Sangam has no model. Line 156 says "The products are not
**three** separate builds. They share one content-generation engine" — which
would silently absorb Atri Sangam into a shared-engine claim that is false,
and `<SharedEngineDiagram />` sits directly beneath it.

- [ ] **Step 1: Scope the section intro**

Replace line 142 exactly:

```markdown
Products under WeGoFwd2020 — each one puts the shaping in the user's hands, not the model's:
```

with:

```markdown
Products under WeGoFwd2020. The first three put the shaping in the user's hands, not the model's; the fourth has no model in it at all:
```

- [ ] **Step 2: Add the bullet**

Insert after line 154 (the StudyBuddy OnDemand bullet, ending
`[Live demo](https://demo.usestudybuddy.com).`) and before the blank line
preceding "The products are not three separate builds":

```markdown
- **[Atri Sangam](https://mambakkam.net/work/atri-sangam)** — _alpha._ A
  GPS/PNT integrity monitor for fixed sites: it cross-checks a GPS receiver
  against independent time references — network, cryptographic, radio, and the
  drift of the local clock — and raises an explainable alarm when they stop
  agreeing. Jamming and spoofing are cheap; a confident wrong answer is the
  dangerous one.
```

- [ ] **Step 3: Scope the shared-engine claim**

Replace lines 156-157 exactly:

```markdown
The products are not three separate builds. They share one content-generation
engine — proven first in Mentible, then reused across the others.
```

with:

```markdown
The first three are not separate builds. They share one content-generation
engine — proven first in Mentible, then reused across the others. Atri Sangam
is a different line of work entirely: no language model, no generation, just
arithmetic on residuals that anyone can check.
```

`<SharedEngineDiagram />` on line 159 stays exactly as it is. It now sits
under copy that names which three products it covers.

- [ ] **Step 4: Build and assert**

```bash
cd mambakkam-net && npm run build
grep -c "Atri Sangam" dist/people/siva-m/index.html
grep -c "The first three are not separate builds" dist/people/siva-m/index.html
grep -c "not three separate builds" dist/people/siva-m/index.html
grep -o 'href="https://mambakkam.net/work/atri-sangam"' dist/people/siva-m/index.html | wc -l
```

Expected: build succeeds; the first two counts are `1` or more; the third
count is **`0`** (the old sentence is gone); the link count is `1`.

- [ ] **Step 5: Read the section back in a browser**

```bash
cd mambakkam-net && npm run preview
```

Open `http://localhost:4321/people/siva-m`, scroll to "What I'm Building".
Expected: four bullets; the intro no longer claims every product has a model;
the paragraph under the list scopes the engine to the first three and names
Atri Sangam as separate; the diagram below it is unchanged. Click the Atri
Sangam link and confirm it lands on the page from Task 1. Stop the preview
server.

- [ ] **Step 6: Formatting gate**

```bash
cd mambakkam-net && npm run check:prettier
```

Expected: pass. If it flags `src/data/people/siva-m.mdx`, run
`npx prettier -w src/data/people/siva-m.mdx` and re-run.

- [ ] **Step 7: Commit and push the branch**

```bash
cd mambakkam-net
git add src/data/people/siva-m.mdx
git commit -m "feat(people): add Atri Sangam to What I'm Building

Adds the fourth product bullet and scopes two claims that hard-coded a
three-product portfolio.

The section intro said every product puts the shaping in the user's
hands 'not the model's' — Atri Sangam has no model. The closing line
said 'The products are not three separate builds. They share one
content-generation engine', which sits directly above
<SharedEngineDiagram /> and would have absorbed Atri Sangam into a
shared-engine claim that is false. Both are now scoped to the first
three products, with Atri Sangam named as a separate line of work."

git push -u origin feat/atri-sangam-work-entry
```

**Do NOT merge.** Merging to `main` deploys mambakkam.net immediately. Open a
PR and hand it to the operator.

---

## Not in this plan

Tracked separately, deliberately excluded:

- `atri-sangam/README.md:287` claims "Current: **v0.1.0**" while
  `pyproject.toml:7` says `0.1.7`.
- The four-lens critique in `project-critique/` needs re-running against
  `ba9c697`, plus an `atri-sangam-last-reviewed.txt` anchor file so the
  portfolio staleness check can see it. It currently has none, which is why
  nothing flagged the drift.
- A logo asset and a dedicated `/atri-sangam` landing page, if the product
  ever warrants the visibility Mentible and Thittam have.
