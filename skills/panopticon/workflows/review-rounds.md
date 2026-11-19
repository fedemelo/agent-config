# Review rounds

| Command | What it does |
| --- | --- |
| `panopticon review-rounds <pr> [--again]` | Starts review rounds on a PR, as its URL or `owner/name#number`, in a new workspace: fresh agents review and address it until a review approves it or three rounds are spent. Nothing is posted to the PR. `--again` starts another run though the last one ended without an approval |

When the user says a PR of theirs is finished, or asks for review rounds on it, run `panopticon review-rounds <pr>`. Never pass `--again` on your own judgment. Pass it only on the user's yes, after a run that ended without an approval.

The run works in a `rounds-<n>` workspace in the `<repo> Review Rounds` group. Both are panopticon's, and a bootstrap never wakes them.

A `rounds-ended` event says how the run ended:

- Approved: tell the user. Triage will propose deleting the workspace.
- Not approved, stopped early without an approval, or an outcome that couldn't be read: it's the user's call. panopticon opens a `rounds-again` decision about the PR: ask it under its number from `decisions --json`. A yes runs `review-rounds <pr> --again`, and a no runs `panopticon continue <ws>`. Offer to read the report with `panopticon read`. Keeping, archiving or deleting the workspace instead are choices you open with `panopticon ask --about <ws>` (`workflows/triage.md`, `workflows/delete.md`). Until the user answers, triage proposes nothing for it.
- Stopped with a question: panopticon opens a `rounds-question` decision about the PR. Put the question to the user under its number, and forward their answer in their own words with `panopticon send --quote`, as under "Sending" in `SKILL.md`.
- The outcome couldn't be read: read the transcript, and tell the user how the run ended, under its `rounds-again` decision.
