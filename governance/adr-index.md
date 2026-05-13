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
| [003](adr-003-claude-opus-triage.md) | Claude Opus 4.7 as first-line AI triage | Accepted | 2026-05-10 | ai cost | 0 |
| [004](adr-004-github-source-of-truth.md) | GitHub as single source of truth, Gitee read-only mirror only | Accepted | 2026-05-10 | china architecture | 2 |
| [005](adr-005-office-hours-only-sla.md) | Office-hours-only personal SLA (Tuesday 14:00-16:00 UTC+8) | Accepted | 2026-05-10 | sustainability sla | 1 |
| [006](adr-006-known-issues-in-script.md) | KNOWN_ISSUES as in-script Python string (deferred RAG upgrade) | Accepted | 2026-05-10 | ai infra | 0 |
| [007](adr-007-feedback-redirect.md) | `feedback@` auto-redirects to GitHub (does not bypass mutual exclusion) | Accepted | 2026-05-10 | architecture ux | 1 |

## Cross-cutting concerns

- **GEO posture** — ADR-001 is the load-bearing rule; ADR-002, ADR-004, ADR-007 all derive consistency from it.
- **Sustainability** — ADR-005 anchors the founder time budget; ADR-002 and ADR-007 enforce it via channel boundary.
- **Cost envelope** — ADR-003 is the dominant cost lever; ADR-006 keeps prompt size bounded; both report into `governance/budget.md`.
- **China access** — ADR-004 is the only ADR that addresses Chinese users; the rest are language-independent.

## Related artifacts

- `governance/risk-register.md` — risks tag-linked to ADRs (e.g., R-02 Claude cost ↔ ADR-003)
- `governance/threat-model.md` — STRIDE threats reference ADR-005 (SLA-driven trust assumption) and ADR-007 (mailbox handling)
- `governance/release-gate.md` — RC gates explicitly check for ADR adherence (no closed channels, mirror drift, etc.)

## Re-evaluation cadence

ADRs are not rotated on a calendar — they are re-evaluated when their explicit triggers fire. Founder's monthly review (last day of month) checks each ADR's trigger list against the month's data.
