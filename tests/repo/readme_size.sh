#!/usr/bin/env bash
# Phase 1 Task 1.5 acceptance #1 (Data shape):
#   README word count between 300-700.
#
# Founder discipline: under 300 reads sparse + unconvincing; over 700 reads
# as wishful all-things-to-all-people. The Tuesday office-hours posture
# rewards terse.

set -euo pipefail
cd "$(dirname "$0")/../.."

MIN=300
MAX=700
README=README.md

[ -f "$README" ] || { echo "FAIL: $README not found"; exit 1; }

count=$(wc -w < "$README" | tr -d ' ')
echo "README word count: $count (target $MIN-$MAX)"

if [ "$count" -lt "$MIN" ]; then
  echo "FAIL: too sparse — under $MIN words."
  exit 1
fi
if [ "$count" -gt "$MAX" ]; then
  echo "FAIL: too verbose — over $MAX words."
  exit 1
fi
echo "PASS: README size in range."
