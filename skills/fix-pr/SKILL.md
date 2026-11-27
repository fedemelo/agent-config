---
name: fix-pr
description: Makes one of your PRs mergeable again. Resolves conflicts with its base, fixes the failing checks that are the PR's own fault, brings in the base when the base has since fixed a failure, and leaves the PR alone while the base is still broken. Merges the base in, except in a stack of PRs, where it rebases and restacks the PRs above. Takes the PR's URL or number, defaulting to the current branch's PR.
disable-model-invocation: true
audience: user
---

Make the user's PR mergeable: no conflicts with its base, and no failing check that the PR can fix.

Hard constraints, held above every other line here:

1. Never post to the PR: no comment, reply, review or reaction. Never change its draft state, its base, its reviewers or its title, and never merge or close it.
2. Never push to the base branch, and never force-push except as "Stacks" says. A force push is always `--force-with-lease`.
3. Never change a test or a check to make it pass when the code it tests is what's wrong, and never skip, disable or mark a check optional.

This is usually started by panopticon, sent as a message to the workspace that works on the PR, while the user is elsewhere. Nobody is there to answer a question during the run. Whatever needs the user goes in your final message, which panopticon shows them.

## Which PR

Load the [[pr-target]] skill and resolve it by that rule. Then read it:

```sh
gh pr view <pr> --json url,number,state,isDraft,headRefName,headRefOid,baseRefName,mergeable,statusCheckRollup,isCrossRepository
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
```

Stop and say why if the PR isn't open, or its head lives in a fork, which can't be pushed to. Check out the head branch if the repo is on another one and the tree is clean, with `gh pr checkout <pr>`. Stop if the tree isn't clean: uncommitted work is the session's, and fixing the PR on top of it would mix the two. Then `git fetch origin` and make the local branch match the PR's `headRefOid`. A local branch ahead of the remote has unpushed work: stop and report it rather than push it unasked.

`mergeable` can read `UNKNOWN` while GitHub works it out. Read it again after a few seconds, up to a minute.

## Is it a stack

The PR is in a stack when its base isn't the default branch, or another open PR uses its head as its base:

```sh
gh pr list --state open --base <headRefName> --json number,headRefName,url
```

The PRs that list returns, and in turn the ones based on each of them, are the PRs above it. Keep their numbers and heads: a rebase of this PR leaves them to restack.

## Bringing in the base

The PR needs its base when it conflicts with it, or when a failing check was fixed on the base after the PR branched (see "Failing checks").

- Not in a stack: `git merge origin/<base>`. Resolve each conflict so both sides keep what they meant: read the base's commits that touched the file and the PR's own change before choosing. Commit the merge with its default message.
- In a stack: `git rebase origin/<base>`, resolving each commit's conflicts the same way. A merge would put the base's commits into this branch's history, and every PR above would then show them as its own changes.

A conflict whose resolution needs a decision only the user can take, such as two features that can't both work as written, isn't guessed at. Abort with `git merge --abort` or `git rebase --abort`, so the branch is as it was, and put the conflict in your final message with the files and what each side wants.

After resolving, build and run the tests that cover the files that conflicted, where the repo lets you. A resolution that compiles but breaks behavior is worse than the conflict.

## Failing checks

Do this after any merge or rebase, on the checks of the PR's head. Skip it when every check passes or still runs. For each failing check, read why it failed:

```sh
gh run view <run id> --log-failed
```

The run id is in the check's link. A commit status from another service has only its link: open what it gives, or judge it from its name and the PR's change.

Then compare with the base. Read the same check on the base's newest commit, and on the commit the PR branched from (`git merge-base origin/<base> HEAD`):

```sh
gh api repos/<owner>/<repo>/commits/<sha>/check-runs --jq '.check_runs[] | [.name, .conclusion] | @tsv'
```

Each failure is one of four:

1. The PR's own fault: it fails on the PR and its log points at code the PR changed, or at a test the change should have updated. Fix it, run the failing test locally where you can, and commit by following the commit skill.
2. The base was broken and is fixed now: it fails where the PR branched and passes on the base's newest commit. Bring in the base, as above. That alone is the fix.
3. The base is still broken: it fails on the base's newest commit too, for the same reason. Change nothing for it. The user hears it from your final message, and panopticon sends the PR again once the base passes.
4. Flaky or the runner's fault: a timeout, a network error, a runner that died, or a test that fails with nothing the PR or the base changed. Run it again once with `gh run rerun <run id> --failed`, and report it. A check that fails the same way twice isn't flaky.

A failure you can't place in one of these is reported with what its log says, and left alone.

## Pushing

Check that the tests you ran pass. Then:

- Not in a stack: `git push`. A plain push is enough after a merge or a fix commit.
- In a stack: `git push --force-with-lease` once this PR was rebased, then restack.

To restack, take each PR above it in order, lowest first. For each one, check out its head, rebase the commits that are its own onto the new head of the PR below it, and push with `--force-with-lease`:

```sh
git rebase --onto <new head of the PR below> <old head of the PR below> <its branch>
```

The old head is the one you kept before rebasing. A restack that conflicts is resolved the same way, or aborted and reported when the conflict needs the user. Leave every branch you restacked checked out as it was, and come back to the PR's own branch at the end. Another workspace may hold a PR above: its local branch no longer matches after the force push, so say which PRs you restacked.

Confirm the push landed: `git rev-parse HEAD` matches `gh pr view <pr> --json headRefOid` for the PR and for each PR you restacked.

## Final message

The user reads this through panopticon, so start with one line saying how it ended: "Fixed #<n>: merged main and fixed the lint error", "Rebased #<n> onto #<m> and restacked #<k>", "#<n> waits on main: `<check>` fails there too", or "Couldn't fix #<n>: <why>". Then, each in a line or two:

- The commits pushed, by short hash and subject, and any force push with the PRs it touched.
- Each failing check, which of the four it was, and what you did about it.
- Each conflict or failure left for the user, with what each side wants or what the log says.
- Anything that went wrong in pushing.
