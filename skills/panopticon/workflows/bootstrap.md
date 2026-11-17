# Bootstrap

| Command | What it does |
| --- | --- |
| `panopticon bootstrap [--json]` | Whether a bootstrap is due and why, the workspaces it would wake, those left asleep and why, and how the reviews stand. Changes nothing |
| `panopticon bootstrap run [--wake <ws>...] [--over-the-cap]` | Wakes the workspaces named and reads their last words, and opens each staged review's PR. Prints what it did as JSON |

A bootstrap is a fresh overview for when the user starts to work. `bootstrap --json` says in `due` whether one is due, and in `reason` why, in plain words. It is due when none of the user's active work is awake: Dev Spaces stops a workspace after 2 idle hours, so when all of it sleeps, the user has been away at least that long.

Whenever the user says something like "let's bootstrap", "start over" or "give me a fresh overview", run `bootstrap --json` again and open with the bootstrap as below, whatever `due` says.

Ask one numbered question: "**1.** Wake the workspaces of your active items". Under it, name each workspace in `wake` by its item's title and what it was doing, from its title. Say that each one runs until Dev Spaces stops it after 2 idle hours. Say how many are in `over_the_cap`, and that the user can ask for any of them by name. The workspaces in `left_asleep` stay asleep, so don't offer them.

Then run `bootstrap run`, with `--wake` and the workspaces the user agreed to. A yes to 1 means every workspace in `wake`. A reply in words, such as "1 but not the debugger one", means what it says. With no yes, run `bootstrap run` without `--wake`, which still opens the tabs. Never name a workspace the user didn't agree to: `bootstrap run` refuses one it wouldn't offer, and wakes nothing then. It also refuses more workspaces than `bootstrap` offered in `wake`. Pass `--over-the-cap` for that only when the user asked for the extra ones by name.

Brief from `triage --json`, as under "Briefing" in `workflows/triage.md`. Every woken workspace now has last words, unless its entry in `bootstrap run`'s output says why not: say so plainly, and never guess where it left off from its title. Its finding was answered as `continue`, so it gets no number. A number goes only to a real choice, such as a workspace whose last words say it's finished.

Then report the reviews, as under "In a bootstrap" in `workflows/reviews.md`.
