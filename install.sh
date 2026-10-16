#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Which environment this is, by the same signals the `environment` skill states, so the installer
# and the skills that branch agree on the answer. First, because the guard below has to decide
# before anything on this machine has been touched.
#
# The two path signals are overridable, which is what lets the refusal below be tested without
# root-owned directories, and leaves room for a pod image that moves them.
share_dir="${AGENT_CONFIG_SHARE_DIR:-/mnt/personal}"
managed_dir="${AGENT_CONFIG_MANAGED_DIR:-/etc/claude-code}"

environment="${AGENT_CONFIG_ENVIRONMENT:-}"
detected=""
if [ -z "$environment" ]; then
  if [ -d "$share_dir" ] && [ -d "$managed_dir" ] && command -v devspaces >/dev/null 2>&1; then
    environment="devspaces"
  else
    environment="owned-machine"
  fi
  detected="yes"
fi

# This script is the wrong tool in a pod, and it now holds the one fact needed to say so. It
# symlinks skills, which the runtime silently never loads there, and it writes machine-wide config
# a pod does not own: ~/.claude/settings.json, where the pod's own policy lives. Running it leaves a setup that looks installed and is not, so it refuses.
#
# Only the detected case refuses. AGENT_CONFIG_ENVIRONMENT is a human naming the environment, and
# overriding the guess is not the same as asking to be stopped; the tests select that way too.
if [ "$environment" = "devspaces" ] && [ -n "$detected" ]; then
  echo "This is a devspaces pod, where this installer is the wrong tool: symlinked skills are" >&2
  echo "silently never loaded, and it would write machine-wide config the pod does not own." >&2
  echo "Run /wire-up instead (\$wire-up in Codex), which follows the pod's own procedure." >&2
  echo "To install anyway, re-run with AGENT_CONFIG_ENVIRONMENT=devspaces." >&2
  exit 1
fi

hooks_dir="$HOME/.claude/hooks"
# Claude Code reads ~/.claude/skills; Codex, Copilot and OpenCode read ~/.agents/skills. Each
# skill is linked into both from the one directory in this repo, so there is still a single copy.
skill_dirs=("$HOME/.claude/skills" "$HOME/.agents/skills")

mkdir -p "$hooks_dir" "${skill_dirs[@]}"

# Earlier versions linked both global-instruction slots at a CLAUDE.md this repo no longer has.
# The rules in it were the user's own, so a slot still linked there becomes a plain copy of the
# file's last version instead of a dangling link that silently drops them.
last_instructions() {
  local removed_in
  removed_in="$(git -C "$repo_dir" log -1 --diff-filter=D --format=%H -- CLAUDE.md 2>/dev/null)"
  [ -n "$removed_in" ] && git -C "$repo_dir" show "$removed_in^:CLAUDE.md" 2>/dev/null
}

unlink_instructions() {
  local slot="$1"
  [ -L "$slot" ] && [ "$(readlink "$slot")" = "$repo_dir/CLAUDE.md" ] || return 0
  rm "$slot"
  if last_instructions > "$slot"; then
    echo "Replaced $slot, a link to this repo's removed CLAUDE.md, with a copy of it"
  else
    rm -f "$slot"
    echo "Removed $slot, a link to this repo's removed CLAUDE.md that git history no longer has"
  fi
}

unlink_instructions "$HOME/.claude/CLAUDE.md"
unlink_instructions "$HOME/.codex/AGENTS.md"

# Links whose target no longer exists are skills and hooks renamed or removed upstream.
# Nothing else prunes them, and a stale skill stays listed as one Claude cannot load. Only
# links pointing back into this repo are touched: a skill symlinked in from somewhere else can
# be temporarily unresolvable, and deleting it then would break an install this does not own.
pruned=0
pruned_hooks=()
for dir in "$hooks_dir" "${skill_dirs[@]}"; do
  for link in "$dir"/*; do
    if [ -L "$link" ] && [ ! -e "$link" ]; then
      case "$(readlink "$link")" in
        "$repo_dir"/*)
          echo "Pruned stale link $(basename "$link") -> $(readlink "$link")"
          [ "$dir" = "$hooks_dir" ] && pruned_hooks+=("$(basename "$link")")
          rm "$link"
          pruned=$((pruned + 1))
          ;;
      esac
    fi
  done
done

for hook in "$repo_dir"/hooks/*.py; do
  ln -sf "$hook" "$hooks_dir/$(basename "$hook")"
done

# A skill scoped to another environment is left out rather than linked. Every installed skill
# spends its description on every session, so one that cannot run here never repays it.
# scripts/skills_for.py is the only reader of the frontmatter key, shared with the pod procedure.
# -sfn (not -sf): don't follow an existing dir symlink, or re-runs nest the link inside it
while IFS= read -r name; do
  for dir in "${skill_dirs[@]}"; do
    ln -sfn "$repo_dir/skills/$name" "$dir/$name"
  done
done < <(python3 "$repo_dir/scripts/skills_for.py" "$environment")

# An excluded skill may still be linked from an earlier run, here or in another environment. Its
# target exists, so the prune above leaves it: a dangling link is all that one removes. Without
# this it stays listed as a skill that cannot run, which is the cost the exclusion exists to save.
excluded=0
while IFS= read -r name; do
  excluded=$((excluded + 1))
  removed=0
  for dir in "${skill_dirs[@]}"; do
    link="$dir/$name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$repo_dir/skills/$name" ]; then
      rm "$link"
      removed=1
    fi
  done
  [ "$removed" -eq 0 ] || echo "Unlinked $name: it is scoped to another environment than $environment"
done < <(python3 "$repo_dir/scripts/skills_for.py" "$environment" --excluded)

echo "Linked hooks into ~/.claude and skills into ~/.claude/skills and ~/.agents/skills, for the $environment environment"
[ "$pruned" -eq 0 ] || echo "Pruned $pruned stale link(s)"
[ "$excluded" -eq 0 ] || echo "Left out $excluded skill(s) scoped to another environment"

python3 "$repo_dir/merge_settings.py" "$repo_dir/settings.json.example" "$HOME/.claude/settings.json" "${pruned_hooks[@]+"${pruned_hooks[@]}"}"

# The merge rewrites settings.json in place, and hooks name their script by path, so a file
# Claude cannot parse or a hook pointing at a script that is not installed both fail silently
# at the point of use rather than here.
python3 - "$HOME/.claude/settings.json" "$HOME/.claude/hooks" <<'PY'
import json, os, re, sys

settings_path, hooks_dir = sys.argv[1], sys.argv[2]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (OSError, json.JSONDecodeError) as error:
    sys.exit(f"FAILED: {settings_path} does not parse after the merge: {error}")

missing = []
for event, groups in settings.get("hooks", {}).items():
    for group in groups:
        for hook in group.get("hooks", []):
            for script in re.findall(r"\.claude/hooks/([\w.-]+)", hook.get("command", "")):
                if not os.path.exists(os.path.join(hooks_dir, script)):
                    missing.append(f"{event} -> {script}")

if missing:
    sys.exit("FAILED: settings.json names hooks that are not installed: " + ", ".join(missing))

print("Verified: settings.json parses and every hook it names is installed")
PY
