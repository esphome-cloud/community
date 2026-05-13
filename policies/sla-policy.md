# SLA Policy — esphome.cloud / community

> **Source of truth for response times.** The matrix below is reproduced
> byte-equal (whitespace-normalized) in three other surfaces: the README's
> "Response Times" section, the four mailbox auto-reply bodies under
> `tests/fixtures/email_autoreplies/`, and (informally) the project Code of
> Conduct's `Be patient` clause. If you edit the matrix here, run
> `bash tests/repo/sla_consistency.sh` to confirm the other surfaces still
> match — or update them in the same commit.
>
> Last reviewed: 2026-05-13. Cadence: review at every Phase exit, or whenever
> a contract negotiation triggers a tier change.

## Operating principle

This project is run by **one founder** with a **5-hour-per-week** operational
budget. The SLA matrix below reflects that constraint honestly:

- One same-day SLA exists, and only for **security** reports.
- Everything else has a **weekly cadence** anchored to a single office-hours
  block: Tuesday 14:00-16:00 UTC+8.
- Paid support tiers exist on paper for the post-BETA Self-hosted contract
  shape, but are **not publicly advertised during BETA**. The `support@`
  address is unlisted on the public website and the auto-reply only fires
  when an explicit Self-hosted partner emails the address.

No tier — paid or unpaid — promises around-the-clock, instant-response, or
"best-effort ASAP" coverage. The founder's calendar block is the SLA.

## SLA matrix

| Channel | Inbound type | Response SLA | Window |
|---|---|---|---|
| `security@esphome.cloud` | Security or privacy reports | 24 hours | Every day |
| `feedback@esphome.cloud` | General feedback (redirected to Discussions/Issues) | Tuesday office hours | Weekly, 14:00-16:00 UTC+8 |
| Discussions / Q&A | Usage questions, ideas, showcase | Tuesday office hours | Weekly, 14:00-16:00 UTC+8 |
| Issues / Bug Report | Bug reports | Tuesday office hours | Weekly, 14:00-16:00 UTC+8 |
| Issues / Feature Request | Feature requests in scope | Tuesday office hours | Weekly, 14:00-16:00 UTC+8 |
| Issues / Build Failed | Build-pipeline failures with Job ID | Tuesday office hours | Weekly, 14:00-16:00 UTC+8 |
| `hello@esphome.cloud` | Private, commercial, partnership, press | Tuesday office hours | Weekly, 14:00-16:00 UTC+8 |
| `support@esphome.cloud` (BETA: NOT public) | Paid Self-hosted contract support | Per contract | Mon-Fri 09:00-18:00 UTC+8 |

## Ritual cadence

- **Tuesday office hours, 14:00-16:00 UTC+8.** The founder's calendar block.
  All public-channel responses happen here. Goal: zero responses outside this
  window for non-security channels.
- **Monthly review, last Friday of the month.** Read the AI-triage retrospective:
  `governance/retros/incidents-YYYYMM.md`. Quarterly secret rotation occurs at
  this review (next: 2026-08-10, per `reference/runbook.md` §S-1).
- **Quarterly drills.** Two tabletop drills per quarter per the runbook §
  Quarterly drill cadence.
- **Phase exit.** SLA matrix re-reviewed at every phase exit (G0/G1/G2/G3/G4)
  to detect drift before it ships.

## What this policy explicitly excludes

By design, the project does NOT make any of these commitments — even when
asked nicely. If a Self-hosted contract negotiation in Phase 4+ requires one
of these, it spawns a new ADR rather than amending this matrix in place.

- Around-the-clock coverage on any unpaid channel.
- Synchronous / instant-message response on any channel.
- Live-chat replies on any channel.
- Same-business-day SLA on non-security inbound (BETA period).
- Cross-time-zone office-hours coverage (Asia-Pacific 14:00-16:00 UTC+8 is the only block).
- Holiday coverage. The Chinese New Year and Western Christmas windows pause
  Tuesday office hours; the next post-holiday Tuesday absorbs the backlog.

## How the SLA is enforced

- **AI triage** picks up every public Issue / Discussion within ~90s and
  applies labels + acknowledgement (per Phase 0 Task 0.4).
- **Auto-reply** fires on every email within 60s (per IC-2..IC-5 contracts).
- **Critical pager** fires on `security_critical` AI classifications via
  SMTP-SSL :465 to `ALERT_EMAIL` (per Task 0.5).
- **No human SLA exists in the auto-reply layer.** The auto-replies set the
  expectation; the founder's calendar block delivers on it.

## Cross-references

- ADR-005 (office-hours-only discipline) — drives the once-a-week response posture.
- ADR-002 (3-channel mutual exclusion) — anchors which channel each row maps to.
- ADR-007 (feedback@ redirect) — explains why `feedback@` has the same SLA as
  Discussions despite being a different inbound surface.
- IC-2 / IC-3 / IC-4 / IC-5 (mailbox auto-reply contracts) — encode the SLA
  text in the auto-reply bodies.
- `governance/release-gate.md` — the G4 BETA→GA gate considers tightening the
  feedback SLA if the founder's time budget allows.

## Edit log

- 2026-05-13 — initial draft (Phase 1 Task 1.4).
