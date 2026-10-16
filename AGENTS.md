# agent-config

Implementation notes for agents working on this repo. `README.md` is for humans and covers what the repo offers and why. This file covers how it's built.

## Layout

- `skills/<name>/SKILL.md`, with `agents/openai.yaml` beside it for Codex. A skill that routes on the environment also has a `targets/` directory.
- `hooks/`: `PreToolUse` hooks. `_pretooluse.py` reads the payload and answers the harness; each hook imports it as a sibling and holds only its own decision.
- `install.sh`, `merge_settings.py`, `settings.json.example`: the installer for an owned machine.
- `scripts/validate_skills.py`: the packaging validator, run in CI.
- `scripts/skills_for.py`: prints the skills one environment gets.
- `explicit-only-skills.txt`: the skills the model may not start on its own. The file's header explains each choice, including why `commit` isn't there.
- `copy_prompt.py`, `Makefile`: `make <skill>`.
- `.claude-plugin/`, `.codex-plugin/`, `.agents/plugins/`: plugin manifests for other people. Not used to install this repo.
- `ruff.toml`: line length 120, `py312`, isort. CI checks format and lint on a pinned ruff.

## Install

`install.sh` does three things:

1. Symlinks `hooks/` into `~/.claude/`.
2. Links every skill this environment gets into both `~/.claude/skills/` and `~/.agents/skills/`. Copilot and OpenCode read the second one too.
3. Merges the hook entries from `settings.json.example` into `~/.claude/settings.json`. Entries are matched by script, so a changed command updates in place.

The repo installs no global rules. `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` belong to the user. Earlier versions linked both at a `CLAUDE.md` in this repo. The installer turns any slot still linked there into a plain copy of that file's last version, taken from git history.

Editing a skill takes effect at once through the symlinks. Adding, renaming or removing one needs a re-run, which creates new links and prunes dead ones.

The manual update order is `git pull && ./install.sh` in git-tools first, then the same here. `/wire-up` does this and checks what the installers leave to a human: `~/.local/bin` on `PATH`, `user.email`, `gh` auth, and every skill linked into both runtimes.

## Environments

The `environment` skill decides which kind of environment a session is in. A devspaces pod has all of `/mnt/personal`, `/etc/claude-code/` and a `devspaces` executable. A host with none of them is an owned machine. When the signals disagree, every skill stops rather than guess. `install.sh` applies the same rule in shell.

In a pod, `install.sh` refuses to run. Symlinked skills are never loaded there, and the installers write machine-wide config the pod doesn't own. `/wire-up` follows `skills/wire-up/targets/devspaces.md` instead. It copies onto the persistent share and from there into both skill directories, and it deletes whatever the repo no longer has. That file explains what breaks otherwise.

The `environment` frontmatter key scopes a skill to `devspaces`, `owned-machine`, or `any` (the default). Every installed skill spends its description on every session, so a skill that can't be used somewhere shouldn't be installed there. Only `land` and `todo` are scoped, to `owned-machine`. The rest work on repo and GitHub state, which is the same everywhere.

- `scripts/skills_for.py` is the only reader of the key. `install.sh` and the devspaces procedure both select through it, so they can't disagree about which skills a pod has.
- A skill may only `[[reference]]` one that is installed everywhere it is. Nothing expands a reference at runtime, so a missing one fails silently.
- When only the procedure differs, the skill stays `any` and routes to a file under `targets/`, as `wire-up` and `review-queue` do. A routing skill can't be scoped, since it would be missing from the environment it's meant to identify.

## Invocation policy

Claude reads `disable-model-invocation` from `SKILL.md`. Codex ignores it and reads `policy.allow_implicit_invocation` from `agents/openai.yaml`. Each skill states its policy in both, and the validator holds both to `explicit-only-skills.txt`.

Hooks and `disallowed-tools` have no Codex equivalent. Under Codex, the read-only skills are held to their own wording.

## Audience

The `audience` frontmatter key is `others` when someone other than the user reads the skill's output, and `user` when the output stays in the session. An `others` skill must reach `[[plain-english]]`, and the validator enforces it. One hop counts: `open-pr` reaches it through `pr-description`. The key is declared per skill rather than listed in the validator, so a new skill can't go unchecked. Neither runtime reads it.

## Hooks

- `enforce-commit-skill.py` blocks `git commit` until the commit skill has been invoked in the session. It reads the transcript.
- `enforce-pr-description-skill.py` blocks `gh pr create`, and `gh pr edit` with a body, until the pr-description skill has been invoked. It reads the transcript too.
- `require-git-tools.py` blocks `git land`, `git todo` and `git review-feedback` until the git-tools executables are installed, so a skill can't fall back to raw `gh` calls.

They are hooks because no permission rule can check session history or the filesystem.

## Settings

`settings.json.example` grants no pre-approved commands. An allow rule would take a command out of the auto mode classifier's review. It's for owned machines only. The installer refuses to run in a pod, and the pod procedure skips the file. Its blank `attribution.commit` would lose to the pod's managed settings anyway.

The installer checks that every hook named in the file exists. The validator checks the other direction: every hook in `hooks/` must be registered, or it's linked and never run.

## Validator

`python3 scripts/validate_skills.py` checks that:

- both runtimes and `explicit-only-skills.txt` agree on invocation policy
- a skill's frontmatter names its own directory
- every `[[reference]]` points at a skill that exists
- every `audience: others` skill reaches the prose standard
- no skill references one that is missing where it runs
- no routing skill is scoped to one environment
- a routing skill and its `targets/` directory list the same files
- every hook in `hooks/` is registered in `settings.json.example`
- `copy_prompt.py` can title every skill
- the plugin manifests stay accurate

It parses YAML itself so the repo stays dependency-free. The parser rejects duplicate keys and anything outside the small subset this repo uses.

## make \<skill\>

The output is the skill without its frontmatter, under a title and wrapped in `"""`, followed by its references in the same shape. A reference the task can't be done without is included, recursively. A skill that's only named as a separate step, like `commit`, goes in a closing block instead. That block tells the model why the text is missing and to ask the user for it if needed.

The clipboard tool is `pbcopy` on macOS, or `wl-copy`, `xclip` or `xsel` on Linux. If none works, the prompt goes to stdout and the reason to stderr. `python3 copy_prompt.py <skill> --stdout` prints it on purpose.

## Tests

```sh
for t in tests/*.test.sh; do "$t"; done
```

No dependencies and no network. Install tests use a throwaway `HOME`. Hook tests feed a payload on stdin, plus a throwaway transcript where needed. Validator tests break one thing in a throwaway copy of the repo. Run the validator directly after changing how a skill is packaged.
