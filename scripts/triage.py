#!/usr/bin/env python3
"""DeepSeek v4-flash triage for esphome-cloud/community.

Per ADR-008 (supersedes ADR-003) + IC-1 + Phase 0 Task 0.4. Classifies a GitHub
Issue or Discussion into one of 9 categories, emits a JSON decision matching
tests/schemas/triage_output.schema.json, and dispatches actions (labels /
comment / close / SMTP-SSL pager) when not running in --dry-run mode.

Run modes:
  - --dry-run --input <fixture.json>   : real DeepSeek call, no GitHub side-effects
  - --mock-category <cat>              : offline stub (CI + schema tests; no API key needed)
  - GITHUB_EVENT_PATH in env           : live mode under .github/workflows/ai-triage.yml

Observability (Phase 0 Task 0.4 acceptance):
  Every run emits to stderr:
    triage.classified{issue:<N>, category:<C>, cost_usd:<X>}

Invariants enforced client-side (FIRST LINE since DeepSeek json_object does NOT
enforce schemas server-side — under Claude this was defense-in-depth atop
output_config.format.json_schema; now it's the only schema check):
  - page_human=true  iff  category=security_critical
  - duplicate_of is int  iff  category=duplicate (else null)
  - should_close per the IC-1 per-category table
  - response_to_user for security_critical: <=200 chars AND contains "email security@"
"""

from __future__ import annotations

import argparse
import json
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from pathlib import Path
from typing import Any

# ----------------------------------------------------------------------------
# Constants — per IC-1, ADR-008, governance/budget.md, governance/risk-register.md
# ----------------------------------------------------------------------------

MODEL = "deepseek-v4-flash"
DEEPSEEK_BASE_URL = "https://api.deepseek.com"

CATEGORIES = [
    "known_issue", "duplicate", "user_config", "real_bug", "feature_request",
    "question", "security_critical", "out_of_scope", "spam",
]

# IC-1 per-category should_close rule.
SHOULD_CLOSE = {
    "known_issue": True, "duplicate": True, "question": True,
    "out_of_scope": True, "spam": True,
    "real_bug": False, "feature_request": False, "user_config": True,
    "security_critical": False,
}

# Pricing (USD per 1M tokens) for the cost-per-issue log line.
# DeepSeek v4-flash: $0.14 input cache-miss / $0.0028 input cache-hit / $0.28 output.
# Automatic prefix caching — no client-side cache_control markers needed.
PRICE_INPUT_PER_M        = 0.14    # cache-miss input
PRICE_INPUT_CACHE_HIT    = 0.0028  # cache-hit input (~50x cheaper)
PRICE_OUTPUT_PER_M       = 0.28

DISCLOSURE_FOOTER = "\n\n— Triaged by AI; reply to reopen for human review"

# 4 starter KNOWN_ISSUES (ADR-006 in-script KB; Task 0.6 seed).
KNOWN_ISSUES: list[dict[str, str]] = [
    {
        "id": "ISSUE #1",
        "symptom": "ESP-IDF setup fails on macOS with Python venv conflicts; pip cannot install requirements against the system Python.",
        "fix": "Use Espressif's `install.sh` which provisions its own venv under `~/.espressif/`. Do NOT use Homebrew Python or `pip install -r requirements.txt` against the system Python. After install run `. ./export.sh` from a fresh shell.",
    },
    {
        "id": "ISSUE #2",
        "symptom": "WebRTC data-channel never opens; `on_open` times out and ICE shows `no candidate pairs`.",
        "fix": "This is firewall/NAT mediation. Confirm the agent's UDP 49152-49231 range is reachable, and the control plane's TURN at 3478 TCP/UDP is open. From a restricted network, the TURN-relayed path must succeed within ~5s or you will hit the test-pattern fast-fail.",
    },
    {
        "id": "ISSUE #3",
        "symptom": "ESP32-S3 build with LVGL crashes at runtime with `assert failed: heap_caps_malloc_alloc OOM`.",
        "fix": "PSRAM is required for non-trivial LVGL frames. Enable `CONFIG_SPIRAM=y` and `CONFIG_SPIRAM_USE_MALLOC=y` in sdkconfig, and pin LVGL buffers to PSRAM via `lv_disp_draw_buf_init` with `MALLOC_CAP_SPIRAM`. Without PSRAM, LVGL works only for trivial sub-200KB UIs.",
    },
    {
        "id": "ISSUE #4",
        "symptom": "Claude Code MCP server for espctl shows 'authentication failed' or 'control plane unreachable'.",
        "fix": "Set MCP_AUTH_SECRET in the MCP server's env section in .claude/settings.json (matching AGENT_AUTH_SECRET on the control plane). Verify CONTROL_BASE_URL is a routable URL (e.g. https://esphome.cloud), NOT an SSH alias. The browser-side surface needs CORS to include https://esphome.cloud on the control plane.",
    },
]

# IC-1 output JSON schema (also lives at tests/schemas/triage_output.schema.json).
OUTPUT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "category":         {"type": "string", "enum": CATEGORIES},
        "duplicate_of":     {"type": ["integer", "null"]},
        "labels_to_add":    {"type": "array", "items": {"type": "string"}},
        "should_close":     {"type": "boolean"},
        "response_to_user": {"type": "string"},
        "page_human":       {"type": "boolean"},
        "reasoning":        {"type": "string"},
    },
    "required": [
        "category", "duplicate_of", "labels_to_add", "should_close",
        "response_to_user", "page_human", "reasoning",
    ],
}


# ----------------------------------------------------------------------------
# System prompt (stable; prompt-cached). Must be >=4096 tokens on Opus 4.7
# to actually cache — pad the policy + few-shot section if it falls short.
# ----------------------------------------------------------------------------

def _render_known_issues() -> str:
    out = ["## KNOWN_ISSUES (KB — match against incoming issue verbatim before considering other categories)"]
    for kb in KNOWN_ISSUES:
        out.append(f"\n### {kb['id']}\n**Symptom.** {kb['symptom']}\n**Fix.** {kb['fix']}")
    return "\n".join(out)


SYSTEM_PROMPT_TEMPLATE = """\
You are the AI triage assistant for the esphome-cloud/community GitHub repository.

The repository is the single feedback intake for esphome.cloud BETA users. It is operated
by ONE founder who reads with Tuesday office-hours cadence (14:00-16:00 UTC+8) on the public
channels, and a 24-hour SLA on security@esphome.cloud only. Your job is to be the founder's
first reader: route inputs correctly, close what is closable, ask for what is missing,
and escalate only what genuinely needs the founder.

You always emit a SINGLE JSON object matching the schema below. No prose outside the JSON.

## Categories (exactly 9)

You MUST classify into one of these. The category determines downstream dispatch.

1. **known_issue** — issue matches one of the KNOWN_ISSUES KB entries below. Reply with the
   fix from the KB and close. `should_close=true`, `labels_to_add=["ai-resolved"]` plus any
   relevant `area/*` or `client/*` label.

2. **duplicate** — the same bug or feature was already filed.
   - If the user explicitly states "this is a duplicate" / "filing as a duplicate" / "close as duplicate":
     classify as `duplicate` even without a specific issue number; set `duplicate_of` to null.
   - If the user references a specific issue # (#NN) you can identify with high confidence: set `duplicate_of=NN`.
   - If the user describes a fresh bug that "happens to be similar" to a prior report: prefer `real_bug` and let
     the human review confirm any duplication.
   Reply with a one-line "marking as duplicate per your request" pointer + close.
   `should_close=true`, `labels_to_add=["duplicate"]`.

3. **user_config** — the bug is the user's setup, not esphome.cloud. Examples: wrong USB
   port, wrong IDF version, env-var not exported. Reply with what to check + close.
   `should_close=true`, `labels_to_add=["ai-resolved"]`.

4. **real_bug** — genuine bug in esphome.cloud that the founder should triage. Reply with
   acknowledgement + ask for any missing reproduction info (Job ID, error log).
   `should_close=false`, `labels_to_add=["bug","needs-triage"]` plus relevant `area/*`.

5. **feature_request** — wants something esphome.cloud does not do. Reply with
   acknowledgement of the use case + note that BETA is bug-focused; if the request is
   in-scope, the founder will respond during office hours. `should_close=false`,
   `labels_to_add=["enhancement","needs-triage"]`.

6. **question** — usage / how-to. Reply with redirect to Discussions/Q&A (since Discussions
   is the question lane per ADR-002), or a short answer if the question is trivially
   answerable from the KB. `should_close=true`, `labels_to_add=["question"]`.

7. **security_critical** — security/privacy report that needs same-day human attention.
   This is the ONLY category that pages the founder via SMTP. The `response_to_user` MUST:
     - be 200 characters or fewer
     - contain the literal phrase "email security@" (to redirect to coordinated disclosure)
     - NOT contain exploit details, vulnerable file paths, or PoC commands
   `should_close=false`, `page_human=true`, `labels_to_add=["needs-human"]`.

8. **out_of_scope** — feature is outside the esphome.cloud BETA mission per
   the Mission alignment section below. Reply by pointing at what is in-scope.
   `should_close=true`, `labels_to_add=["out-of-scope"]`.

9. **spam** — bulk-generated, off-topic, or commercial promotion. Reply with a short
   bulk-close template. `should_close=true`, `labels_to_add=["spam"]`.

## Invariants (NEVER violate)

- `page_human` is `true` ONLY when category is `security_critical`. Every other category
  MUST set `page_human=false`. Pagering the founder for a `real_bug` is a SEV-2 incident.
- For `security_critical`, the `response_to_user` is capped at 200 chars and MUST contain
  "email security@". The body MUST NOT include the symptom, reproduction, or any detail
  that would help an attacker — defer ALL detail to the private security@ thread.
- `duplicate_of` is an integer ONLY when category is `duplicate`. Null in every other case.
- The reply text NEVER mentions Discord, Slack, WeChat, 微信, QQ, Telegram, Lark, Feishu,
  or 飞书 — these channels do not exist for the project (ADR-001 invariant).
- Replies are concise (under 1000 chars for non-security cases). The agent appends a
  disclosure footer; do not include the footer in your reply.

## Mission alignment

esphome.cloud is a single-device wizard + remote build + flash pipeline for ESP32-family
microcontrollers, designed for solo developers and small embedded shops who want to compose
firmware out of well-tested Solution templates rather than wrestle ESP-IDF from scratch.
The mission is **lower the activation energy from idea → flashed device** for one device
at a time, with AI-native tooling (MCP servers + browser wizard + Claude Code integration)
doing the heavy lifting around configuration and build pipelines.

In scope:
  - ESP32-family firmware build (single device at a time)
  - Solution templates (composable board × peripheral × use-case configs)
  - Browser wizard (esphome.cloud)
  - MCP integration (espctl-mcp, idfmcp, @aegis/espctl-web)
  - AI agent native (Claude Code / Cursor / Codex CLI / OpenCode / Claude Desktop)

Out of scope (classify these as `out_of_scope`):
  - OTA fleet management (push firmware to 100+ devices in the field)
  - Device management (inventory, remote-config push, device-state telemetry)
  - Team collaboration (multi-tenant orgs, RBAC, shared workspaces, SSO)
  - IoT platform features (data ingestion, time-series DBs, rules engines, dashboards)

Full policy + re-evaluation triggers at policies/mission-scope-policy.md.

{known_issues}

## Few-shot examples

Use these as anchors for tone, length, and category boundary cases.

### Example A — known_issue + close

Input title: "[Bug]: ESP-IDF install fails on macOS, complains about pip / venv"
Input body: "Trying to set up esphome.cloud locally on macOS 14. Ran `pip install -r requirements.txt` against my brew Python 3.11 and got 'externally-managed-environment'."

Output:
{{
  "category": "known_issue",
  "duplicate_of": null,
  "labels_to_add": ["ai-resolved","area/cli"],
  "should_close": true,
  "response_to_user": "This matches the macOS ESP-IDF venv KB entry: ESP-IDF setup on macOS needs Espressif's own venv. Run `./install.sh` from the IDF tree (it provisions `~/.espressif/`) rather than `pip install` against system Python, then `. ./export.sh` in a fresh shell. Closing — please reopen if the install.sh path also fails.",
  "page_human": false,
  "reasoning": "Title + body exactly match the macOS ESP-IDF venv KB entry. The user said 'pip install -r requirements.txt' which is the exact anti-pattern the KB warns against."
}}

### Example B — real_bug + ask for Job ID

Input title: "[Build Failed]: ESP32-S3 build crashes during cmake link step"
Input body: "Builds were fine yesterday, now every build dies in the linker. No code changes on my side. Tried clean + rebuild, same result. esphome.cloud build, not local."

Output:
{{
  "category": "real_bug",
  "duplicate_of": null,
  "labels_to_add": ["bug","build-failure","needs-triage","area/agent"],
  "should_close": false,
  "response_to_user": "Thanks for the report — 'worked yesterday, fails today, no code change' is exactly the shape we need to investigate. Could you share: (1) the Job ID from the failed build (printed at job start), (2) the linker error itself (last 30 lines of the build log), and (3) the IDF version pin? With those three I can reproduce on our side.",
  "page_human": false,
  "reasoning": "Behavior changed without a user-side trigger; this is a real_bug candidate on our infra, not a user_config issue. Cannot be a KI match (no current KB covers cmake link failures). Asking for Job ID is essential — without it we cannot trace the agent-side build."
}}

### Example C — security_critical (terse redirect, NO detail)

Input title: "Possible IDOR in the wizard"
Input body: "I noticed that visiting /api/job/12345 returns build data for someone else's job. I can include a screenshot privately if useful."

Output:
{{
  "category": "security_critical",
  "duplicate_of": null,
  "labels_to_add": ["needs-human"],
  "should_close": false,
  "response_to_user": "Thank you for reporting this — please email security@esphome.cloud with the details. We follow coordinated disclosure with a 24-hour acknowledgement SLA.",
  "page_human": true,
  "reasoning": "Reporter described a possible IDOR (cross-tenant data leak). Redirecting to security@ per ADR-001 / IC-3. Response body deliberately omits the URL pattern and 'IDOR' framing to avoid surfacing the vulnerability publicly before disclosure coordination."
}}

### Example D — out_of_scope (politely scoped)

Input title: "[Feature]: OTA fleet management"
Input body: "Would be great if esphome.cloud could manage OTA updates for 200 devices in production."

Output:
{{
  "category": "out_of_scope",
  "duplicate_of": null,
  "labels_to_add": ["out-of-scope"],
  "should_close": true,
  "response_to_user": "Thanks for the suggestion — OTA fleet management is outside the esphome.cloud BETA mission (see the 'What I Won't Do' section of the README). The BETA scope is single-device wizard + build + flash, not multi-device production fleet ops. If you want a fleet manager, ESPHome's own dashboard or commercial tools are a better fit.",
  "page_human": false,
  "reasoning": "OTA fleet management is named verbatim as out-of-scope in the founder's mission-scope-policy. Closing politely without dragging the issue out."
}}

## Output

Emit ONLY the JSON object, matching the schema. No surrounding prose, no markdown fences,
no preamble.
"""


def build_system_prompt() -> str:
    """Return the system prompt as a single string.

    DeepSeek does automatic prefix caching server-side — no client-side
    cache_control markers needed. The system prompt is stable across all
    issue calls (only the per-issue user message varies), so the entire
    system prompt becomes a cache-hit after the first request.

    Verify cache hits via response.usage.prompt_cache_hit_tokens at runtime.

    The prompt contains the literal lowercase word "json" (DeepSeek
    requirement for response_format=json_object to take effect).
    """
    return SYSTEM_PROMPT_TEMPLATE.format(known_issues=_render_known_issues())


# ----------------------------------------------------------------------------
# Classification
# ----------------------------------------------------------------------------

def _render_user_message(title: str, body: str) -> str:
    return (
        f"# Issue title\n{title}\n\n"
        f"# Issue body\n{body or '(empty)'}\n\n"
        f"Classify per the schema. Emit JSON only."
    )


def _build_mock(category: str, title: str) -> dict[str, Any]:
    """Deterministic offline stub honoring IC-1 invariants.

    Used by --mock-category for schema-validation tests that run without an
    Anthropic API key (CI offline path + tests/security/triage_no_exploit_disclosure.py).
    """
    labels_map = {
        "known_issue":       ["ai-resolved"],
        "duplicate":         ["duplicate"],
        "user_config":       ["ai-resolved","needs-info"],
        "real_bug":          ["bug","needs-triage"],
        "feature_request":   ["enhancement","needs-triage"],
        "question":          ["question"],
        "security_critical": ["needs-human"],
        "out_of_scope":      ["out-of-scope"],
        "spam":              ["spam"],
    }
    if category == "security_critical":
        # 200-char cap + must contain "email security@"
        response = ("Thanks for reporting. Please email security@esphome.cloud "
                    "with details; 24h SLA on coordinated disclosure.")
    elif category == "duplicate":
        response = "Looks like a duplicate of #1. Closing — please follow that thread."
    elif category == "spam":
        response = "Closing as off-topic / spam. If this was a mistake, please reopen with project context."
    elif category == "out_of_scope":
        response = "Thanks — that capability is outside the esphome.cloud BETA mission. See the 'What I Won't Do' section."
    else:
        response = f"[mock {category}] dispatched by --mock-category for offline testing."

    return {
        "category":         category,
        "duplicate_of":     1 if category == "duplicate" else None,
        "labels_to_add":    labels_map[category],
        "should_close":     SHOULD_CLOSE[category],
        "response_to_user": response,
        "page_human":       category == "security_critical",
        "reasoning":        f"[mock] forced classification via --mock-category={category}; title='{title[:40]}'",
    }


def classify(
    title: str,
    body: str,
    mock_category: str | None = None,
) -> tuple[dict[str, Any], dict[str, int]]:
    """Classify an issue. Returns (decision, usage_dict).

    usage_dict has keys prompt_tokens, completion_tokens,
    prompt_cache_hit_tokens, prompt_cache_miss_tokens
    (zeros for the mock path; DeepSeek-shape under live path).
    """
    if mock_category is not None:
        return _build_mock(mock_category, title), {
            "prompt_tokens": 0, "completion_tokens": 0,
            "prompt_cache_hit_tokens": 0, "prompt_cache_miss_tokens": 0,
        }

    from openai import OpenAI  # Imported lazily so --mock-category works offline.

    # DeepSeek API is OpenAI-compatible. Auth: Bearer DEEPSEEK_API_KEY.
    client = OpenAI(
        api_key=os.environ["DEEPSEEK_API_KEY"],
        base_url=DEEPSEEK_BASE_URL,
    )

    request_kwargs = dict(
        model=MODEL,
        max_tokens=2048,
        # DeepSeek does NOT enforce json_schema — only json_object (free-form).
        # Schema enforcement happens client-side via enforce_invariants().
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": build_system_prompt()},
            {"role": "user",   "content": _render_user_message(title, body)},
        ],
    )

    # DeepSeek occasionally returns empty content OR malformed JSON on
    # response_format=json_object. Retry up to 2 attempts total — one
    # retry empirically clears most transient blips. Surface a clear
    # error if both attempts fail so the workflow log records the failure
    # mode rather than crashing on an opaque exception.
    decision = None
    last_err: Exception | None = None
    for attempt in (1, 2):
        response = client.chat.completions.create(**request_kwargs)
        text = (response.choices[0].message.content or "").strip()
        if not text:
            print(f"[triage] attempt {attempt}: DeepSeek returned empty content",
                  file=sys.stderr)
            last_err = RuntimeError("empty content")
            continue
        try:
            decision = json.loads(text)
            break
        except json.JSONDecodeError as exc:
            print(f"[triage] attempt {attempt}: DeepSeek returned malformed JSON: {exc}",
                  file=sys.stderr)
            last_err = exc

    if decision is None:
        raise RuntimeError(
            f"DeepSeek returned empty/malformed content twice (last: {last_err!r}); "
            "aborting."
        )

    # DeepSeek usage fields. cache_hit + cache_miss = prompt_tokens.
    u = response.usage
    usage = {
        "prompt_tokens":             getattr(u, "prompt_tokens", 0) or 0,
        "completion_tokens":         getattr(u, "completion_tokens", 0) or 0,
        "prompt_cache_hit_tokens":   getattr(u, "prompt_cache_hit_tokens", 0) or 0,
        "prompt_cache_miss_tokens":  getattr(u, "prompt_cache_miss_tokens", 0) or 0,
    }
    return decision, usage


# ----------------------------------------------------------------------------
# Invariants — defense-in-depth atop output_config schema validation.
# ----------------------------------------------------------------------------

def enforce_invariants(decision: dict[str, Any]) -> None:
    cat = decision["category"]
    if cat not in CATEGORIES:
        raise ValueError(f"unknown category: {cat!r}")

    # page_human
    if decision["page_human"] and cat != "security_critical":
        raise ValueError(f"page_human=true with category={cat!r} (IC-1 violation)")

    # security_critical body constraints (R-04 + R-07 mitigation)
    if cat == "security_critical":
        resp = decision["response_to_user"]
        if len(resp) > 200:
            raise ValueError(f"security_critical response too long: {len(resp)} > 200 chars (R-07)")
        if "email security@" not in resp:
            raise ValueError("security_critical response must contain 'email security@' (IC-1 V-3)")

    # duplicate_of pairing — `null` is the default; only required to be NON-null
    # for category != duplicate (where it'd be wrong). For category=duplicate,
    # null is permitted when the user self-identifies as a duplicate without a
    # verifiable issue # reference (per the duplicate-category prompt rules).
    if cat != "duplicate" and decision["duplicate_of"] is not None:
        raise ValueError("duplicate_of must be null unless category=duplicate")

    # should_close per-category rule
    expected = SHOULD_CLOSE.get(cat)
    if expected is not None and decision["should_close"] != expected:
        raise ValueError(
            f"should_close={decision['should_close']} mismatched for category={cat!r}; "
            f"IC-1 requires {expected}"
        )


# ----------------------------------------------------------------------------
# Cost computation + log line
# ----------------------------------------------------------------------------

def compute_cost_usd(usage: dict[str, int]) -> float:
    """Sum DeepSeek per-1M rates against the usage breakdown.

    DeepSeek v4-flash:
      - prompt_cache_miss_tokens × $0.14 / 1M  (fresh input)
      - prompt_cache_hit_tokens  × $0.0028 / 1M (50× cheaper; auto-cached prefix)
      - completion_tokens        × $0.28 / 1M  (output)

    If only the legacy `prompt_tokens` field is populated (some SDK versions
    bundle cache hit+miss into one field), the entire prompt is billed at
    cache-miss rate — conservative.
    """
    miss = usage.get("prompt_cache_miss_tokens", 0) or 0
    hit  = usage.get("prompt_cache_hit_tokens", 0) or 0
    out  = usage.get("completion_tokens", 0) or 0
    # Fallback if the SDK didn't split hit/miss: charge `prompt_tokens` at miss rate.
    if miss == 0 and hit == 0 and usage.get("prompt_tokens", 0):
        miss = usage["prompt_tokens"]
    return round(
        miss * PRICE_INPUT_PER_M / 1_000_000
        + hit  * PRICE_INPUT_CACHE_HIT / 1_000_000
        + out  * PRICE_OUTPUT_PER_M / 1_000_000,
        6,  # 6 decimals — DeepSeek per-issue cost lands near $0.0001
    )


def emit_log_line(issue_n: int, category: str, cost_usd: float) -> None:
    """Format per phase-0-foundation.md Task 0.4 acceptance #4.

    Cost is rendered as fixed-point (.6f) NOT default repr. Default repr
    switches to scientific notation for values < 1e-4 (e.g. 9.3e-05),
    which breaks downstream grep gates that expect `cost_usd:[0-9.]+`.
    Six decimals is sufficient resolution for DeepSeek's cents-of-a-cent
    per-issue costs.
    """
    print(
        f"triage.classified{{issue:{issue_n}, category:{category}, cost_usd:{cost_usd:.6f}}}",
        file=sys.stderr,
        flush=True,
    )


# ----------------------------------------------------------------------------
# Dispatch (real mode) — labels / comment / close / pager
# ----------------------------------------------------------------------------

def send_pager_email(
    issue_n: int,
    title: str,
    body: str,
    decision: dict[str, Any],
    repo: str,
) -> None:
    """SMTP-SSL :465 critical page. Fault-tolerant: any failure logs + returns.

    Task 0.5 lands the validation; this is the dispatch hook so 0.4 stays
    self-contained.
    """
    if not decision.get("page_human"):
        return
    try:
        smtp_host     = os.environ["SMTP_HOST"]
        smtp_user     = os.environ["SMTP_USER"]
        smtp_password = os.environ["SMTP_PASSWORD"]
        alert_email   = os.environ["ALERT_EMAIL"]
    except KeyError as exc:
        print(f"[pager] missing env var {exc!r}; pager skipped", file=sys.stderr)
        return

    # Resend's SMTP relay requires a literal "resend" username distinct from the
    # display From: address; TEE and most other providers use the same value for both.
    smtp_from = os.environ.get("SMTP_FROM", "ai-triage@esphome.cloud")

    msg = EmailMessage()
    msg["From"]    = smtp_from
    msg["To"]      = alert_email
    msg["Subject"] = f"[CRITICAL] esphome.cloud issue #{issue_n}"
    msg.set_content(
        "CRITICAL ISSUE detected:\n"
        f"Issue: #{issue_n}\n"
        f"Title: {title}\n"
        f"Category: {decision['category']}\n"
        f"Reasoning: {decision['reasoning']}\n"
        f"URL: https://github.com/{repo}/issues/{issue_n}\n"
        "Body:\n"
        f"{(body or '')[:1000]}\n"
    )
    try:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(smtp_host, 465, context=ctx, timeout=15) as smtp:
            smtp.login(smtp_user, smtp_password)
            smtp.send_message(msg)
    except Exception as exc:  # Fault-tolerant per Task 0.5.
        print(f"[pager] SMTP send failed: {exc}", file=sys.stderr)


def dispatch_to_github(item_n: int, decision: dict[str, Any], repo: str, kind: str = "issue") -> None:
    """Route to issue (PyGithub REST) or discussion (GraphQL) dispatch."""
    if kind == "discussion":
        _dispatch_to_discussion(item_n, decision, repo)
    else:
        _dispatch_to_issue(item_n, decision, repo)


def _dispatch_to_issue(issue_n: int, decision: dict[str, Any], repo: str) -> None:
    """Apply labels, post comment with disclosure footer, close if appropriate."""
    from github import Github  # PyGithub — imported lazily.

    token = os.environ["GITHUB_TOKEN"]
    gh = Github(token)
    issue = gh.get_repo(repo).get_issue(number=issue_n)

    if decision["labels_to_add"]:
        try:
            issue.add_to_labels(*decision["labels_to_add"])
        except Exception as exc:
            print(f"[dispatch] add_to_labels failed: {exc}", file=sys.stderr)

    if decision["response_to_user"]:
        body = decision["response_to_user"] + DISCLOSURE_FOOTER
        try:
            issue.create_comment(body)
        except Exception as exc:
            print(f"[dispatch] create_comment failed: {exc}", file=sys.stderr)

    if decision["should_close"]:
        try:
            issue.edit(state="closed", state_reason="completed")
        except Exception as exc:
            print(f"[dispatch] close failed: {exc}", file=sys.stderr)


def _graphql_post(query: str, variables: dict[str, Any], token: str) -> dict[str, Any]:
    """Lightweight GraphQL POST via stdlib urllib — no extra runtime deps."""
    import urllib.request
    payload = json.dumps({"query": query, "variables": variables}).encode("utf-8")
    req = urllib.request.Request(
        "https://api.github.com/graphql",
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "esphome-cloud-triage/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _dispatch_to_discussion(disc_n: int, decision: dict[str, Any], repo: str) -> None:
    """Post comment + close on a discussion via GraphQL.

    PyGithub lacks discussion mutations; we use the REST-equivalent
    addDiscussionComment / closeDiscussion mutations directly.

    Labels on discussions are intentionally skipped: discussion-label support
    is repo-conditional, not load-bearing for Phase 1 G1 acceptance (only
    comment + close are required by the e2e smoke).
    """
    token = os.environ["GITHUB_TOKEN"]
    owner, name = repo.split("/", 1)

    try:
        data = _graphql_post(
            "query($o:String!,$n:String!,$num:Int!){repository(owner:$o,name:$n){discussion(number:$num){id}}}",
            {"o": owner, "n": name, "num": disc_n},
            token,
        )
        disc_id = data["data"]["repository"]["discussion"]["id"]
    except Exception as exc:
        print(f"[dispatch] discussion id lookup failed: {exc}", file=sys.stderr)
        return

    if decision.get("response_to_user"):
        body = decision["response_to_user"] + DISCLOSURE_FOOTER
        try:
            _graphql_post(
                "mutation($d:ID!,$b:String!){addDiscussionComment(input:{discussionId:$d,body:$b}){comment{id}}}",
                {"d": disc_id, "b": body},
                token,
            )
        except Exception as exc:
            print(f"[dispatch] addDiscussionComment failed: {exc}", file=sys.stderr)

    if decision.get("should_close"):
        reason = {"duplicate": "DUPLICATE", "spam": "OUTDATED"}.get(
            decision.get("category", ""), "RESOLVED"
        )
        try:
            _graphql_post(
                "mutation($d:ID!,$r:DiscussionCloseReason!){closeDiscussion(input:{discussionId:$d,reason:$r}){discussion{closed}}}",
                {"d": disc_id, "r": reason},
                token,
            )
        except Exception as exc:
            print(f"[dispatch] closeDiscussion failed: {exc}", file=sys.stderr)


# ----------------------------------------------------------------------------
# Input adapters
# ----------------------------------------------------------------------------

def _read_fixture(path: str) -> tuple[str, str, int, str]:
    data = json.loads(Path(path).read_text())
    return data["title"], data.get("body", ""), int(data.get("issue", 0)), "issue"


def _read_gh_event() -> tuple[str, str, int, str]:
    event_path = os.environ["GITHUB_EVENT_PATH"]
    event = json.loads(Path(event_path).read_text())
    if "issue" in event:
        obj, kind = event["issue"], "issue"
    elif "discussion" in event:
        obj, kind = event["discussion"], "discussion"
    else:
        raise SystemExit("GITHUB_EVENT_PATH has neither issue nor discussion payload")
    return obj["title"], obj.get("body") or "", int(obj["number"]), kind


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(description="DeepSeek v4-flash triage for esphome-cloud/community.")
    p.add_argument("--dry-run", action="store_true",
                   help="Classify and emit JSON, but do NOT label/comment/close on GitHub.")
    p.add_argument("--input", help="Path to fixture JSON (title + body + optional issue#).")
    p.add_argument("--mock-category", choices=CATEGORIES,
                   help="Skip DeepSeek API entirely; emit a stub decision. Offline-only.")
    p.add_argument("--issue", type=int, default=0,
                   help="Issue number (overrides fixture / event when set).")
    p.add_argument("--repo", default="esphome-cloud/community",
                   help="GitHub repo slug for dispatch + pager URL.")
    args = p.parse_args()

    # 1. Read input.
    if args.input:
        title, body, issue_n, kind = _read_fixture(args.input)
    elif "GITHUB_EVENT_PATH" in os.environ:
        title, body, issue_n, kind = _read_gh_event()
    else:
        print("error: provide --input <fixture> or set GITHUB_EVENT_PATH", file=sys.stderr)
        return 2
    if args.issue:
        issue_n = args.issue

    # 2. Classify.
    decision, usage = classify(title, body, mock_category=args.mock_category)
    enforce_invariants(decision)

    # 3. Observability log line + JSON to stdout.
    cost_usd = compute_cost_usd(usage)
    emit_log_line(issue_n, decision["category"], cost_usd)
    print(json.dumps(decision, indent=2, ensure_ascii=False))

    # 4. Dispatch unless --dry-run / --mock-category.
    if args.dry_run or args.mock_category:
        return 0
    dispatch_to_github(issue_n, decision, args.repo, kind=kind)
    send_pager_email(issue_n, title, body, decision, args.repo)
    return 0


if __name__ == "__main__":
    sys.exit(main())
