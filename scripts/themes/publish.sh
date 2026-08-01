#!/usr/bin/env bash
# scripts/themes/publish.sh — commit and open a PR for theme reassignments.
#
# The /themes editor writes `theme:` into src/data/work/*.md. This turns that
# working-copy change into a branch, a commit and a pull request, so the edit
# reaches production the same way every other change does.
#
# It deliberately stops at opening the PR. Merging deploys mambakkam.net
# immediately, and that stays a human decision.
#
# Usage:
#   npm run theme:publish
#   npm run theme:publish -- --dry-run
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

cd "$(dirname "$0")/../.."

# Only ever touch the work collection. A theme edit cannot legitimately change
# anything else, and staging more would let unrelated work ride along unseen.
mapfile -t CHANGED < <(git diff --name-only -- src/data/work/ ; git diff --cached --name-only -- src/data/work/)
mapfile -t CHANGED < <(printf '%s\n' "${CHANGED[@]:-}" | grep -v '^$' | sort -u)

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  echo "No changes under src/data/work/ — nothing to publish."
  exit 0
fi

echo "Theme changes to publish:"
for f in "${CHANGED[@]}"; do
  slug="$(basename "$f" .md)"
  theme="$(grep -m1 '^theme:' "$f" 2>/dev/null | sed 's/theme: *//' || true)"
  printf '  %-26s theme: %s\n' "$slug" "${theme:-— none —}"
done
echo

# Refuse to bundle unrelated edits: this script's whole promise is that the PR
# contains theme assignments and nothing else.
OTHER="$(git status --porcelain | grep -v ' src/data/work/' | grep -E '^( M|M |A |\?\?)' || true)"
if [[ -n "$OTHER" ]]; then
  echo "Refusing to publish — other changes are present:"
  echo "$OTHER" | sed 's/^/  /'
  echo
  echo "Commit or stash them first, so this PR carries theme changes alone."
  exit 1
fi

BRANCH="chore/theme-assignments-$(git rev-parse --short HEAD)"
SUMMARY="$(for f in "${CHANGED[@]}"; do
  slug="$(basename "$f" .md)"
  theme="$(grep -m1 '^theme:' "$f" 2>/dev/null | sed 's/theme: *//' || true)"
  printf -- '- %s: %s\n' "$slug" "${theme:-none}"
done)"

if $DRY_RUN; then
  echo "--dry-run: would create branch $BRANCH and commit:"
  echo "$SUMMARY" | sed 's/^/  /'
  exit 0
fi

git switch -c "$BRANCH" >/dev/null 2>&1 || git switch "$BRANCH"
git add -- src/data/work/
git commit -q -m "chore(themes): update theme assignments

$SUMMARY

Made through the /themes editor in dev, which rewrites the theme: field
in the work collection. The value is validated against the registry at
build time — themeById() throws on an unknown id — so a bad assignment
fails CI rather than rendering a page in the wrong palette."

git push -u origin "$BRANCH" -q
echo "Pushed $BRANCH"

if command -v gh >/dev/null; then
  gh pr create --title "chore(themes): update theme assignments" --body "Theme assignments changed through the \`/themes\` editor.

$SUMMARY

The value is validated against the registry at build time — \`themeById()\` throws on an unknown id — so a bad assignment fails CI rather than rendering a page in the wrong palette.

Merging deploys mambakkam.net."
else
  echo "gh not found — open the PR manually for $BRANCH."
fi
