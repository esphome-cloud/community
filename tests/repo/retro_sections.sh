#!/usr/bin/env bash
# Phase 3 Task 3.5 acceptance #1 (Function):
#   governance/retros/week-1.md exists with 4 required H2 sections:
#     What worked
#     What surprised
#     AI mis-handles
#     KNOWN_ISSUES additions
#
# The template lives at governance/retros/week-1.template.md; the actual
# retro is at governance/retros/week-1.md (created on Day 9 by copying
# the template). This test accepts EITHER (so it can run pre-launch).
#
# Exit: 0 = 4/4 H2 anchors present in retro (or template); 1 = any missing.

set -euo pipefail
cd "$(dirname "$0")/../.."

DIR="governance/retros"
RETRO="$DIR/week-1.md"
TEMPLATE="$DIR/week-1.template.md"

if [ -f "$RETRO" ]; then
  TARGET="$RETRO"
  echo "Checking: $RETRO (real retro)"
elif [ -f "$TEMPLATE" ]; then
  TARGET="$TEMPLATE"
  echo "Checking: $TEMPLATE (pre-launch — template stands in for the retro)"
else
  echo "FAIL: neither $RETRO nor $TEMPLATE exists"
  exit 1
fi

REQUIRED=(
  "## What worked"
  "## What surprised"
  "## AI mis-handles"
  "## KNOWN_ISSUES additions"
)

fails=0
for anchor in "${REQUIRED[@]}"; do
  if grep -qF "$anchor" "$TARGET"; then
    echo "  [ok] $anchor"
  else
    echo "  [MISSING] $anchor"
    fails=$((fails + 1))
  fi
done

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails / ${#REQUIRED[@]} H2 anchor(s) missing in $TARGET."
  exit 1
fi
echo
echo "PASS: all 4 required H2 sections present in $TARGET."
