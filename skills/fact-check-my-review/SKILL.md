---
name: fact-check-my-review
description: "Checks the comments in a review you posted on a PR: whether each claim is true of the code you reviewed, whether each suggested fix is right, and whether each point makes sense as written. Judges only what you said, never looks for what you missed, and changes nothing. Takes an optional PR number or URL, defaulting to the current branch's PR. Use when asked to verify, sanity check, or double-check your own review or your comments on a PR."
audience: user
disallowed-tools: Edit Write NotebookEdit
---

Check a review the user already posted. The question is whether each thing they said holds up against the code: the claim is true, the fix they suggest is the right one, and the point makes sense to the author reading it.

Hard constraint: flag only. Never modify code, never commit, never post, edit, or delete a comment, never react, never resolve a thread, and never change the review. Deliver the whole check in this session.

Two things are out of scope, and both are easy to slip into:

1. A new review. Never look for problems the user did not raise, never say what they missed, and never add a point of your own. Reading the code around a comment is how you judge that comment, not an invitation to judge the rest. A real problem you notice on the way stays out of the output.
2. The writing. Judge whether a comment is right, not how it is worded. Tone, grammar, and length are not findings. The one exception is a comment whose meaning the author cannot work out, which is UNCLEAR below.

## Which review

Load the [[pr-target]] skill and resolve the PR by that rule. Then take the user's login and their reviews on it:

```sh
gh api user --template '{{.login}}'
gh api repos/{owner}/{repo}/pulls/<n>/reviews --paginate \
  --jq '.[] | select(.user.login == "<login>") | {id, state, commit_id, submitted_at, body}'
```

Check the most recent one, unless the user named another review or asked for all of them. `commit_id` is the commit the review was written against, and it's the code each comment is judged on.

## Gather what was said

1. Every comment in that review, with the line and commit each was written against:

```sh
gh api repos/{owner}/{repo}/pulls/<n>/reviews/<review-id>/comments --paginate \
  --jq '.[] | {path, line: (.original_line // .line), original_commit_id, diff_hunk, body}'
```

The review's own `body` from the step above counts too. A summary body often holds a point with no line attached, and it's the one most easily skipped.

2. What happened to each comment since, so a reply that changes its meaning is read:

```sh
git review-feedback <pr> --all --json
```

`--all` because a thread the author resolved still holds the comment being checked. Read the user's comments together with any reply in the same thread, since a reply can add a fact the comment didn't have. Judge the comment, not the reply. If `git-review-feedback` is not installed, report that rather than rebuilding it out of raw `gh` calls.

3. The code at the reviewed commit and at the current head. Fetch the head last, so `FETCH_HEAD` names it:

```sh
git fetch origin <commit_id>
git fetch origin pull/<n>/head
git show <commit_id>:<path>
git show FETCH_HEAD:<path>
git log --oneline <commit_id>..FETCH_HEAD
```

## List every point before judging any

List each distinct point the user made, one line each, before evaluating a single one. Split a comment that says several things into one entry per thing: a comment pointing at a null case and suggesting a test is two entries, and each is judged on its own.

A question counts as a point. "Why not reuse the existing parser?" claims that a parser exists and fits here, and that claim gets checked like any other.

## Judge each point against the code

1. Read the code at the reviewed commit before ruling. Never judge from the diff hunk alone, or from what the comment says another part of the code does. If the comment says a case is unhandled, look for where it would be handled. If it says a helper already does this, open the helper.
2. Check a suggested fix against the problem the comment names. Would the change fix that case? Would it break a caller, a test, or another path through the same code? A fix that compiles but moves the bug is a BAD FIX.
3. Check the severity. A comment that calls something a bug claims it happens. Find the path that gets there, or show that none does.
4. Check the comment means one thing. Would the author know what is being claimed and what they're asked to do?
5. When a claim cannot be verified from the code, never assume it holds or fails. Say plainly what could not be confirmed and what would settle it.

A later commit that changes the code doesn't make a comment wrong. When the author already fixed what a comment raised, say so in one line under that point, and judge the comment on the code it was written against.

Findings go to the user, not onto the PR, so precision beats brevity. Name files, functions, and commits freely, cite what you read as `path:line`, and quote the words of the comment you are judging. A finding the user cannot check is worth nothing.

## Categories

1. WRONG: the claim isn't true of the code. The problem can't happen, is already handled, or the code doesn't do what the comment says it does.
2. BAD FIX: the problem is real, but the suggested change wouldn't fix it, or would break something else.
3. OVERSTATED: the problem is real, but smaller than the comment says. A bug that needs an input no caller can send, or a "this breaks" that only slows something down.
4. UNDERSTATED: the problem is real and worse than the comment says. A nit that's in fact a bug.
5. UNCLEAR: the author can't tell what's being claimed or what to do about it, so the comment can be answered wrongly while the author believes they addressed it.

Two boundaries worth a test:

1. WRONG or OVERSTATED: is there any path, through any caller, where the problem occurs? If none, WRONG.
2. WRONG or BAD FIX: is the problem itself real? If not, WRONG, whatever the fix looks like.

## Output

Open with one line saying how many distinct points the review holds and how many are flagged.

Number the findings sequentially, ordered by category as listed above, and write each as:

```
1.
Comment: <the user's words, quoted or closely paraphrased>
Where: <file path and line, or the review body>
Finding: <what doesn't hold, and the evidence from the code>
Instead: <what's actually true, or the fix that would work>
Category: WRONG / BAD FIX / OVERSTATED / UNDERSTATED / UNCLEAR
```

Then, if any, one line per point the author already fixed since the review, with the commit that did it.

When every point holds up, say exactly that and flag nothing. Never invent a finding to justify the check, and never soften a correct comment into a finding.
