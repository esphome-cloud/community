#!/usr/bin/env python3
"""Phase 0 Task 0.5 acceptance #1 (Integration):
   File a dummy issue with body containing a security marker; within 60s the
   founder mailbox receives an email with subject
     [CRITICAL] esphome.cloud issue #<N>
   Verified across 5/5 trials.

Two modes:

  --local (default):
     Patch smtplib.SMTP_SSL with a recorder. Run 5 trials through
     send_pager_email directly. Verify each captured EmailMessage has
     the correct Subject + To: + body markers. Measure wall-clock per
     send and assert <60s each (in-memory, so this is trivially met —
     the assertion mostly guards against accidental sleep loops).

  --live:
     Use the real smtplib.SMTP_SSL against env-configured SMTP_HOST.
     Requires SMTP_HOST + SMTP_USER + SMTP_PASSWORD + ALERT_EMAIL in env.
     The script does NOT verify mailbox arrival (that requires IMAP /
     mailbox polling which is provider-specific). It verifies the send
     call returned without raising and completed within 60s. For full
     end-to-end mailbox-arrival verification, check the founder's inbox
     by hand or wire an IMAP poller via env.

Exit: 0 = 5/5 within budget; 1 = any fail.
"""

from __future__ import annotations

import argparse
import importlib.util
import io
import os
import sys
import time
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[2]
TRIAGE_PATH = REPO_ROOT / "scripts" / "triage.py"

TRIALS = 5
PER_SEND_BUDGET_S = 60.0

# Each trial gets a distinctive marker so we can confirm the body carries it.
SECURITY_MARKER = "<?dummy security marker?>"


def load_triage_module():
    spec = importlib.util.spec_from_file_location("triage", str(TRIAGE_PATH))
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_local() -> int:
    triage = load_triage_module()
    env = {
        "SMTP_HOST":     "smtp.example.invalid",
        "SMTP_USER":     "ai-triage@esphome.cloud",
        "SMTP_PASSWORD": "PAGER-SMOKE-PASSWORD-DO-NOT-LEAK-DEF456",
        "ALERT_EMAIL":   "founder@esphome.cloud",
    }
    secret_value = env["SMTP_PASSWORD"]

    fails: list[str] = []
    latencies: list[float] = []
    captured_msgs: list[object] = []

    with patch.dict("os.environ", env, clear=False), \
         patch("smtplib.SMTP_SSL", autospec=True) as smtp_mock:
        for i in range(1, TRIALS + 1):
            issue_n = 800 + i
            title = f"[Security] possible cross-tenant access — trial {i}"
            body = f"{SECURITY_MARKER}\n\nReporter notes: synthetic pager smoke trial {i} of {TRIALS}."
            decision = triage._build_mock("security_critical", title)

            smtp_mock.reset_mock()
            captured_stderr = io.StringIO()
            t0 = time.monotonic()
            with redirect_stderr(captured_stderr):
                triage.send_pager_email(
                    issue_n=issue_n, title=title, body=body,
                    decision=decision, repo="esphome-cloud/community",
                )
            elapsed = time.monotonic() - t0
            latencies.append(elapsed)

            cm = smtp_mock.return_value.__enter__.return_value
            if not cm.send_message.called:
                fails.append(f"trial {i}: send_message NOT called")
                continue
            msg = cm.send_message.call_args.args[0]

            expected_subj = f"[CRITICAL] esphome.cloud issue #{issue_n}"
            if msg["Subject"] != expected_subj:
                fails.append(f"trial {i}: Subject {msg['Subject']!r} != {expected_subj!r}")
                continue
            if msg["To"] != env["ALERT_EMAIL"]:
                fails.append(f"trial {i}: To {msg['To']!r} != {env['ALERT_EMAIL']!r}")
                continue
            body_text = msg.get_content()
            if f"Issue: #{issue_n}" not in body_text:
                fails.append(f"trial {i}: body missing 'Issue: #{issue_n}'")
                continue
            if SECURITY_MARKER not in body_text:
                fails.append(f"trial {i}: body missing security marker")
                continue
            if elapsed >= PER_SEND_BUDGET_S:
                fails.append(f"trial {i}: send took {elapsed:.1f}s >= {PER_SEND_BUDGET_S}s budget")
                continue
            if secret_value in captured_stderr.getvalue():
                fails.append(f"trial {i}: SMTP_PASSWORD leaked to stderr")
                continue

            captured_msgs.append(msg)
            print(f"  trial {i}: PASS — Subject={expected_subj!r}, "
                  f"To={msg['To']}, t={elapsed*1000:.1f}ms")

    print()
    if not latencies:
        print("FAIL: no trials produced a latency sample")
        return 1
    print(f"sends:     {len(captured_msgs)}/{TRIALS}")
    print(f"latency:   min={min(latencies)*1000:.1f}ms p50={sorted(latencies)[len(latencies)//2]*1000:.1f}ms "
          f"max={max(latencies)*1000:.1f}ms")
    if fails:
        print(f"failures:  {len(fails)}")
        for f in fails:
            print(f"  - {f}")
        print("\nFAIL: Task 0.5 integration acceptance not met (5/5 required).")
        return 1
    print(f"\nPASS: 5/5 sends — correct Subject + To: + body marker + < {PER_SEND_BUDGET_S}s "
          f"budget — no SMTP password leak.")
    return 0


def run_live() -> int:
    """Real SMTP_SSL against env-configured host. No mocks."""
    required = ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD", "ALERT_EMAIL"]
    missing = [k for k in required if not os.environ.get(k)]
    if missing:
        print(f"FAIL: --live requires env vars: {missing}")
        return 2

    triage = load_triage_module()
    fails: list[str] = []
    latencies: list[float] = []

    for i in range(1, TRIALS + 1):
        issue_n = 850 + i
        title = f"[Security] pager smoke (live) — trial {i} / {TRIALS}"
        body = f"{SECURITY_MARKER}\n\nLive pager smoke trial {i}. Subject expected: [CRITICAL] esphome.cloud issue #{issue_n}."
        decision = triage._build_mock("security_critical", title)

        captured_stderr = io.StringIO()
        t0 = time.monotonic()
        with redirect_stderr(captured_stderr):
            triage.send_pager_email(
                issue_n=issue_n, title=title, body=body,
                decision=decision, repo="esphome-cloud/community",
            )
        elapsed = time.monotonic() - t0
        latencies.append(elapsed)

        # Live mode: we cannot inspect the EmailMessage because it left the
        # process. We can only verify (a) the call didn't propagate an
        # exception, (b) it completed within budget, (c) the SMTP transport
        # didn't log a failure to stderr.
        if elapsed >= PER_SEND_BUDGET_S:
            fails.append(f"trial {i}: send took {elapsed:.1f}s >= {PER_SEND_BUDGET_S}s")
            continue
        if "[pager] SMTP send failed:" in captured_stderr.getvalue():
            fails.append(f"trial {i}: SMTP send failed (see stderr above)")
            continue
        print(f"  trial {i}: PASS — sent in {elapsed:.1f}s (verify subject in {os.environ['ALERT_EMAIL']})")

    if fails:
        print()
        for f in fails:
            print(f"  - {f}")
        print("\nFAIL: Task 0.5 integration (live) — manual mailbox-subject check required.")
        return 1

    print(f"\nPASS: 5/5 sends to {os.environ['SMTP_HOST']}; "
          f"max latency {max(latencies):.1f}s < {PER_SEND_BUDGET_S}s. "
          f"Manually verify {os.environ['ALERT_EMAIL']} received 5 emails with "
          "Subject [CRITICAL] esphome.cloud issue #851..#855.")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Task 0.5 pager_smoke: 5/5 integration test.")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--local", action="store_true",
                   help="Patch smtplib.SMTP_SSL; capture and inspect messages in-memory (default).")
    g.add_argument("--live", action="store_true",
                   help="Send to real SMTP_HOST. Requires SMTP_* + ALERT_EMAIL env vars. "
                        "Mailbox-arrival verification is manual.")
    args = p.parse_args()
    if args.live:
        return run_live()
    return run_local()  # default


if __name__ == "__main__":
    sys.exit(main())
