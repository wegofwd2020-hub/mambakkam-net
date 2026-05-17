# Logging — mambakkam.net + StudyBuddy (shared CX22)

**Document version:** 1.0
**Date:** 2026-05-09
**Status:** Scaffolded; brought up alongside Prometheus by the same operator runbook.
**Companion docs:**

- [`MONITORING.md`](MONITORING.md) — metrics architecture + dashboards (sibling document)
- [`DEMO_LAUNCH_PLAN.md`](DEMO_LAUNCH_PLAN.md) — launch runbook (this file is referenced from §8)
- StudyBuddy's structlog setup: [`backend/src/utils/logger.py`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/backend/src/utils/logger.py)

---

## TL;DR

| What                              | Where                                             | How to query                            |
| --------------------------------- | ------------------------------------------------- | --------------------------------------- |
| **Live tail (any source)**        | Grafana Cloud Explore — Loki data source          | LogQL via `<stack>.grafana.net/explore` |
| **App logs** (StudyBuddy)         | Grafana Cloud Loki + local `docker logs` fallback | `{project="studybuddy"}`                |
| **Static-site logs** (mambakkam)  | same                                              | `{project="mambakkam-net"}`             |
| **HTTP access logs**              | Host nginx vhost files + Loki                     | `{job="nginx-host"}`                    |
| **System logs** (sshd, ufw, etc.) | journald + Loki                                   | `{job="systemd-journal"}`               |
| **Backup script output**          | `/var/log/*-backup.log` + Loki                    | `{job="backups"}`                       |

Free-tier Loki: 50 GB monthly ingest + 14-day retention.

---

## Topology

```
┌─ Hetzner CX22 ─────────────────────────────────────────────────────────┐
│                                                                         │
│  Tenant 1: mambakkam-astrowind                                          │
│    └─ stdout/stderr → Docker json-file driver                           │
│           (mounted into Promtail at /var/lib/docker/containers/...)     │
│                                                                         │
│  Tenant 2: StudyBuddy compose stack                                     │
│    ├─ api / celery / web stdout (structlog JSON) → Docker json-file     │
│    ├─ db / redis / nginx stdout → Docker json-file                      │
│    └─ All json-file driver capped at 10 MB × 5 files (50 MB max each)   │
│                                                                         │
│  Tenant 3: monitoring compose stack                                     │
│    ├─ Promtail :9080  (loopback)                                        │
│    │     ├── docker_sd  (auto-tails every container in tenants 1-3)     │
│    │     ├── /var/log/nginx/*.log     (host-mounted, RO)                │
│    │     ├── /var/log/journal         (systemd journal binary, RO)      │
│    │     └── /var/log/*-backup.log    (cron backup logs, RO)            │
│    │                                                                     │
│    │           push (every 5 s, batched)                                │
│    │           ↓                                                         │
│    └──────────│─────────────────────────────────────────────────────────┘
                │
        Cloudflare TLS at edge
                │
                ↓
        Grafana Cloud Loki (logs-prod-NN-prod-YY.grafana.net)
        - 50 GB/month ingest free
        - 14-day retention free
        - Searchable in same Grafana UI as metrics
        - Supports log-based alerts
```

---

## Why this shape

**Logs follow the same agent-model as metrics.**

- Local agent does the tailing (Promtail for logs, Prometheus for metrics).
- Cloud-managed backend does the storage + UI (Grafana Cloud Loki for logs,
  Grafana Cloud Prometheus for metrics).
- One auth token for both; one Grafana UI for both; one bill (free at our scale).

**stdout / stderr is the only logging convention.**

- StudyBuddy backend uses `structlog` → JSON to stdout (see
  [`backend/src/utils/logger.py`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/backend/src/utils/logger.py)).
  Promtail's `pipeline_stages` parses the JSON, promotes `level` and `logger`
  to Loki labels, and uses the structlog timestamp as the log line's time
  (instead of Promtail's read time).
- mambakkam astrowind container uses stock nginx logs (text format) — no
  custom serialisation. Promtail ships them line-for-line.
- Host nginx is the only thing logging to files instead of stdout, because
  it's installed by `apt` and runs as a systemd service. Promtail tails
  those files via a `/var/log` host mount.

**No local Loki to host.**

Same trade-off as no-local-Grafana for metrics: ~80 MB RAM saved on the CX22
in exchange for a SaaS dependency. Acceptable at our traffic forecast.

---

## What gets shipped (4 sources)

### 1. `docker` job — auto-discovered container logs

Promtail's `docker_sd_configs` polls the Docker socket every 15 s and emits
a target for every running container across all three compose stacks. Each
log line gets these Loki labels:

| Label       | Source                                                     | Example                                     |
| ----------- | ---------------------------------------------------------- | ------------------------------------------- |
| `container` | container name                                             | `mambakkam-astrowind`, `studybuddy-api-1`   |
| `project`   | compose project label                                      | `mambakkam-net`, `studybuddy`, `monitoring` |
| `service`   | compose service label                                      | `api`, `web`, `astrowind`, `prometheus`     |
| `stream`    | stdout vs stderr                                           | `stdout`, `stderr`                          |
| `level`     | structlog `level` field (StudyBuddy only, via JSON parser) | `info`, `warning`, `error`                  |
| `logger`    | structlog `logger` field (StudyBuddy only)                 | `auth`, `content`, `pipeline`               |

Drop rules in `pipeline_stages`:

- StudyBuddy lines with `level=debug` are dropped at ingest (~halves the
  StudyBuddy log volume; debug-noise rarely useful at runtime).

### 2. `nginx-host` job — host nginx vhost files

Tails `/var/log/nginx/*.log`. The filename is parsed into `vhost` and `kind`
labels:

| Filename                         | `vhost`               | `kind`   |
| -------------------------------- | --------------------- | -------- |
| `mambakkam.net.access.log`       | `mambakkam.net`       | `access` |
| `mambakkam.net.error.log`        | `mambakkam.net`       | `error`  |
| `demo.usestudybuddy.com.access.log` | `demo.usestudybuddy.com` | `access` |
| `demo.usestudybuddy.com.error.log`  | `demo.usestudybuddy.com` | `error`  |

The compose-internal nginx (inside the StudyBuddy stack and the mambakkam
astrowind container) also writes access logs, but they go to stdout and
get picked up by job 1 above — no double-counting.

### 3. `journal` job — systemd journal

Reads `/var/log/journal` (binary). Per-line labels: `unit`, `hostname`,
`priority`. Drop rules:

- Priority 7 (`debug`) journal lines are dropped at ingest.

Coverage: `sshd.service`, `fail2ban.service`, `ufw`, `docker.service`,
`cron.service`, `nginx.service` (host nginx), and any other systemd unit.

### 4. `backups` job — cron-installed backup script logs

Tails `/var/log/*-backup.log` (matches `mambakkam-backup.log` and
`studybuddy-backup.log`). Filename parses into a `which` label
(`mambakkam` or `studybuddy`).

---

## How to access logs

### Via Grafana Cloud (the default)

1. Open https://`<your-stack>`.grafana.net
2. Explore (compass icon, left rail) → data source: **`grafanacloud-<stack>-logs`**
3. Run LogQL queries — see the cheatsheet below
4. Use the time range picker (top right) to scope by time

LogQL works like PromQL but for logs. Quick mental model: `{label_selector}` to
pick streams, `|=` / `!=` / `|~` to filter substrings, `|` followed by a parser
(`json`, `regexp`, `pattern`) to extract structured fields.

### LogQL cheatsheet — common queries

**StudyBuddy errors only, last 1 h:**

```logql
{project="studybuddy", level="error"}
```

**Tail StudyBuddy auth-related logs:**

```logql
{project="studybuddy", logger="auth"}
```

**All 5xx responses on demo.usestudybuddy.com, sorted by URL:**

```logql
{vhost="demo.usestudybuddy.com", kind="access"} |~ "\" 5\\d\\d "
```

(LogQL regex; the `\` needs doubling in YAML/JSON contexts.)

**fail2ban bans in the last 24 h:**

```logql
{job="systemd-journal", unit="fail2ban.service"} |~ "Ban|Unban"
```

**5xx rate from mambakkam, last 5 min, as a counter for alerting:**

```logql
sum by (vhost) (rate({vhost="mambakkam.net", kind="access"} |~ "\" 5\\d\\d " [5m]))
```

**Backup failures last 7 d:**

```logql
{job="backups"} |~ "(?i)error|fail|abort"
```

**Search across both sites for an IP address (incident triage):**

```logql
{job="nginx-host"} |= "1.2.3.4"
```

### Local fallback — no Grafana Cloud

When Grafana Cloud is unreachable, or the operator is already on the box,
the same data is available raw:

```bash
# ── Container logs (tenant 1 + 2 + 3) ────────────────────────────────────
docker ps --format "table {{.Names}}\t{{.Status}}"
docker logs --tail 200 -f mambakkam-astrowind
docker logs --tail 200 -f studybuddy-api-1            # name varies
docker logs --tail 200 -f monitoring-prometheus

# All containers from one compose project (tail 100, follow):
docker compose -f /opt/mambakkam/docker-compose.demo.yml logs --tail 100 -f
docker compose -f /opt/studybuddy/docker-compose.demo.yml logs --tail 100 -f

# ── Host nginx logs ──────────────────────────────────────────────────────
sudo tail -f /var/log/nginx/mambakkam.net.access.log
sudo tail -f /var/log/nginx/demo.usestudybuddy.com.error.log

# Top 10 5xx URLs in the last 1000 lines:
sudo grep -E '" 5\d\d ' /var/log/nginx/demo.usestudybuddy.com.access.log \
  | tail -1000 \
  | awk '{print $7}' | sort | uniq -c | sort -rn | head

# ── systemd journal ─────────────────────────────────────────────────────
journalctl -u sshd --since "1 hour ago"
journalctl -u fail2ban --since today | grep Ban
journalctl -u nginx -p err          # priority error or higher
journalctl -k --since "1 hour ago"   # kernel ring buffer

# ── Backup logs ──────────────────────────────────────────────────────────
sudo tail -f /var/log/mambakkam-backup.log
sudo tail -f /var/log/studybuddy-backup.log
```

### When to use which surface

| Question                                                 | Surface                                                                         |
| -------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------- |
| "Why is `/api/v1/X` returning 500?"                      | Grafana Cloud — search by URL, filter by `level=error`, see surrounding context |
| "Is fail2ban actively banning during a probe?"           | journalctl on the box (real-time) OR Loki with a tight time range               |
| "Did last night's backup succeed?"                       | Loki query for `{job="backups"}                                                 | last 8h`; fallback `cat /var/log/studybuddy-backup.log` |
| "Show me the last 50 lines from `api`, right now"        | `docker logs --tail 50 studybuddy-api-1` (faster than Loki round-trip)          |
| "What was the request rate at 14:30 UTC three days ago?" | Loki / Grafana Cloud (local files have rotated)                                 |

---

## Setup runbook (operator, ~5 min after MONITORING.md is done)

The Loki side piggybacks on the Grafana Cloud account already created for
metrics. Two extra values to add to `.env.monitoring`:

```bash
ssh deploy@<cx22-ip>
cd /opt/mambakkam/infra/monitoring
vi .env.monitoring
```

Add two lines (the `provision.sh` template now includes placeholders for them):

```
GRAFANA_CLOUD_LOKI_URL=https://logs-prod-NN-prod-YY.grafana.net
GRAFANA_CLOUD_LOKI_USERNAME=<your-numeric-loki-stack-id>
```

Find the values:

- Grafana Cloud portal → your stack → **Connections → Hosted Logs** → "Send Logs"
- Copy the `URL` and the numeric `User`
- The token (`GRAFANA_CLOUD_API_KEY`) is the same one already configured for
  metrics, IF the access policy was created with both `MetricsPublisher` and
  `LogsWriter` scopes. Otherwise generate a new policy with both.

Bring up the stack (or `up -d` to roll Promtail in alongside the existing
Prometheus + exporters):

```bash
docker compose --env-file .env.monitoring up -d

# Verify Promtail picked up the config:
docker compose logs --tail 50 promtail | grep -E "level=(info|error)"
# Look for "Started Loki Promtail" + "filetarget: watching new directory"
# entries; no "error" lines.

# Verify push is working:
docker compose exec promtail wget -qO- localhost:9080/metrics \
  | grep promtail_sent_entries_total
# Number should climb every 5 s as logs ship.
```

Then in Grafana Cloud:

1. Explore → Loki data source
2. Run `{job=~".+"}` — should show all 4 jobs streaming
3. Run `{project="mambakkam-net"}` — should show astrowind container logs
4. Run `{project="studybuddy"}` — should show structlog JSON

If Loki shows no data after 60 s:

- Check `promtail_dropped_entries_total` (should be 0)
- Check `promtail_request_duration_seconds_count{status_code="204"}` —
  204 means "accepted by Loki"; any other status code means push failure
- 401 / 403 → bad creds; double-check `GRAFANA_CLOUD_LOKI_USERNAME` is the
  Loki numeric ID, not the Prometheus one (they're different)

---

## Suggested log-based alerts

Source-of-truth lives in [`infra/monitoring/alerts/log-rules.yaml`](../infra/monitoring/alerts/log-rules.yaml).
Per-alert response procedures + notification routing are in
[`Plans/RUNBOOK.md`](RUNBOOK.md). Apply via `apply.sh` (same script that
uploads metric rules).

The set as of 2026-05-09: `StudyBuddyErrorBurst` (warn),
`Demo5xxRateHigh` (page), `MambakkamErrorLogs` (warn), `BackupSilent`
(page), `ResticCheckFailed` (page), `ResticPruneFailed` (warn),
`BackupSizeRunaway` (warn), `SSHBruteForce` (warn), `Fail2banBurst`
(warn).

---

## Security notes

- **No secrets in logs.** StudyBuddy's logger has the rule "never log
  passwords, JWT tokens, or Stripe keys" baked into
  [`backend/src/utils/logger.py`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/backend/src/utils/logger.py).
  Audit your structlog calls during code review.
- **Promtail runs as root** on the host because it needs the Docker socket
  - `/var/log/journal`. It mounts everything else read-only.
- **Cloud Access Policy token** — separate token from any user login.
  Scope it `MetricsPublisher` + `LogsWriter` only; revoke + rotate if the
  VPS is compromised.
- **PII in nginx access logs.** IPs are personal data under GDPR/PII
  regimes. Cloudflare's "Pseudonymize visitor IP" feature is enabled by
  default (it stamps `CF-Connecting-IP` for app use but the nginx access
  log sees the Cloudflare edge IP). For this demo we accept the residual
  risk; revisit before paying customers arrive.
- **Log retention.** 14 days on Loki + 7 days on the local container
  json-file rotation. Match this to your data-retention policy. After
  launch, once 30 days have elapsed (approx. 2026-06-16), consider
  turning Loki retention down to 7 d if ingest costs threaten the
  free tier.

---

## What's deliberately NOT here at launch

- **Tracing** (Tempo / OpenTelemetry) — no app-side tracing instrumentation
  today
- **Audit log centralisation** — StudyBuddy emits `write_audit_log` events
  that go to its own `audit_log` Postgres table. Those stay there;
  shipping them to Loki would duplicate. If you want Loki-side alerting
  on audit events, write a small periodic job that tails the table and
  emits to stdout (where Promtail can pick it up).
- **Slow-query logging** — Postgres `log_min_duration_statement` is not
  configured; if you turn it on, those lines flow through Promtail
  automatically (they go to `db` container's stdout)
- **Log-based metrics in Loki** (recording rules) — punt until we have a
  reason; Prometheus already covers per-status-code counters via
  nginx_exporter

---

## Outstanding before logs are "ready"

- Grafana Cloud account already has Logs feature enabled (it's on the free
  tier by default; this is a no-op)
- Cloud Access Policy token is scoped for `LogsWriter` (in addition to
  `MetricsPublisher`)
- `.env.monitoring` populated with `GRAFANA_CLOUD_LOKI_URL` +
  `GRAFANA_CLOUD_LOKI_USERNAME`
- Promtail container running healthy
- (Optional) Suggested alerts configured in Grafana Cloud Alerting

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                                                            |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-09 | 1.0     | Initial — Promtail on the CX22 ships docker / nginx / journald / backup logs to Grafana Cloud Loki free tier; LogQL cheatsheet + local-fallback runbook; suggested log-based alerts; Loki creds added to `.env.monitoring` template via mambakkam `provision.sh`. |
