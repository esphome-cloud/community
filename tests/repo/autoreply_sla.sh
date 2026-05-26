#!/usr/bin/env bash
# Phase 1 Task 1.3 acceptance #3 (Security — negative):
#   each auto-reply contains the literal string "office hours" or "24 hours"
#   (rejecting silent SLA promises).
#
# Also asserts V-ADR-001 on every auto-reply: 0 banned closed-channel strings.
#
# Exit: 0 = all 4 fixtures meet the gate; 1 = any miss.

set -euo pipefail
cd "$(dirname "$0")/../.."

DIR="tests/fixtures/email_autoreplies"
[ -d "$DIR" ] || { echo "FAIL: $DIR not found"; exit 1; }

FIXTURES=(feedback.txt security.txt hello.txt support.txt)
BANNED='Discord|Slack|WeChat|微信|QQ|Telegram|Lark|Feishu|飞书'

fails=0
for f in "${FIXTURES[@]}"; do
  path="$DIR/$f"
  if [ ! -f "$path" ]; then
    echo "  [$f] FAIL — missing"
    fails=$((fails + 1))
    continue
  fi

  if grep -qE 'office hours|24 hours|24 小时' "$path"; then
    sla=$(grep -oE 'office hours|24 hours|24 小时' "$path" | sort -u | tr '\n' '|' | sed 's/|$//')
  else
    echo "  [$f] FAIL — missing all SLA anchors ('office hours' / '24 hours' / '24 小时')"
    fails=$((fails + 1)); continue
  fi

  if matches=$(grep -nE "$BANNED" "$path" || true); [ -n "$matches" ]; then
    echo "  [$f] FAIL — contains banned closed-channel string(s):"
    printf '%s\n' "$matches" | sed 's/^/    /'
    fails=$((fails + 1)); continue
  fi

  # Subject sanity — every auto-reply MUST start with `Subject: `.
  if ! head -1 "$path" | grep -q '^Subject: '; then
    echo "  [$f] FAIL — missing 'Subject: ' on first line"
    fails=$((fails + 1)); continue
  fi

  echo "  [$f] ok — SLA anchor(s): $sla; no banned channels; Subject present"
done

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails / ${#FIXTURES[@]} fixtures failed the SLA + V-ADR-001 gate."
  exit 1
fi
echo "PASS: all ${#FIXTURES[@]} auto-reply fixtures carry SLA anchors + no banned channels."
