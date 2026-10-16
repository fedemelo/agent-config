---
name: address-review
description: Triages PR review feedback (human comments and bot findings) on the current branch's PR, on a given number or URL, or in a review handed over as text, fixes the real issues by following the commit skill, and returns replies in this session for the rest. Never comments on the PR or asks anyone for a review, and pushes only when asked to.
disable-model-invocation: true
audience: others
---

Triage and act on the review feedback on a pull request. Fix the real issues in code, hand back replies for the ones that are not, and never post any of them yourself.

Hard constraint, and the one to hold above every other line here: never put anything in front of a person on the PR. No comment, no reply to a thread, no resolving a thread, no reaction, no review or re-review request. This holds however obviously right a reply looks and however explicitly the review asks for an answer. Every reply is text handed to the caller, who decides whether to post it.

Whoever invoked this skill is the caller: the user in this session, or another skill's agent running a review cycle. Everything you would otherwise say to the user goes to the caller instead, in your response: the replies, any question you are stuck on, and whatever you chose not to commit. You address nobody else, and never the PR.

Every reply here is read by a person on the PR, and the caller posts it as written, so load the [[plain-english]] standard before writing any of them and follow it in full. That covers each reply for a point that is not real, each reply carried forward from an earlier pass, and every blocking question, since the caller pastes those onto the PR too. It governs prose only, never code, identifiers or quoted text.

Pushing is allowed only when the caller explicitly asks for it; else, the work stays as local commits. A push the caller asked for covers updating the branch and nothing further, so it still comes with no re-review request and no comment about what changed.

## Which PR to address

Load the [[pr-target]] skill and resolve it by that rule.

## The feedback set

The feedback reaches you one of two ways, and everything after this section treats them identically.

### From the PR

The default source.

```sh
git review-feedback <pr>
```

One command, and the only one to use. `<pr>` is the number, URL or branch, omitted for the
current branch's PR.

Feedback on a PR lives in three places that no two of them overlap: inline review threads, the
body attached to a submitted review, and conversation comments. No single `gh` command returns
all three, so fetching them by hand is how a review gets addressed in part while looking
complete, and the body attached to an approval is what goes missing. This returns all three from
one query. If `git-review-feedback` is not installed, report that
to the caller rather than rebuilding it out of raw `gh` calls, since that is the very thing that
drops a source.

1. Resolved threads are hidden and counted, so what comes back is already the set to act on.
   Address all of it by default. Pass `--all` when the caller asks for resolved threads too, and
   `--author <logins>` when they named specific reviewers ("just Dan's two").
2. Every point carries an id: `R1` for a review body, `T1` for a thread, `C1` for a conversation
   comment. Use those ids in your response so each reply is unambiguous about what it answers.
3. `APPROVED` on a review body does not mean there is nothing to do. An approval often carries a
   request, and it is triaged like any other point.
4. A review body takes no inline reply, which changes where the answer goes, never whether it
   gets one. What is real is fixed in code; what is not goes into your response.
5. `⚠ outdated` on a thread is GitHub's own verdict that the code moved since. `⚠ written before
   the current head` on a review body or comment is a hint rather than a verdict, since nothing
   computes that one. Either way, read the code as it stands before deciding: the point may
   already be moot.
6. Each thread arrives with the diff lines it is anchored to. That is where the comment points,
   not necessarily where the problem is, so read the file itself before concluding.
7. A `[bot]` tag is the author's GitHub account type, not a guess from the login. It only changes
   how a reply is phrased when the point turns out not to be a real issue.
8. If a point cannot be fetched because it lives somewhere `gh` does not reach, ask the caller to
   paste it, then treat it identically.

### Handed to you

When the caller gives you a review as text or as a file path, that review is the feedback set:
read it and do not run the command above. A review produced in a session is never posted, so the
PR holds nothing to fetch, and fetching anyway pulls in points from real reviewers that the
caller never asked you to act on.

1. Each numbered finding is a point, identified `L1`, `L2` and so on, anchored by the `File` and
   `Line` it names. Use those ids in your response, as with the ids above.
2. A finding states its case in `Reasoning` and its posted wording in `Comment`, so judge the
   reasoning. Its category, `BUG` or `MINOR` or another, weighs no more than a `[bot]` tag: it
   phrases a reply and it settles nothing. The triage below is still the judge, or a review
   written in a clean context buys nothing over doing whatever the reviewer typed.
3. The caller may also hand you points already settled in an earlier pass, each with the reply
   that settled it. Those replies are yours. If a point comes back, give the same answer unless
   the new wording carries an argument the old one did not answer; only then triage it afresh. A
   point you rejected and then quietly fix on a later pass changes code that was already right.

## For each point

1. Understand it fully. Read what it actually means. If it is unclear, disambiguate by reading the whole PR, the other comments and discussions, and above all the code. If you still cannot be certain you understand it, do not guess. Stop, and put the question in your response as a blocking question that names the point's id, saying nothing else about that point.
2. Decide whether it is a real issue that truly affects the code.
3. If it is not real, write a very succinct reply explaining why, and return it in your response without posting it. The caller uses it to reply on the PR so other developers understand why nothing changed. Write it to the [[plain-english]] standard loaded above, phrased for the audience: a peer reply for a human reviewer, or a rebuttal for a bot finding that explains why it is irrelevant, already handled, or wrong.
4. If it is real, fix it. Do not introduce new issues or undesired effects; beware race conditions and any change to the original logic or intent of the code. Load the [[comment-hygiene]] skill and apply it to comments in the code you touch: add none that merely restate the code, and drop existing ones that fail it.
5. Review the fix again in context. Confirm it fully addresses the issue, does not alter intended behavior, and causes no problems elsewhere. It is easy to lose the overall workflow while focused on one detail, so check that the fix broke nothing else.
6. Look for similar issues. If the same class of problem exists elsewhere, run this same procedure on each until everything is handled.

## Commit and hand back

1. Commit the changes you are sure about by following the [[commit]] skill; invoke it so its exact conventions load.
2. Every change you made is either committed or discarded, so that nothing of yours is left in the working tree. A change you are unsure about, or that is worth discussing before it lands, gets discarded rather than committed. Say in your response what you did, why you stopped, and what you discarded, in enough detail that the caller can ask for it deliberately.
3. Discard only what you wrote. Anything already in the tree when you started is not yours to commit or to revert, so leave it untouched and say it is there.
4. Push only if the caller asked for a push, and then push the branch alone, as the hard constraint at the top says.
5. Return every reply and discussion point in your response, for the caller to review before publishing.
