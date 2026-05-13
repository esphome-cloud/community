#!/usr/bin/env bash
# Phase 1 Task 1.2 — scriptable portions of Discussions setup.
#
# Three operations:
#   --enable               : PATCH repo.has_discussions = true (REST)
#   --welcome-post         : after the 5 categories exist, createDiscussion +
#                            pinDiscussion for the welcome post in Announcements (GraphQL)
#   --check                : run tests/repo/discussions_cats.sh (live verification)
#
# Default: run all three in sequence. The middle bit — actually creating the
# 5 categories — is UI-only (GitHub has no createDiscussionCategory mutation).
# See docs/discussions-setup-walkthrough.md for the UI steps.
#
# Usage:
#   bash scripts/setup-discussions.sh                      # all three steps
#   bash scripts/setup-discussions.sh --enable             # just enable Discussions
#   bash scripts/setup-discussions.sh --welcome-post       # just the welcome post
#   REPO=my-org/my-repo bash scripts/setup-discussions.sh

set -euo pipefail
cd "$(dirname "$0")/.."

REPO="${REPO:-esphome-cloud/community}"
OWNER="${REPO%/*}"
NAME="${REPO#*/}"
FIXTURE="tests/fixtures/discussions_categories_expected.json"

DO_ENABLE=0
DO_WELCOME=0
DO_CHECK=0
[ "$#" -eq 0 ] && { DO_ENABLE=1; DO_WELCOME=1; DO_CHECK=1; }

for arg in "$@"; do
  case "$arg" in
    --enable)        DO_ENABLE=1 ;;
    --welcome-post)  DO_WELCOME=1 ;;
    --check)         DO_CHECK=1 ;;
    -h|--help)       sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)               echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

for cmd in gh jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not installed"; exit 2; }
done

# ----------------------------------------------------------------------------
# Step 1 — enable Discussions on the repo (REST API).
# ----------------------------------------------------------------------------
if [ "$DO_ENABLE" -eq 1 ]; then
  echo "=== enabling Discussions on $REPO ==="
  status=$(gh api -X PATCH "repos/$REPO" -F has_discussions=true --jq '.has_discussions')
  if [ "$status" = "true" ]; then
    echo "  PASS: has_discussions=true"
  else
    echo "  FAIL: API returned has_discussions=$status"
    exit 1
  fi
  echo
fi

# ----------------------------------------------------------------------------
# Step 2 — create + pin welcome post (requires the 5 categories already created
#          via the UI walkthrough in docs/discussions-setup-walkthrough.md).
# ----------------------------------------------------------------------------
if [ "$DO_WELCOME" -eq 1 ]; then
  echo "=== creating + pinning welcome post in Announcements ==="

  # Pull repo ID + Announcements category ID in one query.
  ids=$(gh api graphql -F owner="$OWNER" -F name="$NAME" -f query='
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        id
        discussionCategories(first: 50) {
          nodes { id name }
        }
      }
    }
  ')
  repo_id=$(echo "$ids" | jq -r '.data.repository.id')
  ann_id=$(echo "$ids" | jq -r '.data.repository.discussionCategories.nodes[] | select(.name == "Announcements") | .id')
  if [ -z "$ann_id" ] || [ "$ann_id" = "null" ]; then
    echo "  FAIL: Announcements category not found."
    echo "  Create the 5 categories via the UI first (see docs/discussions-setup-walkthrough.md)."
    exit 1
  fi
  echo "  repo_id=$repo_id"
  echo "  Announcements category_id=$ann_id"

  # Skip if a welcome post is already pinned.
  pinned=$(gh api graphql -F owner="$OWNER" -F name="$NAME" -f query='
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        pinnedDiscussions(first: 10) {
          nodes { discussion { title category { name } } }
        }
      }
    }
  ' --jq '[.data.repository.pinnedDiscussions.nodes[] | select(.discussion.category.name == "Announcements")] | length')
  if [ "$pinned" -gt 0 ]; then
    echo "  SKIP: $pinned discussion(s) already pinned in Announcements; nothing to do."
  else
    title=$(python3 -c "import json; print(json.load(open('$FIXTURE'))['welcome_post']['title'])")
    body=$(python3 -c "import json; print(json.load(open('$FIXTURE'))['welcome_post']['body_template'])")

    # createDiscussion mutation
    created=$(gh api graphql \
      -F repositoryId="$repo_id" \
      -F categoryId="$ann_id" \
      -F title="$title" \
      -F body="$body" \
      -f query='
        mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
          createDiscussion(input: {repositoryId: $repositoryId, categoryId: $categoryId, title: $title, body: $body}) {
            discussion { id number title url }
          }
        }
      ')
    disc_id=$(echo "$created" | jq -r '.data.createDiscussion.discussion.id')
    disc_num=$(echo "$created" | jq -r '.data.createDiscussion.discussion.number')
    disc_url=$(echo "$created" | jq -r '.data.createDiscussion.discussion.url')
    if [ -z "$disc_id" ] || [ "$disc_id" = "null" ]; then
      echo "  FAIL: createDiscussion returned no ID:"
      echo "$created" | jq . | sed 's/^/    /'
      exit 1
    fi
    echo "  created discussion #$disc_num — $disc_url"

    # pinDiscussion mutation
    pinned_result=$(gh api graphql -F discussionId="$disc_id" -f query='
      mutation($discussionId: ID!) {
        pinDiscussion(input: {discussionId: $discussionId}) {
          pinnedDiscussion { discussion { number title } }
        }
      }
    ')
    if echo "$pinned_result" | jq -e '.data.pinDiscussion.pinnedDiscussion.discussion.number' >/dev/null; then
      echo "  PASS: discussion #$disc_num pinned in Announcements"
    else
      echo "  FAIL: pinDiscussion error:"
      echo "$pinned_result" | jq . | sed 's/^/    /'
      exit 1
    fi
  fi
  echo
fi

# ----------------------------------------------------------------------------
# Step 3 — run the verification script.
# ----------------------------------------------------------------------------
if [ "$DO_CHECK" -eq 1 ]; then
  echo "=== running tests/repo/discussions_cats.sh ==="
  bash tests/repo/discussions_cats.sh
fi
