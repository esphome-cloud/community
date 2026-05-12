#!/usr/bin/env bash
# Verifies the bootstrap commit's file list matches tests/fixtures/repo_init_golden.txt.
#
# Task 0.1 acceptance:
#   `git ls-files` of the bootstrap commit equals exactly:
#     .gitignore, CODE_OF_CONDUCT.md, README.md
#
# The golden documents the BOOTSTRAP state, not HEAD. Subsequent commits add
# tests/ + scripts/ + workflows; this test guards against accidental files
# sneaking into the bootstrap by ensuring the root commit stays clean.
#
# The bootstrap commit is identified as the repo's root commit
# (git rev-list --max-parents=0 HEAD). If multiple root commits exist, the
# first listed wins.
#
# Exit: 0 = match; 1 = mismatch.

set -euo pipefail

cd "$(dirname "$0")/../.."

GOLDEN=tests/fixtures/repo_init_golden.txt
[ -f "$GOLDEN" ] || { echo "FAIL: golden $GOLDEN not found"; exit 1; }

# Identify the bootstrap commit (root commit on the current branch).
boot=$(git rev-list --max-parents=0 HEAD | head -1)
if [ -z "$boot" ]; then
  echo "FAIL: no root commit found"
  exit 1
fi

actual=$(git ls-tree --name-only "$boot" | sort)
expected=$(sort "$GOLDEN")

if [ "$actual" = "$expected" ]; then
  echo "PASS: bootstrap commit $boot matches $GOLDEN"
  echo "$actual" | sed 's/^/  /'
  exit 0
fi

echo "FAIL: bootstrap commit $boot does NOT match $GOLDEN"
echo
echo "Expected:"
echo "$expected" | sed 's/^/  /'
echo
echo "Actual:"
echo "$actual" | sed 's/^/  /'
echo
echo "Diff (- expected, + actual):"
diff <(echo "$expected") <(echo "$actual") | sed 's/^/  /' || true
exit 1
