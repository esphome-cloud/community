#!/usr/bin/env bash
# Phase 0 Task 0.5 acceptance #2 (Security — negative):
#   SMTP_PASSWORD is never written to GH Actions log.
#
# Live-only. Fetches the last N ai-triage.yml workflow runs via `gh run view
# --log` and greps each log for the literal SMTP_PASSWORD value (read from
# the SECRET_VALUE_FILE or interactively).
#
# 0 hits = PASS. Any hit = FAIL + IMMEDIATE rotation required.
#
# The script also greps for ALL 7 secret names' values when SECRETS_DIR is
# set (a directory with one file per secret, named after the secret —
# never tracked by git; .gitignored as .secrets-input).
#
# Usage:
#   ./tests/security/no_smtp_leak.sh                     # interactive prompt for SMTP_PASSWORD
#   SMTP_PASSWORD=value ./tests/security/no_smtp_leak.sh # env (still scrubbed from history below)
#   SECRETS_DIR=/path/to/secrets ./tests/security/no_smtp_leak.sh  # scan all 7
#   REPO=esphome-cloud/community RUNS=200 ./tests/security/no_smtp_leak.sh
#
# Exit: 0 = 0 hits across N runs × M secrets; 1 = at least one hit; 2 = setup.

set -euo pipefail

cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
RUNS="${RUNS:-100}"
WORKFLOW=ai-triage.yml
ALL_NAMES=(ANTHROPIC_API_KEY ALERT_EMAIL SMTP_HOST SMTP_USER SMTP_PASSWORD GITEE_TOKEN GITEE_PRIVATE_KEY)

command -v gh >/dev/null 2>&1 || { echo "FAIL: gh CLI required"; exit 2; }

# Resolve the secret values to grep for.
secrets_to_check=()
if [ -n "${SECRETS_DIR:-}" ]; then
  [ -d "$SECRETS_DIR" ] || { echo "FAIL: SECRETS_DIR=$SECRETS_DIR not a directory"; exit 2; }
  # Refuse to read a tracked file.
  if git -C "$SECRETS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "FAIL: SECRETS_DIR appears to be inside a git repo — refuse to read tracked secret files."
    exit 2
  fi
  for name in "${ALL_NAMES[@]}"; do
    if [ -f "$SECRETS_DIR/$name" ]; then
      val=$(cat "$SECRETS_DIR/$name")
      # Skip values that are trivially short (< 6 chars) or empty.
      if [ -n "$val" ] && [ "${#val}" -ge 6 ]; then
        secrets_to_check+=("$name:$val")
      fi
    fi
  done
  echo "Scanning logs for ${#secrets_to_check[@]} secret value(s) from $SECRETS_DIR"
elif [ -n "${SMTP_PASSWORD:-}" ]; then
  secrets_to_check+=("SMTP_PASSWORD:$SMTP_PASSWORD")
  echo "Scanning logs for SMTP_PASSWORD value from env"
else
  # Interactive: ask for the SMTP_PASSWORD value once. -s suppresses echo.
  printf '  SMTP_PASSWORD value to scan for (input hidden, no history): '
  IFS= read -r -s val
  echo
  [ -n "$val" ] || { echo "FAIL: empty SMTP_PASSWORD"; exit 2; }
  secrets_to_check+=("SMTP_PASSWORD:$val")
fi

[ "${#secrets_to_check[@]}" -gt 0 ] || { echo "FAIL: no secret values to scan"; exit 2; }

# Get the last N completed run IDs.
echo
echo "Fetching last $RUNS run(s) of $WORKFLOW on $REPO..."
run_ids=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
            --status completed --limit "$RUNS" --json databaseId \
            | python3 -c "import json,sys; print('\n'.join(str(x['databaseId']) for x in json.load(sys.stdin)))")

count=$(echo "$run_ids" | grep -c .)
if [ "$count" -eq 0 ]; then
  echo "WARN: no completed runs found. Skipping log scan (no risk surface yet)."
  exit 0
fi
echo "  $count completed run(s) to scan"
echo

# Scan.
hits=()
for run_id in $run_ids; do
  log=$(gh run view "$run_id" --repo "$REPO" --log 2>/dev/null || true)
  [ -n "$log" ] || continue
  for entry in "${secrets_to_check[@]}"; do
    name="${entry%%:*}"
    value="${entry#*:}"
    # Use grep -F (fixed string) for binary-safe value scanning.
    if printf '%s' "$log" | grep -qF -- "$value"; then
      hits+=("run=$run_id secret=$name (value matched in log)")
    fi
  done
done

echo "Results: ${#hits[@]} hit(s) across $count run(s) × ${#secrets_to_check[@]} secret(s)."

if [ "${#hits[@]}" -gt 0 ]; then
  echo
  for h in "${hits[@]}"; do
    echo "  FAIL: $h"
  done
  echo
  echo "FAIL: at least one secret value appeared in GH Actions logs."
  echo "  ACTIONS REQUIRED:"
  echo "  1. Rotate every leaked secret in Anthropic/SMTP/Gitee console."
  echo "  2. Update GH Secrets via: bash scripts/setup-secrets.sh"
  echo "  3. Investigate: which step echoed the value? Check workflow for"
  echo "     \${{ secrets.X }} interpolated into a run: command — must go"
  echo "     through env: instead."
  exit 1
fi

echo "PASS: 0 secret values appeared in $count log(s). Task 0.5 #2 acceptance met."
