# The user's PRs that can't merge

With a `my-pr-unhealthy` rule that has `do = "repair"`, each of the user's open PRs that conflicts with its base, or fails a check its base passes, goes to the workspace that works on it as `/fix-pr <url>`. Drafts count too. That workspace resolves the conflicts, fixes the failures that are the PR's own, brings in the base when the base fixed one, and pushes. It merges the base in, or rebases and restacks when the PR is in a stack. You never do any of that yourself.

The tick holds a PR back on its own while its checks still run, while every check failing on it fails on its base too, or while a lower PR of its stack can't merge. A sleeping workspace is woken only into the room left after the places kept for reviews. One that would take a kept place is held for the `wake-into-reserve` decision, which `workflows/bootstrap.md` covers. Once the user says yes and it's woken, the next run sends it the PR.

What reaches you:

- Sending the PR to its workspace, or opening an `address-<n>` workspace for it, is silent. Say nothing about it unless the user asks about that PR.
- The workspace's turn ending is a `finished` event like any other. Read its final message and relay only what needs the user: a conflict it left for them, a check it couldn't place, a PR that waits on a broken base, or PRs above it that it force-pushed while another workspace holds them. When it fixed everything, a line saying so is enough.
- `pr-repair` with "none fixes it": no workspace opened the PR or works on it in an active item, and the rule opens none. Tell the user in a line with the link. If they want it fixed, they name a workspace, and you send it `/fix-pr <url>` (see "Sending" in `SKILL.md`).
- `pr-repair` with "left to you": the PR was sent to be fixed 3 times in a day and still can't merge, so nothing more is sent until the day has passed. Tell the user in a line with the link, and read the workspace's last final message for why.
