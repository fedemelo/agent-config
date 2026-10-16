# Wire up a devspaces pod

For an ephemeral, prompt-seeded devspaces workspace. Reached from the [wire-up](../SKILL.md) skill, which decides that this is the right procedure.

## Read this first

**Do not run `install.sh` from either repo, and do not run this skill's owned-machine procedure.** They are written for a host you administer and they actively break a pod:

- They **symlink** skills into `~/.claude/skills/`. Claude Code's skill discovery does not follow symlinks, so a symlinked skill is silently never loaded. It appears installed and does nothing. **Copy, never symlink.**
- claude-config's installer installs `PreToolUse` hooks and merges entries into `~/.claude/settings.json`. In a pod, team policy comes from `/etc/claude-code/managed-settings.json`, and repo-level `.claude/settings.json` files are deliberately pinned to `{}` by a background guard. Writing into that machinery is how you break a session, and one of the hooks blocks bare `git commit`, which pods need.
- git-tools' installer sets `core.hooksPath` **globally** and installs a `commit-msg` hook that strips `Co-Authored-By` trailers. See the conflict below; it is not a preference here.
- Both installers prune links pointing into their repo, so a re-run after a pod rebuild deletes what it cannot see.

Everything here is done by hand instead: clone to a scratch directory, copy the files, let one small script re-copy them on each start. It is a handful of `cp` commands, and the manual path is the supported one.

## Why the layout is what it is

`~/.claude` is **rebuilt from the pod image on every start**, so anything written there directly is gone in the next workspace. `/mnt/personal` is the per-user persistent share, mounted into every one of that user's workspaces and surviving rebuilds, stops and deletes. So the durable copy lives on the share, and the user's dotfiles `install.sh` copies it into `~` on every start.

Two tempting shortcuts that do not work:

- **Symlinking `~/.claude/skills` at the share** — skill discovery does not follow symlinks (upstream bug).
- **`CLAUDE_CONFIG_DIR`** — it relocates *all* of `~/.claude`, including `.credentials.json`, onto a shared mount.

Confine everything to the share and the user's home. **Never install any of this into a repository** — not `canals`, not any repo under `~/repositories`. These are one person's tools; a repo checkout is shared with the whole team, and their `.claude/` directories are managed by the pod image.

## Procedure

Paths below assume the standard `$HOME` and share; take the share root from the `/mnt/personal` the router already confirmed.

### 1. Clone the sources to scratch, read-only

```sh
git clone --depth=1 https://github.com/fedemelo/claude-config /tmp/claude-config-src
git clone --depth=1 https://github.com/fedemelo/git-tools    /tmp/git-tools-src
```

Scratch, not a permanent checkout. Delete both when finished so no one later mistakes them for an install.

Nothing in either clone is installed, and the only thing run out of one is `scripts/skills_for.py` in step 2, which reads frontmatter and prints names. That is not a new thing to trust: this procedure is itself read from the same clone, per the paragraph below.

The clone also carries the current version of this procedure. If `/tmp/claude-config-src/skills/wire-up/targets/devspaces.md` differs from the copy you are reading, the installed copy is out of date: read the cloned one and follow that instead.

### 2. Copy the skills

```sh
mkdir -p /mnt/personal/claude/skills
python3 /tmp/claude-config-src/scripts/skills_for.py devspaces /tmp/claude-config-src/skills \
  > /tmp/claude-skills-here
while IFS= read -r name; do
  cp -a "/tmp/claude-config-src/skills/$name" /mnt/personal/claude/skills/
done < /tmp/claude-skills-here
```

Every skill this environment gets, which is every skill that does not declare itself scoped to a different one, and `cp -a` to keep the trees and the file modes. The list comes from `skills_for.py` rather than from reading the frontmatter here, because `install.sh` selects with the same script on a machine you own: two readers of that key would eventually disagree about which skills a pod gets. Keep `/tmp/claude-skills-here` until the deletion below has run, which reads it.

`wire-up` is one of them: it comes with its `targets/` directory, so a later refresh is one `/wire-up` and no commands typed by hand. Its `SKILL.md` only chooses a file to read. It reads the pod signals, all of which hold here, so it reads this file and never the owned-machine one, and the choosing itself runs nothing. The copy of the skill being followed right now is overwritten by this step, which changes nothing, since this session has already read it.

To refresh a single skill rather than all of them, name its directory instead: `cp -a /tmp/claude-config-src/skills/commit /mnt/personal/claude/skills/`.

The same share serves both runtimes. Claude reads `~/.claude/skills/` and Codex reads `~/.agents/skills/`, and step 4 copies the share into each. The `agents/openai.yaml` beside each `SKILL.md` is Codex's copy of the invocation policy, which Claude ignores, so nothing else is needed for Codex. The pod image gives Codex the team's `canals` skills plugin but none of these; without the copy into `~/.agents/skills/`, a Codex session in a pod has no personal skills at all.

Skip `hooks/` and `settings.json.example` from claude-config. Those are harness changes, not skills; see the conflicts below.

**Then delete whatever the list above does not name.** A copy only adds, so a skill the repo no longer has, or no longer gives this environment, stays on the share and gets copied back into both runtimes on every start. Remove those from the share, and remove the same names from `~/.claude/skills` and `~/.agents/skills`, which step 5 will not do for you:

```sh
for dir in /mnt/personal/claude/skills/*/; do
  name="$(basename "$dir")"
  grep -qxF "$name" /tmp/claude-skills-here && continue
  rm -rf "/mnt/personal/claude/skills/$name" "$HOME/.claude/skills/$name" "$HOME/.agents/skills/$name"
  echo "removed $name"
done
```

Comparing against the list, not against the clone's directories, is what makes one rule cover three cases: a skill deleted upstream, a skill renamed, and a skill that still exists but has since been scoped to another environment. It only touches names the share already holds, so it leaves anything the pod image put in either skills directory alone. Keep what it prints; the report names it.

### 3. Copy the git tools

```sh
mkdir -p /mnt/personal/claude/git-tools/bin
cp -a /tmp/git-tools-src/bin/git-review-feedback /mnt/personal/claude/git-tools/bin/
```

**One tool, not three.** `git-land` and `git-todo` back the `land` and `todo` skills, which are scoped to a machine the user owns and are never installed here, so copying them would leave a pod holding tools with nothing to call them. `git-review-feedback` is the one the review skills are built on, and those do run here.

It is a standalone script with no install step. `~/.local/bin` is already on `PATH` in the pod image, and git resolves an executable named `git-<name>` there as the subcommand `git <name>`, so copying it is the whole installation: no config key, nothing to set. Keep the executable bit (`cp -a` does); a copy that loses it fails as "command not found".

Apply removals here too, for the same reason as the skills:

```sh
for f in /mnt/personal/claude/git-tools/bin/*; do
  name="$(basename "$f")"
  [ "$name" = "git-review-feedback" ] && continue
  rm -f "/mnt/personal/claude/git-tools/bin/$name" "$HOME/.local/bin/$name"
  echo "removed $name"
done
```

Comparing against the one name a pod gets, rather than against the clone, is what clears a `git-land` or `git-todo` left behind by an earlier wire-up that still copied them. If `/tmp/git-tools-src/bin` holds some other script, report it rather than copying it. Whether a new tool belongs in a pod is the user's call.

Optionally also copy `hooks/commit-msg` and `ignore` onto the share for reference, but **do not wire either one** — each needs a global `git config` key, and the hook conflicts with pod policy. Leave `core.hooksPath` and `core.excludesFile` unset.

### 4. Ensure the dotfiles install script

The pod runs the first of `install.sh`, `bootstrap.sh`, `setup.sh` found **directly** in `/mnt/personal/dotfiles/` on every start. Discovery keys on the script, not the directory. If the user already has one, **add to it** rather than replacing it — it may carry shell config, gitconfig and more. A script written before Codex was supported copies skills into `~/.claude/skills` only; replace that block with the one below rather than adding a second.

The blocks this setup needs:

```bash
# Personal skills + slash commands: copy from the persistent share into
# ~/.claude (Claude Code) and ~/.agents (Codex) on every start. Copy, don't
# symlink — Claude Code's skill and command discovery doesn't follow symlinks.
if [ -d /mnt/personal/claude/skills ]; then
  for skills_dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    mkdir -p "$skills_dir"
    cp -a /mnt/personal/claude/skills/. "$skills_dir/"
  done
fi

if [ -d /mnt/personal/claude/commands ]; then
  mkdir -p "$HOME/.claude/commands"
  cp -a /mnt/personal/claude/commands/. "$HOME/.claude/commands/"
fi

# git review-feedback, which the PR-review skills are built on. It is the only
# git-tools subcommand a pod gets: git land and git todo back skills scoped to
# an owned machine and never installed here. ~/.local/bin is already on PATH
# and git finds a `git-<name>` executable there as the subcommand `git <name>`.
if [ -d /mnt/personal/claude/git-tools/bin ]; then
  mkdir -p "$HOME/.local/bin"
  cp -a /mnt/personal/claude/git-tools/bin/. "$HOME/.local/bin/"
fi
```

It runs on **every** start, so it has to stay idempotent: guard on the source directory, `mkdir -p`, `cp -a` over whatever is there. A failing install script does not block pod startup, so a broken one fails quietly — which is why step 6 verifies rather than trusts.

Note this copies in one direction, share to home. A skill edited in `~/.claude/skills/` or `~/.agents/skills/` is overwritten on the next start; the share is the source of truth.

### 5. Apply it

```sh
workspace-utils dotfiles
```

Same command the pod runs at startup, so no restart is needed. It reports `using local dotfiles in /mnt/personal/dotfiles` when it picks the script up; if it does not say that, the script is misnamed or not directly in that directory.

**Skills are loaded when a session starts, so newly copied ones are not callable in the session that copied them.** Say so rather than letting the user think it failed. Everything else, the git subcommands included, works immediately.

### 6. Verify, then clean up

Check, do not assume:

1. **No symlinks:** `find ~/.claude/skills ~/.agents/skills -type l` prints nothing.
2. **Content matches:** `diff -r /tmp/claude-config-src/skills <dir>` reports no difference inside any skill from the repo, for both `~/.claude/skills` and `~/.agents/skills`. A name that appears only in one of those came from the pod image and is not yours.
3. **Deletions took:** every name the removal loops printed is gone from `/mnt/personal/claude/skills`, `~/.claude/skills`, `~/.agents/skills`, `/mnt/personal/claude/git-tools/bin` and `~/.local/bin`.
4. **Frontmatter matches directory:** each `SKILL.md`'s `name:` equals its directory name, or neither runtime will load it.
5. **References resolve:** every `[[name]]` in a copied skill names a skill that was also copied. Missing ones are dangling.
6. **The one tool resolves, and only it:** `command -v git-review-feedback` finds it, then a real read, e.g. `git review-feedback <a recent PR number>` from a repo. `--help` through the `git` subcommand form hits a man-page error on the minimized pod image, which is git, not a broken tool; use `git-review-feedback --help` with the hyphen. `command -v git-land git-todo` must find **nothing**: either one resolving means an earlier wire-up copied it and the removal loop has not cleared it.
7. **Nothing leaked into a repo:** `git status --short` in each repo you touched is clean, and none of the skill names appear in any repo's `.claude/skills/` or `.agents/skills/`.

Then `rm -rf /tmp/claude-config-src /tmp/git-tools-src`.

## Conflicts to raise, not resolve

Both of these are real disagreements between the user's conventions and pod policy. Name them and let the user decide; do not quietly pick a side.

- **Commit attribution.** The `commit` skill forbids a `Co-Authored-By` trailer, and git-tools' `commit-msg` hook strips one. The pod's managed settings (`/etc/claude-code/managed-settings.json`, key `attribution.commit`) inject exactly that trailer, and organization policy requires it. Managed settings outrank a user-scope skill. Installing the hook would also rewrite commit messages in **every** repo in the pod, since `core.hooksPath` is global.
- **Repo-specific delivery skills.** A repo may mandate its own PR workflow — `canals` tells every agent to use `/canals:ship-it` — which overlaps `commit` and `open-pr`. Both sets are installed; which wins is the user's call, per repo.

Also worth stating plainly: without git-tools, the review skills (`local-review`, `address-review`, `discussion-audit`, `fact-check-my-review`) lose the `git review-feedback` read they are built on, and since no hooks are installed here the failure is a bare `git: 'review-feedback' is not a git command` rather than anything that explains itself. Those skills say to report that and stop, which is the right answer either way.

## Updating later

No symlinks means no automatic propagation, so picking up upstream changes is a re-run: type `/wire-up` in a Claude session or `$wire-up` in a Codex session, in any pod, and this file is followed again from the top. Steps 1 to 3 re-clone, copy the changed skills and tools over the old ones and delete the ones the repo no longer has; step 5 puts the result in `~/.claude` and `~/.agents`. As always, the updated skills are callable in the next session, not the one that ran it.

To edit a skill for yourself, edit it under `/mnt/personal/claude/skills/` and re-run `workspace-utils dotfiles`; the copies in `~/.claude` and `~/.agents` are disposable. That edit does not survive the next `/wire-up`, which copies the repo's version over it.

## Report

Say which skills and tools were copied, which were deleted because the repo no longer has them, that the dotfiles script was created or extended, what the verification showed for each runtime, and that a new Claude or Codex session is needed before the skills are callable. List the conflicts above last, as decisions waiting on the user.
