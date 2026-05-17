# mambakkam.net — Deployment Plan — Day 0 (Sun May 17) Launch Hosting

**Document version:** 1.0
**Date:** 2026-05-09
**Purpose:** Describe the hosting architecture for the Day 0 (Sun May 17) launch — what's
in the environment, what's deliberately not, and how it's configured.
**Companion docs:**

- [`DEMO_LAUNCH_PLAN.md`](DEMO_LAUNCH_PLAN.md) — the day-by-day cutover runbook
- [`DEMO_HOSTING_GUIDE.md`](https://github.com/wegofwd2020-hub/studybuddy-docs/blob/main/docs/dev/DEMO_HOSTING_GUIDE.md) — StudyBuddy's equivalent (this doc is its mambakkam.net analogue)

This is the "what" and "why" of the launch hosting. For "what to do on Day 0 (Sun May 17)",
read the launch plan. For step-by-step shell commands, read `scripts/launch/*.sh`.

---

## Same Repo, One Environment

The site is fully containerised via `docker-compose.demo.yml`. The application
code does not change between local dev and the launch VPS. What changes is:

- **The host** — operator's laptop (`docker-compose.yml` on `0.0.0.0:8080`)
  vs. the Hetzner CX22 (`docker-compose.demo.yml` on `127.0.0.1:8081`)
- **The compose file** — base for dev convenience, demo overlay for production
  shape (restart:always, healthcheck, resource limits, named log volume)
- **The fronting** — local has no proxy; the VPS has a host-level nginx
  vhost terminating SSL via Cloudflare Origin Cert

A change merged to `main` flows to the VPS automatically via
`.github/workflows/deploy-mambakkam.yml`. **One pipeline, one target.**

---

## Recommended Stack: Co-located Hetzner CX22 + Cloudflare (~$7/mo total)

mambakkam.net is the **first tenant** on a Hetzner CX22 box that will
also host `demo.usestudybuddy.com` later the same day. Host nginx routes by
Host header. mambakkam.net pays the $5/mo VPS bill plus the ~$1/mo
domain — total ~$6/mo all-in. StudyBuddy joins as a second tenant at
**zero marginal infra cost** from its side. (This inverts the framing
from 2026-05-08, when StudyBuddy was assumed to bootstrap the box first;
see Change Log.)

```
┌─ Hetzner CX22 (single VPS, ~$7/mo total) ───────────────────┐
│  2 vCPU · 4 GB RAM · 40 GB SSD                               │
│                                                              │
│  HOST nginx  (apt; :80 + :443)                               │
│      │                                                       │
│      ├─ mambakkam.net          → 127.0.0.1:8081              │
│      │       (this project's astrowind container)            │
│      │                                                       │
│      └─ demo.usestudybuddy.com    → 127.0.0.1:8443              │
│              (StudyBuddy stack's compose-internal nginx)     │
│                                                              │
│  /opt/mambakkam/        (this project — git clone)           │
│    └─ docker compose: 1 container (nginx serving dist/)      │
│                                                              │
│  /opt/studybuddy/       (sibling project)                    │
│    └─ docker compose: 7 containers (db, redis, api, ...)     │
│                                                              │
│  /etc/ssl/cloudflare/   (shared Origin Cert + key)           │
│    SAN = mambakkam.net + *.mambakkam.net + demo.usestudybuddy.com│
└──────────────────────────────────────────────────────────────┘
                          │
                  Cloudflare (free tier)
            DNS · DDoS · TLS at edge · CDN cache
                          │
            mambakkam.net + demo.usestudybuddy.com
```

### Why co-locate

- **~$0 marginal cost on the StudyBuddy side.** mambakkam.net pays the
  $5/mo CX22 bill as the first tenant. StudyBuddy joins for free on the
  infra side — its own ~$2/mo line items (Auth0 free tier, Stripe-test,
  GHCR egress) are unrelated to the VPS. A second VPS would double the
  operational surface for no benefit at the static-site traffic forecast.
- **One ops surface.** Same SSH access, same fail2ban / UFW config, same
  backup schedule (mambakkam at 02:30 UTC, StudyBuddy at 02:00 UTC, offset
  by 30 min to avoid disk I/O collision).
- **One Cloudflare Origin Cert.** Generated once on Day -1 (Sat May 16) by the
  mambakkam.net cold-start operator with both hostnames in the SAN; one
  renewal cycle covers both projects.
- **Same tooling cadence.** `apt-get upgrade -y` once a quarter handles both.

### Trade-off accepted

- **Shared failure domain.** A VPS reboot (planned or panic) takes both sites
  down for ~60s. Acceptable for a launch with no production-traffic forecast;
  re-evaluate if either site lands a paying customer.

### Monthly cost breakdown

| Item                                | Provider                                                   | Cost to mambakkam.net         |
| ----------------------------------- | ---------------------------------------------------------- | ----------------------------- |
| VPS (Hetzner CX22)                  | Hetzner Cloud                                              | $5 (full bill — first tenant) |
| Domain `mambakkam.net`              | Cloudflare Registrar                                       | ~$1 (annual ÷ 12)             |
| SSL certificate                     | Cloudflare (Universal at edge) + Origin Cert (free, 15-yr) | $0                            |
| DNS + DDoS protection + CDN         | Cloudflare free tier                                       | $0                            |
| Email — inbound forwarding          | Cloudflare Email Routing → personal Gmail (free)           | $0                            |
| Backups (image rsync + log archive) | Local to VPS                                               | $0                            |
| GitHub Actions CI/CD                | Free (public repo)                                         | $0                            |
| **Total**                           |                                                            | **~$6/month**                 |

StudyBuddy joins as a second tenant for $0 marginal infra cost; its own
costs (Auth0, Stripe-test, GHCR) are tracked in StudyBuddy's launch plan
and unrelated to this box.

### Alternatives considered

| Platform                                         | Monthly cost | Decided not to pick because…                                                                                           |
| ------------------------------------------------ | ------------ | ---------------------------------------------------------------------------------------------------------------------- |
| **Co-located Hetzner CX22 (mambakkam first)** ⭐ | ~$6 all-in   | Chosen — see "Why co-locate" above                                                                                     |
| Dedicated Hetzner CX22 (mambakkam-only)          | $6           | Same cost since mambakkam pays the bill anyway; co-locating just buys back the value of the second slot for StudyBuddy |
| Cloudflare Pages                                 | $0           | Best long-term fit, but committing during launch week is risky; decided to revisit post-launch                         |
| Netlify / Vercel                                 | $0 hobby     | Same as Pages — defer the move                                                                                         |

---

## What This Environment Does NOT Have

These are intentional omissions for the Day 0 (Sun May 17) launch. None of them affect
what a visitor sees.

- **No app backend** — site is fully static. No DB, no auth, no API routes.
- **No real-time features** — no comments, no live chat, no notifications.
- **No headless CMS** — content authored as markdown in `src/data/`,
  committed via PR. (Migrating to Decap/Tina later is a hosting change with
  no code rewrite.)
- **No contact form** — no app-originated email, no SMTP integration in
  the running container. `siva@mambakkam.net` is inbound-only via
  Cloudflare Email Routing (forwarded to personal Gmail); outbound is
  Gmail send-as in alias mode. When a contact form ships, pair it with
  a paid mail provider (Zoho Mail Lite, Migadu, Fastmail) for SMTP +
  DKIM alignment.
- **No analytics at runtime** — Plausible/GA4 decision is open
  (`DEMO_LAUNCH_PLAN.md` §6); shipping after first quiet week post-launch.
- **No staging environment 24×7** — `staging.mambakkam.net` exists only
  during the May 13–16 test phase (Day -4 to Day -1), then is taken down.
- **No application metrics shipped to Prometheus** — observability is just
  Cloudflare Analytics + nginx access logs.
- **No autoscaling / HA** — single container on a single VPS. If it goes down,
  the site goes down. Acceptable at this scale.

If anyone asks: "this is the primary site for the village/personal brand, not a
multi-tenant app. The architectural simplicity is the point."

---

## Configuration Choices

These choices keep cost and operational overhead at the floor without changing
what the visitor sees.

### 1. Static-only Astro build

```
npm run build  →  dist/  →  COPY dist/ /usr/share/nginx/html/
```

`output: 'static'` in `astro.config.ts`. Every page is pre-rendered HTML at
build time. Runtime is read-only nginx serving files from disk. No server-side
rendering, no edge functions, no incremental static regeneration.

### 2. Co-tenant port discipline

The base `docker-compose.yml` publishes on `0.0.0.0:8080` for local-dev
convenience. The production overlay (`docker-compose.demo.yml`) is
**standalone** (not layered) and binds **only** to `127.0.0.1:8081`. The host
nginx is the single :80 + :443 entry point. Never publish to `0.0.0.0` on the
VPS — that bypasses Cloudflare and the host nginx vhost.

### 3. One Cloudflare Origin Cert covers both domains

A single Origin Cert with SAN = `mambakkam.net, *.mambakkam.net,
demo.usestudybuddy.com` is **generated up-front during the mambakkam.net cold
start on Day -1 (Sat May 16)** (mambakkam.net is the first tenant on the box) and lives
at `/etc/ssl/cloudflare/origin-{cert,key}.pem`. Read by the host nginx
vhost. Cloudflare's "Full (strict)" SSL/TLS mode verifies the chain.
StudyBuddy reuses the same cert when it joins on Day 0 (Sun May 17) — no re-issue.

### 4. Cloudflare Email Routing + Gmail send-as (zero-cost, demo-grade)

Inbound: Cloudflare Email Routing auto-adds MX + SPF, forwards
`siva@mambakkam.net` (and any catch-all) to the operator's personal
Gmail. Outbound: Gmail send-as in "Treat as alias" mode — Gmail's own
outbound, From header rewritten. DMARC at `p=none` since alias-mode
mail signs DKIM as `gmail.com` not `mambakkam.net` (no DMARC alignment).
No SMTP integration with the running container at launch.

When a contact form ships or real inbound volume justifies a separate
inbox, upgrade to a paid mail provider (Zoho Mail Lite ~$12/yr, Migadu
~$19/yr, Fastmail ~$36/yr) — that gives you provider SMTP + domain-aligned
DKIM, at which point DMARC can tighten to `p=quarantine`. Original Zoho
free-tier plan was scratched on 2026-05-16 after Zoho hid the Forever
Free Plan signup for new accounts.

### 5. Git is the source of truth

All code, content (markdown), and image assets are in the repo. The deploy
sequence is `git fetch && git reset --hard origin/main && docker compose
build && up -d`. There are no out-of-band content uploads. `backup.sh` only
covers nginx access logs + image assets (the latter as belt-and-suspenders).

### 6. No runtime secrets

The container runs nginx on a static `dist/`. Build-time env (`.env.demo`) is
limited to an analytics ID. No DB credentials, no auth tokens, no third-party
API keys are required to run the site.

### 7. Auto-deploy on merge, manual rollback

`.github/workflows/deploy-mambakkam.yml` deploys every push to `main`. On
smoke failure, an `incident:mambakkam` issue is filed. Rollback is intentionally
**not** automated — a `git revert` + push redeploys the previous SHA in ~3
minutes, which is fast enough that operator review beats a surprise revert.

---

## Step-by-Step Deployment

The detailed runbook lives in
[`DEMO_LAUNCH_PLAN.md` §2.5](DEMO_LAUNCH_PLAN.md#25--deployment-sequence-consolidated).
The condensed flow:

### Cold start (one-time, ~15 min)

```bash
# On the Hetzner VPS, as root:
curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision.sh | bash

# Confirm Cloudflare Origin Cert is in place at /etc/ssl/cloudflare/origin-*.pem
# Paste GH Actions deploy SSH pubkey to /home/deploy/.ssh/authorized_keys

# Build + start the container:
sudo -u deploy bash /opt/mambakkam/scripts/launch/deploy.sh

# Verify before DNS cutover:
bash /opt/mambakkam/scripts/launch/smoke.sh http://127.0.0.1:8081

# Cut DNS at Cloudflare (apex A → VPS IP, proxied), then:
bash /opt/mambakkam/scripts/launch/smoke.sh https://mambakkam.net
```

### Ongoing (every push to main, ~3 min, automatic)

```
git push origin main
   │
   ▼
GitHub Actions: deploy-mambakkam.yml
   │
   ├── SSH to VPS as deploy@<host>
   ├── /opt/mambakkam/scripts/launch/deploy.sh
   │     ├── git fetch + reset --hard origin/main
   │     ├── docker compose -f docker-compose.demo.yml \
   │     │     --env-file .env.demo up -d --build --remove-orphans
   │     ├── wait 15s, healthcheck settles
   │     └── local smoke: scripts/launch/smoke.sh http://127.0.0.1:8081
   │
   ├── Public-side smoke from runner: scripts/launch/smoke.sh https://mambakkam.net
   │
   └── (smoke red) → file `incident:mambakkam` issue with triage checklist
```

---

## Pre-Launch Checklist

The full checklist with verification commands is in
[`DEMO_LAUNCH_PLAN.md` §1](DEMO_LAUNCH_PLAN.md#1--what-to-complete-before-may-12-4-days-code-freeze-cutoff).
Quick-check before showing anyone the site:

### Infrastructure

- [ ] Cloudflare DNS apex A record points at VPS public IP, **Proxied**
- [ ] `dig mambakkam.net +short` returns a Cloudflare-edge IP, not the VPS IP
- [ ] SSL/TLS mode = Full (strict); Always Use HTTPS = on
- [ ] Origin Cert in place at `/etc/ssl/cloudflare/origin-{cert,key}.pem`
- [ ] `docker compose -f docker-compose.demo.yml ps` shows `Up (healthy)`
- [ ] `bash scripts/launch/smoke.sh https://mambakkam.net` exits 0

### Email

- [ ] Cloudflare Email Routing enabled for mambakkam.net (auto-MX + SPF visible in DNS)
- [ ] `_dmarc` TXT present (`v=DMARC1; p=none; rua=mailto:...`)
- [ ] Inbound test: external sender → `siva@mambakkam.net` lands in personal Gmail
- [ ] Outbound test: Gmail send-as for `siva@mambakkam.net` round-trips a test email

### Content

- [ ] Every navigation entry resolves (home, news, people, landmarks, work)
- [ ] `/work/studybuddy-ondemand` outbound link reaches `demo.usestudybuddy.com` cleanly
- [ ] Coming-soon work items (Thittam) render unlinked with a "Coming soon" pill
- [ ] `/sitemap-index.xml` lists every public page
- [ ] `/robots.txt` does NOT contain a blanket `Disallow: /`

---

## Maintenance — One Pipeline, One Target

The deploy design keeps the maintenance burden of running the site to **~30
minutes per month**, mostly content refresh.

```
Operator pushes to main
        │
        ▼
GitHub Actions  (deploy-mambakkam.yml)
        │
        ├── ssh + scripts/launch/deploy.sh
        │     (compose build + up -d + local smoke)
        │
        └── public smoke on https://mambakkam.net
                │
                ├── (green) — done, no notification
                │
                └── (red) — file incident:mambakkam issue, no auto-rollback
```

| Concern               | How it's handled                                                                                    |
| --------------------- | --------------------------------------------------------------------------------------------------- |
| Deploy a code change  | Auto on merge to main                                                                               |
| Restart the container | `ssh vps; docker compose -f docker-compose.demo.yml restart`                                        |
| Backups               | nightly cron at 02:30 UTC: image rsync + nginx access log archive; 7-day retention                  |
| Monitor errors        | Cloudflare Analytics (traffic shape) + grep nginx logs (5xx rate)                                   |
| Update SSL cert       | Cloudflare auto-renews edge; Origin Cert is 15-year validity                                        |
| Scale up              | Cloudflare CDN auto-handles cache; for origin pressure, move to Cloudflare Pages (zero code change) |

---

## Future Scale-up (Defer Until Triggered)

The static-site architecture is the load-bearing decision: every graduation
below is a hosting swap, not a code rewrite. Don't pre-optimize.

| Trigger                              | Action                                                                        | New cost |
| ------------------------------------ | ----------------------------------------------------------------------------- | -------- |
| StudyBuddy traffic eats CX22 RAM/CPU | Move mambakkam to Cloudflare Pages                                            | $0       |
| Operator wants out of VPS admin      | Cloudflare Pages                                                              | $0       |
| Content team grows                   | Add Decap CMS or TinaCMS (still static output, editors via UI)                | $0       |
| Tamil i18n launches                  | Astro i18n routing; same hosting                                              | $0       |
| Cloudflare Pages free-tier cap hit   | Pages Pro                                                                     | $20/mo   |
| Newsletter/contact form ships        | Sign up for paid mail provider (Zoho Mail Lite ~$12/yr or Migadu ~$19/yr); replace Cloudflare Email Routing MX with provider's MX; add SMTP_* env vars; tighten DMARC to `p=quarantine` | ~$1–2/mo |

---

## Troubleshooting

| Symptom                                                  | Likely cause                                                                          | Fix                                                                                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `502 Bad Gateway` from Cloudflare                        | Container down or host nginx can't reach `127.0.0.1:8081`                             | `docker compose -f docker-compose.demo.yml ps` — check `Up (healthy)`; if not, `docker compose logs astrowind`                                   |
| `Error 521` (Cloudflare can't reach origin)              | UFW blocking inbound 443, OR host nginx not running                                   | `ufw status; systemctl status nginx; nginx -t`                                                                                                   |
| `SSL_ERROR_NO_CYPHER_OVERLAP`                            | Cloudflare set to Full (strict) but Origin Cert missing/expired                       | Check `/etc/ssl/cloudflare/origin-cert.pem`; regenerate at Cloudflare → SSL/TLS → Origin Server                                                  |
| HTTPS works but redirect loops on `www`                  | Cloudflare Page Rule conflicts with `Always Use HTTPS`                                | Disable the Page Rule and let the host vhost handle the www→apex 301                                                                             |
| Pages render but `/_astro/*.css` 404                     | `npm run build` failed silently or `dist/` is stale                                   | SSH to VPS; `cd /opt/mambakkam && docker compose -f docker-compose.demo.yml build --no-cache && docker compose -f docker-compose.demo.yml up -d` |
| `Coming soon` pill missing on Thittam card               | `comingSoon: true` not set in `src/data/work/thittam.md` frontmatter, OR build cached | Verify frontmatter; clear cache with `--no-cache` build                                                                                          |
| Deploy workflow fails at "Run deploy.sh on VPS"          | `MAMBAKKAM_VPS_SSH_KEY` repo secret stale, OR deploy user's `authorized_keys` rotated | Regenerate SSH key pair; update both repo secret and `/home/deploy/.ssh/authorized_keys`                                                         |
| Smoke check fails on `/people/siva-m` after content edit | Slug changed (filename rename)                                                        | Astro slug = filename; verify `src/data/people/siva-m.md` exists; if intentionally renamed, update smoke.sh slug                                 |
| Daily backup cron didn't run                             | cron service died or `/etc/cron.d/mambakkam-backup` got removed                       | `service cron status; ls /etc/cron.d/mambakkam-backup`; re-run `provision.sh` (idempotent)                                                       |

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-09 | 1.0     | Initial — Day 0 (Sun May 17) launch hosting plan, modeled on StudyBuddy's `DEMO_HOSTING_GUIDE.md`                                                                                                                                                                                                                                                                                                                                     |
| 2026-05-09 | 1.1     | **Tenancy-order flip** — mambakkam.net is now the first tenant on a fresh CX22; pays the full $5/mo VPS bill (~$6/mo all-in with the domain). StudyBuddy joins as second tenant on Day 0 (Sun May 17) at zero marginal infra cost. Origin Cert with SAN list (covering both domains) is generated up-front during the mambakkam.net cold start on Day -1 (Sat May 16). Cron offsets: mambakkam at 02:30 UTC, StudyBuddy at 02:00 UTC. |
| 2026-05-16 | 1.2     | **Email provider switch** — Zoho Forever Free Plan no longer reliably available for new signups; replaced with Cloudflare Email Routing (inbound-only forwarding to personal Gmail, free) + Gmail send-as in alias mode for outbound. Cost row, §4 narrative, launch checklist, and "contact form ships" trigger row all updated. DMARC posture relaxed to `p=none` for the demo (no domain-aligned DKIM in alias mode). |
| 2026-05-16 | 1.3     | **Domain rename — studybuddy.app → usestudybuddy.com.** studybuddy.app was unavailable at registration; usestudybuddy.com chosen as fallback. Subdomain convention preserved: `demo.usestudybuddy.com`. All body references updated; Origin Cert SAN regenerated. Cross-doc sweep across MONITORING/LOGGING/RUNBOOK/BACKUPS and infra (nginx/prometheus/alerts/provision) executed in the same pass. |
