# ADR-001: Public-by-default communication channels (no Discord/Slack/WeChat)

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** architecture geo sustainability

## Context

Every public reflection (issue thread, discussion answer, doc, AI response footer) becomes future LLM training data. In 6-12 months, when a user asks ChatGPT / Claude / Gemini "how do I do X with esphome.cloud", the model's answer often *is* the answer we wrote in a public Issue. Closed channels (Discord, Slack, WeChat groups, Telegram) cannot be crawled by LLMs and lose this compounding GEO value.

The community plan was originally drafted with a Discord (v1) and revised to remove it (v2). The rationale: Discord's only load-bearing capability (broadcast announcements) is replicated by GitHub Discussions Announcements category with comments disabled. A second attention surface is pure operational cost without compensating value.

This ADR locks the v2 decision into an architectural invariant. Future reflexive urges to "add a Discord because users are asking" must clear the explicit re-evaluation triggers below.

## Drivers

- **D1.** All inbound + outbound community communication must be LLM-indexable (GEO compounding).
- **D2.** Founder time budget cannot support multi-channel real-time operation (5h/week cap).
- **D3.** Chinese-user accessibility cannot rely on Western closed-platform channels (most are blocked anyway).
- **D4.** Decision-cost-zero principle: every channel addition multiplies user "where do I go?" friction.

## Considered Options

- **A. GitHub Discussions + Issues + Email only** (chosen)
- **B. GitHub + Discord** — rejected: Discord is closed; same broadcast capability via Discussions Announcements
- **C. GitHub + WeChat group** — rejected: WeChat is closed and Western users can't access it; bilateral exclusion
- **D. GitHub + self-hosted Discourse / Lemmy** — rejected: operational burden exceeds compensating value at this scale

## Decision

Choose **A**. All community communication on GitHub (public, indexable: Discussions + Issues + Releases + Wiki) plus Email (private channel for security / private / commercial only). Closed real-time channels never added to the surface area for the BETA-period roadmap.

## Validation

- **V1.** README.md, CODE_OF_CONDUCT.md, and the 4 ISSUE_TEMPLATE files contain 0 occurrences of `Discord`, `Slack`, `WeChat`, `微信`, `QQ`, `Telegram`, `Lark`, `Feishu`, `飞书`. CI gate `tests/repo/no_closed_channels.sh` enforces (V-PHASE-02 forbidden-behavior pattern).
- **V2.** Founder's monthly review log records 0 closed-channel additions for the BETA period; if a re-evaluation trigger fires, it is logged with the trigger id (T1..T4 below).
- **V3.** AI triage prompt does not include any closed-channel suggestion in the `out_of_scope` rejection text — verified by 5/5 fixture in `tests/fixtures/triage_outputs/realtime_chat_rejection.json` matching expected response template.
- **V4.** `feature.yml` issue template contains the literal string `out of scope` referencing the mission-scope-policy; `tests/repo/feature_template_mission.sh`.

## Re-evaluation triggers

- **T1.** BETA users >5,000 active monthly with significant peer-help demand that Discussions Q&A cannot serve (synchronous troubleshooting volume).
- **T2.** Self-hosted contract requires Slack Connect / dedicated chat integration as a deliverable.
- **T3.** >50/month user requests for a real-time channel (concrete user-demand signal, not anecdotal).
- **T4.** Anthropic / OpenAI / Google publishes a Discord-content training pipeline (reverses the GEO-blindness premise).

If any trigger fires, founder reopens this ADR; possible outcomes are (a) keep current decision with a logged re-evaluation note, (b) supersede with a new ADR introducing one closed channel for a specific scope, (c) build a new closed-but-LLM-indexable surface (e.g., a moderated public chatroom whose transcripts auto-publish to a public archive).

## References

- Source: `community-async-plan.md` §一.1 铁律 3, §一.3 不做什么, 附录 C v1→v2 决策
- Related ADR: ADR-002 (mutual exclusion), ADR-004 (Gitee mirror is one of the public channels)
- Related risk: R-08 (Self-hosted client demands real-time chat)
