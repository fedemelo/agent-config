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
from pathlib import Path


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
    """Whether the caller's transcript shows `skill` was loaded, under any plugin namespace.

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
    """The transcript of whoever made the tool call, the session itself or one of its subagents.

    A subagent's payload still carries the session's `transcript_path`, but the subagent's own
    calls are recorded beside it, in `<session>/subagents/agent-<agent_id>.jsonl`. Only what the
    subagent saw counts: a skill the session loaded was never put in front of an ordinary
    subagent. A fork is the exception, as it starts from the session's history, which its file
    names in a leading `fork-context-ref` line instead of copying.
    """
    session_path = payload.get("transcript_path")
    agent_id = payload.get("agent_id")
    if not session_path or not agent_id:
        return _read(session_path)
    own = _read(Path(session_path).with_suffix("") / "subagents" / f"agent-{agent_id}.jsonl")
    return _inherited_history(own, session_path) + own


def _inherited_history(subagent_transcript, session_path):
    ref = _json_or_none(subagent_transcript.partition("\n")[0])
    if not isinstance(ref, dict) or ref.get("type") != "fork-context-ref":
        return ""
    return _lines_through(_read(session_path), ref.get("parentLastUuid"))


def _lines_through(transcript, uuid):
    """The lines of `transcript` up to and including the entry `uuid`, or none if it is absent."""
    kept = []
    for line in transcript.splitlines(keepends=True):
        kept.append(line)
        entry = _json_or_none(line)
        if isinstance(entry, dict) and entry.get("uuid") == uuid:
            return "".join(kept)
    return ""


def _json_or_none(text):
    try:
        return json.loads(text)
    except ValueError:
        return None


def _read(path):
    if not path:
        return ""
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""
