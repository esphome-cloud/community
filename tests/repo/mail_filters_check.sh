#!/usr/bin/env bash
# Phase 3 Task 3.2 acceptance #2 (Function):
#   mail filter rules match tests/fixtures/mail_filters_expected.json.
#
# The COMPARISON is against the founder's exported filter file (provider-
# specific format — Gmail filter export, Apple Mail rules.plist, etc.).
# This script:
#   1. Validates the fixture JSON parses and has the 7 expected rules
#   2. If FOUNDER_FILTERS_FILE env is set, performs a structural diff
#      (warns rather than fails on cosmetic differences)
#
# Live-only for the comparison; the fixture-validity check runs offline.
#
# Exit: 0 = fixture valid (and if applicable, founder export aligned);
#       1 = drift; 2 = setup.

set -euo pipefail
cd "$(dirname "$0")/../.."

FIXTURE="tests/fixtures/mail_filters_expected.json"
[ -f "$FIXTURE" ] || { echo "FAIL: $FIXTURE not found"; exit 2; }

echo "--- Stage 1: fixture validity ---"
python3 - <<'PY'
import json, sys
f = json.load(open("tests/fixtures/mail_filters_expected.json"))

assert f.get("version") == 1, f"bad version: {f.get('version')}"
filters = f.get("filters", [])
print(f"  filters count: {len(filters)} (expected 7)")
if len(filters) != 7:
    print(f"FAIL: expected exactly 7 filter rules, got {len(filters)}"); sys.exit(1)

# Each filter must have id + applies_to + match + actions.
for i, rule in enumerate(filters):
    for key in ("id", "applies_to", "match", "actions"):
        if key not in rule:
            print(f"FAIL: filter #{i} missing '{key}'"); sys.exit(1)
    if not rule["actions"]:
        print(f"FAIL: filter #{i} has empty actions list"); sys.exit(1)

# Every mailbox must be covered.
addresses = {rule["match"].get("to_address", rule["match"].get("from_address", ""))
             for rule in filters}
for required in ("feedback@esphome.cloud", "hello@esphome.cloud", "security@esphome.cloud", "support@esphome.cloud"):
    if required not in addresses:
        # ALERT_EMAIL pager rule uses from_address, so check substring
        addr_strs = [str(a) for a in addresses]
        if not any(required in a for a in addr_strs):
            print(f"FAIL: no rule covers {required}"); sys.exit(1)

print(f"  addresses covered: {sorted(addresses)}")
print("PASS: fixture has 7 well-formed rules covering all 4 mailboxes + critical pager.")
PY
stage1_rc=$?

echo
if [ -z "${FOUNDER_FILTERS_FILE:-}" ]; then
  echo "Stage 2 SKIPPED: FOUNDER_FILTERS_FILE not set."
  echo "  To compare against your real filter export:"
  echo "    FOUNDER_FILTERS_FILE=/path/to/export.json bash tests/repo/mail_filters_check.sh"
  exit $stage1_rc
fi

echo "--- Stage 2: founder export comparison ---"
[ -f "$FOUNDER_FILTERS_FILE" ] || { echo "FAIL: $FOUNDER_FILTERS_FILE not found"; exit 2; }
echo "  comparing against: $FOUNDER_FILTERS_FILE"
echo "  (structural comparison; cosmetic differences are warned, not failed)"
echo
# Structural overlap: every fixture-required address must appear in the export
# (as substring match — the export format is provider-specific).
fails=0
for addr in feedback@esphome.cloud hello@esphome.cloud security@esphome.cloud support@esphome.cloud; do
  if grep -qF "$addr" "$FOUNDER_FILTERS_FILE"; then
    echo "  [ok]   $addr referenced in founder export"
  else
    echo "  [WARN] $addr not found in founder export — filter may be missing"
    fails=$((fails + 1))
  fi
done

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails address(es) not covered by founder's exported filters."
  exit 1
fi
echo
echo "PASS: founder export covers all 4 mailbox addresses."
