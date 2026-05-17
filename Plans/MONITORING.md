# Observability — mambakkam.net + StudyBuddy (shared CX23)

**Document version:** 1.0
**Date:** 2026-05-09
**Status:** Scaffolded; operator brings it up after pasting Grafana Cloud creds.
**Companion docs:**

- [`DEMO_LAUNCH_PLAN.md`](DEMO_LAUNCH_PLAN.md) — day-by-day cutover runbook (this file is referenced in §Observability)
- [`DEPLOYMENT_PLAN.md`](DEPLOYMENT_PLAN.md) — hosting architecture
- [`StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/docs/DEMO_LAUNCH_PLAN.md) — second-tenant runbook
- StudyBuddy's existing instrumentation: [`OBSERVABILITY.md`](https://github.com/wegofwd2020-hub/studybuddy-docs/blob/main/OBSERVABILITY.md) (dev-time Prometheus + Grafana on operator's laptop — superseded in production by this doc)

---

## TL;DR

| What                              | Where                                                                  | How to reach                                 |
| --------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------- |
| **Grafana** (dashboards + alerts) | Grafana Cloud free tier — `https://<your-stack>.grafana.net`           | Grafana SSO (Google / GitHub / email)        |
| **Prometheus UI** (ad-hoc PromQL) | Local on the CX23 — `127.0.0.1:9090`                                   | `ssh -L 9090:127.0.0.1:9090 deploy@<vps-ip>` |
| **mambakkam scrape target**       | nginx_exporter sidecar on container net                                | scraped only by local Prometheus             |
| **StudyBuddy `/metrics`**         | bearer-token-protected, `127.0.0.1:8443/metrics` (loopback)            | scraped only by local Prometheus             |
| **Public `/metrics`** (optional)  | `https://mambakkam.net/metrics`, `https://demo.usestudybuddy.com/metrics` | Cloudflare Access policy required            |
| **Synthetic uptime**              | blackbox-exporter on the CX23                                          | probes 5 public URLs every 15s               |
| **Host metrics**                  | node-exporter on host net                                              | scraped only by local Prometheus             |

Free-tier Grafana Cloud limits (2026-05): 10k active series, 13-month retention, no card required.

---

## Topology

```
┌─ Hetzner CX23 (4 GB RAM) ───────────────────────────────────────────────┐
│                                                                          │
│  Tenant 1: mambakkam-astrowind                                           │
│    ├─ nginx (8080) serves static dist/                                   │
│    └─ /stub_status (loopback in container net)                           │
│              ▲                                                            │
│              │ scrape (every 15s)                                         │
│  Tenant 2: StudyBuddy compose stack                                       │
│    └─ FastAPI api:8000 (compose-internal nginx fronts on 8443)           │
│              ▲                                                            │
│              │ scrape (every 15s, bearer-auth)                            │
│  Tenant 3: monitoring stack                                               │
│    ├─ nginx-prometheus-exporter      :9113                                │
│    ├─ blackbox-exporter              :9115                                │
│    ├─ node-exporter (host net)       :9100                                │
│    └─ Prometheus                     :9090 (loopback only)                │
│              │                                                            │
│              │ remote_write (every 15s, basic-auth)                       │
│              ▼                                                            │
└──────────────│───────────────────────────────────────────────────────────┘
               │
       Cloudflare TLS at edge
               │
               ▼
       Grafana Cloud free tier
       (https://<your-stack>.grafana.net)
        ├─ stores all metrics (13-month retention)
        ├─ dashboards (operator builds + imports JSON)
        └─ alerts (operator wires Slack / email)
```

---

## Why this shape

**Prometheus runs locally; Grafana lives in the cloud.**

- **Prometheus on the VPS** is small (~150 MB RAM, 7d local retention, 2 GB disk cap). It's the cheapest way to scrape co-located targets without a network round-trip per scrape, and it gives the operator a `127.0.0.1:9090` UI for ad-hoc PromQL when something is on fire.
- **Grafana Cloud free tier** at \*.grafana.net is where dashboards + long-term retention + alerting live. No local Grafana service to host means ~150 MB RAM saved on the CX23.
- **`remote_write`** ships every series Prometheus collects to Grafana Cloud. This is Prometheus's standard pattern for "send to managed backend"; same wire protocol Grafana Cloud documents.
- **`write_relabel_configs` in `prometheus.yml`** drops noisy series (especially node-exporter's ~600 default metrics) before they ship — keeps active-series count well under the 10k free-tier cap.

**Cloudflare Access gates the public `/metrics` URLs.**

Public `/metrics` exposure isn't required for the local-Prometheus scrape path (which uses loopback / docker-network), but the host nginx vhosts ship a `/metrics` location anyway so:

- Grafana Cloud (or another external scraper) can pull metrics over the public internet via Cloudflare Tunnel if needed
- The operator can curl from anywhere with their CF Access cookie
- Defence in depth: CF IP allowlist + CF Access JWT check + (for StudyBuddy) the application-level bearer token

The `/metrics` location refuses anything not coming from a Cloudflare IP and refuses anything missing the `Cf-Access-Jwt-Assertion` header — so a direct VPS-IP curl returns 403 even without the Cloudflare side configured.

---

## What gets scraped

### `mambakkam-nginx` job — nginx_exporter sidecar

Source: the astrowind container's `/stub_status` location (loopback inside the compose network).

| Metric                      | Type    | Use                                    |
| --------------------------- | ------- | -------------------------------------- |
| `nginx_http_requests_total` | counter | request rate, useful for traffic shape |
| `nginx_connections_active`  | gauge   | concurrent connections                 |
| `nginx_connections_writing` | gauge   | latency hint — tail of slow clients    |
| `nginx_up`                  | gauge   | 1 if nginx is responding               |

`stub_status` is the upstream nginx feature, not custom — works on the stock `nginx:stable-alpine` image already used by the astrowind Dockerfile.

### `studybuddy-api` job — FastAPI `/metrics`

Source: the StudyBuddy compose-internal nginx at `127.0.0.1:8443`, which proxies to FastAPI api:8000. Bearer token in `STUDYBUDDY_METRICS_TOKEN`.

Already documented in [`OBSERVABILITY.md`](https://github.com/wegofwd2020-hub/studybuddy-docs/blob/main/OBSERVABILITY.md). Series we keep:

| Prefix                        | Examples                                                                      |
| ----------------------------- | ----------------------------------------------------------------------------- |
| `sb_requests_total`           | per (method, path, status) — bound to ~750 series via FastAPI route templates |
| `sb_request_duration_seconds` | histogram with 10 buckets                                                     |
| `sb_db_pool_connections`      | min / max / size / free                                                       |
| `sb_redis_connected`          | 1/0                                                                           |
| `sb_auth_exchanges_total`     | per track                                                                     |
| `sb_auth_failures_total`      | per reason                                                                    |
| `sb_events_total`             | per (category, event_type)                                                    |
| `process_*`, `python_gc_*`    | auto-emitted by `prometheus_client`                                           |

### `cx22-host` job — node-exporter

Source: node-exporter on the host network, `127.0.0.1:9100/metrics`.

Series we keep (the small useful subset of ~600 default metrics):

- CPU: `node_cpu_seconds_total`
- Memory: `node_memory_(MemTotal|MemAvailable|MemFree|Cached|Buffers)_bytes`
- Disk: `node_filesystem_(size|free|avail)_bytes`, `node_disk_(read|write)_bytes_total`
- Network: `node_network_(receive|transmit)_bytes_total`
- Load: `node_load1`, `node_load5`, `node_load15`
- Filehandles: `node_filefd_(allocated|maximum)`
- Boot: `node_boot_time_seconds`

### `blackbox-https` job — synthetic uptime

Source: blackbox-exporter on the monitoring compose net.

Probes (every 15 s, 5 s timeout):

- `https://mambakkam.net`
- `https://mambakkam.net/people/siva-m`
- `https://mambakkam.net/sitemap-index.xml`
- `https://demo.usestudybuddy.com`
- `https://demo.usestudybuddy.com/healthz`

Series shipped: `probe_success`, `probe_duration_seconds`, `probe_http_status_code`, `probe_http_ssl`. Cardinality stays low because each target adds 4 series.

Dashboard signal: alert if `probe_success == 0` for 2 consecutive scrapes (60 s).

---

## Setup runbook (operator, ~30 min)

### Phase 1 — Grafana Cloud account (one-time, ~5 min)

1. Sign up at https://grafana.com/auth/sign-up/create-user (free, no card)
2. Create a stack — pick a region close to the CX23 (e.g. `prod-eu-west-2` for Falkenstein)
3. Stack → **Connections → Hosted Prometheus metrics → Send Metrics**
   - Copy the `URL` value → paste into `.env.monitoring` as `GRAFANA_CLOUD_REMOTE_WRITE_URL`
   - Click **Generate now** under "Password / API Token" → paste the token as `GRAFANA_CLOUD_API_KEY`
   - Note the numeric `username` (your stack ID) → paste as `GRAFANA_CLOUD_USERNAME`

### Phase 2 — Bring up the local stack (~5 min, after StudyBuddy is provisioned)

> The `.env.monitoring` file needs **both** the Prometheus creds (set up in Phase 1 above) and the **Loki creds** (set up in [`LOGGING.md`](LOGGING.md) Phase 2). Do LOGGING.md Phase 2 before running this — otherwise Promtail will start without `GRAFANA_CLOUD_LOKI_URL` + `GRAFANA_CLOUD_LOKI_USERNAME` and log shipping silently fails.

```bash
ssh deploy@<cx22-ip>
cd /opt/mambakkam/infra/monitoring

# Edit creds (provision.sh wrote a template):
vi .env.monitoring

# Copy STUDYBUDDY_METRICS_TOKEN from /opt/studybuddy/.env.demo:
grep '^METRICS_TOKEN=' /opt/studybuddy/.env.demo

# Bring it up:
docker compose --env-file .env.monitoring up -d

# Verify:
docker compose ps                                # 4 containers, all Up
curl -s http://127.0.0.1:9090/-/ready             # "Prometheus is Ready."
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
# Expect 5 jobs all health=up: prometheus, mambakkam-nginx, cx22-host,
# blackbox-https, studybuddy-api
```

If `studybuddy-api` is `health=down`, the bearer token mismatch is almost
certainly the cause. Re-check `STUDYBUDDY_METRICS_TOKEN` matches what's in
`/opt/studybuddy/.env.demo`.

### Phase 3 — Confirm data lands in Grafana Cloud (~2 min)

1. Open https://`<your-stack>`.grafana.net
2. Explore → Prometheus data source (the default one named `grafanacloud-<stack>-prom`)
3. Run query: `up{env="production"}` — should return 5 series (one per job)
4. Run query: `nginx_http_requests_total` — should return mambakkam request counters

If nothing shows up after 60 s, check `prometheus_remote_storage_failed_samples_total` on the local Prometheus UI (`http://127.0.0.1:9090/graph`) — if it's climbing, the credentials are wrong.

### Phase 4 — Build dashboards (ongoing)

Suggested starter dashboards in Grafana Cloud:

| Dashboard          | Top panels                                                                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **CX23 Host**      | CPU, memory available, disk free, load avg, network throughput                                                                                   |
| **Public Uptime**  | `probe_success` per target as a status timeline; `probe_duration_seconds` p50/p95                                                                |
| **mambakkam.net**  | nginx requests/sec, active connections, 5xx rate (derived from nginx access log if you wire mtail later)                                         |
| **StudyBuddy API** | `sb_requests_total` rate by status, `sb_request_duration_seconds` p50/p95, `sb_db_pool_connections{state="free"}`, `sb_auth_failures_total` rate |

The `sb_*` dashboard already exists in StudyBuddy's dev setup ([`studybuddy-health` JSON](https://github.com/wegofwd2020-hub/studybuddy-docs/blob/main/OBSERVABILITY.md)) — it can be imported wholesale once you point its data source at the Grafana Cloud Prometheus.

### Phase 5 — Wire alerts (ongoing)

Alert rules live as code in [`infra/monitoring/alerts/metric-rules.yaml`](../infra/monitoring/alerts/metric-rules.yaml).
Per-alert response procedures + notification routing setup are in
[`Plans/RUNBOOK.md`](RUNBOOK.md). Apply via:

```bash
cd /opt/mambakkam/infra/monitoring/alerts
bash apply.sh
```

Severity convention: `[PAGE]` Gmail subject for customer-visible / DR
issues; `[WARN]` for everything else. Single Gmail destination
(`siva@mambakkam.net`); two Gmail filters split into
`alerts/page` + `alerts/warn` labels.

---

## What's deliberately NOT here at launch

- **Local Grafana** — Grafana Cloud has the UI; saving the local RAM
- **Alertmanager** — Grafana Cloud handles routing on the same metrics
- **Loki / log aggregation** — nginx access logs stay on the CX23 for the operator to grep; Loki on the free tier is plausible follow-up work
- **Tempo / tracing** — no app-side tracing instrumentation today
- **Pushgateway** — no batch jobs to push from yet
- **mtail / log-based exporters** — page-level KPIs from nginx access logs deferred; nginx_exporter's stub_status counters are enough for traffic-shape monitoring at launch
- **Cloudflare Tunnel** — only needed if the operator wants to scrape `/metrics` from a different VPS / Grafana Cloud directly; today the local Prometheus + remote_write covers all observability paths without needing a tunnel

---

## Outstanding work flagged

1. **Cloudflare Access policies** for `mambakkam.net/metrics` and `demo.usestudybuddy.com/metrics` are NOT auto-configured by any script — operator action in the Cloudflare dashboard. Without them, the nginx-side IP allowlist + JWT-header check is the only gate (still safe — direct curls return 403 — but not the full zero-trust posture).

2. **Cloudflare IPv6 ranges** are not in the host nginx vhost allowlist yet. If the CX23 enables IPv6, regenerate the allowlist from https://www.cloudflare.com/ips-v6/.

3. **Quarterly re-check of Cloudflare's IP allowlist.** Calendar reminder: Aug 2026, Nov 2026, Feb 2027.

4. **Origin Cert SAN list.** When mambakkam.net's `provision.sh` generates the Cloudflare Origin Cert, the SAN list MUST include all of:
   - `mambakkam.net`
   - `*.mambakkam.net`
   - `demo.usestudybuddy.com`

   If you also expose `monitoring.mambakkam.net` later (e.g. for a self-hosted Grafana down the road), re-issue the cert with that hostname added.

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                                                                   |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-05-09 | 1.0     | Initial — Prometheus on CX23 + remote_write to Grafana Cloud free tier; nginx-prometheus-exporter for mambakkam; bearer-token /metrics for StudyBuddy; blackbox-exporter for synthetic uptime; node-exporter for host; Cloudflare-Access-gated public /metrics surfaces. |
