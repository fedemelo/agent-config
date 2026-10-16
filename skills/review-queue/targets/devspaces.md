# A review workspace per PR

For the `devspaces` environment. Reached from the [review-queue](../SKILL.md) skill, which decides that this is the right procedure. Everything that skill says still holds; this file only says what a space is here and how to open one.

Each PR gets its own devspaces workspace, and every one of them is filed in the same group as the workspace this session runs in. A workspace per PR keeps the checkouts from colliding. Workspaces are filed in groups, and the group keeps the reviews out of the groups you work in. You decide which group that is by where you start this skill, so starting it from a workspace in your review group is what sends the reviews there.

Take the commands from the pod's own `devspaces` CLI rather than from memory, since its flags are free to change: read its help, then use whatever it offers for telling which workspace this session runs in and which group holds it, listing the workspaces in a group, deleting a workspace, creating one, filing it in a group, and giving it a starting prompt. Seed each one with `/local-review <url>`, so the review is running when you arrive.

## Find the group

Ask the CLI which workspace this session runs in, then which group that workspace is filed in. That group is the one to use, whatever it is named.

Never create a group, and never look one up by name. Looking up by name is how a second group with the same name appeared, and the reviews filed in it were the ones nobody found. If this workspace is in no group, or the CLI cannot say which one, stop and report it.

## Clear out finished reviews

Do this before opening anything. List the workspaces in the group, and take those named `review-<n>`. That name is all you need: never open, attach to, or read a workspace to decide about it, since its review would land in this context.

Check every one of those PRs in a single command, one `gh pr view` per PR separated by `;`, with your login from `gh api user --template '{{.login}}'` written into each:

```sh
gh pr view <n> --json number,state,reviews --template '#{{.number}} {{.state}} {{$mine := "none"}}{{range .reviews}}{{if and (eq .author.login "<login>") (or (eq .state "APPROVED") (eq .state "CHANGES_REQUESTED"))}}{{$mine = .state}}{{end}}{{end}}mine={{$mine}}{{"\n"}}'
```

`mine` is your latest approval or change request, so an approval you later took back with a change request doesn't count. A comment carries no verdict and leaves it unchanged.

Delete the workspace when the state is `MERGED`, or when `mine` is `APPROVED`. Both mean the review is done. Leave every other workspace in place. If a PR you approved is in the list again because someone asked you for another review, it gets a new workspace below, and that review reads the current code.

If the CLI shows which repo a workspace belongs to and it's not this one, leave that workspace alone. Its number is a PR in some other repo.

## Open the rest

Every `review-<n>` workspace left in the group counts as already queued. A PR in the list that already has one keeps it: a second workspace would be a duplicate, and the one already there may hold a review you haven't read. Open a workspace for every other PR in the list, in that group.

If the CLI won't do one of these things, that is the end of this path. Stop and report it. No worktrees, no background sessions, no reviews here.

## Reading spaces back

The skip check and the cleanup step both read the workspaces in this session's group. A workspace named `review-<n>` is PR `<n>`'s space. The deletions above happen before either of them, so neither one sees a deleted workspace.

In the report, "how to reach it" is the workspace's name. Below the blocks, list the workspaces you deleted, one line each with the PR number and the reason (merged, or approved by you).
