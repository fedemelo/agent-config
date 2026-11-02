---
name: commit
description: "Commits staged or pending changes following personal conventions: modular commits, terse single-line messages, no AI attribution. Use when asked to commit."
---

When told to commit, do not change the code; only commit what is already there.

Commit only what belongs in the project. Never commit environment files or secrets. Never commit a file written to plan or track the work (usually .md or .plan), design notes, or scratch files, even if a later agent might find it useful. Changes to documents the project already tracks are committed like code. A document created during this work is committed only if the user asked for that document, such as a README or a skill. When in doubt, leave it out and say so: a missing commit is easy to add later, while a wrong one has to be undone.

Keep commits modular: one commit per separate change, ideally one per file. Group files into a single commit only when committing a file on its own would fail the commit pipeline, linting, or checks that would pass once its dependent files are included.

Never disable linting or any verification to make a commit pass. Never use the `--no-verify` flag.

Give each commit a single message: one succinct sentence that starts with an active verb and summarizes the change. No secondary body, no unnecessary adjectives. Prefer "Update AI agent to use new chunking utilities" over "Update AI agent to use new comprehensive chunking utilities".

When one file holds two or more unrelated changes, stage the parts separately with `git add -p` and commit each on its own, when that is possible and all checks still pass. Otherwise commit the whole file and join the sentences with `;`. Write "Add x" and "Implement y" as separate commits when you can, or "Add x; Implement y" in one when you cannot. Never "Add x and implement y".

If this work is headed for more than one pull request, decide the grouping now, because only a contiguous run of commits can be landed as one PR (what the `land` skill does, which you do not need here). Commit each PR's changes together, so no PR's commits are interleaved with another's. This matters most for a file whose changes belong to different PRs: separating them is only possible while staging, so if `git add -p` is unavailable, commit one change, then make the other and commit it. Landing cannot split them afterwards.

Never list yourself or any AI model as author or co-author of a commit. The same holds for pull requests: never add any author, co-author, or contributor attribution in the title or body, and never include a "Generated with [tool]" footer or a "Co-Authored-By" line. The PR body describes only the change.
