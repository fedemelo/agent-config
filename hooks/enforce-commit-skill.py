#!/usr/bin/env python3
"""PreToolUse hook: require the `commit` skill to be invoked before `git commit`.

If the Bash command being run is a `git commit`, checks this session's transcript for evidence
that the `commit` skill was already invoked. If not found, blocks the command and tells the
model to invoke the skill first.
"""

import re

from _pretooluse import guard_bash, skill_invoked


COMMIT_COMMAND_RE = re.compile(r"(^|;|&&|\|\||\|)\s*git\s+commit(\s|$)")


def veto(command, payload):
    if not COMMIT_COMMAND_RE.search(command):
        return None
    if skill_invoked("commit", payload):
        return None
    return (
        "Blocked: you must invoke the `commit` skill before running `git commit`. "
        "Invoke the commit skill now, follow its instructions, then retry the commit."
    )


if __name__ == "__main__":
    guard_bash(veto)
