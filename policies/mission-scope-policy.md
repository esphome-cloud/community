# Mission scope policy

> **Source of truth for what esphome.cloud builds, and what it explicitly
> doesn't.** Referenced by `scripts/triage.py`'s system prompt (the AI triage
> uses this to classify feature requests as `out_of_scope`) and by
> `.github/ISSUE_TEMPLATE/feature.yml` (the markdown reminder steers writers
> away from out-of-scope asks before they file). If you edit this doc, the
> grep gates in `tests/repo/mission_scope_phrases.sh` and
> `tests/repo/out_of_scope_pillars.sh` will catch missing anchors.
>
> Last reviewed: 2026-05-13 (Phase 3 Task 3.1).

## Mission alignment

esphome.cloud is a single-device wizard + remote build + flash pipeline for
ESP32-family microcontrollers, designed for solo developers and small embedded
shops who want to compose firmware out of well-tested Solution templates rather
than wrestle ESP-IDF from scratch. The mission is **lower the activation energy
from idea → flashed device** for one device at a time, with AI-native tooling
(MCP servers + browser wizard + Claude Code integration) doing the heavy
lifting around configuration and build pipelines.

The mission is **not** to be a generic IoT platform, a fleet-management product,
or a team-collaboration tool. Those problems are real — they're just not ours.
We say so out loud, here, so that contributors and prospective users have an
honest picture.

## In scope:

The following capability surfaces are in-scope for esphome.cloud BETA and
in-scope for the foreseeable post-BETA roadmap. Bug reports + feature requests
in these areas are welcome and triaged on the normal cadence.

- **ESP32-family firmware build.** Remote build pipeline (espctl + Aegis agent),
  IDF version pinning, sdkconfig generation, flash bundle assembly. Single
  device at a time; multi-device coordination is explicitly NOT in scope.
- **Solution templates.** Composable board × peripheral × use-case configs
  contributed by the community (Discussions / Solutions Share) and curated.
  A Solution is a complete recipe for one device's firmware; it is not a
  fleet-deployment manifest.
- **Browser wizard (esphome.cloud).** The web UI for assembling a single-device
  firmware: pick board, pick peripherals, pick a Solution, build, flash. The
  wizard's output is one config + one binary per session.
- **MCP integration.** espctl-mcp, idfmcp, and the browser-side MCP surface
  (`@aegis/espctl-web`) — so AI coding agents can build / flash / monitor
  firmware as first-class tool calls. Includes the 34 MCP tools currently
  exposed.
- **AI agent native.** Claude Code, Cursor, Codex CLI, OpenCode, Claude Desktop
  are first-class clients. Bug reports tagged with `client/<name>` get the
  same triage path as wizard-originated bugs.

## Out of scope:

The following capability surfaces are explicitly **out of scope** for the
esphome.cloud BETA and for the post-BETA roadmap through at least 2027. Feature
requests in these areas will be classified `out_of_scope` by AI triage and
closed politely with a pointer to this policy. The list is curated: each entry
exists because it is a real ask we receive, and naming it explicitly here is
faster than re-litigating per-issue.

- **OTA fleet management.** Pushing firmware updates to 100+ devices in the
  field with rollout status, automatic rollback on failure, A/B canary deploys.
  This is a different product (ESPHome's own dashboard, Mender, Memfault,
  commercial fleet managers). esphome.cloud BETA is single-device only;
  OTA is single-device flash, not multi-device push.
- **Device management.** Inventory tracking, remote-config push, device-state
  telemetry collection, device-group operations. The closest analog is the
  ESPHome dashboard. esphome.cloud knows about *one* device — the one
  currently in the browser session.
- **Team collaboration.** In-product team collaboration features —
  multi-tenant organizations, RBAC, shared workspaces, audit trails, SSO —
  are not on the roadmap. esphome.cloud is single-user during BETA; the
  commercial Self-hosted tier (post-BETA) handles team boundaries via
  discrete instances, not via in-product RBAC.
- **IoT platform features.** Cloud-side data ingestion (MQTT brokers, time-series
  DBs), rules engines, dashboard widgets, alerting on device telemetry, app-side
  device integration (Home Assistant connectors etc.). These belong to IoT
  platforms (Home Assistant, AWS IoT Core, etc.); esphome.cloud generates the
  firmware that talks to those platforms but is not itself one.

## Why these are excluded

Three reasons, in order of weight:

1. **Founder bandwidth.** This project is operated by one founder with a
   5-hour-per-week budget. Building OTA fleet management would consume the
   entire bandwidth for 6+ months and produce a worse product than ESPHome's
   own dashboard.
2. **Strategic clarity.** A wizard + build pipeline is a complete product on
   its own; adding fleet management blurs the value prop and makes it harder
   for the right users to find us.
3. **Honest market segmentation.** The customers who genuinely need OTA fleet
   management have different software-quality, support-SLA, and pricing
   requirements. Trying to serve both segments halfway produces a tool that
   serves neither well.

## Re-evaluation triggers

If any of these conditions hold, this policy reopens for review and may admit
a new in-scope capability:

- **T1.** A specific Self-hosted commercial contract requires one of the
  out-of-scope capabilities as a deliverable. Contract revenue + scope expansion
  decided together.
- **T2.** 50+ feature requests per month consistently land in the same
  out-of-scope bucket for 3 consecutive months, AND there's a clean MVP that
  fits in 1 month of founder bandwidth. Document the MVP + go.
- **T3.** A maintainer-grade upstream (e.g., ESPHome itself) ships the
  out-of-scope capability and integrates with esphome.cloud-generated firmware,
  removing the need for us to build it.

If a trigger fires, the policy update spawns a new ADR documenting the decision
and updates the AI triage prompt + feature.yml markdown reminder to match.

## Cross-references

- ADR-002 (3-channel mutual exclusion) — the channel-routing is a sister concept
  to the scope policy: clear cuts in both dimensions (which channel + which
  capabilities) keep the founder's time budget viable.
- ADR-007 (feedback redirect) — out-of-scope feature requests in `feedback@`
  email are redirected to the public Issues channel where the rejection is
  visible to other potential reporters.
- IC-7 (feature.yml shape) — references this policy via the markdown reminder
  containing "out of scope" + at least one of OTA / device management / team
  collaboration / IoT platform features.

## Edit log

- 2026-05-13 — initial lock-in (Phase 3 Task 3.1).
