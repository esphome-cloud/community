# esphome-cloud-email-router

> **Reference implementation only — NOT currently the deployed path.**
>
> The 4 `esphome.cloud` aliases are served by **Path A2** as of 2026-05-25:
>
>   ImprovMX inbound (5 alias rules) → `ff4415@163.com` →
>   `scripts/auto_reply_poll.py` on 3qMq (systemd timer
>   `aegis-auto-reply.timer`, every 5 min, CN-region) →
>   Resend outbound (`ai-triage@esphome.cloud`).
>
> 163 geo-blocks GitHub Actions runners, so CN-region execution is mandatory
> for the polling host. This Cloudflare Worker (Path B) remains checked in as
> a documented fallback per ADR-009. See
> [`governance/adr-009-cloudflare-email-worker.md`](../governance/adr-009-cloudflare-email-worker.md)
> for the path tradeoffs and `../docs/email-mailbox-setup.md` Path A2 section
> (owed — being written).

Cloudflare Email Worker that handles incoming mail for the 4 esphome.cloud
aliases: forwards to the founder inbox + fires an auto-reply per IC-2..IC-5.

See `../docs/email-mailbox-setup.md` for the end-to-end runbook (DNS, Cloudflare
Email Routing setup, Worker deployment, verification).

## Files

- `email-router.js` — the Worker source. ~140 lines. Inlines the 4 auto-reply
  bodies; keep in sync with `../tests/fixtures/email_autoreplies/*.txt`.
- `wrangler.toml` — Cloudflare Wrangler config for `wrangler deploy`.

## Deploy

Via dashboard: see `../docs/email-mailbox-setup.md` Step 3.

Via wrangler:
```bash
npm install -g wrangler
wrangler login
wrangler deploy
# Then via dashboard: bind feedback@/security@/hello@/support@ to the Worker
# (Wrangler doesn't yet support email-trigger bindings).
```

## Local test

`wrangler dev --test-scheduled` can't simulate incoming mail. To test the
auto-reply bodies match the fixtures byte-equal, run:
```bash
node -e "
const w = require('./email-router.js').default;
const map = (await import('./email-router.js')).default.AUTO_REPLY_BODIES;
// (export AUTO_REPLY_BODIES from the module to make this testable)
"
```

The cleaner test: deploy + use mail-tester.com to verify SPF/DKIM/DMARC + a
manual send to each alias to confirm auto-reply body matches the fixture.
