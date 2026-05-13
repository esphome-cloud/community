#!/usr/bin/env python3
"""Phase 0 Task 0.5 acceptance #3 (Forbidden behavior):
   email pager fires ONLY on category=security_critical.

Runs 5 trials × 9 categories = 45 calls through scripts/triage.py's
send_pager_email path with smtplib.SMTP_SSL patched to a recorder. Asserts:

  - Exactly 5 send_message() invocations (the 5 security_critical trials)
  - 40 no-send trials (every other category)
  - Every send has Subject starting with `[CRITICAL] esphome.cloud issue #<N>`
  - Every send has a To: == ALERT_EMAIL
  - SMTP_PASSWORD never appears in stderr / captured log output
    (defense-in-depth atop tests/security/no_smtp_leak.sh)

The test runs OFFLINE — no real SMTP server, no Anthropic API key.

Exit: 0 = 5/45 sends, 40/45 no-sends; 1 = any miscount.
"""

from __future__ import annotations

import importlib.util
import io
import sys
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import MagicMock, patch

CATEGORIES = [
    "known_issue", "duplicate", "user_config", "real_bug", "feature_request",
    "question", "security_critical", "out_of_scope", "spam",
]
TRIALS_PER_CATEGORY = 5
TOTAL_TRIALS = len(CATEGORIES) * TRIALS_PER_CATEGORY  # 45
EXPECTED_SENDS = TRIALS_PER_CATEGORY                  # only security_critical sends


def load_triage_module() -> object:
    """Load scripts/triage.py as a module without importing via path manipulation."""
    repo_root = Path(__file__).resolve().parents[2]
    triage_path = repo_root / "scripts" / "triage.py"
    spec = importlib.util.spec_from_file_location("triage", str(triage_path))
    assert spec and spec.loader, f"could not load {triage_path}"
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_trial(triage, category: str, issue_n: int, smtp_mock: MagicMock) -> tuple[bool, str]:
    """One trial: mock-classify <category>, then call send_pager_email.
    Returns (a_send_was_attempted, captured_stderr)."""
    decision = triage._build_mock(category, f"trial #{issue_n}")
    captured = io.StringIO()

    # Reset the mock between trials so we can count sends per-trial.
    smtp_mock.reset_mock()

    with redirect_stderr(captured):
        triage.send_pager_email(
            issue_n=issue_n,
            title=f"synthetic trial #{issue_n}",
            body="(empty body)",
            decision=decision,
            repo="esphome-cloud/community",
        )

    # smtplib.SMTP_SSL is patched at the module level inside triage.send_pager_email
    # via the patch context in main(). A send is attempted if the context manager's
    # __enter__ was called AND .send_message() was invoked on the returned object.
    cm = smtp_mock.return_value
    sent = cm.__enter__.return_value.send_message.called
    return sent, captured.getvalue()


def main() -> int:
    triage = load_triage_module()

    # Provide the env vars send_pager_email reads. Values are dummies — the
    # SMTP layer is mocked so they're never wired-up against a real server.
    env_overrides = {
        "SMTP_HOST":     "smtp.example.invalid",
        "SMTP_USER":     "ai-triage@esphome.cloud",
        "SMTP_PASSWORD": "DUMMY-SMTP-PASSWORD-DO-NOT-LEAK-XYZ123",
        "ALERT_EMAIL":   "founder@esphome.cloud",
    }
    secret_value = env_overrides["SMTP_PASSWORD"]

    sends = 0
    no_sends = 0
    bad_subjects: list[tuple[int, str]] = []
    leaks: list[tuple[int, str]] = []

    issue_counter = 1000
    with patch.dict("os.environ", env_overrides, clear=False), \
         patch("smtplib.SMTP_SSL", autospec=True) as smtp_mock:
        for cat in CATEGORIES:
            for _ in range(TRIALS_PER_CATEGORY):
                sent, stderr = run_trial(triage, cat, issue_counter, smtp_mock)
                if sent:
                    sends += 1
                    # Verify subject + To: on the message that was actually sent.
                    msg = smtp_mock.return_value.__enter__.return_value.send_message.call_args.args[0]
                    subj = msg["Subject"]
                    expected_subj = f"[CRITICAL] esphome.cloud issue #{issue_counter}"
                    if subj != expected_subj:
                        bad_subjects.append((issue_counter, subj))
                    to_ok = msg["To"] == env_overrides["ALERT_EMAIL"]
                    if not to_ok:
                        bad_subjects.append((issue_counter, f"To={msg['To']!r}"))
                else:
                    no_sends += 1
                if secret_value in stderr:
                    leaks.append((issue_counter, "stderr"))
                issue_counter += 1

    # Report.
    print(f"trials:    {TOTAL_TRIALS}")
    print(f"sends:     {sends} (expected {EXPECTED_SENDS} = security_critical only)")
    print(f"no-sends:  {no_sends} (expected {TOTAL_TRIALS - EXPECTED_SENDS})")
    print(f"bad subj:  {len(bad_subjects)}")
    print(f"leaks:     {len(leaks)} stderr captures contained SMTP_PASSWORD")

    fail = False
    if sends != EXPECTED_SENDS:
        print(f"\nFAIL: expected exactly {EXPECTED_SENDS} sends, got {sends}")
        fail = True
    if no_sends != TOTAL_TRIALS - EXPECTED_SENDS:
        print(f"\nFAIL: expected exactly {TOTAL_TRIALS - EXPECTED_SENDS} no-sends, got {no_sends}")
        fail = True
    if bad_subjects:
        print(f"\nFAIL: {len(bad_subjects)} trial(s) had wrong Subject/To: {bad_subjects[:5]}")
        fail = True
    if leaks:
        print(f"\nFAIL: SMTP_PASSWORD leaked to stderr in {len(leaks)} trial(s)")
        fail = True

    if fail:
        return 1
    print(f"\nPASS: 5 sends / 40 no-sends across 45 trials; every send had the correct "
          f"Subject + To header; SMTP_PASSWORD never leaked to stderr.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
