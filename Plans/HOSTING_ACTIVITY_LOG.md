# mambakkam.net Hosting Activity Log

> Chronological log of operator actions affecting the live mambakkam.net
> infrastructure: provisioning, deploys, incidents, recoveries. Each entry is
> a dated, self-contained record of what was done, what went wrong (if
> anything), and what was learned. Newest entries at the top — append a new
> `## YYYY-MM-DD — <event>` section above the previous one.
>
> **Secrets policy:** Origin Cert bodies, private keys, the restic password,
> and the GitHub Actions deploy key are NEVER pasted into this file. Where a
> secret was generated or rotated, this log notes _that_ it happened, not the
> value. See the operator password manager for the values.
>
> **Companion docs:** [DEMO_LAUNCH_PLAN.md](DEMO_LAUNCH_PLAN.md) (the runbook
> this log records executions of), [DEPLOYMENT_PLAN.md](DEPLOYMENT_PLAN.md),
> [RUNBOOK.md](RUNBOOK.md) (alert response), [../DOCS_INDEX.md](../DOCS_INDEX.md).

---

## 2026-05-19 — Demo end-to-end walkthrough validated (teacher + student)

**Outcome:** ✅ Fresh demo signup → email verify → teacher login → catalog →
library → unit drill-down → student login → subjects → lesson view all
work end-to-end through Cloudflare. Tagged as the
`demo-walkthrough-2026-05-19` milestone.

**Live URL:** `https://demo.usestudybuddy.com`
**Tenants:** mambakkam.net + demo.usestudybuddy.com both healthy on shared CX23.

**Summary.** Started session #2 of the day to validate the demo flow as a
real visitor would experience it. Walked the full teacher + student
journey and fixed 9 bugs surfaced along the way — most caused by the
asyncpg JSON codec interacting badly with pre-existing call sites that
manually serialised JSON. The compose-hygiene + catalog fixes from
session #1 (commits `63f7bdd`, `63a78a3`) were prerequisites; this
session #2 built on top.

**Bugs found + fixed today (chronological, all committed + auto-deployed):**

| # | Symptom | Root cause | Fix |
| - | ------- | ---------- | --- |
| 1 | Catalog page blank for new teachers | `school_adopted_curricula` had no rows | `7b579ec` — auto-adopt G11 Science in `verify_test_run` |
| 2 | "Failed to load units" on a clicked curriculum | `curriculum_units.title` was NULL for 6 of 7 platform curricula (yesterday's `recover_curriculum` workaround never populated titles) | One-shot backfill from `data/grade*.json` → 108 titles |
| 3 | Curriculum Catalog → has_content cell crashed Pydantic | SQL returned NULL when no `content_subject_versions` row existed | `COALESCE(... > 0, false)` |
| 4 | Curriculum Content page empty for the demo teacher | `c.is_default = false` on every platform curriculum | one-shot UPDATE + safeguard in `preimport_demo_units.py` |
| 5 | Sign Out → "Not Found" | nginx routed `/api/auth/logout` to FastAPI which only has `/api/v1/auth/logout` | `71f96d6` — split nginx into `/api/v1/` (backend) and `/api/` (Next.js) |
| 6 | Sign Out → redirect to `http://localhost:3000/` | `NEXT_PUBLIC_APP_URL` unset on the web container | `02b25ec` — set to `https://demo.usestudybuddy.com` |
| 7 | Subjects page → "Could not load curriculum" (intermittent) | Demo student JWT TTL = 15 min (too short for a demo walkthrough) | `1d986fc` — bump to 240 min in `.env.demo` |
| 8 | Subjects page → 404 (persistent) | `curriculum_units` rows only exist on the OOB curriculum, but resolver returned the school's fork | `d93e9ee` — follow `source_curriculum_id` for the units lookup |
| 9 | Biology lessons → "Could not load lessons" (other subjects worked) | Manual `json.dumps(body)` paired with the asyncpg codec's own `json.dumps` → bodies stored as jsonb _string_ instead of _object_ | `7dec328` — drop manual `json.dumps` at all 7 jsonb write sites; one-shot UPDATE to repair 18 already-bad rows |

**Other ground-clearing landed today:**

- `1a01526` — preimport script now imports ALL 29 G11 Science units as
  approved + published (was 8 as drafts), so Content Library is fully
  populated on a fresh signup. Removes the "manually exercise the
  import flow" demo step that didn't add value.
- `209d122` — `is_default = true` UPDATE baked into the preimport
  script so the drift can't recur.

**Account state at end of session:**

- 2 active demo accounts (1 walked the full demo: `callmds+student@gmail.com`
  + `callmds+teacher@gmail.com`).
- All 29 G11 Science units imported, approved, published.
- 18 previously double-encoded `unit_content_overrides` body rows repaired.

**Memory updated:**

- `[[feedback-asyncpg-json-codec-required]]` — added write-side trap
  documentation (the `json.dumps(x)` × codec double-encode pattern), and
  a SQL repair recipe for already-malformed rows.
- `[[feedback-nginx-upstream-ip-cache]]` (landed earlier) — already
  covered the bind-mount inode + IP cache traps that bit us during
  the nginx config edits.

**Follow-ups remaining (from earlier launch, not blocking demo):**

- **#28** — Deferred rename sweep (17 files inc. Auth0 claim namespaces).
- **#29** — Pre-existing CI failures (138 frontend tests + Backend + API Contract).
- **#31** — `DEMO_VPS_HOST` set to bare IP, so the workflow's smoke
  check always 000's. Needs splitting into SSH-host (IP) + smoke-host
  (DNS name).
- **#12** — `/opt/mambakkam/.git` ownership.
- **Stripe wiring** — blanked in `.env.demo`; subscription endpoints
  500 if anyone exercises them on the demo.

**StudyBuddy_OnDemand commits this session (most recent first):**

```
7dec328 fix(asyncpg): drop manual json.dumps() on every jsonb write path
d93e9ee fix(curriculum): use source_curriculum_id for unit lookup on school forks
1d986fc feat(demo): extend JWT access-token TTL to 4h in .env.demo skeleton
02b25ec fix(demo): set NEXT_PUBLIC_APP_URL so /api/auth/logout redirects to demo URL
71f96d6 fix(demo): scope nginx /api/v1 to backend, let Next.js handle other /api/* paths
209d122 fix(demo): ensure platform curricula have is_default=true (Curriculum Content visibility)
1a01526 feat(demo): preimport all G11 Science units as approved+published (full Content Library)
7b579ec fix(demo): auto-adopt Grade 11 Science into the sandbox school's library on test-run verify
674cf83 feat(demo): add preimport_demo_units.py — curated 2-units-per-subject pre-import
c310b12 fix(catalog): COALESCE has_content boolean (curricula without content_subject_versions rows)
```

---

## 2026-05-19 — Tasks #32 + #30 closed in single session

**Outcome:** ✅ Catalog API fixed AND yesterday's 5 compose workarounds
landed cleanly in the demo override. Demo auto-deploy now runs without
the `--profile never` hack and without symlink/curl band-aids.

**Commits:**

- `63f7bdd` fix(catalog): asyncpg json/jsonb codecs
- `63a78a3` fix(demo): codify launch-time compose workarounds

**Compose hygiene fixes (task #30) landed in `docker-compose.demo.yml`:**

| Old workaround                       | Codified in demo override                                                                            |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `--profile never` on every command   | `depends_on: !override` on every service that referenced `*depends-all`, dropping pgbouncer entirely |
| `ln -sf .env.demo .env`              | `env_file: !override - .env.demo` on api/celery-worker/celery-beat-primary/migrate                   |
| `ln -sf ../.env.demo web/.env.local` | `env_file: !override - .env.demo` on web                                                             |
| `volumes: !reset null` on web        | `volumes: !override - /data/videos:/app/public/videos:ro` (drops `./web:/app` overlay, keeps videos) |
| `mv content_store_data && ln -s ...` | `volumes: !override - /data/content:/data/content` on api/celery/migrate                             |
| broken curl healthcheck override     | Override removed entirely; api inherits the correct python+urllib healthcheck from base              |
| stray `TEST_DB_URL` blanking in base | Moved to `TEST_DB_URL: ""` overrides in demo for api/celery/migrate; base file restored              |

Validated via `docker compose -f docker-compose.yml -f docker-compose.demo.yml --env-file .env.demo config --quiet` → exit 0.

**VPS reconciliation order (executed live):**

1. Stashed 4 modified files (`backend/src/core/app_factory.py`, `backend/src/school/service.py`, `docker-compose.yml`, `docker-compose.demo.yml`) into `stash@{0}` with message `task#30-launch-workarounds-2026-05-18`.
2. Pushed `63a78a3` to main; deploy workflow auto-fired.
3. Workflow's `git pull --ff-only` then succeeded (working tree clean from step 1).
4. `docker compose pull` brought in api image from the catalog-fix build (`2026-05-19T13:27:47Z`).
5. `docker compose up -d --remove-orphans` recreated containers with the new compose layout — no `--profile never` needed, no symlinks needed.

The stash on the VPS is retained for forensic purposes; safe to drop
manually with `sudo /usr/bin/git -C /opt/studybuddy stash drop` once
operator is satisfied no rollback is wanted. Stash contents are 100%
codified by the two commits above plus the now-redundant
TEST_DB_URL hack on `docker-compose.yml` (base).

---

## 2026-05-19 — Task #32 resolved: catalog API 0/0 root-caused + fixed

**Operator:** Siva Mambakkam
**Duration:** ~45 min
**Outcome:** ✅ Catalog API now returns correct subject/unit counts for all 7
platform curricula. Fix committed (`StudyBuddy_OnDemand@63f7bdd`) and
auto-deploying.

**Summary.** Picked up the deferred task #32 from yesterday's launch session.
Root-caused the catalog "0 subjects / 0 units" symptom in ~30 min by invoking
`list_catalog()` directly inside the running api container.

**Root cause.** asyncpg returns `json`/`jsonb` columns as raw strings unless a
codec is registered. `list_catalog()` had a defensive guard
`isinstance(row["subjects"], list) else []` that silently swapped the
JSON string for `[]`. **Bug was catalog-wide, not G11-specific** — every
platform curriculum (G8 through G12, all variants) had been returning
empty subject arrays. Yesterday's note that "G8 catalog works as a
reference for what populated looks like" was unverified speculation;
that catalog endpoint was equally broken.

**Why yesterday's psql validation didn't catch it.** Two compounding red
herrings: (1) the `studybuddy` Postgres role used in psql is `SUPERUSER`
**and** `BYPASSRLS` — so any RLS hypothesis would be untestable in psql;
(2) psql renders json columns as if structured, masking that they're
actually strings until the application calls `len()` / `isinstance(...,
list)` on them.

**Fix.** Pool-level — register `set_type_codec('json'/'jsonb',
encoder=json.dumps, decoder=json.loads, schema='pg_catalog')` via a new
`_init_db_conn` hook passed to `asyncpg.create_pool(init=...)` in
`backend/src/core/app_factory.py`. Also simplified the now-redundant
guard in `service.py:770` and dropped two naked `json.loads(row["theme"])`
calls at `service.py:1233` + `:1275` that would have broken under the
codec. Codebase audit confirmed no other naked `json.loads(row[...])`
patterns; all 7 other `json.loads(d["subjects"])` etc. call sites
already guard with `isinstance(..., str)`, so they become no-ops under
the codec.

**Validation.** Patched live container via `docker cp` + `docker restart
studybuddy-api-1`. Invoked `list_catalog(conn, grade=11)` via Python REPL
inside the container with `_init_db_conn(conn)` registering the codecs —
returned the correct 4 subjects / 29 units for `default-2026-g11-science`
with `has_content=True` on all four. All 7 platform curricula
(G8/G10/G11/G11-commerce/G11-science/G12-science/G12-commerce) now
return correct counts. Then committed + pushed; GH Actions auto-deploy
running.

**Files changed:**

- `backend/src/core/app_factory.py` — `+15 / -1` (json codec + import)
- `backend/src/school/service.py` — `+3 / -3` (3 simplification edits)

Commit: `9faedcc` → rebased onto remote nightly bot → `63f7bdd` pushed.

**Investigative path / negative results:**

- ✗ RLS hypothesis — `curriculum_units` and `content_subject_versions`
  have RLS disabled entirely. `curricula.tenant_isolation` policy
  unconditionally allows `owner_type='platform'` rows. Also moot since
  the app's `studybuddy` role bypasses RLS anyway.
- ✗ `retention_status != 'archived'` NULL-comparison trap — verified
  row has `retention_status='active'`.
- ✗ Container source drift — `/app/src/school/service.py` in container
  matched local source byte-for-byte before the patch.
- ✓ asyncpg JSON serialization — root cause.

**Follow-ups / corrections to yesterday's log:**

- The §10 "G8 catalog works as a reference" workaround note is now known
  to have been inaccurate — that endpoint was equally broken at the
  serialization layer. Yesterday's fixes A-D (symlink, seed_content_db,
  recover_curriculum sed-patch, status=published UPDATE) were still all
  real and necessary to make the _data_ correct; they just couldn't fix
  the symptom because the symptom is purely a serialization bug.

---



**Operator:** Siva Mambakkam
**Duration:** ~4h (12:00 – 16:20 EDT / 16:00 – 20:20 UTC)
**Outcome:** ✅ `https://demo.usestudybuddy.com` publicly serving the full StudyBuddy
demo stack on the same shared CX23 as mambakkam.net. End-to-end verified in
browser: register-for-test-run flow works, email login works, teacher and
student accounts work as planned. Both tenants now live on the box.

**Summary.** Second-tenant join landed but was much rougher than mambakkam's
cold-start — the StudyBuddy demo compose had a series of accumulated
local-dev assumptions that had never been exercised against a fresh CX23.
We hit **7 separate compose/script issues** in sequence and worked around
each one live on the VPS. None of the workarounds were committed to the
StudyBuddy_OnDemand repo; they're tracked as a follow-up
([[#30 Fix StudyBuddy demo compose env_file + profiles hygiene]],
[[#31 Fix StudyBuddy demo smoke.sh]]). Also surfaced + cleared a partial
rename: `studybuddy.app → usestudybuddy.com` had only landed in mambakkam
docs (commit `8329913`) — 33 files in StudyBuddy_OnDemand still referenced
the old domain. 15 deployment-critical were swept in commit `b544029`; 17
remain deferred (Auth0 claim namespaces, tests, docs, Remotion sources).

**Live state at end of session:**

| Item                       | Value                                                                                                                                                                           |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| URL                        | `https://demo.usestudybuddy.com`                                                                                                                                                |
| Cert                       | Cloudflare Origin Cert B, 2-host SAN (`*.usestudybuddy.com`, `demo.usestudybuddy.com`), 15-yr, RSA                                                                              |
| Cert path on VPS           | `/etc/ssl/cloudflare/usestudybuddy.com-{cert,key}.pem` (separate from mambakkam's Cert A)                                                                                       |
| DNS                        | A `178.105.160.62` + AAAA `2a01:4f8:1c18:82e4::1`, both proxied (orange cloud)                                                                                                  |
| Stack                      | 7 services running: api, web, nginx, db (postgres+pgvector), redis, celery-worker, celery-beat-primary                                                                          |
| Disabled-via-profile-never | pgbouncer, celery-pipeline, celery-beat-standby (replicas: 0, but force-activated for depends_on resolution)                                                                    |
| Database                   | `studybuddy` (migrations applied, all 5 seeds populated)                                                                                                                        |
| Seeded accounts            | `wegofwd2020@gmail.com` (super admin); `demo-test@studybuddy.dev` / `DemoTest-2026!`; MilfordWaterford school (4 teachers, 8 students); Dev School (admin/teacher/student trio) |
| Daily restic backup cron   | `0 2 * * *` UTC, repo at `/opt/studybuddy/backups/restic`                                                                                                                       |
| GH Actions auto-deploy     | Enabled (3 `DEMO_VPS_*` secrets set); fires on push to StudyBuddy_OnDemand main                                                                                                 |
| Cosmetic caveat            | Smoke script reports 6 failed checks — all are script-vs-app path/ID mismatches, NOT real app failures (see task #31)                                                           |

---

### Step 0 — Pre-flight readiness check

Confirmed before starting: GHCR images for current main, Cert B + key
in password manager, content artifacts on dev machine. All three green.

### Step 1 — Repo cleanup commit (StudyBuddy_OnDemand)

Discovered via grep audit that the `studybuddy.app → usestudybuddy.com`
rename was only partially applied (33 files still stale). Triaged into
10 deployment-critical + 17 deferred. Edited the critical 10:

```bash
# [laptop] — applied edits in StudyBuddy_OnDemand checkout
# Renamed: infra/nginx/demo.studybuddy.app.conf → demo.usestudybuddy.com.conf
git mv infra/nginx/demo.studybuddy.app.conf infra/nginx/demo.usestudybuddy.com.conf

# Inside the new vhost: server_name + ssl_certificate path (now Cert B's path) +
# split deprecated `listen 443 ssl http2` into `listen 443 ssl` + `http2 on;` +
# updated header comment to document two-cert split.

# Plus targeted edits in:
#   - scripts/demo/provision.sh (SAN check, env-skeleton CORS/URL, vhost paths,
#     Next-Steps printout)
#   - docker-compose.demo.yml line 148 (NEXT_PUBLIC_API_URL)
#   - backend/config.py (EMAIL_FROM default + SMTP_USER example)
#   - backend/src/core/middleware.py (upgrade_url)
#   - backend/src/email/service.py (support_email fallback)
#   - web/app/(public)/demo/{teacher,student}-story/page.tsx (visible support@)
#   - backend/data/help_chunks.jsonl (chatbot answers)
#   - scripts/demo/{smoke,sync-content,seed,nginx.conf} + .github/workflows/deploy-demo.yml + web/lib/demo-mode.ts (comments)

# Single commit, pushed after rebase onto trivial PROGRESS.md update on remote
git commit -m "chore(rename): studybuddy.app → usestudybuddy.com — deployment-critical sweep"
git pull --rebase origin main
git push origin main
# → b544029
```

CI: 138 pre-existing frontend test failures + Backend Tests fail + API
Contract fail. Confirmed via earlier scheduled CI run that **all three
predate our commit** — we didn't regress anything. See task #29.

### Step 2 — Install Cert B (with mid-step recovery)

```bash
# [vps] as root — first paste from password manager
cat > /etc/ssl/cloudflare/usestudybuddy.com-cert.pem <<'EOF'
[Cert B body — REDACTED]
EOF
cat > /etc/ssl/cloudflare/usestudybuddy.com-key.pem <<'EOF'
[Key B body — REDACTED]
EOF
chmod 600 /etc/ssl/cloudflare/usestudybuddy.com-{cert,key}.pem
chown root:root /etc/ssl/cloudflare/usestudybuddy.com-{cert,key}.pem

# SAN verification caught a typo!
openssl x509 -in /etc/ssl/cloudflare/usestudybuddy.com-cert.pem -noout -ext subjectAltName
#   X509v3 Subject Alternative Name:
#     DNS:demo.use.usestudybuddy.com    ← BAD — typo when generating in CF UI
```

The cert had a `demo.use.usestudybuddy.com` SAN (extra `.use.` in the
middle — typo when typing the hostname during CF UI cert generation,
got auto-appended to the zone domain). **Don't proceed with a wrong-SAN
cert.** Same lesson as today's Cert A: regenerate fresh in CF UI with
exactly the right hostname, save to pwmgr immediately, re-paste:

```bash
# [vps] — after regenerating Cert B in CF UI with hostnames
# `demo.usestudybuddy.com` + `*.usestudybuddy.com`
cat > /etc/ssl/cloudflare/usestudybuddy.com-cert.pem <<'EOF'
[new Cert B — REDACTED]
EOF
cat > /etc/ssl/cloudflare/usestudybuddy.com-key.pem <<'EOF'
[new Key B — REDACTED]
EOF
chmod 600 ...; chown root:root ...

openssl x509 -in /etc/ssl/cloudflare/usestudybuddy.com-cert.pem -noout -ext subjectAltName
#   DNS:*.usestudybuddy.com, DNS:demo.usestudybuddy.com  ← ✓
diff <(openssl x509 -in ...-cert.pem -noout -pubkey) <(openssl pkey -in ...-key.pem -pubout) && echo MATCH
#   MATCH ✓
```

### Step 3 — StudyBuddy provision.sh (second-tenant variant)

```bash
# [vps] as root
curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/StudyBuddy_OnDemand/main/scripts/demo/provision.sh | bash
```

Ran clean (`9/9 complete`). Pre-flight check verified mambakkam first-tenant
artifacts + new Cert B at the expected path. Daily backup cron installed
at 02:00 UTC (offset 30 min before mambakkam's 02:30). Restic password
printed once — saved to pwmgr as `studybuddy demo restic backup password`.

### Step 4 — Populate `.env.demo`

```bash
# [vps] as root — generate 5 random secrets
for k in JWT_SECRET ADMIN_JWT_SECRET METRICS_TOKEN POSTGRES_PASSWORD REDIS_PASSWORD; do
  printf "%-20s = %s\n" "$k" "$(openssl rand -hex 32)"
done

# Edit /opt/studybuddy/.env.demo (nano) with:
#   - the 5 secrets above
#   - Auth0 from pwmgr (full domain: wegofwd2020.us.auth0.com, derived from
#     dashboard URL https://manage.auth0.com/dashboard/us/wegofwd2020/;
#     memory's prior "studybuddy-demo" tenant slug was wrong, corrected)
#   - Gmail App Password generated at myaccount.google.com/apppasswords
#   - Sentry DSN from pwmgr
#   - Stripe LEFT BLANK (skipped for launch; payment endpoints will 500 if
#     anyone exercises them; subscription paths aren't on the demo happy path)

# Verify
grep -nE '<(REPLACE|your-|from-|gmail-app|sentry-dsn|with-)' /opt/studybuddy/.env.demo
# → empty (all placeholders replaced or blanked)
```

### Step 5 — GH Actions deploy keypair (StudyBuddy)

```bash
# [laptop] — separate keypair from mambakkam's
ssh-keygen -t ed25519 -f ~/.ssh/studybuddy_deploy -C "gh-actions deploy@studybuddy" -N ""
cat ~/.ssh/studybuddy_deploy.pub  # copy line

# [vps] — APPEND to deploy user's authorized_keys (mambakkam's key already there)
cat >> /home/deploy/.ssh/authorized_keys <<'EOF'
[deploy pubkey — REDACTED]
EOF
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

# [laptop] verify
ssh -i ~/.ssh/studybuddy_deploy deploy@178.105.160.62 'whoami && id'
# → deploy, uid=1000, gid=1000, in docker group ✓

# [laptop] — set 3 secrets in StudyBuddy_OnDemand repo
gh secret set DEMO_VPS_HOST    --repo wegofwd2020-hub/StudyBuddy_OnDemand --body "178.105.160.62"
gh secret set DEMO_VPS_USER    --repo wegofwd2020-hub/StudyBuddy_OnDemand --body "deploy"
gh secret set DEMO_VPS_SSH_KEY --repo wegofwd2020-hub/StudyBuddy_OnDemand < ~/.ssh/studybuddy_deploy
# (Note: no STUDYBUDDY_DEPLOY_ENABLED gating variable — deploy-demo workflow
# fires unconditionally on push to main; will fail at SSH step until these
# secrets exist. Setting them activates auto-deploy.)
```

### Step 6 — Content sync to VPS

```bash
# [laptop]
cd /home/sivam/Documents/code/projects/AIStuff/STEM_studybuddy/StudyBuddy_OnDemand
bash scripts/demo/sync-content.sh deploy@178.105.160.62
# → 5/5 steps: pre-flight + G11 visual inject + rsync content_store_data → /data/content/ (64MB)
#   + rsync web/public/sample-visuals → /data/sample-visuals/ (220MB, 44 MP4s)
# → 582 files / 227MB transferred, 8.82 MB/sec
```

### Step 7 — `docker compose pull + up -d` — and the cascade of compose hygiene issues

This is where the wheels came off. Each fix unblocked the next failure
mode. None of these changes were committed; all are workarounds on the
VPS, tracked in [[#30]] for a proper repo cleanup.

#### Issue #1 — `pgbouncer depends_on` validation

```
service "celery-worker" depends on undefined service "pgbouncer": invalid compose project
```

Demo override disables pgbouncer via `profiles: ["never"]` + `replicas: 0`,
but newer compose versions treat `profiles: [never]` services as
"not present" → depends_on references fail validation. **Workaround:**
add `--profile never` to every `docker compose` invocation, which
activates pgbouncer service for validation purposes while keeping it
from actually running.

```bash
# Every command from here on uses this prefix
docker compose --profile never -f docker-compose.yml -f docker-compose.demo.yml --env-file .env.demo ...
```

#### Issue #2 — Missing `.env` file

```
env file /opt/studybuddy/.env not found
```

Base compose has per-service `env_file: - .env` (separate from
`--env-file .env.demo`). Demo override doesn't redirect.

```bash
# [vps] — symlink workaround
ln -sf .env.demo /opt/studybuddy/.env
```

#### Issue #3 — Missing `web/.env.local`

Same pattern, different file. Web service's `env_file:` block in base
compose points at `./web/.env.local`.

```bash
ln -sf ../.env.demo /opt/studybuddy/web/.env.local
```

#### Issue #4 — api `PermissionError` on `/data/content/visuals`

Bind mount `./content_store_data:/data/content` (relative path in base
compose) overlays `/data/content/` in container with
`/opt/studybuddy/content_store_data/` from host (git-tracked, near-empty
placeholders). Container tried to `mkdir /data/content/visuals` —
permission denied / dir not present.

After several rounds of host-side chmod (which were on the wrong directory
since the container sees the bind-mount target, not the absolute host
path), the issue self-resolved on a 3rd uvicorn restart attempt — likely
because mkdir eventually succeeded after one of the chmod cycles
touched the right inode. App reached "Application startup complete."

**However the api container then showed "unhealthy"** — see Issue #5.

#### Issue #5 — Broken api healthcheck

```bash
# api's /health endpoint actually works:
docker exec studybuddy-api-1 python -c "import urllib.request as u; r=u.urlopen('http://localhost:8000/health'); print(r.status, r.read())"
# → 200 {"db":"ok","redis":"ok","version":"demo"}
```

But docker's healthcheck uses:

```
["CMD","curl","-f","http://localhost:8000/healthz"]
```

Two bugs: `curl` not in the alpine image, AND wrong path
(`/healthz` vs the real `/health`). App is fine; healthcheck is bogus.
Web + nginx couldn't start because they depend on
`api: condition: service_healthy`. **Workaround:** force-start dependents
with `--no-deps`:

```bash
docker compose --profile never -f ... up -d --no-deps web nginx
```

#### Issue #6 — web container crash-loop: `Cannot find module '/app/server.js'`

The image has `/app/server.js` baked in (Next.js standalone build), but
base compose bind-mounts `./web:/app` (dev hot-reload), overlaying the
image's built output with raw TypeScript source — no `server.js` there.

**Workaround:** patch demo override to clear web's inherited volumes.
Started with `volumes: !reset null`; later changed to
`volumes: !override` with explicit list when we needed to add the
`/data/videos` mount (see Issue #7).

```bash
# Live-edit on VPS via python script (idempotent)
python3 <<'PYEOF'
path = '/opt/studybuddy/docker-compose.demo.yml'
content = open(path).read()
old = '    volumes: !reset null\n'
new = '    volumes: !override\n      - /data/videos:/app/public/videos:ro\n'
if old in content:
    open(path, 'w').write(content.replace(old, new, 1))
PYEOF

docker compose --profile never -f ... up -d --force-recreate --no-deps web
```

#### Issue #7 — `seed.sh` path mismatch + `TEST_DB_URL` leak

```bash
docker compose ... exec api bash /app/scripts/demo/seed.sh
# → bash: /app/scripts/demo/seed.sh: No such file or directory
```

`seed.sh` expects to live at `/app/scripts/...` and `cd /app/backend`,
but in this compose layout `/app` IS the backend (bind from
`/opt/studybuddy/backend`) and `/scripts/` isn't bind-mounted into the
container at all. **Workaround:** skip the wrapper, run the 5 underlying
python seed scripts directly:

```bash
for s in seed_super_admin seed_demo_milfordwaterford seed_demo_test_account seed_phase_a_dev seed_dev_content; do
  docker compose ... exec -e TEST_DB_URL= api python scripts/${s}.py
done
```

The `-e TEST_DB_URL=` matters too — `alembic/env.py` line 23 has
`os.environ.get("TEST_DB_URL") or settings.DATABASE_URL`, and a stray
`TEST_DB_URL` in the .env.demo (pointing at `studybuddy_test` database)
meant migrations went to the wrong database initially. Blanking it via
the exec flag forces alembic + seeds to target `studybuddy`.

After running `alembic upgrade head -e TEST_DB_URL=` followed by all 5
seed scripts, `psql -c "\dt"` showed ~30 tables and seed scripts each
printed their `done` lines.

#### Issue #8 — Home page videos 404

Browser DevTools showed home page requests `/videos/StudyBuddy_BioStory.mp4`
returning 404. The 6 MP4s exist on the laptop at `web/public/videos/`
(BioStory, ChemStory, 4 Hydrocarbon\_\*), are **gitignored**, weren't in
the GHCR image, and `sync-content.sh` doesn't push them either.

```bash
# [vps] — create target dir
mkdir -p /data/videos && chown deploy:deploy /data/videos && chmod 775 /data/videos

# [laptop] — rsync
rsync -avh --progress web/public/videos/ deploy@178.105.160.62:/data/videos/

# [vps] — bind-mount to web (replaced earlier !reset null with !override + entry)
# (see Issue #6 — the python patch already did this in one step)

# [vps] — recreate web
docker compose --profile never -f ... up -d --force-recreate --no-deps web

# Test
curl -sI https://demo.usestudybuddy.com/videos/StudyBuddy_BioStory.mp4
# → HTTP/2 200, content-type: video/mp4 ✓
```

### Step 8 — DNS cutover + public smoke

```bash
# [browser] CF UI → usestudybuddy.com → DNS
#   - A record `demo`: 192.0.2.1 (Day -1 placeholder) → 178.105.160.62, proxy ON
#   - AAAA record `demo`: add 2a01:4f8:1c18:82e4::1, proxy ON
#   - SSL/TLS mode: confirmed Full (strict)
#   - Universal SSL: confirmed Active Certificate (do NOT touch — lesson from this morning)

# [laptop] DNS check
dig +short demo.usestudybuddy.com @1.1.1.1
# → 104.21.8.65, 172.67.138.160  (CF anycast IPs)

# [laptop] HTTP check
curl -sI https://demo.usestudybuddy.com/
# → HTTP/2 200, server: cloudflare ✓
```

### Step 9 — Browser walkthrough (the launch-validation moment)

Open `https://demo.usestudybuddy.com` in browser:

- ✅ Landing page renders, no cert warning, padlock visible
- ✅ Home page videos play (after Issue #8 fix)
- ✅ Register-for-test-run flow works end-to-end
- ✅ Email login works
- ✅ Teacher and student account access works as expected

**Demo is launched.**

---

### Step 10 — Post-launch: Grade 11 content population (partial — catalog still 0/0)

Operator reported that **Grade 11 Science Curriculum Catalog shows "0 Subjects, 0
Units"** despite teacher/student G11 accounts working. Multi-step fix sequence
revealed several latent issues:

**A. Container couldn't see rsynced curriculum content.** Same bind-mount pattern
as Issue #4 (api side): container's `/data/content/` is mounted from
`/opt/studybuddy/content_store_data/` (git-tracked, near-empty), not from
`/data/content/` on host where the operator's 220MB rsync landed. Symlink fix:

```bash
mv /opt/studybuddy/content_store_data /opt/studybuddy/content_store_data.preclone
ln -s /data/content /opt/studybuddy/content_store_data
docker compose --profile never -f ... up -d --force-recreate --no-deps api
# Container now sees all 16 curricula at /data/content/curricula/
```

**B. DB didn't have unit rows for G11 Science.** `seed_dev_content` only seeded
Grade 8. Ran `seed_content_db.py` to bulk-import 7 curricula × 128 units:

```bash
docker compose --profile never -f ... exec -e TEST_DB_URL= api \
  python scripts/seed_content_db.py
# default-2026-g11-science → 29 units inserted ✓
```

**C. `recover_curriculum.py --grade 11` only handled the `stem` variant.** The
script is hardcoded to load `grade{N}_stem.json` and write to
`default-{year}-g{N}`. No variant flag. **Workaround:** sed-patched the script
in-place to handle the science variant for this one run, then restored:

```python
src.replace('f"grade{grade}_stem.json"', 'f"grade{grade}_science.json"')
src.replace('f"default-{year}-g{grade}"', 'f"default-{year}-g{grade}-science"')
# ran for grade 11 → 4 content_subject_versions rows inserted (status=pending)
# restored original script
```

Also discovered the grade JSONs needed copying from `/opt/studybuddy/data/` to
`/opt/studybuddy/backend/data/` (recover_curriculum expects them at `/app/data/`
which is bind-mounted from the latter).

**D. subject_versions had status=pending and published_at=NULL.** Compared
against G8 (working in catalog) and found the differences. Fixed both:

```sql
UPDATE content_subject_versions
SET status = 'published',
    published_at = generated_at
WHERE curriculum_id = 'default-2026-g11-science';
```

**E. Catalog API STILL returns 0/0 — root cause unresolved.** After all of
A-D, `https://demo.usestudybuddy.com` G11 Science catalog still shows "0
Subjects, 0 Units" in the browser, and the API returns
`{"subject_count": 0, "unit_count": 0, "subjects": []}` for default-2026-g11-science.

Verified the DB is correct in every dimension we can test:

- `curriculum_units` has 29 rows (Biology=5, Chemistry=9, Mathematics=5, Physics=10)
- `content_subject_versions` has 4 rows (all `status=published`, `published_at` set)
- `classroom_packages` correctly links G11 Science classrooms → `default-2026-g11-science`
- No RLS policies exist on `curriculum_units` or `content_subject_versions`; `curricula` RLS allows `owner_type='platform'` rows in any context
- Running the API's exact catalog SQL (extracted from `src/school/service.py:700-810`) directly in psql returns the correct subjects array

Ruled out as causes:

- ❌ Redis cache (FLUSHALL didn't help)
- ❌ Stale api connection pool (`--force-recreate` api didn't help)
- ❌ Frontend cache (hard-refresh didn't help)
- ❌ Browser cache

The API's `list_catalog()` runs the same SQL via asyncpg but gets an empty
LATERAL-JOIN result. Suspected next-step culprits: middleware-injected SQL
filter, asyncpg query-parameter handling difference, schema/search_path
context mismatch, or stale bytecode in the running container. **Not
investigated further** — operator decided 8+ hour launch session was at its
limit; deferred to task #32 ([[#32 Debug StudyBuddy catalog API returning 0/0]]).

**Workaround for the launch:** ship the demo as-is. G8 catalog works as a
reference for what "populated" looks like. G11 teacher + student accounts work
for login/navigation/test-run flows. Curriculum-content browsing is the
specific feature broken until task #32 is resolved.

---

### Follow-ups created during this session

- [ ] **[#30](#) Fix StudyBuddy demo compose env_file + profiles hygiene** —
      the 5 compose-level workarounds (`--profile never`, two env-file
      symlinks, web volume override, broken healthcheck) all need to land
      in `docker-compose.demo.yml` so the next cold-start operator doesn't
      hit the same gauntlet.
- [ ] **[#31](#) Fix StudyBuddy demo smoke.sh** — script checks endpoints
      that don't match the deployed app (`/healthz`, `/readyz`,
      hardcoded `G8-MATH-001` unit IDs vs `default-2026-g8/...` from
      seed). App actually works; smoke is stale.
- [ ] **[#28](#) Deferred rename sweep (17 files)** —
      `backend/src/auth/router.py` Auth0 claim namespaces (requires
      coordinated Auth0 console update); 4 backend tests; 4 docs;
      7 Remotion video sources.
- [ ] **[#29](#) Pre-existing StudyBuddy CI failures** — Backend Tests +
      API Contract + ~138 Frontend Unit Tests have been failing since
      before today; not introduced by today's commits but worth a
      focused session.
- [ ] **StudyBuddy Stripe wiring** — `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET`
      left blank in `.env.demo` for this launch. Subscription endpoints
      will 500 if exercised; fix when a paying-customer flow is needed.
- [ ] **[#32](#) Debug catalog API 0/0 for G11 Science** — DB is correct,
      SQL works in psql, but API returns empty subjects/units. Needs an
      api-side debug session (add `print()` to `list_catalog`, or invoke
      it directly from python REPL inside the container).
- [ ] **Symlink fix needed for `seed_demo` re-runs** — replaced
      `/opt/studybuddy/content_store_data` with a symlink to `/data/content`
      so the rsynced content is visible to the container. Future
      `seed_dev_content` runs will write through this symlink. The original
      dir is preserved at `/opt/studybuddy/content_store_data.preclone`.
- [ ] **Variant-grade JSONs in `/app/data/`** — copied `grade*_{science,
commerce,humanities,english,advanced}.json` from `/opt/studybuddy/data/`
      to `/opt/studybuddy/backend/data/`. Without this, `recover_curriculum.py`
      won't find variant grade JSONs. Should be done at provision time.

---

## 2026-05-18 — Cold-start launch

**Operator:** Siva Mambakkam
**Duration:** ~3h (11:00 – 15:30 EDT / 15:00 – 19:30 UTC)
**Outcome:** ✅ Site live at https://mambakkam.net. All 10 smoke checks pass
from an external laptop. Auto-deploy pipeline validated end-to-end.

**Summary.** First-time provisioning of the shared CX23 (Hetzner NBG1) as
mambakkam.net's first tenant. `provision.sh` ran clean (14/14 steps). Two
incidents during cert install delayed T-0 by ~45 min: (1) a stale
3-host Origin Cert from an earlier dry-run got pasted instead of the
active 2-host cert → CF returned HTTP 526; (2) Universal SSL ended up
disabled in the CF UI at some point during 526 debugging → all TLS
handshakes failed (`sslv3 alert handshake failure`) until re-enabled.
Both recovered without operator data loss. Post-launch sweep landed
two small repo fixes (`smoke.sh` log path on laptop runs, deprecated
nginx `http2` syntax) and validated the GH Actions auto-deploy
pipeline on commits `9150458`, `994a99f`, `fbdb259`.

**Live state at end of session:**

| Item                     | Value                                                               |
| ------------------------ | ------------------------------------------------------------------- |
| VPS                      | Hetzner CX23, Nuremberg (NBG1), Ubuntu 24.04, name `mambakkam-cx22` |
| IPv4 / IPv6              | `178.105.160.62` / `2a01:4f8:1c18:82e4::1`                          |
| Cloudflare proxy         | Active (orange cloud on both A + AAAA records)                      |
| Cloudflare SSL/TLS mode  | Full (strict)                                                       |
| Cloudflare Origin Cert   | 2-host (`mambakkam.net`, `*.mambakkam.net`), 15-yr, RSA             |
| Host nginx               | 1.28.3, HTTP/2 on, deprecated `listen … http2` syntax removed       |
| Astro container          | `mambakkam-astrowind`, healthy, `127.0.0.1:8081 → 8080/tcp`         |
| GH Actions auto-deploy   | Enabled (`MAMBAKKAM_DEPLOY_ENABLED=true`); fires on push to main    |
| Daily restic backup cron | `30 2 * * *` UTC, repo at `/opt/mambakkam/backups/restic`           |

---

### Step 1 — Provision CX23 in Hetzner console

**[browser]** Hetzner Cloud console → Add Server. Config (matches Day -1
approved values):

- Location: Nuremberg (NBG1)
- Image: Ubuntu 24.04
- Type: Shared vCPU → CX23 (x86)
- Networking: IPv4 + IPv6
- SSH key: `mambakkam-launch-2026` (fingerprint MD5
  `70:96:3b:f0:97:9e:28:9d:bc:75:9f:41:28:aa:81:15`)
- No volumes / firewalls / placement groups; backups OFF
- Name: `mambakkam-cx22` (kept the `cx22` suffix to align with the
  alert-rule names defined in monitoring YAML)

Cost: ~$5.59/mo.

VPS came up with IPv4 `178.105.160.62`, IPv6 `2a01:4f8:1c18:82e4::1`.

### Step 2 — SSH into the VPS

```bash
# [laptop]
ssh -i ~/.ssh/mambakkam_cx22 -o StrictHostKeyChecking=accept-new root@178.105.160.62

# [vps] sanity check
uname -a
df -h /
free -h
```

### Step 3 — Run `provision.sh`

```bash
# [vps] as root
curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision.sh | bash
```

All 14 steps completed clean (~20 min). Key outputs to capture for the
operator password manager:

- **Restic backup password** printed once on stdout. Saved to password
  manager AND lives on disk at `/etc/restic/mambakkam.password` (mode
  600). Without this password, every restic snapshot is permanently
  unrecoverable — there is no escrow.

Script's "Next steps" printout still references the pre-split shared
cert design (mentions `demo.usestudybuddy.com` as a SAN on the
mambakkam cert). Ignored at install time per the two-cert split
discovered Day -1; documented as a follow-up to clean up the printout.

### Step 4 — Install Cloudflare Origin Cert (first attempt — STALE cert)

```bash
# [vps] as root — pasted cert + key from password manager
cat > /etc/ssl/cloudflare/origin-cert.pem <<'EOF'
[Origin Cert body — REDACTED; pasted from password manager]
EOF

cat > /etc/ssl/cloudflare/origin-key.pem <<'EOF'
[Private key — REDACTED]
EOF

chmod 600 /etc/ssl/cloudflare/origin-{cert,key}.pem
chown root:root /etc/ssl/cloudflare/origin-{cert,key}.pem
ls -la /etc/ssl/cloudflare/
nginx -t
```

`nginx -t` clean (with 4 unrelated deprecation warnings — separately
addressed in step 12). **At this point the cert pasted was a stale
3-host cert from an earlier dry-run, not the 2-host active cert
shown in CF UI. That mismatch caused the HTTP 526 incident later.**
See incident §A.

### Step 5 — Generate GH Actions deploy keypair + install pubkey

```bash
# [laptop] — generate dedicated deploy keypair (no passphrase, GH Actions can't type one)
ssh-keygen -t ed25519 -f ~/.ssh/mambakkam_deploy -C "gh-actions deploy@mambakkam" -N ""
cat ~/.ssh/mambakkam_deploy.pub  # copy this one line

# [vps] as root — append pubkey to deploy user's authorized_keys
cat >> /home/deploy/.ssh/authorized_keys <<'EOF'
[deploy pubkey — REDACTED]
EOF
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

# [laptop] verify
ssh -i ~/.ssh/mambakkam_deploy deploy@178.105.160.62 'whoami && id'
# → deploy
# → uid=1000(deploy) gid=1000(deploy) groups=1000(deploy),983(docker)
```

The `docker` group membership (gid 983) is what lets `deploy` run
`docker compose` without sudo.

### Step 6 — Add GitHub repo secrets + ungate workflow

```bash
# [laptop] — gh CLI sets all four in one go
gh secret set MAMBAKKAM_VPS_HOST     --repo wegofwd2020-hub/mambakkam-net --body "178.105.160.62"
gh secret set MAMBAKKAM_VPS_USER     --repo wegofwd2020-hub/mambakkam-net --body "deploy"
gh secret set MAMBAKKAM_VPS_SSH_KEY  --repo wegofwd2020-hub/mambakkam-net < ~/.ssh/mambakkam_deploy
gh variable set MAMBAKKAM_DEPLOY_ENABLED --repo wegofwd2020-hub/mambakkam-net --body "true"

gh secret list   --repo wegofwd2020-hub/mambakkam-net
gh variable list --repo wegofwd2020-hub/mambakkam-net
```

The `< ~/.ssh/mambakkam_deploy` redirect on the third secret keeps
the private key out of shell history / clipboard. After this step
the deploy workflow `.github/workflows/deploy-mambakkam.yml` is
ungated and will fire on every push to `main`.

### Step 7 — Audit `.env.demo`, reload nginx

```bash
# [vps] as root
cat /opt/mambakkam/.env.demo
```

Already launch-ready as provision.sh wrote it: `SITE_URL`,
`PLAUSIBLE_DOMAIN=mambakkam.net` populated, GA4 blank (using
Plausible), SMTP intentionally blank (no contact form ships
at launch).

No edit needed. Reloaded nginx so the Origin Cert pasted in step 4
takes effect:

```bash
# [vps] as root
sudo systemctl reload nginx
sudo systemctl status nginx --no-pager | head -10
sudo ss -tlnp | grep -E ':(80|443) '
```

nginx active, listening on `*:80`, `*:443`, `[::]:80`, `[::]:443`.

### Step 8 — Build + start mambakkam container

```bash
# [vps] as root — runs deploy.sh as the deploy user so docker state is owned correctly
sudo -u deploy bash /opt/mambakkam/scripts/launch/deploy.sh
```

~3 min for the first build (Astro + Tailwind + Leaflet from scratch).
Verified:

```bash
# [vps]
sudo -u deploy docker compose -f /opt/mambakkam/docker-compose.demo.yml ps
# → mambakkam-astrowind  Up 35 seconds (healthy)  127.0.0.1:8081->8080/tcp

curl -sI http://127.0.0.1:8081/ | head -5
# → HTTP/1.1 200 OK
# → Server: nginx/1.30.1
# → Content-Type: text/html

sudo -u deploy docker compose -f /opt/mambakkam/docker-compose.demo.yml logs --tail=20
```

The logs showed `deploy.sh` had already run `smoke.sh` automatically
against the container — all 10 routes hit via `mambakkam-smoke/1.0`
UA returning 200/404 as expected. Local smoke is implicitly part of
the deploy.

### Step 9 — Host-nginx → container sanity check (before DNS cutover)

```bash
# [vps] — fake the mambakkam.net SNI locally to test the actual vhost
curl -ksI --resolve mambakkam.net:443:127.0.0.1 https://mambakkam.net/ | head -10
# → HTTP/2 200
# → server: nginx/1.28.3 (Ubuntu)
# → content-type: text/html
# → strict-transport-security: max-age=31536000; includeSubDomains
# → ... etc
```

### Step 10 — Cloudflare DNS cutover

**[browser]** Cloudflare → mambakkam.net → DNS → Records:

- **A record** at `@`: change value from Day -1 placeholder
  `192.0.2.1` → `178.105.160.62`. **Proxy: orange cloud (ON).**
- **AAAA record** at `@`: add new, value `2a01:4f8:1c18:82e4::1`.
  Proxy ON.
- TTL: Auto (CF overrides when proxied)

**[browser]** Cloudflare → mambakkam.net → SSL/TLS → Overview: confirm
mode is **Full (strict)**.

Verified DNS propagation:

```bash
# [laptop]
dig +short mambakkam.net @1.1.1.1
# → 172.67.165.32
# → 104.21.11.38
```

Both are Cloudflare anycast edge IPs (CF proxy is in effect — NOT
the VPS IP).

### Step 11 — Public smoke from laptop (T-0 attempt)

```bash
# [laptop]
cd /home/sivam/Documents/code/projects/AIStuff/STEM_studybuddy/mambakkam-net
bash scripts/launch/smoke.sh https://mambakkam.net
```

❌ **FAILED. All 10 routes returned status 526.** That kicked off
incident §A.

After incident §A and §B resolved (see below), re-ran:

```bash
# [laptop] — final smoke that closed T-0
bash scripts/launch/smoke.sh https://mambakkam.net
```

```
=== mambakkam.net smoke check ===
    target: https://mambakkam.net
Home:
  ✓ GET / returns 200 + 'Mambakkam' in body
Sitemap:
  ✓ GET /sitemap-index.xml returns 200 + <sitemapindex>
People:
  ✓ GET /people lists Siva
  ✓ GET /people/siva-m returns 200 + 'Siva' in body
Landmarks:
  ✓ GET /landmarks returns 200
  ✓ GET /landmarks/ayyanar-shrine returns 200
Work:
  ✓ GET /work lists StudyBuddy
  ✓ GET /work/studybuddy-ondemand returns 200
404 handling:
  ✓ GET /missing-route returns 404 (not 200)
robots.txt:
  ✓ GET /robots.txt returns 200 + no blanket disallow
══ all smoke checks passed ══
```

**Site is live as of ~15:19 UTC.**

### Step 12 — Post-launch repo cleanups

After T-0 passed, three small fixes were committed + pushed:

```bash
# [laptop] — commit 9150458: fix smoke.sh's "No such file or directory"
#   error tail when run from laptop (LOG_DIR=/opt/mambakkam/logs absent)
git add scripts/launch/_log.sh
git commit -m "fix(launch): skip JSON logging when LOG_DIR isn't writable"
git push origin main

# [laptop] — commit 994a99f: clear the persistent prettier CI red on
#   7 launch-prep .md files (table re-alignment, zero content change)
npx prettier --write DOCS_INDEX.md Plans/ACCOUNT_SETUP.md \
  Plans/DEMO_LAUNCH_PLAN.md Plans/DEPLOYMENT_PLAN.md \
  Plans/LOGGING.md Plans/MONITORING.md scripts/docs_index/README.md
git add ...
git commit -m "style(docs): apply prettier to launch-prep docs"
git push origin main

# [laptop] — commit fbdb259: replace deprecated `listen … http2` syntax
#   in infra/nginx/mambakkam.net.conf with `http2 on;` directive
git add infra/nginx/mambakkam.net.conf
git commit -m "fix(nginx): use http2 directive instead of deprecated listen flag"
git push origin main
```

Verified the auto-deploy fires on each push:

```bash
# [laptop]
gh run list --repo wegofwd2020-hub/mambakkam-net --limit 5
```

| Commit    | Workflow             | Result                                                  |
| --------- | -------------------- | ------------------------------------------------------- |
| `9150458` | Deploy mambakkam.net | ✅ success in 43s                                       |
| `9150458` | GitHub Actions (CI)  | ❌ failure (prettier red, pre-existing)                 |
| `994a99f` | Deploy mambakkam.net | ✅ success in 43s                                       |
| `994a99f` | GitHub Actions (CI)  | ✅ success in 48s (first green CI after prettier sweep) |
| `fbdb259` | Deploy mambakkam.net | ✅ success                                              |
| `fbdb259` | GitHub Actions (CI)  | ✅ success                                              |

The nginx http2 fix on `fbdb259` is in the repo but **not yet
applied to the live host nginx** — the deploy workflow deliberately
does NOT touch host nginx config (a bad reload would also take
down the StudyBuddy co-tenant when it joins). Manually copied
afterward:

```bash
# [vps] as root
cp /opt/mambakkam/infra/nginx/mambakkam.net.conf /etc/nginx/sites-available/mambakkam.net.conf
grep -nE "listen 443|http2" /etc/nginx/sites-available/mambakkam.net.conf
# → 34: listen 443 ssl;
# → 36: http2 on;
# → 47: listen 443 ssl;
# → 49: http2 on;

nginx -t  # clean, no warnings
systemctl reload nginx

# Verify HTTP/2 still works
curl -ksI --resolve mambakkam.net:443:127.0.0.1 https://mambakkam.net/ | head -3
# → HTTP/2 200
# → server: nginx/1.28.3 (Ubuntu)
```

Side observation while doing the `git pull` on VPS to refresh
`/opt/mambakkam`:

```bash
# [vps]
cd /opt/mambakkam
sudo -u deploy git fetch origin main
# → error: cannot open '.git/FETCH_HEAD': Permission denied
sudo -u deploy git log --oneline -3
# → fbdb259 ... (HEAD -> main, origin/main)  ← repo IS at latest
```

`/opt/mambakkam/.git` is root-owned (clone was done as root in
`provision.sh`). Manual `git fetch` as `deploy` fails, but
`deploy-mambakkam.yml` works because its `git fetch + reset` runs
through a different code path. Captured as a follow-up.

---

### Incident §A — HTTP 526 from Cloudflare (stale Origin Cert)

**Symptom.** First public smoke attempt: all 10 routes returned 526.

**Diagnosis.** Verified the cert at `/etc/ssl/cloudflare/origin-cert.pem`
was a real CF Origin Cert, cert/key match, nginx serving it on both
v4 and v6:

```bash
# [vps]
openssl x509 -in /etc/ssl/cloudflare/origin-cert.pem -noout \
  -subject -issuer -dates -ext subjectAltName
# → DNS:*.mambakkam.net, DNS:demo.studybuddy.app.mambakkam.net, DNS:mambakkam.net
#   ← THREE SANs, including a weird `demo.studybuddy.app.mambakkam.net`

diff <(openssl x509 -in /etc/ssl/cloudflare/origin-cert.pem -noout -pubkey) \
     <(openssl pkey -in /etc/ssl/cloudflare/origin-key.pem -pubout) \
  && echo MATCH || echo MISMATCH
# → MATCH

# [laptop] — what cert is served on public IPv4 / IPv6
echo | openssl s_client -connect 178.105.160.62:443 -servername mambakkam.net 2>/dev/null \
  | openssl x509 -noout -subject -issuer
echo | openssl s_client -connect [2a01:4f8:1c18:82e4::1]:443 -servername mambakkam.net 2>/dev/null \
  | openssl x509 -noout -subject -issuer
# → both return the same 3-SAN cert ✓
```

Compared with Cloudflare UI → SSL/TLS → Origin Server: **CF showed
ONE active cert with only 2 SANs** (`*.mambakkam.net`,
`mambakkam.net`), expiring May 13, 2041.

**Root cause.** The cert pasted into `/etc/ssl/cloudflare/origin-cert.pem`
was a **stale cert from an earlier dry-run**, still stored in the
operator's password manager. It had been deleted from the CF UI at
some point and was no longer recognized by CF's edge → 526.

**Recovery.** Regenerated a fresh Cert A in CF UI:

- **[browser]** Cloudflare → SSL/TLS → Origin Server → Create Certificate
- Hostnames: `mambakkam.net`, `*.mambakkam.net` (only 2 — explicitly
  NOT the StudyBuddy domain per the two-cert split)
- Validity: 15 years, key type RSA
- Saved both cert AND key to password manager **immediately** (CF
  shows the key only once)

```bash
# [vps] as root — overwrite both files with the new cert + key
cat > /etc/ssl/cloudflare/origin-cert.pem <<'EOF'
[new 2-host cert body — REDACTED]
EOF
cat > /etc/ssl/cloudflare/origin-key.pem <<'EOF'
[matching new key — REDACTED]
EOF
chmod 600 /etc/ssl/cloudflare/origin-{cert,key}.pem
chown root:root /etc/ssl/cloudflare/origin-{cert,key}.pem

# Verify SAN list is now exactly 2 hosts
openssl x509 -in /etc/ssl/cloudflare/origin-cert.pem -noout -ext subjectAltName
# → DNS:*.mambakkam.net, DNS:mambakkam.net  ✓

# Verify cert/key match
diff <(openssl x509 -in /etc/ssl/cloudflare/origin-cert.pem -noout -pubkey) \
     <(openssl pkey -in /etc/ssl/cloudflare/origin-key.pem -pubout) \
  && echo MATCH || echo MISMATCH
# → MATCH

nginx -t && systemctl reload nginx
```

**Resolution time:** ~25 min. Memory written:
[[feedback-cf-origin-cert-mismatch]] to prevent recurrence on next
deploy or on the StudyBuddy second-tenant join.

---

### Incident §B — TLS handshake failure (Universal SSL disabled)

**Symptom.** After fixing incident §A, the smoke test now returned
status `000` (curl couldn't complete the connection at all). Direct
`curl -v` showed `TLS alert, handshake failure (552)` from CF before
HTTP traffic even started.

**Diagnosis.** Reproduced from BOTH the laptop and the VPS itself
(different continents → different CF PoPs) — same handshake failure
from both. Not a single-PoP propagation issue.

```bash
# [vps]
curl -v https://mambakkam.net 2>&1 | tail -25
# → * TLSv1.3 (IN), TLS alert, handshake failure (552):
# → curl: (35) TLS connect error: error:0A000410:SSL routines::ssl/tls alert handshake failure
```

**Root cause.** Cloudflare's **edge certificate (Universal SSL) was
disabled** for the zone — the "Manage Edge Certificates" section in
CF UI showed "No certificates." CF had nothing to present during
the visitor → edge TLS handshake. Likely got toggled off at some
point during incident §A debugging (the "Disable Universal SSL"
button is prominent on the same page where origin cert troubleshooting
happens).

**Recovery.**

- **[browser]** Cloudflare → mambakkam.net → SSL/TLS → Edge Certificates → scroll to bottom
- Click **Disable Universal SSL** → confirm (kills any pending state)
- Wait 30s
- Click **Enable Universal SSL** → confirm
- Wait ~5 min for CF to re-issue the edge cert (DCV automatic for
  domains using CF nameservers)

After re-provisioning, the smoke ran clean. **Resolution time:**
~10 min from diagnosis to fix.

Memory updated: [[feedback-cf-origin-cert-mismatch]] now also warns
against clicking "Disable Universal SSL" during cert debugging.

---

### Follow-ups created during this session

- [ ] **StudyBuddy second-tenant join** — separate provision script in
      `StudyBuddy_OnDemand/scripts/demo/provision.sh`. Original plan
      had this at T+4h on launch day; deferred. Will install
      Cert B (usestudybuddy.com zone) and add its own daily backup
      cron at `02:00 UTC` (30 min before mambakkam's).
- [ ] **Monitoring stack** — `provision.sh` scaffolded
      `/opt/mambakkam/infra/monitoring/.env.monitoring`; not running
      yet. To activate: fill in Grafana Cloud + StudyBuddy token,
      then `cd /opt/mambakkam/infra/monitoring && docker compose --env-file .env.monitoring up -d`.
- [ ] **Revoke the stale 3-host Origin Cert** in CF UI (cleanup;
      site is using the new 2-host cert now). Two active certs
      were kept during incident §A as a fallback — the old one can
      be safely revoked now.
- [ ] **Fix `/opt/mambakkam/.git` ownership** so `deploy` user can
      `git fetch` (clone was done as root in `provision.sh`).
      Non-blocking; auto-deploy still works.
- [ ] **Patch `provision.sh` Next-Steps printout** — the SAN list
      it prints for the Origin Cert still says
      `demo.usestudybuddy.com` (pre-two-cert-split design). Cosmetic.
- [ ] **`support@/sales@` outbound mail** — deferred; needs paid mail
      provider (Cloudflare Email Routing has no outbound SMTP).
      See [[launch-gmail-sendas-deferred]].

---
