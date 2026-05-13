#!/usr/bin/env bash
# Phase 3 Task 3.5 acceptance #2 (Function):
#   ≥3 new ISSUE # markers were added to scripts/triage.py between the
#   phase-3 start and HEAD.
#
# The "phase-3 start" is identified by:
#   (a) PHASE_3_BASE env var (a commit SHA or tag), if set; preferred path
#       for monthly review or CI.
#   (b) The most recent commit whose message starts with "feat(phase-2):"
#       — auto-detected via git log. Works pre-Phase-3 close.
#   (c) Fallback: the last 14 days of commits.
#
# Asserts: count of lines matching `^+.*ISSUE #` in the diff is >=3.
#
# Counts CHANGED references too (a renamed ISSUE # would show as one - and one +);
# we subtract removals to get the net growth count.
#
# Usage:
#   PHASE_3_BASE=<sha-or-tag> bash tests/repo/known_issues_growth.sh
#   PHASE_3_BASE=phase-3-start bash tests/repo/known_issues_growth.sh
#   bash tests/repo/known_issues_growth.sh   # auto-detect from feat(phase-2):
#
# Exit: 0 = net-new >=3; 1 = below.

set -euo pipefail
cd "$(dirname "$0")/../.."

TARGET=scripts/triage.py
[ -f "$TARGET" ] || { echo "FAIL: $TARGET not found"; exit 1; }

MIN_NEW="${MIN_NEW:-3}"

base="${PHASE_3_BASE:-}"
if [ -z "$base" ]; then
  # Note: awk's `exit` action triggers SIGPIPE on `git log` under
  # `set -o pipefail`. Use head + cut instead to avoid the false-positive
  # pipeline failure.
  base=$(git log --pretty=format:'%H %s' --max-count=200 \
          | grep -E 'feat\(phase-2\)' \
          | head -1 \
          | cut -d' ' -f1) || true
  if [ -z "$base" ]; then
    base=$(git rev-list --max-count=1 --since='14 days ago' HEAD)
  fi
fi

if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
  echo "FAIL: cannot resolve PHASE_3_BASE=$base"
  exit 1
fi

echo "Base:        $base ($(git log -1 --format='%h %s' "$base"))"
echo "HEAD:        $(git rev-parse --short HEAD) ($(git log -1 --format='%s' HEAD))"
echo "Target file: $TARGET"
echo "Min new:     $MIN_NEW"
echo

diff_output=$(git diff "$base..HEAD" -- "$TARGET" || true)
if [ -z "$diff_output" ]; then
  echo "WARN: no changes to $TARGET between base and HEAD."
  added=0; removed=0
else
  added=$(printf '%s\n' "$diff_output" | grep -cE '^\+[^+].*ISSUE #' || true)
  removed=$(printf '%s\n' "$diff_output" | grep -cE '^-[^-].*ISSUE #' || true)
fi
net=$((added - removed))

echo "ISSUE # lines added:    $added"
echo "ISSUE # lines removed:  $removed"
echo "Net new (added-removed): $net"
echo

if [ "$net" -lt "$MIN_NEW" ]; then
  echo "FAIL: net-new ISSUE # = $net < $MIN_NEW (Task 3.5 + G3 floor)."
  exit 1
fi
echo "PASS: net-new ISSUE # = $net >= $MIN_NEW."
