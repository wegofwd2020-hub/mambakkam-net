# `scripts/docs_index/` — nightly doc-index drift detector

This directory holds the local tooling that keeps [`../../DOCS_INDEX.md`](../../DOCS_INDEX.md)
honest. It exists because docs are spread across three sibling repos
(`mambakkam-net`, `studybuddy-docs`, `StudyBuddy_OnDemand`) and there's no
single workflow that watches all of them.

**Status: v1** — detection only. Surfaces drift between the hand-curated
`DOCS_INDEX.md` and what actually exists on disk. Does NOT auto-regenerate
the index (the curated purposes are too valuable to overwrite without a
reviewed topic config — see "Future v2" below).

---

## What's in here

| File             | Purpose                                                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `check_drift.py` | The drift detector. Walks the 3 repos, diffs against `DOCS_INDEX.md`, writes `DRIFT_REPORT.md` to the mambakkam-net repo root. |
| `README.md`      | This file.                                                                                                                     |

**What it produces:** `mambakkam-net/DRIFT_REPORT.md` (gitignored by default).

---

## How to run manually

```bash
python3 scripts/docs_index/check_drift.py
```

Exit codes:

- `0` — index in sync with filesystem
- `1` — drift detected (open `DRIFT_REPORT.md` to see what)
- `2` — fatal (missing sibling repo or unreadable index)

Stderr prints a one-line summary on every run (good for cron logs).

---

## Setting up the nightly cron

Install **once** with `crontab -e` and add:

```cron
# Doc-index drift check — nightly at 02:30 UTC.
# Offset from the (planned) restic backup cron at 02:00 UTC to avoid disk
# contention. Adjust the path if the workspace moves.
30 2 * * * cd /home/sivam/Documents/code/projects/AIStuff/STEM_studybuddy/mambakkam-net && /usr/bin/python3 scripts/docs_index/check_drift.py >> /tmp/docs_index_drift.log 2>&1
```

Notes:

- Uses absolute paths because cron's working directory and `$PATH` are
  minimal — never relies on whatever shell happens to be configured.
- Stdout is the report file itself (written by the script). The cron log
  at `/tmp/docs_index_drift.log` captures stderr only — a one-liner per
  run is enough to know it ran.
- The script doesn't touch git. Nothing gets committed. The next time you
  open the mambakkam-net working tree, `git status` will show
  `DRIFT_REPORT.md` as untracked (or modified, if you've committed a
  previous one) — review it, then either ignore it (no drift to act on)
  or follow up by editing `DOCS_INDEX.md`.

---

## What to do when drift is reported

### "Untracked files"

A `.md` file exists in one of the three repos but isn't referenced from
any topic table in `DOCS_INDEX.md`. Three responses:

1. **The file is a real new doc.** Add a row to the appropriate topic
   table. If no topic fits, add it to the most adjacent one and consider
   whether a new topic is warranted.

2. **The file is one we deliberately don't index** (sample content,
   ephemeral test artefacts, third-party READMEs). Add a pattern to
   `EXCLUDE_GLOBS` at the top of `check_drift.py`, AND add a row to the
   "What is NOT indexed" table in `DOCS_INDEX.md` so the rationale is
   visible.

3. **The file is covered by a sub-index** (e.g., `EPIC_NN_*.md` files are
   collectively pointed at via `docs/epics/INDEX.md`). For v1, these
   show up as untracked — that's expected. Either decide to enumerate
   them individually in `DOCS_INDEX.md`, or add an exclude pattern to
   silence them. Currently kept noisy by design so you notice when a
   new epic appears.

### "Stale references"

`DOCS_INDEX.md` points to a path that doesn't exist on disk. Either:

- The file was moved/renamed → update the path in `DOCS_INDEX.md`.
- The file was deleted → remove the index entry.

---

## Repo layout assumption

The script hardcodes this layout (resolved from its own path):

```
<workspace>/
├── mambakkam-net/             # this repo
│   └── scripts/docs_index/check_drift.py  ← script lives here
├── studybuddy-docs/
└── StudyBuddy_OnDemand/
```

If the workspace ever changes shape, edit the `REPOS` dict at the top of
`check_drift.py`.

---

## Future v2 — auto-regeneration

The current v1 only DETECTS drift. A v2 would also REGENERATE the topic
tables in `DOCS_INDEX.md` from a config file:

```
scripts/docs_index/
├── check_drift.py        # v1 — current
├── topics.yaml           # v2 — topic taxonomy + per-file purpose overrides
└── build_index.py        # v2 — emits DOCS_INDEX.md from topics.yaml
```

`topics.yaml` would let an operator define topics declaratively:

```yaml
topics:
  - name: 'Hosting, Deployment & Cost'
    order: 1
    includes:
      - 'mambakkam-net/Plans/DEPLOYMENT_PLAN.md'
      - 'studybuddy-docs/docs/dev/DEMO_HOSTING_GUIDE.md'
      # ...
overrides:
  'mambakkam-net/Plans/DEPLOYMENT_PLAN.md':
    purpose: 'mambakkam.net deployment + monthly cost breakdown'
```

Deferred to v2 because:

- The hand-written purposes in `DOCS_INDEX.md` are accurate and useful.
  Overwriting them automatically risks losing nuance.
- A config-driven rebuild is most valuable once the index changes
  frequently. At today's cadence (occasional manual edit), drift
  detection alone gets ~90% of the value.

---

## Future v3 — conflate with `doc_audit`

`../../../StudyBuddy_OnDemand/scripts/doc_audit/` already has
`check_link_integrity.py`, `check_test_counts.py`, and
`check_migrations_table.py`. They're built but never run on a schedule.
Folding them into the same nightly cron would give a single drift report
that covers:

- Index-vs-filesystem (what `check_drift.py` does today)
- Link integrity within docs (broken `[label](path)` references)
- Test-count claims in docs vs. actual test counts
- Migrations-table claims in docs vs. actual migrations

The minimal v3 shape:

```bash
# scripts/docs_index/run_all.sh
python3 scripts/docs_index/check_drift.py
python3 ../StudyBuddy_OnDemand/scripts/doc_audit/run_all.py --repos ../studybuddy-docs,../StudyBuddy_OnDemand,./
```

Combining the two reports into a single `DRIFT_REPORT.md` is then a
formatting concern.

---

## Maintenance

| Date       | Version | Change                                                                                                                 |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| 2026-05-17 | 1.0     | Initial — `check_drift.py` + this README. Detects drift between `DOCS_INDEX.md` and the filesystem. No auto-regen yet. |
