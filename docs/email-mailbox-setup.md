# Email mailbox setup (Phase 1 Task 1.3 live)

> Operational runbook for provisioning the 4 esphome.cloud mailboxes
> (`feedback@`, `security@`, `hello@`, `support@`) per IC-2..IC-5 and ADR-005.
> Estimated time end-to-end: **45-60 min** (most of it DNS propagation wait).
>
> Last updated: 2026-05-14.

## Architecture (depends on which DNS provider hosts esphome.cloud)

This runbook supports TWO inbound paths. Pick the one that matches your
current DNS provider; outbound + verification steps are the same for both.

### Path A — DNS on DNSPod (recommended for mainland China founders)

```
   any sender   →    esphome.cloud MX    →    Tencent Enterprise Email   →    founder's primary inbox
                    (records on DNSPod)         (4 mailboxes,                  (forwarded copy)
                                                 free 1st year)
                                                       │
                                                       │ also fires per-mailbox
                                                       ▼
                                              auto-reply (configured in
                                              TEE web UI, byte-equal to
                                              tests/fixtures/email_autoreplies/<alias>.txt)
                                                       │
                                                       ▼
                                              auto-reply → back to original sender
```

Cost: ¥0/yr for first year (under 5 mailboxes), then ¥35/mailbox/yr.
Best mainland-China reachability + native DNSPod integration.

### Path B — DNS on Cloudflare (recommended for founders outside CN)

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

**Why these stacks:**
- **Path A — Tencent Enterprise Email (TEE)**: native to DNSPod (both are
  Tencent products; setup wizard auto-creates MX + SPF + DKIM at DNSPod
  with one click). Per-mailbox auto-reply UI with full Subject + Body
  customization. Reliable from mainland China.
- **Path B — Cloudflare Email Routing**: FREE forever. Requires CF
  nameservers authoritative for esphome.cloud (= migrating DNS to CF).
- **Cloudflare Email Worker**: intercepts mail before forwarding, calls
  MailChannels for custom auto-replies. Path B only.

**Other alternatives** if neither A nor B fits:
- **ImprovMX Premium ($9/mo)** — drop-in: keep DNSPod, add MX records
  pointing at ImprovMX, configure auto-reply in their UI.
- **Mailgun Flex** (~$0.80/1K incl. inbound) — pay-as-you-go.
- **Postmark Streams ($15/mo)** — slickest UI, most expensive.
- **Self-host postfix on debian1301** — free but ~2-4h setup;
  Tencent Cloud may block inbound port 25 by default (unblock request needed).

## Prerequisites

### For Path A (DNSPod + TEE) — recommended for mainland founders

- [ ] DNS for `esphome.cloud` is on DNSPod (verify: `dig +short NS esphome.cloud`
  shows `.dnspod.net` or `.dnsv1.com` etc. nameservers).
- [ ] Tencent Cloud account with DNSPod access; the founder's account also
  has access to the same Tencent Cloud organization (single-account is fine
  for solo).
- [ ] Decide founder primary inbox (e.g. `founder-personal@163.com`) for
  forwarded mail + the `ALERT_EMAIL` for pager.
- [ ] Auto-reply fixture bodies in this repo at
  `tests/fixtures/email_autoreplies/{feedback,security,hello,support}.txt`.

### For Path B (Cloudflare) — recommended for non-CN founders

- [ ] Willing to migrate DNS from current provider to Cloudflare (free; 24-48h
  propagation). NOT recommended if you're on DNSPod and live in mainland China.
- [ ] Cloudflare account with Email Routing + Workers enabled (free tier).
- [ ] Founder's primary inbox decided.
- [ ] Same fixture bodies as Path A.

---

## Path A — DNSPod + Tencent Enterprise Email

### Step A.1 — Create Tencent Enterprise Email tenant (10 min)

1. Sign in to Tencent Cloud → search "企业邮箱" / "Enterprise Email" →
   open the Tencent Enterprise Email console.
2. Click "立即开通" / "Activate" → choose the free tier (5 mailboxes
   under "Lite" / 轻量版). First year is free; renewal at ¥35/mailbox/yr.
3. Bind the `esphome.cloud` domain.
4. The wizard prompts you to add MX records. Because DNSPod and TEE are
   both Tencent products, click "一键添加" / "Add automatically" — TEE
   will inject the required records into DNSPod via your linked account.

Expected DNSPod records after auto-add:
```
MX   esphome.cloud   mxbiz1.qq.com    priority 5
MX   esphome.cloud   mxbiz2.qq.com    priority 10
TXT  esphome.cloud   "v=spf1 include:spf.mail.qq.com ~all"
TXT  <selector>._domainkey.esphome.cloud   "v=DKIM1; ..."  (TEE generates a selector)
```

Verify: `dig +short MX esphome.cloud` should return the two `mxbiz*.qq.com`
hosts within ~5 minutes (DNSPod's TTL is short).

### Step A.2 — Create the 4 mailboxes (5 min)

In TEE console → 邮箱管理 / Mailbox management → 新建邮箱 / Create:

| Address | Display name | Initial password |
|---|---|---|
| `feedback@esphome.cloud` | esphome.cloud Feedback | (any; founder won't log in here directly) |
| `security@esphome.cloud` | esphome.cloud Security | (any) |
| `hello@esphome.cloud` | esphome.cloud Hello | (any) |
| `support@esphome.cloud` | esphome.cloud Support | (any) |

Don't enable 2FA on these — they're never logged into interactively.

### Step A.3 — Configure forwarding to founder inbox (5 min)

For each of the 4 mailboxes:

1. Log in to TEE webmail as that mailbox (use the initial password).
2. 设置 / Settings → 邮件转发 / Mail forwarding → enable.
3. Forward to: `<founder primary inbox>` (e.g. `founder-personal@163.com`).
4. Check "保留邮件副本" / "Keep a copy" (so TEE retains the original for the
   auto-reply trigger).
5. Save.

### Step A.4 — Configure auto-reply per mailbox (15 min)

For each of the 4 mailboxes, in TEE webmail:

1. 设置 / Settings → 自动回复 / Auto-reply → 启用 / Enable.
2. **Subject** — paste the first line (minus `Subject: `) from the matching
   fixture:

   | Mailbox | Subject (paste exactly) |
   |---|---|
   | `feedback@` | `We received your feedback (and please use GitHub)` |
   | `security@` | `Security issue received (24-hour acknowledgement SLA)` |
   | `hello@` | `Hello — and a quick note on response times` |
   | `support@` | `Support request received` |

3. **Body** — paste lines 3+ (everything after the blank line) from the
   matching `tests/fixtures/email_autoreplies/<alias>.txt`. Preserve
   whitespace exactly.
4. **回复频率 / Reply frequency** — set to "每个发件人每天一次" / "Once per
   sender per day" (default). The byte-equal acceptance test sends one
   trial per mailbox, so once-per-day is sufficient.
5. Save.

**Verification command after Steps A.1-A.4:**

```bash
# From any external mailbox (your personal Gmail / 163), send a test:
echo "test body" | mail -s "test subject" feedback@esphome.cloud

# Within 60s, that sender mailbox should receive an auto-reply with:
#  Subject: "We received your feedback (and please use GitHub)"
#  Body: matches tests/fixtures/email_autoreplies/feedback.txt
# The founder inbox should ALSO receive the forwarded copy of the original.
```

Skip to **Step 4 — Wire SMTP secrets for the pager** below.

---

## Path B — Cloudflare Email Routing + Worker

### Step B.1 — Enable Cloudflare Email Routing (5 min)

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

### Step B.2 — Add DKIM + DMARC (10 min, optional but recommended)

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

### Step B.3 — Deploy the Email Worker for auto-replies (20 min)

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

### Recommended for the DNSPod + TEE founder: use 163.com SMTP-SSL

If your founder primary inbox is `<user>@163.com`, you already have free
authenticated SMTP-SSL on port 465. Wire it directly — no separate provider
or per-email cost.

1. Log in to <https://mail.163.com> → 设置 / Settings → POP3/SMTP/IMAP →
   enable SMTP service.
2. Click "客户端授权密码" / "Client authorization password" → generate one
   (NOT your account password — this is the 16-char app token).
3. Set GH Secrets:

```bash
gh secret set SMTP_HOST     --repo esphome-cloud/community --body 'smtp.163.com'
gh secret set SMTP_USER     --repo esphome-cloud/community --body '<founder-user>@163.com'
gh secret set SMTP_PASSWORD --repo esphome-cloud/community --body '<the 16-char auth password from step 2>'
gh secret set ALERT_EMAIL   --repo esphome-cloud/community --body '<founder-user>@163.com'
```

Note: 163.com SMTP-SSL is port 465 — matches the `smtplib.SMTP_SSL(host, 465)`
call hardcoded in `scripts/triage.py`. No code change needed.

### Alternative: outlook.com SMTP

`smtp-mail.outlook.com:587` (STARTTLS, not SSL). Requires changing
`smtplib.SMTP_SSL(SMTP_HOST, 465)` in `scripts/triage.py` to
`smtplib.SMTP(SMTP_HOST, 587)` + `smtp.starttls()`. Not recommended
unless you have a specific reason to avoid 163.com.

### Alternative: dedicated transactional provider

If you don't want the pager to be tied to your personal mailbox:

```bash
# Mailgun free tier (100 emails/mo)
gh secret set SMTP_HOST     --body 'smtp.mailgun.org'
gh secret set SMTP_USER     --body 'postmaster@<your-mg-domain>'
gh secret set SMTP_PASSWORD --body '<provider-issued-password>'
gh secret set ALERT_EMAIL   --body '<founder-user>@163.com'
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
