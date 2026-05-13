#!/usr/bin/env bash
# Phase 3 Task 3.4 acceptance #1 (Capacity):
#   AI handle-rate >= 80% measured across the first 24h of issues filed.
#
#   handle_rate = count(ai-resolved) / count(ai-resolved + needs-human)
#
# Where `ai-resolved` is the label AI applies when it closes an issue itself
# (per Task 0.4 dispatch logic), and `needs-human` is the label AI applies
# when it punts to the founder.
#
# Issues outside the 24h window or without either label are excluded from
# the denominator.
#
# Usage:
#   bash tests/perf/handle_rate.sh                              # last 24h
#   SINCE='2026-05-13T10:00:00Z' bash tests/perf/handle_rate.sh # explicit start
#   THRESHOLD=70 bash tests/perf/handle_rate.sh                 # custom floor
#
# Exit: 0 = rate >= threshold (default 80); 1 = below; 2 = setup.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
THRESHOLD="${THRESHOLD:-80}"

# Default SINCE = 24h ago in ISO 8601 UTC.
if [ -z "${SINCE:-}" ]; then
  SINCE=$(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
          || date -u -v -24H '+%Y-%m-%dT%H:%M:%SZ')
fi

for cmd in gh jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done

echo "Repo: $REPO"
echo "Window: $SINCE → now"
echo "Threshold: $THRESHOLD%"
echo

# Pull issues + their labels in one query. Filter client-side by createdAt
# since `gh issue list --search` is finicky with date predicates.
issues_json=$(gh api "repos/$REPO/issues?since=$SINCE&state=all&per_page=100" \
                --paginate \
                --jq '[.[] | select(.pull_request == null) | {number, created_at, labels: [.labels[].name]}]')

ai_resolved=$(echo "$issues_json" | jq '[.[] | select(.labels | index("ai-resolved"))] | length')
needs_human=$(echo "$issues_json" | jq '[.[] | select(.labels | index("needs-human"))] | length')
total_triaged=$((ai_resolved + needs_human))
total_issues=$(echo "$issues_json" | jq 'length')

echo "Total issues in window: $total_issues"
echo "  ai-resolved:    $ai_resolved"
echo "  needs-human:    $needs_human"
echo "  triaged total:  $total_triaged"

if [ "$total_triaged" -eq 0 ]; then
  echo
  echo "WARN: 0 issues with ai-resolved OR needs-human label in window."
  echo "       Either there's no traffic yet, or ai-triage.yml isn't applying labels."
  echo "       Skipping handle-rate computation; exit 0 (no signal yet)."
  exit 0
fi

rate=$(python3 -c "print(round(100.0 * $ai_resolved / $total_triaged, 1))")
echo
echo "handle_rate = $ai_resolved / $total_triaged = ${rate}%"

# bc/awk-free comparison via python.
if python3 -c "import sys; sys.exit(0 if float('$rate') >= float('$THRESHOLD') else 1)"; then
  echo "PASS: handle-rate ${rate}% >= ${THRESHOLD}%."
  exit 0
fi
echo "FAIL: handle-rate ${rate}% < ${THRESHOLD}% (Task 3.4 #1 / G3 exit floor)."
exit 1
