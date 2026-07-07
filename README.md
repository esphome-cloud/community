# esphome.cloud / community

**[English](#what-do-you-want-to-do)** | **[中文](README.zh-CN.md)**

> The feedback, ideas, and bug reports lane for the [esphome.cloud](https://esphome.cloud) BETA.

This repository is the single feedback intake for esphome.cloud BETA users. It is operated
by **me**, with an AI assistant handling first-line triage so I can spend
their hours on the things AI cannot do.

If you're not sure which lane you belong in, the **decision graph** below answers in one
glance. If you want to know how soon you'll hear back, the **response times** section
sets honest expectations. If GitHub is unreliable for you (mainland China), the
**Gitee mirror** below has you covered.

---

## What do you want to do?

Pick the row that matches your intent. There are exactly **three channels** by design
(Discussions / Issues / Email) — each has one purpose; each purpose has one channel.

| You want to... | Go here |
|---|---|
| Ask "how do I…" question | [Discussions / Q&A](https://github.com/esphome-cloud/community/discussions/categories/q-a) |
| Share an idea | [Discussions / Ideas](https://github.com/esphome-cloud/community/discussions/categories/ideas) |
| Show off what you built | [Discussions / Show & Tell](https://github.com/esphome-cloud/community/discussions/categories/show-and-tell) |
| Report a bug | [Issues / Bug Report](https://github.com/esphome-cloud/community/issues/new?template=bug.yml) |
| Request a feature | [Issues / Feature Request](https://github.com/esphome-cloud/community/issues/new?template=feature.yml) |
| Report a security concern | [security@esphome.cloud](mailto:security@esphome.cloud) |
| Discuss something private (commercial, partnership, press) | [hello@esphome.cloud](mailto:hello@esphome.cloud) |

---

## Response times

| Channel | Response SLA | Window |
|---|---|---|
| security@esphome.cloud | within 24 hours | every day |
| Discussions / Issues / feedback@ | Tuesday office hours | weekly, 14:00-16:00 UTC+8 |
| hello@esphome.cloud | Tuesday office hours | weekly, 14:00-16:00 UTC+8 |

Canonical SLA matrix lives in [`policies/sla-policy.md`](policies/sla-policy.md). Every AI-authored
response in the public channels closes with `— Triaged by AI; reply to reopen for human review` —
reply on the thread and a human reviews it on the next Tuesday window.

---

## What I won't do

- **No realtime chat channel** during BETA — a second attention surface beyond GitHub +
  Email costs more founder time than the 5h/week budget can sustain. Idea-sharing lives in
  Discussions; bugs live in Issues; nothing lives in a closed real-time room.
- **No OTA fleet management** — esphome.cloud BETA is single-device wizard → build → flash.
  Production OTA for 300-device fleets is a different product; ESPHome's own dashboard or
  commercial tools are a better fit.
- **No multi-tenant team collaboration** — no org/team workspaces, no RBAC, no audit trails.
  When a Self-hosted contract requires that shape in Phase 4+, it ships under a different
  product surface, not by retrofitting the BETA.

For the BETA→GA roadmap and the criteria that gate progression, see
[`governance/release-gate.md`](governance/release-gate.md).

---

## Working from China (Gitee mirror)

Read-only mirror at [`gitee.com/esphome-cloud/community`](https://gitee.com/esphome-cloud/community),
synced every 6 hours. Per [ADR-004](governance/adr-004-github-source-of-truth.md), GitHub is
the source of truth; Gitee carries source + docs + answered Q&A one-way. Filing happens on GitHub.

**Discussions mirror**: Since Gitee has no native Discussions, a static copy lives at
[`docs/discussions/`](https://gitee.com/esphome-cloud/community/tree/main/docs/discussions)
on the Gitee mirror — browsable as markdown pages organized by category.

Chinese GitHub-signup + acceleration guide: [`docs/github-signup-cn.md`](docs/github-signup-cn.md).
No-GitHub fallback: email `feedback@esphome.cloud`.

---

## How AI helps here

The first reply on most public threads comes from a DeepSeek v4-flash triage assistant
([`scripts/triage.py`](scripts/triage.py); see [ADR-008](governance/adr-008-deepseek-v4-flash-triage.md)).
It labels, points at `KNOWN_ISSUES`, closes duplicates, and pages a human only for
security-critical reports. Replying re-opens the thread for human review. The full
triage policy is in the script — no hidden moderation.

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Short version: be patient, be useful, don't
`@` the maintainer outside office hours, English or Chinese both welcome, harassment gets
you removed.

## License

Documentation: CC BY 4.0. Scripts (`scripts/`): MIT. See [LICENSE](LICENSE).

---

> 📖 中文用户请见 [README.zh-CN.md](README.zh-CN.md)。
