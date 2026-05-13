# ADR-007: feedback@ auto-redirects to GitHub (does not bypass mutual exclusion)

- **Status:** Accepted
- **Date:** 2026-05-10
- **Deciders:** Founder
- **Tags:** architecture ux china

## Context

`feedback@esphome.cloud` is the public mailbox listed for general feedback. Two failure modes for this mailbox:

1. **Parallel-channel risk** — if it accepts general feedback as a peer to GitHub Issues / Discussions, founder workload doubles (every email needs reading even if AI handled the corresponding GitHub Issue).
2. **Hostile-rejection risk** — if it bounces inbound at SMTP level (5xx code), users feel rejected and lose the China-fallback path.

The middle path: **accept the email**, **reply with a friendly redirect** to GitHub URLs, but **do not have the founder read it** outside Tuesday office hours. The auto-reply does the work of channel-redirection. For users who genuinely cannot use GitHub (China network friction, no account), the email path remains valid because the founder *will* eventually read it on Tuesday.

This is the "channel reduction" pattern. Mutual-exclusion (ADR-002) is preserved by routing email-borne feedback BACK to GitHub via the auto-reply, not by treating email as a peer feedback channel.

## Drivers

- **D1.** Mutual-exclusion (ADR-002) must hold — feedback should land in exactly one place.
- **D2.** Chinese users without GitHub need a real fallback (cannot bounce them).
- **D3.** Founder cannot read general-feedback email at scale (5h/week budget).
- **D4.** Auto-reply must be polite + specific (give them URLs) AND set the office-hours expectation.

## Considered Options

- **A. Auto-reply redirects to GitHub URLs + sets office-hours expectation** (chosen)
- **B. SMTP-level 5xx bounce** — rejected: hostile; loses China fallback
- **C. Founder reads each email manually** — rejected: parallel channel; breaks ADR-002 + budget
- **D. Auto-route inbound to GitHub Issue via SendGrid Inbound Parse + GH API** — interesting but complex; deferred (would also need to handle email author privacy)

## Decision

Choose **A**. `feedback@` auto-reply (per `community-email-and-templates.md`) thanks the user, redirects to GitHub URLs, sets the office-hours expectation. Founder reads `feedback@` only on Tuesday 14-16 UTC+8 (per ADR-005). Other 3 mailboxes (`security@`, `hello@`, `support@`) are NOT general-feedback mailboxes and have their own ADR-orthogonal scopes.

## Validation

- **V1. (Auto-reply contains GitHub URLs)** `feedback@` auto-reply body contains BOTH `github.com/esphome-cloud/community/issues` and `github.com/esphome-cloud/community/discussions`; `tests/fixtures/email_autoreplies/feedback.txt` byte-equal (whitespace-normalized) check.
- **V2. (Auto-reply latency)** Auto-reply fires within 60s of inbound email; `tests/integration/feedback_autoreply_latency.py` measures across 5 trials.
- **V3. (hello@ consistency)** `hello@` auto-reply contains a redirect line steering bug reports to GitHub (consistent with feedback@ stance, scoped to hello@'s commercial+private theme); golden file `tests/fixtures/email_autoreplies/hello.txt`.
- **V4. (Mailbox-channel separation)** AI triage does NOT inspect `feedback@` mailbox (no email-API integration in v1); `tests/repo/triage_no_email_input.sh` greps `scripts/triage.py` for any `imap`, `pop3`, `email.message_from_*`, `gmail` literal — count = 0.
- **V5. (Founder reads in office hours only)** Gmail filter exports show `feedback@` items auto-archive on inbox arrival; founder pulls them only via the Tuesday office-hours saved-search; verified via `tests/fixtures/mail_filters_expected.json` set-equality.

## Re-evaluation triggers

- **T1.** >50/month emails to `feedback@` claiming "I can't use GitHub" (suggests building the deferred Gitee Issue → GitHub Issue Cloudflare Worker bridge per ADR-004 T1; this ADR's V1 redirect is no longer sufficient).
- **T2.** Founder reports the auto-reply tone as too aggressive (user complaints about being "shooed away") for 2 consecutive months.
- **T3.** AI triage gains email-input capability (then `feedback@` becomes a routed channel rather than a redirect; ADR-002 mutual-exclusion is re-evaluated).
- **T4.** A Self-hosted contract requires email-only feedback handling at high volume (need a routed pipeline, not just a redirect).

## References

- Source: `community-async-plan.md` §五.2 feedback@ 自动回复
- Related ADR: ADR-002 (mutual exclusion — V4 above directly enforces it), ADR-004 (China fallback — V1 + V3 keep email path open for blocked users), ADR-005 (founder reads only in office hours — V5 enforces)
- Related risk: R-09 (GitHub outage — `feedback@` becomes the only feedback path during outage; V1 redirect would point at 503-returning URLs but the email is still received and read)
