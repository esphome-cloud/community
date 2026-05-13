# Launch announcement — 中文短篇 (即刻 / Twitter/X CN)

> **目标平台:** 即刻 单条 / Twitter/X 中文圈(≤140 中文字 + 1 张配图)。
> **发布时间:** 周二 10:00 UTC+8(早于 office hours,方便 14:00 后集中回复)。
> **回复窗口:** 当周二 14:00-16:00 UTC+8 office hours。

---

## 草稿(贴文正文)

```
esphome.cloud BETA 上线了:浏览器向导 → 远程编译 → 烧录,专注单设备 ESP32 固件,
AI agent 原生(到处都是 MCP)。我一个人在维护,集中回复时间是周二 14-16 UTC+8
office hours。反馈通道在 GitHub:github.com/esphome-cloud/community
```

字符数:约 117 中文字符,符合 140 字以内限制。

## 配图

向导构建中状态截图,搭配一个 Solution 模板。无人脸、无聊天头像 —— 只展示产品本体。
与 EN 短篇使用同一张图(按 即刻 / X 缩略图比例剪裁)。

## 发布后头 4 小时的回复手册

- **"为什么不开聊天群?"** —— 异步设计;一切公开消息流转都走 GitHub Discussions / Issues,
  AI 90 秒内分诊,人工集中在周二 office hours。
- **"价格?"** —— BETA 期免费。付费分级(Pro / Pro+ / Business / Self-hosted)
  在 BETA 之后才上线 —— 目前不做承诺。
- **"和 ESPHome 有什么区别?"** —— 不同问题域:ESPHome 是面向 HomeAssistant
  的声明式 YAML;esphome.cloud 是通用 ESP32 固件组装器,AI agent 用 MCP 工具操作。
  两者互补,不是替代。
- **"能用于设备集群管理吗?"** —— 不在范围内,详见 README 的 "What I Won't Do" 章节。
  集群管理推荐 ESPHome dashboard / Mender / 商用 fleet manager。

## 不变量

- 包含 **"我一个人"**(personhood 锚点,launch_posts_invariants.sh 会校验)
- 不含任何即时聊天工具名(ADR-001 的封闭通道清单一律不出现 —— 包括上面回复手册里用通用名替代)

## 交叉引用

- `docs/launch/en-short.md` —— Twitter/X 英文版同期发布。
- `docs/launch/cn-long-form.md` —— 知乎 / 即刻 长文版。
- `tests/repo/launch_posts_invariants.sh` 校验 "我一个人" 锚点 + 0 个被禁聊天工具名。
