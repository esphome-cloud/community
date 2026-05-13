# Email mailbox setup (Phase 1 Task 1.3 live)

> Operational runbook for provisioning the 4 esphome.cloud mailboxes
> (`feedback@`, `security@`, `hello@`, `support@`) per IC-2..IC-5 and ADR-005.
> Estimated time end-to-end: **45-60 min** (most of it DNS propagation wait).
>
> Last updated: 2026-05-14.

## Architecture

```
   any sender                 esphome.cloud MX                       founder's primary inbox
   ──────────  →   Cloudflare Email Routing  →    forward    →    e.g. founder@163.com
                          (free, inbound)                          (you read mail here)

                              │ also fires
                              ▼
                   Cloudflare Email Worker
                          (free; <50 LoC)
                              │
                              ▼
                   MailChannels Send API (free for CF)
                              │
                              ▼
                   auto-reply  →  back to the original sender
```

**Why this stack:**
- **Cloudflare Email Routing**: FREE forwarding. Catch-all + per-alias rules.
- **Cloudflare Email Worker** (Email Workers feature): intercepts incoming
  mail BEFORE forwarding, gives us full control to send custom auto-replies.
- **MailChannels Send API**: free outbound mail for Cloudflare-hosted Workers.
  No SMTP server to operate; no separate cost.
- **Total cost: $0/mo** for the 4-mailbox path. Compare to Postmark $15/mo,
  Mailgun $35/mo, etc.

**Alternative architectures** (if Cloudflare isn't an option):
- **ImprovMX Premium ($9/mo)** — drop-in for inbound forward + auto-reply
- **Mailgun Flex** (~$0.80/1K incl. inbound) — pay-as-you-go
- **Postmark Streams ($15/mo)** — slickest UI, most expensive
- **Tencent Enterprise Email** (~¥35/user/year) — best inside-China reachability

This runbook assumes Cloudflare. The DNS records section is provider-agnostic;
only the Worker setup is CF-specific.

## Prerequisites

- [ ] DNS for `esphome.cloud` is on Cloudflare (or you're willing to migrate it).
  Verify: `dig +short NS esphome.cloud` returns Cloudflare nameservers.
- [ ] Cloudflare account with Email Routing + Workers enabled (free tier).
- [ ] Founder's primary inbox decided (e.g. `founder-personal@163.com` or
  similar — destination for forwarded mail + the `ALERT_EMAIL` for pager).
- [ ] Auto-reply fixture bodies in this repo at
  `tests/fixtures/email_autoreplies/{feedback,security,hello,support}.txt`.

## Step 1 — Enable Cloudflare Email Routing (5 min)

1. Cloudflare dashboard → `esphome.cloud` → **Email** → **Email Routing**.
2. Click **Get started**. CF auto-creates these DNS records:
   ```
   MX   esphome.cloud   route1.mx.cloudflare.net   priority 35
   MX   esphome.cloud   route2.mx.cloudflare.net   priority 73
   MX   esphome.cloud   route3.mx.cloudflare.net   priority 90
   TXT  esphome.cloud   "v=spf1 include:_spf.mx.cloudflare.net ~all"
   ```
3. **Custom addresses** → **Create address** × 4:

   | Address | Destination |
   |---|---|
   | `feedback@esphome.cloud` | (your founder inbox, e.g. `founder@163.com`) |
   | `security@esphome.cloud` | same |
   | `hello@esphome.cloud` | same |
   | `support@esphome.cloud` | same |

4. Verify destination address (CF emails a confirmation link to the founder
   inbox — click to accept).

**Verify Step 1**:
```bash
dig +short MX esphome.cloud
# expect: 3 lines with cloudflare.net hostnames

# Send a test email from any sender to feedback@esphome.cloud.
# Should arrive at the founder inbox within ~10s. No auto-reply yet (Step 3 wires that).
```

## Step 2 — Add DKIM + DMARC (10 min, optional but recommended)

These records make outbound auto-replies pass spam checks at the recipient.

Cloudflare dashboard → DNS → Records → add:

```
# DKIM (Cloudflare auto-generates the selector under Email → Email Routing → DNS records)
# Copy the TXT record CF provides; it'll look like:
TXT   cf2024-1._domainkey.esphome.cloud   "v=DKIM1; ..."

# DMARC (start permissive, tighten later)
TXT   _dmarc.esphome.cloud   "v=DMARC1; p=quarantine; rua=mailto:dmarc@esphome.cloud; ruf=mailto:dmarc@esphome.cloud; pct=100; adkim=s; aspf=s"
```

Verify with `https://www.mail-tester.com/` (free; send mail from
ai-triage@esphome.cloud to the unique address it gives you, get a score).
Target ≥9/10 before declaring done.

## Step 3 — Deploy the Email Worker for auto-replies (20 min)

The Worker code is at `cloudflare-worker/email-router.js` in this repo. It:

1. Receives the inbound email.
2. Forwards to the founder inbox (per CF Email Routing rules).
3. Reads the **destination alias** (`feedback@` vs `security@` vs `hello@` vs `support@`).
4. Looks up the matching auto-reply body from the embedded fixture map.
5. Sends the auto-reply via MailChannels Send API, with `Reply-To: <original-sender>`.

### Deploy via Cloudflare dashboard

1. Cloudflare → **Workers & Pages** → **Create application** → **Create Worker**.
2. Name: `esphome-cloud-email-router`.
3. Click **Edit code**, paste contents of `cloudflare-worker/email-router.js`.
4. **Save and Deploy**.
5. **Settings** → **Triggers** → **Email triggers** → **Bind to email address**:
   bind ALL 4 aliases (`feedback@`, `security@`, `hello@`, `support@`)
   to this Worker.
6. **Settings** → **Variables** → add `FROM_ADDRESS = ai-triage@esphome.cloud`
   (the From: header that auto-replies use).

### Deploy via wrangler CLI (alternative)

```bash
npm install -g wrangler
cd cloudflare-worker
wrangler login
wrangler deploy
```

`wrangler.toml` (next to email-router.js) declares the email trigger
bindings; `wrangler deploy` wires them automatically.

## Step 4 — Wire SMTP secrets for the pager (5 min)

The 4 inbound mailboxes are done. The OUTBOUND pager (security_critical
→ ALERT_EMAIL) needs its own SMTP credentials. The placeholders set
earlier need to become real values.

**Recommended outbound path:** MailChannels via the same Cloudflare Worker.
Add a second Worker route for `/pager/send` that triages.py calls instead
of SMTP. (Future Phase 0.5 improvement; see ADR-008 T1 thinking.)

**Practical interim path:** use any SMTP provider's free tier for the pager
only. Mailgun's free tier gives 100 emails/mo — plenty for security pages.

Once the SMTP provider is set up:
```bash
gh secret set SMTP_HOST     --repo esphome-cloud/community --body 'smtp.mailgun.org'
gh secret set SMTP_USER     --repo esphome-cloud/community --body 'postmaster@<your-mg-domain>'
gh secret set SMTP_PASSWORD --repo esphome-cloud/community --body '<provider-issued-password>'
gh secret set ALERT_EMAIL   --repo esphome-cloud/community --body 'founder@163.com'
```

## Step 5 — Verify end-to-end (15 min)

```bash
# 1. From any sender (e.g. your personal Gmail), send 4 test emails:
#    a@gmail.com → feedback@esphome.cloud
#    a@gmail.com → security@esphome.cloud
#    a@gmail.com → hello@esphome.cloud
#    a@gmail.com → support@esphome.cloud

# 2. For each, verify within 60s the sender receives an auto-reply with:
#    - Subject matching the first line of tests/fixtures/email_autoreplies/<alias>.txt
#    - Body byte-equal (whitespace-normalized) to the rest of the fixture

# 3. Verify forwarding: founder's inbox receives all 4 forwarded copies (one per alias).

# 4. Run the Task 1.3 acceptance checks:
cd /Users/feiyu/go/src/github.com/esphome-cloud/community
bash tests/repo/autoreply_sla.sh     # already PASSES offline; rerun for sanity
# The byte-equal mailbox arrival test is currently manual — IMAP-based
# automation deferred to a Phase 1.3 follow-up.

# 5. Run the Task 0.5 live pager smoke (validates the OUTBOUND SMTP path):
python3 tests/integration/pager_smoke.py --live
# Expect 5/5 send within 60s; manually verify ALERT_EMAIL received 5 emails
# with Subject: [CRITICAL] esphome.cloud issue #851..#855
```

## Phase 1 G1 #1 + #2 ticked when

- [ ] All 4 aliases receive + forward to founder inbox
- [ ] All 4 aliases fire auto-reply within 60s with byte-equal body
- [ ] `support@` is NOT linked from any public website (BETA constraint)
- [ ] `tests/integration/pager_smoke.py --live` 5/5
- [ ] `tests/security/no_smtp_leak.sh` returns 0 hits

After Steps 1-5 + the verification list:
- Phase 1 G1 #1 (all 5 Phase-1 task acceptances) → 5/5 (1.3-live now ticked)
- Phase 1 G1 #2 (end-to-end smoke 3/3) → 2/3 (email + Issue paths green;
  Discussion path needs DeepSeek API key to fire which it now has)
- Phase 0 G0 #3 (SMTP pager 5/5 + security-only 45 trials) → flips from
  offline-only to live-verified

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `dig MX esphome.cloud` returns nothing or wrong values | DNS not propagated yet | wait 5-15 min; check from a different resolver |
| Sender doesn't receive auto-reply | Email Worker not bound to the alias | CF → Worker → Triggers → confirm all 4 aliases bound |
| Sender's mailbox marks auto-reply as spam | SPF/DKIM/DMARC not configured | Step 2 + mail-tester.com score check |
| Founder inbox receives forwarded mail but no auto-reply | Worker fires forward path before auto-reply path | check Worker logs in CF dashboard; verify MailChannels Send API call succeeded |
| `pager_smoke.py --live` says SMTP auth failed | SMTP_PASSWORD wrong or domain not verified at provider | provider UI → re-issue creds; verify domain SPF/DKIM at provider |
| Auto-reply body doesn't byte-match fixture | Worker fixture map drifted from `tests/fixtures/email_autoreplies/*.txt` | re-deploy Worker; auto-reply bodies are inlined at build time |

## Cross-references

- ADR-005 (office-hours-only SLA) — anchors the SLA matrix in each auto-reply.
- ADR-007 (feedback@ redirect) — anchors the `feedback@` auto-reply content.
- IC-2..IC-5 (`reference/interface-contracts.md`) — wire-format spec each auto-reply must match.
- `tests/fixtures/email_autoreplies/*.txt` — the canonical auto-reply bodies (4 files).
- `policies/sla-policy.md` §S-1 — secret rotation cadence (quarterly).
- runbook.md Chapter 4 — SMTP failure incident response.
