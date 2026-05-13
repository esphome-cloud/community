#!/usr/bin/env bash
# Phase 3 Task 3.1 acceptance #4 (Forbidden behavior):
#   Out-of-scope section MUST list all 4 pillars by name.
#
# Pillars (literal substring, case-sensitive):
#   OTA
#   device management
#   team collaboration
#   IoT platform features

set -euo pipefail
cd "$(dirname "$0")/../.."

DOC="policies/mission-scope-policy.md"
[ -f "$DOC" ] || { echo "FAIL: $DOC not found"; exit 1; }

PILLARS=("OTA" "device management" "team collaboration" "IoT platform features")
fails=0

for pillar in "${PILLARS[@]}"; do
  n=$(grep -cF "$pillar" "$DOC")
  if [ "$n" -lt 1 ]; then
    echo "  [MISSING] $pillar"
    fails=$((fails + 1))
  else
    echo "  [ok]      $pillar ($n hit$([ "$n" -gt 1 ] && echo 's'))"
  fi
done

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails out-of-scope pillar(s) missing from $DOC."
  exit 1
fi
echo "PASS: all 4 out-of-scope pillars present in $DOC."
