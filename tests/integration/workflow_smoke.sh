#!/usr/bin/env bash
# Task 0.3 acceptance smoke: open 5 dummy issues, verify the ai-triage.yml
# workflow runs to completion (status=completed, conclusion=success) and
# its log contains the literal string "python ok", within a 120s window.
#
# Acceptance per phase-0-foundation.md Task 0.3:
#   - 5 trials, 5/5 success required
#   - p95 round-trip <90s (this script uses a 120s ceiling per trial)
#   - log contains "python ok" (the step name)
#
# Usage:
#   ./tests/integration/workflow_smoke.sh             # REPO=esphome-cloud/community
#   REPO=my-org/my-repo ./tests/integration/workflow_smoke.sh
#   ./tests/integration/workflow_smoke.sh --keep      # don't close dummy issues at end
#
# Exit: 0 = 5/5 success; 1 = any trial failed; 2 = setup/dependency missing.

set -euo pipefail

cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
KEEP=0

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

for cmd in gh jq date; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done

WORKFLOW=ai-triage.yml
TRIALS=5
TIMEOUT_S=120
POLL_S=5

# Nonce keeps reruns independent. Format: YYYYmmdd-HHMMSS-rand4
nonce="$(date '+%Y%m%d-%H%M%S')-$RANDOM"
echo "Smoke run nonce: $nonce"
echo "Repo: $REPO"
echo

created_issues=()
pass=0
fail=0

cleanup() {
  if [ "$KEEP" -eq 1 ]; then
    echo
    echo "--keep set; leaving ${#created_issues[@]} dummy issue(s) open."
    return
  fi
  if [ "${#created_issues[@]}" -gt 0 ]; then
    echo
    echo "Closing ${#created_issues[@]} dummy issue(s)..."
    for n in "${created_issues[@]}"; do
      gh issue close "$n" --repo "$REPO" --reason "not planned" \
        --comment "Auto-close: Task 0.3 smoke dummy (nonce=$nonce)." >/dev/null 2>&1 || true
    done
  fi
}
trap cleanup EXIT

# Run one trial: create issue, wait for matching workflow run, assert success + grep.
run_trial() {
  local n="$1"
  local title="[Bug]: smoke 0.3 #${nonce}-${n}"
  local body
  body=$(printf 'Task 0.3 smoke dummy.\n\nnonce=%s\ntrial=%s/%s\nlog-marker=python ok\n' \
         "$nonce" "$n" "$TRIALS")

  local start_iso
  start_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  echo "[trial $n/$TRIALS] creating issue '$title'"
  local url num
  url=$(gh issue create --repo "$REPO" --title "$title" --body "$body" --label needs-triage 2>/dev/null)
  num=$(printf '%s' "$url" | awk -F/ '{print $NF}')
  if [ -z "$num" ]; then
    echo "  FAIL: could not create issue"; return 1
  fi
  created_issues+=("$num")
  echo "  created issue #$num"

  # Poll for the matching workflow run.
  local run_id="" elapsed=0
  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    sleep "$POLL_S"
    elapsed=$((elapsed + POLL_S))
    # Match: workflow=ai-triage.yml, event=issues, createdAt>=start_iso.
    run_id=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --event issues \
              --created ">=$start_iso" --limit 10 \
              --json databaseId,displayTitle,headBranch,status,conclusion,createdAt \
              | jq -r --arg t "$title" '.[] | select(.displayTitle | contains($t)) | .databaseId' \
              | head -1)
    if [ -n "$run_id" ]; then
      echo "  found run $run_id at t=${elapsed}s"
      break
    fi
  done
  if [ -z "$run_id" ]; then
    echo "  FAIL: no workflow run matched within ${TIMEOUT_S}s"; return 1
  fi

  # Wait for completion.
  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    local status conclusion
    status=$(gh run view "$run_id" --repo "$REPO" --json status -q .status)
    if [ "$status" = "completed" ]; then
      conclusion=$(gh run view "$run_id" --repo "$REPO" --json conclusion -q .conclusion)
      if [ "$conclusion" != "success" ]; then
        echo "  FAIL: run $run_id ended with conclusion=$conclusion"; return 1
      fi
      break
    fi
    sleep "$POLL_S"
    elapsed=$((elapsed + POLL_S))
  done
  if [ "$status" != "completed" ]; then
    echo "  FAIL: run $run_id did not complete within ${TIMEOUT_S}s (status=$status)"; return 1
  fi

  # Grep the log for the smoke marker.
  if gh run view "$run_id" --repo "$REPO" --log 2>/dev/null | grep -qF 'python ok'; then
    echo "  PASS: trial $n round-trip ${elapsed}s, run $run_id, log contains 'python ok'"
    return 0
  else
    echo "  FAIL: run $run_id log does NOT contain 'python ok'"; return 1
  fi
}

for n in $(seq 1 "$TRIALS"); do
  if run_trial "$n"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
done

echo
echo "Summary: $pass/$TRIALS passed; $fail/$TRIALS failed."
if [ "$fail" -eq 0 ]; then
  echo "PASS: Task 0.3 acceptance smoke complete (5/5 success)."
  exit 0
fi
echo "FAIL: Task 0.3 acceptance not met (need 5/5)."
exit 1
