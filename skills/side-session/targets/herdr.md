# A Herdr worktree workspace running this session's agent

For any environment that is not a devspaces pod, when this session runs inside Herdr (`HERDR_ENV=1`), whichever agent it is. Reached from the [side-session](../SKILL.md) skill, which decides that this is the right procedure. Everything that skill says still holds; this file only says what a space is here and how to open, list and delete one.

A space is a Herdr worktree workspace: a git worktree of this repo, opened as a workspace that Herdr files under this repo's workspace in the sidebar, with the same kind of agent as this session running in it. The user sees every space beside the one they work in, and sees when one finishes or waits on an approval. That is why this beats a background session, and why no permission mode is forced on the agent.

Herdr's own skill says not to create worktrees or workspaces unless asked. The calling skill asking for a space is that request.

## Open one

1. Find this session's agent kind. It is `.result.agent.agent` from:

   ```sh
   herdr agent get "$HERDR_PANE_ID"
   ```

   If it is empty, or not a kind `herdr agent start --help` lists, stop and report it.

2. Create the worktree, with a branch and a label both set to the caller's name, without taking the user's focus:

   ```sh
   herdr worktree create --cwd "$PWD" --branch "<name>" --label "<name>" --no-focus
   ```

   Read the new pane from `.result.root_pane.pane_id`. If a branch of that name already exists, the command fails; stop and report it.

3. Start the agent in that pane. Agent names must match `[a-z][a-z0-9_-]{0,31}`, so use the caller's name cut to 32 characters, with any trailing `-` dropped:

   ```sh
   herdr agent start "<agent-name>" --kind "<kind>" --pane "<pane-id>"
   ```

4. Seed it, passing the prompt through a quoted heredoc so its quotes, backticks and `$` reach the agent untouched. No `--wait`: the space runs on its own.

   ```sh
   herdr agent prompt "<agent-name>" "$(cat <<'EOF'
   <starting prompt>
   EOF
   )"
   ```

If any step fails, that is the end of this path. Stop and report what you ran and what it said. None of the space's work is done here instead.

## List and delete

`herdr worktree list --cwd "$PWD"` lists this repo's worktrees. The spaces are the linked ones, known by `branch`, which is the name they were opened under, with `open_workspace_id` for the workspace.

Hand back the line to delete one, and never run it yourself, even when the calling skill says the space is done with. It closes the workspace and stops its agent, whatever it is doing. Never add `--force`, which throws away uncommitted work.

```sh
herdr worktree remove --workspace <workspace-id>
```

## Reaching one

The workspace in Herdr's sidebar, labelled with the space's name, under this repo's workspace.
