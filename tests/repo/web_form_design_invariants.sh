#!/usr/bin/env bash
# Phase 2 Task 2.4 acceptance:
#   #1 Data shape: doc exists; describes 4 form fields, submit dest, activation trigger
#   #2 Function: contains literal "activation runbook"
#   #3 Forbidden behavior: form-fields section has 0 hits for login/signup/password/account
#   #4 Observability: contains literal "support_no_github"
#
# Exit: 0 = all checks pass; 1 = any miss.

set -euo pipefail
cd "$(dirname "$0")/../.."

DOC="docs/web-form-fallback-design.md"
[ -f "$DOC" ] || { echo "FAIL: $DOC not found"; exit 1; }

fails=0

echo '--- #1 Data shape ---'
for required in "Form specification" "Submission transport" "Activation runbook" "Email" "Body" "Category"; do
  if ! grep -qF "$required" "$DOC"; then
    echo "  FAIL: missing required section/concept: $required"
    fails=$((fails + 1))
  fi
done
[ "$fails" -eq 0 ] && echo "  ok: 4 fields + submit dest + activation runbook sections all present"

echo
echo '--- #2 activation runbook anchor ---'
if grep -qiF "activation runbook" "$DOC"; then
  echo "  ok: 'activation runbook' anchor present"
else
  echo "  FAIL: missing literal 'activation runbook'"
  fails=$((fails + 1))
fi

echo
echo '--- #3 no auth fields in form-fields section ---'
# Extract the section between "## Form specification" and the NEXT "## " heading.
# Flag-based awk (POSIX regex; no PCRE negative lookahead).
form_section=$(awk '
  /^## Form specification$/ { in_sec = 1; next }
  /^## / && in_sec        { in_sec = 0 }
  in_sec
' "$DOC")
# grep for forbidden auth-related strings WITHIN that section only.
auth_hits=$(printf '%s\n' "$form_section" | grep -iE '\b(login|signup|password|account)\b' || true)
if [ -n "$auth_hits" ]; then
  echo "  FAIL: form-fields section mentions auth concept(s):"
  printf '%s\n' "$auth_hits" | sed 's/^/    /'
  fails=$((fails + 1))
else
  echo "  ok: 0 login/signup/password/account hits in form-fields section"
fi

echo
echo '--- #4 support_no_github metric ---'
if grep -qF "support_no_github" "$DOC"; then
  echo "  ok: 'support_no_github' metric tag present"
else
  echo "  FAIL: missing 'support_no_github' metric"
  fails=$((fails + 1))
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails Task 2.4 acceptance check(s) failed."
  exit 1
fi
echo "PASS: Task 2.4 acceptance — fields + activation runbook + no auth + support_no_github."
