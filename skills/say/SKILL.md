---
name: say
description: Reads your own immediately preceding response aloud through macOS's `say` command. Use only when explicitly invoked as /say.
disable-model-invocation: true
---

Take the text of your own last response in this conversation, the one you sent right before this invocation, not any earlier one, and read it aloud.

Strip it down to what should actually be spoken before handing it to `say`: drop markdown syntax (`#`, `*`, `` ` ``, link brackets), code blocks, and file paths or raw URLs that would read as noise, but keep the words and sentence structure intact.

Write the cleaned text to a file in the scratchpad directory rather than passing it inline, since long text and quote characters are fragile as a shell argument. Then run `say -v Samantha -f <file>` and wait for it to finish before replying, since the user is listening for it now. Always pass `-v Samantha` explicitly — this machine's system language is set to German, so the bare `say` command without a voice flag speaks with a German accent; pinning an English voice keeps this skill's output in English regardless of that system setting.

If there is no preceding response to read (this is the first turn), say so instead of running `say` on nothing.

Do not summarize, shorten, or rewrite the response before reading it; read what was actually said.
