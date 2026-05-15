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
#   2. Generates a self-signed cert at /etc/ssl/cloudflare/origin-{cert,key}.pem
#      with SAN covering mambakkam.net + www + demo.studybuddy.app, so the
#      host nginx vhost loads cleanly
#   3. Adds 127.0.0.1 → mambakkam.net (+ www) to /etc/hosts so curl-based
#      smoke checks can reach the vhost over HTTPS
#   4. nginx -t + systemctl reload nginx
#
# Exit codes:
#   0 — bootstrap complete
#   1 — fatal error (nginx -t failed after cert install — config issue)
#   2 — must be run as root
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
step "1/4  provision.sh (full system bootstrap)"
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

# ── 2. self-signed Origin Cert ─────────────────────────────────────────────
# Real provision.sh stops at "operator pastes the cert". For localhost we
# substitute a self-signed one with the same SAN list so the vhost loads.
# 30 days is plenty for a test run; bump if you keep the VM around longer.
step "2/4  self-signed Origin Cert at $CERT_DIR"
mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

if [[ -f "$CERT_FILE" ]] && [[ -f "$KEY_FILE" ]]; then
  info "cert + key already present at $CERT_DIR — leaving in place"
else
  if ! command -v openssl >/dev/null 2>&1; then
    fail "openssl not installed (provision.sh should have pulled it via ca-certificates)"
  fi
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
    -keyout "$KEY_FILE" \
    -out    "$CERT_FILE" \
    -subj "/CN=mambakkam.net" \
    -addext "subjectAltName=DNS:mambakkam.net,DNS:www.mambakkam.net,DNS:demo.studybuddy.app" \
    >/dev/null 2>&1
  chmod 600 "$KEY_FILE"
  chmod 644 "$CERT_FILE"
  chown root:root "$KEY_FILE" "$CERT_FILE"
  info "generated self-signed cert (30d, SAN: mambakkam.net + www + demo.studybuddy.app)"
fi

# ── 3. /etc/hosts entry ────────────────────────────────────────────────────
# So curl https://mambakkam.net/ resolves to the local nginx, not the real
# Cloudflare proxy.
step "3/4  /etc/hosts entry"
if grep -qF "$HOSTS_MARKER" /etc/hosts; then
  info "hosts entry already present — leaving in place"
else
  cat >> /etc/hosts <<EOF
$HOSTS_MARKER
127.0.0.1  mambakkam.net www.mambakkam.net
EOF
  info "added 127.0.0.1 → mambakkam.net (+ www) to /etc/hosts"
fi

# ── 4. nginx -t + reload ───────────────────────────────────────────────────
step "4/4  nginx -t + reload"
if nginx -t; then
  systemctl reload nginx
  info "nginx reloaded — vhost active on :80 and :443"
else
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

This bootstrap is for local rehearsal only:
  - Self-signed cert is not trusted by any browser
  - /etc/hosts entry overrides DNS for THIS VM only
  - Real Saturday launch still requires the real Cloudflare Origin Cert
    pasted into $CERT_DIR/ and a DNS record in Cloudflare

EOF
