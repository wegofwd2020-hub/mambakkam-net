# =============================================================================
# scripts/launch/_log.sh — shared JSON step logger for the launch scripts
#
# Sourced (not executed) by deploy.sh, provision-local.sh, smoke.sh. Writes
# one JSON file per script run to $LOG_DIR (default /opt/mambakkam/logs/),
# named <script>-<UTC-timestamp>.json, plus a <script>-latest.json symlink
# that always points at the most recent run.
#
# Each step is logged with name + status (Success | Error) + started_at +
# finished_at + duration_ms. Errors include the error message.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/_log.sh"
#   log_init deploy
#   log_step "git fetch + reset"
#   ... do work ...
#   log_step_ok                          # marks the current step Success
#   log_step "docker compose up"
#   ... do work that might fail ...
#   if ! some_command; then
#     log_step_fail "compose up failed: $(some_command 2>&1 | tail -3)"
#     exit 2
#   fi
#   log_step_ok
#
# An EXIT trap auto-finalizes any unclosed step (e.g. if the script aborts
# from set -e or an explicit exit without log_step_ok/fail). The JSON file
# is always written, regardless of how the script exits.
#
# JSON shape:
#   {
#     "script": "deploy",
#     "host": "studybuddy",
#     "started_at": "2026-05-15T14:28:54Z",
#     "finished_at": "2026-05-15T14:30:12Z",
#     "duration_ms": 78123,
#     "exit_code": 0,
#     "steps": [
#       {"name":"git fetch + reset","status":"Success",
#        "started_at":"...","finished_at":"...","duration_ms":2103},
#       {"name":"docker compose up","status":"Error","error":"...",
#        "started_at":"...","finished_at":"...","duration_ms":76020}
#     ]
#   }
# =============================================================================

# Don't allow this file to be executed directly — it's a library.
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  echo "_log.sh is a library; source it, don't run it." >&2
  exit 64
fi

LOG_DIR="${LOG_DIR:-/opt/mambakkam/logs}"

# Internal state — prefixed with __ so callers don't accidentally clobber.
__LOG_SCRIPT=""
__LOG_FILE=""
__LOG_LATEST=""
__LOG_STARTED_AT=""
__LOG_STARTED_MS=""
__LOG_STEPS=()
__LOG_CUR_NAME=""
__LOG_CUR_STARTED_AT=""
__LOG_CUR_STARTED_MS=""

# ── time helpers ──────────────────────────────────────────────────────────
# date +%s%3N is GNU coreutils; Ubuntu 22/24 ships it. macOS would need gdate.
__log_iso()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
__log_ms()   { date +%s%3N; }

# ── JSON string escaping ──────────────────────────────────────────────────
# Use jq if available (provision.sh installs it); fall back to bash so the
# logger still works if invoked before jq is on the box.
__log_json_str() {
  local s="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$s" | jq -Rsa .
  else
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "$s"
  fi
}

# ── public API ────────────────────────────────────────────────────────────

# log_init <script-name>
#   Set up the log file path and install the EXIT trap.
log_init() {
  __LOG_SCRIPT="${1:-unknown}"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  local ts
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  __LOG_FILE="$LOG_DIR/${__LOG_SCRIPT}-${ts}.json"
  __LOG_LATEST="$LOG_DIR/${__LOG_SCRIPT}-latest.json"
  __LOG_STARTED_AT=$(__log_iso)
  __LOG_STARTED_MS=$(__log_ms)
  __LOG_STEPS=()
  # Chain onto any existing EXIT trap rather than blowing it away.
  local prev
  prev=$(trap -p EXIT | sed -E "s/^trap -- '(.*)' EXIT$/\1/")
  if [[ -n "$prev" ]]; then
    trap "__log_finalize; $prev" EXIT
  else
    trap '__log_finalize' EXIT
  fi
}

# log_step <name>
#   Begin a new step. Auto-finalizes any open step as Success.
log_step() {
  if [[ -n "$__LOG_CUR_NAME" ]]; then
    log_step_ok
  fi
  __LOG_CUR_NAME="$1"
  __LOG_CUR_STARTED_AT=$(__log_iso)
  __LOG_CUR_STARTED_MS=$(__log_ms)
}

# log_step_ok
#   Mark the current step as Success.
log_step_ok() {
  [[ -z "$__LOG_CUR_NAME" ]] && return 0
  local finished_at finished_ms dur
  finished_at=$(__log_iso)
  finished_ms=$(__log_ms)
  dur=$((finished_ms - __LOG_CUR_STARTED_MS))
  __LOG_STEPS+=(
    "$(printf '{"name":%s,"status":"Success","started_at":"%s","finished_at":"%s","duration_ms":%d}' \
      "$(__log_json_str "$__LOG_CUR_NAME")" \
      "$__LOG_CUR_STARTED_AT" "$finished_at" "$dur")"
  )
  __LOG_CUR_NAME=""
}

# log_step_fail <error-message>
#   Mark the current step as Error and record the message.
log_step_fail() {
  [[ -z "$__LOG_CUR_NAME" ]] && return 0
  local err="${1:-unknown error}"
  local finished_at finished_ms dur
  finished_at=$(__log_iso)
  finished_ms=$(__log_ms)
  dur=$((finished_ms - __LOG_CUR_STARTED_MS))
  __LOG_STEPS+=(
    "$(printf '{"name":%s,"status":"Error","error":%s,"started_at":"%s","finished_at":"%s","duration_ms":%d}' \
      "$(__log_json_str "$__LOG_CUR_NAME")" \
      "$(__log_json_str "$err")" \
      "$__LOG_CUR_STARTED_AT" "$finished_at" "$dur")"
  )
  __LOG_CUR_NAME=""
}

# ── internal: EXIT trap that writes the JSON file ─────────────────────────
__log_finalize() {
  local exit_code=$?
  # Don't run twice if the trap chain fires more than once.
  [[ -z "$__LOG_FILE" ]] && return 0
  # Catch the case where the script exited mid-step (e.g. uncaught error).
  if [[ -n "$__LOG_CUR_NAME" ]]; then
    log_step_fail "script exited (code=$exit_code) before step finished"
  fi
  local finished_at finished_ms total_dur host steps_csv
  finished_at=$(__log_iso)
  finished_ms=$(__log_ms)
  total_dur=$((finished_ms - __LOG_STARTED_MS))
  host=$(hostname -s 2>/dev/null || echo unknown)
  local IFS=,
  steps_csv="${__LOG_STEPS[*]}"

  # Write atomically: tmp + mv. Keeps tail-followers from seeing a half file.
  local tmp="$__LOG_FILE.tmp"
  printf '{"script":%s,"host":%s,"started_at":"%s","finished_at":"%s","duration_ms":%d,"exit_code":%d,"steps":[%s]}\n' \
    "$(__log_json_str "$__LOG_SCRIPT")" \
    "$(__log_json_str "$host")" \
    "$__LOG_STARTED_AT" "$finished_at" "$total_dur" "$exit_code" \
    "$steps_csv" > "$tmp" 2>/dev/null
  mv "$tmp" "$__LOG_FILE" 2>/dev/null
  ln -sfn "$__LOG_FILE" "$__LOG_LATEST" 2>/dev/null

  # Don't blow up the caller's exit code.
  __LOG_FILE=""
  return 0
}
