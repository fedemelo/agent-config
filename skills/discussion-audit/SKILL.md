---
name: discussion-audit
description: Audits the discussion on a PR after the replies have been posted, checking every claim in them against the code and finding points that were raised but never answered. Flags what is wrong, partial, missed, imprecise, or left dangling, and changes nothing. Takes an optional PR number or URL, defaulting to the current branch's PR. Use when asked to verify, audit, or double-check the replies or the discussion on a PR.
disallowed-tools: Edit Write NotebookEdit
---

Audit a pull request's discussion once the replies are already posted. The question is whether everything said in that discussion is true of the code, and whether every point raised got an answer.

Hard constraint: flag only. Never modify code, never commit, never post a comment or reply, never react to one, never resolve or unresolve a thread, and never edit anything on the PR. Deliver the whole audit in this session. Everything below is achievable read-only.

Two things are out of scope, and both are easy to slip into:

1. The writing. Judge content only. Never remark on the tone, phrasing, formatting, grammar, or length of a comment or reply.
2. The rest of the PR. This is not a code review. A problem in the code is in scope only when a comment raised it or a reply made a claim about it. Never go hunting for unrelated bugs.

## Which PR to audit

Resolve it with [[pr-target]].

## Gather the whole discussion

Points hide in every corner of a PR, so read both sources before judging any of them.

1. Every point anybody made, from all three places they live:

```sh
git review-feedback <pr> --all
```

`--all` because a resolved thread has to be audited too: resolving proves only that someone
clicked resolve, never that the reply in it was right. The output covers inline threads, the body
of every submitted review, and conversation comments. A review body is the most commonly missed
of the three, since nothing about it looks like an open comment, and it is where a point with no
thread to answer it ends up. Each point carries an id (`R1`, `T1`, `C1`) to name in your findings,
and the header prints the PR number that the commands below need. If `git-review-feedback` is not
installed, report that rather than rebuilding it out of raw `gh`
calls, since that is how a source gets dropped.

2. The code as it stands now, which is the only thing that settles whether a reply is true. Fetch
   the head without checking out, and read the commits so a claimed fix can be traced to one:

```sh
gh pr diff <pr>
git fetch origin pull/<n>/head
git show FETCH_HEAD:<path>
git log --oneline -30 FETCH_HEAD
git show <sha>
```

## Inventory every point before judging any

List every distinct point raised across all four sources, one line each, before evaluating a single one. Build this list first and in full. Skipping it is how a point that was never answered stays invisible, since the eye follows the threads that have replies.

Split a comment that raises several things into one entry per thing. A single comment asking about naming, then about a null case, then suggesting a test, is three entries, and a reply covering only the naming leaves two unanswered.

Watch for the entries that hide:

1. A question buried in a comment that is otherwise approval.
2. A point raised again later in a thread, after the reply that closed the first round.
3. Pushback on a reply, where the reviewer came back and disagreed and nothing followed.
4. A point one reviewer raised that was only ever answered to a different reviewer.
5. Anything in a review summary body.
6. A bot finding nobody engaged with.

## Verify each answer against the code

For every entry in the inventory, find the answer it got and check it holds. Take nothing on trust, least of all the replies themselves.

1. Read the code before ruling on a claim. Never judge from the diff alone, from memory of the discussion, or from what a reply says another part of the code does. If a reply says a case is handled elsewhere, open that place and confirm it.
2. Check a claimed fix against the case that was actually raised, not against the general area. A fix that handles the common path while the comment described an edge case is not a fix.
3. Check that a rebuttal's reasoning is true. When a reply argues the concern cannot happen because of X, verify X.
4. Check that the answer addresses the question that was asked. An accurate statement that answers a nearby question still leaves the original one open.
5. When a claim cannot be verified, never assume it holds. Flag it, say plainly what could not be confirmed, and say what would settle it.

Findings go to the user, not onto the PR, so precision beats brevity. Name files, functions, and commits freely, cite what you read as `path:line`, and quote the words from the reply you are judging. A finding the user cannot check is worth nothing.

## Categories

1. WRONG: the reply says something that is not true of the code.
2. PARTIAL: the answer or the fix covers only part of what was raised.
3. MISSED: the point was raised and never answered at all.
4. IMPRECISE: technically true, but stated so loosely that a reader would take away the wrong thing.
5. DANGLING: the reply promises something later, and nothing on record makes it happen.

Two boundaries worth a test:

1. WRONG or IMPRECISE: would a reader who believes the reply act differently from what the code actually requires? If yes, WRONG.
2. PARTIAL or MISSED: was any part of the point answered? If none of it was, MISSED.

## Output

Number the findings sequentially, ordered by category as listed above, and write each as:

```
1.
Point: <the point raised, and who raised it>
Where: <file path and line, or the review or comment it came from>
Reply: <what the reply claimed, quoted or closely paraphrased>
Finding: <what is wrong with it, and the evidence from the code>
Category: WRONG / PARTIAL / MISSED / IMPRECISE / DANGLING
```

Open with one line stating how many distinct points the inventory holds and how many of them are flagged, so the coverage is visible without printing the whole inventory.

When everything holds up, say exactly that and flag nothing. Never invent a finding to justify the audit, and never re-raise a point that was answered correctly.
