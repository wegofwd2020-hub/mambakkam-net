#!/usr/bin/env bash
# =============================================================================
# scripts/launch/smoke.sh — post-deploy smoke check for mambakkam.net
#
# Curl-based end-to-end smoke. Run after every deploy (auto-deploy CI calls
# it; operator can run it manually).
#
# Usage:
#   bash scripts/launch/smoke.sh                                # default: 127.0.0.1:8081
#   bash scripts/launch/smoke.sh https://mambakkam.net
#   bash scripts/launch/smoke.sh https://staging.mambakkam.net
#   bash scripts/launch/smoke.sh -k https://mambakkam.net       # tolerate self-signed
#   SMOKE_INSECURE=1 bash scripts/launch/smoke.sh https://...   # env-var equivalent
#
# Flags:
#   -k, --insecure   Pass curl's -k so self-signed / untrusted certs don't
#                    fail the check. Use for local-VM rehearsal where the
#                    Cloudflare Origin Cert is replaced by a self-signed one
#                    (see scripts/launch/provision-local.sh). Equivalent to
#                    setting SMOKE_INSECURE=1.
#
# Exit codes:
#   0 — every check passed
#   1 — at least one check failed; failure summary printed at the end
#
# Checks performed (~5 seconds total):
#   - GET /                            (200 + <title> contains "Mambakkam")
#   - GET /sitemap-index.xml           (200 + <sitemapindex)
#   - GET /people                      (200 + lists at least one person)
#   - GET /people/siva-m               (200 + body mentions "Siva")
#   - GET /landmarks                   (200 + lists at least one landmark)
#   - GET /landmarks/ayyanar-shrine    (200)
#   - GET /work                        (200 + lists at least one work item)
#   - GET /work/studybuddy-ondemand    (200)
#   - GET /this-route-does-not-exist   (404 — proves the 404 page works)
#   - GET /robots.txt                  (200 + does NOT block everything)
# =============================================================================

set -uo pipefail   # not -e: we want to collect failures, not abort on first

# ── Parse flags ────────────────────────────────────────────────────────────
# Accept -k / --insecure in any position; remaining positional arg is BASE_URL.
# SMOKE_INSECURE=1 in the env achieves the same thing — useful for CI.
INSECURE_FLAG=()
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    -k|--insecure) INSECURE_FLAG=(-k) ;;
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    *)             POSITIONAL+=("$arg") ;;
  esac
done
[[ "${SMOKE_INSECURE:-0}" == "1" ]] && INSECURE_FLAG=(-k)

BASE_URL="${POSITIONAL[0]:-http://127.0.0.1:8081}"
BASE_URL="${BASE_URL%/}"   # strip trailing slash

# ── JSON step logger (writes /opt/mambakkam/logs/smoke-*.json) ────────────
source "$(dirname "${BASH_SOURCE[0]}")/_log.sh"
log_init smoke

# ── Output helpers ─────────────────────────────────────────────────────────
bold="\033[1m"; green="\033[0;32m"; yellow="\033[0;33m"; red="\033[0;31m"; reset="\033[0m"
declare -a FAILURES=()

# pass / fail close the currently-open log step. Callers open one with
# log_step "<short step name>" before invoking the check.
pass() { echo -e "  ${green}✓${reset} $1"; log_step_ok; }
fail() { echo -e "  ${red}✗${reset} $1 — $2"; FAILURES+=("$1: $2"); log_step_fail "$2"; }

# Curl wrapper: emits HTTP status code + body to stdout, separated by ::status::.
# Times out after 10 seconds. Follows redirects (we want to test the final page).
http_get() {
  local url="$1"
  curl -sL "${INSECURE_FLAG[@]}" -m 10 -w '::status::%{http_code}' \
    -A 'mambakkam-smoke/1.0' \
    "$url" 2>&1
}

# As above, but does NOT follow redirects (used for 404 + robots).
http_get_noredirect() {
  local url="$1"
  curl -s "${INSECURE_FLAG[@]}" -m 10 -w '::status::%{http_code}' \
    -A 'mambakkam-smoke/1.0' \
    "$url" 2>&1
}

# Use bash parameter expansion, not sed: sed is line-oriented, so any response
# body containing a newline (multi-line meta description, robots.txt, etc.)
# made extract_status return body+code instead of just the code. ${var##*X}
# returns everything after the last X; ${var%X*} returns everything before it.
extract_status() { local s="$1"; printf '%s' "${s##*::status::}"; }
extract_body()   { local s="$1"; printf '%s' "${s%::status::*}"; }

echo ""
echo -e "${bold}=== mambakkam.net smoke check ===${reset}"
echo "    target: $BASE_URL"
if [[ ${#INSECURE_FLAG[@]} -gt 0 ]]; then
  echo -e "    ${yellow}insecure: curl -k (self-signed certs tolerated)${reset}"
fi
echo ""

# ── Home ───────────────────────────────────────────────────────────────────
echo "Home:"
log_step "GET /"
RESP=$(http_get "$BASE_URL/")
STATUS=$(extract_status "$RESP")
BODY=$(extract_body "$RESP")
if [[ "$STATUS" == "200" ]] && echo "$BODY" | grep -qi 'mambakkam'; then
  pass "GET / returns 200 + 'Mambakkam' in body"
else
  fail "GET /" "status=$STATUS"
fi

# ── Sitemap ────────────────────────────────────────────────────────────────
echo ""
echo "Sitemap:"
log_step "GET /sitemap-index.xml"
RESP=$(http_get "$BASE_URL/sitemap-index.xml")
STATUS=$(extract_status "$RESP")
BODY=$(extract_body "$RESP")
if [[ "$STATUS" == "200" ]] && echo "$BODY" | grep -q '<sitemapindex'; then
  pass "GET /sitemap-index.xml returns 200 + <sitemapindex>"
else
  fail "GET /sitemap-index.xml" "status=$STATUS"
fi

# ── People ─────────────────────────────────────────────────────────────────
echo ""
echo "People:"
log_step "GET /people"
RESP=$(http_get "$BASE_URL/people")
STATUS=$(extract_status "$RESP")
BODY=$(extract_body "$RESP")
if [[ "$STATUS" == "200" ]] && echo "$BODY" | grep -qi 'siva'; then
  pass "GET /people lists Siva"
else
  fail "GET /people" "status=$STATUS"
fi

log_step "GET /people/siva-m"
RESP=$(http_get "$BASE_URL/people/siva-m")
STATUS=$(extract_status "$RESP")
BODY=$(extract_body "$RESP")
if [[ "$STATUS" == "200" ]] && echo "$BODY" | grep -qi 'siva'; then
  pass "GET /people/siva-m returns 200 + 'Siva' in body"
else
  fail "GET /people/siva-m" "status=$STATUS"
fi

# ── Landmarks ──────────────────────────────────────────────────────────────
echo ""
echo "Landmarks:"
log_step "GET /landmarks"
RESP=$(http_get "$BASE_URL/landmarks")
STATUS=$(extract_status "$RESP")
if [[ "$STATUS" == "200" ]]; then
  pass "GET /landmarks returns 200"
else
  fail "GET /landmarks" "status=$STATUS"
fi

log_step "GET /landmarks/ayyanar-shrine"
RESP=$(http_get "$BASE_URL/landmarks/ayyanar-shrine")
STATUS=$(extract_status "$RESP")
if [[ "$STATUS" == "200" ]]; then
  pass "GET /landmarks/ayyanar-shrine returns 200"
else
  fail "GET /landmarks/ayyanar-shrine" "status=$STATUS"
fi

# ── Work ───────────────────────────────────────────────────────────────────
echo ""
echo "Work:"
log_step "GET /work"
RESP=$(http_get "$BASE_URL/work")
STATUS=$(extract_status "$RESP")
BODY=$(extract_body "$RESP")
if [[ "$STATUS" == "200" ]] && echo "$BODY" | grep -qi 'studybuddy'; then
  pass "GET /work lists StudyBuddy"
else
  fail "GET /work" "status=$STATUS"
fi

log_step "GET /work/studybuddy-ondemand"
RESP=$(http_get "$BASE_URL/work/studybuddy-ondemand")
STATUS=$(extract_status "$RESP")
if [[ "$STATUS" == "200" ]]; then
  pass "GET /work/studybuddy-ondemand returns 200"
else
  fail "GET /work/studybuddy-ondemand" "status=$STATUS"
fi

# ── 404 handling ───────────────────────────────────────────────────────────
echo ""
echo "404 handling:"
log_step "GET /missing-route (expect 404)"
RESP=$(http_get_noredirect "$BASE_URL/this-route-does-not-exist-$(date +%s)")
STATUS=$(extract_status "$RESP")
if [[ "$STATUS" == "404" ]]; then
  pass "GET /missing-route returns 404 (not 200)"
else
  fail "404 handling" "non-existent route returned status=$STATUS (expected 404)"
fi

# ── robots.txt ─────────────────────────────────────────────────────────────
echo ""
echo "robots.txt:"
log_step "GET /robots.txt"
RESP=$(http_get "$BASE_URL/robots.txt")
STATUS=$(extract_status "$RESP")
BODY=$(extract_body "$RESP")
if [[ "$STATUS" == "200" ]]; then
  if echo "$BODY" | grep -qE '^Disallow:[[:space:]]*/[[:space:]]*$'; then
    fail "robots.txt" "blanket 'Disallow: /' found — would deindex the entire site"
  else
    pass "GET /robots.txt returns 200 + no blanket disallow"
  fi
else
  fail "GET /robots.txt" "status=$STATUS"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo -e "${green}${bold}══ all smoke checks passed ══${reset}"
  exit 0
else
  echo -e "${red}${bold}══ ${#FAILURES[@]} smoke check(s) failed ══${reset}"
  for f in "${FAILURES[@]}"; do
    echo -e "  ${red}•${reset} $f"
  done
  exit 1
fi
