---
name: respond-to-review
description: Addresses the review feedback on one of your own PRs from start to end. Fixes the real points and pushes, drafts a reply to each point that needs one, then posts all the replies at once and turns the PR into a draft seconds later, so you can revise every reply before anyone else reads it. Takes the PR's URL or number, defaulting to the current branch's PR.
disable-model-invocation: true
audience: others
---

Address the review feedback on the user's own PR, then put the replies on the PR in one go and turn the PR into a draft. The user reads and revises every reply on GitHub, and takes the PR out of draft themselves once the replies read as theirs. Until then, the draft is what keeps other people from reading a reply the user hasn't checked.

Hard constraints, held above every other line here:

1. Nothing reaches the PR one piece at a time. No reply goes up until every commit is pushed, and then all of them go up together through `git review-reply`, which turns the PR into a draft right after the last one. Never post a reply, a comment or a reaction any other way, and never rebuild `git review-reply` out of `gh` calls. If `git review-reply` isn't installed, stop and say so.
2. Never take the PR out of draft, request a review, re-request one, or resolve a thread. Those are the user's, once they have read the replies.
3. No reply names anyone with `@`, and no line of one starts with `/`. GitHub notifies whoever a reply mentions, and bots act on their tag or a slash command. `git review-reply` refuses both, so a reply that trips it gets rewritten, never posted another way.

This is often started by panopticon, sent as a message to the workspace that opened the PR, while the user is elsewhere. Nobody is there to answer a question during the run. Whatever needs the user goes in your final message, which panopticon shows them.

## Which PR

Load the [[pr-target]] skill and resolve it by that rule. Then check it is the user's own and still open:

```sh
gh pr view <pr> --json url,state,author,isDraft,headRefName
gh api user --jq .login
```

Stop and say why if the PR isn't open or its author isn't the user. Check out the head branch if the repo is on another one and the tree is clean, as review-rounds does with `gh pr checkout <pr>`. Stop if the tree isn't clean, since every reply has to describe code that is pushed.

## Addressing

Address the feedback by following the address-review skill. It is explicit-only, so you can't invoke it as a tool: read its file and follow it as written, with this skill as its caller. The user starting this skill is what authorizes that.

```sh
ls ~/.claude/skills/address-review/SKILL.md ~/.agents/skills/address-review/SKILL.md 2>/dev/null | head -1
```

If that finds nothing, try `find ~/.claude ~/.agents -path '*/address-review/SKILL.md' 2>/dev/null | head -1`, and stop if it still finds nothing.

Its feedback set is the PR's, fetched with `git review-feedback <pr>`. Follow it whole: it fixes the real points, commits, pushes, and hands back one reply per point that needs one, under the point's id and `url`, and says which points asked for nothing. Its rule never to post anything stays in force while you follow it: the replies come back to you, and you post them only as below. Write every reply to the [[plain-english]] standard, which address-review loads too.

Run `git review-feedback <pr> --json` as well, and keep its output: it holds each point's `url` and full text, which the replies file needs.

When address-review stops on a point with a blocking question, or discards a change it wasn't sure of, that point gets no reply now. It goes in your final message instead.

## Posting

Check first that everything is pushed: `git status --porcelain` is empty and `git rev-parse HEAD` matches the PR's `headRefOid`. A push that failed is reported, and nothing is posted.

Write the replies to a file outside the repo, from `mktemp`, in the order the points came in:

```json
{
  "pr": "<PR url>",
  "replies": [
    {"to": "<thread's first comment url>", "body": "<reply>"},
    {"to": "<review body or conversation comment url>", "quote": "<the words it answers>", "body": "<reply>"}
  ]
}
```

1. A thread point (`T`) is answered in its thread: `to` is the `url` of the thread's first comment, and there is no `quote`.
2. A review body (`R`) or a conversation comment (`C`) can't be replied to on GitHub, so it gets a quote reply: a new comment that quotes what it answers. `quote` is the sentence or two the reply is about, copied word for word, not the whole comment when the comment says more. Leave out any `@` mention in it, or put the login in backticks.
3. A point that asked for nothing, and a bot's point, gets no entry, as address-review decided.

Then post them all in one command:

```sh
git review-reply <file>
```

It checks every reply, posts them in order, and turns the PR into a draft straight after the last one, unless it is a draft already. With no replies it posts nothing and leaves the PR as it is.

- It refused the file: it posted nothing. Fix each problem it lists, usually a mention or a line starting with `/`, and run it again.
- A post failed midway: the PR is a draft already, and it names which replies went up. Run it again with a file holding only the ones that didn't.
- Turning the PR into a draft failed: say so first in your final message, since the replies are then visible on a PR that is ready for review.

## Final message

The user reads this through panopticon, so start with one line saying how it ended: "Replied to 4 points on #<n> and turned it into a draft", "Replied to 4 points on #<n>, already a draft", or "Nothing to reply to on #<n>". Then, each in a line or two:

- The commits pushed, by short hash and subject.
- Each blocking question, under the point it is about, with the point's link. It has no reply on the PR yet.
- Each change you discarded, and why.
- The points left without a reply because they asked for nothing, by id and author.
- Anything that went wrong in posting.

Don't repeat the replies here: the user reads them on the PR.
