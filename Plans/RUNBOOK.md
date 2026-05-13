# Alert Runbook — mambakkam.net + StudyBuddy

**Document version:** 1.0
**Date:** 2026-05-09
**Status:** Source-of-truth for alert response. Rule definitions live in
`infra/monitoring/alerts/`; this doc says what to do when one fires.
**Companion docs:**

- [`MONITORING.md`](MONITORING.md) — metrics architecture
- [`LOGGING.md`](LOGGING.md) — log shipping
- [`BACKUPS.md`](BACKUPS.md) — backup architecture
- Rule files: [`infra/monitoring/alerts/metric-rules.yaml`](../infra/monitoring/alerts/metric-rules.yaml), [`log-rules.yaml`](../infra/monitoring/alerts/log-rules.yaml)

---

## TL;DR

| Severity | Where it lands                   | Response time                   | When you'll see it                          |
| -------- | -------------------------------- | ------------------------------- | ------------------------------------------- |
| `[PAGE]` | Gmail inbox, label `alerts/page` | Immediate (during waking hours) | Customer-visible breakage or DR risk        |
| `[WARN]` | Gmail inbox, label `alerts/warn` | Next time at the keyboard       | Symptoms worth investigating but not urgent |

Single operator, best-effort coverage. No formal on-call; nothing wakes you at 3am — emails are filtered out of the lock-screen-notifying mail clients between 23:00 and 07:00. Revisit when the first paying customer arrives.

---

## Notification routing setup (one-time, in Grafana Cloud UI)

Click-ops in the Grafana Cloud Alerting UI — easier than the API for a 2-channel-1-destination setup.

### 1. Contact point

`Alerting → Contact points → Add contact point`

| Field          | Value                                                                                  |
| -------------- | -------------------------------------------------------------------------------------- |
| Name           | `gmail-siva`                                                                           |
| Type           | Email                                                                                  |
| Addresses      | `siva@mambakkam.net`                                                                   |
| Single email   | ON (one email per alert; don't bundle dissimilar alerts)                               |
| Subject (page) | `[PAGE] {{.GroupLabels.alertname}} — {{.CommonLabels.site}}`                           |
| Subject (warn) | `[WARN] {{.GroupLabels.alertname}} — {{.CommonLabels.site}}`                           |
| Message body   | Default Grafana template — includes the `description` and `runbook_url` from each rule |

### 2. Notification policy

`Alerting → Notification policies → Edit default policy`

Default route: `gmail-siva` (catches anything not matching specific routes).

Specific routes (top-down, first-match):

| Match             | Route to     | Subject template                                             |
| ----------------- | ------------ | ------------------------------------------------------------ |
| `severity = page` | `gmail-siva` | `[PAGE] {{.GroupLabels.alertname}} — {{.CommonLabels.site}}` |
| `severity = warn` | `gmail-siva` | `[WARN] {{.GroupLabels.alertname}} — {{.CommonLabels.site}}` |

Both routes can use the same contact point because the subject prefix is what differentiates the inbox handling. Gmail filters do the rest:

```
# Gmail filter 1 — page label
Subject: ([PAGE])
→ Apply label "alerts/page"
→ Mark as important
→ Skip the inbox  (UNCHECK if you want them in the main inbox too)

# Gmail filter 2 — warn label
Subject: ([WARN])
→ Apply label "alerts/warn"
→ Skip the inbox
→ Auto-reply: never
```

### 3. Group + repeat intervals

Per the click-ops policy:

| Setting            | Value                                     | Why                                                                                                  |
| ------------------ | ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Group wait         | `30s`                                     | Wait briefly for related alerts to bunch (e.g. 5xx surge often pulls in StudyBuddyHighErrorRate too) |
| Group interval     | `5m`                                      | Don't re-page on the same group within 5 min                                                         |
| Repeat interval    | `4h`                                      | Re-page every 4 h while the alert remains firing — prevents "I forgot about that" syndrome           |
| Mute timing (page) | none                                      | Pages are always delivered                                                                           |
| Mute timing (warn) | weekday 07:00–22:00 (operator local time) | Warns piled up over night/weekend land in one batch when you're back                                 |

### 4. Test the path before launch

```bash
# Pick an existing alert, temporarily edit threshold to fire immediately,
# wait 60-90s, confirm Gmail receives the message, restore threshold.
# OR use the "Test" button on the contact point in the Grafana Cloud UI.
```

The Day -2 (Fri May 15) test plan in `DEMO_LAUNCH_PLAN.md` includes one end-to-end test fire — don't skip.

---

## Applying the rules

```bash
# Source-of-truth lives in infra/monitoring/alerts/. After any edit:
cd /opt/mambakkam/infra/monitoring/alerts
bash apply.sh                    # both metric + log rules
bash apply.sh metric             # just metric rules
bash apply.sh log                # just log rules
```

Rules take effect within ~60s of upload (ruler poll interval). Notification routing changes are immediate.

The Cloud Access Policy token must have all three scopes from the start: `metrics:write` (Prometheus push), `logs:write` (Loki push), `alerts:write` (Mimir + Loki ruler API — what `apply.sh` calls). This is set up up-front in [`ACCOUNT_SETUP.md`](ACCOUNT_SETUP.md) §5.4. If the upload returns 401/403, your existing policy is missing `alerts:write` — generate a new policy in Grafana Cloud → Access policies with all three scopes, save the token, replace `GRAFANA_CLOUD_API_KEY` in `.env.monitoring`, re-run `apply.sh`.

---

## Alert-by-alert response

Order: `[PAGE]` first (the ones that matter), then `[WARN]`.

---

### MambakkamDown

**Severity:** `[PAGE]`
**Expr:** `probe_success{instance="https://mambakkam.net"} == 0` for 2 m

**What it means**

blackbox-exporter on the CX22 has been unable to reach `https://mambakkam.net` for >2 min. The probe goes Cloudflare → host nginx → astrowind container; a failure can be at any layer.

**Likely causes**

1. **astrowind container died or unhealthy.** Check `docker compose ps` on the box.
2. **Host nginx down or refusing 443.** Check `systemctl status nginx`.
3. **Cloudflare→origin path broken** — Origin Cert expired, vhost misconfigured, UFW dropped 443.
4. **Promtail stopped** — wouldn't actually take the site down but if the alert fired at the same time as a deploy, it's worth checking.

**First response (≤10 min)**

```bash
# 1. Confirm site is actually down (rule out a Grafana Cloud false positive):
curl -I https://mambakkam.net                       # expect 200
curl -I https://mambakkam.net --resolve mambakkam.net:443:<vps-ip>   # bypass CF

# 2. Check container + host nginx:
ssh deploy@<vps-ip>
docker ps | grep mambakkam
sudo systemctl status nginx
sudo nginx -t

# 3. Check container logs for crash/restart loop:
docker logs --tail 100 mambakkam-astrowind

# 4. If container died: restart it.
cd /opt/mambakkam
sudo docker compose -f docker-compose.demo.yml up -d
```

**Escalation**

- If host nginx config-test fails: revert `infra/nginx/mambakkam.net.conf` from git (`git -C /opt/mambakkam log -p infra/nginx/`); reload nginx.
- If Origin Cert expired: regenerate at Cloudflare → SSL/TLS → Origin Server (15 min). SAN list: mambakkam.net + \*.mambakkam.net + demo.studybuddy.app.
- If the VPS is itself unreachable: file Hetzner ticket + post a Cloudflare maintenance worker as cover (5 min via CF dashboard).

---

### StudyBuddyDown

**Severity:** `[PAGE]`
**Expr:** `probe_success{instance="https://demo.studybuddy.app/healthz"} == 0` for 2 m

**What it means**

`/healthz` returns 200 only when the API can reach DB + Redis. A failure means one of: API container down, DB container down, Redis down, or the host nginx isn't routing correctly.

**Likely causes**

1. **API container OOM-killed.** Check `dmesg | grep -i kill` and `docker ps`.
2. **Postgres connection pool exhausted.** Look for `connection refused` in `docker logs studybuddy-api-1`.
3. **DB container down.** `docker ps | grep db`.
4. **Bad recent deploy.** Check `git log --oneline -5` in `/opt/studybuddy`.

**First response (≤10 min)**

```bash
ssh deploy@<vps-ip>
cd /opt/studybuddy

# 1. Confirm:
curl -fsSL https://demo.studybuddy.app/healthz       # expect {"db":"ok","redis":"ok"}

# 2. Service health:
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo ps

# 3. Targeted log check — usually the failing service is obvious here:
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo logs --tail 200 api db redis | grep -iE "error|fatal|kill"

# 4. If a service is unhealthy: restart only that one:
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo restart api
```

**Escalation**

- If recent deploy is the cause: `git -C /opt/studybuddy reset --hard <prev-sha> && bash scripts/demo/deploy.sh` (~3 min). Sequence B in `docs/DEMO_LAUNCH_PLAN.md` §2.5.
- If DB has corrupted: BACKUPS.md Scenario 1 — full restore.
- If sustained OOM under StudyBuddy load: consider upgrading to CX32 (€10/mo). At demo traffic this should not happen.

---

### StudyBuddyHighErrorRate

**Severity:** `[PAGE]`
**Expr:** 5xx rate > 5% of total traffic for 5 m

**What it means**

The application is responding, but 1 in 20 requests is a 500-class error. Usually a bug shipped in a recent deploy or a downstream dependency (Auth0 / Stripe) failing.

**Likely causes**

1. **Recent deploy regressed something.** Check `git log -5` and `/admin/audit`.
2. **Auth0 or Stripe outage.** Check the providers' status pages.
3. **Database query timing out** — see DB locks or connection pool stats in `/admin/`.
4. **Celery queue backed up** — workers can't keep up; API blocks on syncly-awaited tasks.

**First response (≤10 min)**

```bash
# 1. Identify which routes are 5xx-ing:
# In Grafana Cloud → Explore → Loki:
{vhost="demo.studybuddy.app", kind="access"} |~ `" 5\d\d ` | json | line_format "{{.uri}}"

# 2. Confirm via the metric:
sum by (path) (rate(sb_requests_total{status=~"5.."}[5m]))

# 3. Match against recent deploy:
git -C /opt/studybuddy log --oneline -10

# 4. If deploy is the cause, roll back:
git -C /opt/studybuddy reset --hard <prev-sha>
sudo bash /opt/studybuddy/scripts/demo/deploy.sh
```

**Escalation**

- File post-mortem after recovery: `/admin/audit` exports + Loki time-window dump.
- If rate stays >5% post-rollback, page is invalid (bug not in this repo) — investigate dependency outages.

---

### CX22DiskFull

**Severity:** `[PAGE]`
**Expr:** `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.10` for 5 m

**What it means**

CX22 root partition has <10% free. Postgres will start refusing writes around 5%; restic backups will start failing. Act fast.

**Likely causes**

1. **Restic repo growing unexpectedly** (forget+prune drift).
2. **Container logs filled the disk** (json-file driver cap should prevent this, but check).
3. **Content store has a runaway upload.**
4. **Postgres WAL accumulated** (less likely at our query volume).

**First response (≤15 min)**

```bash
# 1. Identify the heavy hitter:
sudo du -h --max-depth=2 /opt /var | sort -rh | head -20

# 2. If it's Docker logs (despite caps):
sudo docker system df               # what does Docker think?
sudo docker system prune -f         # safe — removes only unused

# 3. If it's restic repo on a forget-but-no-prune drift:
sudo bash /opt/mambakkam/scripts/launch/backup-check.sh    # runs prune
sudo bash /opt/studybuddy/scripts/demo/backup-check.sh

# 4. If it's a runaway content upload:
sudo find /data/content -type f -size +50M
```

**Escalation**

- If can't free enough fast: shrink the restic forget policy temporarily (`--keep-daily 3 --keep-weekly 0` — recovers ~50% of repo size).
- If still tight: upgrade CX22 → CX32 (40 → 80 GB SSD; €5/mo extra) via Hetzner console. Live resize.

---

### Demo5xxRateHigh

**Severity:** `[PAGE]`
**Expr:** demo.studybuddy.app access log 5xx rate > 0.5/s for 5 m

**What it means**

Same symptom as StudyBuddyHighErrorRate but observed from the access log instead of the application metrics. They usually fire together.

**Likely causes**

Same as StudyBuddyHighErrorRate. The two alerts together give you confidence the issue is real (vs. a metrics-pipeline glitch).

**First response**

If StudyBuddyHighErrorRate is also firing → handle that one; this'll auto-resolve.

If only Demo5xxRateHigh is firing (no metrics version) → `sb_requests_total` may be stale; check Prometheus scrape health: `up{job="studybuddy-api"} == 1`. If 0, the application metrics pipeline is broken but the application itself may be fine — or vice versa.

**Escalation**

Same as StudyBuddyHighErrorRate.

---

### BackupSilent

**Severity:** `[PAGE]`
**Expr:** `count_over_time({job="backups"}[24h]) < 5` for 1 h

**What it means**

Either the cron didn't run, or both backups silently failed without writing log lines, or Promtail stopped tailing. Any of these = no recovery point for whatever happens in the next 24 h.

**First response (≤15 min)**

```bash
ssh deploy@<vps-ip>

# 1. Cron status:
sudo systemctl status cron
ls -la /etc/cron.d/{mambakkam-backup,studybuddy-demo-backup}
sudo cat /var/log/syslog | grep -i cron | tail -20

# 2. Last backup log lines on disk:
sudo tail -50 /var/log/mambakkam-backup.log
sudo tail -50 /var/log/studybuddy-backup.log

# 3. Promtail still running?
sudo docker compose -f /opt/mambakkam/infra/monitoring/docker-compose.monitoring.yml ps promtail
sudo docker logs --tail 100 monitoring-promtail | grep -iE "error|fail"

# 4. Force-run a backup right now to confirm the script works:
sudo bash /opt/mambakkam/scripts/launch/backup.sh
sudo bash /opt/studybuddy/scripts/demo/backup.sh
```

If the manual run succeeds, cron itself is the issue — `systemctl restart cron` and watch the next 02:00 / 02:30 UTC window.

**Escalation**

- If the cron service is broken at the systemd level: rebuild the cron entry from `provision.sh` (re-running provision.sh is idempotent; it'll restore /etc/cron.d/\* without touching anything else).
- If backups are silently failing (script reports success but no snapshot lands): run `restic snapshots` on each repo manually; if the snapshot list matches expectations, the alert query has a bug — open a follow-up to fix the LogQL.

---

### ResticCheckFailed

**Severity:** `[PAGE]`
**Expr:** `count_over_time({job="backups"} |~ "CHECK FAILED" [1d]) > 0`

**What it means**

`restic check --read-data-subset 5%` detected possible bit-rot or repo corruption. Some recent snapshots may not be restorable.

**First response (≤30 min)**

```bash
ssh deploy@<vps-ip>

# 1. Run a full check (slow; 30+ min):
sudo RESTIC_PASSWORD_FILE=/etc/restic/<site>.password \
     restic -r /opt/<site>/backups/restic \
     check --read-data-subset 100% 2>&1 | tee /tmp/restic-full-check.log

# 2. Note exactly which packs / blobs were flagged:
grep -i "error\|broken\|invalid\|missing" /tmp/restic-full-check.log

# 3. If specific snapshots are corrupted, list them:
sudo RESTIC_PASSWORD_FILE=/etc/restic/<site>.password \
     restic -r /opt/<site>/backups/restic snapshots

# 4. Keep older snapshots intact; delete only the corrupted recent ones:
sudo RESTIC_PASSWORD_FILE=/etc/restic/<site>.password \
     restic -r /opt/<site>/backups/restic forget <bad-snapshot-id> --prune
```

**Escalation**

- If the repo's metadata pack is corrupted (not just data): the repo is likely unrecoverable. Test-restore the latest still-good snapshot to /tmp; if successful, init a new repo and start fresh (lose history past that snapshot).
- File a calendar reminder for monthly disk SMART check (`smartctl --health`) since recurring corruption usually means the underlying disk is dying.

---

### CX22LowMemory

**Severity:** `[WARN]`
**Expr:** `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10` for 5 m

**What it means**

CX22 has <10% memory available. Usually a bursty workload that recovers in minutes; occasionally a leaking process that doesn't.

**First response (next-time-at-keyboard)**

```bash
# 1. What's eating memory now?
ssh deploy@<vps-ip>
free -h
ps aux --sort=-rss | head -15

# 2. Per-container:
sudo docker stats --no-stream

# 3. OOM-killed something already?
journalctl -k --since "30 min ago" | grep -i oom

# 4. If a specific container is leaking, restart it:
sudo docker compose -f /opt/studybuddy/docker-compose.yml -f /opt/studybuddy/docker-compose.demo.yml \
     --env-file /opt/studybuddy/.env.demo restart <service>
```

**Escalation**

- Sustained >24 h with a stable workload: profile the leak (which container is growing). Add a `mem_limit` cap to the offending compose service if appropriate.
- If demo traffic genuinely needs more RAM: CX32 (€10/mo) is a one-click upgrade in Hetzner console.

---

### StudyBuddyErrorBurst

**Severity:** `[WARN]`
**Expr:** `sum(rate({project="studybuddy", level="error"}[5m])) > 1` for 5 m

**What it means**

Backend code is logging structlog errors at >1/sec. Could be auth errors (rare-but-recoverable), DB hiccups, Celery task failures, or a bug.

**First response (next-time-at-keyboard)**

```logql
# In Grafana Cloud Explore → Loki, pivot by logger:
{project="studybuddy", level="error"} | json | line_format "{{.logger}} | {{.event}}"
```

Common patterns:

- `logger=auth event="invalid_token"` — usually noise from automated scanners; ignore unless rate climbs.
- `logger=pipeline` — content-generation hiccup; check `/admin/pipeline`.
- `logger=stripe` — webhook signature mismatch; usually a misconfigured webhook URL.

**Escalation**

If sustained >24 h and you can identify a specific pattern: add a more targeted alert + investigate root cause.

---

### MambakkamErrorLogs

**Severity:** `[WARN]`
**Expr:** `sum(rate({vhost="mambakkam.net", kind="error"}[10m])) > 0.1` for 10 m

**What it means**

Host nginx error log is producing >0.1 lines/sec for 10 min on the mambakkam vhost. Common: 502 (upstream container restarting), 504 (upstream slow), bot traffic hitting non-existent paths.

**First response**

```bash
sudo tail -100 /var/log/nginx/mambakkam.net.error.log
```

If it's all 502s and the timestamp matches a deploy → expected (briefly during container swap).
If it's bot scanning → fail2ban will catch persistent abuse; no action.
If it's unexpected upstream errors → check astrowind container.

**Escalation**

If an attack pattern is visible (same User-Agent, distributed IPs): add a Cloudflare WAF rule.

---

### ResticPruneFailed

**Severity:** `[WARN]`
**Expr:** `count_over_time({job="backups"} |~ "prune FAILED" [1d]) > 0`

**What it means**

The weekly `restic prune` failed. Disk space won't be reclaimed from forgotten snapshots; repo size will grow until next successful prune.

**First response (next-time-at-keyboard)**

```bash
# 1. Lock files from a prior crashed run are the most common cause:
sudo ls -la /opt/<site>/backups/restic/locks/

# 2. If lock files exist and are stale (older than ~30 min):
sudo RESTIC_PASSWORD_FILE=/etc/restic/<site>.password \
     restic -r /opt/<site>/backups/restic unlock

# 3. Re-run prune:
sudo RESTIC_PASSWORD_FILE=/etc/restic/<site>.password \
     restic -r /opt/<site>/backups/restic prune --max-unused 5%
```

**Escalation**

If prune keeps failing: check disk space (CX22DiskFull might also be firing), then the restic GitHub issues for the version installed.

---

### BackupSizeRunaway

**Severity:** `[WARN]`
**Expr:** Heuristic: any `repo on-disk size: <2-digit-or-more>G` line in last 24h

**What it means**

The backup script logged a repo size of ≥10 GB. Heuristic — not precise. Usually means dedup ratio degraded (lots of new content) or daily forgets aren't actually freeing anything (prune is failing, see ResticPruneFailed).

**First response (next-time-at-keyboard)**

```bash
sudo RESTIC_PASSWORD_FILE=/etc/restic/<site>.password \
     restic -r /opt/<site>/backups/restic stats --mode raw-data
```

If the "Total Size" is unexpectedly large, look at recent commits in the content store / images dir to see what's been added.

**Escalation**

Tune the rule once you have a few weeks of baseline data. The proper fix is a Prometheus exporter for `restic stats --json` — flagged in `BACKUPS.md` as future work.

---

### SSHBruteForce

**Severity:** `[WARN]`
**Expr:** `sum(rate({job="systemd-journal", unit="sshd.service"} |~ "Failed password" [5m])) > 1` for 5 m

**What it means**

Sustained SSH login failures >1/sec for 5 min. fail2ban automatically bans single-source attackers; this catches distributed attempts.

**First response (next-time-at-keyboard)**

```bash
# 1. Confirm SSH is key-only (it should be):
sudo grep PasswordAuthentication /etc/ssh/sshd_config       # expect "no"

# 2. Recent fail2ban activity:
sudo fail2ban-client status sshd
sudo journalctl -u fail2ban --since "1 hour ago" | tail -20
```

If `PasswordAuthentication no` is set → password auth is rejected at the protocol level; "Failed password" entries are red herrings (some sshd versions log them anyway). No action needed.

**Escalation**

- If somehow PasswordAuthentication ends up "yes" again: set to "no", restart sshd, run `provision.sh` to re-cement.
- If a specific IP is hammering despite fail2ban (very rare): add it to `/etc/hosts.deny` directly.

---

### Fail2banBurst

**Severity:** `[WARN]`
**Expr:** `sum(rate({job="systemd-journal", unit="fail2ban.service"} |~ "Ban" [10m])) > 5` for 10 m

**What it means**

fail2ban is issuing >5 bans per 10 min — a meaningful incoming attack pattern. fail2ban handled it for SSH; this is a heads-up.

**First response (next-time-at-keyboard)**

```bash
# Per-jail breakdown:
sudo fail2ban-client status
for jail in $(sudo fail2ban-client status | awk -F"\t" '/Jail list/ {print $2}' | tr ',' ' '); do
  echo "── $jail ──"
  sudo fail2ban-client status "$jail"
done
```

If this is the `sshd` jail only → expected during attack waves; no action.
If a non-SSH jail (`auth`, `web`) is busy → that's an application-layer brute force. Investigate the corresponding service.

**Escalation**

Cloudflare WAF can be tightened (Bot Fight Mode + rate limit) for application-layer attacks. Free tier covers it.

---

## Adding a new alert

1. Pick metric or log: a metric source uses Mimir; a log pattern uses Loki.
2. Add a rule under the appropriate group in `infra/monitoring/alerts/{metric,log}-rules.yaml`.
3. Set `severity: page` or `severity: warn` deliberately. Defaults are: paying-customer impact / DR risk → page; everything else → warn.
4. Set `runbook_url` annotation to a future-anchor in this file (`#newalertname`). Add the entry below to match.
5. `bash infra/monitoring/alerts/apply.sh` to upload.
6. Verify the alert fires by lowering its threshold temporarily.

Don't ship an alert without a runbook entry. An unguided 3am page is hostile to whoever's on call (today: only you).

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                               |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-05-09 | 1.0     | Initial — 14 alerts (5 metric + 9 log) consolidated from MONITORING/LOGGING/BACKUPS docs into a single source of truth. Per-alert response runbook. Notification routing as 2-severity Gmail click-ops. apply.sh helper for uploads. |
