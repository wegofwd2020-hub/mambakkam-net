# Mentible "Work with me" / book-a-call funnel — Design

**Status:** Approved (brainstorming, 2026-08-14). **Repo:** `mambakkam-net` (the marketing
site — Astro/AstroWind + Tailwind, self-hosted on the Hetzner VPS behind nginx).

Turn the Mentible landing page's amber "Book a 30-minute conversation" node into a real,
shippable surface: a `/mentible/work-with-me` page that frames the **services-led** offer
(Discovery / Sprint / Pilot, per Mentible ADR-037) and lets a qualified SME book a call.

## Context (verified)

- Marketing site is **Astro 5 / AstroWind + Tailwind**, built to `dist/`, deployed to
  `mambakkam.net` by `.github/workflows/deploy-mambakkam.yml` onto the VPS nginx
  (`nginx/nginx.conf`). **Not** Netlify — `netlify.toml` is a leftover slated for removal,
  so **Netlify Forms is unavailable**.
- Mentible landing page: `src/pages/mentible.astro` — self-contained, its own `mtb-*` brand
  CSS (Playfair/Inter, cream/gold), with two CTA rows of `.mtb-btn.mtb-btn-primary` /
  `.mtb-btn.mtb-btn-ghost` links (+ an arrow `<svg>`). Consts at top: `APP_URL='/app/mentible/'`,
  `DEMO_URL='/demos/mentible/'`, `APK_URL=...`. Its CTAs point at app / demo / APK only —
  **no book-a-call today.**
- `nginx/nginx.conf` sets **no Content-Security-Policy** today → an external embed is not
  blocked. (Guard: if a CSP is ever added, it must allowlist the scheduler — see below.)
- A generic `src/pages/contact.astro` + AstroWind `Contact.astro` widget exist, but the
  AstroWind form **does not submit anywhere** (demo stub) — not reused here.

## Decisions (from brainstorming)

1. **Scheduler-native intake.** No lead form on our infra. The qualify fields become
   **required intake questions on the scheduler's booking form** (Calendly, default). A
   booking IS the lead + the email notification. Our page stores nothing → lowest PII burden.
   This collapses the earlier "qualify form → then scheduler" into one tool.
2. **New dedicated page** `/mentible/work-with-me` (its own hero + qualify + embed), linked
   from a new Mentible-landing CTA. Not a section on `mentible.astro`, not the generic contact page.
3. **Qualify fields (moderate)** → the scheduler's intake questions: **Org / role**,
   **What you want validated**, **Timeline**. Name + Email captured natively by the scheduler.
4. **On-brand:** reuse the `mtb-*` visual language (share the CSS; see Architecture), not the
   default AstroWind theme.

## Architecture

One new page + one small edit + one shared style import. No JS we author beyond the
scheduler's own embed script; no backend; no data store.

### New page — `src/pages/mentible/work-with-me.astro`

Astro coexists with the flat `mentible.astro` (→ `/mentible`) and this nested file
(→ `/mentible/work-with-me`). Uses the AstroWind `~/layouts/Layout.astro` with Mentible
`metadata` (title/description/OG — reuse `mentible-og.png`). Sections, top→bottom:

1. **Hero** — H1 "Work with me: turn your expertise into validated, traceable knowledge",
   subhead naming the SME audience and the four-phase loop. One primary button →
   `#book` (scrolls to the embed).
2. **Engagement types** — three `.mtb-*` cards: **Discovery**, **Sprint**, **Pilot**
   (copy seeded from ADR-037; placeholder-free but owner-tunable — see Content).
3. **How it works** — a compact Capture → Create → Validate → Share strip (mirror the
   `steps` array pattern already in `mentible.astro`).
4. **Who it's for** — short SME self-qualifier prose (so unqualified visitors self-select out).
5. **Book (`id="book"`)** — the scheduler embed (see below), preceded by one line telling the
   visitor the booking will ask a few questions.
6. **Footer note** — a one-line privacy notice + `mailto:` fallback link.

### Scheduler embed (Calendly inline widget)

A single config const at the top of the page:

```astro
const SCHEDULER_URL = 'https://calendly.com/<account>/30min'; // swap to Cal.com by changing this URL
```

Markup:

```html
<div id="book" class="mtb-book">
  <div class="calendly-inline-widget" data-url="{SCHEDULER_URL}" style="min-width:320px;height:700px"></div>
  <script src="https://assets.calendly.com/assets/external/widget.js" async is:inline></script>
  <noscript><a class="mtb-btn mtb-btn-primary" href="{SCHEDULER_URL}">Book a 30-minute conversation</a></noscript>
  <p class="mtb-book-fallback">
    Trouble loading the scheduler?
    <a href="mailto:wegofwd2020@gmail.com?subject=Mentible%20%E2%80%94%20work%20with%20me">Email me</a> instead.
  </p>
</div>
```

- `is:inline` keeps Astro from bundling the third-party script.
- The `<noscript>` + `mtb-book-fallback` mailto cover a blocked/failed widget (JS off, CSP,
  network) so the page is never a dead end.

### Entry CTA — edit `src/pages/mentible.astro`

Add `const WORK_URL = '/mentible/work-with-me/';` beside the other URL consts, and add ONE
`<a class="mtb-btn mtb-btn-primary" href={WORK_URL}>Work with me →</a>` to the **hero** CTA row
(the existing App/Demo/APK buttons stay — the self-learner path is unchanged; this adds the
SME/services path). Reuse the existing arrow-`svg` pattern for visual consistency.

### Styling

Reuse the Mentible brand. Preferred: **extract the `mtb-*` block** from `mentible.astro`'s
`<style>` into `src/components/mentible/brand.css` (or a shared `.astro` style partial) and
import it in both pages, so the two Mentible pages can't drift. If extraction is risky mid-task,
the fallback is to copy the handful of `mtb-*` rules this page uses into its own scoped
`<style>` — but note the duplication in the PR so it's a conscious choice.

## Config / prerequisites (owner, one-time, outside code)

These are **manual setup the owner does in the scheduler**, not code — the page just points
at the result:

1. Create the Calendly (or Cal.com) account + a **"30-minute conversation"** event type.
2. Add three **required** intake questions: _Organisation / role_, _What do you want
   validated?_ (long text), _Timeline_ (dropdown: Now / This quarter / Exploring).
3. Set the event's notifications to email the owner on every booking.
4. Put the event's public URL into `SCHEDULER_URL`.

The spec/plan documents these; the plan does not automate them.

## Content (seed copy — owner-tunable)

Engagement tiers (from ADR-037, services-led):

- **Discovery** — a scoped conversation to map your expertise and pick a first artifact.
- **Sprint** — a fixed-scope engagement producing one expert-validated, traceable asset.
- **Pilot** — a longer run standing up your validation workflow across several assets.

Copy is real (no `TBD`), and marked in the plan as owner-editable before launch.

## Integration & risk

- **CSP:** none in `nginx.conf` today → embed loads. **Guard clause for the plan:** if a CSP
  is introduced, add `script-src https://assets.calendly.com` and
  `frame-src https://calendly.com` (and `style-src`/`img-src` for the widget's assets). The
  `mailto:` fallback is the safety net either way.
- **Third-party dependency:** the scheduler is external (Calendly). The page degrades to a
  plain booking link + mailto if their script is unavailable. Acceptable for a marketing page.
- **Subresource Integrity (SRI):** deliberately **not** applied to `widget.js` — Calendly ships
  it from a versionless URL they rotate, so a pinned `integrity=` hash would break on their next
  update, and they publish no hashes. Trade-off accepted for a marketing page that stores no user
  data; the `mailto:`/`<noscript>` fallback bounds the blast radius. Revisit if we self-host or
  the vendor starts publishing hashes.
- **PII:** we collect and store **nothing** — the scheduler is the data controller. The page
  carries a one-line notice + a link to the site's existing `privacy.md`.

## Testing / verification

Static Astro site — the gates:

- `npm run build` succeeds; `/mentible/work-with-me` emits in `dist/`; no broken internal links.
- **Local render (the gate):** `astro preview` (or serve `dist`), screenshot the page — confirm
  Mentible brand (not default AstroWind theme), all five sections present and laid out, the CTA
  on `mentible.astro` links here, and the embed container + mailto fallback render. Record the
  screenshot.
- Lint/format pass (`eslint`), matching the repo's config.
- The Calendly **live widget needs network** and a configured event → a **manual post-deploy
  check** (documented, not a CI gate): load the deployed page, confirm the widget mounts and the
  three intake questions appear.

## Rollout

Merge to `main` → `deploy-mambakkam.yml` builds Astro and ships `dist/` to the VPS nginx.
Post-deploy manual check of the live embed. Owner completes the scheduler setup + fills
`SCHEDULER_URL` before (or as part of) the launch.

## Out of scope

Self-serve Pro / payment. The rest of the marketing site (About / Books / Content). Derivatives,
PDF/Word export, the referral loop. A first-party lead store or CRM (revisit only if the
scheduler-native intake proves insufficient). Domain changes (stays on `mambakkam.net`
subpaths).

## Open (non-blocking) decisions

- **Scheduler vendor:** Calendly (default, assumed) vs Cal.com (open-source/self-hostable) —
  swappable via the single `SCHEDULER_URL`; pick at setup.
- **Engagement-tier copy** — seeded here; owner refines before launch.
