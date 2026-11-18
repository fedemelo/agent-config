# Bootstrap

| Command | What it does |
| --- | --- |
| `panopticon bootstrap [--json]` | Whether a bootstrap is due and why, the room under Dev Spaces' limit, the workspaces it would wake, those left asleep and why, and how the reviews stand. Changes nothing |
| `panopticon bootstrap run` | Wakes every workspace of the user's active items that fits the room and reads their last words, asks about those that would take the places kept for reviews, and opens each staged review's PR. Prints what it did as JSON |
| `panopticon wake <ws>... [--into-reserve]` | Wakes the workspaces named and reads their last words, within the same room. Prints what it did as JSON |

A bootstrap is a fresh overview for when the user starts to work. `bootstrap --json` says in `due` whether one is due, and in `reason` why, in plain words. It is due when none of the user's active work is awake: Dev Spaces stops a workspace after 2 idle hours, so when all of it sleeps, the user has been away at least that long.

Whenever the user says something like "let's bootstrap", "start over" or "give me a fresh overview", run the bootstrap as below, whatever `due` says.

## Running it

Don't ask whether to wake anything. Waking the active work is what the user would say yes to every time, since asleep it gets nothing done.

Run `bootstrap run`, and `wake`, as background commands: each waits up to 11 minutes for the workspaces to come up and answer, and the session must keep listening meanwhile. Tell the user you're waking them, and report once the command returns.

`bootstrap run` wakes the workspaces of active items that fit the room: Dev Spaces' limit of active workspaces, less those already up, less the places kept for review requests. Those that would take a reserved place stay asleep, held for one decision, whose number is in `decision`. The decision gathers what every wake held, keeps its number, and drops a workspace once it's woken or no longer a candidate. Those past the limit stay asleep either way. Each one not woken is in `not_woken` with its reason. When `warnings` says Dev Spaces' limit is lower than the config's, tell the user the line to set in the config. Workspaces of deferred or done items, kept or proposed ones, and those outside the conventions are never candidates.

## The report

Open with what you did: "I woke the parser fix and the bulk deletions work." Name each workspace by its item's title and what it was doing, from its title.

Then, for each woken workspace, say where it left off from `last_words` in `bootstrap run`'s output. When its entry has an `error` instead, say so plainly, and never guess where it left off from its title. Brief from `triage --json`, as under "Briefing" in `workflows/triage.md`. Its finding was answered as `continue`, which closed its decision. Open one with `panopticon ask` only for a real choice about the work, such as a workspace whose last words say it's finished.

Then the ones not woken, most recent first, each with its reason in plain words. When `decision` is set, name it as under "Decisions" in `SKILL.md`: what yes costs (a review request may find no room until something stops) and what no keeps.

Then report the reviews, as under "In a bootstrap" in `workflows/reviews.md`.

## Waking during the day

When you need to read or continue a stopped workspace, because the user asks about it, asks you to send to it, or asks to continue it, run `panopticon wake <ws>` and say you did. Don't ask first. `wake` fits the room as `bootstrap run` does, records the wake so triage's clock isn't reset, and reads the last words. It refuses, waking nothing, a workspace that isn't a candidate: tell the user why, from its message.

When `wake` leaves a workspace asleep for the review places, it adds it to the same decision. The user answers it like any decision, by its number, as under "Decisions" in `SKILL.md`: a number named alone is a yes. Record the answer with `panopticon answer`, and only after a yes run the command its yes names, `wake <ws>... --into-reserve`, with no workspace it doesn't name. A no leaves them asleep and the places free.
