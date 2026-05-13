#!/usr/bin/env bash
# Phase 1 Task 1.1 acceptance #4 (Forbidden behavior) + V-ADR-001 V4:
#   feature.yml MUST contain the literal "out of scope" AND at least one of
#   OTA / device management / team collaboration / IoT platform features.
#
# Steers feature-request writers away from out-of-scope asks before they file.
#
# Exit: 0 = both conditions met; 1 = either missing.

set -euo pipefail
cd "$(dirname "$0")/../.."

TARGET=".github/ISSUE_TEMPLATE/feature.yml"
[ -f "$TARGET" ] || { echo "FAIL: $TARGET not found"; exit 1; }

if ! grep -qF "out of scope" "$TARGET"; then
  echo "FAIL: $TARGET missing literal 'out of scope' string (V-ADR-001 V4)"
  exit 1
fi

MISSION_TERMS='OTA|device management|team collaboration|IoT platform features'
if ! grep -qE "$MISSION_TERMS" "$TARGET"; then
  echo "FAIL: $TARGET missing any of: $MISSION_TERMS"
  exit 1
fi

hits=$(grep -oE "$MISSION_TERMS" "$TARGET" | sort -u | tr '\n' ',' | sed 's/,$//')
echo "PASS: feature.yml steers writers — 'out of scope' present + mission terms: $hits"
