# Work items

| Command | What it does |
| --- | --- |
| `panopticon items [--due] [--json]` | The user's work items by state. `--due` lists only the deferred items that wait on the user. `--json` gives each item's links, workspaces, summary, blocker, pick-up and why it waits, if it does |
| `panopticon item show <item>` | One item as markdown: links, workspaces, state, summary |
| `panopticon item new`, `item edit <item>` | Add an item by hand, or edit one in `$EDITOR` |
| `panopticon open <item>` | Opens the item's links in the browser |
| `panopticon defer <item> --summary <file or -> [--blocker <b>] [--pick-up <p>]` | Records an approved summary and sets the item aside |
| `panopticon done <item>` | Marks an item done |
| `panopticon resume <item> [--group <g>]` | Creates a workspace seeded with a deferred item's summary, and opens its links |

A work item is the record of one piece of the user's work: its links, its workspaces, its state, and, once deferred, a summary. Workspaces and tabs are views of it that can be closed and opened again. When the user asks what they're working on, start from `items --json`, not from `ls`.

Deferring is where you do the work the CLI never does. When the user wants to set an item aside:

1. Read the transcripts of its workspaces.
2. Draft a summary: the task, what was found, what blocks it, and when to pick it up.
3. Show it to the user, and change it until they approve it.
4. Only then call `defer`, passing the summary on stdin with a quoted heredoc, and the blocker and pick-up with `--blocker` and `--pick-up`.

A deferred item's workspaces may then be archived, or deleted with the user's yes. Its summary is what lasts, so never defer without one the user approved.

## Deferred items coming back

A tick brings a deferred item back to the inbox when its pick-up date passes, or when every PR its blocker or pick-up names is merged or closed. The item stays deferred until the user resumes it, marks it done, or defers it again. `items --due` lists the deferred items that wait on the user, and `items --json` gives the same reason in `waiting`:

- `due` and `unblocked`: it came back, and panopticon opened an `item-due` decision about it: yes resumes it, and no leaves it deferred. It stays in the feed until the user answers, so name it only when it is new.
- `check-failed`: the last check couldn't read a PR it waits on.
- `by-hand`: no tick can check its pick-up or blocker, such as "when Mastra comes up again".

Ask about the `check-failed` and `by-hand` ones about once a week, not every session. Keep the date you last asked in `~/.local/state/panopticon-skill/due-asked-on`, and ask once it is seven days old or missing. For each one, give its title, blocker and pick-up, and open a decision:

```sh
panopticon ask --about <item id> --kind resume \
  --question "Resume <title>?" \
  --yes "a new workspace starts from its summary: panopticon resume <item id>" \
  --no "it stays deferred, and you're asked again in a week"
```

Marking it done instead is a choice the user can name in words.

`done` and `resume` change the item's state, and `resume` creates a workspace. `defer` and `done` also close the Chrome tabs of the item's specific links, unless given `--keep-tabs`. Run them only when the user asks, for the item they named. `item migrate` writes only with `--apply`, and needs the user's yes for that.
