# Review rounds

| Command | What it does |
| --- | --- |
| `panopticon review-rounds <pr> [--again]` | Starts review rounds on a PR, as its URL or `owner/name#number`, in a new workspace: fresh agents review and address it until a review approves it or three rounds are spent. Nothing is posted to the PR. `--again` starts another run though the last one ended without an approval |

When the user says a PR of theirs is finished, or asks for review rounds on it, run `panopticon review-rounds <pr>`. Never pass `--again` on your own judgment. Pass it only on the user's yes, after a run that ended without an approval.

The run works in a `rounds-<n>` workspace in the `<repo> Review Rounds` group. Both are panopticon's, and a bootstrap never wakes them.

A `rounds-ended` event says how the run ended:

- Approved: tell the user. Triage will propose deleting the workspace.
- Not approved, or stopped early without an approval: it's the user's call. Offer to read the report with `panopticon read`. Then ask whether to continue or keep the workspace (`workflows/triage.md`), archive or delete it (`workflows/delete.md`), or start another run with `--again`. Until the user answers, triage proposes nothing for it.
- Stopped with a question: put the question to the user, and forward their answer with `panopticon send`.
- The outcome couldn't be read: read the transcript, and tell the user how the run ended.
