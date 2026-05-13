#!/usr/bin/env bash
# Phase 3 Task 3.3 acceptance #2 (Forbidden behavior):
#   each launch post explicitly states "I'm one person" (EN) or
#   "我一个人" (CN). Across the 3 drafts under docs/launch/ this should
#   produce >=3 hits (one per post).
#
# Also asserts:
#   - 0 banned closed-channel strings (V-ADR-001) across the 3 drafts
#   - 3 draft files exist with non-trivial content (>200 chars each)
#
# tests/fixtures/launch_posts.txt is OPTIONAL — when the founder publishes
# the 3 posts, they record the live URLs there for monthly review. The
# invariants check runs against the SOURCE drafts under docs/launch/.
#
# Exit: 0 = all checks pass; 1 = any miss.

set -euo pipefail
cd "$(dirname "$0")/../.."

DRAFT_DIR="docs/launch"
DRAFTS=(cn-short.md en-short.md cn-long-form.md)
BANNED='Discord|Slack|WeChat|微信|QQ|Telegram|Lark|Feishu|飞书'

[ -d "$DRAFT_DIR" ] || { echo "FAIL: $DRAFT_DIR not found"; exit 1; }

fails=0

# Per-draft existence + size + personhood + no-banned check.
personhood_total=0
for d in "${DRAFTS[@]}"; do
  path="$DRAFT_DIR/$d"
  if [ ! -f "$path" ]; then
    echo "  [$d] FAIL — missing"
    fails=$((fails + 1))
    continue
  fi

  size=$(wc -m < "$path" | tr -d ' ')
  if [ "$size" -lt 200 ]; then
    echo "  [$d] FAIL — only $size chars (expected >200)"
    fails=$((fails + 1))
    continue
  fi

  # Personhood anchor: at least one of "I'm one person" / "我一个人" / "I am one person".
  if grep -qF "I'm one person" "$path" || grep -qF "我一个人" "$path"; then
    personhood_total=$((personhood_total + 1))
    sla_anchor=$(grep -oE "I'm one person|我一个人" "$path" | head -1)
    echo "  [$d] ok — $size chars; personhood anchor '$sla_anchor'"
  else
    echo "  [$d] FAIL — missing personhood anchor ('I'm one person' or '我一个人')"
    fails=$((fails + 1))
    continue
  fi

  # V-ADR-001 banned-channel check (post body only — the "reply playbook"
  # sections may include the words DEFENSIVELY; this check covers the FULL
  # draft but the writer is responsible for using generic terms in the
  # reply guidance, not the literal banned platform names).
  if matches=$(grep -nE "$BANNED" "$path" || true); [ -n "$matches" ]; then
    echo "  [$d] FAIL — banned closed-channel string(s):"
    printf '%s\n' "$matches" | sed 's/^/    /'
    fails=$((fails + 1))
    continue
  fi
done

# At least 3 personhood-anchor hits across the 3 drafts (one per post).
if [ "$personhood_total" -lt 3 ]; then
  echo
  echo "FAIL: only $personhood_total / 3 drafts carry the personhood anchor."
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails launch-post invariant check(s) failed."
  exit 1
fi
echo
echo "PASS: all 3 launch drafts size-clean, personhood-anchored, no banned channels."
