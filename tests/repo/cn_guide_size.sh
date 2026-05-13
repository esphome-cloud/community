#!/usr/bin/env bash
# Phase 2 Task 2.3 acceptance #1 (Data shape):
#   docs/github-signup-cn.md exists with >=600 chars (CJK counted) and
#   >=5 H2 sections.
#
# Plus acceptance #2 (>=3 acceleration methods), #3 (feedback@ + web-form
# link both present), and #5 (forbidden chat-channel mentions = 0).
#
# Exit: 0 = all checks pass; 1 = any miss.

set -euo pipefail
cd "$(dirname "$0")/../.."

GUIDE="docs/github-signup-cn.md"
[ -f "$GUIDE" ] || { echo "FAIL: $GUIDE not found"; exit 1; }

fails=0

echo '--- Stage 1: size + H2 count ---'
# wc -m counts characters (CJK = 1 each in modern wc).
chars=$(wc -m < "$GUIDE" | tr -d ' ')
h2s=$(grep -c '^## ' "$GUIDE" || true)
echo "  chars: $chars (target >= 600)"
echo "  H2 sections: $h2s (target >= 5)"
if [ "$chars" -lt 600 ]; then
  echo "  FAIL: too short."
  fails=$((fails + 1))
fi
if [ "$h2s" -lt 5 ]; then
  echo "  FAIL: too few H2 sections."
  fails=$((fails + 1))
fi

echo
echo '--- Stage 2: >=3 acceleration methods ---'
acc_terms=$(grep -oE 'hosts|ghproxy|FastGit|Chrome' "$GUIDE" | sort -u | wc -l | tr -d ' ')
echo "  distinct acceleration mentions: $acc_terms (target >= 3)"
if [ "$acc_terms" -lt 3 ]; then
  echo "  FAIL: too few acceleration methods."
  fails=$((fails + 1))
fi

echo
echo '--- Stage 3: feedback@ + web-form fallback links ---'
if ! grep -qF 'feedback@esphome' "$GUIDE"; then
  echo "  FAIL: missing 'feedback@esphome'"
  fails=$((fails + 1))
else
  echo "  ok: feedback@esphome present"
fi
if ! grep -qE 'esphome\.cloud/feedback' "$GUIDE"; then
  echo "  FAIL: missing 'esphome.cloud/feedback'"
  fails=$((fails + 1))
else
  echo "  ok: esphome.cloud/feedback present"
fi

echo
echo '--- Stage 4: no closed chat channels (Task 2.3 #5) ---'
# Per Task 2.3 spec: ban Discord/Slack/WeChat/微信/QQ群 (note QQ群 = chat groups;
# QQ邮箱 email service is NOT banned here per design — but we sidestep by not
# mentioning QQ at all in this guide).
BANNED_CHAT='Discord|Slack|WeChat|微信|QQ群|Telegram|Lark|Feishu|飞书'
hits=$(grep -nE "$BANNED_CHAT" "$GUIDE" || true)
if [ -n "$hits" ]; then
  echo "  FAIL: closed chat channel(s) mentioned:"
  echo "$hits" | sed 's/^/    /'
  fails=$((fails + 1))
else
  echo "  ok: 0 closed-chat-channel mentions"
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails check(s) failed in $GUIDE."
  exit 1
fi
echo "PASS: $GUIDE size + sections + acceleration + fallback links + no banned chats."
