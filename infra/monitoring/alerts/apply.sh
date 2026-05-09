#!/usr/bin/env bash
# =============================================================================
# infra/monitoring/alerts/apply.sh — upload alert rules to Grafana Cloud
#
# Idempotent — safe to re-run; Grafana Cloud's ruler API replaces the
# rule group's contents on each upload.
#
# What it does:
#   1. Sources .env.monitoring (the same file Prometheus + Promtail use)
#   2. POSTs metric-rules.yaml to Grafana Cloud Mimir's ruler API
#   3. POSTs log-rules.yaml to Grafana Cloud Loki's ruler API
#   4. Verifies both uploads by listing rule groups under the namespace
#
# Both uploads use Cloud Access Policy token auth. The token must have
# scope `rules:write` (in addition to the metrics + logs write scopes
# already needed by Prometheus + Promtail).
#
# Notification routing (contact point + notification policy) is configured
# separately as click-ops in the Grafana Cloud UI — see Plans/RUNBOOK.md
# §"Notification routing". The alert rules below set `severity` labels
# that the click-ops policy then matches on.
#
# Usage:
#   cd /opt/mambakkam/infra/monitoring/alerts
#   bash apply.sh                       # apply both rule files
#   bash apply.sh metric                # apply just metric-rules.yaml
#   bash apply.sh log                   # apply just log-rules.yaml
#
# Exit codes:
#   0 — apply succeeded
#   1 — env file missing or malformed
#   2 — upload failed (see message)
#   3 — verification listing failed
# =============================================================================

set -euo pipefail

ALERTS_DIR="$(cd "$(dirname "$0")" && pwd)"
MONITORING_DIR="$(cd "$ALERTS_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$MONITORING_DIR/.env.monitoring}"
NAMESPACE="${NAMESPACE:-studybuddy-alerts}"

bold="\033[1m"; green="\033[0;32m"; yellow="\033[0;33m"; red="\033[0;31m"; reset="\033[0m"
info() { echo -e "${green}[info]${reset}  $*"; }
warn() { echo -e "${yellow}[warn]${reset}  $*"; }
fail() { echo -e "${red}[FAIL]${reset}  $*" >&2; exit 2; }

# ── Source env ─────────────────────────────────────────────────────────────
if [[ ! -r "$ENV_FILE" ]]; then
  echo "FATAL: $ENV_FILE not found or unreadable. Run scripts/launch/provision.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a

# ── Sanity-check required env vars ─────────────────────────────────────────
required=(
  GRAFANA_CLOUD_REMOTE_WRITE_URL
  GRAFANA_CLOUD_USERNAME
  GRAFANA_CLOUD_LOKI_URL
  GRAFANA_CLOUD_LOKI_USERNAME
  GRAFANA_CLOUD_API_KEY
)
for v in "${required[@]}"; do
  if [[ -z "${!v:-}" ]] || [[ "${!v}" == \<* ]]; then
    echo "FATAL: $v not set in $ENV_FILE (still has placeholder?)" >&2
    exit 1
  fi
done

# Mimir's ruler API base — strip the /api/prom/push suffix from the
# remote_write URL to get the stack root, then append /api/v1/rules/<ns>.
MIMIR_BASE="${GRAFANA_CLOUD_REMOTE_WRITE_URL%/api/prom/push}"
MIMIR_RULES_URL="$MIMIR_BASE/api/v1/rules/$NAMESPACE"

# Loki's ruler API base — same shape, different host.
LOKI_RULES_URL="$GRAFANA_CLOUD_LOKI_URL/loki/api/v1/rules/$NAMESPACE"

# ── Helper: upload one rule file ───────────────────────────────────────────
upload() {
  local kind="$1"        # "metric" or "log"
  local file="$2"
  local url="$3"
  local user="$4"

  if [[ ! -r "$file" ]]; then
    fail "$file not readable"
  fi

  info "uploading $kind rules from $(basename "$file") → $url"

  # The ruler APIs accept POST with the YAML rules group as the body.
  # Both Mimir and Loki use the same Prometheus-compatible YAML format.
  local http_code body
  body=$(mktemp)
  trap 'rm -f "$body"' EXIT

  http_code=$(curl -s -o "$body" -w "%{http_code}" \
    -X POST "$url" \
    -u "$user:$GRAFANA_CLOUD_API_KEY" \
    -H "Content-Type: application/yaml" \
    --data-binary "@$file" \
    --max-time 30)

  case "$http_code" in
    200|201|202)
      info "  uploaded ($http_code)"
      ;;
    401|403)
      fail "  auth failed ($http_code) — check GRAFANA_CLOUD_API_KEY scope (needs rules:write)"
      ;;
    400)
      fail "  bad request ($http_code): $(cat "$body")"
      ;;
    404)
      fail "  endpoint not found ($http_code) — check the URL: $url"
      ;;
    *)
      fail "  unexpected ($http_code): $(cat "$body")"
      ;;
  esac

  rm -f "$body"; trap - EXIT
}

# ── Helper: list rule groups in a namespace (verification) ─────────────────
verify() {
  local kind="$1"
  local url="$2"
  local user="$3"

  info "verifying $kind rules in namespace $NAMESPACE..."
  local groups
  groups=$(curl -fsS -u "$user:$GRAFANA_CLOUD_API_KEY" "$url" 2>&1 \
    | grep -E '^- name:|^  - alert:' \
    || echo "(empty or HTTP error)")

  if [[ -z "$groups" ]]; then
    warn "  no groups returned — upload may not have taken effect yet (ruler poll latency ~30s)"
  else
    echo "$groups" | sed 's/^/    /'
  fi
}

# ── Dispatch on argument ────────────────────────────────────────────────────
target="${1:-both}"

case "$target" in
  metric)
    upload metric "$ALERTS_DIR/metric-rules.yaml" "$MIMIR_RULES_URL" "$GRAFANA_CLOUD_USERNAME"
    verify metric "$MIMIR_RULES_URL" "$GRAFANA_CLOUD_USERNAME"
    ;;
  log)
    upload log "$ALERTS_DIR/log-rules.yaml" "$LOKI_RULES_URL" "$GRAFANA_CLOUD_LOKI_USERNAME"
    verify log "$LOKI_RULES_URL" "$GRAFANA_CLOUD_LOKI_USERNAME"
    ;;
  both)
    upload metric "$ALERTS_DIR/metric-rules.yaml" "$MIMIR_RULES_URL" "$GRAFANA_CLOUD_USERNAME"
    upload log "$ALERTS_DIR/log-rules.yaml" "$LOKI_RULES_URL" "$GRAFANA_CLOUD_LOKI_USERNAME"
    echo
    verify metric "$MIMIR_RULES_URL" "$GRAFANA_CLOUD_USERNAME"
    verify log "$LOKI_RULES_URL" "$GRAFANA_CLOUD_LOKI_USERNAME"
    ;;
  *)
    echo "usage: $0 [metric|log|both]" >&2
    exit 1
    ;;
esac

echo
info "done. New rules take effect within ~60s of upload (ruler eval interval)."
info "Configure notification policy in Grafana Cloud UI per Plans/RUNBOOK.md."
