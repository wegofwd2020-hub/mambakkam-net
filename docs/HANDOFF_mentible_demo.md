# HANDOFF — Mentible public demo (resume here)

Portable status note so this work can be picked up on another machine. The technical
detail lives in [`DEMO_mentible_lite.md`](./DEMO_mentible_lite.md); this file is the
"where are we / what's next" snapshot.

**Last updated:** 2026-06-11. **Status:** ✅ **go-live gate PASSED** (keyed end-to-end
smoke test green); backend validated locally; **still NOT deployed to the VPS; not
announced.**

## Goal

Public Mentible demo with **no new domain**, on the shared Hetzner VPS that already
hosts mambakkam.net + the StudyBuddy demo. Same-origin:

- Frontend (static Expo-web export): `mambakkam.net/demos/mentible/`
- Backend (FastAPI + redis, sibling Docker stack): `mambakkam.net/mentible-api/` → `127.0.0.1:8092`

Path-on-apex (not a subdomain) was chosen deliberately to avoid an Origin Cert reissue

- DNS record — and to skip CORS. Mentible is **not** backend-free (the app routes
  generate/structure/export through FastAPI; the BYOK key is sent to the backend).

## PR status

| Repo                   | PR  | Branch                               | Status                                                                                                      |
| ---------------------- | --- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| mambakkam-net          | #39 | `feat/mentible-lite-demo-slot`       | ✅ **MERGED** 2026-06-11 — frontend slot + SPA fallback + host-nginx route + runbook                        |
| StudyBuddy_SelfLearner | #88 | `feat/mentible-demo-backend-compose` | ⏳ **OPEN** — `docker-compose.demo.yml` (prod backend stack); now also carries the git Dockerfile fix below |

## ✅ Go-live GATE — PASSED 2026-06-11

The operator's requirement was: **run a keyed end-to-end smoke test (structure →
generate → export) AND see it healthy BEFORE telling anyone.** Done, against the
prod-shaped `docker-compose.demo.yml` stack on `127.0.0.1:8092`:

- `/readyz` → `{"status":"ok","redis":"ok"}`
- `/structure` → done (returns `{subjects}`)
- `/generate "Quadratic formula"` → done; **KaTeX rendered** (`class="katex"` in the
  EPUB chapter, not raw `$…$`)
- `/generate "TCP three-way handshake"` → done; **Mermaid rendered** (`diagrams=true`
  PDF is +60 KB over the placeholder — the Chromium Mermaid→SVG pass embedded the diagram)
- `/export` → valid EPUB (362 KB, OPF package) + PDF (388 KB) + diagrams PDF (448 KB)

**Found + fixed during the gate:** the demo image **could not build at all** —
`backend/requirements.txt` pulls `wegofwd-llm` over `git+https`, but the backend
Dockerfile never installed `git`, so `pip install` failed (`Cannot find command
'git'`). Fixed by adding `git` + `ca-certificates` to the apt layer; pushed to PR #88.
Without it the VPS `docker compose … up --build` in §Deploy fails identically.

## Next steps (in order)

1. ~~Smoke test (the gate).~~ ✅ done.
2. **Merge PR #88** (includes the git Dockerfile fix — required for the build).
3. VPS backend, host-nginx reload, frontend export, deploy — full commands in
   `DEMO_mentible_lite.md` (§Deploy).
4. Decide `noindex` → indexable, confirm live end-to-end on the VPS, **then** announce.

## Cross-machine notes

- **Durable / travels:** everything above is on GitHub; the reminder routine (DOCS_INDEX
  sweep, daily) is a claude.ai cloud routine tied to the account.
- **Does NOT travel:** (a) the original Claude Code file-memory was machine-local — this
  HANDOFF replaces it; (b) the smoke-test stack is a **local Docker build**. To rebuild on
  a new machine: clone SelfLearner → check out `feat/mentible-demo-backend-compose` →
  `printf 'BYOK_MASTER_KEY=%s\n' "$(openssl rand -hex 32)" > .env.demo` →
  `docker compose -f docker-compose.demo.yml --env-file .env.demo up -d --build`. The
  keyed smoke test needs an operator-supplied `sk-ant-…` (BYOK); Claude will not use a
  key unprompted.
