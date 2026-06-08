# Design — People & Work pages

> **Repo:** `mambakkam-net` · **Status:** implemented (2026-06-08) · **Owner:** Siva Mambakkam
>
> How the site models *people* and their *work*, why `/work` is owner-scoped,
> and how to add a second person with **zero code changes**. Captures the
> changes shipped 2026-06-08 and the one open proposal still on the table.

---

## 1. Intent

`mambakkam.net` is a village-community site that doubles as the site owner's
(Siva Mambakkam's) personal/professional home. The **Work** area must:

1. Show **only the owner's curated projects** on the flagship `/work` page —
   not every project in the repo, and not (yet) other people's work.
2. Give **each person** on `/people` their own profile *and* a dedicated work
   listing, so adding a second maker never pollutes the owner's page or
   produces broken cross-links.

Before this change, `/work` listed every non-draft project and the person
profile's "All work →" link was hardcoded to `/work` — both would break the
moment a second person was added.

---

## 2. Content model

Two Astro content collections drive everything (schemas in
`src/content/config.ts`):

### `people` — `src/data/people/*.mdx`
One file per person. The **filename is the slug** (`siva-m.mdx` → `siva-m`).
Key fields: `name`, `nameTamil?`, `role`, `bio`, `image?`, `stats?`, `links?`,
`featured`, `draft?`. Body (MDX) renders as the profile prose.

### `work` — `src/data/work/*.md`
One file per project. The **filename is the slug** (`mentible.md` → `mentible`).
Relevant fields:

| Field        | Meaning                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------- |
| `author`     | **Person slug** this project belongs to (e.g. `siva-m`). Ties work → person.              |
| `type`       | `product` \| `project` \| `open-source` \| `research`                                     |
| `status`     | `live` \| `in-progress` \| `archived`                                                     |
| `featured`   | Sorts to the front of listings.                                                           |
| `comingSoon` | Renders a "Coming soon" card with **no detail-page link** (and no detail page is built).  |
| `listed`     | **Defaults `true`.** Set `false` to hide from *all work listings* while keeping its page. |
| `draft`      | Excludes the project entirely (no listing, no page).                                      |

**The `listed` flag** is the curation lever. `listed: false` removes a project
from `/work` **and** every per-person work listing **and** the profile's
embedded Work section — but its detail page at `/work/<slug>` is still built and
directly linkable (`/work/[slug].astro`'s `getStaticPaths` does not filter on
`listed`). Currently `listed: false` on `ai-learning-platform` and
`studybuddy-free`.

---

## 3. Route map

| Route                   | Source                          | Shows                                                                       |
| ----------------------- | ------------------------------- | -------------------------------------------------------------------------- |
| `/work`                 | `pages/work/index.astro`        | **Owner-scoped** product showcase — `author === SITE_OWNER` + `listed`.    |
| `/work/[slug]`          | `pages/work/[slug].astro`       | A single project's detail page. Built for all non-draft, non-comingSoon.   |
| `/people`               | `pages/people/index.astro`      | All non-draft people.                                                       |
| `/people/[slug]`        | `pages/people/[slug].astro`     | A person's profile + an **embedded** Work section (their listed work).      |
| `/people/[slug]/work`   | `pages/people/[slug]/work.astro`| A person's **dedicated** work listing — `author === slug` + `listed`.       |

`SITE_OWNER` is a constant (`'siva-m'`) in `pages/work/index.astro`. That is the
single line that makes `/work` the owner's page rather than everyone's.

The profile page links its "All work →" to `/people/[slug]/work` (person-aware),
so each maker's link always points at their own page.

---

## 4. Changes shipped 2026-06-08

Three commits on `main`, all deployed and smoke-tested live:

1. **`feat(work): scope /work to Siva's curated four projects`** (`f404c0a`)
   - Added the `listed` flag to the `work` schema (default `true`).
   - Set `listed: false` on `ai-learning-platform` and `studybuddy-free`.
   - `/work` now filters `!draft && listed !== false && author === SITE_OWNER`.
   - Result: `/work` shows exactly StudyBuddy OnDemand, Thittam, Mentible, Pramana.

2. **`feat(work): drop "by Siva Mambakkam" attribution from work cards`** (`1ec712e`)
   - Removed the per-card author link (redundant — cards already link to the
     product detail page, and `/work` is single-author).
   - Dropped the now-unused `people` lookup from the index.

3. **`feat(people): add per-person work pages`** (`438b26e`)
   - New `pages/people/[slug]/work.astro` — one work page per non-draft person.
   - Profile "All work →" now → `/people/[slug]/work` (was `/work`).
   - Applied the `listed` filter to the profile's embedded Work section too, so
     hidden projects stay hidden everywhere. Generalized the flag's documented
     meaning from "/work only" to "all work listings."

---

## 5. How to add a second person (no code)

1. Create `src/data/people/<their-slug>.mdx` with `name`, `role`, `bio`,
   optional `image`/`stats`/`links`, and MDX body.
2. Add their projects under `src/data/work/` with `author: <their-slug>`.

They automatically get:
- a profile at `/people/<their-slug>`,
- a dedicated work page at `/people/<their-slug>/work`,
- correct scoping everywhere (their work never appears on `/work`, the owner's
  work never appears on their pages).

No edits to routes, schemas, or `SITE_OWNER` required.

---

## 6. Open proposal — should `/work` aggregate all makers?

**Decision deferred.** Today `/work` (the top-nav "Products" page) is
intentionally owner-only via `SITE_OWNER`. Once a second maker exists, the owner
may instead want `/work` to be a *village-wide* product showcase aggregating
every maker, with per-person pages (`/people/[slug]/work`) remaining the
individual views.

- **Keep owner-scoped (current):** `/work` = Siva's products; clean personal
  brand front-door. No change needed.
- **Aggregate all makers:** drop the `author === SITE_OWNER` clause in
  `pages/work/index.astro` (one line). Reintroduce a per-card author/attribution
  so visitors can tell whose product is whose (see commit `1ec712e` for the
  markup that was removed). Consider grouping by person or showing a "by <name>"
  chip again.

This is a content/brand call, not a technical blocker — revisit when the second
person is actually onboarded.
