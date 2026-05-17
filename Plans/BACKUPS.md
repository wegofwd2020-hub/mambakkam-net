# Backups & Restore — mambakkam.net + StudyBuddy (shared CX22)

**Document version:** 1.0
**Date:** 2026-05-09
**Status:** Scaffolded; both repos initialised by their respective `provision.sh`.
**Companion docs:**

- [`MONITORING.md`](MONITORING.md) — metrics architecture
- [`LOGGING.md`](LOGGING.md) — log shipping + the `BackupSilent` alert
- [`DEMO_LAUNCH_PLAN.md`](DEMO_LAUNCH_PLAN.md) — launch runbook (this file is referenced from §9)
- [`StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md`](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand/blob/main/docs/DEMO_LAUNCH_PLAN.md) — second-tenant launch plan

---

## TL;DR

| What                 | Where                                                  | When                                   | Restore via                                          |
| -------------------- | ------------------------------------------------------ | -------------------------------------- | ---------------------------------------------------- |
| **mambakkam repo**   | `/opt/mambakkam/backups/restic/` (encrypted, deduped)  | Daily 02:30 UTC                        | `restic restore <snapshot-id> --target /tmp/restore` |
| **StudyBuddy repo**  | `/opt/studybuddy/backups/restic/` (encrypted, deduped) | Daily 02:00 UTC                        | same syntax, different password file                 |
| **Integrity check**  | both repos, `--read-data-subset 5%` + `prune`          | Weekly Sun 03:00 (SB) / 03:30 (mb) UTC | log: `/var/log/{site}-backup.log`                    |
| **Hetzner snapshot** | StudyBuddy only, optional via `HCLOUD_TOKEN`           | Daily after restic, if token set       | Hetzner console                                      |

Retention: `--keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 1` ≈ 15 snapshots, ~1.2× a single full snapshot on disk thanks to dedup.

Passwords: `/etc/restic/{mambakkam,studybuddy}.password` (mode 600 root). **Lost password = unrecoverable repo.**

---

## What's in each repo

### mambakkam repo — `/opt/mambakkam/backups/restic/`

| Source                                      | Why it's backed up                                                                       |
| ------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `/opt/mambakkam/src/assets/images/`         | Large media, occasionally dropped on the VPS without git commit                          |
| `/opt/mambakkam/.env.demo`                  | Analytics ID + (future) SMTP creds; tedious to reconstruct                               |
| `/etc/ssl/cloudflare/origin-{cert,key}.pem` | Origin Cert + key (15-yr validity, regeneratable from Cloudflare but cleaner to back up) |
| `/var/log/nginx/mambakkam.net.*.log[.gz]`   | Host nginx access + error logs incl. logrotate's archives                                |

### StudyBuddy repo — `/opt/studybuddy/backups/restic/`

| Source                                              | Why it's backed up                                                                                                                                                   |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/opt/studybuddy/backups/staging/db-latest.dump.gz` | Postgres `pg_dump -Fc` of the studybuddy database, written fresh before each restic run (dedup means many "daily" dumps cost <2x one dump on disk)                   |
| `/data/content/`                                    | Content store — pre-generated lessons / quizzes / tutorials / experiments / MP3s. Costly to regenerate (~$215 of Anthropic spend per `studybuddy-docs/COST_PLAN.md`) |
| `/opt/studybuddy/.env.demo`                         | Server-generated secrets + Auth0 + Stripe-test + Gmail App Password values; expensive to reconstruct from scratch                                                    |

### What's deliberately NOT in either repo

- Container logs — already shipped to Loki (14 d retention there)
- Code + content as JSON in the repo — already in git
- Compose configs — already in git
- Redis state — cache + refresh-tokens; users can re-login. Not worth the backup churn at our scale
- Hetzner Origin Cert backup is in **mambakkam's** repo, not StudyBuddy's — single source of truth, since the cert is shared by both vhosts

---

## Why restic + local-only

**Operator decision 2026-05-09: stay local-only, encrypt + dedupe via restic.**

The 3-2-1 rule (3 copies / 2 media / 1 offsite) is the textbook target. We deliberately ship a 1-copy/1-medium/0-offsite posture for the demo, because:

- Demo carries no paying-customer data on day 1
- Off-box destinations add provider friction (Hetzner Storage Box is €1.20/mo + setup; B2 is free-tier-eligible but adds bandwidth charges if a 30 d restore goes badly)
- The restic encryption + dedup posture covers most of the wins (encrypted-at-rest reduces leak risk if disk is stolen / imaged; dedup means we keep more history without ballooning disk)

**Residual risk we accept:** total data loss if the CX22's disk fails or the box is rooted (in either case the local repo is gone too). Acceptable until first paying customer.

**To upgrade off-box later:** `restic copy` to a second repo on Hetzner Storage Box or Backblaze B2 — the on-CX22 repo stays as-is; nothing else changes. ~30 min of work + the operator pasting an SFTP password / B2 keypair.

---

## How it runs day-to-day

### Daily backup

mambakkam: `02:30 UTC` cron → `bash /opt/mambakkam/scripts/launch/backup.sh`
StudyBuddy: `02:00 UTC` cron → `bash /opt/studybuddy/scripts/demo/backup.sh`

Steps each script does:

1. (StudyBuddy only) `pg_dump -Fc | gzip` → staging file (overwritten daily; dedup handles retention)
2. `restic backup` snapshot of all sources, tagged `daily` + `host=<hostname>`
3. `restic forget` to apply the keep-policy (no `prune` — see below)
4. (StudyBuddy only) Optional Hetzner snapshot via API if `HCLOUD_TOKEN` set

The daily run only `forget`s — `prune` is heavy (rewrites pack files) and runs weekly instead.

### Weekly integrity check + prune

mambakkam: `Sun 03:30 UTC` → `bash backup-check.sh`
StudyBuddy: `Sun 03:00 UTC` → `bash backup-check.sh`

Steps:

1. `restic check --read-data-subset 5%` — verifies repo metadata + reads 5% of pack files to catch silent bit-rot. 100% would take too long on the daily disk; 5% weekly cycles every pack within ~5 months.
2. `restic prune --max-unused 5%` — reclaims disk that the daily forgets have marked as unreferenced.

Both append to the same log file the daily run uses, so the `BackupSilent` Loki alert in [`LOGGING.md`](LOGGING.md) catches a failure on either path.

### Where the logs land

| Site       | Log file                         | LogQL query (Grafana Cloud)           |
| ---------- | -------------------------------- | ------------------------------------- |
| mambakkam  | `/var/log/mambakkam-backup.log`  | `{job="backups", which="mambakkam"}`  |
| StudyBuddy | `/var/log/studybuddy-backup.log` | `{job="backups", which="studybuddy"}` |

Grep recipes for the on-box fallback:

```bash
sudo grep -E "FAIL|FATAL|error" /var/log/mambakkam-backup.log | tail
sudo grep "snapshot" /var/log/studybuddy-backup.log | tail
sudo tail -f /var/log/studybuddy-backup.log   # live tail during a manual run
```

---

## Setup runbook (operator)

This runs automatically as part of `provision.sh` — the "restic password + repo init" step in each script (mambakkam's `scripts/launch/provision.sh` and StudyBuddy's `scripts/demo/provision.sh`). Don't hard-code step numbers here; they shift as the script grows. Quick reference for what the script does and what the operator must save out-of-band:

### First-tenant (mambakkam) — Day -1 (Sat May 16) cold start

1. `apt install restic` happens in step 1
2. Step 12 generates `/etc/restic/mambakkam.password` if absent
3. Step 12 initialises `/opt/mambakkam/backups/restic/`
4. **Final operator screen prints the password ONCE.** Save it to a password manager _now_.
5. The first daily-backup cron fires at 02:30 UTC the next day.

### Second-tenant (StudyBuddy) — Day 0 (Sun May 17) join

1. Pre-flight (step 0) confirms mambakkam already provisioned the box
2. Step 1 ensures `restic` is present (no-op if already installed)
3. Step 8 generates `/etc/restic/studybuddy.password` and inits the StudyBuddy repo
4. **Final operator screen prints the StudyBuddy password ONCE.** Save it to a password manager.
5. The first daily-backup cron fires at 02:00 UTC the next day.

### Manual force-run (sanity check after install)

```bash
ssh deploy@<vps-ip>

# mambakkam — runs the full daily routine (1-2 min)
sudo bash /opt/mambakkam/scripts/launch/backup.sh

# StudyBuddy — runs the full daily routine (~5 min, mostly pg_dump)
sudo bash /opt/studybuddy/scripts/demo/backup.sh

# List snapshots in either repo
sudo RESTIC_PASSWORD_FILE=/etc/restic/mambakkam.password \
     restic -r /opt/mambakkam/backups/restic snapshots

sudo RESTIC_PASSWORD_FILE=/etc/restic/studybuddy.password \
     restic -r /opt/studybuddy/backups/restic snapshots
```

---

## Restore runbook

Five common scenarios. Run as `root` unless noted otherwise.

### Scenario 1 — full Postgres restore (StudyBuddy)

For when the live DB is corrupted, a bad migration ate data, or you want to roll back to yesterday's state.

```bash
# 1. Pick a snapshot.
sudo RESTIC_PASSWORD_FILE=/etc/restic/studybuddy.password \
     restic -r /opt/studybuddy/backups/restic snapshots --tag daily
# Note the ID column of the row you want, e.g. abc12345

# 2. Restore the dump file to a tmp path.
sudo RESTIC_PASSWORD_FILE=/etc/restic/studybuddy.password \
     restic -r /opt/studybuddy/backups/restic restore abc12345 \
     --target /tmp/sb-restore \
     --include /opt/studybuddy/backups/staging/db-latest.dump.gz

# 3. Stop the API + workers (keep the db container up):
cd /opt/studybuddy
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo stop api celery-worker celery-beat-primary web

# 4. Restore the dump into a fresh database name (safer than overwriting):
DUMP="/tmp/sb-restore/opt/studybuddy/backups/staging/db-latest.dump.gz"
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo exec -T db \
     bash -c "createdb -U studybuddy studybuddy_restore && \
              gunzip -c < /dev/stdin | pg_restore -U studybuddy -d studybuddy_restore" \
     < "$DUMP"

# 5. Sanity-check the restored DB BEFORE swapping (count rows you expect):
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo exec -T db \
     psql -U studybuddy -d studybuddy_restore -c \
     "SELECT count(*) FROM students; SELECT count(*) FROM curricula;"

# 6. Atomically swap (rename current → backup, restored → current):
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo exec -T db \
     psql -U studybuddy -d postgres -c \
     "ALTER DATABASE studybuddy RENAME TO studybuddy_old; \
      ALTER DATABASE studybuddy_restore RENAME TO studybuddy;"

# 7. Restart services:
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo start api celery-worker celery-beat-primary web

# 8. Smoke-check via the existing script:
bash /opt/studybuddy/scripts/demo/smoke.sh https://demo.usestudybuddy.com

# 9. After confirming everything works, drop the old DB:
sudo docker compose -f docker-compose.yml -f docker-compose.demo.yml \
     --env-file .env.demo exec -T db \
     psql -U studybuddy -d postgres -c "DROP DATABASE studybuddy_old;"

# 10. Clean up the staging restore:
sudo rm -rf /tmp/sb-restore
```

### Scenario 2 — single content unit restore (StudyBuddy)

You accidentally deleted `/data/content/curricula/default-2026-g8/G8-MATH-001/` and need it back.

```bash
# 1. Find the latest snapshot containing the file:
sudo RESTIC_PASSWORD_FILE=/etc/restic/studybuddy.password \
     restic -r /opt/studybuddy/backups/restic find /data/content/curricula/default-2026-g8/G8-MATH-001

# 2. Restore the directory:
sudo RESTIC_PASSWORD_FILE=/etc/restic/studybuddy.password \
     restic -r /opt/studybuddy/backups/restic restore latest \
     --target / \
     --include /data/content/curricula/default-2026-g8/G8-MATH-001

# 3. Verify:
ls -la /data/content/curricula/default-2026-g8/G8-MATH-001/
```

`latest` resolves to the most recent snapshot. Use a snapshot ID instead if you need a specific older version.

### Scenario 3 — recover an `.env.demo` after disk loss

You're rebuilding the box from a Hetzner snapshot taken before the breakage and need yesterday's `.env.demo` (the snapshot is older).

```bash
# Mount the older restic repo from a Hetzner volume / Storage Box / etc:
sudo RESTIC_PASSWORD_FILE=/path/to/saved/studybuddy.password \
     restic -r /path/to/recovered/restic restore latest \
     --target /tmp/env-restore \
     --include /opt/studybuddy/.env.demo

# Inspect:
sudo cat /tmp/env-restore/opt/studybuddy/.env.demo

# Copy back into place:
sudo cp /tmp/env-restore/opt/studybuddy/.env.demo /opt/studybuddy/.env.demo
sudo chmod 600 /opt/studybuddy/.env.demo
sudo chown deploy:deploy /opt/studybuddy/.env.demo
```

You'll likely want to rotate the secrets in this file after a recovery — assume the previous values may be compromised if the disk loss was malicious.

### Scenario 4 — recover the Cloudflare Origin Cert + key

```bash
sudo RESTIC_PASSWORD_FILE=/etc/restic/mambakkam.password \
     restic -r /opt/mambakkam/backups/restic restore latest \
     --target / \
     --include /etc/ssl/cloudflare

sudo nginx -t && sudo systemctl reload nginx
```

If both the on-disk repo and your password manager copy are gone: regenerate the cert at Cloudflare → SSL/TLS → Origin Server (15-min recreate path), making sure the SAN list still includes mambakkam.net + \*.mambakkam.net + demo.usestudybuddy.com.

### Scenario 5 — historical access-log search (mambakkam)

You're investigating an incident from 9 days ago, before Loki's 14-day retention but within local-restic 30-day retention.

```bash
# 1. Find the snapshot from that date:
sudo RESTIC_PASSWORD_FILE=/etc/restic/mambakkam.password \
     restic -r /opt/mambakkam/backups/restic snapshots --tag daily \
     | grep "2026-04-30"   # adjust date

# 2. Restore just the log files:
sudo RESTIC_PASSWORD_FILE=/etc/restic/mambakkam.password \
     restic -r /opt/mambakkam/backups/restic restore <snapshot-id> \
     --target /tmp/old-logs \
     --include /var/log/nginx

# 3. grep / awk over the restored files:
zgrep "1.2.3.4" /tmp/old-logs/var/log/nginx/mambakkam.net.access.log*
```

---

## Suggested alerts (Grafana Cloud)

Backup-relevant alert rules ship in
[`infra/monitoring/alerts/log-rules.yaml`](../infra/monitoring/alerts/log-rules.yaml)
under group `backups`: `BackupSilent` (page), `ResticCheckFailed` (page),
`ResticPruneFailed` (warn), `BackupSizeRunaway` (warn). Per-alert
response procedures in [`RUNBOOK.md`](RUNBOOK.md).

`BackupSizeRunaway` is a LogQL heuristic — the proper fix is a Prometheus
exporter that runs `restic stats --json` periodically and emits
`restic_repo_size_bytes`. Flagged as future work below.

---

## Outstanding / future work

- **Off-box destination.** When the first paying customer arrives, add a Hetzner Storage Box (€1.20/mo) and copy snapshots there nightly via `restic copy`. The on-CX22 repo stays as the primary; the Storage Box becomes the disaster-recovery copy. ~30 min of setup work.
- **Restore drill cadence.** Today: one drill on Day -2 (Fri 2026-05-15) of the test phase. After launch: quarterly restore drills (next: 2026-08-14).
- **Password escrow.** If only the operator has the restic passwords and the operator is unavailable, the backups are unreachable. Two practical options: (a) dual-control via a sealed envelope kept somewhere safe, (b) a second team member's password manager once there's a second team member. Defer until there's a second person.
- **Restic exporter for Prometheus.** Would emit `restic_snapshot_count`, `restic_repo_size_bytes`, `restic_last_backup_seconds_ago`. Cheap to add (~50 lines of Python in a sidecar); deferred until we want the size-growth alerts above to be cleaner.
- **Secrets in repo.** `.env.demo` is in the restic repo. The repo is encrypted at rest but anyone with shell access on the CX22 + the password file can read it. This matches the existing security boundary (root on the box ≈ full compromise) so the marginal exposure is small. Revisit when there's a customer-data-breach posture to maintain.

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                                     |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-05-09 | 1.0     | Initial — restic-based local-only backups for both sites; daily snapshots + weekly integrity check + prune; password generation in provision.sh; 5-scenario restore runbook; residual-risk note + path to off-box destination when needed. |
