# Reviews

| Command | What it does |
| --- | --- |
| `panopticon refresh-review <repo>#<n>`, `keep-review <repo>#<n>` | Only when the user asks, for a stale review they edited: discard it and run a fresh review, or keep it and never refresh it |
| `panopticon exclude-review <owner>/<repo>#<n>` | The user left the PR's review to someone else: requests through a team open no review for it again, and its staged review is never refreshed |
| `panopticon include-review <owner>/<repo>#<n>`, `excluded-reviews` | Take an excluded PR's review back; list the excluded PRs |
| `panopticon review-redrafted <owner>/<repo>#<n>` | After a review workspace rewrote its staged comments, take the new wording as drafted, so it doesn't count as the user's edit |
| `panopticon rewrite-review <owner>/<repo>#<n>` | When the workspace that staged a review is gone, open a new review workspace that rewrites the comments the user hasn't changed |

## A review is ready

The one thing to tell the user about a review is the `review-staged` event: "the review of *<PR title>* is ready". Report it in that one line with its `link`, once per event. It comes for every review a workspace stages, the first one or a fresh one that replaced a stale one, and the two are told the same way. Don't add how many comments it has, that it replaced another, or how many times it was redone. Nothing to ask.

## A plainer review

When the user finds a staged review too hard to read, send `/stage-review rewrite` to that PR's review workspace, followed by the comment numbers if they named some. Wake it first if it's stopped. If that workspace is gone, run `panopticon rewrite-review <owner>/<repo>#<n>` instead, which opens a new one for the rewrite. Comment numbers can't go to it, since they belong to the old workspace's index, so it rewrites every comment the user hasn't changed: say so if they named some. Either way, when its turn ends, read its report and run the `panopticon review-redrafted` line it ends with. Never rewrite a comment in this session.

## In a bootstrap

The reviews come from `bootstrap --json`'s `reviews`, in one short block:

- Staged: one line per review, "the review of *<PR title>* is ready", with its link, and say its PR is open in a tab (`tabs_opened` or `tabs_already_open`). Report each entry in `warnings` in a line, such as tabs that couldn't be opened.
- Not staged, each PR by its title, with its state in plain words: running, waiting (it runs idle with nothing staged, so it may be asking something; read it), never ran, or stopped without staging.
- A staged review with `stale` is one the user edited whose PR changed since: say so once, as information, with what changed (`stale`), and that their edited review is kept. Ask nothing.
- A not-staged review with `refreshes` is a fresh review replacing one that went stale: report it like any other, without the reason or the old review.
- A review that never ran gets a decision, asked under the number it prints:

  ```sh
  panopticon ask --about <ws> --kind start-review \
    --question "Start the review of <PR title>?" \
    --yes "wake it with its prompt: panopticon send <ws> --wake -- /stage-review <url>" \
    --no "leave it stopped; triage proposes it for deletion once its PR ends"
  ```

  A yes runs `panopticon send <ws> --wake -- /stage-review <url>`. A review that stopped without staging can't be read while stopped: say so, and ask in words whether to start it the same way.

## Stale staged reviews

A staged review the user hasn't submitted goes stale once anything happens on its PR: a push, or a comment, review or reply by anyone else. panopticon handles it without asking, and never opens a decision about it:

- Untouched: panopticon discards it and opens a new `review-<n>` workspace on its own. Its events, the refresh and any refresh that failed, are silent: they never reach the inbox or a notification, so there is nothing to report or ask. The user hears of it only when the new review is ready (see "A review is ready").
- "the review of *<PR title>* went stale and couldn't be redone": a refresh kept failing past the quiet window with no new review staged. It comes once. Report it in a line with its link; the user may want to review the PR by hand.
- Edited by the user: their work in progress, which panopticon never discards, refreshes or asks about. One `stale-review-edited` event, "*<PR title>* changed since its review was staged; your edited review is kept", with what changed in its context, arrives once. Report it once as information, with no number and no question. Run `refresh-review` or `keep-review` only when the user asks for it. If `refresh-review` says there is nothing to do, the review is no longer pending, the PR is closed or a draft, or a tick already refreshed it: say which applies.
- "was replaced by a new review but isn't deleted": the user's standing yes (`[reviews] delete_replaced`) let a tick try to delete the old workspace, and a check refused: its agent was working or had messages queued, it holds work that isn't on GitHub, or the user retitled or moved it. It stays proposed for deletion in triage. Report why.

While that standing yes is on, an untouched stale review's old workspace is deleted without asking, so don't ask about it. Without it, triage proposes it as replaced by a newer review, and it needs a yes like any other.

## Reviews left to someone else

A review request can come through a team the user is in, and the team may agree that someone else takes it. When the user says so about a PR, run `exclude-review` on it without asking. From then on panopticon opens no review workspace for that PR, however often the team is asked again, and never refreshes a review staged on it. Don't tell the user to remove themselves from the PR's reviewers: there is no need to. Only a request that names the user, not their team, opens a review again. When the new review is ready, say that the user was asked by name on a PR they had left to someone else. Run `include-review` only when the user says they'll review the PR after all.

Excluding a PR leaves what it already has as it is. A staged review still pending on it is the user's, so ask in words whether to discard it. Its workspaces are handled as in "Finished review workspaces": once the PR has no pending review of the user's, they are deleted under the standing yes, or proposed in triage without it.

## Finished review workspaces

With `[reviews] delete_finished = true`, the user's standing yes, panopticon deletes a review workspace it created once its review is over: its PR merged or closed, or the review it staged is no longer pending (the user submitted or discarded it) and no pending review of theirs is left on the PR. It does so through the deletion queue with `--discard-work`, and silently: no decision, no notification, no inbox event to report, not even its stopping or going. Don't ask about these workspaces or report them as gone. If the standing yes stops covering one, such as the PR reopening, the deletion ends without a word. Only a deletion that gives up reaches the inbox, once, and is handled as in `workflows/delete.md`. A `review-<n>` workspace the user made by hand is never deleted this way, and triage proposes it as before. Without the key, triage proposes them and asks, as in `workflows/triage.md`.
