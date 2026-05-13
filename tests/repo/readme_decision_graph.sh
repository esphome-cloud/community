#!/usr/bin/env bash
# Phase 1 Task 1.5 acceptance #2 (Function) + ADR-002 V1:
#   README "What do you want to do?" decision graph has exactly 7 routing
#   rows mapping (Ask / Idea / Showcase / Bug / Feature / Security / Private)
#   → (Discussions / Discussions / Discussions / Issues / Issues / security@ / hello@)
#
# Also asserts the section has the literal "There are exactly **three channels**"
# claim that explains ADR-002's mutual-exclusion to readers.

set -euo pipefail
cd "$(dirname "$0")/../.."

README=README.md
[ -f "$README" ] || { echo "FAIL: $README not found"; exit 1; }

python3 - <<'PY'
import re, sys
src = open("README.md").read()

# Find the EN decision-graph table — header "You want to..."
m = re.search(r'\| You want to\.\.\. \| Go here \|.*?\n((?:\|[^\n]*\n)+)', src, re.S)
if not m:
    print("FAIL: 'You want to... | Go here' table not found in README"); sys.exit(1)

# Body rows: skip the separator row (|---|---|).
body = m.group(1)
rows = [ln for ln in body.splitlines()
        if ln.strip().startswith('|') and not re.match(r'^\|[-: ]+\|[-: ]+\|', ln)]
if len(rows) != 7:
    print(f"FAIL: expected exactly 7 routing rows, got {len(rows)}")
    for r in rows:
        print(f"  {r[:80]}")
    sys.exit(1)

# Verify each row maps to the expected channel category.
expected_routing = [
    ("Ask",       "discussions/categories/q-a"),
    ("idea",      "discussions/categories/ideas"),
    ("Show",      "discussions/categories/show-and-tell"),
    ("bug",       "issues/new?template=bug.yml"),
    ("feature",   "issues/new?template=feature.yml"),
    ("security",  "mailto:security@esphome.cloud"),
    ("private",   "mailto:hello@esphome.cloud"),
]
mismatches = []
for (intent_kw, expected_link), row in zip(expected_routing, rows):
    if intent_kw.lower() not in row.lower():
        mismatches.append(f"row missing intent keyword '{intent_kw}': {row[:80]}")
    if expected_link not in row:
        mismatches.append(f"row missing expected link '{expected_link}': {row[:80]}")

if mismatches:
    print("FAIL: decision-graph row drift")
    for m in mismatches:
        print(f"  {m}")
    sys.exit(1)

# ADR-002 V1: "three channels" claim somewhere near the decision graph.
if "three channels" not in src.lower():
    print("FAIL: README doesn't mention 'three channels' (ADR-002 V1)"); sys.exit(1)

print(f"PASS: 7 routing rows × correct intent→channel mapping; 'three channels' claim present.")
PY
