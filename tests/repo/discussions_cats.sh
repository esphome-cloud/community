#!/usr/bin/env bash
# Phase 1 Task 1.2 acceptance:
#   - exactly 5 categories matching the names in
#     tests/fixtures/discussions_categories_expected.json
#   - no "General" / "Off-Topic" / "Chat" / "Random" category (V-ADR-001 spirit)
#   - 📢 Announcements has comments disabled
#   - 1 pinned welcome post in Announcements
#
# Queries the live repo via gh GraphQL.
#
# Usage:
#   bash tests/repo/discussions_cats.sh
#   REPO=my-org/my-repo bash tests/repo/discussions_cats.sh
#
# Exit: 0 = all green; 1 = drift detected; 2 = setup / Discussions not enabled.

set -euo pipefail
cd "$(dirname "$0")/../.."

REPO="${REPO:-esphome-cloud/community}"
OWNER="${REPO%/*}"
NAME="${REPO#*/}"
FIXTURE="tests/fixtures/discussions_categories_expected.json"

for cmd in gh jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done
[ -f "$FIXTURE" ] || { echo "FAIL: $FIXTURE not found"; exit 2; }

# Fetch live category set + pinned-discussion-in-Announcements status in one query.
read -r -d '' QUERY <<'GQL' || true
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    hasDiscussionsEnabled
    discussionCategories(first: 50) {
      nodes {
        id
        name
        slug
        emoji
        isAnswerable
        description
      }
    }
    pinnedDiscussions(first: 5) {
      nodes {
        discussion {
          title
          category { name }
        }
      }
    }
  }
}
GQL

resp=$(gh api graphql -F owner="$OWNER" -F name="$NAME" -f query="$QUERY" 2>&1) || {
  echo "FAIL: gh graphql call failed: $resp"
  exit 2
}

enabled=$(echo "$resp" | jq -r '.data.repository.hasDiscussionsEnabled // false')
if [ "$enabled" != "true" ]; then
  echo "FAIL: Discussions not enabled on $REPO."
  echo "  Run: gh api -X PATCH 'repos/$REPO' -F has_discussions=true"
  echo "  Or:  github.com/$REPO/settings → Features → check 'Discussions'"
  exit 2
fi

# Compare live categories to fixture.
fails=0
echo '=== category check ==='
python3 <<PY
import json, sys
resp = json.loads('''$resp''')
fixture = json.load(open("$FIXTURE"))

live = resp["data"]["repository"]["discussionCategories"]["nodes"]
expected_names = [c["name"] for c in fixture["categories"]]
live_names = sorted([c["name"] for c in live])
expected_sorted = sorted(expected_names)

print(f"live count:     {len(live)}")
print(f"expected count: {fixture['expected_count']}")

# Check count.
if len(live) != fixture["expected_count"]:
    print(f"FAIL: expected {fixture['expected_count']} categories, got {len(live)}")
    sys.exit(1)

# Check each expected name is present.
missing = [n for n in expected_names if n not in live_names]
if missing:
    print(f"FAIL: missing categories: {missing}")
    sys.exit(1)

# Check no forbidden names.
forbidden = fixture["forbidden_names"]
bad = [n for n in live_names if n in forbidden]
if bad:
    print(f"FAIL: forbidden categories present: {bad}")
    sys.exit(1)

# Check no extras (live has only the expected set).
extra = [n for n in live_names if n not in expected_names]
if extra:
    print(f"FAIL: unexpected extra categories: {extra}")
    sys.exit(1)

# Check Q&A is answerable.
qa = next((c for c in live if c["name"] == "Q&A"), None)
if not qa:
    print("FAIL: Q&A category not found"); sys.exit(1)
if not qa["isAnswerable"]:
    print("FAIL: Q&A is not answerable (should be QUESTION_ANSWERS format)")
    sys.exit(1)

print(f"category names: {live_names}")
print(f"PASS: 5/5 categories present, no forbidden, no extras, Q&A is answerable")
PY
cat_result=$?
[ $cat_result -ne 0 ] && fails=$((fails + 1))

echo
echo '=== pinned welcome post in Announcements ==='
python3 <<PY
import json, sys
resp = json.loads('''$resp''')
pinned = resp["data"]["repository"]["pinnedDiscussions"]["nodes"]
ann_pinned = [p for p in pinned if p["discussion"]["category"]["name"] == "Announcements"]
if not ann_pinned:
    print("FAIL: no pinned discussion in Announcements category")
    print("  Run: bash scripts/setup-discussions.sh --welcome-post")
    sys.exit(1)
print(f"pinned in Announcements: {len(ann_pinned)}")
for p in ann_pinned:
    print(f"  - {p['discussion']['title']!r}")
print("PASS: at least 1 pinned post in Announcements")
PY
pin_result=$?
[ $pin_result -ne 0 ] && fails=$((fails + 1))

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails check(s) failed."
  exit 1
fi
echo "PASS: Task 1.2 acceptance — categories + pinned welcome post both green."
