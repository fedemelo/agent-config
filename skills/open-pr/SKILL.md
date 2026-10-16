---
name: open-pr
description: "Puts up a clean PR for the current working changes: cuts a fresh branch off the latest default branch, commits only valid code changes, pushes, and opens a PR assigned to the user with a terse description."
disable-model-invocation: true
audience: others
---

Put up a clean PR for the changes already in the working tree. Do not write, refactor, clean up, or make opportunistic code changes; commit and open the PR with the existing changes exactly as they are.

## Cut a fresh branch off the latest default branch

Find the remote's default branch instead of assuming `main` or `master`:

```sh
git symbolic-ref refs/remotes/origin/HEAD --short
```

This reads a local ref, so it answers instantly and needs no network round trip. It prints `origin/<base>`: use that as the start point below, and drop the `origin/` prefix for `--base`. Prefer it over `git remote show origin`, which queries the remote and needs a pipe into `sed` to be readable, costing a permission prompt every run.

It exits non-zero when `origin/HEAD` is not set locally, which happens in a repo built with `git init` and `git remote add` rather than cloned. Fall back to the API, which returns the bare branch name:

```sh
gh repo view --json defaultBranchRef --template '{{.defaultBranchRef.name}}'
```

Decide between them on the exit status, never by matching the error text, which is localized.

Get fully up to date and cut a new branch from the remote default, never from the current branch:

```sh
git fetch origin
git switch -c <branch> origin/<base>
```

Uncommitted changes in the working tree carry over onto the new branch, which is intended. If the changes are already committed on the current branch, move them onto the new branch with `git cherry-pick` or `git rebase` rather than losing them. Name the branch clearly from the changes, for example `fix-token-refresh-race`.

## Commit only valid code changes

Inspect the changes with `git status`, then commit by following the [[commit]] skill; invoke it so its exact conventions load rather than committing by hand. Do not commit design files (any .md or .plan), secrets, environment files, or unrelated or accidental changes. Commit only code changes.

## Push and open the PR

Push the branch and open a PR that targets the default branch and is assigned to the user:

```sh
git push -u origin <branch>
gh pr create --base <base> --assignee @me --title "<title>" --body "<description>"
```

## PR description

Load the [[pr-description]] skill and write the description by it. Never add AI attribution to the PR title or body, per the [[commit]] skill.
