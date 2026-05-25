# ADR-009: Multi-path inbound mail (TEE / DNSPod+Resend / CF Email Worker) with byte-equal fixture-sourced auto-replies

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** founder
- **Tags:** architecture email infrastructure geo

## Context

Phase 1 Task 1.3 (`email-mailboxes`) originally treated mail as "provision 4 mailboxes at $registrar with per-mailbox auto-replies set in the vendor web UI" — a single transport, untyped. Two facts emerged during the 2026-05-13/14 implementation push:

1. **Mainland-China reachability is path-dependent.** Cloudflare Email Routing (free, easy) is the obvious default outside CN but is unreliable when the founder is reading mail from inside mainland China. Tencent Enterprise Email (TEE) paired with DNSPod-hosted DNS is the dominant reliable path inside mainland China. The choice depends on which DNS provider holds `esphome.cloud`'s authoritative zone and where the founder physically reads mail.
2. **Auto-reply byte-equality became a hard contract.** `reference/interface-contracts.md` IC-2..IC-5 require the 4 auto-reply bodies to be byte-equal to `tests/fixtures/email_autoreplies/{feedback,security,hello,support}.txt`. Mailbox-UI-configured replies drift silently across vendor UI changes; that drift is unobservable until a user catches a mismatched body and reports it.

ADR-002 (three mutually-exclusive channels) and ADR-007 (feedback@ auto-redirect) both depend on the auto-reply copy carrying load-bearing structural messages; degrading byte-equality is a slow leak in those decisions.

## Drivers

- D1. ADR-005 (office-hours-only SLA): auto-reply copy must disclose the SLA tier — copy is load-bearing
- D2. ADR-007 (feedback@ redirect): auto-reply must steer toward GitHub — copy is load-bearing
- D3. Mainland-China reachability for the founder's read path (in-CN ↔ out-of-CN is a known variable)
- D4. Auto-reply body byte-equality to `tests/fixtures/email_autoreplies/*.txt` (IC-2..IC-5 contract)
- D5. <$20/mo total cost ceiling (`governance/budget.md` envelope)
- D6. Operational simplicity for a single founder (<5h/wk ops budget per `governance/performance-engineering.md`)

## Considered Options

1. **TEE-only (single-path via Tencent Enterprise Email + DNSPod).** Auto-replies authored in TEE's per-mailbox web UI. Free first year (≤5 mailboxes), then ¥35/mailbox/yr × 4 ≈ ¥140/yr ≈ $20/yr. Native mainland-CN reachability. Weakness: web-UI-stored copy drifts silently against the fixture contract.
2. **CF-only (single-path via Cloudflare Email Routing + Cloudflare Email Worker).** Copy lives in `email-router.js` (~140 LoC), free indefinitely, requires CF nameservers authoritative for `esphome.cloud`. Outbound auto-reply via MailChannels Send API (free for CF Workers). Weakness: degraded mainland-CN reachability if founder reads mail in-CN.
3. **DNSPod free email forwarding + Resend free-tier outbound (single-path zero-cost hybrid).** Inbound: DNSPod-hosted MX with free email-forwarding rules (one rule per alias → founder's free @163.com/@qq.com inbox). Outbound auto-reply: Resend free tier (100 emails/day, supports SPF/DKIM on custom domain). Free indefinitely; native mainland-CN inbound. Weakness: glues two providers; DNSPod forwarding offers no native auto-reply trigger so the outbound side needs a separate trigger mechanism (IMAP-poll, webhook bridge, or self-hosted MX).
4. **Path-flexible: pick one of {TEE / DNSPod+Resend / CF Email Worker} at deploy time; all three deploy the same byte-equal auto-replies from a single fixture-set source-of-truth.** All three satisfy IC-2..IC-5; operator picks based on where DNS lives + where the founder reads mail + acceptable operational complexity.

## Decision

We chose **Option 4** — path-flexible inbound mail with `tests/fixtures/email_autoreplies/*.txt` as canonical source. Three currently-supported paths; operator picks at deploy time based on (a) where DNS lives, (b) where the founder reads mail, (c) acceptable operational complexity, (d) annual cost tolerance.

- **Path A (TEE + DNSPod)** — native Tencent integration; setup wizard auto-creates MX + SPF + DKIM at DNSPod in one click; per-mailbox auto-reply via TEE web UI. Free year-1 (≤5 mailboxes), ~¥35/mailbox/yr × 4 ≈ $20/yr after. Native mainland-CN reachability. UI-drift mitigated by `tests/repo/autoreply_sla.sh` running monthly to grep SLA-disclosure strings. **Currently the default for in-CN founder.**
- **Path A2 (DNSPod free email forwarding + Resend free-tier outbound)** — fully-zero-cost mainland-CN-native fallback. Inbound: DNSPod free forwarding rules (one rule per alias → founder's existing free @163.com/@qq.com inbox). Outbound auto-reply: Resend free tier (100 emails/day; SPF/DKIM on `esphome.cloud`). The outbound trigger mechanism is the open design question for Path A2 — three sub-options:
  - (a) IMAP-poll founder's primary inbox, match alias-tagged subjects, POST auto-reply via Resend API (~50 LoC Python on a free-tier cron host or laptop) — simplest and the recommended sub-option if Path A2 is activated
  - (b) Replace DNSPod forwarding with Resend Inbound (or similar inbound-webhook service that fires a webhook), then trigger the Resend outbound from the webhook handler
  - (c) Self-hosted Postfix + procmail autoresponder on a CN VPS — undermines the "free" framing because VPS rent ≈ ¥30/mo
  Path A2 is **documented but not deployed** as of 2026-05-14; activation is gated on T6 (Path A cost or CF reachability change) — see Re-evaluation triggers below.
- **Path B (CF Email Routing + Worker)** — `cloudflare-worker/email-router.js` inlines the 4 fixture bodies; outbound auto-reply via MailChannels Send API (free for CF Workers); `FORWARD_TO` env var routes the inbound copy to the founder's primary inbox. Mainland-CN reachability ⚠️ but mostly OK. **Currently the default for out-of-CN founder.**

All three paths must deliver byte-equal auto-replies from `tests/fixtures/email_autoreplies/*.txt`. The operational runbook `docs/email-mailbox-setup.md` covers Path A + Path B end-to-end (DNS, deploy, verify); Path A2's runbook is owed when/if it's activated.

## Consequences

**Positive:**
- Founder can be in or out of mainland China; reachability is preserved either way (D3)
- Code-as-source-of-truth on Path B eliminates silent UI-drift on the auto-reply contract (D4)
- Path A2 documented as fully-zero-cost mainland-CN-native fallback simultaneously satisfying D3 + D5 (the only path that does both)
- Cost stays within budget on all three paths (Path A2 + Path B free; Path A free year-1 then ~$20/yr — well under the $20/mo cap)

**Negative:**
- Three deployment runbooks to maintain in `docs/email-mailbox-setup.md` (Path A + Path B currently documented; Path A2 owed when/if activated)
- Path A's UI-configured auto-replies need monthly byte-equality drift audits via `tests/repo/autoreply_sla.sh`
- Vendor lock-in to Cloudflare on Path B; if Email Routing or MailChannels Send API gates or deprecates, fallback is Path A or Path A2
- MailChannels Send API rate limits are not publicly documented; observed safe for ≤100 outbound/day, may not survive a spam burst (cross-reference R-05)
- Path A2's outbound trigger mechanism (IMAP-poll-then-reply or webhook bridge) is not yet specified or implemented; activating Path A2 requires solving this AND running the V5 G1 evidence run
- Resend free tier 100/day cap may be tight in a spam-burst scenario on Path A2 (current expected volume <10/day so comfortable in steady state)

**Risks:**
- New **R-11** (CF Email Routing vendor lock-in / silent rate-limit) — file in `governance/risk-register.md` during Phase-1 sync
- Conditional **R-12** (Path A2 trigger mechanism complexity vs reliability) — file only if Path A2 is activated; documented here for completeness
- Existing **R-04** (SMTP cred leak) widens scope on Path A: TEE SMTP password joins the secret rotation matrix (`reference/runbook.md` §S-1)

## Validation

- **V1.** Both active paths deliver auto-reply byte-equal to `tests/fixtures/email_autoreplies/<alias>.txt` for each of `feedback`/`security`/`hello`/`support`; verified by `tests/integration/email_autoreply_smoke.py` (G1-owed: one run per active path, 5/5 sends per alias receive byte-equal auto-reply within 60s).
- **V2.** Path A drift detection: `tests/repo/autoreply_sla.sh` runs monthly; if any of `office hours` or `24 hours` strings disappear from any auto-reply, founder alerted via monthly review log (already authored; live).
- **V3.** Email infrastructure cost ≤ $20/yr (Path A) or $0/yr (Path B); reconciled monthly in `governance/budget.md` §1.
- **V4.** Path B Worker source `cloudflare-worker/email-router.js` MUST inline the 4 fixture bodies byte-equal at deploy time; CI gate `tests/repo/worker_fixture_sync.sh` (G1-owed) diffs Worker `AUTO_REPLY_BODIES` map against the fixture files and exits non-zero on drift.
- **V5.** Path A2 (if activated): the outbound trigger mechanism (IMAP-poll-then-reply or webhook bridge) MUST deliver byte-equal auto-reply within 60s p95 of inbound mail receipt; verified by `tests/integration/email_autoreply_smoke.py` running against Path A2's outbound path (the same test as V1, parameterized by `--path a2`).
- **V6.** Path A2 (if activated): Resend daily outbound count stays under 100/day soft cap; alarming if 7-day rolling p95 crosses 80/day (telemetry from Resend dashboard scraped into `governance/budget.md` §1).

## Re-evaluation triggers

- **T1.** CF Email Routing or MailChannels Send API announces deprecation, paid-tier introduction, or rate-limit changes affecting `esphome.cloud` volume → revisit Path B; Path A or Path A2 becomes mandatory.
- **T2.** TEE annual cost crosses $50/yr (currently ¥35/mailbox/yr × 4 ≈ $20/yr) → revisit Path A; Path A2 or Path B becomes mandatory.
- **T3.** Founder relocates permanently (in-CN ↔ out-of-CN) → re-rank paths by reachability.
- **T4.** Email volume crosses 100/day (currently <10/day) → re-test Path B's MailChannels free-tier reliability AND Path A2's Resend free-tier headroom; consider paid MailChannels, paid Resend, or Mailgun.
- **T5.** Any auto-reply fixture drifts >1 line from byte-equal in any active path for 30 consecutive days → re-evaluate the byte-equality contract; either tighten CI enforcement or relax to "structural equivalence" (and update IC-2..IC-5 accordingly).
- **T6.** Path A2 activation: if Path A first-year free period expires AND founder rejects the ~$20/yr ongoing cost, OR if Path B's mainland-CN reachability degrades below 95% delivery for 7 consecutive days → activate Path A2; pick a sub-option (a/b/c above) + run V5+V6 evidence + author Path A2 runbook in `docs/email-mailbox-setup.md`.

## Links

- Implements driver(s): D1 (ADR-005), D2 (ADR-007); ratifies the Phase-1 G1 email gate
- Related ADRs: ADR-005 (office-hours-SLA — informs auto-reply copy), ADR-007 (feedback@ redirect — informs feedback@ body)
- Phase: 1 (Task 1.3 `email-mailboxes` provisioning + auto-reply byte-equality)
- Implementation (Path B, live): `cloudflare-worker/email-router.js`, `cloudflare-worker/wrangler.toml`
- Implementation (Path A, live): `docs/email-mailbox-setup.md` Path A section (DNSPod + TEE)
- Implementation (Path A2, not yet deployed): TBD when activated — likely a small IMAP-poll script + Resend API integration; Path A2 runbook owed in `docs/email-mailbox-setup.md` post-activation
- Tests (live): `tests/repo/autoreply_sla.sh`
- Tests (G1-owed): `tests/integration/email_autoreply_smoke.py`, `tests/repo/worker_fixture_sync.sh`
- Risk register: introduces R-11 (CF vendor lock-in); conditional R-12 (Path A2 trigger complexity, only if activated); widens R-04 scope to TEE SMTP password (Path A) or Resend API key (Path A2)
