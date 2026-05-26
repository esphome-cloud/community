# Tester B — 42y coffee-shop owner (Hangzhou)

## Persona

- Age 42, small business owner running a coffee shop in Hangzhou
- Recently heard about ESP32-based devices for monitoring shop
  temperature/humidity
- Used GitHub maybe 3 times in life
- Primary language: Mandarin Chinese; basic professional English

## Methodology

- Skim live README at `https://github.com/esphome-cloud/community` in ~30s
- CN-primary reader: skip the EN section, scroll directly to 中文版 header

## 5 prompts + routing decisions

### Prompt 1: "我开了一家咖啡店,想用这个监控室温、湿度还有冰箱温度。能用吗?哪里有教程?"

- **Route**: Discussions / Q&A
- **Reasoning**: 表里写着 "How-to questions" 走 Q&A,我这是问"怎么用",
  对号入座。
- **Confidence**: ✅

### Prompt 2: "Hi, our company has 50 shops in Zhejiang, we want to know if you have an enterprise / paid version with formal SLA support"

- **Route**: hello@esphome.cloud
- **Reasoning**: Commercial/partnership 那一行,50 家店明显是商务合作,
  直接发邮件最稳。
- **Confidence**: ✅

### Prompt 3: "I followed the wizard for adding a humidity sensor, it gave error code -5 and no further info"

- **Route**: Issues / Bug Report
- **Reasoning**: 有错误码就是 bug,表里 Bug Report 明确。
- **Confidence**: ✅

### Prompt 4: "我希望增加一个手机短信通知功能,温度超过阈值就发短信"

- **Route**: Issues / Feature Request
- **Reasoning**: "希望增加"就是新功能请求,表里有 Feature Request。
  但其实我也犹豫了一下要不要发 Ideas 讨论区 —— README 没说"还没定型
  的想法"和"明确功能请求"怎么区分。
- **Confidence**: ❓ unsure (Issues vs Ideas boundary)

### Prompt 5: "We export to EU and need GDPR data-residency promises — who do I talk to?"

- **Route**: hello@esphome.cloud
- **Reasoning**: 不是 security 漏洞,也不是 bug,看着像商务 + 合规,
  商务邮箱兜底。**不太确定**,GDPR 算 security 还是 commercial?
  README 没明说 regulatory / 合规问题归哪边。
- **Confidence**: ❓ unsure (GDPR / compliance not in decision graph)

## Tally

- **Confident**: 3 / 5
- **Unsure-but-defensible**: 2 / 5
- **Wrong**: 0 / 5
- **Strict %**: 60% (below the 80% gate strict reading)
- **Defensible %**: 100%

## Pain points

- ✅ 清楚:routing table 一目了然,中英双语很贴心,Gitee 镜像对国内用户
  友好。
- ❌ 不清楚:Feature Request (Issues) 和 Ideas (Discussions) 的边界没解释。
  GDPR / 数据合规这类 regulatory 问题没有专门一栏,只能猜走 hello@。
  没有"自托管 / 付费版"明确入口,50 家店的商业咨询全靠 hello@ 一个
  邮箱兜底,心里没底。
- ⚠️ office hours 周二 14-16 UTC+8 看到了,但我提问可能要等一周 ——
  对小商户来说节奏偏慢,商务合作可能等不起。
