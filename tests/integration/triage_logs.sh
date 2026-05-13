#!/usr/bin/env bash
# Phase 0 Task 0.4 acceptance #4 (Observability):
#   Every triage run emits to stderr a line matching
#     triage.classified{issue:<N>, category:<C>, cost_usd:<X>}
#   100% of 30 dummy runs must emit this marker.
#
# Strategy: open 30 dummy issues against the live repo, wait for each to be
# triaged by ai-triage.yml, fetch the workflow log, grep for the marker.
# A run is a pass if the marker appears at least once in its log AND the
# issue.number embedded in the marker matches the dummy issue we just opened.
#
# Usage:
#   ./tests/integration/triage_logs.sh
#   REPO=my-org/my-repo TRIALS=10 ./tests/integration/triage_logs.sh
#   ./tests/integration/triage_logs.sh --keep
#
# Exit: 0 = 100% trials emitted the marker; 1 = any miss; 2 = setup error.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
TRIALS="${TRIALS:-30}"
TIMEOUT_S=240
POLL_S=5
WORKFLOW=ai-triage.yml
KEEP=0

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

for cmd in gh jq date awk; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done

nonce="$(date '+%Y%m%d-%H%M%S')-$RANDOM"
echo "Run nonce: $nonce; repo=$REPO; trials=$TRIALS"
echo

created_issues=()
pass=0
fail=0
miss_details=()

cleanup() {
  if [ "$KEEP" -eq 1 ] || [ "${#created_issues[@]}" -eq 0 ]; then return; fi
  echo
  echo "Closing ${#created_issues[@]} dummy issue(s)..."
  for n in "${created_issues[@]}"; do
    gh issue close "$n" --repo "$REPO" --reason "not planned" \
      --comment "Auto-close: Task 0.4 triage_logs.sh dummy (nonce=$nonce)." >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

run_one() {
  local n="$1"
  local title="[Bug]: triage_logs smoke ${nonce} trial-${n}"
  local body
  body=$(printf 'Triage log marker smoke (Task 0.4 acceptance #4).\n\nnonce=%s\ntrial=%s/%s\n' "$nonce" "$n" "$TRIALS")

  local start_iso
  start_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  local url num
  url=$(gh issue create --repo "$REPO" --title "$title" --body "$body" --label needs-triage 2>/dev/null)
  num=$(printf '%s' "$url" | awk -F/ '{print $NF}')
  [ -n "$num" ] || { echo "  trial $n: FAIL - could not create issue"; return 1; }
  created_issues+=("$num")
  echo "  trial $n: created issue #$num"

  local run_id="" elapsed=0
  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    sleep "$POLL_S"; elapsed=$((elapsed + POLL_S))
    run_id=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --event issues \
              --created ">=$start_iso" --limit 20 \
              --json databaseId,displayTitle \
              | jq -r --arg t "$title" '.[] | select(.displayTitle | contains($t)) | .databaseId' \
              | head -1)
    [ -n "$run_id" ] && break
  done
  [ -n "$run_id" ] || { echo "  trial $n: FAIL - no workflow run within ${TIMEOUT_S}s"; return 1; }

  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    local status
    status=$(gh run view "$run_id" --repo "$REPO" --json status -q .status 2>/dev/null || echo "")
    [ "$status" = "completed" ] && break
    sleep "$POLL_S"; elapsed=$((elapsed + POLL_S))
  done

  local log
  log=$(gh run view "$run_id" --repo "$REPO" --log 2>/dev/null || true)
  if echo "$log" | grep -qE "triage\.classified\{issue:${num}, category:[a-z_]+, cost_usd:[0-9.]+\}"; then
    echo "  trial $n: PASS - marker found for issue #$num"
    return 0
  fi
  if echo "$log" | grep -qF 'triage.classified{issue:'; then
    echo "  trial $n: FAIL - marker present but issue number mismatch (expected $num)"
  else
    echo "  trial $n: FAIL - no 'triage.classified{issue:' marker in run log"
  fi
  miss_details+=("issue=$num run=$run_id")
  return 1
}

for n in $(seq 1 "$TRIALS"); do
  if run_one "$n"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done

echo
echo "Summary: $pass / $TRIALS passed (target 100%)."
if [ "$fail" -gt 0 ]; then
  echo "Misses:"
  printf '  - %s\n' "${miss_details[@]}"
  echo
  echo "FAIL: Task 0.4 observability acceptance requires 100% (every run emits the marker)."
  exit 1
fi
echo "PASS: every triage run emitted the 'triage.classified{issue:...}' log line."
