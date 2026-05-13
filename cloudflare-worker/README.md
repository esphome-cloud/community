# esphome-cloud-email-router

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
