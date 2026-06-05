# esphome.cloud / community

**[中文](#你想做什么)** | **[English](README.md)**

> [esphome.cloud](https://esphome.cloud) BETA 的反馈、想法、Bug 报告专区。

此仓库是 esphome.cloud BETA 用户唯一的反馈入口。由**我**独自维护，AI 助手（DeepSeek v4-flash）处理第一道分诊，让我能把时间花在 AI 做不到的事情上。

不确定该走哪个通道？下面的表格一目了然。想知道多久能收到回复？**响应时间**部分给出了诚实的预期。如果 GitHub 访问不稳定（中国大陆用户），下面的 **Gitee 镜像**可以帮到你。

---

## 你想做什么？

选一行匹配你的意图。只有**三条通道**（Discussions / Issues / Email）—— 每种目的对应一条通道。

| 你想... | 请去 |
|---|---|
| 问"怎么做"的问题 | [Discussions / Q&A](https://github.com/esphome-cloud/community/discussions/categories/q-a) |
| 分享一个想法 | [Discussions / Ideas](https://github.com/esphome-cloud/community/discussions/categories/ideas) |
| 展示你做的项目 | [Discussions / Show & Tell](https://github.com/esphome-cloud/community/discussions/categories/show-and-tell) |
| 报告 Bug | [Issues / Bug Report](https://github.com/esphome-cloud/community/issues/new?template=bug.yml) |
| 提交功能请求 | [Issues / Feature Request](https://github.com/esphome-cloud/community/issues/new?template=feature.yml) |
| 报告安全问题 | [security@esphome.cloud](mailto:security@esphome.cloud) |
| 私下沟通（商业、合作、媒体） | [hello@esphome.cloud](mailto:hello@esphome.cloud) |

---

## 响应时间

| 通道 | 响应 SLA | 窗口 |
|---|---|---|
| security@esphome.cloud | 24 小时内 | 每天 |
| Discussions / Issues / feedback@ | 周二 office hours | 每周，14:00-16:00 UTC+8 |
| hello@esphome.cloud | 周二 office hours | 每周，14:00-16:00 UTC+8 |

完整 SLA 矩阵见 [`policies/sla-policy.md`](policies/sla-policy.md)。所有 AI 回复在公开频道末尾都会标注 `— Triaged by AI; reply to reopen for human review` —— 在帖子里回复即可在下一个周二窗口获得人工审核。

---

## 我不做的事

- **BETA 期间没有实时聊天** —— GitHub + Email 之外的第二注意力面超出了每周 5 小时的运营预算。想法分享在 Discussions，Bug 在 Issues，没有任何东西关在私密的实时房间里。
- **没有 OTA 设备群管理** —— esphome.cloud BETA 只做单设备向导→构建→刷写。300 台设备的生产级 OTA 是另一个产品；ESPHome 自带的 dashboard 或商业工具更适合。
- **没有多租户团队协作** —— 没有组织/团队工作区、没有 RBAC、没有审计日志。如果 Phase 4+ 的自托管合同需要这种形态，会以独立产品面交付，不会通过给 BETA 打补丁来实现。

BETA→GA 路线图及各阶段的准入标准见 [`governance/release-gate.md`](governance/release-gate.md)。

---

## 中国大陆用户（Gitee 镜像）

只读镜像位于 [`gitee.com/esphome-cloud/community`](https://gitee.com/esphome-cloud/community)，每 6 小时同步一次。依据 [ADR-004](governance/adr-004-github-source-of-truth.md)，GitHub 是唯一权威来源，Gitee 单向承载源码 + 文档 + 已回复的问答。提交仍在 GitHub 侧进行。

GitHub 注册与加速指南：[`docs/github-signup-cn.md`](docs/github-signup-cn.md)。不用 GitHub 的兜底方案：发邮件到 `feedback@esphome.cloud`。

---

## AI 如何辅助

大多数公开帖子的第一回复来自 DeepSeek v4-flash 分诊助手（[`scripts/triage.py`](scripts/triage.py)；详见 [ADR-008](governance/adr-008-deepseek-v4-flash-triage.md)）。它会打标签、引用 `KNOWN_ISSUES`、关闭重复帖，仅在安全报告时通知人工。回复帖子即可重新打开进行人工审核。完整的分诊策略在脚本中 —— 没有任何隐形审核。

## 行为准则

见 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。简短版：有耐心、有价值、不在 office hours 外 at 维护者、中英文都欢迎、骚扰零容忍。

## 许可证

文档：CC BY 4.0。脚本（`scripts/`）：MIT。详见 [LICENSE](LICENSE)。
