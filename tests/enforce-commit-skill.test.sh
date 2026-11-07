#!/usr/bin/env bash
# Tests enforce-commit-skill.py, the hook that blocks `git commit` until the commit skill has
# been invoked. Every case feeds it one PreToolUse payload and a transcript holding a single
# line, and asserts only whether the commit was allowed through.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook="$repo_root/hooks/enforce-commit-skill.py"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
transcript="$scratch/session.jsonl"

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

echo "=== a subagent is judged by its own transcript ==="
# A subagent's payload still names the session's transcript; its own calls are recorded beside it.
mkdir -p "$scratch/session/subagents"
agent_transcript="$scratch/session/subagents/agent-a1.jsonl"
subagent_verdict() { # session transcript line, subagent transcript line
  printf '%s' "$1" > "$transcript"
  printf '%s' "$2" > "$agent_transcript"
  decide "$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"transcript_path":"%s","agent_id":"a1"}' \
    "$transcript")"
}
check "the subagent invoking the skill allows" "$(subagent_verdict "" "$(skill_call commit)")" "allow"
check "the subagent without the skill blocks" "$(subagent_verdict "" "$(skill_call open-pr)")" "deny"
# The session loading the skill never put its rules in front of the subagent.
check "only the session invoking the skill blocks" "$(subagent_verdict "$(skill_call commit)" "")" "deny"
check "a subagent with no transcript blocks" \
  "$(decide "$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"transcript_path":"%s","agent_id":"nope"}' \
    "$transcript")")" "deny"
check "the session is still judged by its own transcript" \
  "$(verdict "git commit -m x" "$(skill_call commit)")" "allow"

echo "=== a fork also counts the session history it inherited ==="
# A fork's transcript opens with a pointer to the last session entry it inherited.
filler='{"type":"user"}'
fork_ref='{"type":"fork-context-ref","parentLastUuid":"u2"}'
entry() { # uuid, transcript line
  printf '%s' "$2" | sed "s/^{/{\"uuid\":\"$1\",/"
}
session_lines() { # transcript lines, one entry each, with uuids u1, u2, ...
  local i=0 line
  for line in "$@"; do i=$((i+1)); entry "u$i" "$line"; printf '\n'; done
}
check "the session loading the skill before the fork allows" \
  "$(subagent_verdict "$(session_lines "$(skill_call commit)" "$filler")" "$fork_ref")" "allow"
check "the session loading the skill after the fork blocks" \
  "$(subagent_verdict "$(session_lines "$filler" "$filler" "$(skill_call commit)")" "$fork_ref")" "deny"
check "the fork loading the skill itself allows" \
  "$(subagent_verdict "$(session_lines "$filler" "$filler")" "$fork_ref
$(skill_call commit)")" "allow"
check "an inherited entry missing from the session blocks" \
  "$(subagent_verdict "$(session_lines "$(skill_call commit)")" "$fork_ref")" "deny"
check "an ordinary subagent still ignores the session" \
  "$(subagent_verdict "$(session_lines "$(skill_call commit)" "$filler")" "$filler")" "deny"

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
