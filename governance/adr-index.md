# ADR Index — community

Architectural decisions for the `esphome-cloud/community` feedback infrastructure. Profile triggers (`security_sensitive=true`, `external_api_surface=true`) emit a dedicated ADR index per `methodology/governance-triggers.md`.

## Conventions

- Numbering: 3-digit, monotonic across the project. **001 is the most foundational.**
- Status: `Proposed` / `Accepted` / `Superseded by ADR-NNN` / `Deprecated`
- Date: ADR-acceptance date (YYYY-MM-DD)
- Mandatory sections per `methodology/adr-format.md`: `Status`, `Date`, `Deciders`, `Tags`, `Context`, `Drivers`, `Considered Options`, `Decision`, `## Validation` (V1..Vn), `## Re-evaluation triggers` (T1..Tn). Validator V-ADR-01 enforces.

## ADR table

| ADR | Title | Status | Date | Tags | Phase landed |
|---|---|---|---|---|---|
| [001](adr-001-public-by-default.md) | Public-by-default communication channels (no Discord/Slack/WeChat) | Accepted | 2026-05-10 | architecture geo | 0 |
| [002](adr-002-three-channels-mutually-exclusive.md) | Three mutually-exclusive feedback channels (Discussions / Issues / Email) | Accepted | 2026-05-10 | architecture ux | 0 |
| [003](adr-003-claude-opus-triage.md) | Claude Opus 4.7 as first-line AI triage | Superseded by [ADR-008](adr-008-deepseek-v4-flash-triage.md) | 2026-05-10 → 2026-05-13 | ai cost | 0 |
| [004](adr-004-github-source-of-truth.md) | GitHub as single source of truth, Gitee read-only mirror only | Accepted | 2026-05-10 | china architecture | 2 |
| [005](adr-005-office-hours-only-sla.md) | Office-hours-only personal SLA (Tuesday 14:00-16:00 UTC+8) | Accepted | 2026-05-10 | sustainability sla | 1 |
| [006](adr-006-known-issues-in-script.md) | KNOWN_ISSUES as in-script Python string (deferred RAG upgrade) | Accepted | 2026-05-10 | ai infra | 0 |
| [007](adr-007-feedback-redirect.md) | `feedback@` auto-redirects to GitHub (does not bypass mutual exclusion) | Accepted | 2026-05-10 | architecture ux | 1 |
| [008](adr-008-deepseek-v4-flash-triage.md) | DeepSeek v4-flash as first-line AI triage (supersedes ADR-003) | Accepted | 2026-05-13 | ai cost geo | 3 |
| [009](adr-009-cloudflare-email-worker.md) | Multi-path inbound mail with byte-equal fixture-sourced auto-replies (TEE / DNSPod+Resend / CF Worker) | Accepted | 2026-05-14 | architecture email infra geo | 1 |

## Cross-cutting concerns

- **GEO posture** — ADR-001 is the load-bearing rule; ADR-002, ADR-004, ADR-007, ADR-009 all derive consistency from it (ADR-009's path selection is partly driven by mainland-CN reachability).
- **Sustainability** — ADR-005 anchors the founder time budget; ADR-002 and ADR-007 enforce it via channel boundary; ADR-009's auto-reply byte-equality contract keeps SLA copy in sync across the 4 mailboxes.
- **Cost envelope** — ADR-008 (formerly ADR-003) is the dominant AI-cost lever; ADR-006 keeps prompt size bounded; ADR-009 documents email-infra cost (free Path A2/B or ~$20/yr Path A); all three report into `governance/budget.md`. Migration to DeepSeek dropped per-issue cost by ~250×.
- **China access** — ADR-004 (GitHub source-of-truth, Gitee mirror) and ADR-009 (multi-path inbound mail with mainland-CN-native Path A + fully-free Path A2) are the two CN-aware ADRs; the rest are language- and geography-independent.

## Related artifacts

- `governance/risk-register.md` — risks tag-linked to ADRs (e.g., R-02 Claude cost ↔ ADR-003)
- `governance/threat-model.md` — STRIDE threats reference ADR-005 (SLA-driven trust assumption) and ADR-007 (mailbox handling)
- `governance/release-gate.md` — RC gates explicitly check for ADR adherence (no closed channels, mirror drift, etc.)

## Re-evaluation cadence

ADRs are not rotated on a calendar — they are re-evaluated when their explicit triggers fire. Founder's monthly review (last day of month) checks each ADR's trigger list against the month's data.
