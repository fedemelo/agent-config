# Reviews on the user's PRs

With a `my-pr-reviewed` rule that has `do = "address"`, every review someone leaves on the user's PR goes to the workspace that opened the PR, woken if it sleeps, as `/respond-to-review <url>`. That workspace fixes what holds, pushes, posts a reply per point all at once, and turns the PR into a draft straight after. The user revises every reply on GitHub and takes the PR out of draft themselves. You never do any of that: you never post, edit or delete a reply, take the PR out of draft, or ask anyone for a review.

What reaches you:

- Sending the review to the workspace is silent. Say nothing about it, even when the user asks what's new, unless they ask about that PR.
- `new-review` with "no workspace of yours opened it": no workspace lists the PR as one it opened, so nothing addresses it. Tell the user in a line with the link. If they want it addressed, they name a workspace, and you send it `/respond-to-review <url>` (see "Sending" in `SKILL.md`).
- `replies-ready`: the workspace's turn ended. Tell the user in one line with the link: "*N* replies on *<PR title>* are ready for you to revise", or that the review needed no reply. Notify it with `--open <link>`: this is the notification the user waits for. Then read the workspace's final message, from the `finished` event that came with it or `panopticon read <ws>`, and relay only what needs the user: a question it left unanswered, a change it discarded, or a reply that failed to post or a PR that didn't turn into a draft. Name the point each is about. When it all went through, add nothing.
- `replies-unread`: panopticon couldn't read the workspace's replies, so it can't keep the user's edits of them. Report it in a line. The replies themselves are on the PR as posted.

A question the workspace left gets the user's answer in their own words, with `panopticon send --quote`, and a note asking it to run `/respond-to-review <url>` again once it has acted on the answer. That run replies only to what is still unanswered, and posts those replies the same way.

Another review while the PR is still a draft goes to the workspace on its own, as the first did. Nothing for you to do.
