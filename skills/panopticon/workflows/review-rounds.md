# Review rounds

| Command | What it does |
| --- | --- |
| `panopticon review-rounds <pr> [--again]` | Starts review rounds on a PR, as its URL or `owner/name#number`, in the workspace that opened it, or in a new workspace when none of the user's did: fresh agents review and address it until a review approves it or five rounds are spent. Nothing is posted to the PR. `--again` starts another run though the last one ended without an approval |

Every PR a worker opens goes through review rounds before the user hears of the work, and the user never asks for it. A tick starts them on its own: once the turn that opened a PR is over, it sends `/review-rounds <url>` to the workspace that opened it, which already holds the branch, and silences that turn's `finished` event. The turn that reports the outcome is silenced too, so the `rounds-ended` event is the user's first and only word of the finished job.

So never ask the user whether to run review rounds, and never run `review-rounds` for a PR a worker just opened: the tick does. When a `finished` event does reach you from a turn that says it opened a PR, say nothing about it. Dev Spaces can list the PR a minute after the turn ends, and the tick starts the rounds then.

Run `panopticon review-rounds <pr>` yourself only when the user asks for rounds on a PR, such as one they opened by hand. Never pass `--again` on your own judgment. Pass it only on the user's yes, after a run that ended without an approval.

A run on a PR no workspace of the user's opened works in a `rounds-<n>` workspace in the `<repo> Review Rounds` group. Both are panopticon's, and a bootstrap never wakes them.

## When the rounds end

A `rounds-ended` event says how the run ended. Notify it however it ended, with `--open <link>`: it is when the work reaches the user.

When the run worked in the workspace that opened the PR, tell the user about the job as a whole, in a few lines, since this is the first they hear of it: what they asked that workspace for, the PR it put up, by title, and how the rounds ended. For example: "*Retry the parser on timeouts*: done, in *retry parser on timeout* (#812). Review rounds approved it in round 4." Or: "…Review rounds still requested changes after 5 rounds." Read the workspace with `panopticon read` for what it was asked and for anything the turn before the rounds left for the user, such as a question or something it didn't do, and relay that too. The rounds' report is its last turn, so read back far enough to see the turn before it.

Then, by outcome:

- Approved: nothing to decide. For a `rounds-<n>` workspace, triage will propose deleting it.
- Not approved, stopped early without an approval, or an outcome that couldn't be read: it's the user's call. panopticon opens a `rounds-again` decision about the PR: ask it under its number from `decisions --lane work --json`. A yes runs `review-rounds <pr> --again`, and a no runs `panopticon continue <ws>`. Offer to read the report with `panopticon read`. For a `rounds-<n>` workspace, keeping, archiving or deleting it instead are choices you open with `panopticon ask --about <ws> --lane work` (`workflows/triage.md`, `workflows/delete.md`), and until the user answers, triage proposes nothing for it.
- Stopped with a question: panopticon opens a `rounds-question` decision about the PR. Put the question to the user under its number, and forward their answer in their own words with `panopticon send --quote`, as under "Sending" in `SKILL.md`.
- The outcome couldn't be read: read the transcript, and tell the user how the run ended, under its `rounds-again` decision.
