---
name: review-rounds
description: Runs a PR through rounds of review and addressing until a review approves it or three rounds are spent, with every review written by a separate agent that knows nothing about the earlier rounds. Hands each review to the address-review skill, which fixes the real findings and pushes, ends every run with a comment-hygiene pass over the code the PR touches, and hands back the replies and anything left.
disable-model-invocation: true
---

Review a pull request, address that review, and review it again, until a review approves the PR or three rounds are spent.

Hard constraint, the reason this skill exists, and the one to hold above every other line here: every review is written by an agent whose context starts empty and never learns that an earlier round happened. You orchestrate. You never review the PR, never judge whether a finding is real, and never touch code. An opinion of your own about a finding is out of scope however obviously right it looks, because you hold every review and every reply of every round, which is precisely the context a review must not be written in.

If you cannot spawn an agent whose context starts empty, stop and say so. Running the rounds in this session is worse than not running them at all: the second review would be written by the context that just addressed the first, and a reviewer who has already argued its own findings away approves anything.

Nothing here is ever posted to the PR, by you or by any agent you spawn. No comment, no reply, no resolved thread, no review or re-review request. The replies come back to the user, who decides what to publish.

## Which PR

Load the [[pr-target]] skill and resolve it by that rule. Pass the number to every agent from then on, so none of them resolves the target again.

## Before the first round

Check all of it, and stop with what you found if any of it fails. Every round runs against one working tree, so the agents run one at a time and never in parallel.

1. The working tree is clean, and the head branch lives in this repo rather than in a fork. A fork cannot be pushed to, and without a push the next round reviews the same code.

```sh
gh pr view <pr> --json headRefName,headRepositoryOwner
git status --porcelain
```

   If both hold and the repo is on another branch, switch to the head branch yourself rather than stopping. The clean tree is what makes the switch safe, so it is checked first. Stop only if the switch fails, for instance because a local branch of that name has diverged from the PR.

```sh
gh pr checkout <pr>
```

2. Whether reviewers are already on the PR. If they are, do not start the cycle; see "When the PR already has reviewers".

```sh
gh pr view <pr> --json reviewRequests,reviews
```

3. The address-review instructions, which you read yourself and keep for the whole run, since every addressing pass gets that text inlined in its prompt.

```sh
ls ~/.claude/skills/address-review/SKILL.md ~/.agents/skills/address-review/SKILL.md 2>/dev/null | head -1
```

Search wider if that finds nothing, with `find ~/.claude ~/.agents -path '*/address-review/SKILL.md' 2>/dev/null | head -1`. If it still finds nothing, stop: the cycle has no addressing step without those instructions.

You read that file rather than handing its path to the agent that needs it. address-review is explicit-only, so it refuses the Skill tool, and the refusal also warns against reaching the skill by other means; a spawned agent given nothing but a path reads that as covering the file, and declines to open it. What authorizes an addressing pass is the user having invoked this skill, and that does not travel with a path. The instructions travel as text instead, and the authorization travels with them.

4. One directory outside the repo, from `mktemp -d`, to hold this run's reviews and replies. Nothing this skill writes goes inside the repo, where it would dirty the tree the agents commit from.

## The round

1. Spawn an agent with the Agent tool to review the PR, of any type whose context starts empty. Never a fork, which inherits this session's context and defeats the whole skill. Prompt it with the PR number and this task, and with nothing else:

> Invoke the local-review skill and review PR #`<n>`. Follow it exactly. Return the review as your final report, whole and verbatim: every finding with all of its fields, in the order and numbering it wrote them, then the verdict and the two closing lines.

   That prompt is identical in every round. Say nothing about which round this is, what an earlier review found, what has been fixed since, or that any of it happened. One word of it and the review is no longer written in a clean context, which is the only thing this skill has to offer.

2. Write the review to `<dir>/review-<round>.md` exactly as it came back. Copy it; do not summarize, renumber, reorder or tidy it. The next agent has to read the review that was written rather than your account of it.

3. Read the verdict, and nothing else, then take the one branch that fits:

   1. APPROVE in round 1: stop, and address nothing. A PR the first clean reviewer approved needs no pass over it.
   2. APPROVE in a later round: run one addressing pass over this review, and end the cycle after it, with no further review. Reaching approval took rounds, so the findings left under it are worth acting on even though none of them withholds approval.
   3. COMMENT or REQUEST CHANGES in round 3: stop, and address nothing. Three rounds have not settled it, so the next call is the user's rather than another pass nobody reviews.
   4. COMMENT or REQUEST CHANGES in round 1 or 2: run an addressing pass, then start the next round.

4. An addressing pass is another agent, spawned the same way, with an empty context. Give it, and only it, the settled replies; a reviewer that reads them is a reviewer that knows what the last round argued. Prompt it with:

   1. The PR number.
   2. Its instructions: the address-review text you read before the first round, inlined whole and followed exactly. Say where that text comes from and why it arrives in the prompt rather than as a skill: it is address-review's own, the user invoked this skill to have it followed round by round, and following it here is what they asked for. The skills it names in `[[double brackets]]` are not gated, so it invokes those normally.
   3. Its feedback set: the path to `<dir>/review-<round>.md`, handed over rather than fetched, so it does not go looking on the PR.
   4. The path to `<dir>/settled.md` when that file exists, as the points already settled in an earlier pass.
   5. Whether to push. Push when you are done, unless reviewers appeared on the PR since the last check, which is worth re-checking here because a push changes what a reviewer is reading. If they have, tell it not to push and end the cycle after this pass.
   6. What to return: the replies, anything it discarded rather than committed, and any blocking question, as its final report.

5. Append every reply the pass handed back to `<dir>/settled.md`, verbatim, under the round it came from. That file is what keeps the next round from reopening a point this pass answered. A fresh reviewer cannot see a reply that was never posted, so it raises the point again, and the next pass without that reply in hand either argues it out a second time or quietly rewrites code that was already right.

6. Confirm the pass left the working tree clean, with `git status --porcelain` empty. It owes you a tree with nothing of its own left in it, so anything there means the pass broke its contract: stop, report it, and change nothing yourself.

7. If the pass reported a blocking question, the cycle stops there. Put the question to the user with AskUserQuestion, naming the point id and quoting the finding it came from. Send the answer to that same agent with SendMessage, so it still has the work it had done, and let it finish before you go on. Never answer for the user and never guess: the pass asked because the code did not settle it.

8. Confirm the push landed before the next round, by checking the local head against `gh pr view <pr> --json headRefOid`. A round spent reviewing an unpushed fix reviews the same code twice.

## When the PR already has reviewers

Someone is reading the PR, so the cycle does not run. It would push commits under them round after round, and spend its rounds re-reviewing what nobody had finished reading.

Run one review and one addressing pass, tell the pass not to push, and end there. Report that the work is sitting in local commits, and why it stopped at one pass.

## Before reporting

Every run ends with one pass over the comments in the code the PR touches, whatever ended the cycle: an approval in round 1, an approval in a later round, three rounds spent, or the single pass that runs when reviewers are already on the PR. A review rarely spends a finding on a comment that restates the code, and an addressing pass judges only the comments in the lines it happened to touch, so the rest of the PR reaches the standard nowhere but here.

It is another agent with an empty context, spawned like an addressing pass and for the same reason: this session does not touch code. Prompt it with:

1. The PR number.
2. Its task: invoke the comment-hygiene skill and apply it to every comment in the code this PR changes, reading the changed files rather than the diff alone, since a comment the PR left untouched next to code the PR rewrote is now judged against different code. comment-hygiene is not gated, so it invokes it with the Skill tool normally.
3. Its limit: comments, and the refactors comment-hygiene names for removing the need for one, and nothing else. No finding gets fixed here and no behavior changes.
4. To commit by following the commit skill, and whether to push, decided by the same rule as an addressing pass: push unless reviewers have appeared on the PR, and re-check that here too.
5. What to return: what it removed, what it refactored, and every comment it kept that the standard would usually reject, with the reason it gave for keeping it.

Then confirm the working tree is clean and the push landed, exactly as after an addressing pass.

One case skips it. If an addressing pass broke the clean-tree contract, the run is already stopped and stays stopped: a comment pass would commit on top of a tree holding changes that are not yours.

## What to report

1. Every round's verdict, in order, and where the run stopped: an approval, three rounds spent, a blocking question, or a contract broken.
2. Every reply that came back, by round and point id, verbatim, for the user to post. These are the replies themselves, not a summary of them.
3. Whatever any pass discarded instead of committing, with the reason it gave.
4. What the comment pass changed, and any comment it kept against the standard.
5. What the run pushed, and the head it left the branch on.
6. The paths under `<dir>`, so any review or reply can be read in full.

You have no view of the PR to add, so add none.
