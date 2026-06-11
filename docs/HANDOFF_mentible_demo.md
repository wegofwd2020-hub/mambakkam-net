# HANDOFF — Mentible public demo (resume here)

Portable status note so this work can be picked up on another machine. The technical
detail lives in [`DEMO_mentible_lite.md`](./DEMO_mentible_lite.md); this file is the
"where are we / what's next" snapshot.

**Last updated:** 2026-06-11. **Status:** designed + artifacts committed; **nothing
deployed to the VPS; not announced.**

## Goal

Public Mentible demo with **no new domain**, on the shared Hetzner VPS that already
hosts mambakkam.net + the StudyBuddy demo. Same-origin:

- Frontend (static Expo-web export): `mambakkam.net/demos/mentible/`
- Backend (FastAPI + redis, sibling Docker stack): `mambakkam.net/mentible-api/` → `127.0.0.1:8092`

Path-on-apex (not a subdomain) was chosen deliberately to avoid an Origin Cert reissue

- DNS record — and to skip CORS. Mentible is **not** backend-free (the app routes
  generate/structure/export through FastAPI; the BYOK key is sent to the backend).

## Open PRs (both unmerged)

| Repo                   | PR  | Branch                               | Contents                                                                 |
| ---------------------- | --- | ------------------------------------ | ------------------------------------------------------------------------ |
| mambakkam-net          | #39 | `feat/mentible-lite-demo-slot`       | frontend slot + SPA fallback + lint-ignores + host-nginx route + runbook |
| StudyBuddy_SelfLearner | #88 | `feat/mentible-demo-backend-compose` | `docker-compose.demo.yml` (prod backend stack)                           |

## 🚦 Go-live GATE (operator's explicit requirement)

**Run a keyed end-to-end smoke test (structure → generate → export) AND see it healthy
BEFORE telling anyone.** Mentible is `status: in-progress` and has never been observed
generating. The smoke test needs an `ANTHROPIC_API_KEY` (BYOK) the operator supplies;
Claude will not use a key unprompted. **Not done yet.**

## Next steps (in order)

1. **Smoke test (the gate).** Provide a key, then drive `/structure` → `/generate` →
   `/export` against a running backend; confirm KaTeX ("Quadratic formula") + Mermaid
   ("TCP three-way handshake") render and EPUB/PDF export works. Don't proceed if broken.
2. Merge PR #39 and PR #88.
3. VPS backend, host-nginx reload, frontend export, deploy — full commands in
   `DEMO_mentible_lite.md` (§Deploy).
4. Decide `noindex` → indexable, confirm live end-to-end, **then** announce.

## Cross-machine notes

- **Durable / travels:** everything above is on GitHub; the reminder routine (DOCS_INDEX
  sweep, daily) is a claude.ai cloud routine tied to the account.
- **Does NOT travel:** (a) the original Claude Code file-memory was machine-local — this
  HANDOFF replaces it; (b) the smoke-test relied on a **local Docker stack** (backend
  `:8001` + redis, web `:8081`) on the original Linux box. On a new machine, rebuild it:
  clone SelfLearner → `docker compose up -d --build` → `cd mobile && npx expo start --web`.
