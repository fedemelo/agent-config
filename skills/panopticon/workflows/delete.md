# Archiving and deleting

| Command | What it does |
| --- | --- |
| `panopticon archive <ws> [--interrupt]`, `delete <ws>... --yes [--unproposed] [--interrupt] [--discard-work]` | Archives a workspace, or queues deleting one or more and returns at once. panopticon carries the deletion through in the background, retrying for up to a day, and reports how it ended in the inbox |
| `panopticon delete --cancel <ws>`, `panopticon deletions [--json]` | Withdraws a queued deletion, or lists the queued ones and how each stands |

A workspace is archived or deleted as one of these:

- `panopticon archive <ws>`: stops it and archives it. It refuses while the agent is working. Pass `--interrupt` only when the user said to stop that turn.
- `panopticon delete <ws>... --yes`: only after the user said yes to deleting each workspace named: by its number, or named or clearly meant. A general "delete them all" isn't a yes for each one, and you never pass `--yes` on your own. A delete can't be undone. Each of its other flags waives one check, and needs a yes of its own for what that check keeps:
  - `--unproposed`, for a workspace triage doesn't propose for deletion, or no longer does: one the user asks to delete on their own, one outside the conventions, one whose proposal was withdrawn, or one in a deferred item. Before asking, tell the user that triage didn't propose it and why it would keep it, such as an open PR or recent activity, and what deleting loses: the agent's conversation, and any work not on GitHub, which panopticon checks for and lists before it deletes anything. For a deferred item's workspace, its summary is already kept. A yes to deleting it after hearing this is the yes for `--unproposed`.
  - `--interrupt`, only when the user said to stop the agent's turn, or to drop the messages queued for it.
  - `--discard-work`, only after panopticon listed what it found that isn't on GitHub (uncommitted or untracked changes, stashes, commits on no remote branch, entries that aren't repos), you showed that list to the user, and they said yes to losing it. Tell them ignored files, such as a `.env`, are lost too and never listed. For a deletion parked because the workspace holds no repo, or one that gave up because it couldn't be read, pass it only after the user heard its work couldn't be checked and said yes to losing whatever it holds. Never pass it just to skip the check.

  `delete` checks right away only what needs no waiting: that the workspace is the user's, and that triage proposes it or the user said yes anyway. When it refuses then, report why and ask about the flag the refusal names, if any. Otherwise it prints that the deletion is queued and returns. Run it once, tell the user it's queued, and move on. panopticon carries it through by itself: it starts a stopped workspace for the check, waits for SSH, waits out a working agent, and retries a dropped connection or a busy Dev Spaces for up to a day. Never run delete again, wait, poll `deletions`, or check the workspace to see how it's going. Running delete again with the same flags changes nothing, and keeps the day the first yes gave it.

  When the user said yes to deleting several workspaces, queue them in one call, not one call each. A flag applies to every workspace in the call, so put in one call only the workspaces that need the same flags, and run one call per set of flags. When it refuses some of them, report each refusal by workspace, and ask about the flag each one names.

  Act only when the inbox says how it ended. Each of these arrives once:
  - `deleted`: tell the user it's gone.
  - `deleted-elsewhere`: something else deleted it first, such as a review refresh. Tell the user it's gone. Nothing is left to do.
  - `deletion-parked`: it waits on the user's answer, and the event says why:
    - Work that isn't on GitHub, listed in the event: show the list and ask about `--discard-work`.
    - `~/repositories` holds no repo, so nothing could be checked: tell the user its work couldn't be checked, and ask about `--discard-work` for losing whatever it holds.
    - Triage no longer proposes it, or it was moved or retitled out of the conventions since the yes: say what changed, and ask about `--unproposed`.

    On a yes, run delete again with that flag, once, and move on as before. On a no, run `panopticon delete --cancel <ws>`.
  - `deletion-abandoned`: it gave up after a day of failures, or it was cancelled but the workspace panopticon started for the check couldn't be stopped. Report the reason. After giving up, a workspace started for the check is stopped again, unless the event says it was left running. Run delete again only if the user asks.

  Never find another way to delete.
