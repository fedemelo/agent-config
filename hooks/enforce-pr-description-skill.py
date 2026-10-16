#!/usr/bin/env python3
"""PreToolUse hook: require the `pr-description` skill before writing a PR body.

If the Bash command creates a PR, or edits one's body, checks this session's transcript for
evidence that the `pr-description` skill was already invoked. If not found, blocks the command
and tells the model to invoke the skill first, so PR bodies follow the project's actual
convention instead of the generic Summary/Test-plan template baked into the base PR instructions.
"""

import re

from _pretooluse import guard_bash, skill_invoked


PR_CREATE_RE = re.compile(r"(^|;|&&|\|\||\|)\s*gh\s+pr\s+create(\s|$)")
PR_EDIT_BODY_RE = re.compile(r"(^|;|&&|\|\||\|)\s*gh\s+pr\s+edit\s.*--body(-file)?(\s|=|$)")


def veto(command, payload):
    if not (PR_CREATE_RE.search(command) or PR_EDIT_BODY_RE.search(command)):
        return None
    if skill_invoked("pr-description", payload):
        return None
    return (
        "Blocked: you must invoke the `pr-description` skill before writing a PR body. "
        "Invoke the pr-description skill now, follow its instructions, then retry."
    )


if __name__ == "__main__":
    guard_bash(veto)
