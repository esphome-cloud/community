#!/usr/bin/env bash
# Idempotently provisions the 7 GitHub Secrets on the live repo.
#
# Secret values come from one of:
#   1. Interactive prompt (default; values typed/pasted, never echoed)
#   2. A local .secrets-input file (key=value lines; gitignored by default)
#      Use this for one-shot setup; delete after.
#
# Usage:
#   ./scripts/setup-secrets.sh
#   ./scripts/setup-secrets.sh --from-file .secrets-input
#   REPO=my-org/my-repo ./scripts/setup-secrets.sh
#
# Exit: 0 = all 7 set; non-zero = at least one failure or aborted.

set -euo pipefail

cd "$(dirname "$0")/.."

REPO="${REPO:-esphome-cloud/community}"
INPUT_FILE=""

for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --from-file)
      next=$((i + 1))
      INPUT_FILE="${!next:-}"
      [ -n "$INPUT_FILE" ] || { echo "--from-file requires a path"; exit 2; }
      i=$next
      ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: ${!i}" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "FAIL: gh CLI not installed"; exit 1; }

# Refuse to run if the input file is tracked by git (catches accidental commits).
if [ -n "$INPUT_FILE" ]; then
  [ -f "$INPUT_FILE" ] || { echo "FAIL: input file $INPUT_FILE not found"; exit 1; }
  if git ls-files --error-unmatch "$INPUT_FILE" >/dev/null 2>&1; then
    echo "FAIL: $INPUT_FILE is tracked by git. Move it out of the repo (or untrack it) before continuing."
    exit 1
  fi
fi

SECRETS=(
  DEEPSEEK_API_KEY
  ALERT_EMAIL
  SMTP_HOST
  SMTP_USER
  SMTP_PASSWORD
  GITEE_TOKEN
  GITEE_PRIVATE_KEY
)

# Heuristic help text per secret (shown at the interactive prompt; ASCII only).
describe() {
  case "$1" in
    DEEPSEEK_API_KEY)  echo "sk-... DeepSeek API key for v4-flash triage (per ADR-008)" ;;
    ALERT_EMAIL)       echo "founder@... mailbox that receives [CRITICAL] pager emails" ;;
    SMTP_HOST)         echo "smtp.example.com  outbound SMTP-SSL :465 host for the pager" ;;
    SMTP_USER)         echo "ai-triage@esphome.cloud  SMTP login user" ;;
    SMTP_PASSWORD)     echo "SMTP login password (or app-specific token)" ;;
    GITEE_TOKEN)       echo "Gitee personal access token for mirror-to-gitee workflow (Phase 2)" ;;
    GITEE_PRIVATE_KEY) echo "SSH private key for Gitee push mirror (Phase 2)" ;;
    *)                 echo "" ;;
  esac
}

# Read a value either from $INPUT_FILE (key=value lines) or interactively.
read_value() {
  local name="$1"
  if [ -n "$INPUT_FILE" ]; then
    # Allow multi-line values via heredoc-style: key=<<EOF ... EOF.  For simplicity
    # we support single-line only here. Multi-line keys (GITEE_PRIVATE_KEY) require
    # interactive entry or a separate dedicated load step.
    local v
    v=$(grep -E "^${name}=" "$INPUT_FILE" | head -1 | sed -E "s/^${name}=//") || true
    if [ -z "$v" ]; then
      echo "FAIL: $INPUT_FILE has no entry for $name=" >&2
      return 1
    fi
    printf '%s' "$v"
    return 0
  fi
  # Interactive: no echo, no history.
  local v
  printf '  [%s]\n  hint: %s\n  value: ' "$name" "$(describe "$name")" >&2
  IFS= read -r -s v
  echo >&2
  if [ -z "$v" ]; then
    echo "FAIL: empty value for $name" >&2
    return 1
  fi
  printf '%s' "$v"
}

ok=0
failed=0
total=${#SECRETS[@]}

echo "Setting $total secrets on $REPO"
echo "Source: ${INPUT_FILE:-interactive prompt}"
echo

for name in "${SECRETS[@]}"; do
  value=$(read_value "$name") || { failed=$((failed + 1)); continue; }
  if printf '%s' "$value" | gh secret set "$name" --repo "$REPO" --body - >/dev/null 2>&1; then
    echo "  [ok] $name set"
    ok=$((ok + 1))
  else
    echo "  [FAILED] $name"
    failed=$((failed + 1))
  fi
  unset value
done

echo
if [ "$failed" -gt 0 ]; then
  echo "FAIL: $failed/$total secret(s) failed. Check gh auth status and repo admin perms."
  exit 1
fi

echo "PASS: $ok/$total secrets set on $REPO."
echo
echo "Reminder: rotate quarterly. First rotation date: 2026-08-10 (per Task 0.2 + runbook)."
echo "Verify with: bash tests/repo/secrets.sh"
