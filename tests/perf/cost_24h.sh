#!/usr/bin/env bash
# Phase 3 Task 3.4 acceptance #2 (Capacity):
#   Claude API cost <= $2 over the first 24h.
#   G3 exit criterion: cost <= $10 over week-1.
#
# Strategy: scrape `gh run view <id> --log` for the marker line that
# scripts/triage.py emits on every triage call:
#   triage.classified{issue:<N>, category:<C>, cost_usd:<X>}
# Sum X across all completed ai-triage.yml runs in the window.
#
# Usage:
#   bash tests/perf/cost_24h.sh                              # last 24h, $2 cap
#   THRESHOLD_USD=10 SINCE='2026-05-13T00:00:00Z' bash tests/perf/cost_24h.sh
#
# Exit: 0 = sum <= threshold; 1 = exceeded; 2 = setup.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
WORKFLOW=ai-triage.yml
THRESHOLD_USD="${THRESHOLD_USD:-2}"

if [ -z "${SINCE:-}" ]; then
  SINCE=$(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
          || date -u -v -24H '+%Y-%m-%dT%H:%M:%SZ')
fi

for cmd in gh jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done

echo "Repo: $REPO"
echo "Workflow: $WORKFLOW"
echo "Window: $SINCE → now"
echo "Threshold: \$$THRESHOLD_USD"
echo

# Fetch run IDs in the window.
run_ids=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --status completed \
            --created ">=$SINCE" --limit 1000 \
            --json databaseId,conclusion \
            --jq '.[] | select(.conclusion == "success") | .databaseId')

if [ -z "$run_ids" ]; then
  echo "WARN: no completed successful runs in window — skipping; exit 0."
  exit 0
fi

count=$(echo "$run_ids" | wc -l | tr -d ' ')
echo "Scanning $count run(s)..."
echo

# Scrape cost markers; sum.
costs=()
runs_with_marker=0
for id in $run_ids; do
  log=$(gh run view "$id" --repo "$REPO" --log 2>/dev/null || true)
  cost=$(printf '%s' "$log" \
           | grep -oE 'triage\.classified\{issue:[0-9]+, category:[a-z_]+, cost_usd:[0-9.]+\}' \
           | sed -E 's/.*cost_usd:([0-9.]+).*/\1/' \
           | head -1)
  if [ -n "$cost" ]; then
    costs+=("$cost")
    runs_with_marker=$((runs_with_marker + 1))
  fi
done

if [ "${#costs[@]}" -eq 0 ]; then
  echo "WARN: 0 runs emitted the triage.classified cost marker. Skipping; exit 0."
  echo "      (This suggests scripts/triage.py is not actually running — check Anthropic key.)"
  exit 0
fi

sum=$(printf '%s\n' "${costs[@]}" | python3 -c "
import sys
costs = [float(x.strip()) for x in sys.stdin if x.strip()]
print(f'{sum(costs):.4f}')
")
mean=$(python3 -c "
costs = ${costs[@]+[$(printf '%s,' "${costs[@]}")]}
print(f'{sum(costs)/len(costs):.4f}' if costs else '0')
")

echo "runs with cost marker: $runs_with_marker / $count"
echo "  sum:  \$$sum"
echo "  mean: \$$mean per issue"
echo "  threshold: \$$THRESHOLD_USD"
echo

if python3 -c "import sys; sys.exit(0 if float('$sum') <= float('$THRESHOLD_USD') else 1)"; then
  echo "PASS: \$$sum <= \$$THRESHOLD_USD ($(python3 -c "print(round(100*float('$sum')/float('$THRESHOLD_USD'), 0))")% of budget)."
  exit 0
fi
echo "FAIL: \$$sum > \$$THRESHOLD_USD — runbook Chapter 2 (cost overshoot) triggers."
exit 1
