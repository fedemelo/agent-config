---
name: review-queue
description: Lists the open PRs on this repo that are waiting on your review, newest first, and opens one space per PR to review it — a devspaces workspace in the same group as the one it runs from in a pod, a background session elsewhere — so the reviews arrive as separate spaces you switch between rather than in this one. In a pod it first deletes the review workspaces whose PR you approved or that merged; elsewhere it names the review spaces whose PR no longer needs you, for you to delete.
disable-model-invocation: true
---

Two jobs, in order: find the PRs waiting on your review, then open one space per PR to review it.

You never review a PR here. This session ends holding nothing but the roster of what it opened, because the reviews are read one at a time in their own spaces, and a session that also holds five reviews is the clutter this skill exists to avoid.

## The list

Run this as it stands:

```sh
gh pr list --search "is:open draft:false review-requested:@me sort:created-desc" --limit 20 \
  --json number,url,createdAt,title \
  --template '{{printf "%-8s %-45s %-14s %s\n" "PR" "LINK" "CREATED" "TITLE"}}{{range .}}{{printf "%-8v %-45s %-14s %s\n" .number .url (.createdAt | timeago) .title}}{{end}}'
```

`--search` goes through the search API, which orders by best match unless told otherwise, so `sort:created-desc` is what makes "the 20 most recent" true rather than an arbitrary 20 of them. `draft:false` leaves out drafts, which are not ready for review even when someone is already requested on them. The command is scoped to the current repo by `gh pr list` itself.

Nothing in the list means nothing is waiting on you. Say so and stop; do not open a space to confirm it.

## A space per PR

One space each, and never a review in this one. Load the [[side-session]] skill and open, list and delete spaces by it. Before opening anything, clear out finished reviews as the next section says, so the skip check below never sees a space that is about to go.

- **Name it `review-<n>`**, for PR number `<n>`. Keep the shape exactly: it is what you see on the tab, and what the skip and cleanup steps read back.
- **Seed it with `/local-review <url>`** and nothing else, so the review is running when you arrive. Never `/review-loop`, which addresses and pushes; the review is yours to act on.
- **The target is the PR's `url`, not its number**, since a pasted or attached space cannot be assumed to sit in this repo.
- **Skip any PR that already has a `review-<n>` space**, so running this again opens only what is new. A second space would be a duplicate, and the one already there may hold a review you haven't read. A PR skipped this way still gets a line in the report.

## Spaces you are done with

A PR that is no longer in the list no longer wants your review: you reviewed it, it closed, or it went back to draft. Its space is now clutter. Take every `review-<n>` space for an `<n>` absent from the list.

Where side-session landed on devspaces workspaces, the PR itself shows whether the review is finished, so delete those whose review is. Check every one of those PRs in a single command, one `gh pr view` per PR separated by `;`, with your login from `gh api user --template '{{.login}}'` written into each:

```sh
gh pr view <n> --json number,state,reviews --template '#{{.number}} {{.state}} {{$mine := "none"}}{{range .reviews}}{{if and (eq .author.login "<login>") (or (eq .state "APPROVED") (eq .state "CHANGES_REQUESTED"))}}{{$mine = .state}}{{end}}{{end}}mine={{$mine}}{{"\n"}}'
```

`mine` is your latest approval or change request, so an approval you later took back with a change request doesn't count. A comment carries no verdict and leaves it unchanged.

Delete the workspace when the state is `MERGED`, or when `mine` is `APPROVED`. Both mean the review is done. If a PR you approved is in the list again because someone asked you for another review, it gets a new workspace, and that review reads the current code.

Every other space, and every space wherever side-session landed on anything else, you name and never delete. A review you have not read yet is not yours to throw away.

## What to report

No table: one block per PR, in the same newest-first order as the list, and nothing else surrounding it. For each PR:

```
#<n>: <title> (<created>)
    <how to reach it>
    <url>
```

"How to reach it" is what side-session's target file says. A PR skipped because a `review-<n>` space already existed still gets a block, pointing at that space.

Below the blocks, list the workspaces you deleted, one line each with the PR number and the reason (merged, or approved by you), and then the spaces you named for the user to delete.

Where side-session opened nothing, report the list as the command printed it, then the `/local-review` lines to paste, and say that the cleanup does not apply.

Nothing about any PR's contents, either way: you have not read one.
