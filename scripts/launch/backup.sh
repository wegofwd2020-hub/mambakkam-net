#!/usr/bin/env bash
# =============================================================================
# scripts/launch/backup.sh — daily restic backup for mambakkam.net
#
# Runs from cron at 02:30 UTC (offset 30 min from StudyBuddy's 02:00 to avoid
# I/O collision on the shared CX22 box).
#
# Sources (everything that's costly to recreate):
#   - $INSTALL_DIR/src/assets/images/   — large media, sometimes dropped on VPS
#   - /var/log/nginx/mambakkam.net.*    — host nginx vhost logs (rotation
#                                          archives still live in /var/log
#                                          when this runs; logrotate keeps 14d
#                                          worth, restic snapshots ~10s of MB)
#   - /etc/ssl/cloudflare/              — Origin Cert + key (15-yr validity but
#                                          a clean rebuild needs them on hand)
#   - $INSTALL_DIR/.env.demo            — env file with analytics ID etc.
#
# Why restic instead of plain rsync+gzip:
#   - Encryption-at-rest (AES-256). A stolen disk image isn't immediately
#     readable. Pre-launch posture; matters more once nginx access logs
#     start carrying real visitor IPs.
#   - Content-addressed deduplication. 30 daily snapshots takes ~1.2x the
#     size of one full snapshot, not 30x. So we can keep more history on
#     the same 40 GB disk.
#   - Per-snapshot integrity checks via `restic check`.
#
# Repo lives at $RESTIC_REPO (default: $INSTALL_DIR/backups/restic). Same
# disk as the originals (deliberate — operator chose local-only retention
# for the demo; see Plans/BACKUPS.md residual-risk section).
#
# Password lives at $RESTIC_PASSWORD_FILE (default /etc/restic/mambakkam.password).
# provision.sh generates and prints it once. If lost, the repo is unrecoverable
# (this is a design property of restic, not a bug).
#
# Forget policy:
#   --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 1
#   ≈ 15 snapshots retained, ~30 days of daily resolution + a year of older
#
# Usage (typically via cron):
#   sudo bash /opt/mambakkam/scripts/launch/backup.sh
#
# Exit codes:
#   0 — backup + forget + prune successful
#   1 — restic backup failed
#   2 — restic forget/prune failed
#   3 — repo not initialised (run provision.sh, or `restic init` manually)
#   4 — password file missing or unreadable
# =============================================================================

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/mambakkam}"
BACKUP_DIR="${BACKUP_DIR:-$INSTALL_DIR/backups}"
RESTIC_REPO="${RESTIC_REPO:-$BACKUP_DIR/restic}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/mambakkam.password}"

# Tag this snapshot so `restic snapshots --tag daily` works for forensics.
HOSTNAME_TAG="$(hostname -s)"
SNAPSHOT_TAG="daily"

export RESTIC_REPOSITORY="$RESTIC_REPO"
export RESTIC_PASSWORD_FILE

mkdir -p "$BACKUP_DIR"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# ── Pre-flight ──────────────────────────────────────────────────────────────
if ! command -v restic >/dev/null 2>&1; then
  log "FATAL: restic not installed. Run scripts/launch/provision.sh."
  exit 3
fi

if [[ ! -r "$RESTIC_PASSWORD_FILE" ]]; then
  log "FATAL: $RESTIC_PASSWORD_FILE missing or unreadable. Run provision.sh."
  exit 4
fi

if [[ ! -f "$RESTIC_REPO/config" ]]; then
  log "FATAL: restic repo not initialised at $RESTIC_REPO."
  log "  Run: RESTIC_REPOSITORY=$RESTIC_REPO RESTIC_PASSWORD_FILE=$RESTIC_PASSWORD_FILE restic init"
  exit 3
fi

# ── 1. snapshot ─────────────────────────────────────────────────────────────
log "step 1/3  restic backup → $RESTIC_REPO"

# Build the source list. Skip anything that doesn't exist (e.g. nginx logs
# may not be present on a fresh provision before any traffic has hit).
SOURCES=()
[[ -d "$INSTALL_DIR/src/assets/images" ]] && SOURCES+=("$INSTALL_DIR/src/assets/images")
[[ -f "$INSTALL_DIR/.env.demo" ]] && SOURCES+=("$INSTALL_DIR/.env.demo")
[[ -d /etc/ssl/cloudflare ]] && SOURCES+=(/etc/ssl/cloudflare)

# nginx logs: include the active access/error log + any rotated .gz files
# logrotate has produced. Use a glob via shell.
shopt -s nullglob
for path in /var/log/nginx/mambakkam.net.*; do
  SOURCES+=("$path")
done
shopt -u nullglob

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  log "WARNING: no sources to back up. Aborting."
  exit 1
fi

log "  sources:"
for src in "${SOURCES[@]}"; do log "    - $src"; done

if ! restic backup \
    --tag "$SNAPSHOT_TAG" \
    --tag "host=$HOSTNAME_TAG" \
    --exclude-caches \
    "${SOURCES[@]}"; then
  log "  restic backup FAILED"
  exit 1
fi

log "  backup OK"

# ── 2. forget — apply retention policy ─────────────────────────────────────
log "step 2/3  restic forget — keep 7d / 4w / 3m / 1y"
if ! restic forget \
    --tag "$SNAPSHOT_TAG" \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 3 \
    --keep-yearly 1; then
  log "  restic forget FAILED"
  exit 2
fi

# ── 3. prune — reclaim the disk space the forgotten snapshots used ─────────
# This is the slow step (rewrites the repo's pack files). Run weekly via
# backup-check.sh instead of every day, to keep the daily cron under 2 min.
# Today's daily run only forgets; weekly cron prunes.
#
# Comment out the prune below — backup-check.sh handles it.
# log "step 3/3  restic prune"
# if ! restic prune --max-unused 5%; then
#   log "  restic prune FAILED"
#   exit 2
# fi
log "step 3/3  prune skipped — runs from backup-check.sh on Sundays"

# ── Summary ────────────────────────────────────────────────────────────────
log "current snapshots:"
restic snapshots --compact | tail -10 | sed 's/^/  /'

REPO_SIZE=$(du -sh "$RESTIC_REPO" 2>/dev/null | cut -f1 || echo "?")
log "repo on-disk size: $REPO_SIZE"
log "backup complete."
