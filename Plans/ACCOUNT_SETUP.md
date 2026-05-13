# Account & Email Setup — Day -1 (Sat May 16) 17:00–20:30 EDT

**Document version:** 1.0
**Date:** 2026-05-09
**Audience:** Operator (Sivakumar)
**Window:** Day -1 (Sat May 16 2026), 17:00–20:30 EDT (3.5 hr block)
**Companion docs:**

- [`DEMO_LAUNCH_PLAN.md`](DEMO_LAUNCH_PLAN.md) — referenced from §2 Day -1 evening
- [`MONITORING.md`](MONITORING.md) · [`LOGGING.md`](LOGGING.md) — Grafana Cloud setup
- [`StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/docs/DEMO_LAUNCH_PLAN.md) — Auth0 / Stripe / Sentry context

---

## TL;DR

Sit down with a password manager open at 17:00 EDT. Work through the 9
sections below in order. Every section ends with what you need to copy
into the password manager. By 20:30 EDT you have everything tomorrow's
`provision.sh` runs need.

| Section | Time block  | Account                                      | Why                                               |
| ------- | ----------- | -------------------------------------------- | ------------------------------------------------- |
| 1       | 17:00–17:15 | Cloudflare                                   | DNS for both domains, Origin Cert with shared SAN |
| 2       | 17:15–17:25 | Hetzner Cloud                                | VPS provider; SSH key only — no CX22 yet          |
| 3       | 17:25–17:55 | Zoho Mail                                    | mambakkam.net mailbox + DNS records               |
| 4       | 17:55–18:15 | Gmail send-as                                | Compose-from custom domain                        |
| 5       | 18:15–18:40 | Grafana Cloud                                | Metrics + logs + alert rules                      |
| 6       | 18:40–18:50 | Pre-stage DNS for mambakkam                  | Day-0 cutover is just a value change              |
| 7       | 19:00–19:25 | studybuddy.app domain + DNS + Zoho mailboxes | StudyBuddy-side setup begins                      |
| 8       | 19:25–19:50 | Auth0 dev tenant                             | Student + teacher login                           |
| 9       | 19:50–20:30 | Stripe (test mode) + Sentry                  | Payments + error tracking                         |

**Total:** 3.5 hours. Budget 4 if Zoho DKIM verification stalls.

**No credit card needed for:** Cloudflare, Zoho free tier, Grafana Cloud, Auth0 free tier, Stripe (test mode), Sentry free tier, Plausible has paid only.
**Credit card needed for:** Hetzner Cloud (€7.50 deposit credit; CX22 billing starts Day 0 morning when you spin one up).

---

## Prerequisites — open BEFORE you start at 17:00 EDT

- [ ] Personal email account (for all sign-ups) — recommend a dedicated account or +alias e.g. `you+studybuddy-launch@gmail.com`
- [ ] Phone for 2FA (most providers require it)
- [ ] Password manager unlocked (1Password, Bitwarden, etc.) with a fresh "StudyBuddy Launch May 2026" vault/folder
- [ ] Credit card (Hetzner only)
- [ ] Confirmation that you currently own `mambakkam.net` (check current registrar; you'll move DNS to Cloudflare in §1)
- [ ] This document open in another tab

**Naming convention for password-manager entries** — use this consistently:

```
[Launch May 2026] Cloudflare account
[Launch May 2026] Cloudflare Origin Cert (mambakkam + studybuddy SAN)
[Launch May 2026] Hetzner Cloud account
[Launch May 2026] Hetzner SSH keypair
[Launch May 2026] Zoho org admin
[Launch May 2026] Zoho App Password (Gmail integration)
... (one entry per credential)
```

The bracket prefix lets you find them all with one search later.

---

## §1 — Cloudflare (17:00–17:15, 15 min)

mambakkam.net is presumed already registered at a previous registrar.
You're moving DNS to Cloudflare nameservers and pre-configuring SSL.

### 1.1 — Account

- [ ] Sign up at https://dash.cloudflare.com/sign-up
- [ ] Verify email
- [ ] Enable 2FA (Account → Profile → Authentication)
- [ ] **Save** to password manager: `[Launch May 2026] Cloudflare account` (email + password)

### 1.2 — Add `mambakkam.net` zone

- [ ] Cloudflare dashboard → "+ Add a Site" → enter `mambakkam.net` → Free plan
- [ ] Cloudflare scans existing DNS records — review for stale Netlify/Vercel A/AAAA records (delete any not part of the launch plan)
- [ ] Note Cloudflare's two assigned nameservers (e.g. `kim.ns.cloudflare.com`, `walt.ns.cloudflare.com`)
- [ ] **Go to your previous registrar** (where mambakkam.net was registered) and change the nameservers to those two values
- [ ] Wait — propagation can take up to 24h, but usually <30 min. **Move on to §1.3 while you wait.**

**Verify (later, can run from terminal anytime):**

```bash
dig NS mambakkam.net +short
# Expect: kim.ns.cloudflare.com / walt.ns.cloudflare.com (or whatever Cloudflare assigned)
```

### 1.3 — Generate Cloudflare Origin Certificate (SAN list for both domains)

- [ ] In Cloudflare dashboard → mambakkam.net zone → **SSL/TLS → Origin Server → Create Certificate**
- [ ] Key type: **RSA** (default; ECDSA also fine)
- [ ] Hostnames — type each on a new line:
  ```
  mambakkam.net
  *.mambakkam.net
  demo.studybuddy.app
  ```
  _Important:_ `demo.studybuddy.app` must be in the SAN list now even though that domain isn't on Cloudflare yet — Cloudflare allows it because Origin Certs are issued by Cloudflare's PKI and don't require domain ownership at generation time. StudyBuddy uses this same cert when it joins on Day 0 afternoon.
- [ ] Validity: **15 years** (default)
- [ ] Click "Create" — Cloudflare displays the certificate + private key ONCE
- [ ] **Copy both** to the password manager:
  - `[Launch May 2026] Cloudflare Origin Cert (cert PEM)`
  - `[Launch May 2026] Cloudflare Origin Key (private key PEM)`
  - SAN list = `mambakkam.net + *.mambakkam.net + demo.studybuddy.app`
- [ ] Tomorrow morning you'll paste these into `/etc/ssl/cloudflare/origin-{cert,key}.pem` on the VPS

### 1.4 — SSL/TLS settings for `mambakkam.net`

- [ ] Cloudflare dashboard → mambakkam.net → **SSL/TLS → Overview**
- [ ] Set encryption mode: **Full (strict)**
- [ ] **SSL/TLS → Edge Certificates** → **Always Use HTTPS** = **ON**
- [ ] **Speed → Optimization** → leave defaults (Auto Minify is fine; Rocket Loader off)

> studybuddy.app DNS work happens in §7 below, after the domain is registered.

---

## §2 — Hetzner Cloud (17:15–17:25, 10 min)

Sign up + add SSH key. **Don't actually create the CX22 yet** — that's
Day 0 (Sun May 17) morning at 08:00 EDT, after you've slept.

### 2.1 — Account

- [ ] Sign up at https://accounts.hetzner.com/signUp
- [ ] Verify email
- [ ] Add credit card / enable bank transfer (€7.50 initial credit)
- [ ] Enable 2FA
- [ ] **Save** to password manager: `[Launch May 2026] Hetzner Cloud account`

### 2.2 — SSH key for the deploy user

If you don't already have a dedicated SSH keypair for VPS access, generate one now:

```bash
# On your laptop, in ~/.ssh/:
ssh-keygen -t ed25519 -f ~/.ssh/mambakkam_cx22 -C "mambakkam-launch-2026"
# Press enter for no passphrase OR set a passphrase (more secure but requires ssh-agent)
```

This creates two files:

- `~/.ssh/mambakkam_cx22` (private key — never share)
- `~/.ssh/mambakkam_cx22.pub` (public key — paste into Hetzner)

- [ ] Hetzner Cloud Console → **Security → SSH Keys → Add SSH Key**
- [ ] Paste the contents of `~/.ssh/mambakkam_cx22.pub`
- [ ] Name: `mambakkam-launch-2026`
- [ ] **Save** to password manager: `[Launch May 2026] Hetzner SSH keypair` — paste the **private key** (`~/.ssh/mambakkam_cx22`)
- [ ] Note the SSH key fingerprint shown by Hetzner (compare with `ssh-keygen -lf ~/.ssh/mambakkam_cx22.pub` on your laptop)

### 2.3 — (Optional) Hetzner API token for snapshots

If you want **StudyBuddy_OnDemand's** [`scripts/demo/backup.sh`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/scripts/demo/backup.sh) (lives in a different repo) to also trigger a Hetzner **server image snapshot** as belt-and-braces alongside its restic backup. Note: this is StudyBuddy-only; mambakkam's `scripts/launch/backup.sh` does not call the Hetzner API and doesn't need this token.

- [ ] Hetzner Cloud Console → **Security → API Tokens → Generate API Token**
- [ ] Name: `studybuddy-snapshot-trigger`, permissions: **Read & Write**
- [ ] Copy the token (shown ONCE)
- [ ] **Save** to password manager: `[Launch May 2026] Hetzner API token (HCLOUD_TOKEN)`

Skip if you don't want Hetzner-side snapshots — restic local backups are sufficient for the demo.

### 2.4 — Pick the region

- [ ] Decide: **Falkenstein (Germany)** is the default for EU/GDPR + cheapest. Helsinki (Finland) and Ashburn (USA) are alternatives if your demo audience is geographically distinct.
- [ ] **Note**: `Falkenstein (DEU)` (or your choice) — you'll select this tomorrow when creating the CX22

---

## §3 — Zoho Mail (17:25–17:55, 30 min)

mambakkam.net mailbox first. studybuddy.app mailboxes get added in §7
once that domain is registered.

### 3.1 — Org + first domain

- [ ] Sign up at https://www.zoho.com/mail/zohomail-pricing.html → **Forever Free Plan**
- [ ] Verify email
- [ ] Enable 2FA
- [ ] At "Add domain" prompt — enter `mambakkam.net`
- [ ] Zoho displays a verification TXT record (e.g. `zoho-verification=zb12345abc...`)
- [ ] **Save** to password manager: `[Launch May 2026] Zoho org admin`

### 3.2 — Verification TXT at Cloudflare

> **Prerequisite:** §1.2 nameserver change at your previous registrar must have propagated to Cloudflare being authoritative for `mambakkam.net`. Verify with `dig NS mambakkam.net +short` returning Cloudflare's two nameservers. If not yet propagated (usually <30 min, can be up to 24h), come back to §3.2 later — DO NOT add the TXT record at the previous registrar instead, you'll have to redo it.

- [ ] Cloudflare → mambakkam.net → **DNS → Records → + Add record**
- [ ] Type: **TXT**, Name: **@** (apex), Content: paste the `zoho-verification=...` value, TTL: Auto, Proxy: **DNS only** (grey cloud, not orange)
- [ ] Save
- [ ] Wait ~2 min for propagation, then back in Zoho click **"Verify"**

**Verify (terminal):**

```bash
dig TXT mambakkam.net +short
# Expect to see "zoho-verification=zb..." among the results
```

### 3.3 — Mailbox + DNS records (MX, SPF, DKIM, DMARC)

- [ ] In Zoho post-verification — create mailbox `siva@mambakkam.net` (or your chosen handle); set a strong password
- [ ] Zoho displays four sets of records to add at Cloudflare. Copy each carefully:

#### MX records (3 entries)

- [ ] Cloudflare → DNS → + Add record:
  - Type: **MX**, Name: **@**, Server: **mx.zoho.com**, Priority: **10**
- [ ] Repeat: Server: **mx2.zoho.com**, Priority: **20**
- [ ] Repeat: Server: **mx3.zoho.com**, Priority: **50**

#### SPF (single TXT at apex)

- [ ] Type: **TXT**, Name: **@**, Content: `v=spf1 include:zoho.com ~all`, Proxy: DNS only

#### DKIM

- [ ] In Zoho → Domains → mambakkam.net → **Email Configuration → DKIM** — Zoho generates a public key
- [ ] Cloudflare DNS → + Add record:
  - Type: **TXT**, Name: **zmail.\_domainkey**, Content: paste Zoho's public key string

#### DMARC (single TXT)

- [ ] Type: **TXT**, Name: **\_dmarc**, Content: `v=DMARC1; p=quarantine; rua=mailto:siva@mambakkam.net`

#### Verify all four green in Zoho

- [ ] Back in Zoho's UI, click **Verify** on each (MX, SPF, DKIM). DKIM may take 5-10 min.
- [ ] Once all green, **save** to password manager: `[Launch May 2026] Zoho mailbox siva@mambakkam.net` (email + password)

**Verify (terminal):**

```bash
dig MX mambakkam.net +short                # mx.zoho.com / mx2.zoho.com / mx3.zoho.com
dig TXT mambakkam.net +short | grep spf1   # v=spf1 include:zoho.com ~all
dig TXT zmail._domainkey.mambakkam.net +short  # long key string starting v=DKIM1
dig TXT _dmarc.mambakkam.net +short        # v=DMARC1...
```

### 3.4 — App Password for Gmail integration

- [ ] In Zoho → Profile → **Security → Application-Specific Passwords → Generate**
- [ ] Description: `Gmail send-as integration (mambakkam)`
- [ ] Zoho displays the App Password ONCE (16-char string)
- [ ] **Save** to password manager: `[Launch May 2026] Zoho App Password (mambakkam Gmail)`

---

## §4 — Gmail send-as for `siva@mambakkam.net` (17:55–18:15, 20 min)

Lets you compose mail FROM `siva@mambakkam.net` while reading via Gmail.

### 4.1 — Add as send-as identity

> **Prerequisite:** §3.3 MX records must be propagated and accepting mail. Gmail's verification email below goes TO `siva@mambakkam.net`, which means MX needs to be live. Quick check: `dig MX mambakkam.net +short` returns `mx.zoho.com / mx2.zoho.com / mx3.zoho.com`. If empty or wrong, wait — §3.3 may still be propagating. If the verification email doesn't arrive within 10 min, this is the most likely cause (not Gmail being slow).

- [ ] In Gmail → **Settings (gear) → See all settings → Accounts and Import → Send mail as → Add another email address**
- [ ] Name: `Siva Mambakkam`, Email: `siva@mambakkam.net`, **Treat as alias: NO** (uncheck), → Next
- [ ] SMTP Server: `smtp.zoho.com`, Port: `465`, Username: `siva@mambakkam.net`, Password: paste the Zoho App Password from §3.4, **Secured connection using SSL** (default), → Add Account
- [ ] Gmail sends a verification email to `siva@mambakkam.net` — open Zoho mail, find it, click the confirm link
- [ ] Back in Gmail, **set as default From if you want** (probably keep your personal Gmail as default)

### 4.2 — Test round-trip

- [ ] Compose new mail in Gmail — From dropdown shows `Siva Mambakkam <siva@mambakkam.net>`
- [ ] Send to your personal Gmail (or any address you can read)
- [ ] Reply from there — confirm reply lands in Zoho inbox
- [ ] **Verify** the test message in Zoho webmail (https://mail.zoho.com)

If round-trip works, mambakkam mail is fully wired.

---

## §5 — Grafana Cloud (18:15–18:40, 25 min)

Free tier covers all of demo's metrics + logs + alerts. No card.

### 5.1 — Account + stack

- [ ] Sign up at https://grafana.com/auth/sign-up/create-user
- [ ] Verify email; pick "Just for me / Hobby"
- [ ] Enable 2FA
- [ ] Create stack — name: `studybuddy-demo` (or similar), region: pick close to Hetzner location (e.g. **prod-eu-west-2** if Falkenstein)
- [ ] **Save** to password manager: `[Launch May 2026] Grafana Cloud account`

### 5.2 — Capture Prometheus remote_write credentials

- [ ] In your stack's overview → **Connections** (top nav) → **Hosted Prometheus metrics** → click **"Send Metrics"**
- [ ] Copy the two values shown on this page to the password manager:
  - **URL** (looks like `https://prometheus-prod-XX-prod-YY.grafana.net/api/prom/push`) → `GRAFANA_CLOUD_REMOTE_WRITE_URL`
  - **Username** (numeric, e.g. `1234567`) → `GRAFANA_CLOUD_USERNAME`
- [ ] The third Prometheus credential (`GRAFANA_CLOUD_API_KEY`) is the access-policy token generated below in §5.4 — same token serves Prometheus, Loki, and the alert ruler.
- [ ] **Save** to password manager: `[Launch May 2026] Grafana Cloud Prometheus URL + user`

### 5.3 — Capture Loki credentials

- [ ] Same Connections page → **Hosted Logs** → click **"Send Logs"**
- [ ] Loki has its own URL + numeric user (different from Prometheus):
  - **URL** (looks like `https://logs-prod-NN-prod-YY.grafana.net`) → `GRAFANA_CLOUD_LOKI_URL`
  - **Username** (different numeric ID from Prometheus) → `GRAFANA_CLOUD_LOKI_USERNAME`
- [ ] **Save**: `[Launch May 2026] Grafana Cloud Loki URL + user`

### 5.4 — Generate Cloud Access Policy token (single token, multiple scopes)

- [ ] Stack → **Access Policies** → **Create access policy**
- [ ] Name: `studybuddy-demo-vps`
- [ ] Scopes — check ALL of:
  - `metrics:write` (Prometheus push)
  - `logs:write` (Loki push)
  - `alerts:write` (Mimir + Loki ruler API for alert rules)
- [ ] Save policy → **Add token** under that policy → token name `studybuddy-demo-vps-token`
- [ ] Copy the token shown (only displayed ONCE)
- [ ] **Save** to password manager: `[Launch May 2026] Grafana Cloud token (GRAFANA_CLOUD_API_KEY)`

### 5.5 — (Optional) Notification contact point

You can do this now or later. Per `RUNBOOK.md`, the contact point is just an
email destination + two notification policies that match on `severity=page`
or `severity=warn`. Skip for tonight if you're tired — you can configure it
during Day -2 alert-test-fire (Fri May 15) instead.

---

## §6 — Pre-stage DNS for `mambakkam.net` (18:40–18:50, 10 min)

Create the apex A record now with a placeholder IP and TTL=300s. Tomorrow
morning you change the value to the real CX22 IP — much faster than
creating a new record under launch-day pressure.

- [ ] Cloudflare → mambakkam.net → DNS → **+ Add record**
- [ ] Type: **A**, Name: **@** (apex), IPv4: **192.0.2.1** (RFC 5737 documentation IP — placeholder), TTL: **5 min** (Cloudflare may show this as a 300-second value), Proxy: **DNS only** (grey cloud) for now
- [ ] Save
- [ ] **+ Add record** for **www**: Type: **CNAME**, Name: **www**, Target: **mambakkam.net**, Proxy: **DNS only**

> Tomorrow morning at ~08:45 EDT (mambakkam T-15m), you'll edit the apex A record value from `192.0.2.1` to the real Hetzner CX22 IP and **enable proxy** (orange cloud).

**Verify:**

```bash
dig mambakkam.net +short    # 192.0.2.1
dig www.mambakkam.net +short # mambakkam.net (then 192.0.2.1)
```

### Wrap-up of mambakkam side (18:50–19:00, 10 min)

- [ ] All §1-§6 items have entries in the password manager
- [ ] Mark this section complete in your operator notebook
- [ ] Stretch break before StudyBuddy work below

---

## §7 — `studybuddy.app` domain + DNS + Zoho mailboxes (19:00–19:25, 25 min)

### 7.1 — Register the domain

- [ ] Cloudflare dashboard → **Domain Registration → Register Domain** → search `studybuddy.app`
- [ ] If available, add to cart and complete purchase (~$12-15/yr for `.app`; auto-renew default ON; ICANN privacy on)
- [ ] **Save** to password manager: `[Launch May 2026] studybuddy.app domain` — note the registration date + auto-renew status
- [ ] Cloudflare automatically configures the zone — no nameserver migration needed since registration was at Cloudflare itself

> If `studybuddy.app` is unavailable, decide on alternative: `studybuddy.io`, `studybuddy.dev`, `studybuddy.cloud`. Update `.env.demo`'s `FRONTEND_URL` and the host-nginx vhost `server_name` accordingly tomorrow morning.

### 7.2 — Cloudflare DNS for `demo.studybuddy.app`

- [ ] Cloudflare → studybuddy.app → DNS → **+ Add record**
- [ ] Type: **A**, Name: **demo**, IPv4: **192.0.2.1** (placeholder, same idea as §6), TTL: **5 min**, Proxy: **DNS only** (off — turning proxy on without a working origin would 502; flip to orange tomorrow morning at 12:45 EDT during StudyBuddy cutover)

### 7.3 — SSL/TLS for studybuddy.app

- [ ] Cloudflare → studybuddy.app → **SSL/TLS → Overview** → Mode: **Full (strict)**
- [ ] **SSL/TLS → Edge Certificates** → **Always Use HTTPS** = **ON**
- [ ] (Origin Cert was already generated in §1.3 with `demo.studybuddy.app` in the SAN list — no work here)

### 7.4 — Add studybuddy.app to existing Zoho org

- [ ] Zoho admin console → Domains → **+ Add Domain** → enter `studybuddy.app`
- [ ] Add the Zoho verification TXT at Cloudflare DNS (same pattern as §3.2)
- [ ] Verify in Zoho

### 7.5 — Mailboxes + DNS for studybuddy.app

- [ ] Create mailbox `support@studybuddy.app` (strong password)
- [ ] Create mailbox `sales@studybuddy.app` (strong password)
- [ ] Add MX (mx.zoho.com / mx2 / mx3 — same priorities as §3.3) at Cloudflare for **studybuddy.app**
- [ ] Add SPF: TXT @ `v=spf1 include:zoho.com ~all`
- [ ] Add DKIM: from Zoho config
- [ ] Add DMARC: TXT \_dmarc `v=DMARC1; p=quarantine; rua=mailto:support@studybuddy.app`
- [ ] **Save** to password manager:
  - `[Launch May 2026] Zoho mailbox support@studybuddy.app`
  - `[Launch May 2026] Zoho mailbox sales@studybuddy.app`

### 7.6 — Generate App Password for Gmail integration (StudyBuddy)

- [ ] In Zoho → Profile → Security → App Passwords → **Generate**
- [ ] Description: `Gmail send-as integration (studybuddy.app)`
- [ ] Note: this is a SECOND App Password for the same Zoho account; `support@studybuddy.app` and `siva@mambakkam.net` are independent send-as identities in Gmail
- [ ] **Save** to password manager: `[Launch May 2026] Zoho App Password (studybuddy.app Gmail)`

### 7.7 — Add support@studybuddy.app as Gmail send-as (optional but recommended)

- [ ] Gmail → Settings → Accounts → Send mail as → **Add another email address** → use the App Password from §7.6
- [ ] Verify via the Zoho mailbox confirmation link

---

## §8 — Auth0 dev tenant (19:25–19:50, 25 min)

Free tier — 7,500 MAU, more than enough for the demo.

### 8.1 — Account + tenant

- [ ] Sign up at https://auth0.com/signup
- [ ] Pick "Personal" → free dev tenant
- [ ] Tenant name: `studybuddy-demo` (lowercase, no special chars). Region: closest to Hetzner location (US, EU, AU)
- [ ] Note your tenant domain — looks like `studybuddy-demo.us.auth0.com` (region-prefixed)
- [ ] Enable 2FA on your Auth0 admin login
- [ ] **Save** to password manager: `[Launch May 2026] Auth0 admin account` + `[Launch May 2026] Auth0 tenant domain` (= `studybuddy-demo.<region>.auth0.com`)

### 8.2 — Student application (Single Page App)

- [ ] Auth0 dashboard → **Applications → Create Application**
- [ ] Name: `StudyBuddy Student`, Type: **Single Page Application** → Create
- [ ] Settings tab:
  - **Allowed Callback URLs:** `https://demo.studybuddy.app/auth/callback, http://localhost:3000/auth/callback`
  - **Allowed Logout URLs:** `https://demo.studybuddy.app, http://localhost:3000`
  - **Allowed Web Origins:** `https://demo.studybuddy.app, http://localhost:3000`
- [ ] Save changes
- [ ] **Note + save** to password manager:
  - `[Launch May 2026] Auth0 student client_id` (the **Client ID** from this app's Settings tab)

### 8.3 — Teacher application (separate SPA)

- [ ] Same as 8.2 but Name: `StudyBuddy Teacher`, with same callback URLs
- [ ] **Note + save**: `[Launch May 2026] Auth0 teacher client_id`

### 8.4 — Management API M2M application (for backend → Auth0 admin operations)

- [ ] Auth0 → Applications → Create Application → Name: `StudyBuddy Backend M2M`, Type: **Machine to Machine**
- [ ] Authorize for the **Auth0 Management API**
- [ ] Permissions (scopes): pick the minimum your app needs. Common: `read:users`, `update:users`, `delete:users`. (Your backend code reveals exactly which.)
- [ ] **Note + save**:
  - `[Launch May 2026] Auth0 M2M client_id`
  - `[Launch May 2026] Auth0 M2M client_secret`
  - `[Launch May 2026] Auth0 M2M API URL` = `https://studybuddy-demo.<region>.auth0.com/api/v2/`

### 8.5 — JWKS URL

This is derived from your tenant domain — no separate config needed:

- `[Launch May 2026] Auth0 JWKS URL` = `https://studybuddy-demo.<region>.auth0.com/.well-known/jwks.json`

### 8.6 — Verify

- [ ] In Auth0 → Applications, you should now see 3 applications listed: Student SPA, Teacher SPA, Backend M2M

---

## §9 — Stripe (test mode) + Sentry (19:50–20:30, 40 min)

### 9.1 — Stripe sign-up

- [ ] Sign up at https://dashboard.stripe.com/register
- [ ] Email + password; do NOT activate live mode (no business info needed for test mode)
- [ ] Enable 2FA
- [ ] **Save** to password manager: `[Launch May 2026] Stripe account`

### 9.2 — Test mode keys

- [ ] Top-right toggle: confirm **"Test mode"** is ON (orange tag)
- [ ] **Developers → API keys**
- [ ] **Note + save** to password manager:
  - `[Launch May 2026] Stripe sk_test_*` (Secret key, click "Reveal")
  - `[Launch May 2026] Stripe pk_test_*` (Publishable key)

### 9.3 — Test webhook endpoint

- [ ] **Developers → Webhooks → + Add endpoint**
- [ ] Endpoint URL: `https://demo.studybuddy.app/api/v1/subscriptions/webhook`
- [ ] **Listen to**: select these events at minimum:
  - `checkout.session.completed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.payment_succeeded`
  - `invoice.payment_failed`
- [ ] After creation, Stripe shows the **Signing secret** (`whsec_...`)
- [ ] **Note + save**: `[Launch May 2026] Stripe webhook signing secret (STRIPE_WEBHOOK_SECRET)`

> The webhook will return 4xx tonight because demo.studybuddy.app isn't live yet — that's expected. Stripe retries on failure; once StudyBuddy is up tomorrow, the next test event will succeed.

### 9.4 — Sentry sign-up

- [ ] Sign up at https://sentry.io/signup/
- [ ] Free Developer plan (no card)
- [ ] Org name: `studybuddy` (or your handle)
- [ ] **Save** to password manager: `[Launch May 2026] Sentry account`

### 9.5 — Create project + DSN

- [ ] **Projects → Create project**
- [ ] Platform: **Python (FastAPI)**, Alert frequency: defaults are fine
- [ ] Project name: `studybuddy-api`
- [ ] After creation, Sentry shows the DSN (looks like `https://xxx@oNNN.ingest.sentry.io/PPP`)
- [ ] **Note + save**: `[Launch May 2026] Sentry DSN`

> Optional: create a second Sentry project for the Next.js frontend if you want separate error streams. The backend project alone is enough for the demo.

### 9.6 — Final go/no-go (20:25–20:30, 5 min)

Run through this checklist before closing the laptop:

- [ ] All §1-§9 items have entries in the password manager (~25 entries total)
- [ ] You have one consolidated note somewhere with the values you'll paste into `.env.demo` tomorrow morning (see §10 below)
- [ ] DNS for both `mambakkam.net` and `demo.studybuddy.app` is pre-staged at Cloudflare with TTL=5min, proxy off
- [ ] Cloudflare Origin Cert + key are in the password manager
- [ ] Hetzner SSH private key is in the password manager
- [ ] You have NOT yet provisioned a CX22 (Day 0 morning at 08:00 EDT)
- [ ] Tomorrow morning's checklist starts with: open this file, open the password manager, open `mambakkam-net/Plans/DEMO_LAUNCH_PLAN.md` §2 Day 0 runbook

If any unchecked, finish before 22:00 EDT or set an alarm to do them at 06:00 EDT Sunday before starting Day 0 work.

---

## §10 — Values to paste into `.env.demo` tomorrow morning

Day 0 cheat-sheet — this is the consolidated list of values you'll paste
into `/opt/mambakkam/.env.demo` and `/opt/studybuddy/.env.demo` tomorrow
morning. Pull each from the password manager.

### `/opt/mambakkam/.env.demo`

| Variable                                | Source                                                  |
| --------------------------------------- | ------------------------------------------------------- |
| `PLAUSIBLE_DOMAIN` (if using Plausible) | Plausible site setup — defer; not on tonight's list     |
| `SMTP_HOST=smtp.zoho.com`               | static                                                  |
| `SMTP_PORT=465`                         | static                                                  |
| `SMTP_USER=siva@mambakkam.net`          | static                                                  |
| `SMTP_PASSWORD`                         | `[Launch May 2026] Zoho App Password (mambakkam Gmail)` |

### `/opt/studybuddy/.env.demo` (~12 lines need pasting; rest auto-generated by `openssl rand`)

| Variable                           | Source                                                       |
| ---------------------------------- | ------------------------------------------------------------ |
| `JWT_SECRET`                       | run `openssl rand -hex 32`                                   |
| `ADMIN_JWT_SECRET`                 | run `openssl rand -hex 32`                                   |
| `METRICS_TOKEN`                    | run `openssl rand -hex 32`                                   |
| `POSTGRES_PASSWORD`                | run `openssl rand -hex 32`                                   |
| `REDIS_PASSWORD`                   | run `openssl rand -hex 32`                                   |
| `AUTH0_DOMAIN`                     | `[Launch May 2026] Auth0 tenant domain`                      |
| `AUTH0_JWKS_URL`                   | `[Launch May 2026] Auth0 JWKS URL`                           |
| `AUTH0_STUDENT_CLIENT_ID`          | `[Launch May 2026] Auth0 student client_id`                  |
| `AUTH0_TEACHER_CLIENT_ID`          | `[Launch May 2026] Auth0 teacher client_id`                  |
| `AUTH0_MGMT_CLIENT_ID`             | `[Launch May 2026] Auth0 M2M client_id`                      |
| `AUTH0_MGMT_CLIENT_SECRET`         | `[Launch May 2026] Auth0 M2M client_secret`                  |
| `AUTH0_MGMT_API_URL`               | `[Launch May 2026] Auth0 M2M API URL`                        |
| `SMTP_USER=support@studybuddy.app` | static                                                       |
| `SMTP_PASSWORD`                    | `[Launch May 2026] Zoho App Password (studybuddy.app Gmail)` |
| `STRIPE_SECRET_KEY`                | `[Launch May 2026] Stripe sk_test_*`                         |
| `STRIPE_WEBHOOK_SECRET`            | `[Launch May 2026] Stripe webhook signing secret`            |
| `SENTRY_DSN`                       | `[Launch May 2026] Sentry DSN`                               |
| `HCLOUD_TOKEN` (optional)          | `[Launch May 2026] Hetzner API token`                        |

### `/opt/mambakkam/infra/monitoring/.env.monitoring`

| Variable                         | Source                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------ |
| `GRAFANA_CLOUD_REMOTE_WRITE_URL` | `[Launch May 2026] Grafana Cloud Prometheus URL + user`                        |
| `GRAFANA_CLOUD_USERNAME`         | (same entry, Prometheus numeric user)                                          |
| `GRAFANA_CLOUD_LOKI_URL`         | `[Launch May 2026] Grafana Cloud Loki URL + user`                              |
| `GRAFANA_CLOUD_LOKI_USERNAME`    | (same entry, Loki numeric user — different number from Prometheus)             |
| `GRAFANA_CLOUD_API_KEY`          | `[Launch May 2026] Grafana Cloud token`                                        |
| `STUDYBUDDY_METRICS_TOKEN`       | matches the `METRICS_TOKEN` you `openssl rand`-ed in /opt/studybuddy/.env.demo |

### `/etc/ssl/cloudflare/origin-{cert,key}.pem`

| File                             | Source                                                      |
| -------------------------------- | ----------------------------------------------------------- |
| `origin-cert.pem` (mode 644)     | `[Launch May 2026] Cloudflare Origin Cert (cert PEM)`       |
| `origin-key.pem` (mode 600 root) | `[Launch May 2026] Cloudflare Origin Key (private key PEM)` |

### GitHub Actions repo secrets

These you set in **GitHub → repo → Settings → Secrets and variables → Actions** at some point on Day -2 or Day -1; not strictly required tonight but easy to do while you're at the laptop:

| Secret name             | Value                                                                                                                                     | Used by                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| `MAMBAKKAM_VPS_HOST`    | (filled in tomorrow once you know the CX22 public IP)                                                                                     | mambakkam-net deploy workflow         |
| `MAMBAKKAM_VPS_USER`    | `deploy`                                                                                                                                  | same                                  |
| `MAMBAKKAM_VPS_SSH_KEY` | content of `~/.ssh/mambakkam_cx22` (the private key)                                                                                      | same                                  |
| `DEMO_VPS_HOST`         | same as MAMBAKKAM_VPS_HOST (shared CX22)                                                                                                  | StudyBuddy deploy workflow            |
| `DEMO_VPS_USER`         | `deploy`                                                                                                                                  | same                                  |
| `DEMO_VPS_SSH_KEY`      | a separate SSH keypair (generate one for studybuddy in §2.2 if not done) — or reuse the mambakkam key if you prefer one shared deploy key | same                                  |
| `GHCR_TOKEN`            | personal access token with `write:packages` scope                                                                                         | StudyBuddy deploy (Docker image push) |

---

## What to do if something goes sideways tonight

| Symptom                                                                | Diagnosis                          | Recover                                                                                                                                                                  |
| ---------------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Cloudflare nameserver migration not propagating after 30 min           | Some registrars cache aggressively | Wait until 22:00 EDT and recheck; in worst case, do §1.2 first thing tomorrow morning before §6                                                                          |
| Zoho DKIM verification stays grey                                      | DNS propagation lag                | Wait 30 min, retry. If still grey at 18:30, skip and revisit Day 0 morning — the demo doesn't strictly need DKIM working at launch                                       |
| Hetzner asks for additional verification (passport scan, etc.)         | First-time account on a new email  | Have a backup plan: use an existing Hetzner account, or use a different VPS provider (DigitalOcean, Vultr) at the same price point — adjust `provision.sh` if you switch |
| `studybuddy.app` is taken                                              | Common-word risk                   | Have backup: `studybuddy.io`, `studybuddy.dev`, `studybuddy.cloud`, `usestudybuddy.com`. Update `.env.demo` and host-nginx vhost tomorrow                                |
| Auth0 free tier requires phone verification you can't complete tonight | Phone-network issues               | Skip Auth0 for tonight; wire it on Day 0 morning before StudyBuddy second-tenant cutover at 13:00 EDT                                                                    |
| Stripe asks for business info even in test mode                        | Sometimes does                     | You can use test-mode without activation — just make sure the `Test mode` toggle is ON. If forced to activate, defer to Day 0 morning                                    |

If you fall behind by more than 30 min, **don't push past 21:00 EDT**.
Sleep is your most important Day 0 asset. Deferred items can move to Day 0
morning before the 08:00 EDT VPS work begins (start at 06:30 instead).

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                                                                                                                          |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-09 | 1.0     | Initial — chronological 9-section operator checklist for Day -1 (Sat May 16) 17:00–20:30 EDT account + email setup. Cloudflare → Hetzner → Zoho → Gmail → Grafana Cloud → DNS pre-stage → studybuddy.app + Zoho mailboxes → Auth0 → Stripe + Sentry. Plus a §10 "values to paste tomorrow" cheat-sheet and a contingency table. |
