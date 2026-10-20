---
name: pr-from-review
description: Spins a point from a PR review off into a PR of its own, stacked on the reviewed PR's branch instead of changing that PR. Hands the work to a separate space, where it is built on a fresh branch off the reviewed branch with linear history and opened as a draft assigned to you, with no reviewers. Works on your own PRs and on other people's.
disable-model-invocation: true
audience: others
---

Turn a point raised in a review into a separate PR, stacked on top of the PR the review was about. The reviewed PR is never changed: the point is out of its scope, too big for it, or not its author's job, so it gets a PR of its own.

There are two halves, and an invocation runs exactly one of them. One whose arguments start with `build` is a space this skill opened: follow "Build it". Any other invocation is the user's: follow "Hand it off". This split keeps the session the user reviews in from ever touching code.

## Hand it off

### What the PR is about

The PR is about the point or points the user handed over, and nothing you work out yourself. Something is handed over in one of two ways:

1. Pasted into the invocation, as the text of a review comment or finding.
2. Named in the invocation, by a reference that matches exactly one thing in this session, such as "comment 5 above" or "L3 and L7".

If neither holds, stop and ask the user what the PR should be about. That covers an invocation with nothing pasted, a reference that matches nothing, and one that matches more than one thing, such as "comment 5" with two reviews in the session. Never pick a point from context, however obvious the candidate looks and even if this session holds only one review. A PR built on the wrong point is a branch, a push, and a draft for the user to find and throw away.

Copy each point whole and word for word: every field of a local-review finding, the full text of a comment. Never summarize it, since the space knows nothing else about it.

Several points make one PR. The user invokes this again to get separate ones.

### What it stacks on

The PR the point was raised on. If the point comes with its PR, as a thread URL does, or a review in this session that names the PR it reviewed, that is the PR given. Otherwise load the [[pr-target]] skill and resolve it by that rule.

```sh
gh pr view <pr> --json number,url,state,headRefName,baseRefName,isCrossRepository
```

1. `isCrossRepository` true: stop. The branch lives in a fork, and a PR here cannot be based on it.
2. `OPEN`: the base is `headRefName`. In a stack, that is exactly the branch the reviewed PR adds, which is the one to build on.
3. `MERGED`: the base is `baseRefName`, the branch the reviewed PR merged into, which now holds its change.
4. `CLOSED` without merging: stop. Its change is on no branch anyone will merge.

Settle this here rather than in the space, so that a PR this cannot stack on fails in front of the user instead of in a space they have not opened yet.

### Open the space

Load the [[side-session]] skill and open one space by it, named `pr-from-review-<n>-<slug>`, with `<slug>` two to four words naming the change. Seed it with:

```
/pr-from-review build
PR: <url>
Base: <base>
Points:
<each point, word for word>
```

Write `$` for `/` in a runtime that invokes skills that way, as Codex does.

Do nothing else here: no branch, no code, no commit. Never attach to the space or wait for it.

### Report

Where the space is, as side-session's target file says to reach it, the base it will stack on, and which points it was seeded with. Not the PR, which does not exist yet.

## Build it

Hard constraint: the PR is a draft, with no reviewers, and nothing is posted on the reviewed PR or requested of anyone. The user decides when it is ready and who sees it.

1. Read the seed. If it lacks the PR, the base, or the points, stop and say what is missing. Never fill a gap from the reviewed PR or from guesses.
2. Confirm the working tree is clean with `git status --porcelain`, and stop if it is not. A space has a checkout of its own, so anything in it was not put there for this.
3. Cut a fresh branch, named from the change, off the latest base:

```sh
git fetch origin
git switch -c <branch> origin/<base>
```

4. Understand each point before changing anything. It was written about the reviewed PR, so read that PR's diff with `gh pr diff <url>` and the code around it. If a point is still unclear, stop and ask; do not guess. If the code shows a point is wrong, or already handled on the base, stop and say so rather than opening a PR that changes nothing or the wrong thing.
5. Make the change the points ask for, and nothing else: no opportunistic cleanup, no unrelated fixes. Beware altering behavior beyond what the points ask. Load the [[comment-hygiene]] skill and apply it to comments in the code you touch.
6. Commit by following the [[commit]] skill; invoke it so its exact conventions load. Then check the history is linear and the diff clean: `git log --oneline origin/<base>..HEAD` lists only your commits, with no merges, and `git diff origin/<base>...HEAD` shows only your change.
7. Push and open the draft against the base:

```sh
git push -u origin <branch>
gh pr create --draft --base <base> --assignee @me --title "<title>" --body "<description>"
```

   Load the [[pr-description]] skill and write the description by it. Never add AI attribution to the title or body, per the [[commit]] skill.

8. Report the PR's URL, the base it stacks on, what changed, and anything you decided not to commit, with why. Add that the PR needs restacking if the reviewed PR's branch is rebased or force-pushed, since nothing here watches for it.
