#!/usr/bin/env bash
# Verifies no secret values have been committed to the repo's git history.
#
# Scans full git history for added lines (^+) matching known secret prefixes
# or the literal pass-assignment env shape.
#
# Patterns (extend as new secret shapes appear):
#   ghp_      — GitHub personal access tokens
#   gho_      — GitHub OAuth tokens
#   ghs_      — GitHub Apps tokens
#   sk-ant-   — Anthropic API keys
#   AKIA      — AWS access key ID prefix
#   -----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----
#   pass-assignment env-var shape (PASS=value with letters/digits)
#
# Exit: 0 = pass (no hits); 1 = at least one hit (CI block).

set -euo pipefail

cd "$(dirname "$0")/../.."

PATTERNS=(
  'ghp_[A-Za-z0-9]{20,}'
  'gho_[A-Za-z0-9]{20,}'
  'ghs_[A-Za-z0-9]{20,}'
  'sk-ant-[A-Za-z0-9_-]{20,}'
  'AKIA[A-Z0-9]{16,}'
  '-----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----'
  'PASS(WORD)?=[A-Za-z0-9_./+=-]{6,}'
)

# Scan only added lines in history (^+) but not the +++ file-header lines.
log=$(git log --all -p --no-color --no-merges 2>/dev/null || true)
if [ -z "$log" ]; then
  echo "PASS: empty git history (no commits yet)."
  exit 0
fi

hits=0
for pat in "${PATTERNS[@]}"; do
  if matches=$(echo "$log" | grep -nE "^\+[^+].*${pat}" || true); [ -n "$matches" ]; then
    echo "FAIL: secret-shaped pattern matched in history: $pat"
    echo "$matches" | head -5 | sed 's/^/  /'
    hits=$((hits + 1))
  fi
done

if [ "$hits" -gt 0 ]; then
  echo
  echo "$hits secret-shape pattern(s) hit in git history."
  echo "Rotate any leaked credential IMMEDIATELY."
  exit 1
fi

echo "PASS: no secret-shaped values found in git history (${#PATTERNS[@]} patterns scanned)."
