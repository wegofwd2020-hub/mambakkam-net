# Account & Email Setup — Day -1 (Sat May 16) 17:00–20:30 EDT

**Document version:** 1.4
**Date:** 2026-05-16
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
| 1       | 17:00–17:20 | Cloudflare                                   | Register mambakkam.net, DNS, Origin Cert with shared SAN |
| 2       | 17:15–17:25 | Hetzner Cloud                                | VPS provider; SSH key only — no CX22 yet          |
| 3       | 17:25–17:35 | Cloudflare Email Routing (mambakkam)         | Forward siva@mambakkam.net → personal Gmail       |
| 4       | 17:35–17:45 | Gmail send-as                                | Compose-from custom domain (alias mode)           |
| 5       | 18:15–18:40 | Grafana Cloud                                | Metrics + logs + alert rules                      |
| 6       | 18:40–18:50 | Pre-stage DNS for mambakkam                  | Day-0 cutover is just a value change              |
| 7       | 19:00–19:25 | usestudybuddy.com domain + DNS + Email Routing  | StudyBuddy-side setup begins                      |
| 8       | 19:25–19:50 | Auth0 dev tenant                             | Student + teacher login                           |
| 9       | 19:50–19:55 | Final go/no-go                               | Stripe + Sentry deferred to Phase 5; just the wrap-up |

**Total:** ~3 hours. Email is no longer a bottleneck (Cloudflare Email Routing is ~5 min/zone with no DKIM wait). §9 Stripe + Sentry deferred — neither blocks the demo (Stripe is Phase 5; Sentry replaced by Grafana Cloud Loki for error visibility).

**No credit card needed for:** Cloudflare Email Routing, Grafana Cloud, Auth0 free tier, Stripe (test mode), Sentry free tier, Plausible has paid only.
**Credit card needed for:** Cloudflare (one-time ~$10–11 for the `mambakkam.net` registration in §1.2), Hetzner Cloud (€7.50 deposit credit; CX22 billing starts Day 0 morning when you spin one up).

---

## Prerequisites — open BEFORE you start at 17:00 EDT

- [ ] Personal email account (for all sign-ups) — recommend a dedicated account or +alias e.g. `you+studybuddy-launch@gmail.com`
- [ ] Phone for 2FA (most providers require it)
- [ ] Password manager unlocked (1Password, Bitwarden, etc.) with a fresh "StudyBuddy Launch May 2026" vault/folder
- [ ] Credit card (Cloudflare domain registration + Hetzner)
- [ ] `mambakkam.net` is **not** yet registered — you'll register it fresh at Cloudflare Registrar in §1.2 (~$10–11/yr for `.net`). If someone has since taken it, fall back to Porkbun or pick an alternative TLD before continuing.
- [ ] This document open in another tab

**Naming convention for password-manager entries** — use this consistently:

```
[Launch May 2026] Cloudflare account
[Launch May 2026] Cloudflare Registrar — mambakkam.net (registration date + expiry + auth code)
[Launch May 2026] Cloudflare Origin Cert (mambakkam + studybuddy SAN)
[Launch May 2026] Hetzner Cloud account
[Launch May 2026] Hetzner SSH keypair
... (one entry per credential)

Cloudflare Email Routing (§3, §7) needs no separate credentials — it's
managed inside your Cloudflare account from §1.1.
```

The bracket prefix lets you find them all with one search later.

---

## §1 — Cloudflare (17:00–17:20, 20 min)

mambakkam.net is not yet registered. You'll register it at Cloudflare
Registrar (which auto-attaches the zone with Cloudflare nameservers, so
no nameserver-change step is needed), then pre-configure SSL.

### 1.1 — Account

- [ ] Sign up at https://dash.cloudflare.com/sign-up
- [ ] Verify email
- [ ] Enable 2FA (Account → Profile → Authentication)
- [ ] **Save** to password manager: `[Launch May 2026] Cloudflare account` (email + password)

### 1.2 — Register `mambakkam.net` at Cloudflare Registrar

- [ ] Add a payment method first: top-right profile → **Billing → Payment Methods → Add** (credit card required; Cloudflare Registrar does not accept other methods for domain purchases)
- [ ] Cloudflare dashboard → left sidebar → **Domain Registration → Register Domains**
- [ ] Search `mambakkam` → confirm `.net` is available at ~$10–11/yr (Cloudflare passes through wholesale; no markup)
- [ ] Click **Purchase** → 1-year term (extend later if you want)
- [ ] Contact info — leave Cloudflare's WHOIS privacy **ON** (free; real contact details go only to the registry, not public WHOIS)
- [ ] Confirm + pay; registration completes in ~1–2 min
- [ ] The zone auto-attaches to your Cloudflare account with Cloudflare nameservers already assigned — no separate "Add a Site" or nameserver-change step needed
- [ ] **Save** to password manager: `[Launch May 2026] Cloudflare Registrar — mambakkam.net` (registration date, expiry date, and the transfer auth code if Cloudflare shows one)

**If `.net` is not registrable at Cloudflare** (rare, but the supported-TLD list does change): register at **Porkbun** instead (~$11/yr), then come back here, do the old §1.2 flow — "+ Add a Site" → Free plan → change nameservers at Porkbun to the two `*.ns.cloudflare.com` values Cloudflare assigns. Transfer to Cloudflare Registrar after the 60-day ICANN new-registration lock expires (~mid-July 2026).

**Verify (can run from terminal anytime once registration completes):**

```bash
dig NS mambakkam.net +short
# Expect: two *.ns.cloudflare.com nameservers
whois mambakkam.net | grep -iE "registrar:|expir"
# Expect: Registrar: Cloudflare, Inc.
```

### 1.3 — Generate Cloudflare Origin Certificate (SAN list for both domains)

- [ ] In Cloudflare dashboard → mambakkam.net zone → **SSL/TLS → Origin Server → Create Certificate**
- [ ] Key type: **RSA** (default; ECDSA also fine)
- [ ] Hostnames — type each on a new line:
  ```
  mambakkam.net
  *.mambakkam.net
  demo.usestudybuddy.com
  ```
  _Important:_ `demo.usestudybuddy.com` must be in the SAN list now even though that domain isn't on Cloudflare yet — Cloudflare allows it because Origin Certs are issued by Cloudflare's PKI and don't require domain ownership at generation time. StudyBuddy uses this same cert when it joins on Day 0 afternoon.
- [ ] Validity: **15 years** (default)
- [ ] Click "Create" — Cloudflare displays the certificate + private key ONCE
- [ ] **Copy both** to the password manager:
  - `[Launch May 2026] Cloudflare Origin Cert (cert PEM)`
  - `[Launch May 2026] Cloudflare Origin Key (private key PEM)`
  - SAN list = `mambakkam.net + *.mambakkam.net + demo.usestudybuddy.com`
- [ ] Tomorrow morning you'll paste these into `/etc/ssl/cloudflare/origin-{cert,key}.pem` on the VPS

### 1.4 — SSL/TLS settings for `mambakkam.net`

- [ ] Cloudflare dashboard → mambakkam.net → **SSL/TLS → Overview**
- [ ] Set encryption mode: **Full (strict)**
- [ ] **SSL/TLS → Edge Certificates** → **Always Use HTTPS** = **ON**
- [ ] **Speed → Optimization** → leave defaults (Auto Minify is fine; Rocket Loader off)

> usestudybuddy.com DNS work happens in §7 below, after the domain is registered.

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

## §3 — Cloudflare Email Routing for mambakkam.net (17:25–17:35, 10 min)

Demo-grade inbound mail: forward `siva@mambakkam.net` → your personal
Gmail. No mailbox, no IMAP, no SMTP, no monthly bill. When real inbound
traffic justifies a separate inbox, upgrade to a paid provider (Zoho
Mail Lite ~$12/yr, Migadu ~$19/yr, Fastmail ~$36/yr) and revisit §3 + §4
+ the DEPLOYMENT_PLAN cost table.

Studybuddy.app uses the same pattern in §7.

### 3.1 — Enable Email Routing

- [ ] Cloudflare dashboard → mambakkam.net zone → left sidebar → **Email → Email Routing**
- [ ] Click **Get started** (or **Enable Email Routing**)
- [ ] Cloudflare prompts to auto-add the required DNS records (3× MX + 1× SPF TXT). Click **Add records and enable** — Cloudflare writes them directly into the zone, no manual entry needed.

Records Cloudflare adds for you (FYI; do not edit):

- 3× MX at apex pointing to `route1.mx.cloudflare.net`, `route2.mx.cloudflare.net`, `route3.mx.cloudflare.net` (priorities CF-assigned)
- 1× TXT at apex: `v=spf1 include:_spf.mx.cloudflare.net ~all`

### 3.2 — Add destination address (your personal Gmail)

- [ ] Email Routing → **Destination addresses** tab → **+ Add destination address**
- [ ] Enter your personal Gmail (e.g. `wegofwd2020@gmail.com`)
- [ ] Cloudflare sends a verification email to that address — open Gmail, click the **Verify** link
- [ ] Back in Cloudflare, destination shows green ✓ **Verified**

### 3.3 — Create routing rule for `siva@mambakkam.net`

- [ ] Email Routing → **Routes** tab → **+ Create address**
- [ ] Custom address: `siva` (Cloudflare auto-appends `@mambakkam.net`)
- [ ] Action: **Send to an email** → select your verified Gmail
- [ ] Save
- [ ] (Optional but recommended) Also add a **Catch-all** rule: top of the Routes tab → enable Catch-all → action: Send to your Gmail. Catches typos and any `info@`, `hello@`, etc. that future visitors might guess.

### 3.4 — DMARC for the domain (single TXT)

DMARC is not added by Cloudflare automatically. Add it manually so you can monitor send-side behaviour and so receivers know the domain's posture.

- [ ] Cloudflare → DNS → Records → **+ Add record**
- [ ] Type: **TXT**, Name: **\_dmarc**, Content: `v=DMARC1; p=none; rua=mailto:wegofwd2020@gmail.com`
- [ ] _Why `p=none`:_ when you send-as from Gmail in §4, DKIM signs as `gmail.com` and SPF passes for `gmail.com`, so neither aligns with `mambakkam.net`. `p=none` puts DMARC in monitor-only mode — messages still deliver. Tighten to `p=quarantine` later if/when you move to a real mail provider that can sign DKIM for the domain.

### 3.5 — End-to-end inbound test

- [ ] From a different email account (not your personal Gmail — outbound from Gmail to yourself can short-circuit the test), send a message to `siva@mambakkam.net`
- [ ] Within ~30 sec, the message lands in your personal Gmail inbox
- [ ] Open it and check headers: `Received:` chain should show `*.mx.cloudflare.net` as the first hop

**Verify (terminal):**

```bash
dig MX mambakkam.net +short                # route1.mx.cloudflare.net / route2.../ route3...
dig TXT mambakkam.net +short | grep spf1   # v=spf1 include:_spf.mx.cloudflare.net ~all
dig TXT _dmarc.mambakkam.net +short        # v=DMARC1; p=none; rua=mailto:...
```

> No password-manager entry needed for §3 — Cloudflare Email Routing has no separate credentials. Account-level Cloudflare creds from §1.1 are all you need.

---

## §4 — Gmail send-as for `siva@mambakkam.net` (17:35–17:45, 10 min)

Lets you compose mail FROM `siva@mambakkam.net` while reading via Gmail.
Because Cloudflare Email Routing is inbound-only (no outbound SMTP),
you use Gmail's own outbound — i.e. "Treat as alias" mode.

**Caveats of alias mode** (acceptable for a demo, document for later):

- Recipients in some clients see `via gmail.com` next to your From address
- DKIM signs as `gmail.com`, not `mambakkam.net` (no DMARC alignment — that's why §3.4 sets `p=none`)
- Outbound from your personal Gmail account is rate-limited and tied to your Gmail reputation
- When you move to a paid mail provider, re-do this with provider SMTP + App Password and tighten DMARC to `p=quarantine`

### 4.1 — Add as send-as identity

> **Prerequisite:** §3.3 routing rule is live, §3.5 inbound test passed. Gmail's verification email below goes TO `siva@mambakkam.net`, which means Cloudflare Email Routing has to be forwarding correctly. If §3.5 worked, this will too.

- [ ] In Gmail → **Settings (gear) → See all settings → Accounts and Import → Send mail as → Add another email address**
- [ ] Name: `Siva Mambakkam`, Email: `siva@mambakkam.net`, **Treat as alias: YES** (leave checked — the default), → Next Step
- [ ] Gmail offers an SMTP form. You can **skip it** if Gmail shows a "Send through Gmail" option (it usually does for aliases you've forwarded to yourself). If Gmail insists on SMTP details, see Fallback below.
- [ ] Gmail sends a verification email to `siva@mambakkam.net` — it forwards via Cloudflare to your personal Gmail inbox — open it, click the **Confirm** link (or copy the verification code into the popup)
- [ ] Back in Gmail Settings → **set as default From** if you want all outbound to default to this identity (your call; many keep personal Gmail as default and pick the alias per-compose)

**Fallback if Gmail won't let you use "Send through Gmail":** This usually only happens when "Treat as alias" is unchecked. Make sure it's checked. If Gmail still requires SMTP, you'll need to either (a) sign up for a paid mail provider in §3 and redo §4 with their SMTP, or (b) use a free SMTP relay like Brevo (300/day free) — out of scope for the demo path.

### 4.2 — Test round-trip

- [ ] Compose new mail in Gmail — From dropdown shows `Siva Mambakkam <siva@mambakkam.net>`
- [ ] Send to a non-Gmail address you control (Gmail-to-Gmail can hide alias issues)
- [ ] Confirm it arrived from `siva@mambakkam.net`
- [ ] Reply from that address — confirm reply lands in your personal Gmail inbox (forwarded by Cloudflare Email Routing)

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

## §7 — `usestudybuddy.com` domain + DNS + Email Routing (19:00–19:25, 25 min)

### 7.1 — Register the domain

- [ ] Cloudflare dashboard → **Domain Registration → Register Domain** → search `usestudybuddy.com`
- [ ] If available, add to cart and complete purchase (~$12-15/yr for `.app`; auto-renew default ON; ICANN privacy on)
- [ ] **Save** to password manager: `[Launch May 2026] usestudybuddy.com domain` — note the registration date + auto-renew status
- [ ] Cloudflare automatically configures the zone — no nameserver migration needed since registration was at Cloudflare itself

> If `usestudybuddy.com` is unavailable, decide on alternative: `studybuddy.io`, `studybuddy.dev`, `studybuddy.cloud`. Update `.env.demo`'s `FRONTEND_URL` and the host-nginx vhost `server_name` accordingly tomorrow morning.

### 7.2 — Cloudflare DNS for `demo.usestudybuddy.com`

- [ ] Cloudflare → usestudybuddy.com → DNS → **+ Add record**
- [ ] Type: **A**, Name: **demo**, IPv4: **192.0.2.1** (placeholder, same idea as §6), TTL: **5 min**, Proxy: **DNS only** (off — turning proxy on without a working origin would 502; flip to orange tomorrow morning at 12:45 EDT during StudyBuddy cutover)

### 7.3 — SSL/TLS for usestudybuddy.com

- [ ] Cloudflare → usestudybuddy.com → **SSL/TLS → Overview** → Mode: **Full (strict)**
- [ ] **SSL/TLS → Edge Certificates** → **Always Use HTTPS** = **ON**
- [ ] (Origin Cert was already generated in §1.3 with `demo.usestudybuddy.com` in the SAN list — no work here)

### 7.4 — Enable Cloudflare Email Routing for usestudybuddy.com

Same pattern as §3 for mambakkam.net — inbound forwarding only, demo-grade.

- [ ] Cloudflare dashboard → usestudybuddy.com zone → **Email → Email Routing → Get started**
- [ ] Click **Add records and enable** — Cloudflare writes 3× MX + 1× SPF TXT into the zone automatically
- [ ] Destination addresses tab — your personal Gmail is already verified from §3.2, so it shows in the dropdown; no need to re-verify

### 7.5 — Routing rules + DMARC for usestudybuddy.com

- [ ] Email Routing → Routes → **+ Create address** → `support` → action: send to your verified Gmail
- [ ] Repeat: **+ Create address** → `sales` → send to your Gmail
- [ ] (Recommended) Enable **Catch-all** → send to your Gmail (catches typos, plus any guessed addresses like `hello@`, `info@`)
- [ ] DNS → Records → **+ Add record**: Type **TXT**, Name **\_dmarc**, Content `v=DMARC1; p=none; rua=mailto:wegofwd2020@gmail.com`
- [ ] Same `p=none` rationale as §3.4 — Gmail send-as alias mode in §7.6 won't DMARC-align for the domain

### 7.6 — Add support@usestudybuddy.com as Gmail send-as

- [ ] Gmail → Settings → Accounts → Send mail as → **Add another email address**
- [ ] Name: `StudyBuddy Support`, Email: `support@usestudybuddy.com`, **Treat as alias: YES**
- [ ] Send through Gmail (same pattern as §4.1 — no SMTP server needed in alias mode)
- [ ] Gmail sends a verification email to `support@usestudybuddy.com` — it forwards via Cloudflare to your personal Gmail; click the Confirm link
- [ ] (Optional) Repeat for `sales@usestudybuddy.com` if you want it as a separate identity in the Gmail From dropdown

> No password-manager entry needed for §7.4–7.6 — Cloudflare Email Routing has no separate credentials. When you upgrade to a paid mail provider (and re-enable mailbox-based receive + provider SMTP), come back here and add mailbox + App Password entries to the password manager.

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
  - **Allowed Callback URLs:** `https://demo.usestudybuddy.com/auth/callback, http://localhost:3000/auth/callback`
  - **Allowed Logout URLs:** `https://demo.usestudybuddy.com, http://localhost:3000`
  - **Allowed Web Origins:** `https://demo.usestudybuddy.com, http://localhost:3000`
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

## §9 — Final go/no-go (19:50–19:55, 5 min)

Stripe + Sentry were originally planned for tonight. Both are deferred:

- **Stripe** — code is wired in (`config.py` has `STRIPE_SECRET_KEY: str | None = None`; all usage sites do `getattr(..., None)` and only raise if a billing endpoint is hit). The demo flow (admin-provisioned Teacher + Student accounts browsing pre-built content) never touches a billing endpoint. Sign-up + test keys + webhook = deferred to Phase 5 (when a paid tier ships). Tonight: do nothing.
- **Sentry** — error tracking. Skipped in favour of Grafana Cloud Loki (§5) for log-based error visibility. Less ergonomic (raw log lines vs grouped issues + stack traces) but saves a third-party dependency.

### §9.1–§9.5 — Deferred (Phase 5)

When you add a paid tier post-launch, come back here. Original steps (sign up at https://dashboard.stripe.com/register, capture `sk_test_*` + `pk_test_*` + webhook `whsec_*`, point webhook at `https://demo.usestudybuddy.com/api/v1/subscriptions/webhook` with the 6 subscription events) lived in v1.3 of this doc — pull from git history if you need them verbatim.

For Sentry, original steps (sign up at https://sentry.io/signup/, create Python/FastAPI project, capture DSN) also lived in v1.3.

### §9.6 — Final go/no-go (now §9, since 9.1–9.5 are skipped)

Run through this checklist before closing the laptop:

- [ ] All §1-§8 items have entries in the password manager (~20 entries total)
- [ ] You have one consolidated note somewhere with the values you'll paste into `.env.demo` tomorrow morning (see §10 below)
- [ ] DNS for both `mambakkam.net` and `demo.usestudybuddy.com` is pre-staged at Cloudflare with TTL=5min, proxy off
- [ ] Cloudflare Origin Cert + key are in the password manager (SAN: `mambakkam.net`, `*.mambakkam.net`, `demo.usestudybuddy.com`)
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
| _SMTP_HOST / SMTP_USER / SMTP_PASSWORD_ | **Omit for demo.** No app-originated email ships in the demo; outbound from `siva@mambakkam.net` goes via Gmail send-as (alias mode), not from the server. When you later add a contact form + paid mail provider, paste back the four SMTP_* lines with provider host/credentials. |

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
| _SMTP_USER / SMTP_PASSWORD_        | **Omit for demo.** Same rationale as `/opt/mambakkam/.env.demo` above — no app-originated email in demo; add when you wire a contact form + paid mail provider. |
| _STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET_ | **Omit for demo.** Stripe is Phase-5 only; `config.py` defaults `STRIPE_SECRET_KEY: str \| None = None` and all usage sites do `getattr(..., None)` — app boots fine without these. Add when a paid tier ships. |
| _SENTRY_DSN_                       | **Omit for demo.** Error visibility comes from Grafana Cloud Loki (§5) instead. Add Sentry later if grouped issues + stack traces become worth the extra dependency. |
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
| Cloudflare Email Routing "Get started" button greyed out               | Zone not fully active yet          | Wait 1–2 min after registration completes; refresh the page. If still grey, check the zone's overview tab — status should be "Active"                                    |
| Gmail send-as won't let you skip the SMTP form                         | "Treat as alias" wasn't checked    | Back out, re-add the address with **Treat as alias = YES** checked. If still required, use the Fallback note in §4.1                                                     |
| Hetzner asks for additional verification (passport scan, etc.)         | First-time account on a new email  | Have a backup plan: use an existing Hetzner account, or use a different VPS provider (DigitalOcean, Vultr) at the same price point — adjust `provision.sh` if you switch |
| `usestudybuddy.com` is taken                                              | Common-word risk                   | Have backup: `studybuddy.io`, `studybuddy.dev`, `studybuddy.cloud`, `usestudybuddy.com`. Update `.env.demo` and host-nginx vhost tomorrow                                |
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
| 2026-05-16 | 1.1     | §1.2 rewritten: register `mambakkam.net` fresh at Cloudflare Registrar (~$10–11/yr) instead of presuming it's already registered elsewhere. No nameserver-change step needed. §3.2 prerequisite note updated to match. Credit-card line, prereq checklist, and password-manager naming list updated. |
| 2026-05-16 | 1.2     | **Email-provider switch — Zoho free plan no longer reliably available for new signups.** §3 rewritten to Cloudflare Email Routing (free, inbound-only forwarding to personal Gmail). §4 switched to Gmail send-as in alias mode (no SMTP needed). §7.4–7.6 same pattern for studybuddy.app. §10 SMTP env vars marked "omit for demo" since no app-originated email ships. DMARC set to `p=none` for both domains (alias mode doesn't align). Plan: revisit when real inbound traffic justifies paid mail (Zoho Mail Lite ~$12/yr, Migadu ~$19/yr). |
| 2026-05-16 | 1.3     | **Domain rename — studybuddy.app → usestudybuddy.com.** studybuddy.app was unavailable at registration time; usestudybuddy.com chosen as the "use<product>.com" fallback per the contingency table. Subdomain convention preserved: `demo.studybuddy.app` → `demo.usestudybuddy.com`. Body of §1.3 (Origin Cert SAN), §7 (DNS, Email Routing) updated. Origin Cert regenerated at Cloudflare with new SAN list; old cert revoked. Sibling docs DEPLOYMENT_PLAN.md, DEMO_LAUNCH_PLAN.md, MONITORING.md, LOGGING.md, RUNBOOK.md, BACKUPS.md updated in the same pass, plus infra (nginx vhost, prometheus.yml, alert rules YAML, provision.sh, provision-local.sh). StudyBuddy_OnDemand sibling repo requires the same sweep on its side. |
| 2026-05-16 | 1.4     | **Stripe + Sentry deferred from tonight.** Stripe — verified in StudyBuddy_OnDemand `config.py`: `STRIPE_SECRET_KEY: str \| None = None` with all usage sites doing `getattr(..., None)`, raising only when a billing endpoint is hit. Demo flow (admin-provisioned Teacher + Student accounts browsing pre-built content) never touches billing, so app boots fine without keys. §9.1–§9.3 deferred to Phase 5. Sentry — replaced by Grafana Cloud Loki (§5) for error visibility; §9.4–§9.5 dropped. §9 collapses to the original §9.6 go/no-go (renamed to just "§9 — Final go/no-go"). §10 env-var table marks `STRIPE_*` and `SENTRY_DSN` as "omit for demo". TL;DR row §9 retitled. Total time: 3.5h → ~3h. |
