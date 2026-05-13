# ADR-002: Three mutually-exclusive feedback channels (Discussions / Issues / Email)

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** architecture ux sustainability

## Context

A multi-channel community without channel-purpose mutual exclusion creates two failure modes: (a) user confusion ("which channel is right for my question?") and (b) founder fragmentation ("which surfaces did I check today?"). Both are sustainability hazards. Both compound over time.

Mutual-exclusion principle: each channel has exactly one purpose, and each purpose has exactly one channel. The user's question shape (asking / reporting / private) determines the channel automatically. The README "What do you want to do?" decision graph encodes this 1-to-1 mapping.

## Drivers

- **D1.** User decision cost = 0 (channel choice obvious from question shape).
- **D2.** Founder loop covers exactly 3 surfaces (Discussions / Issues / Email). Anything more breaks the 5h/week budget.
- **D3.** AI triage can redirect misfiled inputs (e.g., a question filed as Issue) but *not* across to email — so the in-GitHub redirect must be a single hop.
- **D4.** Email channel must remain low-volume — it is the only channel without AI triage available.

## Considered Options

- **A. Discussions / Issues / Email mutually-exclusive** (chosen)
- **B. All channels accept all feedback types** — rejected: high user friction; founder fragmentation
- **C. Single GitHub Issues channel only** — rejected: misuses Issues for chat/Q&A; loses the Discussions Q&A pattern (mark-accepted-answer)
- **D. Two channels (Issues + Email; no Discussions)** — rejected: Q&A and ideas land in Issues, polluting bug-tracking surface

## Decision

Choose **A**. Discussions for Q&A / ideas / showcase; Issues for bugs / features / build-failures; Email for security / private / commercial. README decision graph maps 7 user-question shapes to these 3 channels (3→Discussions, 2→Issues, 1→security@, 1→hello@).

## Validation

- **V1.** README "What do you want to do?" decision graph contains exactly 7 routing rows mapping (Ask / Idea / Showcase / Bug / Feature / Security / Private) → (Discussions / Discussions / Discussions / Issues / Issues / security@ / hello@); parsed by `tests/repo/readme_decision_graph.sh`.
- **V2.** AI triage `question` category fires for inputs filed as Issues that should have been Discussions, redirecting via comment + close + label; verified by 5/5 fixtures in `tests/fixtures/triage_inputs/misfiled_question_*.txt`.
- **V3.** `feedback@` auto-reply (per ADR-007) redirects general feedback to GitHub URLs; `tests/fixtures/email_autoreplies/feedback.txt` golden file (byte-equal whitespace-normalized).
- **V4.** Discussions has exactly 5 categories with no `General` / `Off-Topic` / `Chat` category; verified by `gh api repos/esphome-cloud/community/discussions/categories | jq '. | length == 5 and (map(.name) | index("General") | not)'`.

## Re-evaluation triggers

- **T1.** AI triage `question` category fires >30% of new Issues for 30 consecutive days (signals systemic user confusion about Discussions vs Issues — README needs revision, not a new channel).
- **T2.** >50/month emails to `feedback@` that are bug reports (signals email channel is being misused as Issues bypass — strengthen auto-reply, not split channel).
- **T3.** Discussions category usage skewed (>90% concentrated in 1 category for 60 days; others <2%) → consolidate categories, not add channels.
- **T4.** A real demand for a new channel type appears with concrete user volume (e.g., an "Ideas: Hardware Recommendation" lane that doesn't fit existing 3) → consider a new Discussions category, NOT a new channel.

## References

- Source: `community-async-plan.md` §一.2 三渠道为什么互斥, §三.1-§三.5 GitHub 配置
- Related ADR: ADR-001 (public-by-default; gives the 3-channel set), ADR-007 (feedback redirect implements V3 above)
- Related risk: R-07 (footer disclosure missing) — undermines V2 because users don't know the AI redirected them
