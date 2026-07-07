# GitHub 注册与访问指南(中国大陆用户)

> 本文档适用于在中国大陆使用 esphome.cloud 的开发者。GitHub 是 esphome.cloud
> community 的唯一权威来源(详见 [ADR-004](../governance/adr-004-github-source-of-truth.md)),
> Gitee 仅作为只读镜像存在。本文档帮助你完成 GitHub 账号注册、解决常见的网络
> 与风控问题、以及在确实无法访问 GitHub 时使用替代反馈通道。

---

## 一、账号注册

### 邮箱选择

- **优先 163 邮箱**(`@163.com` / `@126.com`):接收 GitHub 验证邮件成功率较高,
  且不依赖境外网络。
- **Outlook 邮箱**(`@outlook.com` / `@hotmail.com`):微软家也行,海外邮件链路稳定。
- **iCloud 邮箱**(`@icloud.com`):有 Apple ID 的用户可以使用。
- **Gmail 谨慎选择**:Gmail 接收 GitHub 验证邮件需要稳定的境外网络;
  如果当下无法访问 mail.google.com,验证流程会卡住。

### 用户名建议

- 使用 **3-15 字符纯英文+数字**,避免中文拼音过长(GitHub URL 在分享时会更清爽)。
- 不要包含敏感词(GitHub 反诈骗系统在含敏感词的用户名上会更激进)。
- 一旦注册成功,改用户名会让所有旧 URL 跳转 30 天,所以一开始就选好。

### 避开节假日高峰

GitHub 的反诈骗系统在中国节假日(春节、国庆)前后对中国大陆 IP 的注册会更敏感,
误判率更高。如果可以,在工作日内完成注册。

### 邮箱验证

注册后 GitHub 会发送验证邮件。如果 10 分钟内没收到:

1. 检查垃圾邮件文件夹。
2. 检查邮箱服务商是否拦截 `noreply@github.com`(163 邮箱有时会临时拦截)。
3. 在 GitHub 设置中重新发送验证邮件。

---

## 二、风控失败恢复

如果注册时账号被立即标记 "Suspended" 或 "Account locked",原因通常有三类:

- **IP 信誉问题**:你的网络出口 IP 在 GitHub 黑名单上(共享 VPN / 校园网常见)。
- **邮箱信誉问题**:邮箱域名最近被批量注册过(部分一次性邮箱服务受影响)。
- **User-Agent 异常**:使用自动化工具或老旧浏览器注册时容易触发。

### 申诉流程

1. 访问 https://support.github.com/contact?tags=docs-accounts
2. 主题填 "Account Suspension Appeal"
3. 用中性英文说明使用场景(学习开源、个人项目等),**不要写商业用途**(会被升级审核)。
4. 等待 1-3 个工作日的回复。

### 重新注册注意

- 换一个 IP(切换网络环境,例如手机热点)。
- 换一个邮箱。
- 间隔至少 24 小时再尝试。

---

## 三、GitHub 加速访问

国内访问 github.com 偶尔慢甚至超时是普遍现象。以下 **≥3 种** 方法可改善,
任选其一或组合使用。

### 方法 1:hosts 文件

将 GitHub 域名手动解析到稳定可达的 IP。推荐工具:

- **GitHub520 项目**(`github.com/521xueweihan/GitHub520`):自动维护 hosts 列表。
- **ipaddress.com**:手动查询 GitHub 各域名的可用 IP。

修改 `/etc/hosts` (Linux/macOS) 或 `C:\Windows\System32\drivers\etc\hosts` (Windows),
追加形如:

```
140.82.114.4    github.com
185.199.108.133 raw.githubusercontent.com
```

### 方法 2:ghproxy / FastGit 反向代理

将 `github.com` 替换为代理域名以加速 raw 文件、release 下载、git clone:

- `ghproxy.com/https://github.com/...` 用于 git clone 和文件下载
- `FastGit.org` 是 GitHub 的镜像,可作为 git remote 的备选
- `bgithub.xyz`、`hub.fastgit.xyz` 等社区维护的镜像也可选

### 方法 3:Chrome 浏览器扩展

- **SwitchyOmega**:配合本地代理转发 GitHub 流量。
- **GitHub 加速类扩展**:在 Chrome 扩展商店搜索 "GitHub 加速" 或 "GitHub 镜像",
  选择评分高且最近更新过的。

### 方法 4:Cloudflare CDN(进阶)

部署一个 Cloudflare Worker 转发 GitHub 流量到自己专属的代理域名,稳定性最高
但需要 Cloudflare 账号 + 域名。

---

## 四、esphome.cloud 反馈通道

注册完成后,使用 esphome.cloud community 仓库的标准反馈路径:

- **报告 Bug**:在
  [Issues / Bug Report](https://github.com/esphome-cloud/community/issues/new?template=bug.yml)
  填表(附 Job ID 后投递)。
- **使用问题、想法、展示**:在
  [Discussions](https://github.com/esphome-cloud/community/discussions) 对应分类下发帖。
- **安全或隐私问题**:发邮件到 `security@esphome.cloud`(24 小时内确认)。
- **商业 / 合作 / 媒体**:发邮件到 `hello@esphome.cloud`(周二 office hours 回复)。

人工回复集中在 **周二 14:00-16:00 UTC+8**(office hours),
AI 助手会在 90 秒内做第一道分诊。详见仓库 [README](../README.zh-CN.md#响应时间)。

---

## 五、拒绝 GitHub:替代反馈通道

如果你出于隐私、合规、或者实在无法访问 GitHub 等原因不想注册账号,有两条替代路径:

### 替代 1:直接发邮件到 feedback@esphome.cloud

这是 esphome.cloud 反馈通道的"无 GitHub 兜底入口"。邮件内容会进入 AI 分诊流程,
和 GitHub Issues 走同一套响应 SLA(周二 office hours)。

注意事项:

- 邮件主题写清楚问题概要(例如 `[Bug] WebRTC 数据通道无法打开`),AI 分诊更准确。
- 邮件正文里包含必要信息:重现步骤、Job ID(如适用)、报错日志片段。
- 邮件不会公开到 GitHub Issues —— 如果你的问题对其他用户也有价值,
  人工回复时会请你考虑授权我们把内容(脱敏后)同步到 Discussions。

### 替代 2:网页反馈页(`esphome.cloud/feedback`)

[`https://esphome.cloud/feedback`](https://esphome.cloud/feedback) 是一个无需
账号的网页入口,内置邮件直达按钮以及 security@ / hello@ / Gitee 镜像各通道
的简要说明。点击页面上的"发送邮件"按钮会自动打开本机的邮件客户端,内容
会进入 `feedback@esphome.cloud` 邮箱并走同一套 AI 分诊流程。

未来版本计划替换为完整的"无账号、不打开邮件客户端就能提交"的网页表单
(详见 [`docs/web-form-fallback-design.md`](web-form-fallback-design.md))。
在该完整表单上线之前,如果你的邮件客户端工作良好,直接走替代 1 的纯邮件
路径同样有效。

### 关于实时聊天

esphome.cloud BETA 期不提供任何实时聊天通道(详见
[ADR-001](../governance/adr-001-public-by-default.md))。一切异步发生在 GitHub
Discussions / Issues 或上述邮箱中。

---

## 六、Gitee 只读镜像

`gitee.com/esphome-cloud/community` 是仓库的只读镜像,主要用途:

- **不翻墙读源码 / 文档**:本指南本身就是从这里被你读到的。
- **不翻墙读已回答的问题**:Discussions / Issues 内容会随 6 小时一次的同步流到 Gitee。
- **Discussions 静态镜像**:Gitee 不支持原生 Discussions，但 Discussions
  内容会自动转换为只读 Markdown 页面，存放在 Gitee 镜像的
  [`docs/discussions/`](https://gitee.com/esphome-cloud/community/tree/main/docs/discussions)
  目录中，按分类（Q&A / Ideas / Show & Tell / Announcements）整理。

镜像是 **只读** 的 —— Gitee 上不能新建 Issue 或 Discussion(创建后我们也不会同步回 GitHub),
请通过上述方法之一在 GitHub 侧操作。

---

## 七、问题与反馈本指南

本指南本身如果有遗漏、过时、或者错误,可以:

1. 在 Discussions / Ideas 分类下发帖(英文或中文均可)。
2. 直接发邮件到 `feedback@esphome.cloud`,标题写 `[CN guide]` 前缀。

文档更新日期:2026-05-13。
