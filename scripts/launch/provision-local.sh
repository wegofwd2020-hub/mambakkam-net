#!/usr/bin/env bash
# =============================================================================
# scripts/launch/provision-local.sh — localhost-only test wrapper
#
# Run on a fresh Ubuntu 22/24 VM (as root) when you want to rehearse the
# launch flow without public DNS, without Cloudflare in front, and without
# a real Origin Cert. Wraps provision.sh and bolts on the bits that the
# production script deliberately leaves to the operator.
#
# Idempotent — re-running is safe; finished steps are skipped.
#
# Usage:
#   sudo bash scripts/launch/provision-local.sh
# Or one-liner (curl-pipe; provision.sh will clone the repo for us):
#   curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision-local.sh | bash
#
# What it does on top of provision.sh:
#   1. Runs provision.sh (skipped if state stamp already present)
#   2. Docker DNS preflight: tests whether a container can resolve
#      registry.npmjs.org. If not (common on home-NAT VMs where systemd-
#      resolved doesn't forward into Docker's bridge), writes explicit
#      DNS servers into /etc/docker/daemon.json and restarts Docker.
#   3. Generates a self-signed cert at /etc/ssl/cloudflare/origin-{cert,key}.pem
#      with SAN covering mambakkam.net + www + demo.usestudybuddy.com, so the
#      host nginx vhost loads cleanly
#   4. Adds 127.0.0.1 → mambakkam.net (+ www) to /etc/hosts so curl-based
#      smoke checks can reach the vhost over HTTPS
#   5. nginx -t + systemctl reload nginx
#
# A per-run JSON step log is written to /opt/mambakkam/logs/provision-local-*.json
# (plus a -latest.json symlink); step 1 is the wrapped provision.sh, the
# remaining steps come from this script.
#
# Exit codes:
#   0 — bootstrap complete
#   1 — fatal error (nginx -t failed after cert install — config issue)
#   2 — must be run as root
#   3 — Docker DNS still broken after writing daemon.json
# =============================================================================

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/mambakkam}"
STATE_STAMP="/var/lib/mambakkam/first-tenant-provisioned"
CERT_DIR="/etc/ssl/cloudflare"
CERT_FILE="$CERT_DIR/origin-cert.pem"
KEY_FILE="$CERT_DIR/origin-key.pem"
HOSTS_MARKER="# mambakkam-net local-VM test (provision-local.sh)"
PROVISION_REMOTE_URL="https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision.sh"

# ── Output helpers (match provision.sh) ────────────────────────────────────
bold="\033[1m"; green="\033[0;32m"; yellow="\033[0;33m"; red="\033[0;31m"; reset="\033[0m"
info() { echo -e "${green}[info]${reset}  $*"; }
warn() { echo -e "${yellow}[warn]${reset}  $*"; }
fail() { echo -e "${red}[FAIL]${reset}  $*" >&2; exit 1; }
step() { echo -e "\n${bold}── $* ──${reset}"; }

[[ $EUID -eq 0 ]] || { echo "must be run as root (try: sudo bash $0)"; exit 2; }

# ── 1. provision.sh ─────────────────────────────────────────────────────────
# Done BEFORE sourcing the JSON logger because, on a fresh VM with no repo
# clone yet, _log.sh doesn't exist on disk until provision.sh has cloned it.
# So this step is captured only via exit code, not as a JSON entry. Subsequent
# steps are logged.
step "1/5  provision.sh (full system bootstrap)"
if [[ -f "$STATE_STAMP" ]]; then
  info "state stamp present at $STATE_STAMP — skipping provision.sh"
else
  PROVISION_SH="$INSTALL_DIR/scripts/launch/provision.sh"
  if [[ -x "$PROVISION_SH" ]]; then
    info "running local copy: $PROVISION_SH"
    bash "$PROVISION_SH"
  else
    info "no local copy at $PROVISION_SH — fetching from origin"
    curl -fsSL "$PROVISION_REMOTE_URL" | bash
  fi
fi

# ── Now source the JSON logger (repo is on disk after step 1) ─────────────
LOG_SH="$INSTALL_DIR/scripts/launch/_log.sh"
if [[ -f "$LOG_SH" ]]; then
  # shellcheck source=/opt/mambakkam/scripts/launch/_log.sh
  source "$LOG_SH"
  log_init provision-local
else
  warn "_log.sh not found at $LOG_SH — continuing without JSON step log"
  # No-op shims so the rest of the script doesn't have to guard every call.
  log_step()      { :; }
  log_step_ok()   { :; }
  log_step_fail() { :; }
fi

# ── 2. Docker DNS preflight ────────────────────────────────────────────────
# On the real Hetzner CX22, container DNS works out of the box. On a local
# VM behind home NAT, Docker's bridge often can't reach the host resolver
# and `npm install` (or any container fetch) hangs for 5 min with EAI_AGAIN
# before npm dies in a state where its exit handler can't run. Detect that
# pattern once and write an explicit nameserver list into daemon.json.
step "2/5  Docker DNS preflight"
log_step "Docker DNS preflight"
if ! command -v docker >/dev/null 2>&1; then
  log_step_fail "docker not installed (provision.sh should have installed it)"
  fail "docker not installed — provision.sh must have failed earlier"
fi

# 5s timeout — if DNS is broken, getent will fail fast.
if docker run --rm --entrypoint sh node:lts \
     -c 'getent hosts registry.npmjs.org' >/dev/null 2>&1; then
  info "container DNS works — no daemon.json change needed"
  log_step_ok
else
  warn "container can't resolve registry.npmjs.org — writing /etc/docker/daemon.json"
  DAEMON_JSON=/etc/docker/daemon.json
  if [[ -f "$DAEMON_JSON" ]] && grep -q '"dns"' "$DAEMON_JSON"; then
    info "daemon.json already has a dns entry; leaving in place and restarting docker"
  else
    # Back up any existing daemon.json before overwriting.
    [[ -f "$DAEMON_JSON" ]] && cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%s)"
    cat > "$DAEMON_JSON" <<'EOF'
{
  "dns": ["1.1.1.1", "8.8.8.8"]
}
EOF
    chmod 644 "$DAEMON_JSON"
    info "wrote $DAEMON_JSON with public DNS (1.1.1.1, 8.8.8.8)"
  fi
  systemctl restart docker
  # Re-test; bail if still broken (something deeper than DNS is wrong).
  if docker run --rm --entrypoint sh node:lts \
       -c 'getent hosts registry.npmjs.org' >/dev/null 2>&1; then
    info "container DNS now resolves — proceeding"
    log_step_ok
  else
    log_step_fail "container DNS still broken after writing daemon.json"
    echo "container DNS still broken after daemon.json + docker restart" >&2
    exit 3
  fi
fi

# ── 3. self-signed Origin Cert ─────────────────────────────────────────────
# Real provision.sh stops at "operator pastes the cert". For localhost we
# substitute a self-signed one with the same SAN list so the vhost loads.
# 30 days is plenty for a test run; bump if you keep the VM around longer.
step "3/5  self-signed Origin Cert at $CERT_DIR"
log_step "self-signed Origin Cert"
mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

if [[ -f "$CERT_FILE" ]] && [[ -f "$KEY_FILE" ]]; then
  info "cert + key already present at $CERT_DIR — leaving in place"
  log_step_ok
else
  if ! command -v openssl >/dev/null 2>&1; then
    log_step_fail "openssl not installed"
    fail "openssl not installed (provision.sh should have pulled it via ca-certificates)"
  fi
  if openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
       -keyout "$KEY_FILE" \
       -out    "$CERT_FILE" \
       -subj "/CN=mambakkam.net" \
       -addext "subjectAltName=DNS:mambakkam.net,DNS:www.mambakkam.net,DNS:demo.usestudybuddy.com" \
       >/dev/null 2>&1; then
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    chown root:root "$KEY_FILE" "$CERT_FILE"
    info "generated self-signed cert (30d, SAN: mambakkam.net + www + demo.usestudybuddy.com)"
    log_step_ok
  else
    log_step_fail "openssl req failed generating self-signed cert"
    fail "openssl req failed"
  fi
fi

# ── 4. /etc/hosts entry ────────────────────────────────────────────────────
# So curl https://mambakkam.net/ resolves to the local nginx, not the real
# Cloudflare proxy.
step "4/5  /etc/hosts entry"
log_step "/etc/hosts entry"
if grep -qF "$HOSTS_MARKER" /etc/hosts; then
  info "hosts entry already present — leaving in place"
else
  cat >> /etc/hosts <<EOF
$HOSTS_MARKER
127.0.0.1  mambakkam.net www.mambakkam.net
EOF
  info "added 127.0.0.1 → mambakkam.net (+ www) to /etc/hosts"
fi
log_step_ok

# ── 5. nginx -t + reload ───────────────────────────────────────────────────
step "5/5  nginx -t + reload"
log_step "nginx -t + reload"
NGINX_ERR=$(mktemp)
if nginx -t 2> "$NGINX_ERR"; then
  systemctl reload nginx
  info "nginx reloaded — vhost active on :80 and :443"
  rm -f "$NGINX_ERR"
  log_step_ok
else
  ERR_TAIL=$(tail -5 "$NGINX_ERR" 2>/dev/null)
  cat "$NGINX_ERR" >&2
  rm -f "$NGINX_ERR"
  log_step_fail "nginx -t failed: $ERR_TAIL"
  fail "nginx -t failed even after self-signed cert install — inspect /etc/nginx/sites-enabled/ for unrelated issues"
fi

# ── Done ───────────────────────────────────────────────────────────────────
cat <<EOF

${bold}═════════════════════════════════════════════════════════════════════${reset}
${green}✓ localhost test bootstrap complete${reset}
${bold}═════════════════════════════════════════════════════════════════════${reset}

Next steps (still inside the VM):

1. Deploy:
     sudo -u deploy bash $INSTALL_DIR/scripts/launch/deploy.sh

2. Smoke — container direct (bypasses nginx):
     bash $INSTALL_DIR/scripts/launch/smoke.sh http://127.0.0.1:8081

3. Smoke — through host nginx over HTTPS (self-signed):
     bash $INSTALL_DIR/scripts/launch/smoke.sh -k https://mambakkam.net

4. Optional — exercise the backup script:
     sudo bash $INSTALL_DIR/scripts/launch/backup.sh
     sudo restic -r $INSTALL_DIR/backups/restic \\
       --password-file /etc/restic/mambakkam.password snapshots

JSON step log for this run:
  /opt/mambakkam/logs/provision-local-latest.json

This bootstrap is for local rehearsal only:
  - Self-signed cert is not trusted by any browser
  - /etc/hosts entry overrides DNS for THIS VM only
  - Real Saturday launch still requires the real Cloudflare Origin Cert
    pasted into $CERT_DIR/ and a DNS record in Cloudflare

EOF
