#!/usr/bin/env bash
# Idempotently provisions the 30-label taxonomy on the live GitHub repo.
#
# Reads tests/fixtures/labels_expected.json (source of truth) and runs
# `gh label create --force` for each entry. --force makes this idempotent:
# pre-existing labels get their color/description updated; new ones are
# created.
#
# Usage:
#   ./scripts/setup-labels.sh             # default REPO=esphome-cloud/community
#   REPO=my-org/my-repo ./scripts/setup-labels.sh
#   ./scripts/setup-labels.sh --dry-run   # show what would happen, no API calls
#
# Exit: 0 = all 30 applied; non-zero = at least one failure.

set -euo pipefail

cd "$(dirname "$0")/.."

REPO="${REPO:-esphome-cloud/community}"
FIXTURE=tests/fixtures/labels_expected.json
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

for cmd in gh jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 1; }
done
[ -f "$FIXTURE" ] || { echo "FAIL: fixture $FIXTURE not found"; exit 1; }

total=$(jq '.labels | length' "$FIXTURE")
echo "Applying $total labels to $REPO (dry-run=$DRY_RUN)"
echo

ok=0
failed=0
i=0

# Iterate via a TSV: name\tcolor\tdescription (tabs are safe; no label name contains tab).
while IFS=$'\t' read -r name color desc; do
  i=$((i + 1))
  printf '[%2d/%d] %-30s ' "$i" "$total" "$name"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "(would gh label create --force, color=$color)"
    ok=$((ok + 1))
    continue
  fi

  if gh label create "$name" \
       --color "$color" \
       --description "$desc" \
       --repo "$REPO" \
       --force >/dev/null 2>&1; then
    echo "ok"
    ok=$((ok + 1))
  else
    echo "FAILED"
    failed=$((failed + 1))
  fi
done < <(jq -r '.labels[] | [.name, .color, .description] | @tsv' "$FIXTURE")

echo
if [ "$failed" -gt 0 ]; then
  echo "FAIL: $failed/$total label(s) failed to apply. Check gh auth (gh auth status) and repo perms."
  exit 1
fi

echo "PASS: $ok/$total labels applied to $REPO."
echo "Verify with: bash tests/repo/labels.sh"
