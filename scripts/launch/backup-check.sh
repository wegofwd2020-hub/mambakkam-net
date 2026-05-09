#!/usr/bin/env bash
# =============================================================================
# scripts/launch/backup-check.sh — weekly restic integrity check + prune
#
# Runs from cron at 03:30 UTC on Sundays (one hour after Sunday's daily
# backup at 02:30, so the daily isn't competing for the repo lock).
#
# Two-step routine:
#   1. restic check --read-data-subset 5%
#      Verifies repo metadata + reads 5% of pack files to catch silent
#      bit-rot. Doing 100% would take too long on the daily disk; 5%
#      weekly means we exercise every pack within ~5 months on average.
#   2. restic prune --max-unused 5%
#      Reclaims disk space from snapshots that the daily forget step has
#      marked. Daily backup.sh skips prune to keep its run under 2 min;
#      we do it here weekly instead.
#
# Output streams to /var/log/mambakkam-backup.log via the cron entry, so
# Promtail picks it up alongside the daily-backup output. Loki query:
#   {job="backups", which="mambakkam"} |~ "(?i)check|prune|error"
#
# Exit codes:
#   0 — check + prune successful
#   1 — restic check failed (POSSIBLE BIT-ROT — investigate immediately)
#   2 — restic prune failed
#   3 — repo not initialised
#   4 — password file unreadable
# =============================================================================

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/mambakkam}"
BACKUP_DIR="${BACKUP_DIR:-$INSTALL_DIR/backups}"
RESTIC_REPO="${RESTIC_REPO:-$BACKUP_DIR/restic}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/mambakkam.password}"

export RESTIC_REPOSITORY="$RESTIC_REPO"
export RESTIC_PASSWORD_FILE

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# ── Pre-flight ──────────────────────────────────────────────────────────────
[[ -r "$RESTIC_PASSWORD_FILE" ]] || { log "FATAL: $RESTIC_PASSWORD_FILE unreadable"; exit 4; }
[[ -f "$RESTIC_REPO/config" ]]   || { log "FATAL: repo not at $RESTIC_REPO"; exit 3; }

# ── 1. integrity check ─────────────────────────────────────────────────────
log "step 1/2  restic check --read-data-subset 5%"
if ! restic check --read-data-subset 5%; then
  log "  CHECK FAILED — possible bit-rot or repo corruption."
  log "  Investigate immediately. Recent snapshots may not be restorable."
  log "  Try: restic check --read-data-subset 100%   (slower; full audit)"
  exit 1
fi
log "  check OK"

# ── 2. prune ───────────────────────────────────────────────────────────────
log "step 2/2  restic prune --max-unused 5%"
if ! restic prune --max-unused 5%; then
  log "  prune FAILED"
  exit 2
fi
log "  prune OK"

REPO_SIZE=$(du -sh "$RESTIC_REPO" 2>/dev/null | cut -f1 || echo "?")
log "weekly check complete. repo on-disk size: $REPO_SIZE"
