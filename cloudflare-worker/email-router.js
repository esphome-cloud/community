/**
 * Cloudflare Email Worker — esphome-cloud/community auto-replies.
 *
 * Phase 1 Task 1.3 / IC-2..IC-5. ADR-009 Path B reference implementation.
 * NOT currently deployed — the live path is Path A2 (ImprovMX → 163 →
 * scripts/auto_reply_poll.py on 3qMq → Resend) as of 2026-05-25. This file
 * exists so that an operator can fall back to a CF Worker binding all 4
 * aliases if Path A2 degrades:
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
    subject: '我们收到了你的反馈(下次请直接用 GitHub)',
    body: `感谢来信 esphome.cloud / community。

这个邮箱有人值守,但绝大多数你想反馈的内容,GitHub 都更快、更公开、更多其他
用户能看到 —— 而且 AI 助手会在 ~90 秒内给出第一条回复:

  Bug 报告 + 功能请求:
    https://github.com/esphome-cloud/community/issues

  提问 + 想法 + 作品展示:
    https://github.com/esphome-cloud/community/discussions

人工跟进集中在**每周二 14:00-16:00 UTC+8 的 office hours**(一周一次,
没有实时聊天)。

如果是**安全相关问题**,请改投 security@esphome.cloud
(24 小时内致谢确认,每天有效,不仅限周二)。

如果是**私下沟通**(商业、合作、媒体咨询),请改投 hello@esphome.cloud。

—— esphome.cloud / community 自动回复
`,
  },
  'security': {
    subject: '已收到安全报告(24 小时内致谢确认)',
    body: `感谢报告这个安全或隐私问题。

我们承诺在 **24 小时内** 对所有安全报告致谢确认 —— 每天有效,不局限于
office hours。首次回复将给出以下三者之一:

  - 一个已分诊的严重程度评估
  - 一个请你补充信息的问题清单
  - 一份协调披露(coordinated disclosure)的时间线建议

我们遵循协调披露原则。如果还没附上,请补充:

  - 问题的简短描述
  - 复现步骤(或概念验证 PoC,如有)
  - 你对影响范围 + 受影响组件的评估
  - 你希望使用的披露线程沟通渠道
  - 修复发布时是否公开致谢你(可选)

在修复发布之前,我们不会公开披露任何细节,并会给你协调披露时机的机会。

—— esphome.cloud / community 安全响应组
`,
  },
  'hello': {
    subject: '你好 —— 关于回复时间的说明',
    body: `感谢来信 hello@esphome.cloud。

这个邮箱专门处理**不适合公开**的话题:Self-hosted 合作咨询、商业合作、
媒体采访,以及其他私下沟通。

几条快速重定向,确保不同话题进到正确的入口:

  Bug 报告 + 功能请求:
    https://github.com/esphome-cloud/community/issues

  提问 + 想法 + 作品展示:
    https://github.com/esphome-cloud/community/discussions

  安全 / 隐私报告:
    security@esphome.cloud(24 小时内致谢确认)

属于 hello@ 的内容,人工回复会安排在**每周二 14:00-16:00 UTC+8 的 office
hours**,一周一次 —— 没有实时回复预期。

—— esphome.cloud / community 创始人邮箱自动回复
`,
  },
  'support': {
    subject: '已收到 support 工单',
    body: `感谢联系 esphome.cloud / community support。

此邮箱**仅服务 Self-hosted 合同伙伴**。响应窗口为**工作日 周一至周五
09:00-18:00 UTC+8 的 office hours**(并非 24 小时);窗口外的请求排队
到下一个工作日。

  Self-hosted: 按合同响应

**BETA 期注意事项**:BETA 期间付费 support 不对外开放。此邮箱仅提供给
现有 Self-hosted 合作伙伴。如果你是误发到此地址、内容属于一般咨询,
请改投 hello@esphome.cloud。

—— esphome.cloud / community support 响应组
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
