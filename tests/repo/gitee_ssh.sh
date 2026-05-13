#!/usr/bin/env bash
# Phase 2 Task 2.1 acceptance #2 (Function):
#   ssh -T git@gitee.com -i ~/.ssh/gitee_mirror returns the success banner.
#
# Also asserts (Security — negative):
#   - ~/.ssh/gitee_mirror EXISTS (dedicated mirror key)
#   - ~/.ssh/id_ed25519 (founder's primary key, if present) is NOT used
#     by this test — we explicitly pin to the dedicated key via -i
#
# Live-runnable once user has:
#   1. Generated `~/.ssh/gitee_mirror` via `ssh-keygen -t ed25519 -f ~/.ssh/gitee_mirror -C github-mirror@esphome.cloud`
#   2. Uploaded the public half (`~/.ssh/gitee_mirror.pub`) to gitee.com SSH-keys
#   3. Real-name-verified the Gitee account (mainland China KYC requirement)
#
# Exit: 0 = SSH banner received; 1 = banner absent / network issue; 2 = setup.

set -euo pipefail

KEY="${GITEE_MIRROR_KEY:-$HOME/.ssh/gitee_mirror}"
PUB="$KEY.pub"

# Stage 1: the dedicated key file must exist.
if [ ! -f "$KEY" ]; then
  echo "FAIL: $KEY not found."
  echo "  Generate with:"
  echo "    ssh-keygen -t ed25519 -f $KEY -C github-mirror@esphome.cloud -N ''"
  echo "  (No passphrase — the workflow can't supply one.)"
  exit 2
fi

# Stage 2: dedicated key must NOT be the same as ~/.ssh/id_ed25519
if [ -f "$HOME/.ssh/id_ed25519" ] && cmp -s "$HOME/.ssh/id_ed25519" "$KEY"; then
  echo "FAIL: $KEY appears identical to ~/.ssh/id_ed25519 (founder's primary key)."
  echo "  Mirror SSH key MUST be dedicated. Regenerate $KEY."
  exit 1
fi

# Stage 3: file perms must be 600 (otherwise SSH refuses to use it).
perms=$(stat -f '%Lp' "$KEY" 2>/dev/null || stat -c '%a' "$KEY")
if [ "$perms" != "600" ]; then
  echo "WARN: $KEY perms are $perms; SSH may refuse. Fix with: chmod 600 $KEY"
fi

# Stage 4: try the SSH banner test.
# Gitee returns banner-only over SSH; we don't need to actually push anything.
echo "--- SSH banner probe ---"
banner=$(ssh -T -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes \
            -o ConnectTimeout=10 -o BatchMode=yes \
            -i "$KEY" git@gitee.com 2>&1 || true)
echo "$banner" | sed 's/^/  /'
echo

# Gitee's success banner format: "Hi <username>! You've successfully authenticated, but Gitee does not provide shell access."
if echo "$banner" | grep -qE "Hi .*!.*successfully authenticated"; then
  user=$(echo "$banner" | sed -nE 's/^Hi ([^!]+)!.*/\1/p')
  echo "PASS: SSH banner received — Gitee account user='$user'"
  exit 0
fi

# Common Gitee failure modes — surface specific guidance.
if echo "$banner" | grep -qF "Permission denied"; then
  echo "FAIL: SSH key authenticated against gitee.com but Gitee refused — likely:"
  echo "  - $PUB not uploaded to gitee.com → Settings → SSH Keys"
  echo "  - Gitee account not real-name-verified (mainland China KYC)"
  exit 1
fi
if echo "$banner" | grep -qiE "name or service|timed out|no route"; then
  echo "FAIL: cannot reach gitee.com — network/proxy issue."
  exit 1
fi
echo "FAIL: unexpected SSH banner output (see above)."
exit 1
