---
name: side-session
description: "The procedure for opening a separate space seeded with a starting prompt, so a task runs in its own checkout and its own context rather than in this session: a devspaces workspace in this session's group in a pod, a background session in its own worktree elsewhere, or a line to paste where neither exists. Other skills reference it so they all open spaces the same way. Use when a task has to run in a space of its own."
---

Open a separate space, give it a name and a starting prompt, and leave it running. The skill that sent you here supplies both and decides what the space is for. This one only says what a space is where you are running, and how to open, list and delete one.

A space has its own checkout and its own context. Its own checkout, so that nothing it does to files or branches touches the tree this session works in. Its own context, so that nothing it reads or writes lands here.

## Which kind

The mechanisms have nothing in common, so each one is a file of its own. Load the [[environment]] skill and work out the environment by its rule, take the first row that matches, and read only that file:

| Where you are | What to open | Procedure |
| --- | --- | --- |
| The `devspaces` environment | A devspaces workspace, in the group this session's workspace is in | `targets/devspaces.md` |
| Any other environment, with the `claude` CLI on `PATH` | A background session in its own worktree | `targets/local-cli.md` |
| Any other environment, without it, as in Codex or a cloud session | Nothing; hand back a line to paste | `targets/no-local-cli.md` |

The CLI is the second question, asked only once the first has settled that this is not a pod: `command -v claude`.

**There is no fallback.** The row follows from the environment, not from how well its mechanism cooperates. If the one you landed on does not work, stop, name what you ran and what it said, and report which spaces were opened and which were not. Never drop to the row below, and never do a space's task in this session instead. A pod that opened background sessions because the workspaces were harder is a pod where the work is somewhere you will not think to look.

Nothing outside the chosen file applies. Read it in full before acting on any part of it.

## Whichever kind

- **The starting prompt goes in exactly as the caller wrote it.** It is how the space learns its task, and nothing else reaches it.
- **Never attach to a space you opened, read its output, or wait on it.** The user switches to it when they want what it did.
- **The target file says how to reach a space**, which goes in the caller's report, **and how to list and delete spaces.** When to delete one is the caller's decision, never this skill's.

If you cannot read files here (this skill was pasted as a prompt rather than loaded), say so and ask the user for the target file, naming the one you need. Do not reconstruct the procedure from memory.
