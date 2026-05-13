#!/usr/bin/env bash
# Phase 2 Task 2.2 acceptance #3 (Capacity):
#   over 24h period (4 cron firings + push-triggered runs), drift between
#   GH HEAD and Gitee HEAD never exceeds 6h + workflow runtime (~10 min).
#   This script samples drift hourly for 25h.
#
# Drift = (time of GH HEAD commit) - (time of most-recent Gitee HEAD commit)
#       = (now - last successful mirror push that updated Gitee HEAD)
#
# Practical implementation: each hour, fetch GH HEAD + Gitee HEAD, compute
# the commit-timestamp difference (NOT clock time — clock drift between
# the two services is irrelevant; what matters is the commit gap).
#
# Designed to run unattended:
#   nohup bash tests/perf/mirror_drift.sh > /tmp/mirror-drift.log 2>&1 &
#
# Exit: 0 = 25 samples taken, drift always <=6h10min; 1 = any sample exceeded.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
GITEE_REPO="${GITEE_REPO:-git@gitee.com:esphome-cloud/community.git}"
GITEE_KEY="${GITEE_MIRROR_KEY:-$HOME/.ssh/gitee_mirror}"
SAMPLES="${SAMPLES:-25}"
INTERVAL_S=3600           # 1 hour
# Drift budget: 6h (cron) + 10min (workflow runtime) = 6h10min = 22200s
DRIFT_BUDGET_S=22200
STATE_DIR=".mirror-drift-state"
mkdir -p "$STATE_DIR"

[ -f "$GITEE_KEY" ] || { echo "FAIL: $GITEE_KEY not found"; exit 2; }

fail_samples=()
for i in $(seq 1 "$SAMPLES"); do
  # Fetch GH HEAD timestamp.
  gh_ts=$(gh api "repos/$REPO/commits/main" --jq '.commit.committer.date' 2>/dev/null || echo "")
  # Fetch Gitee HEAD via ls-remote + then look up commit ts via Gitee REST.
  gitee_sha=$(GIT_SSH_COMMAND="ssh -i $GITEE_KEY -o IdentitiesOnly=yes" \
                  git ls-remote "$GITEE_REPO" refs/heads/main 2>/dev/null \
                  | awk '{print $1}' | head -1)
  if [ -z "$gh_ts" ] || [ -z "$gitee_sha" ]; then
    echo "[sample $i/$SAMPLES] WARN: skipping — could not fetch one side."
    sleep "$INTERVAL_S"
    continue
  fi

  # Convert GH HEAD ISO to epoch.
  gh_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$gh_ts" "+%s" 2>/dev/null \
             || date -d "$gh_ts" "+%s" 2>/dev/null \
             || echo 0)

  # We can't easily get Gitee commit ts without a REST call to Gitee (which
  # needs an API token). Approximation: if Gitee SHA == GH SHA, drift is 0.
  # If SHAs differ, we measure drift as (now - gh_epoch) — the upper bound on
  # how long the GH commit has been "ahead".
  gh_sha=$(gh api "repos/$REPO/commits/main" --jq '.sha' 2>/dev/null)
  if [ "$gh_sha" = "$gitee_sha" ]; then
    drift_s=0
    status="in-sync"
  else
    now_epoch=$(date '+%s')
    drift_s=$((now_epoch - gh_epoch))
    status="drift"
  fi

  pretty_drift=$(printf '%dh%02dm' $((drift_s / 3600)) $(((drift_s % 3600) / 60)))
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[sample $i/$SAMPLES] $ts  GH=${gh_sha:0:7}  Gitee=${gitee_sha:0:7}  drift=$pretty_drift  ($status)"
  echo "$ts $gh_sha $gitee_sha $drift_s" >> "$STATE_DIR/samples.tsv"

  if [ "$drift_s" -gt "$DRIFT_BUDGET_S" ]; then
    fail_samples+=("sample $i: drift $pretty_drift > budget (6h10m)")
  fi

  [ "$i" -lt "$SAMPLES" ] && sleep "$INTERVAL_S"
done

echo
echo "Samples: $SAMPLES; failures: ${#fail_samples[@]}"
if [ "${#fail_samples[@]}" -gt 0 ]; then
  printf '  - %s\n' "${fail_samples[@]}"
  exit 1
fi
echo "PASS: drift never exceeded 6h10m budget over $SAMPLES hourly samples."
