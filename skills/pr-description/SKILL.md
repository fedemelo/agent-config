---
name: pr-description
description: "The standard for PR descriptions: succinct, unformatted, at most two short paragraphs covering what was fixed and any non-obvious decisions. Other skills reference it when opening a PR or judging an existing description. Use when writing or reviewing a PR description."
audience: others
---

Write a normal first draft, then load the [[plain-english]] skill and tighten the draft against it and every rule below.

Form:

1. At most two paragraphs: what was fixed, then the reasons behind the non-obvious choices. Include the second only when it earns its place.
2. Each paragraph is two or three simple sentences of one or two lines each, so the longest runs about six lines and most run two or three.
3. Say everything exactly once. Cut every repetition, however important the point, and never restate for emphasis.
4. Plain prose only. No bold, italics, all-caps, bullet lists, headers, or dashes as connectors. Allow a header only in the rare case one is genuinely warranted. Keep Markdown near zero.

First paragraph, what was fixed:

1. When a ticket or issue exists, open with `Fixed: <link>` or `Addressed: <link>`; otherwise start straight in.
2. Then one or two sentences on what was actually fixed, meaning the real change rather than the ticket title or the reported symptom. Not "loading was slow" but "optimized loading in module X by removing the exponential backoff".

Second paragraph, the reasons:

1. Include only choices and trade-offs a reader cannot infer from the diff: why this approach over the alternative, and what it buys. Never what the code already shows.
2. If every change is self-evident from the diff, omit this paragraph entirely. Never narrate the diff ("removed comments", "simplified loop").
