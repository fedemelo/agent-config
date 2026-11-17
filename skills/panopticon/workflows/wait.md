# Waiting on a turn

The inbox already reports every finished turn, within a minute. When the user asks to hear when a workspace is done, tell them you'll hear it from the inbox, and wait yourself only when they want the result in this session. In that case, take `agentStatusChangedAt` from `status` right before sending, or right away if nothing is being sent. Then poll `status` every 15 seconds in a background command, until one of these:

- `status` isn't `running`. The workspace stopped, and that is not a finished turn: say so.
- `agentStatusChangedAt` differs from the one you took and `agentStatus` isn't `working`. A turn ended. `idle` can still mean a question or an approval is waiting, so read the workspace before you call it done, and never call it a success without reading it.
- Ten minutes pass. Report that it's still going, and ask whether to keep waiting.

A failed `status` is an error to report, never a sign that the turn ended. When you watch several workspaces, keep a separate baseline for each. Once the background command stops, you are no longer watching, so don't say you are.
