# Launch announcement — 中文长篇 (知乎 / 即刻长文)

> **目标平台:** 知乎专栏文章 + 即刻长文。
> **发布时间:** 与 EN 短 + CN 短同一个周二 10:00 UTC+8。
> **回复窗口:** 当周 + 之后所有周二 office hours。

---

## 标题

「esphome.cloud BETA 上线 —— 一个人做一个 ESP32 固件向导,AI agent 原生」

## 引子

我一个人,做了一个东西叫 esphome.cloud。

它是一个浏览器向导加远程编译流水线,专注于做一件事:把"我有一块 ESP32-S3,
想用 LVGL + WiFi 写一个能联网的小屏幕设备"这种想法,变成一个能立刻烧录的固件。
单设备焦点,不做大规模运维。

今天 BETA 上线。这篇是介绍 + 反馈通道说明。

## 为什么做这个

ESP32 生态有 ESP-IDF(官方),有 PlatformIO,有 ESPHome(面向 HomeAssistant),
还有越来越多 AI 编码工具(Claude Code、Cursor、Codex CLI)。
但是把它们串起来用,新手依然要踩一堆坑:

- 装 ESP-IDF 失败(macOS Homebrew Python 不兼容)
- WebRTC / WiFi 配置出问题(防火墙 / NAT)
- ESP32-S3 + LVGL 跑不起来(PSRAM 没开)
- MCP 工具配置不对(Claude Code 链路断在哪一步)

这些坑每个都不大,但加起来劝退了很多本来很有想法的人。
esphome.cloud 把这些路径默认对了 —— 你打开向导,选板子、选外设、选 Solution
模板,远程编译,几分钟后下载 flash bundle 直接烧录。

AI agent 原生是另一条主轴:Claude Code / Cursor / Codex CLI / OpenCode / Claude Desktop
都能通过 MCP 直接调用 espctl 来 build / flash / monitor,目前一共暴露 34 个 MCP 工具。

## 不做什么

清单很短,但是必须说清楚 ——

- **不做 OTA 集群管理。** 单设备烧录是 esphome.cloud 的 scope,300 台设备的
  灰度发布不是。需要这能力请用 ESPHome dashboard / Mender / 商用 fleet manager。
- **不做多租户团队协作。** 没有组织、没有 RBAC、没有审计日志。BETA 期是单用户
  + 单会话;商用 Self-hosted 版本(BETA 之后)按独立实例处理团队边界,
  不在产品里加 RBAC。
- **不做实时聊天通道。** 没有任何实时聊天工具的官方群。所有交流都在
  GitHub Discussions / Issues 或 4 个邮箱(feedback@ / security@ /
  hello@ / support@)上异步发生。我一个人,带不动多通道实时回复。

## 反馈通道

- **GitHub Issues**: bug 报告、功能请求、构建失败
  → https://github.com/esphome-cloud/community/issues
- **GitHub Discussions**: 使用问题、想法、晒作品、Solution 模板分享
  → https://github.com/esphome-cloud/community/discussions
- **邮箱**: security@esphome.cloud (24 hours SLA) /
  feedback@ / hello@ (Tuesday office hours 14-16 UTC+8)

AI 助手会在 90 秒内对每个 Issue / Discussion 做第一道分诊 —— 命中 KNOWN_ISSUES
直接给答案 + 关闭;像 bug 的会要求补全 Job ID + 日志;
security_critical 会同步发邮件呼叫人工。

人工集中处理在 **周二 14:00-16:00 UTC+8 office hours**。这一个时间块就是 SLA,
其它时间窗口我会不在。

## 关于中文用户的特殊路径

GitHub 在中国大陆访问偶有抖动,Gitee 镜像(`gitee.com/esphome-cloud/community`)
作为只读备份每 6 小时同步一次。如果你完全不想注册 GitHub,
可以直接发邮件到 `feedback@esphome.cloud`,内容会进入和 GitHub Issues 同一套
AI 分诊流程,响应 SLA 一致。

完整中文 GitHub 注册指南 + 加速方法见
[`docs/github-signup-cn.md`](../github-signup-cn.md)。

## 为什么我一个人能做这个

老实说,如果是 5 年前我做不了。

2026 年的不同是:Cursor + Claude Code 这一套 AI agent 工具
把 ESP-IDF 配置、Rust no_std 嵌入式 + ESP-WIFI-Mesh / TCP/IP 协议栈、
WebRTC 信令、QUIC 中继这种系统级东西的实现门槛降到了 "一个人 + 一些咖啡因 +
office hours 节奏" 能扛住的程度。esphome.cloud 自己用了这套工具链构建,
是它产生的第一批生产代码之一。社区仓库的 AI 分诊则用 DeepSeek v4-flash
(性价比 + 地理分散性考虑;详见 ADR-008)。

## 接下来 7 天

会做的事:
- 紧盯每条反馈,周二集中回。
- 每天读一次 AI 误分类 —— 累计 ≥3 条新 KNOWN_ISSUES 后会更新 triage 提示词。
- 第 7 天发一篇 "Week 1 in numbers" 总结(AI handle-rate / 成本 / 总数 / Spam 占比)。

不会做的事:
- 不会开聊天群。
- 不会承诺 24/7 响应。
- 不会扩 scope 接住"能不能加 X"的请求 ——
  那些都得走标准的 feature request 流程。

如果这个调性听起来还算对你的胃口,
[github.com/esphome-cloud/community](https://github.com/esphome-cloud/community)
见。

---

_2026-05-13 · 由 esphome.cloud 创始人撰写 · 1 人 · Tuesday office hours_
