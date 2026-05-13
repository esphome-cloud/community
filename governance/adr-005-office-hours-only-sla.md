# ADR-005: Office-hours-only personal SLA (Tuesday 14:00-16:00 UTC+8)

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** sla sustainability ux

## Context

The founder is a single person building esphome.cloud as a 5-10 year endeavor. 24/7 implicit availability is unsustainable; explicit SLA-less ("we'll get to it") is opaque and reputation-damaging. The middle path: a transparent, tiered SLA matrix that gives everyone a real expectation while keeping the founder's personal response surface bounded to 2h/week.

Tiered design:
- **AI-handled** (within minutes) — covers 80-90% of inbound
- **Community-handled** (Discussions, hours) — peer-to-peer answer pattern via Q&A category
- **Founder-handled** (Tuesday 14-16 UTC+8) — for `needs-human` issues + email
- **Security** (24h) — out-of-band priority for security issues regardless of tier
- **Paid tiers** (4h Pro / 2h Pro+ / 1h Business) — explicit business-hours response

## Drivers

- **D1.** Founder must sustain 5-10 year cadence; 5h/week is the hard ceiling.
- **D2.** Real SLAs need to be specific enough to be falsifiable (else they erode trust).
- **D3.** Security issues need a 24h SLA regardless of tier (cannot be deferred to office hours).
- **D4.** User expectation must be transparent (preempts "why aren't you responding" complaints).
- **D5.** Communication discipline: no apologetic openings, no deadline commitments — these breed unsustainable habits.

## Considered Options

- **A. Tiered SLA: AI minutes / community hours / Tuesday 14-16 personal / 24h security / paid 4-2-1h** (chosen)
- **B. 24/7 best-effort** — rejected: unsustainable; founder will burn out
- **C. SLA-less ("we'll get to it")** — rejected: untransparent; reputation risk; users complain unpredictably
- **D. Quarterly written status updates only (no individual response)** — rejected: too austere; pushes users to closed channels seeking response

## Decision

Choose **A**. Codified in:
- README "Response Times" table (5 rows for free-tier, separate paid-tier section)
- `feedback@` + `hello@` + `security@` + `support@` auto-replies, byte-equal SLA references
- CODE_OF_CONDUCT additions ("Be patient" clause + "Don't @ the maintainer" clause)
- Founder calendar with Tuesday 14:00-16:00 UTC+8 recurring entry

Communication discipline rules (NO apologetic openings, NO deadline commitments, NO process explanations) are part of the founder's monthly review checklist.

## Validation

- **V1. (Matrix shape)** README "Response Times" table contains exactly 5 SLA rows (AI / community / personal / critical / security); `tests/repo/readme_sla_count.sh`.
- **V2. (Cross-surface consistency)** README + `feedback@` auto-reply + `hello@` auto-reply + CODE_OF_CONDUCT all reference the literal phrase `Tuesday 14:00-16:00 UTC+8` (or its equivalent rendering); set-equality test in `tests/repo/sla_consistency.sh`.
- **V3. (Calendar)** Founder calendar `.ics` export contains a recurring `RRULE:FREQ=WEEKLY;BYDAY=TU` event at the right time; `tests/repo/calendar_check.py` parses.
- **V4. (Communication discipline)** Founder's last 50 GitHub Issue comments contain 0 instances of `sorry for the delay`, `I'll fix this by`, `I've been busy`, `I'll get to this by` — `tests/repo/discipline_audit.sh` greps the founder's last 50 comments via `gh api`.
- **V5. (Mailbox auto-reply timing)** Auto-reply fires within 60 seconds of inbound on each of the 4 mailboxes; `tests/integration/autoreply_latency.py`.

## Re-evaluation triggers

- **T1.** Founder reports >7h/week on community ops for 4 consecutive weeks (the budget is breached; relax via more aggressive AI handling, not via wider personal SLA).
- **T2.** ≥5 paid Self-hosted clients with contracts requiring named hours that exceed Tuesday 14-16 (open separate paid-tier office-hours block).
- **T3.** AI handle-rate <70% (more spillover to founder than the 2h/week budget can absorb).
- **T4.** User complaints about office-hours-only SLA exceed 1 per month sustained for 3 months (consider widening the slot; reasoning logged).

## References

- Source: `community-async-plan.md` §一.2 铁律 2, §三.3 README Response Times, §五 邮件配置, §八 日常工作流, §九.3 Communication anti-patterns
- Related ADR: ADR-001 (public-by-default — auto-replies are public-facing GEO assets), ADR-002 (channels are bounded so SLA is scoped)
- Related risk: R-06 (office-hours discipline drift) — V3 + V4 are direct mitigations
