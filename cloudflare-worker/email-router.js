/**
 * Cloudflare Email Worker — esphome-cloud/community auto-replies.
 *
 * Phase 1 Task 1.3 / IC-2..IC-5. Deployed to a CF Worker bound to all 4 aliases:
 *   feedback@esphome.cloud  security@esphome.cloud
 *   hello@esphome.cloud     support@esphome.cloud
 *
 * Flow per incoming email:
 *   1. Forward to founder inbox (via CF Email Routing — done by message.forward()).
 *   2. Determine which alias was hit from message.to.
 *   3. Send auto-reply via MailChannels Send API (free for CF Workers).
 *      Body is byte-equal to tests/fixtures/email_autoreplies/<alias>.txt
 *      in the community repo (kept in sync manually; see deploy notes).
 *
 * Env vars (set in Worker → Settings → Variables):
 *   FROM_ADDRESS   — sender for auto-replies, e.g. 'ai-triage@esphome.cloud'
 *   FORWARD_TO     — founder inbox, e.g. 'founder@163.com'
 *
 * Tests/fixtures source-of-truth lives in the community repo. When the
 * fixtures change, re-deploy this Worker. wrangler-managed deploys can
 * read the fixtures at build time from a parallel checkout; the inline
 * map below is the manual mirror.
 */

const AUTO_REPLY_BODIES = {
  'feedback': {
    subject: 'We received your feedback (and please use GitHub)',
    body: `Thank you for writing to esphome.cloud / community.

This mailbox is monitored, but for almost everything you might want to file,
GitHub is faster, more visible to other users, and gets you an AI-assisted
first reply within ~90 seconds:

  Bug reports + feature requests:
    https://github.com/esphome-cloud/community/issues

  Questions + ideas + showcase:
    https://github.com/esphome-cloud/community/discussions

Human follow-up on those channels happens Tuesday during office hours
(14:00-16:00 UTC+8). One window per week, no realtime chat.

If your message is security-related, please re-send to security@esphome.cloud
(24-hour acknowledgement SLA — every day, not just Tuesday).

If your message is private, commercial, or partnership-related, that should
go to hello@esphome.cloud.

— The esphome.cloud / community auto-responder
`,
  },
  'security': {
    subject: 'Security issue received (24-hour acknowledgement SLA)',
    body: `Thank you for reporting a security or privacy concern.

We acknowledge security reports within 24 hours, every day (not just office
hours). Initial response will include either a triaged severity, a request
for clarifying information, or a coordinated disclosure timeline.

We follow coordinated disclosure. If you have not already, please include:

  - A short description of the issue
  - Steps to reproduce (or a proof-of-concept if available)
  - Your assessment of impact and affected components
  - Your preferred contact channel for the disclosure thread
  - Whether we should publicly credit you on resolution (with consent)

We will not disclose details publicly until a fix is shipped and you have
been given the opportunity to coordinate disclosure timing.

— The esphome.cloud / community security desk
`,
  },
  'hello': {
    subject: 'Hello — and a quick note on response times',
    body: `Thanks for writing to hello@esphome.cloud.

This mailbox is for things that should not be public: Self-hosted contract
inquiries, partnership conversations, press requests, and other private
matters.

A few quick redirects so the right things end up in the right places:

  Bug reports + feature requests:
    https://github.com/esphome-cloud/community/issues

  Questions + ideas + showcase:
    https://github.com/esphome-cloud/community/discussions

  Security or privacy reports:
    security@esphome.cloud (24-hour acknowledgement SLA)

For anything that belongs here, a human replies on the Tuesday office hours
window (14:00-16:00 UTC+8). One window per week — no realtime expectations.

— The esphome.cloud / community founder mailbox auto-responder
`,
  },
  'support': {
    subject: 'Support request received',
    body: `Thank you for reaching out to esphome.cloud / community support.

This mailbox serves paid support contracts only. Coverage is business
office hours Mon-Fri 09:00-18:00 UTC+8 (not 24-hour); outside that window
requests queue until the next business day. Per-tier response windows:

  Pro tier:          response within 4 hours, Mon-Fri 09:00-18:00 UTC+8
  Pro+ tier:         response within 2 hours, Mon-Fri 09:00-18:00 UTC+8
  Business tier:     response within 1 hour,  Mon-Fri 09:00-18:00 UTC+8
  Self-hosted tier:  response per contract,   Mon-Fri 09:00-18:00 UTC+8

BETA NOTICE: paid support is not generally available during BETA.
This mailbox is provided to existing Self-hosted contract partners only.
If you reached this address by mistake and your inquiry is general, please
re-send to hello@esphome.cloud instead.

— The esphome.cloud / community support desk
`,
  },
};

export default {
  async email(message, env, ctx) {
    const fromAddress = env.FROM_ADDRESS || 'ai-triage@esphome.cloud';
    const forwardTo   = env.FORWARD_TO   || '';  // set in Worker env

    // 1. Determine which alias was hit.
    const toAddress = (message.to || '').toLowerCase();
    const aliasMatch = toAddress.match(/^([a-z]+)@esphome\.cloud$/i);
    const alias = aliasMatch ? aliasMatch[1] : null;
    if (!alias || !AUTO_REPLY_BODIES[alias]) {
      // Unknown alias — just forward (no auto-reply).
      if (forwardTo) {
        await message.forward(forwardTo);
      }
      return;
    }

    // 2. Forward to founder inbox (catch-all behaviour).
    if (forwardTo) {
      ctx.waitUntil(message.forward(forwardTo).catch((err) => {
        console.error(`forward to ${forwardTo} failed:`, err);
      }));
    }

    // 3. Send auto-reply via MailChannels.
    // Don't auto-reply to bounce / auto-reply / no-reply senders (loop guard).
    const sender = (message.from || '').toLowerCase();
    const loopGuards = ['mailer-daemon', 'no-reply', 'noreply', 'postmaster', fromAddress.toLowerCase()];
    if (loopGuards.some((g) => sender.includes(g))) {
      return;
    }
    // Also skip auto-reply if subject contains "auto-reply" markers (additional loop guard).
    const subj = (message.headers.get('subject') || '').toLowerCase();
    if (subj.startsWith('auto:') || subj.includes('out of office') || subj.includes('auto-reply')) {
      return;
    }

    const { subject, body } = AUTO_REPLY_BODIES[alias];
    const messageId = message.headers.get('message-id');
    const inReplyTo = messageId ? [['In-Reply-To', messageId], ['References', messageId]] : [];

    const mcRequest = {
      personalizations: [{ to: [{ email: message.from }] }],
      from: { email: fromAddress, name: 'esphome.cloud auto-responder' },
      reply_to: { email: fromAddress },
      subject,
      content: [{ type: 'text/plain', value: body }],
      headers: Object.fromEntries(inReplyTo),
    };

    const mcResponse = await fetch('https://api.mailchannels.net/tx/v1/send', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(mcRequest),
    });

    if (!mcResponse.ok) {
      const errText = await mcResponse.text();
      console.error(`MailChannels send failed for ${alias}:`, mcResponse.status, errText);
      // Don't throw — failed auto-reply must not block the forward path.
    }
  },
};
