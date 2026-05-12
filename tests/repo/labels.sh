#!/usr/bin/env bash
# Verifies the live GitHub repo's label set matches tests/fixtures/labels_expected.json.
#
# Default repo: esphome-cloud/community (override with REPO env var).
# Acceptance criterion: >=30 labels, every expected name present.
#
# Requires: gh CLI authenticated; jq.
# Exit: 0 = pass; 1 = missing label(s) or mismatch.

set -euo pipefail

cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
FIXTURE=tests/fixtures/labels_expected.json

for cmd in gh jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 1; }
done
[ -f "$FIXTURE" ] || { echo "FAIL: fixture $FIXTURE not found"; exit 1; }

# Pull live labels (gh paginates automatically with --limit 100).
live=$(gh label list --repo "$REPO" --limit 100 --json name,color,description)
live_count=$(echo "$live" | jq 'length')

# Expected names + counts from the fixture.
expected_count=$(jq '.labels | length' "$FIXTURE")
expected_names=()
while IFS= read -r n; do expected_names+=("$n"); done < <(jq -r '.labels[].name' "$FIXTURE")

if [ "$live_count" -lt "$expected_count" ]; then
  echo "FAIL: live repo has $live_count labels; expected >=$expected_count."
  exit 1
fi

missing=()
for name in "${expected_names[@]}"; do
  if ! echo "$live" | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null; then
    missing+=("$name")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "FAIL: ${#missing[@]} expected label(s) missing on $REPO:"
  printf '  - %s\n' "${missing[@]}"
  echo
  echo "Run: ./scripts/setup-labels.sh"
  exit 1
fi

echo "PASS: all $expected_count expected labels present on $REPO ($live_count live labels total)."
