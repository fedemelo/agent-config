# Reviews

| Command | What it does |
| --- | --- |
| `panopticon reviews [--json]` | The review queue: each staged review waiting on the user, and each review workspace that hasn't staged one yet, with how it stands. Changes nothing |
| `panopticon reviews open` | Opens the PR of each staged review that no Chrome tab shows. Prints what it opened as JSON |
| `panopticon refresh-review <repo>#<n>` | Only when the user asks: bring the staged review in line with its PR now, without waiting for the PR to go quiet |
| `panopticon exclude-review <owner>/<repo>#<n>` | The user left the PR's review to someone else: requests through a team open no review for it again, and its staged review is never updated |
| `panopticon include-review <owner>/<repo>#<n>`, `excluded-reviews` | Take an excluded PR's review back; list the excluded PRs |
| `panopticon review-redrafted <owner>/<repo>#<n>` | After a review workspace rewrote its staged comments, take the new wording as drafted, so it doesn't count as the user's edit |
| `panopticon rewrite-review <owner>/<repo>#<n>` | When the workspace that staged a review is gone, open a new review workspace that rewrites the comments the user hasn't changed |

## A review is ready

The one thing to tell the user about a review is the `review-staged` event: "the review of *<PR title>* is ready". Report it in that one line with its `link`, once per event. It comes once per review, when a workspace first stages it, or when a new workspace takes over a review whose workspace was gone. Don't add how many comments it has or how many times it was updated. Nothing to ask.

## A plainer review

When the user finds a staged review too hard to read, send `/stage-review rewrite` to that PR's review workspace, followed by the comment numbers if they named some. Wake it first if it's stopped. If that workspace is gone, run `panopticon rewrite-review <owner>/<repo>#<n>` instead, which opens a new one for the rewrite. Comment numbers can't go to it, since they belong to the old workspace's index, so it rewrites every comment the user hasn't changed: say so if they named some. Either way, when its turn ends, read its report and run the `panopticon review-redrafted` line it ends with. Never rewrite a comment in this session.

## The queue

The reviews session opens on the queue, so the user sees at once what waits for them, and shows it again whenever they ask what reviews are pending. Run `panopticon reviews --json`, then `panopticon reviews open`, without asking, so each staged review's PR is open in a tab. Report the queue in one short block, newest first. When it is empty, say in a line that no review waits on them:

- Staged: one line per review, "the review of *<PR title>* is ready", with its link, and say its PR is open in a tab (`opened` or `already_open`). Report each entry in `warnings` in a line, such as tabs that couldn't be opened.
- Not staged, each PR by its title, with its state in plain words: running, waiting (it runs idle with nothing staged, so it may be asking something; read it), never ran, or stopped without staging.
- A staged review with `updating` is being brought in line with its PR: say so in the same line, with what changed (`updating`), so the user waits for it before editing. Ask nothing.
- A review that never ran gets a decision, asked under the number it prints:

  ```sh
  panopticon ask --about <ws> --lane reviews --kind start-review \
    --question "Start the review of <PR title>?" \
    --yes "wake it with its prompt: panopticon send <ws> --wake -- /stage-review <url>" \
    --no "leave it stopped; triage proposes it for deletion once its PR ends"
  ```

  A yes runs `panopticon send <ws> --wake -- /stage-review <url>`. A review that stopped without staging can't be read while stopped: say so, and ask in words whether to start it the same way.

## Stale staged reviews

A staged review the user hasn't submitted goes stale once anything happens on its PR: new commits, or a comment, review or reply by anyone else, bots and backtests included. panopticon handles it without asking, and never opens a decision about it. Once the PR has been quiet for a while, it sends `/stage-review update` to the workspace that staged the review, or opens a new one when that is gone. The update removes comments the code fixed or that someone else already made, rewrites ones that add to someone else's point as "I agree with <name>", moves outdated ones and adds new findings, in the pending review. It does this to the user's own edited comments too: keeping the review current matters more than keeping their wording.

- An update that changed none of the user's comments is silent: there is nothing to report.
- "the review of *<PR title>* was updated; N of your comments changed": report it in a line with its link and the comments it names. Their old text is in the workspace's report; offer to show it, and read it from the workspace when asked.
- "the review of *<PR title>* went stale and couldn't be redone": an update kept failing past the quiet window. It comes once. Report it in a line with its link; the user may want to review the PR by hand.
- Run `refresh-review` only when the user asks to update a review now. If it refuses, an update is already running, or the review is no longer pending or its PR is closed or a draft: say which applies.

## Reviews left to someone else

A review request can come through a team the user is in, and the team may agree that someone else takes it. When the user says so about a PR, run `exclude-review` on it without asking. From then on panopticon opens no review workspace for that PR, however often the team is asked again, and never updates a review staged on it. Don't tell the user to remove themselves from the PR's reviewers: there is no need to. Only a request that names the user, not their team, opens a review again. When the new review is ready, say that the user was asked by name on a PR they had left to someone else. Run `include-review` only when the user says they'll review the PR after all.

Excluding a PR leaves what it already has as it is. A staged review still pending on it is the user's, so ask in words whether to discard it. Its workspaces are handled as in "Finished review workspaces": once the PR has no pending review of the user's, they are deleted under the standing yes, or proposed in triage without it.

## Finished review workspaces

With `[reviews] delete_finished = true`, the user's standing yes, panopticon deletes a review workspace it created once its review is over: its PR merged or closed, or the review it staged is no longer pending (the user submitted or discarded it) and no pending review of theirs is left on the PR. It does so through the deletion queue with `--discard-work`, and silently: no decision, no notification, no inbox event to report, not even its stopping or going. Don't ask about these workspaces or report them as gone. If the standing yes stops covering one, such as the PR reopening, the deletion ends without a word. Only a deletion that gives up reaches the inbox, once, and is handled as in `workflows/delete.md`. A `review-<n>` workspace the user made by hand is never deleted this way, and triage proposes it as before. Without the key, triage proposes them and asks, as in `workflows/triage.md`.
