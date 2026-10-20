# A background session in its own worktree

For any environment that is not a devspaces pod, is not inside Herdr, and has the `claude` CLI on `PATH`. Reached from the [side-session](../SKILL.md) skill, which decides that this is the right procedure. Everything that skill says still holds; this file only says what a space is here and how to open, list and delete one.

## Open one

```sh
claude --bg -w "<name>" -n "<name>" --permission-mode auto "$(cat <<'EOF'
<starting prompt>
EOF
)"
```

- `--bg` returns immediately with a short id, so opening eight of these costs eight lines here and nothing else. The session starts in this repo.
- `-w` gives the session a worktree of its own. Without it the session shares this working tree, and anything it does to files or branches happens under this session too.
- `--permission-mode auto` because a background session in manual mode stalls on its first `gh` call, waiting for someone to switch to it and approve.
- The quoted heredoc passes the prompt through untouched. A prompt carrying quoted text, such as a review comment, is full of quotes, backticks and `$` that the shell would otherwise act on.

If the CLI will not open a session, that is the end of this path. Stop and report it. None of the space's work is done here instead.

## List and delete

`claude agents --json --all` lists the sessions, by name and id.

Hand back the line to delete one, and never run it yourself, even when the calling skill says the space is done with. It removes the session's worktree too, which may hold work that was never pushed.

```sh
claude rm <id>
```

## Reaching one

`claude attach <id>`, with the short id `claude --bg` returned.
