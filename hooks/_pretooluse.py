"""The plumbing every `PreToolUse` hook here shares: read the payload, answer the harness.

Imported, never run, so it carries no shebang and is not executable. A hook imports it as a
sibling module, which resolves because Python sets `sys.path[0]` to the directory the script
really lives in rather than the one it was invoked through. So this file has to travel with the
hooks and land beside them, however they got there: linked from this repo, or copied somewhere
wholesale. Install a hook without it and the hook dies on import.
"""

import json
import re
import sys


def guard_bash(veto):
    """Let `veto` decide whether to block the Bash command in the payload on stdin.

    `veto(command, payload)` returns the reason to block, or None to stay out of the way. Both
    are reported the way the harness expects: a reason as a deny decision plus a message the
    user sees, and None as an empty object, which leaves the command to the normal permission
    rules rather than approving it.

    Anything that is not a Bash call, and any payload that will not parse, is left alone. A hook
    that cannot read its own input must not be the reason a command fails.
    """
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        payload = {}

    reason = None
    if isinstance(payload, dict) and payload.get("tool_name") == "Bash":
        tool_input = payload.get("tool_input")
        command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
        reason = veto(command, payload)

    print(json.dumps(_decision(reason) if reason else {}))
    sys.exit(0)


def _decision(reason):
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        },
        "systemMessage": reason,
    }


def skill_invoked(skill, payload):
    """Whether this session's transcript shows `skill` was loaded, under any plugin namespace.

    The two ways a skill gets loaded leave different traces. Claude invoking it leaves a Skill
    tool call; the user typing /<skill> leaves none, since the CLI expands the skill itself and
    only records the command name. A transcript that cannot be read holds no evidence.
    """
    name = r"(?:[\w-]+:)?" + re.escape(skill)
    invoked = re.compile(
        r'"name"\s*:\s*"Skill".{0,200}?"skill"\s*:\s*"' + name + r'"'
        r"|<command-name>/" + name + r"</command-name>"
    )
    return bool(invoked.search(_transcript_of(payload)))


def _transcript_of(payload):
    path = payload.get("transcript_path")
    if not path:
        return ""
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""
