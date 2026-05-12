#!/usr/bin/env bash
# Verifies the 5 project-specific CoC clauses are present in CODE_OF_CONDUCT.md.
#
# Anchors (grep -F, literal strings):
#   1. "Be patient"
#   2. "Be useful"
#   3. "Don't @ the maintainer"
#   4. "English or Chinese"
#   5. "Harassment zero-tolerance"
#
# Exit: 0 = all 5 present; 1 = one or more missing.

set -euo pipefail

cd "$(dirname "$0")/../.."

COC=CODE_OF_CONDUCT.md
if [ ! -f "$COC" ]; then
  echo "FAIL: $COC not found"
  exit 1
fi

CLAUSES=(
  'Be patient'
  'Be useful'
  "Don't @ the maintainer"
  'English or Chinese'
  'Harassment zero-tolerance'
)

missing=0
found=0
for c in "${CLAUSES[@]}"; do
  if grep -F -q "$c" "$COC"; then
    found=$((found + 1))
    echo "  [ok] $c"
  else
    missing=$((missing + 1))
    echo "  [MISSING] $c"
  fi
done

if [ "$missing" -gt 0 ]; then
  echo
  echo "FAIL: $missing of ${#CLAUSES[@]} project-specific CoC clauses missing from $COC."
  echo "Task 0.1 acceptance requires count == 5."
  exit 1
fi

echo "PASS: all $found project-specific CoC clauses present (Task 0.1 acceptance)."
