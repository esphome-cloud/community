#!/usr/bin/env bash
# Verifies V-ADR-001: no closed-channel references in user-facing surfaces.
#
# In-scope files: README.md, CODE_OF_CONDUCT.md, and (once they exist)
# .github/ISSUE_TEMPLATE/*.yml — anything a public reader would land on.
#
# Banned strings (case-sensitive ASCII + Chinese variants):
#   Discord, Slack, WeChat, 微信, QQ, Telegram, Lark, Feishu, 飞书
#
# Exit: 0 = pass (zero hits); 1 = at least one hit.

set -euo pipefail

cd "$(dirname "$0")/../.."

BANNED='Discord|Slack|WeChat|微信|QQ|Telegram|Lark|Feishu|飞书'

# Files to scan: README + CoC always; ISSUE_TEMPLATE/* if present.
TARGETS=(README.md CODE_OF_CONDUCT.md)
if [ -d .github/ISSUE_TEMPLATE ]; then
  while IFS= read -r f; do TARGETS+=("$f"); done < <(
    find .github/ISSUE_TEMPLATE -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.md' \)
  )
fi

hits=0
for f in "${TARGETS[@]}"; do
  if [ ! -e "$f" ]; then
    continue
  fi
  if matches=$(grep -nE "$BANNED" "$f" || true); [ -n "$matches" ]; then
    echo "FAIL: $f contains banned closed-channel string(s):"
    echo "$matches" | sed 's/^/  /'
    hits=$((hits + 1))
  fi
done

if [ "$hits" -gt 0 ]; then
  echo
  echo "V-ADR-001 violated: $hits file(s) contain banned closed-channel references."
  echo "ADR-001 (governance/adr-001-public-by-default.md) requires all user-facing"
  echo "surfaces to remain free of Discord/Slack/WeChat/QQ/Telegram/Lark/Feishu."
  exit 1
fi

echo "PASS: V-ADR-001 — ${#TARGETS[@]} user-facing file(s) scanned; 0 banned strings."
