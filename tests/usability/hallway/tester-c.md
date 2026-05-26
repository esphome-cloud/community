# Tester C — 21y industrial-design 大三 student (Shenzhen)

## Persona

- Age 21, university student in Shenzhen
- Major: industrial design (NOT CS / EE)
- Has used GitHub for class assignments but never filed an issue
- Bilingual but reads CN faster than EN
- Just discovered esphome.cloud while building a class project

## Methodology

- Skim live README at `https://github.com/esphome-cloud/community` in ~30s
- CN-first student: skip EN sections, focus on 中文版 from ~line 97 onward

## 5 prompts + routing decisions

### Prompt 1: "我做了一个课程项目,用 esphome.cloud 控制了 8 个 LED 灯,想分享给大家看看"

- **Route**: Discussions / Show & Tell
- **Reasoning**: 表格里写得很清楚 "Project showcase",我这个就是想给
  大家看看,不是求助也不是 bug。
- **Confidence**: ✅

### Prompt 2: "Quick question — does esphome.cloud work with ESP8266 or only ESP32 series?"

- **Route**: Discussions / Q&A
- **Reasoning**: 就是"怎么做 / 支持吗"的问题,表格里"Questions (怎么做)"
  对应 Q&A。
- **Confidence**: ✅

### Prompt 3: "我点击 'add device' 按钮没有任何反应,试了好几次都不行 (Chrome 浏览器)"

- **Route**: Issues / bug.yml
- **Reasoning**: 功能坏了 = bug 报告,有浏览器信息可以填模板。
- **Confidence**: ✅

### Prompt 4: "你们的 logo 看起来很像另一个开源项目的 logo,可能有商标问题?"

- **Route**: hello@esphome.cloud (guessed)
- **Reasoning**: README 表格里没"商标 / 法律"这一行。security@ 是安全
  漏洞 24h SLA,感觉不太对。Issues 也不像 bug。猜 hello@ 因为它写的是
  "commercial, partnerships, press" —— 商标算商业 / 法律事务?
- **Confidence**: ❓ unsure (legal / IP not in decision graph)

### Prompt 5: "我有个想法 —— 能不能加一个 'export to Home Assistant config' 的功能"

- **Route**: Issues / feature.yml
- **Reasoning**: 表格写 "Feature requests → Issues / Feature Request"。
  不过我有点犹豫要不要先发 Discussions / Ideas 探讨一下…但表格里
  "Ideas sharing" 和 "Feature requests" 分成两栏了,既然是具体功能
  请求,走 feature.yml 应该没错。
- **Confidence**: ✅ (slightly hesitant)

## Tally

- **Confident**: 4 / 5
- **Unsure-but-defensible**: 1 / 5
- **Wrong**: 0 / 5
- **Strict %**: 80%
- **Defensible %**: 100%

## Pain points

- 商标 / 法律这种 "灰色地带" 完全没提 —— 不是 security 也不是 bug
  更不是 feature,只能猜 hello@。
- Ideas vs Feature Request 的界限对我这种新人不太直观,如果 README
  给一两句话举例说明会更好。
