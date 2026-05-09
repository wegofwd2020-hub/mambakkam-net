#!/usr/bin/env bash
# =============================================================================
# scripts/launch/deploy.sh — pull, rebuild, restart, smoke
#
# Run on the Hetzner VPS (as the `deploy` user). Called by:
#   - .github/workflows/deploy-mambakkam.yml on every push to main
#   - the operator manually for a forced redeploy
#
# Usage:
#   sudo -u deploy bash /opt/mambakkam/scripts/launch/deploy.sh
#
# Exit codes:
#   0 — deploy + smoke green
#   1 — git pull failed
#   2 — docker compose build/up failed
#   3 — local smoke check failed (container is up but not serving correctly)
# =============================================================================

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/mambakkam}"
ENV_FILE="${ENV_FILE:-$INSTALL_DIR/.env.demo}"
LOCAL_URL="${LOCAL_URL:-http://127.0.0.1:8081}"

# ── Output helpers ─────────────────────────────────────────────────────────
bold="\033[1m"; green="\033[0;32m"; red="\033[0;31m"; reset="\033[0m"
log() { echo -e "${bold}[$(date -u +%H:%M:%S)]${reset} $*"; }
ok()  { echo -e "  ${green}✓${reset} $*"; }
err() { echo -e "  ${red}✗${reset} $*" >&2; }

cd "$INSTALL_DIR"

# ── 1. git pull ─────────────────────────────────────────────────────────────
log "1/4  git fetch + reset --hard origin/main"
if sudo git -C "$INSTALL_DIR" fetch origin main && \
   sudo git -C "$INSTALL_DIR" reset --hard origin/main; then
  HEAD_SHA="$(git -C "$INSTALL_DIR" rev-parse --short HEAD)"
  ok "now at $HEAD_SHA"
else
  err "git pull failed"
  exit 1
fi

# ── 2. docker compose up ────────────────────────────────────────────────────
log "2/4  docker compose build + up -d"
if sudo docker compose \
     -f "$INSTALL_DIR/docker-compose.demo.yml" \
     --env-file "$ENV_FILE" \
     up -d --build --remove-orphans; then
  ok "compose up -d succeeded"
else
  err "compose up -d failed"
  exit 2
fi

# ── 3. wait for healthcheck ────────────────────────────────────────────────
log "3/4  waiting 15s for healthcheck to settle"
sleep 15

# Print compose ps for the deploy log
sudo docker compose \
  -f "$INSTALL_DIR/docker-compose.demo.yml" \
  --env-file "$ENV_FILE" \
  ps

# ── 4. local smoke ──────────────────────────────────────────────────────────
log "4/4  local smoke ($LOCAL_URL)"
if bash "$INSTALL_DIR/scripts/launch/smoke.sh" "$LOCAL_URL"; then
  ok "local smoke passed"
else
  err "local smoke failed — container is up but not serving correctly"
  exit 3
fi

log "deploy complete (HEAD=$HEAD_SHA)"
