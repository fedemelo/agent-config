---
name: land
description: Pushes local commits to the tracked branch with the git-land tool, which wraps them in a disposable, auto-merged PR.
disable-model-invocation: true
environment: owned-machine
---

Run `git land` from the current repo. Do not write code, open a PR by hand, or call `gh pr create` or `gh pr merge` yourself, since `git land` already does all of that. If `git-land` is not installed, a hook blocks the command and says so; report that to the user instead of replicating the behavior with raw `gh` or `git` commands.

This is for solo work that merges without review, on a branch that already tracks an upstream, normally the default branch. When the change should be reviewed before merging, or the current branch has no upstream at all, `git land` is the wrong tool and refuses to run; put up a real PR with the [[open-pr]] skill instead.

Usage: `git land ["title"] [--until <commit>] [--each] [--force]`

The title is optional and defaults to the last commit's subject. Pass it in quotes only when the user gave one, or when a clear one-line summary is obvious from context; otherwise omit it. Always pass one when the land covers several commits, since the last commit's subject usually describes the smallest part of the work.

## Before running it

1. Check what will land: `git log --oneline @{u}..HEAD`. Every commit listed goes in, including ones from earlier sessions that have nothing to do with the task at hand. If the list holds more than the current work, land just the relevant prefix with `--until`, or ask which commits to land. Never land unfamiliar commits blindly.
2. Never `git push` first. `git land` does the pushing itself. A manual push moves the upstream forward, so `git land` then reports nothing to land and the work arrives on the branch with no PR recorded at all, which defeats the entire purpose. Landing is the only publish step.
3. Uncommitted and staged changes never land, since `git land` only ever lands what is already committed. If the work is not committed yet, commit it first by following the [[commit]] skill.

## How much gets landed

`git land` works on the commits ahead of the branch's upstream, and by default lands all of them as one PR. Two flags split that up:

1. `git land --until <commit>` lands only up to and including `<commit>`, leaving everything above it local and unlanded. It takes any commit-ish, so `--until HEAD~2` works as well as a hash from `git log --oneline`. Run it again for the next batch.
2. `git land --each` lands every commit ahead as its own PR, each titled from its own commit subject. Add `--until` to cap how far it goes. Do not pass a title with `--each`; the command refuses it. Never reach for this on your own; see below.

Only a prefix of the history can be landed, because commits form a chain rather than a set: landing the first two and then the rest is fine, but landing the first and third while skipping the second is impossible. Nothing here rewrites history to work around that.

## Choosing the shape

Decide this before landing, from what the commits actually are:

1. One PR for one cohesive change, however many commits it took: plain `git land "<title>"`. This is the normal case and the default; prefer it whenever the commits add up to a single piece of work.
2. Several PRs when the branch genuinely holds more than one distinct piece of work: `git land --until <last commit of the first piece>`, then land again for the next.

Never use `--each` unless the user explicitly asks for one PR per commit. Splitting one piece of work across a PR per commit scatters it over several records, so nothing can be read, reviewed, or reverted as a unit, and a one-file commit that only makes sense alongside its siblings becomes its own PR. Landing several commits together in one PR is almost always correct: the commits of one change belong to one PR. Choose between option 1 and option 2 above; `--each` is not a third option to weigh.

After each run it prints how many commits remain ahead of upstream, so an unfinished stack is visible rather than silently left behind.

Because only prefixes can be landed, the commits belonging to one PR must sit together in history. That ordering is decided while committing, not here, so follow the [[commit]] skill's grouping rules first; a file whose changes belong to two different PRs has to be split at staging time, since no flag here can separate them afterwards.

`git land` refuses to run in a few cases. When it refuses because the branch is behind its upstream, run `git pull --rebase` and land again if the rebase applies cleanly. If it stops on a conflict, run `git rebase --abort` to restore the branch as it was, and report the conflict instead of resolving it. The rebase rewrites the local commits, so take any `--until` hash from `git log --oneline @{u}..HEAD` again afterwards. It also refuses when there is nothing to land, including an `--until` commit that is already on upstream, is not an ancestor of `HEAD`, or sits behind upstream; surface that message rather than working around it. It also refuses when the remote repo is not owned by the authenticated GitHub user, which `--force` overrides; add `--force` only when the user explicitly confirms this is solo, unreviewed work they want merged automatically on someone else's repo, never preemptively to clear a refusal.

For context, and not to be replicated by hand: it pushes the commits being landed to a disposable `tmp/...` branch, opens a PR, comments that the PR was auto-created and merged without review for recordkeeping, fast-forwards them onto the base branch so signatures survive, and deletes the temp branch. If that push is refused by branch protection it falls back to a server-side rebase-merge, which rewrites the landed commits and then replays any still-unlanded ones on top, so a partial land never strands local work. If an immediate merge is blocked by required checks or review, it enables auto-merge instead of hanging.
