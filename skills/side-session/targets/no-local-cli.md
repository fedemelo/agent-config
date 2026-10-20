# No space to open, so hand back the line to paste

For any environment that is not a devspaces pod and has no `claude` CLI on `PATH`: Codex, or a cloud session without it. Reached from the [side-session](../SKILL.md) skill, which decides that this is the right procedure.

`claude --bg` does not exist here, and there is no way to hand a cloud session a starting prompt. So open nothing. Hand back each starting prompt, as the caller wrote it, for the user to paste into a space of their own.

Say that is what happened and why. **Never do the space's task here instead.** Keeping that task out of this context is the reason the caller asked for a space, and doing it here fails quietly: the result looks the same while carrying everything this session already holds.

## List and delete

Nothing opens a space here, so there is nothing to list or delete. Tell the caller that any step built on listing does not apply, so it says so rather than leaving it unmentioned.

## Reaching one

There is no space to reach. The report carries the starting prompts to paste instead.
