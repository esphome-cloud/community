#!/usr/bin/env bash
# Phase 2 Task 2.2 acceptance #2 (Function):
#   triggering `gh workflow run mirror-to-gitee.yml` results in a successful
#   sync within 10 minutes; Gitee HEAD commit matches GitHub HEAD commit
#   after sync. 3 trials, 3/3 success required.
#
# Per trial:
#   1. Snapshot GitHub HEAD on main
#   2. Trigger mirror-to-gitee.yml via gh workflow run
#   3. Wait <=10min for the run to complete with conclusion=success
#   4. Assert Gitee HEAD on main equals the GitHub HEAD snapshot
#
# Uses git ls-remote against gitee.com via the dedicated SSH key (defaults to
# ~/.ssh/gitee_mirror; override via GITEE_MIRROR_KEY).
#
# Usage:
#   bash tests/integration/mirror_sync.sh                       # 3 trials
#   TRIALS=1 bash tests/integration/mirror_sync.sh              # quicker smoke
#   GITEE_REPO=gitee.com/esphome-cloud/community bash ...
#
# Exit: 0 = 3/3 trials confirm Gitee HEAD == GH HEAD; 1 = any drift / fail.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
GITEE_REPO="${GITEE_REPO:-git@gitee.com:esphome-cloud/community.git}"
WORKFLOW=mirror-to-gitee.yml
TIMEOUT_S="${TIMEOUT_S:-600}"
POLL_S=10
TRIALS="${TRIALS:-3}"
GITEE_KEY="${GITEE_MIRROR_KEY:-$HOME/.ssh/gitee_mirror}"

for cmd in gh git date awk; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done
[ -f "$GITEE_KEY" ] || { echo "FAIL: $GITEE_KEY not found (run gitee_ssh.sh first)"; exit 2; }

trial() {
  local n="$1"
  echo "[trial $n/$TRIALS]"

  local gh_head
  gh_head=$(gh api "repos/$REPO/commits/main" --jq '.sha' 2>/dev/null)
  [ -n "$gh_head" ] || { echo "  FAIL: could not fetch GH HEAD"; return 1; }
  echo "  GH main HEAD: ${gh_head:0:7}"

  local start_iso
  start_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  gh workflow run "$WORKFLOW" --repo "$REPO" --ref main >/dev/null
  echo "  triggered $WORKFLOW; waiting for completion"

  local run_id="" elapsed=0
  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    sleep "$POLL_S"; elapsed=$((elapsed + POLL_S))
    run_id=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
                --event workflow_dispatch --created ">=$start_iso" \
                --limit 5 --json databaseId,createdAt \
                --jq '.[0].databaseId // empty')
    [ -n "$run_id" ] && break
  done
  [ -n "$run_id" ] || { echo "  FAIL: no workflow run within ${TIMEOUT_S}s"; return 1; }

  while [ "$elapsed" -lt "$TIMEOUT_S" ]; do
    local status conclusion
    status=$(gh run view "$run_id" --repo "$REPO" --json status -q .status 2>/dev/null || echo "")
    if [ "$status" = "completed" ]; then
      conclusion=$(gh run view "$run_id" --repo "$REPO" --json conclusion -q .conclusion)
      if [ "$conclusion" != "success" ]; then
        echo "  FAIL: run $run_id concluded=$conclusion"
        return 1
      fi
      break
    fi
    sleep "$POLL_S"; elapsed=$((elapsed + POLL_S))
  done
  echo "  run $run_id concluded=success at t=${elapsed}s"

  sleep 5
  local gitee_head
  if ! gitee_head=$(GIT_SSH_COMMAND="ssh -i $GITEE_KEY -o IdentitiesOnly=yes" \
                      git ls-remote "$GITEE_REPO" refs/heads/main 2>&1 | awk '{print $1}'); then
    echo "  FAIL: could not ls-remote $GITEE_REPO ($gitee_head)"
    return 1
  fi
  echo "  Gitee main HEAD: ${gitee_head:0:7}"

  if [ "$gitee_head" != "$gh_head" ]; then
    echo "  FAIL: drift — Gitee=${gitee_head:0:7} GitHub=${gh_head:0:7}"
    return 1
  fi

  if ! gh run view "$run_id" --repo "$REPO" --log 2>/dev/null \
        | grep -qF 'Mirrored to Gitee at'; then
    echo "  WARN: workflow log missing 'Mirrored to Gitee at' marker"
  fi

  echo "  trial $n PASS — Gitee HEAD == GitHub HEAD in ${elapsed}s"
  return 0
}

pass=0
fail=0
for n in $(seq 1 "$TRIALS"); do
  if trial "$n"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done

echo
echo "Summary: $pass / $TRIALS trials confirmed Gitee HEAD == GitHub HEAD."
if [ "$fail" -gt 0 ]; then
  echo "FAIL: Task 2.2 acceptance #2 requires $TRIALS / $TRIALS."
  exit 1
fi
echo "PASS: mirror sync end-to-end."
