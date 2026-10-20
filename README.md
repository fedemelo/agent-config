# agent-config

My skills and hooks for Claude Code and Codex.

Some perks:
- The skills are meant to save *humans* time (and agents tokens). They work for Claude Code and Codex.
- This does not touch/conflict with your own setup. To install/update, on a new machine or on an older version of this repo, just tell an agent to follow for the wire-up skill (or run `./install.sh`)
- Useful stuff: 
    - Some skills call fast [git-tools](https://github.com/fedemelo/git-tools) commands instead of `gh` ones
    - The skills are symlinked so editing them in the cloned repo edits them live
    - Some skills can only be used with explicit invocation (i.e., no agent can decide to use them, only a human)
    - Skills know to act differently on different environments (e.g., a local machine vs a short-lived container)
    - Hooks block commands such as `git commit` until the `commit` skill is loaded

The installed settings pre-approve no commands, so in auto mode the classifier still reviews every command.

If you're working with a model without a harness, use `make <skill>` to copy a skill (and any info it depends on) to the clipboard to use it as a prompt:
```sh
make local-review   # Copied to clipboard: local-review, pr-target, comment-hygiene, plain-english
make list           # the skills you can copy
```

## Skills

Skills marked \* only start when you type them (`/name` in Claude Code, `$name` in Codex), not automatically.

- [wire-up](skills/wire-up/SKILL.md)\*: brings any environment's setup up to date.
- [local-review](skills/local-review/SKILL.md): an in-session PR or code review. Never posts to the PR. E.g. prompt:, `local-review https://github.com/org/repo/pull/1067`
- [review-queue](skills/review-queue/SKILL.md)\*: gathers the PRs waiting on your review, assigns an separate agent to local-review each.
- [address-review](skills/address-review/SKILL.md)\*: takes a review, checks whether comments hold, fixes the real comments and drafts in-session replies to the rest. It never posts to the PR.
- [pr-from-review](skills/pr-from-review/SKILL.md)\*: turns a review comment into a draft PR stacked on the reviewed branch, built by a separate agent. Works on your PRs and on other people's.
- [review-rounds](skills/review-rounds/SKILL.md)\*: up to three local-review then adress-review rounds, each by a fresh agent.
- [land](skills/land/SKILL.md)\*: ships your commits through a disposable PR that merges itself.
- [open-pr](skills/open-pr/SKILL.md)\*: branches off the latest default branch, commits, assigns you and writes a strict description.
- [todo](skills/todo/SKILL.md)\*: files a GitHub issue assigned to you.
- [commit](skills/commit/SKILL.md): one commit per file, a terse message, no AI attribution.
- [fact-check-my-review](skills/fact-check-my-review/SKILL.md): checks that a PR review you posted is true, its fixes work and its severity fits.
- [discussion-audit](skills/discussion-audit/SKILL.md): checks your posted replies against the PR code and finds if you forgot to address something.
- [work-summary](skills/work-summary/SKILL.md): recaps your PRs since a date, split into open, merged and closed.
- Shared standards the others follow: [environment](skills/environment/SKILL.md), [side-session](skills/side-session/SKILL.md), [pr-target](skills/pr-target/SKILL.md), [comment-hygiene](skills/comment-hygiene/SKILL.md), [pr-description](skills/pr-description/SKILL.md), [plain-english](skills/plain-english/SKILL.md).

