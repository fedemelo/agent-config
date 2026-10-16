# Wire up a machine you own

For a host with a persistent home directory that you administer: your laptop, your desktop. Reached from the [wire-up](../SKILL.md) skill, which decides that this is the right procedure. Do not follow it in a devspaces pod; that has its own file beside this one.

Two repos hold everything, and each installs itself. Your job is to find them, pull them, run their installers, and check the few things the installers deliberately leave to a human. Never wire anything by hand: the links, `~/.claude/settings.json` and `core.hooksPath` belong to the installers, which are idempotent and verify their own work, so a second copy of that logic here would drift from the one that runs everywhere else.

## Find the repos

- **agent-config** — `dirname "$(dirname "$(readlink ~/.claude/skills/commit)")"`. If that link is missing, the repo is the one this skill was loaded from.
- **git-tools** — `dirname "$(dirname "$(readlink "$(command -v git-land)")")"`, else `~/git-tools`. If it is nowhere, clone `https://github.com/fedemelo/git-tools` beside agent-config: without it the `land`, `todo` and PR-review skills are inert, and a hook blocks their commands.

## Update each

git-tools first, then agent-config, because the skills over there call flags that only a current `git-land` has.

```sh
git -C <repo> pull --ff-only && <repo>/install.sh
```

`--ff-only` on purpose: a dirty tree, a branch that has diverged, or local commits mean someone was working in that repo, and a merge or rebase to get the pull through is a decision that is not yours. Stop, name the repo and what you found, and leave it untouched.

If an installer exits non-zero, report its output as it stands and stop. Both fail loudly at the one thing they cannot verify silently — a `commit-msg` hook that is not stripping trailers, a `settings.json` that no longer parses or names a hook that is not installed — and working around that leaves a setup that looks installed and is not.

## Check what the installers leave out

Each of these fails at first use rather than at install time, so check every one of them and report them together:

1. `~/.local/bin` is on `PATH`, via `command -v git-land git-todo git-review-feedback`. If the files exist but the commands do not resolve, give the user the line to add to their shell rc and ask before editing it yourself.
2. `git config --global user.email` is set. A fresh machine has none and every commit fails. Point at git-tools' `gitconfig.example` and let the user fill in their name, email and signing key. Never guess any of the three.
3. `gh auth status` succeeds. Almost every skill drives `gh`.
4. Every skill this environment gets is linked in both `~/.claude/skills/` and `~/.agents/skills/`. That is not the same as every directory under `<agent-config>/skills/`: one whose frontmatter scopes it to another environment is left out on purpose, and the installer reports which. Take the list to check against from `python3 <agent-config>/scripts/skills_for.py owned-machine`, never from the directory, or a correct install reads as a broken one. A skill added upstream only appears once the installer has run, which is the whole reason this skill exists: editing a skill takes effect immediately through the symlinks, adding or removing one does not.

## Report

Say what each repo pulled or that it was already current, what the installers changed (new links, pruned links, skills left out as scoped to another environment, settings merged), and, last, whatever the user still has to do themselves. If nothing changed and every check passes, say that in one line.
