# Triage

| Command | What it does |
| --- | --- |
| `panopticon triage [--json]` | A briefing per workspace waiting on an answer: its item, title and prompt, status, PRs read from GitHub, last words, and what triage found |
| `panopticon continue <ws>`, `keep <ws>` | Answers a finding: the work goes on, or leave the workspace alone for good |

Every 15 minutes, a tick checks each workspace and records at most one finding for it. A finding is one of three kinds:
- **Rested**: idle or stopped for an hour with nothing queued.
- **Stale**: no activity for 14 days, but it still has an open PR.
- **Proposed for deletion**: its item is done, its linked PRs are merged or closed, you approved the review, a newer review replaced it, or it has had no activity for 14 days and has no open PR.

Each finding arrives once in the inbox. A tick never acts on one.

When the user asks what needs them, run `panopticon triage --json` for the list, and the inbox for what's new.

## Briefing

`triage --json` has most of what a briefing needs, so brief from that rather than reading each workspace. Name workspaces and PRs as under "Naming things" in the skill.

- Group the workspaces by work item, and name the item.
- Say where the agent left off, in a line, from its last words. Use `panopticon read` only when they are missing or don't settle it, and only on a running workspace. A stopped one would have to be woken to read it, so wake it only when the user agreed to that.
- Say why triage flagged it, and what you'd do.

Triage can be wrong. When the briefing doesn't fit the finding, check it, and say so when a finding is wrong.

panopticon opens a decision for each finding itself: `archive` for a rested or stale workspace, and `delete` for one proposed for deletion. Brief each under the number `decisions --json` gives it, as under "Decisions" in the skill, and never open another for the same finding. Any other choice about a workspace, such as deferring its item, is one you open with `panopticon ask --about <ws>`.

## Actions

Each answer runs as one of these:

- `panopticon continue <ws>`: the work goes on. Pair it with a `send` if the user wants the agent to do something next.
- `panopticon keep <ws>`: leave it as it is. Triage won't propose anything for it again.
- Defer its item, as `workflows/work-items.md` describes, when the work is set aside but must not be lost.
- Archive or delete it, as `workflows/delete.md` describes.
