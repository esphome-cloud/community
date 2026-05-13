# Launch announcement — EN short

> **Target platform:** Twitter/X (single post, ≤280 chars + 1 image).
> **Scheduled posting time:** Tuesday 10:00 UTC+8.
> **Reply window:** the same Tuesday's 14:00-16:00 UTC+8 office hours block.

---

## Draft (post body)

```
esphome.cloud BETA is live: browser wizard → remote build → flash for ESP32
firmware, single-device focus, AI-agent-native (MCP everywhere). I'm one
person; reply cadence is Tuesday 14-16 UTC+8 office hours. Feedback lane:
github.com/esphome-cloud/community
```

Character count: 271 of 280.

## Companion image

A screenshot of the wizard mid-build with a Solution template active. No
faces, no chat avatars — just the product surface.

## Reply playbook for the first 4 hours after posting

- **"Realtime chat?"** — "No realtime chat by design. Reply on the GitHub
  thread, AI acks within 90s, human replies Tuesday office hours."
- **"Pricing?"** — "BETA is free. Paid tiers (Pro / Pro+ / Business /
  Self-hosted) come post-BETA — no commitments yet."
- **"How does this differ from ESPHome?"** — "Different problem: ESPHome is
  declarative YAML for HomeAssistant-style devices; esphome.cloud is a
  generic ESP32 firmware compositor with AI-agent-native MCP tooling.
  Complement, not replacement."
- **"Can I use it for fleet management?"** — "Out of scope, see the README's
  'What I Won't Do' section. ESPHome dashboard / Mender / commercial fleet
  managers are better fits."

## Cross-references

- `docs/launch/cn-short.md` — Chinese sibling.
- `docs/launch/cn-long-form.md` — 知乎 / 即刻 long-form sibling.
- `tests/repo/launch_posts_invariants.sh` asserts "I'm one person" anchor +
  no banned closed-channel strings across all 3 drafts.
