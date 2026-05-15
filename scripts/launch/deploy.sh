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

# ── JSON step logger (writes /opt/mambakkam/logs/deploy-*.json) ───────────
source "$(dirname "${BASH_SOURCE[0]}")/_log.sh"
log_init deploy

cd "$INSTALL_DIR"

# ── 1. git pull ─────────────────────────────────────────────────────────────
log_step "git fetch + reset --hard origin/main"
log "1/4  git fetch + reset --hard origin/main"
GIT_ERR=$(mktemp)
if sudo git -C "$INSTALL_DIR" fetch origin main 2> "$GIT_ERR" && \
   sudo git -C "$INSTALL_DIR" reset --hard origin/main 2>> "$GIT_ERR"; then
  HEAD_SHA="$(git -C "$INSTALL_DIR" rev-parse --short HEAD)"
  ok "now at $HEAD_SHA"
  rm -f "$GIT_ERR"
  log_step_ok
else
  err "git pull failed"
  log_step_fail "git fetch/reset failed: $(tail -5 "$GIT_ERR" 2>/dev/null)"
  rm -f "$GIT_ERR"
  exit 1
fi

# ── 2. docker compose up ────────────────────────────────────────────────────
log_step "docker compose build + up -d"
log "2/4  docker compose build + up -d"
COMPOSE_ERR=$(mktemp)
if sudo docker compose \
     -f "$INSTALL_DIR/docker-compose.demo.yml" \
     --env-file "$ENV_FILE" \
     up -d --build --remove-orphans 2> >(tee "$COMPOSE_ERR" >&2); then
  ok "compose up -d succeeded"
  rm -f "$COMPOSE_ERR"
  log_step_ok
else
  err "compose up -d failed"
  log_step_fail "compose up failed: $(tail -10 "$COMPOSE_ERR" 2>/dev/null)"
  rm -f "$COMPOSE_ERR"
  exit 2
fi

# ── 3. wait for healthcheck ────────────────────────────────────────────────
log_step "healthcheck settle (15s)"
log "3/4  waiting 15s for healthcheck to settle"
sleep 15

# Print compose ps for the deploy log
sudo docker compose \
  -f "$INSTALL_DIR/docker-compose.demo.yml" \
  --env-file "$ENV_FILE" \
  ps
log_step_ok

# ── 4. local smoke ──────────────────────────────────────────────────────────
log_step "local smoke ($LOCAL_URL)"
log "4/4  local smoke ($LOCAL_URL)"
if bash "$INSTALL_DIR/scripts/launch/smoke.sh" "$LOCAL_URL"; then
  ok "local smoke passed"
  log_step_ok
else
  err "local smoke failed — container is up but not serving correctly"
  log_step_fail "smoke.sh exited non-zero (see smoke-latest.json for per-check detail)"
  exit 3
fi

log "deploy complete (HEAD=$HEAD_SHA)"
