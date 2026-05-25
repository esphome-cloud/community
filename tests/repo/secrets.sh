#!/usr/bin/env bash
# Verifies the live GitHub repo has exactly the 7 expected secret names.
#
# Default repo: esphome-cloud/community (override with REPO env var).
# Golden list (order-insensitive; per ADR-008 ANTHROPIC_API_KEY was retired):
#   DEEPSEEK_API_KEY, ALERT_EMAIL, SMTP_HOST, SMTP_USER, SMTP_PASSWORD,
#   GITEE_TOKEN, GITEE_PRIVATE_KEY
#
# Values are intentionally NOT inspected (gh secret list never exposes them).
# Exit: 0 = pass; 1 = missing or extra secret(s).

set -euo pipefail

cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"

command -v gh >/dev/null 2>&1 || { echo "FAIL: gh CLI not installed"; exit 1; }

EXPECTED=(
  DEEPSEEK_API_KEY
  ALERT_EMAIL
  SMTP_HOST
  SMTP_USER
  SMTP_PASSWORD
  IMAP_PASSWORD
  GITEE_TOKEN
  GITEE_PRIVATE_KEY
)

# Pull live names (gh secret list outputs NAME<tab>UPDATED).
live=$(gh secret list --repo "$REPO" | awk 'NF { print $1 }' | sort)
expected_sorted=$(printf '%s\n' "${EXPECTED[@]}" | sort)

live_count=$(echo "$live" | wc -l | tr -d ' ')
exp_count=${#EXPECTED[@]}

missing=$(comm -23 <(echo "$expected_sorted") <(echo "$live") || true)
extra=$(comm -13 <(echo "$expected_sorted") <(echo "$live") || true)

if [ -n "$missing" ] || [ -n "$extra" ]; then
  echo "FAIL: secret-set mismatch on $REPO"
  [ -n "$missing" ] && { echo "  Missing:"; echo "$missing" | sed 's/^/    - /'; }
  [ -n "$extra" ]   && { echo "  Unexpected extra:"; echo "$extra" | sed 's/^/    - /'; }
  echo
  echo "Run: ./scripts/setup-secrets.sh"
  exit 1
fi

if [ "$live_count" -ne "$exp_count" ]; then
  echo "FAIL: secret count $live_count != expected $exp_count"
  exit 1
fi

echo "PASS: exactly $exp_count expected secrets present on $REPO."
