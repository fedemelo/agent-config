#!/usr/bin/env bash
# Tests enforce-commit-skill.py, the hook that blocks `git commit` until the commit skill has
# been invoked. Every case feeds it one PreToolUse payload and a transcript holding a single
# line, and asserts only whether the commit was allowed through.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$repo_root/hooks/enforce-commit-skill.py"

transcript="$(mktemp)"
trap 'rm -f "$transcript"' EXIT

pass=0; fail=0

check() {
  if [ "$2" = "$3" ]; then printf '  PASS %s\n' "$1"; pass=$((pass+1))
  else printf '  FAIL %s\n       got:  %s\n       want: %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

# "deny" when the hook blocked the command, "allow" when it left it to the normal
# permission flow. Reads the payload from stdin, as the hook itself does.
decide() { # takes a whole payload, as the hook reads one from stdin
  if printf '%s' "$1" | python3 "$hook" | grep -q '"permissionDecision": "deny"'; then
    echo deny
  else
    echo allow
  fi
}

# The common case: a Bash command judged against a transcript holding a single line.
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

echo "=== a commit needs the skill ==="
check "no evidence at all blocks" "$(verdict "git commit -m x")" "deny"
check "Claude invoking the skill allows" "$(verdict "git commit -m x" "$(skill_call commit)")" "allow"
check "a different skill still blocks" "$(verdict "git commit -m x" "$(skill_call open-pr)")" "deny"
# The prefix is optional, so a name merely ending in commit must not satisfy it.
check "a skill named like commit blocks" "$(verdict "git commit -m x" "$(skill_call not-commit)")" "deny"

echo "=== both ways of reaching the skill count ==="
# Installed as a plugin the skill answers to <plugin>:commit, which is what the transcript records.
check "a namespaced skill call allows" \
  "$(verdict "git commit -m x" "$(skill_call fedemelo:commit)")" "allow"
# Typing /commit leaves no Skill call, only the command name the CLI expanded.
check "typing /commit allows" "$(verdict "git commit -m x" "$(slash_call commit)")" "allow"
check "typing the namespaced command allows" \
  "$(verdict "git commit -m x" "$(slash_call fedemelo:commit)")" "allow"

echo "=== only a commit is judged ==="
check "another git command passes" "$(verdict "git status")" "allow"
check "a command merely starting with commit passes" "$(verdict "git commit-tree abc")" "allow"
check "a commit chained after another command is caught" "$(verdict "git add . && git commit -m x")" "deny"
check "a commit behind a pipe is caught" "$(verdict "echo x | git commit -F -")" "deny"
check "another tool is never judged" \
  "$(decide '{"tool_name":"Write","tool_input":{"command":"git commit -m x"}}')" "allow"

echo "=== the hook fails open, never closed on its own errors ==="
check "unparseable input passes" "$(decide 'not json')" "allow"
# A transcript that cannot be read is treated as holding no evidence, so the commit is blocked.
check "a missing transcript blocks" \
  "$(decide '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"transcript_path":"/nope.jsonl"}')" \
  "deny"

echo
echo "=== $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
