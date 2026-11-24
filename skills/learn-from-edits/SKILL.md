---
name: learn-from-edits
description: Learns from how the user changed Claude's drafted review comments and replies before posting them, read from panopticon's review-edits and reply-edits, and changes the skills that drafted them so the next drafts need fewer edits. Lands the changes it may make on its own, asks through a panopticon decision about the rest, marks learned only the edits behind a change, and notifies the user once with what changed.
disable-model-invocation: true
environment: owned-machine
audience: user
---

The user rewrites or deletes most of what Claude drafts for other people to read before anyone does. Each rewrite says what a skill should have written. Find the changes that recur, turn them into the smallest set of rule changes in the skills that wrote the drafts, and land them, so the next drafts come closer to what the user posts.

## Where to work

The skills live in the agent-config repo. Find it from an installed skill: `git -C "$(dirname "$(realpath ~/.claude/skills/local-review)")" rev-parse --show-toplevel`. Other sessions edit its main checkout, so never edit there.

Work in a worktree of agent-config on a branch of its own. If this session already runs in one, as when it was opened as a side session there, use it. Otherwise make one beside the main checkout:

```sh
git -C <repo> fetch origin
git -C <repo> worktree add -b learn-from-edits-<yyyy-mm-dd> <repo>-learn-from-edits-<yyyy-mm-dd> origin/main
```

Read the repo's `AGENTS.md` before editing. It says how skills are written and checked.

## What drafted what

| Feed | Drafts written by | Rules that govern them |
| --- | --- | --- |
| `panopticon review-edits` | `local-review`, staged by `stage-review` | `skills/local-review/SKILL.md`, `skills/plain-english/SKILL.md` |
| `panopticon reply-edits` | `address-review`, posted by `respond-to-review` | `skills/address-review/SKILL.md`, `skills/respond-to-review/SKILL.md`, `skills/plain-english/SKILL.md` |

Read each of those files as a file, by path in the worktree. Don't load them as skills: loading `local-review` starts a review.

## Steps

1. **Read the feeds.** Save each feed's JSON to a scratch file outside the repo. A review's comments and a turn's replies each carry a `fate`: `kept`, `edited`, `deleted` or `added`, with the `draft` and the `final` body. Only edited, deleted and added ones say anything. A review discarded before submitting keeps no comments. Done when you've read every draft next to its final body.

2. **Find the patterns.** Sort every difference into what the user did to it: cut it to the claim, dropped the fix, rewrote the layout, changed the stance words, deleted a kind of comment outright, corrected a fact. Count each pattern, how many reviews or turns it spans, and how many PRs. Keep two or three short examples of each, draft against final. Review comments and replies are counted apart, since different skills wrote them.

3. **Check each pattern against the rules.** For each, find out which of these it is:
   - the rule exists and the drafts break it: make it more concrete or more prominent, never write it a second time;
   - the drafts follow a rule and the user keeps undoing it: the rule is wrong;
   - no rule covers it: a new rule.

4. **Decide what may change without asking.**
   - Making an existing rule more concrete: when the pattern spans at least 3 PRs.
   - Adding a new rule: when it spans at least 5 PRs.
   - Removing or loosening a rule or a category: when the user undid it in at least 5 PRs.
   - Anything else the evidence points to needs the user's yes: a new rule from a pattern in 3 or 4 PRs, or a change to a skill outside the table above.
   - A pattern in fewer PRs changes nothing. Its edits stay unmarked, so they count again next time.

5. **Edit.** Make the smallest change that covers each pattern you act on, in the style of the file around it. Don't paste examples from the user's PRs, which are private. A short paraphrase is fine. Keep each skill's other rules consistent with the change, as removing a category means removing it from the verdict rules too. Grep the repo for anything else that names what you changed.

6. **Check.** Run what `AGENTS.md` asks before a commit: the validator and every test. Fix what fails, or drop the change that broke it.

7. **Land what needs no yes.** Commit by the [[commit]] skill, one commit per skill changed. Then make the branch track `origin/main` and land it, as `/land` does:

   ```sh
   git branch --set-upstream-to=origin/main
   git land "<one line saying what the drafts learned>"
   ```

   `git land` refuses when the branch is behind. Then `git pull --rebase` and land again, and stop on a conflict, reporting it. The installed skills are links into the main checkout, so bring it up to date with `git -C <repo> pull --ff-only`. If that refuses because of another session's work there, leave it as it is and say so.

8. **Ask about the rest.** Commit each change that needs a yes on its own branch in the worktree, after the landed ones, and open one decision for each with `panopticon ask`. The question names the pattern and its counts. A yes lands it, and a no drops the branch. Its edits stay unmarked until the answer.

9. **Mark learned only what backed a landed change:** each review whose edits a landed change counted, with `panopticon review-edits learned <review>...`, and each turn with `panopticon reply-edits learned <id>...`. Everything else stays listed for the next run.

10. **Notify once, and only if something landed.** Run `panopticon notify --title "Learned from your edits" --message "<the rules changed, in a line>" --open <the PR git land opened>`. Then end with the report: the pattern table (pattern, count, reviews or turns, PRs, one short example), what changed in which file, what needs the user's yes and its decision numbers, what you left alone and why, and `git diff --stat` of what landed. When nothing changed, end with that report and send no notification.
