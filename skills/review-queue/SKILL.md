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

One space each, and never a review in this one. What a space is depends on where you are running, and the mechanisms have nothing in common, so each one is a file of its own. Load the [[environment]] skill and work out the environment by its rule, take the first row that matches, and read only that file:

| Where you are | What to open | Procedure |
| --- | --- | --- |
| The `devspaces` environment | A devspaces workspace, in the group this session's workspace is in | `targets/devspaces.md` |
| Any other environment, with the `claude` CLI on `PATH` | A background session | `targets/local-cli.md` |
| Any other environment, without it, as in Codex or a cloud session | Nothing; print a line to paste | `targets/no-local-cli.md` |

The CLI is the second question, asked only once the first has settled that this is not a pod: `command -v claude`.

**There is no fallback.** The row follows from the environment, not from how well its mechanism cooperates. If the one you landed on does not work, stop, name what you ran and what it said, and report which PRs got a space and which did not. Never drop to the row below, and never review a PR here instead. A pod that opened background sessions because the workspaces were harder is a pod where the reviews are somewhere you will not think to look.

Nothing outside the chosen file applies. Read it in full before acting on any part of it.

Whichever row you land on, these hold:

- **Name it `review-<n>`**, for PR number `<n>`. Keep the shape exactly: it is what you see on the tab, and what the skip and cleanup steps below read back.
- **Skip any PR that already has a `review-<n>` space**, so running this again opens only what is new. A PR skipped this way still gets a line in the report.
- **The target is the PR's `url`, not its number**, since a pasted or attached space cannot be assumed to sit in this repo.
- **`/local-review` and nothing else.** Never `/review-loop`, which addresses and pushes; the review is yours to act on.
- **Never attach to a space you opened, read its output, or wait on it.** Switch to it yourself when you want the review.

### Reporting back

This is the report format wherever spaces were opened. The file that opens none keeps its own, and says so. No table: one block per PR, in the same newest-first order as the list, and nothing else surrounding it. For each PR:

```
#<n>: <title> (<created>)
    <how to reach it>
    <url>
```

The target file you read says what goes in "how to reach it". A PR skipped because a `review-<n>` space already existed still gets a line, pointing at that space.

## Spaces you are done with

A PR that is no longer in the list no longer wants your review: you reviewed it, it closed, or it went back to draft. Its space is now clutter.

Take every `review-<n>` space for an `<n>` absent from the list, enumerated the way the target file you read says, and hand them back for you to delete.

Name them; never delete one. A review you have not read yet is not yours to throw away. The one exception is a space the target file you read says to delete, because its PR shows the review is finished. That file says when, and it does that before anything is opened.

## What to report

Where you opened spaces, use the block format under "Reporting back" above, for the list and the spaces you opened, plus the spaces to delete from the section above. Where the target file keeps its own report, follow that file. Nothing about any PR's contents, either way: you have not read one.

If you cannot read files here (this skill was pasted as a prompt rather than loaded), say so and ask the user for the target file, naming the one you need. Do not reconstruct the procedure from memory.
