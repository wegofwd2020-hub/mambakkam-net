# Activating the monitoring stack

A self-contained checklist to bring monitoring up for the first time. Written
2026-08-22 after discovering the stack had never been activated. For the
alert-response side, see [`../../Plans/RUNBOOK.md`](../../Plans/RUNBOOK.md).

## Why this exists

Verified on `mambakkam-cx22`, 2026-08-22:

- `docker ps` → **no monitoring containers running**
- `curl http://127.0.0.1:9090/-/ready` → **connection refused (HTTP 000)**
- `.env.monitoring` → still all `<placeholders>`

So there is currently **no active monitoring or alerting for any tenant**
(mambakkam.net, StudyBuddy, kaundinyalabs.com) even though the scrape config
and alert rules are all committed. `provision.sh` deliberately does not
auto-start the stack, because Prometheus cannot start against placeholder
secrets. Filling those in and bringing it up is the whole job.

## Step 1 — fill in `.env.monitoring`

Edit `/opt/mambakkam/infra/monitoring/.env.monitoring` (mode `600`, owned by
`deploy`, so edit as `deploy` or via `sudo`). Replace every `<placeholder>`.
Six values:

| Variable | What it is | Where to get it |
|---|---|---|
| `GRAFANA_CLOUD_REMOTE_WRITE_URL` | Prometheus push URL | Grafana Cloud → stack → **Connections → Hosted Prometheus → Send Metrics** (e.g. `https://prometheus-prod-XX-prod-YY.grafana.net/api/prom/push`) |
| `GRAFANA_CLOUD_USERNAME` | Numeric **Prometheus** instance/stack ID | Same "Send Metrics" page (username field) |
| `GRAFANA_CLOUD_LOKI_URL` | Loki push URL | **Connections → Hosted Logs (Loki) → Send Logs** (e.g. `https://logs-prod-NN-prod-YY.grafana.net`) |
| `GRAFANA_CLOUD_LOKI_USERNAME` | Numeric **Loki** user ID (separate from the Prometheus one) | Same "Send Logs" page |
| `GRAFANA_CLOUD_API_KEY` | Access Policy token (shared: metrics + logs + rules) | **Access Policies → Create access policy → create token** |
| `STUDYBUDDY_METRICS_TOKEN` | Bearer token for the StudyBuddy `/metrics` scrape | The `METRICS_TOKEN=` line in `/opt/studybuddy/.env.demo` |

> ### ⚠️ Token scope — correction to the scaffold's own comment
> The template comment in `.env.monitoring` says to scope the token
> `MetricsPublisher + LogsWriter`. **That is not enough.** `apply.sh` uploads
> alert rules to the Mimir/Loki **ruler API**, which needs the rules-write
> scope as well (`rules:write`, shown as **`alerts:write`** in some Grafana
> Cloud UIs). Create the access policy with **all three**: metrics write +
> logs write + rules/alerts write. With only the two publisher scopes,
> `remote_write` and logs work but `apply.sh` fails with `401/403`.

Confirm nothing is left unset — this must print `0`:

```bash
grep -c '=<' /opt/mambakkam/infra/monitoring/.env.monitoring
```

`STUDYBUDDY_METRICS_TOKEN` is not required for kaundinyalabs (only the
StudyBuddy app-metrics scrape uses it) and `apply.sh` will not block on it, but
set it so that scrape is not left failing.

## Step 2 — bring the stack up

```bash
cd /opt/mambakkam/infra/monitoring
docker compose --env-file .env.monitoring up -d
docker compose ps        # prometheus, blackbox, promtail, exporters all "Up"
```

## Step 3 — confirm it is live and shipping

```bash
curl -sf http://127.0.0.1:9090/-/ready && echo ready
# no auth/Non-recoverable errors here means remote_write reached Grafana Cloud:
docker logs --tail 20 monitoring-prometheus 2>&1 | grep -i remote_write
```

## Step 4 — upload the alert rules

```bash
cd /opt/mambakkam/infra/monitoring/alerts
bash apply.sh            # uploads metric + log rules to Grafana Cloud
```

Expect `[info] uploaded (200)` (or 201/202). A `401/403` means the token is
missing the rules/alerts write scope (see the callout above).

## Step 5 — verify end to end

```bash
# the kaundinyalabs.com uptime probe is registered and healthy
curl -s http://127.0.0.1:9090/api/v1/targets \
  | python3 -c "import sys,json; [print(t['labels']['instance'], t['health']) for t in json.load(sys.stdin)['data']['activeTargets'] if 'kaundinyalabs' in t['labels'].get('instance','')]"
# expect: https://kaundinyalabs.com up
```

Then in Grafana Cloud, confirm `KaundinyaLabsDown` (and the other rules) appear
under the `studybuddy-alerts` namespace, and that a notification policy is
configured (Grafana Cloud UI — see RUNBOOK "Notification routing setup").

Once step 5 shows `up` and the rules are present, monitoring is live and
kaundinyalabs-website issue #3 can be closed.
