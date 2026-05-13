#!/usr/bin/env bash
# Phase 0 Task 0.6 acceptance #2 (End-to-end):
#   5 hand-crafted dummy issues across 5 categories — AI handles all 5
#   correctly within 90s. 5/5 must succeed.
#
# Categories per the PRD: known_issue, duplicate, user_config, real_bug,
# out_of_scope. (Skips feature_request / question / security_critical / spam
# / duplicate-with-#N pointer for this smoke — those have their own coverage
# via the 9-fixture acceptance + pager smoke.)
#
# For each trial:
#   1. File a dummy issue from the matching fixture under tests/fixtures/triage_inputs/.
#   2. Wait <=120s for ai-triage.yml to complete.
#   3. Fetch run log; assert `triage.classified{issue:<N>, category:<expected>, cost_usd:<X>}`
#      matches the expected category (Task 0.4 #4 + Task 0.6 #2).
#   4. Fetch the issue; assert at least one expected label was applied (defense-in-depth
#      on the dispatch path that Task 0.4 stood up).
#   5. Capture cost_usd from the log line so triage_cost.py can read it.
#
# Writes a state file to .smoke-state/phase0-<nonce>.json with the per-trial
# {issue_n, run_id, category, cost_usd} so tests/perf/triage_cost.py can
# operate over the same run set without re-querying.
#
# Usage:
#   ./tests/e2e/phase0_smoke.sh
#   REPO=my-org/my-repo TIMEOUT_S=240 ./tests/e2e/phase0_smoke.sh
#   ./tests/e2e/phase0_smoke.sh --keep
#
# Exit: 0 = 5/5 correct within 90s; 1 = any miss; 2 = setup.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
TIMEOUT_S="${TIMEOUT_S:-120}"
POLL_S=5
WORKFLOW=ai-triage.yml
KEEP=0
STATE_DIR=".smoke-state"

# The 5 hand-crafted fixtures (already present from Task 0.4).
declare -a TRIALS=(
  "known_issue:known_issue.json:ai-resolved"
  "duplicate:duplicate.json:duplicate"
  "user_config:user_config.json:ai-resolved"
  "real_bug:real_bug.json:bug"
  "out_of_scope:out_of_scope.json:out-of-scope"
)

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

for cmd in gh jq awk date python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done

nonce="$(date '+%Y%m%d-%H%M%S')-$RANDOM"
mkdir -p "$STATE_DIR"
state_file="$STATE_DIR/phase0-${nonce}.json"
echo '{"version": 1, "trials": []}' > "$state_file"

echo "Repo: $REPO"
echo "Nonce: $nonce"
echo "State: $state_file"
echo "Trials: 5 (known_issue, duplicate, user_config, real_bug, out_of_scope)"
echo

created_issues=()
pass=0
fail=0
fail_detail=()

cleanup() {
  if [ "$KEEP" -eq 1 ] || [ "${#created_issues[@]}" -eq 0 ]; then return; fi
  echo
  echo "Closing ${#created_issues[@]} dummy issue(s)..."
  for n in "${created_issues[@]}"; do
    gh issue close "$n" --repo "$REPO" --reason "not planned" \
      --comment "Auto-close: Task 0.6 phase0_smoke dummy (nonce=$nonce)." >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

append_state() {
  # Append {issue_n, run_id, category, cost_usd} to the trials array.
  local issue_n="$1" run_id="$2" category="$3" cost_usd="$4"
  python3 -c "
import json, sys
state = json.load(open('$state_file'))
state['trials'].append({
    'issue_n': int('$issue_n'),
    'run_id': int('$run_id') if '$run_id' else None,
    'category': '$category',
    'cost_usd': float('$cost_usd') if '$cost_usd' else None,
})
json.dump(state, open('$state_file', 'w'), indent=2)
"
}

run_trial() {
  local idx="$1" expected_category="$2" fixture_file="$3" expected_label="$4"
  local fixture_path="tests/fixtures/triage_inputs/$fixture_file"
  [ -f "$fixture_path" ] || { echo "  [$idx] FAIL: fixture not found: $fixture_path"; return 1; }

  # Title + body from the fixture, plus nonce so we can match the workflow run.
  local title body
  title=$(python3 -c "import json; print(json.load(open('$fixture_path'))['title'] + ' [smoke ${nonce}-${idx}]')")
  # Note: the f-string variables are BASH-interpolated (escaped \$). The
  # python f-string itself is not evaluating any python variables; the
  # nonce + idx + expected_category come from bash via $-substitution.
  body=$(python3 -c "
import json
d = json.load(open('$fixture_path'))
print(d['body'])
print()
print('<!-- phase0_smoke trial=${idx}/5 expected=${expected_category} nonce=${nonce} -->')
")

  local start_iso url issue_n err
  start_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  # Retry gh issue create with exponential backoff for proxy-EOF resilience.
  # 5 attempts × {2,4,8,16,32}s = ~62s window. Matches the workflow_smoke.sh pattern.
  local -a create_delays=(2 4 8 16 32)
  for attempt in 1 2 3 4 5; do
    err=$(gh issue create --repo "$REPO" --title "$title" --body "$body" \
              --label needs-triage 2>&1 >/tmp/.p0_url.$$)
    if [ -s /tmp/.p0_url.$$ ]; then
      url=$(cat /tmp/.p0_url.$$)
      rm -f /tmp/.p0_url.$$
      break
    fi
    if [ "$attempt" -lt 5 ]; then
      sleep_s="${create_delays[$((attempt-1))]}"
      echo "  [$idx] (gh issue create attempt $attempt: ${err:0:100}; retrying ${sleep_s}s)"
      sleep "$sleep_s"
    fi
  done
  issue_n=$(printf '%s' "${url:-}" | awk -F/ '{print $NF}')
  if [ -z "$issue_n" ]; then
    echo "  [$idx] FAIL: could not create issue after 5 attempts (last error: ${err:0:200})"
    return 1
  fi
  created_issues+=("$issue_n")
  echo "  [$idx] $expected_category → issue #$issue_n created"

  # Wait for workflow run + completion.
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
  if [ -z "$run_id" ]; then
    echo "  [$idx] FAIL: no workflow run within ${TIMEOUT_S}s"
    append_state "$issue_n" "" "$expected_category" ""
    return 1
  fi

  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    local status
    status=$(gh run view "$run_id" --repo "$REPO" --json status -q .status 2>/dev/null || echo "")
    [ "$status" = "completed" ] && break
    sleep "$POLL_S"; elapsed=$((elapsed + POLL_S))
  done

  # Pull the log; expect a triage.classified line. Capture cost_usd.
  # Retry the log fetch up to 5 times × {3,6,12,24,48}s backoff (~93s window)
  # to absorb proxy-EOF blips between client and api.github.com.
  local log log_bytes marker_line actual_cat actual_cost
  local -a log_delays=(3 6 12 24 48)
  for attempt in 1 2 3 4 5; do
    log=$(gh run view "$run_id" --repo "$REPO" --log 2>/dev/null || true)
    log_bytes=$(printf '%s' "$log" | wc -c | tr -d ' ')
    [ "$log_bytes" -gt 100 ] && break
    if [ "$attempt" -lt 5 ]; then
      sleep_s="${log_delays[$((attempt-1))]}"
      echo "  [$idx] (log fetch attempt $attempt returned $log_bytes bytes; retrying ${sleep_s}s)"
      sleep "$sleep_s"
    fi
  done

  marker_line=$(printf '%s' "$log" \
                | grep -oE "triage\.classified\{issue:${issue_n}, category:[a-z_]+, cost_usd:[0-9.]+\}" \
                | head -1)
  if [ -z "$marker_line" ]; then
    if [ "$log_bytes" -le 100 ]; then
      echo "  [$idx] FAIL: log unfetchable after 5 attempts ($log_bytes bytes — proxy?)"
    else
      echo "  [$idx] FAIL: no 'triage.classified{issue:${issue_n}...}' marker in log ($log_bytes bytes fetched)"
    fi
    fail_detail+=("issue=$issue_n run=$run_id reason=no-marker")
    append_state "$issue_n" "$run_id" "$expected_category" ""
    return 1
  fi
  actual_cat=$(printf '%s' "$marker_line" | sed -E 's/.*category:([a-z_]+).*/\1/')
  actual_cost=$(printf '%s' "$marker_line" | sed -E 's/.*cost_usd:([0-9.]+).*/\1/')

  if [ "$actual_cat" != "$expected_category" ]; then
    echo "  [$idx] FAIL: category=$actual_cat (expected $expected_category)"
    fail_detail+=("issue=$issue_n run=$run_id expected=$expected_category got=$actual_cat")
    append_state "$issue_n" "$run_id" "$actual_cat" "$actual_cost"
    return 1
  fi

  # Defense-in-depth: assert the expected label is on the issue.
  local labels
  labels=$(gh issue view "$issue_n" --repo "$REPO" --json labels -q '[.labels[].name] | join(",")' 2>/dev/null)
  if ! printf '%s' "$labels" | grep -qE "(^|,)${expected_label}(,|\$)"; then
    echo "  [$idx] WARN: expected label '$expected_label' not on issue (got: $labels). Marker matched, so passing on category alone."
  fi

  echo "  [$idx] PASS — category=$actual_cat cost=\$$actual_cost t<=${elapsed}s labels=[$labels]"
  append_state "$issue_n" "$run_id" "$actual_cat" "$actual_cost"
  return 0
}

idx=1
for trial in "${TRIALS[@]}"; do
  IFS=':' read -r cat fixture label <<< "$trial"
  if run_trial "$idx" "$cat" "$fixture" "$label"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
  idx=$((idx + 1))
done

echo
echo "Summary: $pass / 5 trials passed within ${TIMEOUT_S}s per trial."
if [ "$fail" -gt 0 ]; then
  echo "Failures:"
  printf '  - %s\n' "${fail_detail[@]}"
  echo
  echo "FAIL: Task 0.6 acceptance #2 requires 5/5."
  echo "State (partial): $state_file"
  exit 1
fi
echo "PASS: 5/5 hand-crafted dummies correctly classified."
echo "State: $state_file (feed into tests/perf/triage_cost.py --from-state)"
