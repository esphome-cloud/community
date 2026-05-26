# Tester A — 35y home-automation hobbyist

## Persona

- Age 35, smart-home tinkerer
- No programming background
- Comfortable in both English and Mandarin Chinese (CN-primary)
- First time seeing this repo

## Methodology

- Skim live README at `https://github.com/esphome-cloud/community` in ~30s
- CN-primary reader: skip the EN section, scroll to 中文版 (~line 97)

## 5 prompts + routing decisions

### Prompt 1: "我想用这个东西配合我家的小米空气净化器一起用,怎么开始?"

- **Route**: Discussions / Q&A
- **Reasoning**: 这是"怎么开始"的问题,表里 Q&A 就是问问题用的。
- **Confidence**: ✅

### Prompt 2: "Hey, I made this cool dashboard for my home with esphome.cloud — here are some pics!"

- **Route**: Discussions / Show & Tell
- **Reasoning**: 表里写得很清楚 "Show projects" 走这里,晒图刚好对上。
- **Confidence**: ✅

### Prompt 3: "The wizard freezes for like 30 seconds whenever I select ESP32-S3 as the board"

- **Route**: Issues / Bug Report
- **Reasoning**: 卡住 30 秒明显是 bug,不是想法。
- **Confidence**: ✅

### Prompt 4: "你们能不能加一个深度睡眠模式?我那些用电池的传感器需要省电"

- **Route**: Issues / Feature Request
- **Reasoning**: "能不能加" = 功能请求,表里 Feature Request 对得上。
  不过我有点犹豫 —— 这种"想要个功能"的想法 vs Discussions / Ideas
  我分不太清,但表里写"Feature requests"明确走 Issues,我就听它的。
- **Confidence**: ❓ unsure (defensible — Feature Request vs Ideas boundary)

### Prompt 5: "I think I found a way to bypass authentication on the device pairing flow"

- **Route**: security@esphome.cloud
- **Reasoning**: 绕过认证听起来就是安全问题,表里有 24h SLA 的就是这个
  邮箱,不能发公开 issue。
- **Confidence**: ✅

## Tally

- **Confident**: 4 / 5
- **Unsure-but-defensible**: 1 / 5
- **Wrong**: 0 / 5
- **Strict %**: 80%
- **Defensible %**: 100%

## Pain points

- Feature Request (Issues) 和 Share ideas (Discussions / Ideas) 对我这种
  非程序员来说界线模糊 —— "加个深度睡眠" 到底算成型的需求还是只是个
  idea?README 没解释两者区别。
- 整个表只有一行一行的对应,没给例子;#1 那种 "怎么搭配小米设备"
  我也不是 100% 确定算 Q&A 还是 Ideas(最后选了 Q&A 因为是"怎么开始"
  的问句)。
