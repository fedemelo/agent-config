#!/usr/bin/env bash
# Tests require-git-tools.py, the hook that blocks a git-tools subcommand when the
# git-tools executables are missing. Presence is decided by PATH, so each case runs the hook
# with a PATH that either holds stub executables or holds none.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$repo_root/hooks/require-git-tools.py"

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

# A PATH holding the real executables, and one holding neither. python3 has to stay reachable
# in both, since the hook runs on it.
mkdir -p "$ROOT/installed" "$ROOT/bare"
printf '#!/bin/sh\n' > "$ROOT/installed/git-land"
printf '#!/bin/sh\n' > "$ROOT/installed/git-todo"
printf '#!/bin/sh\n' > "$ROOT/installed/git-review-feedback"
printf '#!/bin/sh\n' > "$ROOT/installed/git-review-reply"
chmod +x "$ROOT/installed/git-land" "$ROOT/installed/git-todo" "$ROOT/installed/git-review-feedback" \
  "$ROOT/installed/git-review-reply"
python_dir="$(dirname "$(command -v python3)")"
WITH_TOOLS="$ROOT/installed:$python_dir:/usr/bin:/bin"
WITHOUT_TOOLS="$ROOT/bare:$python_dir:/usr/bin:/bin"

pass=0; fail=0

check() {
  if [ "$2" = "$3" ]; then printf '  PASS %s\n' "$1"; pass=$((pass+1))
  else printf '  FAIL %s\n       got:  %s\n       want: %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

# "deny" when the hook blocked the command, "allow" when it left it to the normal
# permission flow.
decide() { # $1 = whole payload, $2 = PATH to run under
  if printf '%s' "$1" | env PATH="$2" python3 "$hook" | grep -q '"permissionDecision": "deny"'; then
    echo deny
  else
    echo allow
  fi
}

verdict() { # $1 = Bash command, $2 = PATH
  decide "$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1")" "$2"
}

reason() { # the message shown to the model when blocked
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" \
    | env PATH="$WITHOUT_TOOLS" python3 "$hook"
}

echo "=== with the tools installed, nothing is blocked ==="
check "git land runs" "$(verdict 'git land' "$WITH_TOOLS")" "allow"
check "git todo runs" "$(verdict 'git todo Something' "$WITH_TOOLS")" "allow"
check "git review-feedback runs" "$(verdict 'git review-feedback 7' "$WITH_TOOLS")" "allow"
check "git review-reply runs" "$(verdict 'git review-reply /tmp/replies.json' "$WITH_TOOLS")" "allow"

echo "=== with the tools missing, their commands are blocked ==="
check "git land is blocked" "$(verdict 'git land' "$WITHOUT_TOOLS")" "deny"
check "git land with a title is blocked" "$(verdict 'git land \"A title\"' "$WITHOUT_TOOLS")" "deny"
check "git todo is blocked" "$(verdict 'git todo Something' "$WITHOUT_TOOLS")" "deny"
check "git review-feedback is blocked" "$(verdict 'git review-feedback' "$WITHOUT_TOOLS")" "deny"
check "git review-feedback with flags is blocked" "$(verdict 'git review-feedback 7 --all' "$WITHOUT_TOOLS")" "deny"
check "the reason names git-land" "$(reason 'git land' | grep -c 'git-land')" "1"
check "the reason names git-todo" "$(reason 'git todo x' | grep -c 'git-todo')" "1"
check "the reason names git-review-feedback" "$(reason 'git review-feedback' | grep -c 'git-review-feedback')" "1"
check "git review-reply is blocked" "$(verdict 'git review-reply /tmp/replies.json' "$WITHOUT_TOOLS")" "deny"
check "the reason names git-review-reply" "$(reason 'git review-reply x' | grep -c 'git-review-reply')" "1"

echo "=== a blocked command is only ever the one that is missing ==="
only_land="$ROOT/only-land:$python_dir:/usr/bin:/bin"
mkdir -p "$ROOT/only-land"; cp "$ROOT/installed/git-land" "$ROOT/only-land/git-land"
check "git land runs when only it is installed" "$(verdict 'git land' "$only_land")" "allow"
check "git todo is blocked when only git-land is installed" "$(verdict 'git todo x' "$only_land")" "deny"

echo "=== unrelated commands pass through even with nothing installed ==="
check "git status" "$(verdict 'git status' "$WITHOUT_TOOLS")" "allow"
check "git log" "$(verdict 'git log --oneline' "$WITHOUT_TOOLS")" "allow"
check "gh pr view" "$(verdict 'gh pr view' "$WITHOUT_TOOLS")" "allow"

echo "=== the command has to be the one being run, not merely mentioned ==="
check "echo git land is not a land" "$(verdict 'echo git land' "$WITHOUT_TOOLS")" "allow"
check "git landmine is not a land" "$(verdict 'git landmine' "$WITHOUT_TOOLS")" "allow"
check "git todos is not a todo" "$(verdict 'git todos' "$WITHOUT_TOOLS")" "allow"

echo "=== a chained command is caught wherever it sits ==="
check "after && " "$(verdict 'cd /tmp && git land' "$WITHOUT_TOOLS")" "deny"
check "after ; " "$(verdict 'git status ; git land' "$WITHOUT_TOOLS")" "deny"
check "after | " "$(verdict 'echo x | git todo y' "$WITHOUT_TOOLS")" "deny"

echo "=== anything that is not a Bash call is left alone ==="
check "a Read call" "$(decide '{"tool_name":"Read","tool_input":{"file_path":"/x"}}' "$WITHOUT_TOOLS")" "allow"
check "an unparseable payload" "$(decide 'not json at all' "$WITHOUT_TOOLS")" "allow"
check "a Bash call with no command" "$(decide '{"tool_name":"Bash","tool_input":{}}' "$WITHOUT_TOOLS")" "allow"

printf '\n=== %d passed, %d failed ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
