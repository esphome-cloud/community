#!/usr/bin/env bash
# Phase 1 Task 1.1 acceptance #1 (Data shape):
#   each ISSUE_TEMPLATE/*.yml parses cleanly.
#
# Also asserts:
#   - config.yml has blank_issues_enabled: false (forces template chooser)
#   - bug.yml, feature.yml, build_failure.yml include "needs-triage" label
#     so ai-triage.yml picks them up (per IC-6/7/8)
#
# Exit: 0 = all 4 files parse + invariants hold; 1 = any failure.

set -euo pipefail
cd "$(dirname "$0")/../.."

TEMPLATE_DIR=".github/ISSUE_TEMPLATE"
[ -d "$TEMPLATE_DIR" ] || { echo "FAIL: $TEMPLATE_DIR not found"; exit 1; }

fails=0
checked=0

# Stage 1: every YAML file parses cleanly.
for f in "$TEMPLATE_DIR"/*.yml "$TEMPLATE_DIR"/*.yaml; do
  [ -f "$f" ] || continue
  checked=$((checked + 1))
  if err=$(python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>&1); then
    :
  else
    echo "FAIL: $f does not parse as YAML"
    printf '%s\n' "$err" | sed 's/^/  /'
    fails=$((fails + 1))
  fi
done

# Stage 2: invariants on config + the 3 template files.
if python3 - <<'PY'
import os, sys, yaml
d = ".github/ISSUE_TEMPLATE"

cfg_path = os.path.join(d, "config.yml")
if not os.path.exists(cfg_path):
    print(f"FAIL: {cfg_path} missing"); sys.exit(1)
cfg = yaml.safe_load(open(cfg_path))
if cfg.get("blank_issues_enabled") is not False:
    print(f"FAIL: {cfg_path}: blank_issues_enabled must be `false` "
          f"(got {cfg.get('blank_issues_enabled')!r})"); sys.exit(1)

for name in ("bug.yml", "feature.yml", "build_failure.yml"):
    p = os.path.join(d, name)
    if not os.path.exists(p):
        print(f"FAIL: {p} missing"); sys.exit(1)
    t = yaml.safe_load(open(p))
    labels = t.get("labels", [])
    if "needs-triage" not in labels:
        print(f"FAIL: {p}: missing 'needs-triage' label "
              f"(ai-triage.yml will not pick this issue up)"); sys.exit(1)

print(f"PASS: config.blank_issues_enabled=false; "
      f"bug/feature/build_failure all carry 'needs-triage'")
sys.exit(0)
PY
then
  :
else
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  echo
  echo "FAIL: $fails check(s) failed."
  exit 1
fi
echo "PASS: $checked template file(s) parse + invariants hold."
