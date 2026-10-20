# A devspaces workspace

For the `devspaces` environment. Reached from the [side-session](../SKILL.md) skill, which decides that this is the right procedure. Everything that skill says still holds; this file only says what a space is here and how to open, list and delete one.

A space is a devspaces workspace, filed in the same group as the workspace this session runs in. Workspaces are filed in groups, and the group keeps these spaces out of the groups you work in. You decide which group that is by where you start the calling skill.

Take the commands from the pod's own `devspaces` CLI rather than from memory, since its flags are free to change: read its help, then use whatever it offers for telling which workspace this session runs in and which group holds it, listing the workspaces in a group, deleting a workspace, creating one, filing it in a group, and giving it a starting prompt.

## Find the group

Ask the CLI which workspace this session runs in, then which group that workspace is filed in. That group is the one to use, whatever it is named.

Never create a group, and never look one up by name. Looking up by name is how a second group with the same name appeared, and the reviews filed in it were the ones nobody found. If this workspace is in no group, or the CLI cannot say which one, stop and report it.

## Open one

Create the workspace under the name the caller gave, file it in that group, and seed it with the caller's starting prompt.

If the CLI won't do one of these things, that is the end of this path. Stop and report it. No worktrees, no background sessions, and none of the space's work done here.

## List and delete

The spaces are the workspaces in this session's group, known by name. That name is all you need: never open, attach to, or read a workspace to decide about it, since what it holds would land in this context.

If the CLI shows which repo a workspace belongs to and it's not this one, leave that workspace alone. Its name means something in some other repo.

Delete a workspace with the CLI, and only when the calling skill says to.

## Reaching one

The workspace's name.
