#!/usr/bin/env bash
# Lints every workflow file under .github/workflows/ and asserts the
# ai-triage.yml trigger contract (V-PHASE-02 forbidden-behavior).
#
# Two gates:
#   1. yamllint over .github/workflows/*.yml — exit 0 if all parse cleanly
#      under the project .yamllint config.
#   2. ai-triage.yml `.on` has EXACTLY two top-level keys: `issues` and
#      `discussion`. No push / pull_request / workflow_dispatch / schedule.
#
# Requires: yamllint (pip install yamllint) and python3 (for the .on check;
# yq is optional fallback if installed).
#
# Exit: 0 = pass; 1 = lint or .on-keys mismatch; 2 = missing dependency.

set -euo pipefail

cd "$(dirname "$0")/../.."

WORKFLOW_DIR=.github/workflows
TARGET=$WORKFLOW_DIR/ai-triage.yml

if [ ! -d "$WORKFLOW_DIR" ]; then
  echo "FAIL: $WORKFLOW_DIR not found"; exit 1
fi

# Gate 1: yamllint.
if ! command -v yamllint >/dev/null 2>&1; then
  echo "FAIL: yamllint not installed (pip install --user yamllint)"; exit 2
fi

echo "--- yamllint $WORKFLOW_DIR ---"
if yamllint "$WORKFLOW_DIR"; then
  echo "  PASS: all workflow files lint clean"
else
  echo "  FAIL: yamllint reported errors"; exit 1
fi
echo

# Gate 2: ai-triage.yml .on keys.
[ -f "$TARGET" ] || { echo "FAIL: $TARGET not found"; exit 1; }

if command -v yq >/dev/null 2>&1; then
  echo "--- $TARGET via yq: .on | keys ---"
  on_keys=$(yq -r '.on | keys | @csv' "$TARGET" 2>/dev/null || true)
  echo "  on keys (yq): $on_keys"
fi

# Python fallback (always run; authoritative).
echo "--- $TARGET via python3: .on key check ---"
python3 - "$TARGET" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()

m = re.search(r'^on:\s*\n((?:[ ].*\n|^\s*\n)*)', src, re.M)
if not m:
    print("  FAIL: no `on:` block in workflow"); sys.exit(1)
on_body = m.group(1)
keys = [k.group(1) for k in re.finditer(r'^  (\w+):', on_body, re.M)]
print(f"  on keys: {keys}")
if keys != ['issues', 'discussion']:
    print(f"  FAIL: expected exactly [issues, discussion], got {keys}")
    print("  (V-PHASE-02 forbidden-behavior: no push/PR/dispatch/schedule)")
    sys.exit(1)

# Confirm no forbidden top-level on subkey exists anywhere by tail-checking
# every line that looks like a 2-space-indented key.
forbidden = {"push", "pull_request", "workflow_dispatch", "schedule"}
hit = [k for k in keys if k in forbidden]
if hit:
    print(f"  FAIL: forbidden trigger keys found: {hit}"); sys.exit(1)
print("  PASS: .on has exactly [issues, discussion]")
PY

echo
echo "PASS: yamllint + .on-keys gates both green"
