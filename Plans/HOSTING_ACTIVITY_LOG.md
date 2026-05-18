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
