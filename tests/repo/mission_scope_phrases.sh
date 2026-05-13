#!/usr/bin/env bash
# Phase 3 Task 3.1 acceptance #2 (Function):
#   mission-scope-policy.md contains the literal phrases
#     "In scope:" (>=1 hit)
#     "Out of scope:" (>=1 hit)
#
# These are the section-header anchors the AI triage prompt + the issue
# template's mission reminder reference.

set -euo pipefail
cd "$(dirname "$0")/../.."

DOC="policies/mission-scope-policy.md"
[ -f "$DOC" ] || { echo "FAIL: $DOC not found"; exit 1; }

fails=0
for anchor in "In scope:" "Out of scope:"; do
  n=$(grep -cF "$anchor" "$DOC")
  if [ "$n" -lt 1 ]; then
    echo "  [FAIL] '$anchor' has $n hits (expected >=1)"
    fails=$((fails + 1))
  else
    echo "  [ok]   '$anchor' has $n hit(s)"
  fi
done

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails section-header anchor(s) missing in $DOC."
  exit 1
fi
echo "PASS: mission-scope-policy.md has both 'In scope:' and 'Out of scope:' anchors."
