# mambakkam.net — Launch Plan (target: Day 0 / Sun 2026-05-17)

**Audience:** Sivakumar (operator) · future on-call deputy
**Document type:** End-to-end runbook from "today's main branch" → "live site at `https://mambakkam.net`"
**Companion docs:**

- [`DEMO_LAUNCH_PLAN.md`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/docs/DEMO_LAUNCH_PLAN.md) (StudyBuddy_OnDemand — co-tenant on the same Hetzner CX22)
- [`DEMO_HOSTING_GUIDE.md`](https://github.com/wegofwd2020-hub/studybuddy-docs/blob/main/docs/dev/DEMO_HOSTING_GUIDE.md) (Hetzner-based architecture rationale)
- [`dns-and-email-setup.md`](https://github.com/wegofwd2020-hub/studybuddy-docs/blob/main/docs/operations/dns-and-email-setup.md) (Cloudflare DNS + Zoho Mail pattern, applied here to `mambakkam.net`)

mambakkam.net is the **primary site** for the Day 0 (Sun May 17) launch and the **first
tenant** on a fresh Hetzner CX22 box. StudyBuddy_OnDemand
(`demo.usestudybuddy.com`) launches the same day, **later in the morning**, by
joining the same CX22 as a second tenant. mambakkam.net's `provision.sh`
performs the full system bootstrap (Docker, UFW, fail2ban, deploy user,
Origin Cert directory, daily-backup cron); StudyBuddy's provisioning is the
shorter "second-tenant" variant that reuses what's already there.

**Launch order on Day 0 (Sun May 17):**

1. mambakkam.net cuts over at **T-0 = 09:00 EST** (full runbook in §2 below).
2. StudyBuddy joins the same box and cuts over at **T+4h = 13:00 EST** once
   mambakkam.net has shown ~4 hours of stable Cloudflare-edge traffic. See
   the StudyBuddy launch plan for its own runbook:
   [`StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/docs/DEMO_LAUNCH_PLAN.md).

---

## Timeline at a Glance

```
May 8  (Fri) ──┐
May 9  (Sat)   │  CODE FREEZE PHASE — automation + last-mile fixes
May 10 (Sun)   │
May 11 (Mon)   │
May 12 (Tue) ──┤◀─── Day -5   code-freeze cutoff (no app changes after EOD)
May 13 (Wed)   │     Day -4   ┐
May 14 (Thu)   │     Day -3   │  TEST PHASE — staging deploy + walkthroughs
May 15 (Fri)   │     Day -2   │
May 16 (Sat)   │     Day -1 ──┘  Regression sweep + final go/no-go (EOD)
May 17 (Sun) ──┴───  Day  0      LAUNCH · accounts · email · host setup · DNS cutover
May 18 (Mon)         Day  1      First day live · monitoring · smoke
```

Eight calendar days from today (2026-05-09) to Day 0 launch (2026-05-17).
The original 2026-05-08 plan targeted May 16 launch; this revision (per
2026-05-09 change log) shifts launch to May 17, retains the May 12 EOD
code-freeze cutoff, and shifts the 4-day test phase to May 13-16.

---

## §0 · Architecture — Co-located on the StudyBuddy Hetzner CX22

```
┌─ Hetzner CX22 (single VPS, ~$7/mo total) ───────────────────┐
│                                                              │
│  HOST nginx  (Ubuntu apt, listens on :80 + :443)             │
│      │                                                       │
│      ├─ Host: mambakkam.net          → 127.0.0.1:8081        │
│      │       (this project's astrowind container)            │
│      │                                                       │
│      └─ Host: demo.usestudybuddy.com    → 127.0.0.1:8443        │
│              (StudyBuddy stack's compose-internal nginx)     │
│                                                              │
│  /opt/mambakkam/         (this project — git clone)          │
│    └─ docker compose: 1 container (astrowind/nginx-static)   │
│                                                              │
│  /opt/studybuddy/        (sibling project)                   │
│    └─ docker compose: 7 containers (db, redis, api, ...)     │
│                                                              │
│  /etc/ssl/cloudflare/    (shared Origin Cert + key)          │
│    ├─ origin-cert.pem    (covers *.mambakkam.net + sb.app)   │
│    └─ origin-key.pem                                         │
└──────────────────────────────────────────────────────────────┘
                            │
                    Cloudflare (free tier)
              DNS · DDoS · SSL termination at edge
                            │
              mambakkam.net + demo.usestudybuddy.com
```

**Why co-locate.** The static site uses a few hundred KB of memory and ~zero
CPU. Running a second VPS would double the bill ($14/mo vs ~$7/mo) for no
practical isolation gain on a launch with no production traffic forecast.
Both projects' lifecycles are operator-driven; a coordinated reboot is fine.

**Tenancy order (decided 2026-05-09).** mambakkam.net is the **first tenant**
on the box: it pays the $5/mo VPS bill (plus ~$1/mo domain) and its
`provision.sh` performs the full system bootstrap. StudyBuddy joins as the
second tenant later the same day, at zero marginal infra cost from its
side. This inverts the original 2026-05-08 framing (which assumed
StudyBuddy provisioned first); see Change Log.

**Listening-port discipline.** Both compose stacks publish on `127.0.0.1:<port>`
only — never `0.0.0.0`. The host's `nginx` is the single entry point on
:80 + :443. This is enforced in `docker-compose.demo.yml` (this repo) and
verified during the cold-start dry-run.

**Cloudflare Origin Cert.** A single Cloudflare Origin Certificate covers
both `mambakkam.net` (apex + `www`) and `demo.usestudybuddy.com`. Generated
once via the Cloudflare dashboard with both hostnames in the SAN list.
Lives at `/etc/ssl/cloudflare/origin-cert.pem` and is read by host nginx.

---

## §1 · What to Complete Before Day -5 (Tue May 12) Code-Freeze Cutoff

Three categories: **automation** (must), **content** (must), **polish** (nice-to-have if time permits).

### 1.A Automation — must-have for Day 0 (Sun May 17) (this commit ships them)

These ship with this PR. Use them as-is; no further code work needed.

| Deliverable                  | File                                                                                  | Purpose                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Production compose           | [`docker-compose.demo.yml`](../docker-compose.demo.yml)                               | Standalone production-shaped compose: binds to `127.0.0.1:8081`, `restart: always`, named log volume, healthcheck          |
| First-time provisioning      | [`scripts/launch/provision.sh`](../scripts/launch/provision.sh)                       | Idempotent Hetzner CX22 add-on — host nginx install, `/opt/mambakkam` clone, deploy user, vhost dropped, daily-backup cron |
| Manual / CI deploy           | [`scripts/launch/deploy.sh`](../scripts/launch/deploy.sh)                             | `git pull && docker compose build && up -d` + post-deploy smoke                                                            |
| Post-deploy smoke check      | [`scripts/launch/smoke.sh`](../scripts/launch/smoke.sh)                               | Curl-based: `/`, `/sitemap-index.xml`, key landing-page words present, 404 returns 404                                     |
| Daily content backup         | [`scripts/launch/backup.sh`](../scripts/launch/backup.sh)                             | restic-based, encrypted at-rest. Sources: `src/assets/images/` + `/var/log/nginx/mambakkam.net.*` + `/etc/ssl/cloudflare/` + `.env.demo` → `restic forget` with 7d/4w/3m/1y policy. Cron 02:30 UTC. |
| Weekly restic check + prune  | [`scripts/launch/backup-check.sh`](../scripts/launch/backup-check.sh)                 | `restic check --read-data-subset 5%` (silent bit-rot detection) → `restic prune --max-unused 5%` (reclaim disk that daily `forget`s marked unreferenced). Cron Sun 03:30 UTC, 1h after the daily so they don't compete for the repo lock. |
| Host nginx vhost             | [`infra/nginx/mambakkam.net.conf`](../infra/nginx/mambakkam.net.conf)                 | SSL termination via Cloudflare Origin Cert; proxy_pass to `127.0.0.1:8081`; HSTS; gzip; long-cache for `/_astro/*`         |
| Auto-deploy on merge to main | [`.github/workflows/deploy-mambakkam.yml`](../.github/workflows/deploy-mambakkam.yml) | SSH to Hetzner → `scripts/launch/deploy.sh` → smoke against public domain → open issue on failure                          |
| Env skeleton                 | [`.env.demo.example`](../.env.demo.example)                                           | Placeholders for analytics ID + Zoho SMTP (future contact form)                                                            |

### 1.A.bis Domain + Email — must-have

Out-of-repo deliverables. Track each by ticking the checkbox; the "verify by"
column is the green-light command.

#### Phase 1 — Domain at Cloudflare (~10 min)

mambakkam.net is presumed already registered (see git config / current owner).
The work here is moving DNS to Cloudflare nameservers (or, if already there,
verifying the zone is healthy).

- [ ] `mambakkam.net` zone is on Cloudflare nameservers
      · _verify:_ `dig NS mambakkam.net` returns `*.ns.cloudflare.com`
- [ ] Universal SSL is **Active** in Cloudflare → SSL/TLS → Edge Certificates
      · _verify:_ `curl -vI https://mambakkam.net` shows a valid Cloudflare-edge cert (until DNS cutover, this is on the existing host — a 200/301 from anywhere is fine)
- [ ] Existing DNS records audited; any stale Netlify/Vercel A/AAAA records flagged for deletion at cutover
      · _verify:_ Cloudflare DNS UI lists exactly the records this plan calls for

#### Phase 2 — Cloudflare DNS for `mambakkam.net` + `www` (~10 min)

- [ ] A record `@` (apex) → VPS public IP, **Proxied** (orange cloud)
      · _verify:_ `dig mambakkam.net +short` returns a Cloudflare-edge IP (104.21.x.x or 172.67.x.x), **NOT** the raw VPS IP
- [ ] CNAME `www` → `mambakkam.net`, **Proxied**
      · _verify:_ `dig www.mambakkam.net +short` resolves through Cloudflare
- [ ] Page Rule (or Bulk Redirect): `www.mambakkam.net/*` → `https://mambakkam.net/$1`, 301
      · _verify:_ `curl -sI https://www.mambakkam.net/` returns `301` to the apex
- [ ] SSL/TLS mode set to **Full (strict)**; **Always Use HTTPS** toggled on
      · _verify:_ `curl -sI http://mambakkam.net/` returns `301` to https
- [ ] Cloudflare Origin Certificate generated with SAN = `mambakkam.net, *.mambakkam.net, demo.usestudybuddy.com`; cert + key installed at `/etc/ssl/cloudflare/origin-{cert,key}.pem` on the VPS (shared with StudyBuddy)
      · _verify:_ host nginx reloads cleanly; `curl https://mambakkam.net/` returns 200
- [ ] Pre-launch (Day -1 / Sat May 16 EOD): TTL on the apex A record lowered to 300s
      · _verify:_ Cloudflare DNS UI shows "TTL: 5 min" instead of "Auto"

#### Phase 3 — Zoho Mail free-tier (~30 min)

mambakkam.net is the first domain in this Zoho free-tier org; StudyBuddy
will be added as a second domain on its launch day. Each domain has its
own MX/SPF/DKIM/DMARC records; the Zoho **tenant** is shared across both.

- [ ] `mambakkam.net` added to Zoho; domain-verification TXT record added to Cloudflare DNS
      · _verify:_ `dig TXT mambakkam.net +short` shows `zoho-verification=zb...`
- [ ] One mailbox live: `siva@mambakkam.net` (operator can extend later)
      · _verify:_ Send a test from Zoho webmail to your personal Gmail; reply arrives back in Zoho
- [ ] MX records (mx.zoho.com priorities 10/20/50) added to Cloudflare DNS
      · _verify:_ `dig MX mambakkam.net +short` lists `mx.zoho.com`, `mx2.zoho.com`, `mx3.zoho.com`
- [ ] SPF record `v=spf1 include:zoho.com ~all` added (single TXT at apex)
      · _verify:_ `dig TXT mambakkam.net +short | grep spf1` returns the record
- [ ] DKIM record `zmail._domainkey` added with the Zoho-supplied public key
      · _verify:_ All three (MX, SPF, DKIM) show green checkmarks in Zoho's verification UI
- [ ] DMARC record `_dmarc` added with `v=DMARC1; p=quarantine; rua=mailto:siva@mambakkam.net`
      · _verify:_ `dig TXT _dmarc.mambakkam.net +short` returns the policy

#### Phase 4 — Gmail send-as (~10 min, optional but recommended)

- [ ] Zoho App Password generated for the Gmail integration
      · _verify:_ App Password copied to a password manager
- [ ] `siva@mambakkam.net` added as a send-as identity in Gmail (SMTP `smtp.zoho.com:465`, SSL on)
      · _verify:_ Compose new mail in Gmail; From dropdown shows `Siva Mambakkam <siva@mambakkam.net>`

#### Phase 5 — Wire SMTP into the site (deferred — no contact form on day 1)

mambakkam.net has no contact form, no auth, no app-originated email at launch.
The Zoho mailbox covers human inbox/outbox via Gmail send-as. The
`SMTP_*` env vars in `.env.demo.example` are placeholders for the future
contact form/newsletter; nothing to wire up for Day 0 (Sun May 17).

### 1.B Content — must-have

The site is a static Astro build. "Content" here is the markdown collections
(landmarks, people, work) and image assets in `src/assets/images/`. No
external pipeline, no API keys.

| Item                                                                           | Owner    | Verify by                                                                           |
| ------------------------------------------------------------------------------ | -------- | ----------------------------------------------------------------------------------- |
| All currently-staged village images present and rotated for orientation/size   | Operator | `ls src/assets/images/village/*.jpeg \| wc -l` matches expected; spot-check a build |
| `src/data/people/siva-m.md` complete with bio + headshot                       | Operator | `npm run build` includes the page; opens at `/people/siva-m`                        |
| All four landmarks in `src/data/landmarks/` build cleanly                      | Operator | Lighthouse `/landmarks` returns 200 + each landmark page renders its body           |
| All four work items in `src/data/work/` build cleanly                          | Operator | `/work` lists all four; each detail page returns 200                                |
| `studybuddy-ondemand.md` work item links to `https://demo.usestudybuddy.com`      | Operator | `grep -l 'demo.usestudybuddy.com' src/data/work/*.md` returns the file                 |
| Hero copy + nav final-pass for typos                                           | Operator | Manual read; or `npx cspell '**/*.{md,astro}'` if added later                       |
| `npm run build` exits clean — zero broken-link warnings, zero typecheck errors | Operator | `npm run check && npm run build` exit code 0                                        |

### 1.C Polish — nice-to-have (skip if blocking)

| Item                                                               | Effort | Skip if                                                                 |
| ------------------------------------------------------------------ | ------ | ----------------------------------------------------------------------- |
| Custom 404 page tied to village photography                        | 30 min | Default AstroWind 404 acceptable for launch                             |
| Open Graph image set per page (currently global only)              | 1 hour | Global `default.png` is acceptable                                      |
| `manifest.webmanifest` + Apple touch icons                         | 30 min | Browser-default favicon is acceptable                                   |
| Plausible / GA4 wired via `analytics.vendors` in `src/config.yaml` | 15 min | Should ship — single config change                                      |
| robots.txt sanity check (no `Disallow: /` left from staging)       | 5 min  | Never skip                                                              |
| `dist/sitemap-index.xml` smoke-tested in the smoke script          | 5 min  | Never skip — already in this PR                                         |
| Dyslexia-mode toggle final-pass on every layout                    | 30 min | Already shipped (`ToggleDyslexic.astro`) — verify, don't rebuild        |
| VillageMap loads without console errors on Safari iOS              | 20 min | If Safari doesn't render Leaflet tiles, fall back to a static map image |

### 1.D Definition of "Done" for Day -5 (Tue May 12 EOD)

Green checkboxes on each of these means we enter the test phase clean:

- [ ] All Tier-1.A automation deliverables in `main`
- [ ] All Tier-1.A.bis Domain + Email phases 1–4 ticked
- [ ] All Tier-1.B content built; `dist/` from a clean `npm run build` reviewed end-to-end
- [ ] `npm run check` (astro check + eslint + prettier) green on `main`
- [ ] One **complete dry-run on a throwaway subdomain** of the production VPS (e.g. `staging.mambakkam.net`): run provision-add-on → deploy → smoke — including the DNS + email phases against the staging hostname

---

## §2 · Day 0 (Sun May 17) Launch-Day Runbook

**Prerequisite checks the day before (Day -1 / Sat May 16 EOD):**

- DNS pre-staged at Cloudflare (apex A record TTL=300s a day in advance)
- Hetzner production VPS freshly provisioned ≥ 24h before launch via
  mambakkam.net's `scripts/launch/provision.sh` (full system bootstrap —
  Docker, UFW, fail2ban, deploy user, host nginx, Origin Cert directory,
  daily-backup cron). StudyBuddy is **not yet** on this box.
- `/opt/mambakkam` deployed and serving on `127.0.0.1:8081`
- Host nginx vhost installed, Origin Cert in place (SAN already includes
  `demo.usestudybuddy.com` so StudyBuddy can join later without a re-issue),
  `nginx -t` clean
- `.env.demo` populated (only analytics ID needed at launch; SMTP placeholders OK)
- Note: the GitHub Actions deploy keypair, the 3 repo secrets
  (`MAMBAKKAM_VPS_*`), and the `MAMBAKKAM_DEPLOY_ENABLED` variable are
  **deliberately NOT pre-staged** — they're set on Day 0 morning during
  the cutover (rows at 08:28 + 08:30 below). The deploy workflow stays
  gated (skipped status) until then per
  [`.github/workflows/deploy-mambakkam.yml`](../.github/workflows/deploy-mambakkam.yml).

### Day -1 (Sat May 16) 17:00–20:30 EDT — Account + Email Setup

Operator-side work, done the evening before launch from your laptop.
**Full chronological checklist in [`ACCOUNT_SETUP.md`](ACCOUNT_SETUP.md)** — 9
sections covering every account, the values to copy into the password
manager, and a §10 cheat-sheet for which value goes into which `.env`
line tomorrow morning.

**One-paragraph summary:**
17:00 Cloudflare account + Origin Cert generation (SAN list = mambakkam.net

- \*.mambakkam.net + demo.usestudybuddy.com); 17:15 Hetzner sign-up + SSH
  key (no CX22 yet); 17:25 Zoho Mail with mambakkam.net mailbox + MX/SPF/
  DKIM/DMARC; 17:55 Gmail send-as; 18:15 Grafana Cloud account + Access
  Policy token (3 scopes); 18:40 pre-stage mambakkam DNS A record at
  TTL=300s; 19:00 register usestudybuddy.com + add mailboxes; 19:25 Auth0
  dev tenant + 3 applications; 19:50 Stripe test mode + webhook + Sentry.
  20:30 final go/no-go before bed. Total 3.5 hours; budget 4 if Zoho DKIM
  verification stalls.

**Hard "no" tonight:**

- Don't actually provision the Hetzner CX22 (that's Day 0 at 08:00 EDT)
- Don't enable Cloudflare proxy on either pre-staged A record (would 502)
- Don't push past 21:00 EDT — sleep beats finishing

---

### Day 0 (Sun May 17) — Server Cutover Runbook

Operator starts on the VPS at **08:00 EDT** the morning of launch. This
gives 1 hour of provisioning + smoke-testing before the public T-0 cutover
at 09:00 EDT.

| Time (EDT)         | Δ       | Action                                                                                                                                                                                                                                                                                                                           | Owner    | Pass criterion                                                                                                  |
| ------------------ | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| 08:00              | T-1h    | **Open laptop**, Hetzner console — provision a fresh CX22 (Ubuntu 22.04, SSH key from Day -1, Falkenstein)                                                                                                                                                                                                                       | Operator | VPS public IP visible; SSH-able as root within ~3 min                                                           |
| 08:03              | T-57m   | `ssh root@<vps-ip>` + run `provision.sh` one-liner from §2.5 Sequence A step 1                                                                                                                                                                                                                                                   | Operator | All 14 steps complete (~20 min); restic password printed once and saved                                         |
| 08:25              | T-35m   | Paste Cloudflare Origin Cert + key into `/etc/ssl/cloudflare/origin-{cert,key}.pem` (mode 600)                                                                                                                                                                                                                                   | Operator | `nginx -t` is clean                                                                                             |
| 08:28              | T-32m   | **Generate the GH-Actions deploy keypair + paste pubkey** (task 20, part 1): on laptop, `ssh-keygen -t ed25519 -f ~/.ssh/mambakkam_deploy -C "gh-actions deploy@mambakkam"`. Paste `~/.ssh/mambakkam_deploy.pub` to `/home/deploy/.ssh/authorized_keys` on the VPS (mode 600, owned by deploy:deploy)                            | Operator | `ssh -i ~/.ssh/mambakkam_deploy deploy@<vps-ip> 'whoami'` returns `deploy`                                      |
| 08:30              | T-30m   | **Add 3 repo secrets + 1 variable in GitHub** (task 20, part 2): repo Settings → Secrets → Actions: `MAMBAKKAM_VPS_HOST=<vps-ip>`, `MAMBAKKAM_VPS_USER=deploy`, `MAMBAKKAM_VPS_SSH_KEY=<paste private key from ~/.ssh/mambakkam_deploy>`. Settings → Variables → Actions: `MAMBAKKAM_DEPLOY_ENABLED=true` to ungate the workflow | Operator | All 4 entries visible in repo Settings UI; the next merge to `main` will fire the deploy workflow (post-launch) |
| 08:32              | T-28m   | Edit `/opt/mambakkam/.env.demo` with the analytics ID; sudo systemctl reload nginx                                                                                                                                                                                                                                               | Operator | nginx reload OK                                                                                                 |
| 08:34              | T-26m   | Build + start mambakkam container: `sudo -u deploy bash /opt/mambakkam/scripts/launch/deploy.sh`                                                                                                                                                                                                                                 | Operator | `docker compose ps` shows `Up (healthy)`                                                                        |
| 08:40              | T-20m   | Local smoke: `bash scripts/launch/smoke.sh http://127.0.0.1:8081`                                                                                                                                                                                                                                                                | Operator | Exit 0                                                                                                          |
| 08:45              | T-15m   | DNS cutover: at Cloudflare, change the apex A record value from the Day -1 placeholder IP to the real VPS public IP, **enable proxy** (orange cloud)                                                                                                                                                                             | Operator | `dig +short mambakkam.net` returns a Cloudflare-edge IP within 60s                                              |
| 08:50              | T-10m   | Public smoke: `bash scripts/launch/smoke.sh https://mambakkam.net` from your laptop                                                                                                                                                                                                                                              | Operator | Exit 0                                                                                                          |
| 08:55              | T-5m    | Manual click-through: home → about → people/siva-m → landmarks → work → studybuddy link reaches `demo.usestudybuddy.com` (will 404 until 13:00, that's expected)                                                                                                                                                                    | Operator | Every mambakkam page renders correctly                                                                          |
| **09:00**          | **T-0** | **GO LIVE** — share `https://mambakkam.net` to the announcement channel                                                                                                                                                                                                                                                          | Operator | Announcement sent                                                                                               |
| 09:30              | T+30m   | First user-traffic check — Cloudflare Analytics + nginx access log                                                                                                                                                                                                                                                               | Operator | No 5xx in the access log                                                                                        |
| 11:00              | T+2h    | Stability check — green light for StudyBuddy second-tenant join                                                                                                                                                                                                                                                                  | Operator | Cloudflare Analytics shows steady 200s                                                                          |
| 13:00              | T+4h    | **StudyBuddy joins the box** — second-tenant provisioning + DNS cutover (driven by StudyBuddy's launch plan §2)                                                                                                                                                                                                                  | Operator | StudyBuddy `smoke.sh` exits 0; mambakkam unaffected                                                             |
| 15:00              | T+6h    | First post-launch incident review (even if uneventful)                                                                                                                                                                                                                                                                           | Operator | Notes captured for retrospective                                                                                |
| Next day 02:30 UTC | —       | First nightly content backup runs (`30 2 * * *`)                                                                                                                                                                                                                                                                                 | Auto     | Backup file in `/opt/mambakkam/backups/`; StudyBuddy's 02:00 UTC ran 30 min earlier                             |

**Rollback plan (if smoke fails after cutover):**

1. **Cloudflare-side maintenance page** (fastest, ~2 min): in Cloudflare → Pages or Workers → flip the apex to a "Site under maintenance" worker. TTL=300s means propagation ≤ 5 min.
2. **Container rollback** (if a bad deploy is the cause): `ssh vps 'cd /opt/mambakkam && git reset --hard <previous-sha> && bash scripts/launch/deploy.sh'`. Same-image rollback ~3 min.
3. **DNS revert** (only if the Hetzner box itself is unhealthy): point apex A back to whatever was serving the site pre-launch (Netlify/Vercel deploy URL — keep these alive until T+24h as a fallback).

**On-call duties (T+0 → T+24h):**

- Watch Cloudflare Analytics every 30 min for the first 4 hours
- Tail `/var/log/nginx/mambakkam.net.access.log` for 5xx
- Respond to first user feedback within 1 hour during business hours

---

## §2.5 · Deployment Sequence (consolidated)

Two distinct sequences:

- **Cold start** — done once during the Day -2 to Day -1 (May 15-16) staging dry-run and again
  on/around Day -1 (Sat May 16) if the production VPS is provisioned fresh. Manual; the
  operator drives.
- **Ongoing deploy** — fires automatically on every merge to `main` after
  initial cold-start. CI drives; operator only intervenes on failure.

### Sequence A — Cold start (manual; ~20 minutes the first time)

This sequence runs against a **fresh Hetzner CX22**. mambakkam.net is the
first tenant on the box, so its `provision.sh` must perform the full
system bootstrap — Docker, UFW, fail2ban, the `deploy` user, host nginx,
the `/etc/ssl/cloudflare/` directory, and the daily-backup cron.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Operator action                                                      │
└──────────────────────────────────────────────────────────────────────┘

  1. SSH in + run provision.sh                                       [~5 min]
     ssh root@<vps-ip>
     curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision.sh \
       | bash
     As the first tenant on a fresh CX22, this installs:
       - Docker CE + Compose plugin (apt)
       - UFW firewall (allow ssh / 80 / 443) + fail2ban
       - Host nginx (apt) — the single :80 + :443 entry point for both
         tenants. mambakkam vhost dropped to /etc/nginx/sites-available
         and enabled.
       - /opt/mambakkam (git clone) + .env.demo skeleton
       - The `deploy` system user (passwordless sudo for docker compose)
       - /etc/ssl/cloudflare/ directory (operator pastes Origin Cert)
       - Daily-backup cron at 02:30 UTC
     Idempotent: re-running skips finished steps. Safe for StudyBuddy
     to re-use the same `deploy` user when it joins later.

  2. Generate + install Cloudflare Origin Cert                       [~2 min]
     Cloudflare → SSL/TLS → Origin Server → Create Certificate.
     SAN list MUST include all of:
       - mambakkam.net
       - *.mambakkam.net
       - demo.usestudybuddy.com          (for the StudyBuddy second tenant)
     Paste cert + key into:
       /etc/ssl/cloudflare/origin-cert.pem
       /etc/ssl/cloudflare/origin-key.pem
     One cert, one renewal, both tenants — generated up-front so
     StudyBuddy can join later without a re-issue.

  3. Build + start the container                                     [~3 min]
     cd /opt/mambakkam
     docker compose -f docker-compose.demo.yml \
       --env-file .env.demo up -d --build

  4. Reload host nginx                                               [~10 sec]
     nginx -t && systemctl reload nginx

  5. Paste GH Actions deploy SSH pubkey                              [~1 min]
     /home/deploy/.ssh/authorized_keys
     (matching private key → repo secret MAMBAKKAM_VPS_SSH_KEY)

  6. smoke.sh                                                        [~10 sec]
     bash scripts/launch/smoke.sh http://127.0.0.1:8081
     # then with public hostname after DNS cuts over:
     bash scripts/launch/smoke.sh https://mambakkam.net

┌──────────────────────────────────────────────────────────────────────┐
│  Make it public                                                       │
└──────────────────────────────────────────────────────────────────────┘

  7. Cloudflare DNS apex A record → VPS public IP                    [~3 min]
     Cloudflare dashboard → mambakkam.net → DNS.
     SSL/TLS mode: Full (strict).
     TTL: 300s in advance of cutover.

  8. smoke.sh against the public domain                              [~10 sec]
     bash scripts/launch/smoke.sh https://mambakkam.net
     Cold-start complete when this exits 0.
```

**Total cold-start time:** ~20 minutes (vs. ~15 in the previous draft —
the extra time covers the system-bootstrap steps that were previously
assumed to be done by StudyBuddy's `provision.sh`).

### Sequence B — Ongoing deploy (automatic; ~3 minutes per merge)

Fires on every push to `main` via `.github/workflows/deploy-mambakkam.yml`.
No operator action unless the smoke check fails.

```
┌──────────────────────────────────────────────────────────────────────┐
│  GitHub Actions                                                       │
└──────────────────────────────────────────────────────────────────────┘

  1. Push lands on main                                               [event]

  2. actions.yaml runs first (existing CI workflow)                  [~2 min]
     Multi-version build matrix (Node 18/20/22) + npm run check.
     deploy-mambakkam.yml does NOT wait on this today — operator
     ensures CI is green before merging.

  3. deploy-mambakkam.yml triggered                                   [event]

┌──────────────────────────────────────────────────────────────────────┐
│  VPS                                                                  │
└──────────────────────────────────────────────────────────────────────┘

  4. SSH to VPS as deploy@MAMBAKKAM_VPS_HOST                         [~1 sec]
     Uses MAMBAKKAM_VPS_SSH_KEY repo secret.

  5. bash /opt/mambakkam/scripts/launch/deploy.sh                    [~2 min]
     deploy.sh does:
       a. cd /opt/mambakkam && git fetch && git reset --hard origin/main
       b. docker compose -f docker-compose.demo.yml \
            --env-file .env.demo up -d --build --remove-orphans
       c. wait 15s for healthcheck to settle
       d. bash scripts/launch/smoke.sh http://127.0.0.1:8081

  6. Run public-side smoke from the GH Actions runner                 [~10 sec]
     bash scripts/launch/smoke.sh https://mambakkam.net

  7a. (Smoke green)
      Step summary posted to GH Actions UI. Done.

  7b. (Smoke fails)
      Auto-creates GitHub issue tagged `incident:mambakkam` +
      `priority:high` with the workflow-run URL and a triage checklist.
      Auto-rollback is intentionally NOT wired — operator must triage.
```

**Total auto-deploy time:** ~3 minutes from `git push` to live site.

### When NOT to follow Sequence B

Two cases where auto-deploy should be skipped or the operator should take over:

1. **Image asset rename or content-collection schema change.** Astro's content
   collections will fail-fast at build time on shape mismatches. CI typecheck
   should catch this; if it doesn't and the deploy fails build, the previous
   container keeps serving (compose `up -d --build` only swaps on success).
   Triage: re-run locally, fix the schema, push.

2. **Host nginx vhost change.** `infra/nginx/mambakkam.net.conf` lives in the
   repo but the deploy script does NOT auto-copy it into `/etc/nginx/`. After
   editing the vhost: `sudo cp infra/nginx/mambakkam.net.conf
/etc/nginx/sites-available/ && sudo nginx -t && sudo systemctl reload
nginx`. Manual on purpose — a bad vhost would take down BOTH co-tenant
   sites including StudyBuddy.

---

## §3 · Automation Scripts — Inventory + Usage

All scripts live under `scripts/launch/` and are invoked from the **operator's
laptop** or **the Hetzner VPS** depending on the script. The deploy workflow is
in `.github/workflows/`.

### 3.1 First-time provisioning — `scripts/launch/provision.sh`

**Run on:** the Hetzner VPS (as root), once when standing up the box.
mambakkam.net is the **first tenant**, so this script does the full system
bootstrap — StudyBuddy's later `provision.sh` is the shorter second-tenant
variant that reuses what's already here.

```bash
# After ssh-ing into a fresh Hetzner CX22 Ubuntu 22.04 box:
curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision.sh | bash
```

What it does (full first-tenant bootstrap):

- `apt-get update && upgrade`
- Installs Docker CE + Compose plugin, `nginx` (host-level), `ufw`,
  `fail2ban`, `cron`, `rsync`
- Configures UFW (allow ssh / 80 / 443; deny everything else) + fail2ban
  (default ssh jail)
- Creates the `deploy` system user with passwordless sudo for `docker
compose` only — StudyBuddy will reuse this same user when it joins
- Creates `/opt/mambakkam/` + git clones the repo
- Generates `.env.demo` skeleton from `.env.demo.example`
- Drops `infra/nginx/mambakkam.net.conf` into `/etc/nginx/sites-available/`
  and enables it
- Creates `/etc/ssl/cloudflare/` (operator pastes the SAN-list Origin Cert
  covering both mambakkam.net + demo.usestudybuddy.com)
- Sets up `cron` for the daily backup at 02:30 UTC (StudyBuddy will offset
  its own cron to 02:00 UTC when it joins, so the two rsync passes don't
  collide on disk I/O)
- **Idempotent**: re-running is safe (skips finished steps)

> **Outstanding before Day -5 (Tue May 12):** the current script
> (`scripts/launch/provision.sh`) was originally written assuming StudyBuddy
> bootstrapped the box first. Items above marked _Docker CE_, _UFW_,
> _fail2ban_, and the _deploy user_ need to be added to the script before
> the Day -5 (Tue May 12) code-freeze gate, or the operator must run those steps
> manually during cold start.

**Output:** the script ends with a checklist of next steps the operator must
do manually (paste Origin Cert, run docker compose, reload nginx, etc.).

### 3.2 Manual / CI deploy — `scripts/launch/deploy.sh`

**Run on:** the Hetzner VPS (as `deploy` user), via CI or manually.

```bash
sudo -u deploy bash /opt/mambakkam/scripts/launch/deploy.sh
```

What it does:

1. `cd /opt/mambakkam`
2. `git fetch origin main && git reset --hard origin/main`
3. `docker compose -f docker-compose.demo.yml --env-file .env.demo up -d --build --remove-orphans`
4. Wait 15 seconds for the container to settle
5. Run `scripts/launch/smoke.sh http://127.0.0.1:8081`
6. Exit 0 on success; exit non-zero (with the smoke summary) on failure

Idempotent. Safe to re-run; no destructive actions.

### 3.3 Post-deploy smoke test — `scripts/launch/smoke.sh`

**Run on:** the operator's laptop (against the public domain) or in CI (against
the local container or public URL).

```bash
./scripts/launch/smoke.sh https://mambakkam.net
```

What it checks:

| Check                           | Expected                                  | Fails on                                   |
| ------------------------------- | ----------------------------------------- | ------------------------------------------ |
| `GET /`                         | 200 + `<title>` contains `Mambakkam`      | Any non-200                                |
| `GET /sitemap-index.xml`        | 200 + `<sitemapindex`                     | Empty or missing                           |
| `GET /people/siva-m`            | 200 + body contains `Siva`                | Any non-200                                |
| `GET /landmarks/ayyanar-shrine` | 200                                       | Any non-200                                |
| `GET /work/studybuddy-ondemand` | 200 + body contains `demo.usestudybuddy.com` | Outbound link missing                      |
| `GET /404-this-does-not-exist`  | 404 (correct error path, not 200)         | A 200 means the 404 page was misconfigured |
| `GET /robots.txt`               | 200 + does NOT contain `Disallow: /`      | Stale "noindex everything" rule            |

Exits 0 if all green; exits 1 with a structured failure summary on any miss.

### 3.4 Daily content backup — `scripts/launch/backup.sh` (restic)

**Run on:** the Hetzner VPS via cron. Two scripts on two schedules, both
wired up by `provision.sh`: the cron file at `/etc/cron.d/mambakkam-backup`,
and the restic repo + password initialised inline.

```cron
# Daily backup — restic snapshot of non-git assets
30 2 * * *  root cd /opt/mambakkam && bash scripts/launch/backup.sh       >> /var/log/mambakkam-backup.log 2>&1

# Weekly integrity check + prune (Sundays, 1h after the daily — see §3.5)
30 3 * * 0  root cd /opt/mambakkam && bash scripts/launch/backup-check.sh >> /var/log/mambakkam-backup.log 2>&1
```

**Daily — `backup.sh`** (2 steps):

1. `restic backup` → `/opt/mambakkam/backups/restic/` covering four sources, all the things that would be costly to recreate (code + Markdown are in git, so they're excluded):
   - `$INSTALL_DIR/src/assets/images/` — large media uploaded directly to the VPS
   - `/var/log/nginx/mambakkam.net.*` — host nginx vhost logs (logrotate keeps 14d; restic captures the live window in case of investigation)
   - `/etc/ssl/cloudflare/` — Origin Cert + key (15-yr validity but a clean rebuild needs them on hand)
   - `$INSTALL_DIR/.env.demo` — analytics ID + future contact-form SMTP creds

   Tag: `daily`. Encrypted at-rest with AES-256; password at `/etc/restic/mambakkam.password` (generated and printed once by `provision.sh`).

2. `restic forget --tag daily --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 1` — about 15 snapshots retained. `forget` only marks snapshots unreferenced; actual disk reclamation runs weekly via `backup-check.sh` (see §3.5).

Exit codes: **0** success / **1** restic backup failed / **2** restic forget/prune failed / **3** repo not initialised (run `provision.sh`) / **4** password file missing or unreadable.

### 3.5 Weekly restic check + prune — `scripts/launch/backup-check.sh`

**Run on:** the Hetzner VPS via cron at Sun 03:30 UTC (one hour after the Sunday daily backup so they don't compete for the repo lock). Wired up alongside the daily in `provision.sh`'s cron file.

What it does (2 steps):

1. `restic check --read-data-subset 5%` — verifies repo metadata + reads 5% of pack files to catch silent bit-rot. Full 100% audit is too slow to run weekly; 5% cycles every pack within ~5 months on average.
2. `restic prune --max-unused 5%` — reclaims disk that the daily `forget`s marked unreferenced but didn't physically delete.

Exit codes: 0 success / 1 check failed (**possible bit-rot — investigate immediately**) / 2 prune failed / 3 repo not initialised / 4 password file unreadable.

**Log routing.** Both scripts write to `/var/log/mambakkam-backup.log` via cron redirect. Promtail (running in the StudyBuddy monitoring stack — see [`Plans/MONITORING.md`](MONITORING.md)) ships that log to Grafana Cloud Loki. Query: `{job="backups", which="mambakkam"} |~ "(?i)check|prune|error"`.

**Companion runbook.** [`Plans/BACKUPS.md`](BACKUPS.md) documents 5 restore scenarios — Scenarios 4 (recover Cloudflare Origin Cert + key) and 5 (historical access-log search) are mambakkam-relevant. Scenario rehearsals happen in §4 Day -3 alongside the alert test-fire.

### 3.6 Auto-deploy CI — `.github/workflows/deploy-mambakkam.yml`

**Triggers:** push to `main`, manual `workflow_dispatch`.

Steps:

1. Checkout (no build needed in CI — the VPS rebuilds in-place)
2. SSH to VPS using `MAMBAKKAM_VPS_SSH_KEY` repo secret
3. Run `bash /opt/mambakkam/scripts/launch/deploy.sh`
4. Run `scripts/launch/smoke.sh https://mambakkam.net` from the GH runner
5. On smoke failure: open a GitHub issue tagged `incident:mambakkam`; do NOT roll back automatically

**Required GitHub secrets:**

| Secret                  | Purpose                                                                           |
| ----------------------- | --------------------------------------------------------------------------------- |
| `MAMBAKKAM_VPS_SSH_KEY` | Private SSH key for the `deploy` user on the VPS                                  |
| `MAMBAKKAM_VPS_HOST`    | The VPS hostname or IP (same value as StudyBuddy's `DEMO_VPS_HOST` if co-located) |
| `MAMBAKKAM_VPS_USER`    | `deploy`                                                                          |

---

## §4 · Test Plan — Day -4 (Wed May 13) → Day -1 (Sat May 16)

Four-day phased validation. Each day has a **pass/fail gate** — if any gate
fails, the next day's tests don't start until the issue is fixed.

### Day -4 — Wednesday May 13 — Initial Deploy + Infrastructure Smoke

**Goal:** prove the automation works end-to-end against a real Hetzner box.

| Time           | Activity                                                                                                                                                                                                        | Pass criterion                                                                                                           |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Morning        | Provision a fresh Hetzner CX22 (the **staging** box, separate from the production box that gets cut on Day -1 (Sat May 16)) by running `scripts/launch/provision.sh` from scratch — full first-tenant bootstrap | Docker installed, UFW/fail2ban active, host nginx serves a "hello" page from a temp container                            |
|                | Configure Cloudflare DNS for `staging.mambakkam.net` (proxied)                                                                                                                                                  | `dig` resolves the new A-record to a Cloudflare-edge IP                                                                  |
|                | Run `scripts/launch/deploy.sh`                                                                                                                                                                                  | Container `Up`; `smoke.sh http://127.0.0.1:8081` exits 0                                                                 |
|                | Run `scripts/launch/smoke.sh https://staging.mambakkam.net`                                                                                                                                                     | Exit 0                                                                                                                   |
| Afternoon      | Trigger a fake `main` push → verify auto-deploy works end-to-end                                                                                                                                                | `deploy-mambakkam.yml` finishes green; smoke check passes                                                                |
|                | Trigger a deliberate smoke failure (rename a key page in `src/data/`) — verify issue creation                                                                                                                   | Issue auto-opened with `incident:mambakkam` label                                                                        |
| Late afternoon | **Co-tenant smoke** — onto the same staging box, run StudyBuddy's `scripts/demo/provision.sh` and confirm it does NOT clobber Docker/UFW/fail2ban/deploy user/host nginx put in place by mambakkam              | Both `staging.mambakkam.net` and a StudyBuddy staging hostname respond cleanly; `nginx -t` green; `ufw status` unchanged |
| End of day     | Backup script runs (manually trigger once at 17:00 to verify cron works)                                                                                                                                        | Backup file present in `/opt/mambakkam/backups/`                                                                         |

**Gate to Day 2:** all infra works on staging; rollback path proven.

### Day -3 — Thursday May 14 — Content Walkthrough

**Goal:** every page renders, every link works, every image loads.

Walk through every URL in the navigation (top + footer) against
`https://staging.mambakkam.net`. Expand subtrees: every landmark, every person,
every work item.

| Section     | Pages to check                                                               | Critical check                                                                                         |
| ----------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Home        | `/`                                                                          | Hero loads, village map renders, no 5xx in network tab                                                 |
| News (blog) | `/news`, individual posts                                                    | Pagination works; tag/category pages 200                                                               |
| People      | `/people`, `/people/siva-m`                                                  | Headshot loads at 1x and 2x; bio renders Markdown                                                      |
| Landmarks   | `/landmarks/{ayyanar-shrine,ellaiyamman-temple,new-temple,pillaiyar-temple}` | Each renders body + photo                                                                              |
| Work        | `/work`, all four work detail pages                                          | `/work/studybuddy-ondemand` outbound link to `demo.usestudybuddy.com` is `target="_blank" rel="noopener"` |
| 404         | `/this-doesnt-exist`                                                         | Returns HTTP 404 (not 200) and renders the custom 404                                                  |
| Sitemap     | `/sitemap-index.xml`                                                         | Returns 200 + lists every public page                                                                  |
| robots.txt  | `/robots.txt`                                                                | No `Disallow: /`                                                                                       |

**Gate to Day 3:** every page passes; any 5xx documented + fixed; any broken
image flagged.

**Alert test-fire (afternoon, ~10 min).** First end-to-end test of the
alert pipeline. Pick one rule (e.g. `MambakkamDown`), temporarily lower
its `for:` threshold to 30 s, restart Prometheus to pick up the change,
trigger by stopping the astrowind container for 60 s, confirm the email
arrives in Gmail with `[PAGE]` subject prefix. Restart container, restore
threshold, re-apply rules:

```bash
ssh deploy@<vps-ip>
sudo docker stop mambakkam-astrowind
# wait 90s, check Gmail inbox for [PAGE] MambakkamDown email
sudo docker start mambakkam-astrowind
# email auto-resolves within 1m
```

If the email doesn't arrive, the notification routing isn't right —
fix per `RUNBOOK.md` §"Notification routing setup" before launch.

**Restore drill (afternoon, ~30 min).** First end-to-end test of the
restic-based backup path (§9) on the staging box:

1. Force-run a backup to ensure there's at least one snapshot:
   `sudo bash /opt/mambakkam/scripts/launch/backup.sh`
2. Simulate disk loss for one image: `sudo rm /opt/mambakkam/src/assets/images/people/siva-m.jpg`
3. Verify the page is now broken (404 on the headshot in `/people/siva-m`)
4. Restore from the latest snapshot per `Plans/BACKUPS.md` Scenario 2:
   ```
   sudo RESTIC_PASSWORD_FILE=/etc/restic/mambakkam.password \
        restic -r /opt/mambakkam/backups/restic restore latest \
        --target / --include /opt/mambakkam/src/assets/images/people/siva-m.jpg
   ```
5. Verify file is back + page renders the headshot again

If any step fails, the bug stops the launch (DR is non-negotiable for a
public site). On success, capture the timing for the runbook so the
post-launch drill cadence has a baseline.

### Day -2 — Friday May 15 — Accessibility, Mobile, Cross-link

**Goal:** non-happy-path holds up; demo can run end-to-end with no surprises.

| Test area                   | Specific tests                                                                                                                                                                                                                                     |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Accessibility**           | Alt+D toggles OpenDyslexic (cookie persists). Tab through home — no traps. axe-core scan on home + people + landmarks: no critical violations. Screen-reader test on `/people/siva-m` — heading hierarchy intact, alt text present on every image. |
| **Mobile**                  | Open `https://staging.mambakkam.net/` on a real phone (iOS Safari + Android Chrome). Hero stacks, nav opens, village map is usable on a small viewport.                                                                                            |
| **Outbound to StudyBuddy**  | Click the "Visit StudyBuddy" CTA from `/work/studybuddy-ondemand`. Lands on `demo.usestudybuddy.com` with no certificate warning.                                                                                                                     |
| **Inbound from StudyBuddy** | If StudyBuddy has a back-link, click it from there → arrives on mambakkam.net cleanly.                                                                                                                                                             |
| **Cloudflare cache check**  | Visit `/_astro/<hash>.css` twice; second response shows `cf-cache-status: HIT`.                                                                                                                                                                    |
| **Lighthouse**              | Run on home + a content page. Target: Performance ≥ 90, Accessibility ≥ 95, SEO ≥ 95.                                                                                                                                                              |

**Gate to Day 4:** every flow above passes; Lighthouse scores meet bar.

### Day -1 — Saturday May 16 — Regression Sweep + Final Go/No-Go

**Goal:** confirm nothing has regressed and produce an explicit go-decision.

| Time      | Activity                                                                                                                                                                                       | Pass criterion                                                                                        |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Morning   | Re-run all of Day 2's content walkthrough against staging                                                                                                                                      | Same passes as Day 2                                                                                  |
| Morning   | `npm run check && npm run build` on a clean clone                                                                                                                                              | Exit code 0                                                                                           |
| Midday    | Lower DNS TTL on `mambakkam.net` apex A record to 300s                                                                                                                                         | Cloudflare confirms TTL=300                                                                           |
| Midday    | Provision the **production** Hetzner CX22 (separate from staging — same `provision.sh` from scratch). Paste Origin Cert with the SAN list covering both mambakkam.net and demo.usestudybuddy.com. | Production box healthy; `staging.mambakkam.net` stays running for last-mile testing                   |
| Midday    | Confirm StudyBuddy is ready to join the production box on Day 0 (Sun May 17) (read its launch plan §4 day 4)                                                                                   | StudyBuddy second-tenant gate is green; its `provision.sh` validated against the staging box on Day 1 |
| Afternoon | Final go/no-go meeting with self — separate decisions for mambakkam.net (T-0 = 09:00) and StudyBuddy (T+4h = 13:00)                                                                            | Both boxes ticked → GO for both cutovers                                                              |

**Gate to Day 0 (Sun May 17) launch:** 4 successive days of green plus a documented go-decision.

---

## §5 · Risk Register

The known risks worth pre-mitigating, ordered by likelihood × impact:

| Risk                                                                              | Likelihood | Impact | Mitigation                                                                                                                                                                            |
| --------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Host nginx vhost edit breaks BOTH mambakkam + StudyBuddy on same box              | Medium     | High   | `nginx -t` before every reload; vhost edit is manual (intentionally not auto-deployed); keep the StudyBuddy vhost in a separate file so a syntax error in one doesn't break the other |
| Cloudflare Origin Cert expires (1 year default)                                   | Low        | High   | Set a calendar reminder for 11 months out; cert covers both domains so a renewal blocks both — schedule for a quiet weekend                                                           |
| `docker compose up --build` on push to main pulls in a breaking npm dep           | Medium     | Medium | Lockfile is committed; CI matrix tests Node 18/20/22 before merge; if a build breaks, the previous container keeps serving                                                            |
| Image assets bloat git repo size over time                                        | Low        | Low    | `backup.sh` only rsyncs assets; if repo grows past 1 GB, move large originals to git LFS or S3                                                                                        |
| Cloudflare DNS cutover takes longer than 5 min                                    | Low        | Medium | Pre-stage TTL=300s on Day -1 (Sat May 16); have the staging URL bookmark as fallback during the announcement                                                                          |
| Apex/www redirect loop on Cloudflare proxy                                        | Low        | Medium | Test `curl -sI https://www.mambakkam.net/` resolves to a single 301 (not a chain). Page Rule must not conflict with `Always Use HTTPS`                                                |
| Hetzner CX22 OOM under combined load (mambakkam is tiny but StudyBuddy is hungry) | Low        | Medium | mambakkam container resource limit set in compose (cpus: 0.25, mem: 128M); `docker stats` monitored on Day 1                                                                          |
| Static site goes stale (no fresh content for 6 months)                            | Medium     | Low    | Schedule monthly content review; `news/` collection acts as the heartbeat                                                                                                             |

---

## §6 · Pre-Launch Decisions Open as of May 8

These need a decision before Day -5 (Tue May 12) — flagging now so they don't surface on Day -1 (Sat May 16) as blockers.

1. **Analytics vendor.** Plausible (paid, privacy-friendly, ~$9/mo) or Google
   Analytics 4 (free, requires cookie banner)? Recommend Plausible; the
   site's village-first ethos doesn't need GA's depth.
2. **Hetzner location.** Already decided by StudyBuddy's choice (co-located).
3. **Pre-existing Netlify/Vercel deploys.** Keep alive until T+24h as a
   rollback target, then archive. Do not delete the deploy URLs yet.
4. **Sitemap submission to Google Search Console.** Submit on Day 0 (Sun May 17) after
   DNS cutover, not before — submitting against Netlify/Vercel URLs would
   leak the staging hostname into Google's index.
5. **Remove vendor tooling files.** `netlify.toml`, `vercel.json`,
   `sandbox.config.json` — keep until T+30d as fallback evidence, then
   delete in a follow-up PR.

### Decided 2026-05-08 — closed for the launch

**Hosting — co-located Hetzner CX22.** Confirmed 2026-05-08 over two
alternatives (dedicated CX22 or Cloudflare Pages). Trade-off: shared
failure domain with StudyBuddy in exchange for a single $7/mo bill and
a unified ops surface. Re-evaluate if either site outgrows the box.

**Email — Zoho free tier on `mambakkam.net`.** Confirmed 2026-05-08. Mailbox:
`siva@mambakkam.net`. No app-originated email at launch (no contact form);
SMTP wiring deferred to whenever a contact form ships.

### Decided 2026-05-09 — closed for the launch

**Tenancy order — mambakkam.net is the first tenant; StudyBuddy joins
later same day.** Inverts the original 2026-05-08 framing (which assumed
StudyBuddy provisioned the box first). Concrete consequences:

- mambakkam.net `provision.sh` performs the **full** system bootstrap
  (Docker, UFW, fail2ban, deploy user, host nginx, Origin Cert directory,
  daily-backup cron). StudyBuddy's `provision.sh` becomes the shorter
  second-tenant variant.
- mambakkam.net pays the $5/mo VPS bill plus the ~$1/mo domain.
  StudyBuddy joins at zero marginal infra cost from its side.
- Cloudflare Origin Cert is generated on Day -1 (Sat May 16) (mambakkam.net cold
  start) with the SAN list including `demo.usestudybuddy.com` so StudyBuddy
  can join without a re-issue.
- Cron offsets: mambakkam.net backup at 02:30 UTC; StudyBuddy at 02:00 UTC.
- Launch-day timing on Day 0 (Sun May 17): mambakkam.net cutover at T-0 = 09:00 EST;
  StudyBuddy second-tenant cutover at T+4h = 13:00 EST after ~4 hours
  of mambakkam.net stability.

---

## §7 · Observability

A third compose stack on the same CX22 ships metrics to Grafana Cloud free
tier. Full design + setup runbook in [`MONITORING.md`](MONITORING.md).

**One-paragraph summary:**
Local Prometheus on the CX22 (`127.0.0.1:9090`, ~150 MB RAM) scrapes a
small set of co-located targets — mambakkam's nginx via a sidecar exporter,
StudyBuddy's `/metrics` over loopback, the host via node-exporter, and a
blackbox-exporter probing both public hostnames every 15 s — then
`remote_write`s every series to Grafana Cloud (10k active series + 13-month
retention free, no card). Grafana Cloud (`<your-stack>.grafana.net`) is
where dashboards + alerts live; no local Grafana. Public `/metrics`
endpoints on both vhosts are gated by Cloudflare Access + nginx-side
Cloudflare-IP allowlist + (for StudyBuddy) the application bearer token.

**Where it fits in the launch timeline.** The monitoring stack is
**deliberately deferred** to after the launch is green:

- mambakkam-net's `provision.sh` creates `infra/monitoring/.env.monitoring`
  as a template during cold start (no scrape activity yet).
- After cutover (T+0 = 09:00) and stability confirmed (T+30m), operator
  signs up for Grafana Cloud, pastes credentials, runs:

      cd /opt/mambakkam/infra/monitoring
      docker compose --env-file .env.monitoring up -d

  before the StudyBuddy second-tenant cutover at T+4h = 13:00 — that way
  StudyBuddy is observable from the moment it joins.

- If launch-day pressure pushes monitoring out, that's fine — the stack
  scaffolding is in place; bringing it up is ~5 min any time after.

Outstanding before the operator can claim observability is "ready":

- Grafana Cloud account + stack created (one-time, ~5 min)
- `.env.monitoring` populated with real Grafana Cloud creds
- Cloudflare Access policies defined for `mambakkam.net/metrics` and
  `demo.usestudybuddy.com/metrics` (out-of-repo Cloudflare dashboard work)
- Starter dashboards imported in Grafana Cloud (StudyBuddy's existing
  `studybuddy-health` JSON works once data-source is repointed)

---

## §8 · Logging

Sister stack to §7 — same Promtail-to-Grafana-Cloud-Loki shape that §7 uses
for Prometheus-to-Grafana-Cloud-metrics. Full design + LogQL cheatsheet +
local-fallback runbook in [`LOGGING.md`](LOGGING.md).

**One-paragraph summary:**
Promtail (a fifth service in the monitoring compose stack) tails four
sources locally — every Docker container's stdout/stderr (auto-discovered),
host nginx vhost files, the systemd journal, and the cron-backup logs —
and pushes to Grafana Cloud Loki (50 GB / 14 d free). Searchable + alertable
in the same Grafana UI as metrics. mambakkam astrowind container logs go
to Docker json-file (capped 10 MB × 5); StudyBuddy compose now has the
same cap on every service via a YAML anchor. Nothing changes in the
application's `print`/`structlog` calls — stdout was already the
convention.

**Where it fits in the launch timeline.** Same as §7 — bring up Promtail
alongside the rest of the monitoring stack at T+30m to T+2h on Day 0 (Sun May 17),
before StudyBuddy joins at T+4h. Or defer the whole monitoring stack
post-launch; nothing about cutover depends on logs landing in Loki.

Outstanding before logging is "ready":

- Grafana Cloud Loki credentials in `.env.monitoring` (template ships
  via `provision.sh` step 13)
- Cloud Access Policy token scoped for `LogsWriter` in addition to
  `MetricsPublisher`
- (Optional) Log-based alerts configured in Grafana Cloud Alerting —
  recommended starter set in `LOGGING.md`

---

## §9 · Backups & Restore

Restic-based encrypted local backups on both repos; daily snapshot +
weekly integrity check + prune. Full design + 5-scenario restore runbook
in [`BACKUPS.md`](BACKUPS.md).

**One-paragraph summary:**
The existing `backup.sh` scripts were rewritten on 2026-05-09 to use restic
(encrypted, deduped, incremental) instead of rsync + gzip + pg_dump
files-as-timestamped-tarballs. Each site has its own repo at
`/opt/<site>/backups/restic/`, its own password at
`/etc/restic/<site>.password`, and a forget policy of `7 daily / 4 weekly /
3 monthly / 1 yearly` (~15 snapshots, ~1.2× one full snapshot on disk
thanks to dedup). A new `backup-check.sh` runs `restic check
--read-data-subset 5%` + `restic prune` weekly on Sundays. **Local-only
posture** — both repos live on the same CX22 disk as the originals, which
is acceptable for the demo and documented as residual risk in
`BACKUPS.md`.

**Where it fits in the launch timeline.** `provision.sh` for both sites
auto-installs restic, generates the password (printed ONCE — operator
must record), initialises the repo, and adds the daily + weekly cron
entries during cold start (mambakkam step 12; StudyBuddy step 8). First
daily backup fires at 02:00/02:30 UTC the first night.

**Restore drill on Day -2 of test phase (Fri May 15).** Inserted into §4
above — verifies the restic restore path against the staging box before
production launch.

Outstanding before backups are "ready":

- Both restic passwords saved to a password manager (out of band)
- One successful daily-cron run observed in `/var/log/<site>-backup.log`
- (Optional, post-launch) The 3 suggested LogQL alerts in `BACKUPS.md`
  wired in Grafana Cloud
- (Future) Off-box destination via `restic copy` to Hetzner Storage Box
  or Backblaze B2 — defer until first paying customer

---

## §10 · Alerts

14 alert rules live as YAML in
[`infra/monitoring/alerts/`](../infra/monitoring/alerts/) — 5 metric
rules (Mimir / Prometheus format) and 9 log rules (Loki / LogQL format).
Per-alert response procedures + notification routing setup in
[`RUNBOOK.md`](RUNBOOK.md).

**One-paragraph summary:**
Alert rules are uploaded to Grafana Cloud's Mimir + Loki ruler APIs via
`bash infra/monitoring/alerts/apply.sh` (idempotent; re-run on every
edit). Notification routing is click-ops in the Grafana Cloud UI per
`RUNBOOK.md` §"Notification routing setup" — single Gmail destination
with `[PAGE]` / `[WARN]` subject prefixes that two Gmail filters split
into separate labels. Best-effort coverage by a single operator;
nothing wakes you at 3am.

**Severity assignments at-a-glance:**

| Pages (immediate, customer/DR impact)                                                                                  | Warns (next time at keyboard)                                                                                               |
| ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| MambakkamDown, StudyBuddyDown, StudyBuddyHighErrorRate, Demo5xxRateHigh, CX22DiskFull, BackupSilent, ResticCheckFailed | CX22LowMemory, StudyBuddyErrorBurst, MambakkamErrorLogs, ResticPruneFailed, BackupSizeRunaway, SSHBruteForce, Fail2banBurst |

**Where it fits in the launch timeline.** Apply rules at the same time
the rest of the monitoring stack is brought up (T+30m to T+2h on
Day 0 (Sun May 17)). One end-to-end alert test-fire is a Day -2 (Fri May 15) test-plan
gate — see §4 above.

Outstanding before alerts are "ready":

- Cloud Access Policy token scoped for `RulesWriter` (in addition to
  Metrics + Logs writer scopes)
- Notification policy + Gmail filters configured per `RUNBOOK.md`
- One synthetic page test-fired and received (Day 3 test plan)

---

## Change Log

| Date       | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-09 | Initial — comprehensive plan for May 16 launch (4 days code freeze + 4 days test phase); co-located on StudyBuddy Hetzner CX22; Zoho free-tier email                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| 2026-05-09 | **Tenancy-order flip** — mambakkam.net is now the first tenant on a fresh CX22; StudyBuddy joins as second tenant later the same day on May 16 (T+4h after mambakkam.net cutover). Re-framed §0 cost narrative, §1.A.bis Phase 3 Zoho note, §2 launch-day timing, §2.5 cold-start sequence, §3.1 provision.sh inventory, Day 1 + Day 4 of test plan. Added §6 "Decided 2026-05-09" block. Flagged outstanding work on `scripts/launch/provision.sh` (must add Docker/UFW/fail2ban/deploy-user steps before May 12).                                                                                                                                                                                                                                                                                |
| 2026-05-09 | **Observability scaffolded** — added §7 plus full design in `MONITORING.md`. Prometheus + nginx-exporter + blackbox + node-exporter as a third compose stack on the CX22; remote_write to Grafana Cloud free tier (no local Grafana). `provision.sh` writes the `.env.monitoring` template; operator brings the stack up post-cutover. Public `/metrics` on both vhosts is Cloudflare-Access-gated.                                                                                                                                                                                                                                                                                                                                                                                                |
| 2026-05-09 | **Logging scaffolded** — added §8 plus full design in `LOGGING.md`. Promtail joins the monitoring compose stack as a fifth service; ships docker / nginx / journald / backup logs to Grafana Cloud Loki free tier (50 GB / 14 d). Loki creds added to `.env.monitoring` template (separate URL + numeric user from Prometheus; same access-policy token works if scoped).                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 2026-05-09 | **Backups rewritten** — added §9 plus full design + restore runbook in `BACKUPS.md`. Replaced rsync+pg_dump+gzip with restic (encrypted + deduped + incremental). New weekly integrity-check script; password auto-generated by `provision.sh` and printed once. Day 3 restore-drill row added to §4 test plan. Local-only posture; off-box deferred until first paying customer.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 2026-05-09 | **Alerts as code** — added §10 + new `Plans/RUNBOOK.md` consolidating the 14 alerts that were previously scattered across MONITORING / LOGGING / BACKUPS docs. Rules ship as YAML in `infra/monitoring/alerts/` with an idempotent `apply.sh` upload helper. Two-severity Gmail routing (`[PAGE]` / `[WARN]` subject prefix). Per-alert response runbook entries. Day 3 alert-test-fire row added to §4.                                                                                                                                                                                                                                                                                                                                                                                           |
| 2026-05-09 | **Day-N labels + date shift** — launch slipped from May 16 → May 17 (Day 0 = Sun May 17). Day -5 to Day -1 labels added to the 4-day test phase (May 13-16); Day 0 = launch, Day 1 = first day live (May 18). Code-freeze cutoff stays at May 12 EOD (now Day -5). Day-of-week labels in the original timeline were corrected (off by one). All section headers + body text updated; sibling docs (DEPLOYMENT/MONITORING/LOGGING/BACKUPS/RUNBOOK + provision.sh) shifted in the same pass.                                                                                                                                                                                                                                                                                                         |
| 2026-05-09 | **Concrete Day -1 / Day 0 timing** — operator anchored times: Day -1 (Sat May 16) 17:00-19:00 EDT for account + email setup (Cloudflare, Hetzner, Zoho, Grafana Cloud); Day 0 (Sun May 17) 08:00 EDT operator arrives at the VPS, T-0 (public cutover) at 09:00 EDT. Replaced the prior abstract T-2h/T-1h/T-30m table with a wall-clock minute-by-minute version anchored on 08:00 EDT start.                                                                                                                                                                                                                                                                                                                                                                                                     |
| 2026-05-09 | **GitHub deploy auth deferred to Day 0** — the SSH keypair + 3 repo secrets (`MAMBAKKAM_VPS_HOST`, `MAMBAKKAM_VPS_USER`, `MAMBAKKAM_VPS_SSH_KEY`) + the `MAMBAKKAM_DEPLOY_ENABLED` Variable now happen on Day 0 morning instead of pre-launch. §2 cutover table split into two rows at 08:28 + 08:30 (keypair gen + pubkey paste; then GitHub Settings UI). Subsequent rows shifted +2 min (.env.demo edit at 08:32, container build at 08:34). Prerequisites list updated to call out the deferral explicitly. Rationale: consolidates all "credentials and pasting" work into the Day 0 cutover window, reduces pre-launch operator overhead, keeps the deploy workflow's existing `if: vars.MAMBAKKAM_DEPLOY_ENABLED == 'true'` gate as the single switch that goes from "skipped" to "active". |
