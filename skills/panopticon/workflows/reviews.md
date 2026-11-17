# Reviews

| Command | What it does |
| --- | --- |
| `panopticon refresh-review <repo>#<n>`, `keep-review <repo>#<n>` | Answers a stale review the user edited: discard it and run a fresh review, or keep it and never refresh it |

## In a bootstrap

The reviews come from `bootstrap --json`'s `reviews`, in one short block:

- Staged: each PR by its title, with its number of comments, and say its PR is open in a tab (`tabs_opened` or `tabs_already_open`). Report each entry in `warnings` in a line, such as tabs that couldn't be opened, and give those PRs' links instead.
- Not staged, each PR by its title, with its state in plain words: running, waiting (it runs idle with nothing staged, so it may be asking something; read it), never ran, or stopped without staging.
- A staged review with `stale` went stale after the user edited it: say what made it stale and ask as under "Stale staged reviews".
- A not-staged review with `refreshes` is a fresh review replacing one that went stale: say so, with the reason, in the same line.
- A review that never ran gets a decision, asked under the number it prints:

  ```sh
  panopticon ask --about <ws> --kind start-review \
    --question "Start the review of <PR title>?" \
    --yes "wake it with its prompt: panopticon send <ws> --wake -- /stage-review <url>" \
    --no "leave it stopped; triage proposes it for deletion once its PR ends"
  ```

  A yes runs `panopticon send <ws> --wake -- /stage-review <url>`. A review that stopped without staging can't be read while stopped: say so, and ask in words whether to start it the same way.

## Stale staged reviews

A staged review the user hasn't submitted goes stale once anything happens on its PR: a push, or a comment, review or reply by anyone else. Ticks check every 15 minutes and wait for 30 quiet minutes. Their events:

- "review of *<title>* was stale, a new one is running": the review was untouched, so panopticon discarded it and opened a new `review-<n>` workspace. Report it, with the reason in its context. Nothing to ask.
- "review of *<title>* is stale, but you edited it": nothing was discarded. It can also come after a refresh started, when the user edited the review before panopticon deleted it. panopticon opens its decision itself, a `refresh-review` about the PR: ask it under the number `decisions --json` gives it. Yes runs `panopticon refresh-review <repo>#<n>`: the pending review and the user's edits on it are deleted, and a new review workspace stages a new one from scratch. No runs `panopticon keep-review <repo>#<n>`: the review stays as it is, with the user's edits, and is never refreshed, even if more happens on the PR. Say both under the question, since here a no also acts. If `refresh-review` says there is nothing to do, the review is no longer pending, the PR is closed or a draft, or a tick already refreshed it: say which applies.
- "couldn't refresh the review of …": a step failed, and the next follow-up tries again. Report the error.
- "was replaced by a new review but isn't deleted": the user's standing yes (`[reviews] delete_replaced`) let a tick try to delete the old workspace, and a check refused: its agent was working or had messages queued, it holds work that isn't on GitHub, or the user retitled or moved it. It stays proposed for deletion in triage. Report why.

While the standing yes is on, an untouched stale review's old workspace is deleted without asking, so don't ask about it. Without it, or for a review the user edited, triage proposes it as replaced by a newer review, and it needs a yes like any other.
