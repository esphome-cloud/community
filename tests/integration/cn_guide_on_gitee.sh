#!/usr/bin/env bash
# Phase 2 Task 2.3 acceptance #4 (End-to-end mirror):
#   After Gitee mirror sync, the guide is accessible at
#     https://gitee.com/esphome-cloud/community/raw/main/docs/github-signup-cn.md
#   returning HTTP 200.
#
# Live-only; defers to the mirror-to-gitee.yml workflow having run at least once.
#
# Usage:
#   bash tests/integration/cn_guide_on_gitee.sh
#
# Exit: 0 = HTTP 200 + body contains expected anchor; 1 = 404 / wrong content.

set -euo pipefail

URL="${CN_GUIDE_URL:-https://gitee.com/esphome-cloud/community/raw/main/docs/github-signup-cn.md}"
EXPECTED_ANCHOR='GitHub 注册与访问指南'

echo "Probing: $URL"

# Capture body + status separately.
body=$(curl -sSL -o /tmp/cn_guide_body -w '%{http_code}' "$URL" 2>&1) || {
  echo "FAIL: curl failed: $body"
  exit 1
}

if [ "$body" != "200" ]; then
  echo "FAIL: HTTP $body (expected 200)"
  echo "  Has the Gitee mirror synced yet? Trigger:"
  echo "    gh workflow run mirror-to-gitee.yml --repo esphome-cloud/community --ref main"
  exit 1
fi

if ! grep -qF "$EXPECTED_ANCHOR" /tmp/cn_guide_body; then
  echo "FAIL: body fetched but anchor '$EXPECTED_ANCHOR' not present."
  head -10 /tmp/cn_guide_body | sed 's/^/  /'
  exit 1
fi

chars=$(wc -m < /tmp/cn_guide_body | tr -d ' ')
echo "  HTTP 200; body has $chars chars; anchor '$EXPECTED_ANCHOR' present"
rm -f /tmp/cn_guide_body
echo "PASS: Chinese signup guide reachable from Gitee mirror."
