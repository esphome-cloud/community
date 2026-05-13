#!/usr/bin/env bash
# Phase 1 Task 1.4 acceptance #2 (Function):
#   SLA matrix is consistent across three surfaces:
#     1. policies/sla-policy.md (canonical)
#     2. README.md "Response Times" section
#     3. tests/fixtures/email_autoreplies/*.txt
#
# We check the consistency at the LEVEL of key promises (per-channel SLA
# windows + the 24h security anchor) rather than byte-equal markdown tables,
# because each surface formats slightly differently. The promises that MUST
# appear identically:
#
#   - security@: "24 hours"
#   - feedback@/Discussions/Issues/hello@: "Tuesday 14:00-16:00 UTC+8" or
#     "Tuesday during office hours"
#   - support@: "Mon-Fri 09:00-18:00 UTC+8" (BETA: not public)
#
# Exit: 0 = all three surfaces align; 1 = drift detected.

set -euo pipefail
cd "$(dirname "$0")/../.."

POLICY="policies/sla-policy.md"
README="README.md"
AUTOREPLY_DIR="tests/fixtures/email_autoreplies"

for p in "$POLICY" "$README"; do
  [ -f "$p" ] || { echo "FAIL: $p not found"; exit 1; }
done

fails=0
report() {
  local label="$1" file="$2" pattern="$3"
  if grep -qE "$pattern" "$file"; then
    echo "  [ok] $label in $file"
  else
    echo "  [FAIL] $label NOT in $file (pattern: $pattern)"
    fails=$((fails + 1))
  fi
}

echo "--- security@ — 24 hours (every day) ---"
report "24-hour SLA"     "$POLICY"  '24 hours'
report "24-hour SLA"     "$README"  '24 hours'
report "24-hour SLA"     "$AUTOREPLY_DIR/security.txt" '24 hours'

echo
echo "--- public channels — Tuesday office hours 14-16 UTC+8 ---"
report "office hours window"  "$POLICY"  '14:00-16:00 UTC\+8'
report "office hours window"  "$README"  '14:00-16:00 UTC\+8'
report "office hours window"  "$AUTOREPLY_DIR/feedback.txt" '14:00-16:00 UTC\+8'
report "office hours window"  "$AUTOREPLY_DIR/hello.txt"    '14:00-16:00 UTC\+8'

echo
echo "--- support@ — Mon-Fri 09-18 (BETA: not public) ---"
report "Mon-Fri 09:00-18:00 UTC+8"  "$POLICY"  'Mon-Fri 09:00-18:00 UTC\+8'
report "Mon-Fri 09:00-18:00 UTC+8"  "$AUTOREPLY_DIR/support.txt" 'Mon-Fri 09:00-18:00 UTC\+8'

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails consistency check(s) drifted across surfaces."
  echo "Fix the matrix at the canonical source first ($POLICY), then propagate."
  exit 1
fi
echo "PASS: SLA matrix consistent across $POLICY + $README + $AUTOREPLY_DIR/*.txt."
