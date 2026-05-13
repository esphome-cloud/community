#!/usr/bin/env bash
# Phase 2 Task 2.2 acceptance #4 (Forbidden behavior):
#   workflow does NOT sync any branch named private/*.
#
# Strategy: create a dummy `private/test-${nonce}` branch from main on GitHub,
# trigger the mirror workflow, wait for completion, then assert the branch
# DOES NOT exist on Gitee. Cleanup: delete the dummy branch from GitHub on
# exit (unless --keep).
#
# Usage:
#   bash tests/repo/mirror_private_excluded.sh
#   bash tests/repo/mirror_private_excluded.sh --keep
#
# Exit: 0 = private/* branch absent from Gitee after sync; 1 = leaked.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
GITEE_REPO="${GITEE_REPO:-git@gitee.com:esphome-cloud/community.git}"
GITEE_KEY="${GITEE_MIRROR_KEY:-$HOME/.ssh/gitee_mirror}"
WORKFLOW=mirror-to-gitee.yml
KEEP=0

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

for cmd in gh git date awk; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done
[ -f "$GITEE_KEY" ] || { echo "FAIL: $GITEE_KEY not found"; exit 2; }

nonce="$(date '+%Y%m%d-%H%M%S')-$RANDOM"
branch="private/test-${nonce}"
echo "Test branch: $branch"

cleanup() {
  if [ "$KEEP" -eq 1 ]; then
    echo "--keep set; leaving $branch in place"
    return
  fi
  echo "Cleaning up $branch on GitHub..."
  gh api -X DELETE "repos/$REPO/git/refs/heads/$branch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 1. Create the private branch from main HEAD.
gh_main_sha=$(gh api "repos/$REPO/commits/main" --jq '.sha')
gh api -X POST "repos/$REPO/git/refs" \
  -f "ref=refs/heads/$branch" \
  -f "sha=$gh_main_sha" >/dev/null
echo "Created $branch on GitHub at ${gh_main_sha:0:7}"

# 2. Trigger mirror workflow + wait for completion.
start_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
gh workflow run "$WORKFLOW" --repo "$REPO" --ref main >/dev/null
echo "Triggered $WORKFLOW (start=$start_iso); waiting up to 10 min..."

run_id=""
elapsed=0
while [ "$elapsed" -lt 600 ]; do
  sleep 10; elapsed=$((elapsed + 10))
  run_id=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
              --event workflow_dispatch --created ">=$start_iso" \
              --limit 5 --json databaseId,status,conclusion \
              --jq '.[0] | select(.status == "completed") | .databaseId // empty')
  [ -n "$run_id" ] && break
done
[ -n "$run_id" ] || { echo "FAIL: workflow did not complete within 10 min"; exit 1; }

conclusion=$(gh run view "$run_id" --repo "$REPO" --json conclusion -q .conclusion)
[ "$conclusion" = "success" ] || { echo "FAIL: run $run_id concluded=$conclusion"; exit 1; }
echo "Mirror run $run_id completed: $conclusion"

# 3. Assert the private branch is NOT on Gitee.
if gitee_listing=$(GIT_SSH_COMMAND="ssh -i $GITEE_KEY -o IdentitiesOnly=yes" \
                     git ls-remote --heads "$GITEE_REPO" "refs/heads/$branch" 2>&1); then
  if [ -n "$gitee_listing" ]; then
    echo
    echo "FAIL: $branch IS PRESENT on Gitee (V-Phase-02 forbidden-behavior violated):"
    echo "  $gitee_listing"
    echo
    echo "The mirror workflow leaked a private/* branch. Audit"
    echo ".github/workflows/mirror-to-gitee.yml — the private/* exclusion loop"
    echo "is the load-bearing logic."
    exit 1
  fi
fi
echo "PASS: $branch was excluded from the Gitee mirror as expected."
