---
name: stage-review
description: Puts a local review's comments on a GitHub PR as a pending review, each on the line it is about, so you read, edit, delete and submit them in GitHub's own review screen. A pending review is visible only to you until you submit it. Ends with a short index of the comments in the order GitHub shows them, and explains and redrafts any one you reply with the number of. Takes the PR's URL or number, defaulting to the current branch's PR, and runs a local review first when this session holds none.
disable-model-invocation: true
audience: others
---

Stage a review: turn the findings of a local review into a pending review on the PR, one comment per finding, each on its line. The user then opens the PR's Files changed tab, deletes the comments they don't want, edits the rest in place, and submits the review with the verdict they pick.

Hard constraint: never submit the review. Create it without an `event`, so it stays pending and nobody but the user sees it. Choosing COMMENT, APPROVE or REQUEST_CHANGES is the user's decision, made in GitHub, after reading every comment. Never post a comment outside the pending review either, and never touch a review that already exists.

## The review to stage

Load the [[pr-target]] skill and resolve the PR by that rule.

The review is the most recent output of the [[local-review]] skill in this session whose closing `URL:` line is that PR. If there is none, load local-review and run it on that PR now, then stage what it returns. Never write or reword a finding here: each comment is posted exactly as local-review wrote it after `Comment:`, because the user reads it in GitHub as the review drafted it.

A review in this session written in an older format, with no `Line number:` field or no `Commit:` line, is staged all the same: work out what is missing as the steps below say, from the diff at the PR's current head.

## Before staging

Read the PR and your login, then any pending review you already have on the PR. GitHub returns a pending review only to its own author, so anything listed is yours.

```sh
gh pr view <pr> --json number,url,state,headRefOid
gh api repos/<owner>/<repo>/pulls/<n>/reviews --paginate --jq '.[] | select(.state == "PENDING") | .html_url'
```

1. The PR isn't `OPEN`: stop and say so.
2. A pending review exists: stop and give its URL. GitHub allows one per person per PR, and it may hold comments the user already wrote by hand. They submit or discard it, then run this again.

The commit is the review's `Commit:` line, since its line numbers describe that commit. If the PR's head has moved on since, say so in the report, because GitHub will mark comments on lines that changed since as outdated.

## Placing each comment

Read the diff at that commit:

```sh
gh api repos/<owner>/<repo>/compare/<base>...<commit> --jq '.files[] | {filename, patch}'
```

where `<base>` is the PR's `baseRefOid`. For each finding, place it from its `File`, `Line` and `Line number`:

1. The line given by `Line number` is in one of that file's hunks, and its text contains the `Line` snippet: use it. A line marked `(removed)` is a `-` line, numbered in the base, on side `LEFT`. Any other line is a `+` or context line, numbered at the head, on side `RIGHT`.
2. Otherwise, look for the snippet in that file's hunks. Exactly one line matches: use it, and say in the report that the number was wrong.
3. No line or several lines match: don't stage that finding. Report it with the reason, so the user posts it by hand.

GitHub only accepts a comment on a line inside a hunk, so a line outside every hunk falls under 3 even when the number is right.

## Staging

Write the request to a file outside the repo and send it. Leave out `event` and `body`:

```json
{
  "commit_id": "<commit>",
  "comments": [
    { "path": "<File>", "line": <line>, "side": "RIGHT", "body": "<Comment, verbatim>" }
  ]
}
```

```sh
gh api -X POST repos/<owner>/<repo>/pulls/<n>/reviews --input <file> --jq '{state, html_url}'
```

The state must come back `PENDING`. If anything else comes back, stop and report it, since the review is then visible to the PR's author.

## Report

Load the [[environment]] skill. On an `owned-machine`, open `<PR url>/files` in the browser with `open`. In `devspaces`, the user's browser is elsewhere, so the link in the index is how they get there.

The full review stays above, written out in local-review's format, even though the user doesn't read it. Writing the reasoning is what makes the findings and their categories hold up, and it is what you explain from later. Never shorten the review to save the user reading: the index below is what saves it.

End with the index and nothing after it:

```
Staged on #<n>, pending, only you see it:
<PR url>/files

1. MAJOR       <path>:<line>
2. MINOR       <path>:<line>

Verdict: <verdict>. <one sentence saying why>

Reply with a number to get it explained and redrafted here.
```

1. Number the comments in the order they appear on the Files changed tab: by file, in the order the diff lists them, then by line. That order is usually not local-review's, which goes by category. The user reads the comments in GitHub and not in the review, so the index numbers are the only ones they know. From here on, a number from the user means an index number.
2. Give each the category local-review gave it, and the full path and line, so the user can check that the comment they're looking at is the one the number names.
3. A finding left out of the pending review gets its index number after the staged ones, marked `not staged` with the reason, and its full comment text below the line, since it isn't on GitHub for the user to read.
4. If the head moved on since the reviewed commit, say so in one line above the verdict.

## When the user replies with a number

Explain that finding and redraft its comment, here in the session. Never edit, add or delete anything in the pending review: the user changes the comment on GitHub.

1. The explanation is for the user, not the author. Say what is wrong and why it matters, from the finding's reasoning, in plain words, and show the code it's about. If the reasoning doesn't hold up when you go back to the code, say so, and say what is true.
2. The redraft is a new version of the comment, written to [[plain-english]] and the comment rules in [[local-review]]. Make it easier to follow than the first one, since a comment the user didn't understand will lose the author too. If the explanation showed the finding is wrong, say the comment should be deleted and give no redraft.

Several numbers in one reply get one answer each, in the order given.
