---
name: stage-review
description: Puts a local review's comments on a GitHub PR as a pending review, each on the line it is about, and its replies in the threads they answer, so you read, edit, delete and submit them in GitHub's own review screen. A pending review is visible only to you until you submit it. Ends with a short index of the comments in the order GitHub shows them, and explains and redrafts any one you reply with the number of. `rewrite`, with or without numbers, rewrites the staged comments in plainer words on GitHub itself. `update` brings the pending review in line with the PR's new commits and anyone else's comments since it was staged, in place. Takes the PR's URL or number, defaulting to the current branch's PR, and runs a local review first when this session holds none.
disable-model-invocation: true
audience: others
---

Stage a review: turn the findings of a local review into a pending review on the PR, one comment per finding, each on its line, and one reply per answer, in its thread. The user then opens the PR's Files changed tab, deletes the comments they don't want, edits the rest in place, and submits the review with the verdict they pick.

Hard constraint: never submit the review. Create it without an `event`, so it stays pending and nobody but the user sees it. Choosing COMMENT, APPROVE or REQUEST_CHANGES is the user's decision, made in GitHub, after reading every comment. Never post a comment outside the pending review either, and never touch a review that already exists, except in `rewrite`, and then only the comments you staged that the user didn't change, and in `update`. Never react to a comment or resolve a thread: both are public at once.

## Before reviewing

Load the [[pr-target]] skill and resolve the PR by that rule. Then read the PR and any pending review you already have on it, before any review is run, since a review that can't be staged is wasted. GitHub returns a pending review only to its own author, so anything listed is yours.

```sh
gh pr view <pr> --json number,url,state,headRefOid
gh api repos/<owner>/<repo>/pulls/<n>/reviews --paginate --jq '.[] | select(.state == "PENDING") | .html_url'
```

1. The PR isn't `OPEN`: stop and say so.
2. A pending review exists: stop and give its URL. GitHub allows one per person per PR, and it may hold comments the user already wrote by hand. They submit or discard it, then run this again. `rewrite` and `update` work on that review instead, and skip everything up to their own sections.

## The review to stage

The review is the most recent output of the [[local-review]] skill in this session whose closing `URL:` line is that PR. If there is none, load local-review and run it on that PR now, then stage what it returns. Never write or reword a finding or a reply here: each is posted exactly as local-review wrote it after `Comment:` or `Reply:`, because the user reads it in GitHub as the review drafted it.

A review in this session written in an older format, with no `Line number:` field or no `Commit:` line, is staged all the same: work out what is missing as the steps below say, from the diff at the PR's current head.

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
gh api -X POST repos/<owner>/<repo>/pulls/<n>/reviews --input <file> --jq '{state, html_url, node_id}'
```

The state must come back `PENDING`. If anything else comes back, stop and report it, since the review is then visible to the PR's author. Send `"comments": []` when the review has only replies.

Then add each reply to the thread holding the comment its `Reply to:` names. Find the thread's id:

```sh
gh api graphql -F owner=<owner> -F name=<repo> -F n=<n> -f query='query($owner:String!,$name:String!,$n:Int!){
  repository(owner:$owner,name:$name){ pullRequest(number:$n){ reviewThreads(first:100){ nodes{ id path line comments(first:100){ nodes{ url }}}}}}}'
```

and send the reply into the pending review by its `node_id`:

```sh
gh api graphql -f review=<node_id> -f thread=<thread id> -f body=<Reply, verbatim> -f query='mutation($review:ID!,$thread:ID!,$body:String!){
  addPullRequestReviewThreadReply(input:{pullRequestReviewId:$review,pullRequestReviewThreadId:$thread,body:$body}){ comment{ state }}}'
```

Never leave out `pullRequestReviewId`, which is what keeps the reply pending, and never use REST's replies endpoint, which posts at once. Each must come back `PENDING`, or stop and report it as above. A reply whose comment is in no thread, such as a review body or a conversation comment, can't be staged, since GitHub has no pending reply to those.

## Report

Load the [[environment]] skill. On an `owned-machine`, open `<PR url>/files` in the browser with `open`. In `devspaces`, the user's browser is elsewhere, so the link in the index is how they get there.

The full review stays above, written out in local-review's format, even though the user doesn't read it. Writing the reasoning is what makes the findings and their categories hold up, and it is what you explain from later. Never shorten the review to save the user reading: the index below is what saves it.

End with the index and nothing after it:

```
Staged on #<n>, pending, only you see it:
<PR url>/files

1. MAJOR       <path>:<line>
2. MINOR       <path>:<line>

Replies:
3. agreed      <path>:<line>
4. MAJOR       <path>:<line>

Verdict: <verdict>. <one sentence saying why>

Reply with a number to get it explained and redrafted here.
```

1. Number the comments in the order they appear on the Files changed tab: by file, in the order the diff lists them, then by line. That order is usually not local-review's, which goes by category. The user reads the comments in GitHub and not in the review, so the index numbers are the only ones they know. From here on, a number from the user means an index number.
2. Give each the category local-review gave it, and the full path and line, so the user can check that the comment they're looking at is the one the number names.
3. Replies come after the comments, numbered on from them in the same order, with their thread's path and line, and `agreed` for one with no category.
4. A finding or reply left out of the pending review gets its index number after the staged ones, marked `not staged` with the reason, and its full comment text below the line, since it isn't on GitHub for the user to read.
5. If the head moved on since the reviewed commit, say so in one line above the verdict.

## When the user replies with a number

Explain that finding or reply and redraft it, here in the session. Never edit, add or delete anything in the pending review: the user changes the comment on GitHub.

1. The explanation is for the user, not the author. Say what is wrong and why it matters, from the finding's reasoning, in plain words, and show the code it's about. If the reasoning doesn't hold up when you go back to the code, say so, and say what is true.
2. The redraft is a new version of the comment, written to [[plain-english]] and the comment rules in [[local-review]]. Make it easier to follow than the first one, since a comment the user didn't understand will lose the author too. If the explanation showed the finding is wrong, say the comment should be deleted and give no redraft.

Several numbers in one reply get one answer each, in the order given.

## Rewriting the staged review

`/stage-review rewrite` means the user found the staged comments hard to read. Rewrite them in plainer words and change them on GitHub, in the pending review. `rewrite` followed by numbers does the same for those index numbers only. This is the one time you change the pending review after staging it, and it skips everything above: it never runs a review or stages one.

panopticon may start a fresh session on `rewrite <PR url> <comment ids>` when the session that staged the review is gone. That session has no index and staged nothing, so the ids it was given stand in for both: they are the comments still as staged, and the only ones to rewrite. It has none of the review's reasoning either, so it reads the diff at the review's commit before judging a finding.

1. Load the [[plain-english]] skill and the comment rules in [[local-review]] before writing anything.
2. Read the pending review as it is now:

   ```sh
   gh api graphql -F owner=<owner> -F name=<repo> -F n=<n> -f query='query($owner:String!,$name:String!,$n:Int!){
     repository(owner:$owner,name:$name){ pullRequest(number:$n){ reviews(states:PENDING,first:1){ nodes{ id url comments(first:100){ nodes{ id path line body }}}}}}}'
   ```

   If there is no pending review, stop and say so: the user submitted or discarded it. In the session that staged it, it must be the review you staged. In a fresh session given comment ids, every id must be among its comments. Otherwise stop and say so, since it isn't the review panopticon meant.
3. In the session that staged it, rewrite only the comments and replies whose text is still what you staged. One the user changed is theirs: leave it and list its number in the report. In a fresh session, rewrite exactly the comments whose ids you were given, and leave every other one alone.
4. A rewrite says the same thing as the comment it replaces, about the same line. It adds no new point and drops none. It reads easier than the first version, since a comment the user didn't understand will lose the author too. If you go back to the code and the finding doesn't hold, don't rewrite it. Say in the report that it should be deleted and why.
5. Change each one in place:

   ```sh
   gh api graphql -f id=<comment id> -f body=<rewrite> -f query='mutation($id:ID!,$body:String!){
     updatePullRequestReviewComment(input:{pullRequestReviewCommentId:$id,body:$body}){ pullRequestReviewComment{ state }}}'
   ```

   Each must come back `PENDING`, or stop and report it, as when staging.
6. panopticon keeps a copy of each comment as staged, and counts any change to one as the user's own edit. Load the [[environment]] skill. On an `owned-machine` with `panopticon` on the `PATH`, run `panopticon review-redrafted <owner>/<repo>#<n>`, so it takes the new wording as the draft. In `devspaces`, it can't be run here, so put that command in the report for whoever drives this session to run on the user's machine.

Report in this shape, and nothing after it:

```
Rewrote <k> comments on #<n>, still pending:
<PR url>/files

Left alone, since you changed them: <numbers>
Should be deleted: <number>, <one sentence saying why>

panopticon review-redrafted <owner>/<repo>#<n>
```

Leave out each line that has nothing to say. Drop the command line once you ran it, and say instead that panopticon took the new wording. The index numbers stay the same, since nothing moved. A fresh session has no index, so it names each comment by its path and line instead of a number, and leaves out the "Left alone" line, since panopticon already left those out.

## Updating the staged review

`/stage-review update <PR url> <comment ids>` comes from panopticon after something happened on the PR under a pending review: new commits, or a comment, review or reply by someone else, a bot or a backtest included. The review was written against older code and an older discussion, so some comments may now point at code that changed or a bug that was fixed, and some may repeat what someone else has said since. Bring the review in line with the PR as it is now, in the pending review itself. It usually comes to the session that staged the review, which holds its reasoning, and comes to a fresh session only when that one is gone.

The ids are the comments still exactly as drafted. Every other comment and reply in the review is the user's: one they edited or added. Being current matters more than keeping the user's wording, so judge their comments by the same rules as yours. Keep their wording when the comment still holds and nobody else has made its point. Change or delete it only when it doesn't, and give its full text in the report, so they can put it back.

1. Load the [[plain-english]] skill and the comment rules in [[local-review]] before writing anything.
2. Read the PR's head and the pending review:

   ```sh
   gh api graphql -F owner=<owner> -F name=<repo> -F n=<n> -f query='query($owner:String!,$name:String!,$n:Int!){
     repository(owner:$owner,name:$name){ pullRequest(number:$n){ url headRefOid reviews(states:PENDING,first:1){ nodes{ id url commit{ oid } comments(first:100){ nodes{ id path line outdated body }}}}}}}'
   ```

   If there is no pending review, stop and say so: the user submitted or discarded it. If any id you were given isn't among its comments, stop and say so, since it isn't the review panopticon meant. Keep each comment's body as read now.
3. Read the PR's whole history as [[local-review]] does: every point anyone made, human or bot, with the answers to each. What came since the review was staged is what most likely changes it.
4. Work out what changed in the code. When the head is still the review's commit, only the discussion changed: skip to 5 and don't review the code again. Otherwise read the diff from the review's commit to the head, then run [[local-review]] on the PR at its current head, and write it out in full above, as when staging. In the session that staged the review, check each finding against the code at the head, not against what you concluded before: the point of the update is that the code moved. In a fresh session you have no earlier reasoning, so review the code without leaning on the comments already there.
5. Go through every comment in the review, yours and the user's, against the code at the head and the discussion now:
   1. The code at the head fixed what it points out, or it no longer holds: delete it.
   2. Someone else already made its point, since it was staged or before: delete it.
   3. Someone else made part of its point: rewrite it to open with "I agree with <name>" and say only what it adds, following the comment rules.
   4. It still holds and adds something, but GitHub marks it `outdated`: delete it and add the same text again on its line at the head, as in 6. One that can't be placed there stays where it is, and the report says so.
   5. Otherwise leave it as it is.

   Delete with:

   ```sh
   gh api graphql -f id=<comment id> -f query='mutation($id:ID!){
     deletePullRequestReviewComment(input:{id:$id}){ pullRequestReview{ state }}}'
   ```

   and rewrite in place with:

   ```sh
   gh api graphql -f id=<comment id> -f body=<rewrite> -f query='mutation($id:ID!,$body:String!){
     updatePullRequestReviewComment(input:{pullRequestReviewCommentId:$id,body:$body}){ pullRequestReviewComment{ state }}}'
   ```

   Before each delete, move or rewrite, read that comment again, and go ahead only if its body is still what step 2 read. The user may be editing it while you work. One that changed is left alone and listed in the report.
6. Add each new finding that no comment in the review and no one else already makes. A finding that adds to someone else's point opens with "I agree with <name>". Place it on its line at the head by the rules in "Placing each comment", against the diff at `headRefOid`, and send it into the pending review by its id, never through REST and never through anything that posts:

   ```sh
   gh api graphql -f review=<review id> -f path=<File> -F line=<line> -f side=RIGHT -f body=<Comment, verbatim> -f query='mutation($review:ID!,$path:String!,$line:Int!,$side:DiffSide!,$body:String!){
     addPullRequestReviewThread(input:{pullRequestReviewId:$review,path:$path,line:$line,side:$side,body:$body}){ thread{ comments(first:1){ nodes{ id state outdated commit{ oid }}}}}}'
   ```

   It must come back `PENDING`, or stop and report it, as when staging. A pending review keeps the commit it was created on, and GitHub's docs don't say that a thread added to it later lands on the current head. So check the first one you add or move: its `commit` must be `headRefOid` and it must not be `outdated`. If it isn't, delete it again, add or move nothing more, and give every remaining finding as not staged, saying that GitHub put new comments on the review's old commit.
7. Never submit the review, never post outside it, and never react to a comment or resolve a thread.
8. panopticon notices the update and takes the new wording as drafted on its own, so unlike `rewrite` there is no `review-redrafted` command to run.

Report in this shape, and nothing after it:

```
Updated the review of #<n> for <short head sha>, still pending:
<PR url>/files

Added:
1. MAJOR       <path>:<line>
Removed:
2. <path>:<line>  <one sentence saying why: fixed, no longer holds, or who already said it>
Rewritten:
3. MINOR       <path>:<line>  now agrees with <name>
Moved:
4. MINOR       <path>:<old line> -> <new line>
Left alone, since you were editing it:
5. <path>:<line>
Not staged:
6. MINOR       <path>:<line>  <reason>

Verdict: <verdict>. <one sentence saying why>

Reply with a number to get it explained and redrafted here.
```

Leave out each heading with nothing under it. Number the entries on from one through every heading, each heading's entries in the order the Files changed tab shows them, so a number from the user names one entry, as in the staging index. Mark each removed or rewritten comment that was the user's with `(yours)` and give its full text as it was below the line, so they can put it back. Give each not-staged finding's full comment text below the line too, since it isn't on GitHub. A reply with a number gets an explanation and a redraft as in "When the user replies with a number", and a removed comment gets the reason it went.
