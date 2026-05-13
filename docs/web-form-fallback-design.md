# Web-form fallback design (deferred)

> **Status:** Design-only as of 2026-05-13 (Phase 2 Task 2.4). The implementation
> is **deferred** until the activation trigger fires. See "Activation runbook"
> below.

## Why this exists

Some prospective esphome.cloud users — especially in mainland China — either
cannot or will not register a GitHub account. They have legitimate feedback
that should reach the founder, and the current options for them are:

1. The Gitee mirror (read-only — they can read docs, but can't file anything).
2. Sending email to `feedback@esphome.cloud` (works, but requires composing
   a free-form email and knowing the address).

Option 2 is sufficient when "no GitHub" reports are a trickle. At higher
volume, a structured web form lowers friction enough to capture feedback we'd
otherwise miss. This document specifies what that form looks like, what it
submits to, and the condition that flips it from "deferred" to "build it now".

## Activation runbook

**Trigger:** 50 or more "no GitHub" feedback emails arrive at
`feedback@esphome.cloud` in a single rolling 30-day window.

**How we count:** every email that arrives at `feedback@` and is sent from
an originator who explicitly states they are not on GitHub gets tagged
`support_no_github` in the founder's mailbox provider's labelling rules
(or in the AI triage step that processes inbound `feedback@`, once that
exists). The monthly review counts the tag.

**When the trigger fires:**

1. Stand up the form per "Form specification" below.
2. Wire submission to `feedback@esphome.cloud` (see "Submission transport"
   below for the two implementation options).
3. Update the README's "Working from China" callout to reference the form.
4. Update `docs/github-signup-cn.md` § "替代 2:网页反馈表" to remove the
   "尚未上线" caveat.
5. Update interface contract IC-10 (in `reference/interface-contracts.md`)
   from `v0 (design-only)` to `v1 stable`.
6. Spawn a new ADR documenting the activation decision + which transport
   option was chosen.

## Form specification

Single HTML page at `https://esphome.cloud/feedback`. Markup is plain HTML
with no client-side JavaScript framework (anti-fragility — should work in
any browser including 10-year-old mobile WebKit). Three form fields, all
required:

| Field | Type | Validation | Notes |
|---|---|---|---|
| Email | `<input type="email">` | RFC 5322 + non-empty | Used as the `Reply-To` header on the resulting email. NOT stored beyond the auto-reply confirmation flow. |
| Body | `<textarea minlength="20" maxlength="5000">` | 20-5000 chars | Free-form feedback. Becomes the email body verbatim. |
| Category | `<input type="radio">` × 3 options | Exactly one of: `Bug` / `Feature` / `Question` | Determines the subject prefix. |

**Anonymous submission only.** The form takes no credentials and creates no
identity. The whole point of the form is "no GitHub" — adding any sign-in
requirement here defeats the purpose.

**Anti-spam controls** (implementation-level, no UX impact):

- Rate limit: 10 submissions per IP per hour.
- Cloudflare Turnstile (or equivalent invisible-by-default CAPTCHA) gates
  the submission. Visible challenge only fires on suspicious IPs.
- Honeypot field hidden by CSS (any submission filling it is dropped).
- Server-side check: reject submissions where `body` is mostly URLs (links/text
  ratio > 0.5).

## Submission transport

Two implementation options; pick at activation time based on what's
operationally cheaper to maintain.

### Option A — Cloudflare Worker → SMTP

```
Browser POST → Cloudflare Worker → MailChannels Send API → feedback@esphome.cloud
```

- Cloudflare Worker handles Turnstile validation + rate limiting + honeypot.
- Worker formats the email: `Subject: [Bug|Feature|Question] <first 60 chars>...`,
  `From: webform-noreply@esphome.cloud`, `Reply-To: <user-email>`, `Body: <body>`.
- MailChannels Send API ships the email to `feedback@esphome.cloud`.
- Pros: serverless, no infrastructure to maintain, free under fair use.
- Cons: requires Cloudflare setup + MailChannels Send permission.

### Option B — provider HTTP-to-email gateway

Postmark / Mailgun / SendGrid all offer an HTTP API that accepts a JSON
payload and turns it into an email. Same Subject / Reply-To shape applies.

- Pros: simpler to set up (one API call from the form's submission handler).
- Cons: requires the provider's API token at the form-page edge — must be
  scoped to send-only.

## Out-of-scope for v0

Explicitly NOT in the v0 design and DO NOT block activation:

- File attachments (logs, screenshots). v0 is text-only.
- Threaded follow-up: fire-and-forget. Follow-up via the email reply.
- Localized form copy (English-only for v0).
- Status visibility: no submission tracking.

## Operational metrics

Once active, track in monthly review:

- `support_no_github` tag count per month (should level off after the
  form is up — indicates the form is absorbing demand).
- Form submission count per month (proxy for non-GitHub feedback volume).
- Per-category breakdown (Bug / Feature / Question) — informs radio calibration.
- AI triage routing of form-originated emails (should match IC-2 / ADR-007).

## Security considerations

- **No PII storage**: the form does NOT persist the user's email beyond
  the submission flow.
- **CSRF**: not applicable — there's no authenticated session.
- **Email spoofing**: `From: webform-noreply@esphome.cloud` with SPF/DKIM/
  DMARC; user's email goes into `Reply-To`, not `From`.
- **Open redirect**: form has no redirect parameters.

## References

- [ADR-007](../governance/adr-007-feedback-redirect.md) — feedback@ redirect
  policy; this form is the structured variant.
- [IC-10](../reference/interface-contracts.md) — Web-form POST contract
  (currently v0; promoted to v1 at activation).
- `policies/sla-policy.md` — form-originated emails inherit the feedback@ row.

---

_Last updated: 2026-05-13 (Phase 2 Task 2.4). Activation pending the 50/mo
trigger described above._
