#!/usr/bin/env bash
# =============================================================================
# scripts/launch/provision.sh — first-tenant bootstrap for the shared CX22
#
# Run on a fresh Hetzner CX22 (as root). mambakkam.net is the FIRST tenant
# on the box, so this script performs the full system bootstrap. StudyBuddy
# joins later as a second tenant via its own (shorter) provision.sh, which
# expects the artefacts produced here to already be in place.
#
# Idempotent — re-running is safe; finished steps are skipped.
#
# Usage (one-liner from a fresh shell):
#   curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/mambakkam-net/main/scripts/launch/provision.sh | bash
#
# Or, if you've already cloned the repo:
#   sudo bash scripts/launch/provision.sh
#
# What it does:
#   1.  apt update + upgrade + base system packages (incl. restic)
#   2.  UFW firewall (allow ssh / 80 / 443) + fail2ban
#   3.  Docker CE + Compose plugin (Docker's official apt repo)
#   4.  Host nginx (apt) + cron + rsync
#   5.  /opt/mambakkam + git clone
#   6.  .env.demo skeleton from .env.demo.example
#   7.  deploy system user (passwordless sudo restricted to docker compose +
#       git pull + nginx reload). Reused by StudyBuddy's second-tenant
#       provision — that's why we install the user up-front.
#   8.  Host nginx vhost (infra/nginx/mambakkam.net.conf → sites-enabled)
#   9.  /etc/ssl/cloudflare/ (operator pastes Origin Cert with SAN list
#       covering mambakkam.net + demo.studybuddy.app)
#   10. cron — daily restic backup (02:30 UTC) + weekly check (Sun 03:30)
#   11. backup directory
#   12. restic password generation + repo init at /opt/mambakkam/backups/restic/
#       (PRINTS PASSWORD ONCE — operator must record it; lost = unrecoverable)
#   13. State stamp at /var/lib/mambakkam/first-tenant-provisioned
#   14. Monitoring stack scaffold (.env.monitoring template + Prometheus
#       compose stack — operator brings it up after pasting Grafana Cloud creds)
#
# Exit codes:
#   0 — provisioning complete (or already done)
#   1 — fatal error
#   2 — must be run as root
# =============================================================================

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/wegofwd2020-hub/mambakkam-net.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/mambakkam}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"

# ── Output helpers ─────────────────────────────────────────────────────────
bold="\033[1m"; green="\033[0;32m"; yellow="\033[0;33m"; red="\033[0;31m"; reset="\033[0m"
info() { echo -e "${green}[info]${reset}  $*"; }
warn() { echo -e "${yellow}[warn]${reset}  $*"; }
fail() { echo -e "${red}[FAIL]${reset}  $*" >&2; exit 1; }
step() { echo -e "\n${bold}── $* ──${reset}"; }

[[ $EUID -eq 0 ]] || { echo "must be run as root (try: sudo bash $0)"; exit 2; }

# ── 1. apt update + upgrade + base packages ────────────────────────────────
step "1/14  apt update + upgrade + base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  ca-certificates curl gnupg lsb-release \
  git rsync cron jq unzip restic
info "base packages installed (incl. restic for encrypted backups)"

# ── 2. UFW + fail2ban ───────────────────────────────────────────────────────
step "2/14  UFW firewall + fail2ban"
apt-get install -y ufw fail2ban
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status verbose

systemctl enable --now fail2ban
info "ufw + fail2ban configured (StudyBuddy second-tenant provision will inherit these)"

# ── 3. Docker CE + Compose plugin ───────────────────────────────────────────
step "3/14  Docker CE + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  info "docker installed: $(docker --version)"
else
  info "docker already present: $(docker --version)"
fi

# ── 4. Host nginx ───────────────────────────────────────────────────────────
step "4/14  host nginx"
apt-get install -y nginx
info "host nginx installed (single :80 + :443 entry point for both tenants)"

# ── 5. /opt/mambakkam + git clone ──────────────────────────────────────────
step "5/14  $INSTALL_DIR  +  git clone"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
if [[ -d .git ]]; then
  info "repo already cloned at $INSTALL_DIR — running git fetch + reset"
  git fetch origin "$REPO_BRANCH"
  git reset --hard "origin/$REPO_BRANCH"
else
  git clone --branch "$REPO_BRANCH" --depth 50 "$REPO_URL" .
  info "cloned $REPO_URL @ $REPO_BRANCH"
fi

# ── 6. .env.demo skeleton ──────────────────────────────────────────────────
step "6/14  .env.demo skeleton"
ENV_FILE="$INSTALL_DIR/.env.demo"
if [[ -f "$ENV_FILE" ]]; then
  warn ".env.demo already exists — leaving in place (not overwriting)"
elif [[ -f "$INSTALL_DIR/.env.demo.example" ]]; then
  cp "$INSTALL_DIR/.env.demo.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  info "wrote $ENV_FILE from .env.demo.example (mode 600). Edit before deploying."
else
  warn ".env.demo.example not found — skipping skeleton creation"
fi

# ── 7. deploy user (StudyBuddy second-tenant provision will reuse this) ────
step "7/14  deploy user + docker group + restricted sudo"
if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$DEPLOY_USER"
  info "created user: $DEPLOY_USER"
else
  info "user $DEPLOY_USER already exists"
fi
usermod -aG docker "$DEPLOY_USER"

# Add a sudoers entry scoped to /opt/mambakkam if not already broader
SUDO_FILE="/etc/sudoers.d/mambakkam-deploy"
if [[ ! -f "$SUDO_FILE" ]]; then
  cat > "$SUDO_FILE" <<EOF
# Allow $DEPLOY_USER to run docker compose + git operations from $INSTALL_DIR
# without a password. Restricts sudo to compose + git pull so an auto-deploy
# CI job can't accidentally do anything else.
$DEPLOY_USER ALL=(root) NOPASSWD: /usr/bin/docker compose *, /usr/bin/git -C $INSTALL_DIR *, /usr/bin/systemctl reload nginx, /usr/sbin/nginx -t
EOF
  chmod 440 "$SUDO_FILE"
  visudo -cf "$SUDO_FILE" >/dev/null
  info "deploy-user sudo policy installed at $SUDO_FILE"
else
  info "sudoers entry $SUDO_FILE already exists — leaving in place"
fi

# Ensure authorized_keys placeholder exists (StudyBuddy may have created it)
mkdir -p "/home/$DEPLOY_USER/.ssh"
chmod 700 "/home/$DEPLOY_USER/.ssh"
touch "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"

# Repo ownership: deploy user needs to git pull
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$INSTALL_DIR"

# ── 8. host nginx vhost ────────────────────────────────────────────────────
step "8/14  host nginx vhost"
VHOST_SRC="$INSTALL_DIR/infra/nginx/mambakkam.net.conf"
VHOST_AVAIL="/etc/nginx/sites-available/mambakkam.net.conf"
VHOST_ENABLED="/etc/nginx/sites-enabled/mambakkam.net.conf"

if [[ ! -f "$VHOST_SRC" ]]; then
  fail "vhost source $VHOST_SRC not found — repo state is broken"
fi

cp "$VHOST_SRC" "$VHOST_AVAIL"
info "copied vhost → $VHOST_AVAIL"

# Disable the default catch-all vhost (Ubuntu nginx ships one; it would shadow ours)
if [[ -L /etc/nginx/sites-enabled/default ]]; then
  rm /etc/nginx/sites-enabled/default
  info "removed default nginx vhost symlink"
fi

# Enable our vhost
ln -sf "$VHOST_AVAIL" "$VHOST_ENABLED"
info "enabled vhost via symlink"

# Validate config; if it fails (e.g. cert missing), keep going so the operator
# can fix the cert and reload manually.
if nginx -t 2>/dev/null; then
  systemctl reload nginx
  info "nginx -t green; nginx reloaded"
else
  warn "nginx -t failed (likely missing Origin Cert at /etc/ssl/cloudflare/) — fix and run: systemctl reload nginx"
fi

# ── 9. Cloudflare Origin Cert dir ──────────────────────────────────────────
step "9/14  Cloudflare Origin Cert directory"
mkdir -p /etc/ssl/cloudflare
chmod 700 /etc/ssl/cloudflare
if [[ -f /etc/ssl/cloudflare/origin-cert.pem ]] && [[ -f /etc/ssl/cloudflare/origin-key.pem ]]; then
  info "Origin Cert + key already present at /etc/ssl/cloudflare/"
else
  warn "Origin Cert NOT yet installed — paste cert + key into:"
  warn "  /etc/ssl/cloudflare/origin-cert.pem"
  warn "  /etc/ssl/cloudflare/origin-key.pem"
  warn "Cert SAN MUST include all of:"
  warn "  - mambakkam.net"
  warn "  - *.mambakkam.net"
  warn "  - demo.studybuddy.app   (StudyBuddy will join this box on Day 0 (Sun May 17))"
  warn "Generating with the StudyBuddy SAN now avoids a re-issue when the"
  warn "second tenant joins."
fi

# ── 10. cron — daily backup at 02:30 UTC ───────────────────────────────────
step "10/14  cron — daily backup at 02:30 UTC"
CRON_FILE="/etc/cron.d/mambakkam-backup"
cat > "$CRON_FILE" <<EOF
# mambakkam.net backup cron — generated by provision.sh
#
# Two entries:
#   - DAILY at 02:30 UTC: restic backup (snapshot + forget; no prune)
#     Offset 30 min after StudyBuddy's 02:00 to avoid disk I/O collision.
#   - WEEKLY Sunday at 03:30 UTC: restic check + prune
#     Catches silent bit-rot via random 5% pack read; reclaims disk space
#     from forgets that the daily skips.
#
# Both append to /var/log/mambakkam-backup.log so Promtail (Loki) picks up
# both events under the same {job="backups", which="mambakkam"} stream.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

30 2 * * *   root cd $INSTALL_DIR && bash scripts/launch/backup.sh       >> /var/log/mambakkam-backup.log 2>&1
30 3 * * 0   root cd $INSTALL_DIR && bash scripts/launch/backup-check.sh >> /var/log/mambakkam-backup.log 2>&1
EOF
chmod 644 "$CRON_FILE"
service cron reload
info "cron entry installed at $CRON_FILE"

# ── 11. backup directory ───────────────────────────────────────────────────
step "11/14  backup directory"
mkdir -p "$INSTALL_DIR/backups"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$INSTALL_DIR/backups"
info "backups dir ready at $INSTALL_DIR/backups"

# ── 12. restic — encrypted backup repository ──────────────────────────────
# mambakkam.net is the first tenant: this script generates the password
# AND initialises the repo so the daily-backup cron from step 10 can succeed
# on its first run (otherwise the cron would error out for ~24h until the
# operator notices). StudyBuddy's second-tenant provision.sh does the same
# for /opt/studybuddy/backups/restic/ — separate repo, separate password.
step "12/14  restic password + repo init"

RESTIC_PWD_DIR="/etc/restic"
RESTIC_PWD_FILE="$RESTIC_PWD_DIR/mambakkam.password"
RESTIC_REPO_PATH="$INSTALL_DIR/backups/restic"

mkdir -p "$RESTIC_PWD_DIR"
chmod 700 "$RESTIC_PWD_DIR"

if [[ -f "$RESTIC_PWD_FILE" ]]; then
  info "restic password already exists at $RESTIC_PWD_FILE — leaving in place"
  RESTIC_PWD_NEW=0
else
  # 32 bytes of urandom → 64 hex chars. ~256 bits of entropy.
  openssl rand -hex 32 > "$RESTIC_PWD_FILE"
  chmod 600 "$RESTIC_PWD_FILE"
  chown root:root "$RESTIC_PWD_FILE"
  info "generated restic password at $RESTIC_PWD_FILE (mode 600 root:root)"
  RESTIC_PWD_NEW=1
fi

# Initialise the repo if it doesn't exist yet.
if [[ -f "$RESTIC_REPO_PATH/config" ]]; then
  info "restic repo already initialised at $RESTIC_REPO_PATH"
else
  mkdir -p "$RESTIC_REPO_PATH"
  if RESTIC_REPOSITORY="$RESTIC_REPO_PATH" \
     RESTIC_PASSWORD_FILE="$RESTIC_PWD_FILE" \
     restic init >/dev/null; then
    info "restic repo initialised at $RESTIC_REPO_PATH"
  else
    fail "restic init failed — check $RESTIC_REPO_PATH permissions"
  fi
fi

# ── 13. final state stamp ──────────────────────────────────────────────────
step "13/14  state stamp"
# Drop a marker file so StudyBuddy's second-tenant provision can hard-fail
# fast if the operator runs them in the wrong order.
STATE_DIR="/var/lib/mambakkam"
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/first-tenant-provisioned" <<EOF
# This box has been bootstrapped by mambakkam.net first-tenant provision.sh.
# StudyBuddy_OnDemand's second-tenant scripts/demo/provision.sh checks for
# this marker and aborts if it's missing (to prevent silent skip of the
# system bootstrap steps).
provisioned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
provisioned_by=mambakkam-net/scripts/launch/provision.sh
deploy_user=$DEPLOY_USER
install_dir=$INSTALL_DIR
EOF
chmod 644 "$STATE_DIR/first-tenant-provisioned"
info "state stamp written to $STATE_DIR/first-tenant-provisioned"

# ── 14. monitoring scaffold (Prometheus + remote_write to Grafana Cloud) ──
step "14/14  monitoring scaffold (.env.monitoring template)"
MON_DIR="$INSTALL_DIR/infra/monitoring"
MON_ENV="$MON_DIR/.env.monitoring"

if [[ ! -d "$MON_DIR" ]]; then
  warn "monitoring directory $MON_DIR not found in repo — skipping. Update the"
  warn "repo and re-run if you want the Prometheus + Grafana Cloud stack."
elif [[ -f "$MON_ENV" ]]; then
  info ".env.monitoring already present — leaving in place"
else
  cat > "$MON_ENV" <<'MON_ENV_EOF'
# =============================================================================
# infra/monitoring/.env.monitoring — generated by provision.sh
#
# Replace every <PLACEHOLDER> with a real value from Grafana Cloud, then
# bring the monitoring stack up:
#   cd /opt/mambakkam/infra/monitoring
#   docker compose --env-file .env.monitoring up -d
#
# How to obtain each value (Grafana Cloud free tier — no card required):
#
#   1. Sign up at https://grafana.com/auth/sign-up/create-user
#   2. Create a stack. Note the numeric stack ID — that's
#      GRAFANA_CLOUD_USERNAME below.
#   3. Stack → Connections → Hosted Prometheus metrics → "Send Metrics"
#      Copy the URL value (e.g. https://prometheus-prod-XX-prod-YY.grafana.net/api/prom/push)
#      → that's GRAFANA_CLOUD_REMOTE_WRITE_URL
#   4. Same Connections page → Hosted Logs (Loki) → "Send Logs"
#      Copy the URL value (e.g. https://logs-prod-NN-prod-YY.grafana.net)
#      and the numeric Loki user
#      → those are GRAFANA_CLOUD_LOKI_URL and GRAFANA_CLOUD_LOKI_USERNAME
#   5. Stack → Access policies → Create access policy
#      Scope: MetricsPublisher + LogsWriter (one token covers both)
#      → that's GRAFANA_CLOUD_API_KEY
#   6. STUDYBUDDY_METRICS_TOKEN matches METRICS_TOKEN in
#      /opt/studybuddy/.env.demo. Copy it from there (after StudyBuddy has
#      been provisioned as the second tenant).
# =============================================================================

# ── Metrics → Grafana Cloud Prometheus ─────────────────────────────────────
GRAFANA_CLOUD_REMOTE_WRITE_URL=https://prometheus-prod-XX-prod-YY.grafana.net/api/prom/push
GRAFANA_CLOUD_USERNAME=<your-numeric-prom-stack-id>

# ── Logs → Grafana Cloud Loki ──────────────────────────────────────────────
# Note: Loki has its own numeric user ID, separate from the Prometheus one.
GRAFANA_CLOUD_LOKI_URL=https://logs-prod-NN-prod-YY.grafana.net
GRAFANA_CLOUD_LOKI_USERNAME=<your-numeric-loki-stack-id>

# ── Shared Cloud Access Policy token (scoped: MetricsPublisher + LogsWriter)
GRAFANA_CLOUD_API_KEY=<cloud-access-policy-token>

# ── StudyBuddy /metrics scrape token ───────────────────────────────────────
STUDYBUDDY_METRICS_TOKEN=<copy-from-/opt/studybuddy/.env.demo-METRICS_TOKEN-line-after-2nd-tenant-provisioning>
MON_ENV_EOF
  chmod 600 "$MON_ENV"
  chown "$DEPLOY_USER:$DEPLOY_USER" "$MON_ENV"
  info "wrote $MON_ENV (mode 600). Edit before bringing the stack up."
fi

# Don't auto-start the monitoring stack — placeholder secrets would fail
# Prometheus startup. Operator brings it up after editing .env.monitoring.

# ── Final checklist ─────────────────────────────────────────────────────────
PUBLIC_IP="$(curl -s ifconfig.me 2>/dev/null || echo "<this-vps-public-ip>")"
cat <<EOF

${bold}═════════════════════════════════════════════════════════════════════${reset}
${green}✓ mambakkam.net first-tenant provisioning complete${reset}
${bold}═════════════════════════════════════════════════════════════════════${reset}
EOF

# ── Print restic password ONCE if it was newly generated ───────────────────
# Lost passwords = unrecoverable backups (restic's encryption is real, no
# master key escrow). Operator must record this before going further.
if [[ "${RESTIC_PWD_NEW:-0}" -eq 1 ]]; then
  cat <<EOF

${red}${bold}╔═══════════════════════════════════════════════════════════════════╗${reset}
${red}${bold}║  IMPORTANT — RESTIC BACKUP PASSWORD (shown once, write it down)   ║${reset}
${red}${bold}╚═══════════════════════════════════════════════════════════════════╝${reset}

This password unlocks /opt/mambakkam/backups/restic/. Without it, every
snapshot in that repo is permanently unrecoverable. Restic encryption is
real — there is no escrow mechanism, no Anthropic, no Hetzner, no
operator can recover it for you. Save it to a password manager NOW.

${bold}Password:${reset}  $(cat "$RESTIC_PWD_FILE")

A copy is on disk at: $RESTIC_PWD_FILE  (mode 600 root)

If the disk dies, the on-disk copy dies with it. The password manager
copy is your sole guarantee that off-box recovery (e.g. from a Hetzner
volume snapshot) can decrypt the repo.

EOF
fi

cat <<EOF

Next steps (in order):

1. Edit $ENV_FILE
   - Fill in any analytics ID (Plausible / GA4) — Zoho SMTP placeholders
     can stay as-is until a contact form ships.

2. Generate + install the Cloudflare Origin Cert at:
   /etc/ssl/cloudflare/origin-cert.pem
   /etc/ssl/cloudflare/origin-key.pem
   SAN list MUST include all of:
     - mambakkam.net
     - *.mambakkam.net
     - demo.studybuddy.app   (StudyBuddy joins this box on Day 0 (Sun May 17))

3. Paste the GitHub Actions deploy SSH public key into:
   /home/$DEPLOY_USER/.ssh/authorized_keys
   (the matching private key goes into repo secret MAMBAKKAM_VPS_SSH_KEY)
   This key is APPEND-ONLY — StudyBuddy's second-tenant provision will
   add its own deploy key alongside this one.

4. Build + start the mambakkam container:
   sudo -u $DEPLOY_USER bash $INSTALL_DIR/scripts/launch/deploy.sh

5. Smoke-check locally (before DNS cutover):
   bash $INSTALL_DIR/scripts/launch/smoke.sh http://127.0.0.1:8081

6. Configure Cloudflare DNS:
   mambakkam.net  →  $PUBLIC_IP   (Proxied, orange cloud)

7. Public-side smoke:
   bash $INSTALL_DIR/scripts/launch/smoke.sh https://mambakkam.net

When all 7 steps are green, mambakkam.net is live.

────────────────────────────────────────────────────────────────────
8. (Optional, can defer) Bring up the monitoring stack — Prometheus
   ships data to Grafana Cloud free tier; no local Grafana to host:

     # First, edit Grafana Cloud creds + StudyBuddy token:
     vi $INSTALL_DIR/infra/monitoring/.env.monitoring

     # Bring up Prometheus + nginx-exporter + blackbox-exporter + node-exporter:
     cd $INSTALL_DIR/infra/monitoring
     docker compose --env-file .env.monitoring up -d

     # Verify:
     curl -s http://127.0.0.1:9090/-/ready    # → "Prometheus is Ready."
     docker compose ps                         # all 4 containers Up

   Dashboards live at https://<your-stack>.grafana.net (Grafana Cloud UI).
   Import the StudyBuddy starter dashboard JSON from
   $INSTALL_DIR/infra/monitoring/dashboards/ if you've added one.

   Skip this step at first cutover if you want to launch fast and add
   observability after T+0; provisioning has scaffolded everything.
────────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────────
Then, when ready to join StudyBuddy as the second tenant on Day 0 (Sun May 17):

  curl -fsSL https://raw.githubusercontent.com/wegofwd2020-hub/StudyBuddy_OnDemand/main/scripts/demo/provision.sh | bash

That script does NOT re-run any of the system-bootstrap steps above
(Docker, UFW, fail2ban, deploy user, host nginx, /etc/ssl/cloudflare/).
It only adds the StudyBuddy-specific repo, .env.demo, host-nginx vhost,
and 02:00 UTC backup cron. State stamp at /var/lib/mambakkam/first-
tenant-provisioned tells it whether this script ran first.
────────────────────────────────────────────────────────────────────

EOF
