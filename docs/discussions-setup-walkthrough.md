# Discussions setup walkthrough (Phase 1 Task 1.2)

GitHub does **not** expose a public `createDiscussionCategory` mutation (verified
via introspection 2026-05-13). Category management is UI-only. This walkthrough
gives you the paste-driven steps so you don't have to retype the canonical
specs from `tests/fixtures/discussions_categories_expected.json`.

Estimated time: **10 minutes** end-to-end.

## Confirm the API limitation yourself (optional, 30 sec)

If you want to double-check that GitHub still hasn't shipped category mutations:

```bash
gh api graphql -f query='
  query { __schema { mutationType { fields { name } } } }
' --jq '.data.__schema.mutationType.fields[].name' | grep -iE 'discussionCategory'
```

Expected output: empty. If non-empty, GitHub added category mutations — let us know and we'll update the scaffolding.

## Step 1 — enable Discussions (10 sec, scripted)

```bash
cd /Users/feiyu/go/src/github.com/esphome-cloud/community
bash scripts/setup-discussions.sh --enable
```

This is a one-line REST PATCH that sets `has_discussions=true` on the repo. Verify:

```bash
gh api repos/esphome-cloud/community --jq '.has_discussions'
# expect: true
```

After this, the repo gets GitHub's **default 5 categories**: Announcements, General, Ideas, Polls, Q&A, Show and tell. We're going to delete 2, rename 0, and add 1 to match our canonical 5.

## Step 2 — manage categories via the UI (5-8 min)

### 2.1 — navigate to category management

Open `https://github.com/esphome-cloud/community/discussions/categories` in your browser. You'll see GitHub's 5 defaults. You need to end up at exactly these 5 (in this exact order doesn't matter, but the names do):

| # | Name | Emoji | Type | Comments | Description (paste this) |
|---|---|---|---|---|---|
| 1 | `Announcements` | 📢 / `:mega:` | Announcement | **Disabled** | One-way broadcasts from the maintainer. Comments are disabled; replies live in other categories. |
| 2 | `Q&A` | 🙏 / `:pray:` | Question / Answer | Enabled | Usage questions and how-to's. Mark the accepted answer with the green check; mark-answer surfaces the best reply for future readers. |
| 3 | `Ideas` | 💡 / `:bulb:` | Open-ended discussion | Enabled | Feature seedlings, design exploration, things that aren't quite ready to become an Issue. Upvote with thumbs-up. |
| 4 | `Show & Tell` | 🛠 / `:hammer_and_wrench:` | Open-ended discussion | Enabled | Projects you built with esphome.cloud. Photos, videos, repo links — show off what you made. |
| 5 | `Solutions Share` | 🎯 / `:dart:` | Open-ended discussion | Enabled | User-contributed Solution templates: complete board × peripheral × use-case configurations others can re-use directly. |

### 2.2 — delete what we don't want

GitHub's defaults include **General** and **Polls** — both forbidden by IC-9 / V-ADR-001 spirit (no chat, no general bucket). For each:

1. Click the category in the sidebar
2. Click the ⚙ (gear) icon → **Edit category** → scroll down → **Delete category**
3. Confirm

Categories to delete: **General**, **Polls**. (Leave Announcements, Ideas, Q&A, Show and tell — we'll rename a couple.)

### 2.3 — rename + tune the survivors

For each of the 4 survivors, click ⚙ → **Edit category**:

- **Announcements**: emoji ✓, type ✓. **Uncheck "Allow comments"**. Paste the description from row 1. Save.
- **Q&A**: emoji 🙏 (change from default 💬 if needed), type **Question / Answer** ✓. Paste description from row 2. Save.
- **Ideas**: emoji 💡 ✓, type Open-ended ✓. Paste description from row 3. Save.
- **Show and tell**: rename to **Show & Tell** (with ampersand and spaces around it). Emoji 🛠 (change from default 👀). Paste description from row 4. Save.

### 2.4 — add the 5th category

Click **New category** (top-right). Fill in:

- Name: `Solutions Share`
- Emoji: `:dart:` (🎯)
- Description: paste row 5
- Discussion format: **Open-ended discussion**

Click **Create**.

### 2.5 — verify in browser

You should see exactly 5 categories. The category page URL slugs should be:

- `/categories/announcements`
- `/categories/q-a`
- `/categories/ideas`
- `/categories/show-and-tell`
- `/categories/solutions-share`

(Those match the `slug_hint` field in `tests/fixtures/discussions_categories_expected.json`.)

## Step 3 — create + pin the welcome post (10 sec, scripted)

After Step 2 is done in the UI:

```bash
bash scripts/setup-discussions.sh --welcome-post
```

This script:

1. Fetches the repo ID + Announcements category ID via GraphQL.
2. Calls `createDiscussion` with the title + body from `tests/fixtures/discussions_categories_expected.json` (`welcome_post.title` / `welcome_post.body_template`).
3. Calls `pinDiscussion` to pin it.

If a discussion is already pinned in Announcements, the script no-ops and prints `SKIP`.

## Step 4 — verify (10 sec, scripted)

```bash
bash scripts/setup-discussions.sh --check
# or equivalently:
bash tests/repo/discussions_cats.sh
```

Expected output:

```
=== category check ===
live count:     5
expected count: 5
category names: ['Announcements', 'Ideas', 'Q&A', 'Show & Tell', 'Solutions Share']
PASS: 5/5 categories present, no forbidden, no extras, Q&A is answerable

=== pinned welcome post in Announcements ===
pinned in Announcements: 1
  - 'Welcome to esphome.cloud / community'
PASS: at least 1 pinned post in Announcements

PASS: Task 1.2 acceptance — categories + pinned welcome post both green.
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `--enable` says `has_discussions=null` | gh CLI flag misparsed boolean | Use `gh api -X PATCH 'repos/<...>' -F has_discussions=true` directly |
| `--welcome-post` says "Announcements category not found" | You deleted the default Announcements during 2.2 and forgot to keep one | Re-create Announcements in the UI; re-run |
| `discussions_cats.sh` says `unexpected extra categories: ['General']` | You forgot to delete General during 2.2 | Delete in UI; re-run |
| `discussions_cats.sh` says `Q&A is not answerable` | Category was created as Open-ended instead of Question/Answer | Edit category in UI, change type to Question/Answer |
| `discussions_cats.sh` says `live count: 4` (not 5) | You didn't create Solutions Share | UI Step 2.4 |
| `pinDiscussion` returns `FORBIDDEN` | Token lacks `repo` scope OR you're not a repo admin | `gh auth refresh -s repo` |

## Why is this so manual?

GitHub treats Discussions categories as repository configuration, not content,
and has consistently declined to expose category mutations via either GraphQL
or REST. Other projects with similar setups (kubernetes/kubernetes,
microsoft/typescript, etc.) all maintain their categories via the UI. We
follow suit and lean on the welcome-post + verification scaffolding instead.

If GitHub ships `createDiscussionCategory` in a future API version, replace
the UI walkthrough with a 50-line `scripts/setup-categories.sh` that creates
all 5 from the fixture in one go.
