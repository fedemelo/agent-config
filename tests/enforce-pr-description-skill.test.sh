#!/usr/bin/env bash
# Tests enforce-pr-description-skill.py, the hook that blocks writing a PR body until the
# pr-description skill has been invoked. Every case feeds it one PreToolUse payload and a
# transcript holding a single line, and asserts only whether the command was allowed through.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$repo_root/hooks/enforce-pr-description-skill.py"

transcript="$(mktemp)"
trap 'rm -f "$transcript"' EXIT

pass=0; fail=0

check() {
  if [ "$2" = "$3" ]; then printf '  PASS %s\n' "$1"; pass=$((pass+1))
  else printf '  FAIL %s\n       got:  %s\n       want: %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

decide() { # takes a whole payload, as the hook reads one from stdin
  if printf '%s' "$1" | python3 "$hook" | grep -q '"permissionDecision": "deny"'; then
    echo deny
  else
    echo allow
  fi
}

verdict() {
  printf '%s' "${2-}" > "$transcript"
  decide "$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"transcript_path":"%s"}' \
    "$1" "$transcript")"
}

skill_call() {
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"%s"}}]}}' "$1"
}
slash_call() {
  printf '{"type":"user","message":{"role":"user","content":"<command-message>%s</command-message>\\n<command-name>/%s</command-name>"}}' "$1" "$1"
}

echo "=== writing a PR body needs the skill ==="
check "creating a PR with no evidence blocks" "$(verdict "gh pr create --title x --body y")" "deny"
check "editing a PR body with no evidence blocks" "$(verdict "gh pr edit 1 --body y")" "deny"
check "editing from a body file blocks" "$(verdict "gh pr edit 1 --body-file b.md")" "deny"
check "Claude invoking the skill allows" \
  "$(verdict "gh pr create --body y" "$(skill_call pr-description)")" "allow"
check "a namespaced skill call allows" \
  "$(verdict "gh pr create --body y" "$(skill_call fedemelo:pr-description)")" "allow"
check "typing /pr-description allows" \
  "$(verdict "gh pr create --body y" "$(slash_call pr-description)")" "allow"
check "a different skill still blocks" "$(verdict "gh pr create --body y" "$(skill_call commit)")" "deny"

echo "=== only writing a body is judged ==="
check "editing a PR's title passes" "$(verdict "gh pr edit 1 --title x")" "allow"
check "viewing a PR passes" "$(verdict "gh pr view 1")" "allow"
check "a create chained after another command is caught" "$(verdict "git push && gh pr create --body y")" "deny"
check "another tool is never judged" \
  "$(decide '{"tool_name":"Write","tool_input":{"command":"gh pr create"}}')" "allow"

echo
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
