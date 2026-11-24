# Learning from the user's edits

| Command | What it does |
| --- | --- |
| `panopticon review-edits [learned <review>...]` | The staged reviews the user submitted or discarded, each comment as drafted and as the user left it: kept, edited, deleted or added |
| `panopticon reply-edits [learned <id>...]` | The replies to reviews on the user's PRs that the user is done with, each as drafted and as the user left it: kept, edited or deleted |

These two say how the user rewrites what Claude drafts for other people. The `learn-from-edits` skill reads them, changes the skills that drafted them, lands those changes, and marks learned only the edits behind a change. You never run it here, and you never mark anything learned yourself: working out what the drafts should learn takes a whole context, and this session's is for watching.

- `edits-to-learn`: enough reviews and replies the user changed came since they were last told, or the oldest of them has waited a week. Load the [[side-session]] skill and open a space named `learn-from-edits-<yyyy-mm-dd>`, seeded with `/learn-from-edits`. Tell the user in one line that it started and how to reach it. Send no notification: the skill sends one when it changes something.
- The user asks to learn from their edits: open the same space. The user asks what waits to be learned from: count what each command lists and say it in a line.
- A decision the skill opened comes up like any other (see "Decisions" in `SKILL.md`).
