---
name: say
description: Reads your own immediately preceding response aloud through macOS's `say` command. Use only when explicitly invoked as /say.
disable-model-invocation: true
---

Take the text of your own last response in this conversation, the one you sent right before this invocation, not any earlier one, and read it aloud.

## Choosing the voice

Pick the voice by the language the response is written in:

- Spanish: `-v Paulina`.
- English: `-v Samantha`.
- A response that mixes both: use the voice of the language most of the prose is in. Leave English technical terms inside Spanish prose (for example "Inversion Graph", "stack") as they are, and read them with Paulina.

Always pass `-v` explicitly.

## Turning the text into speech

Strip the response down to what should actually be spoken, keeping the words and sentence structure intact:

- Drop markdown syntax (`#`, `*`, `` ` ``, link brackets) and code blocks.
- Drop raw URLs. In a list of sources, say the name of each source instead.
- Do not read a file path. Say just the file's name in words, for example `proyectos/parte-2/solucion/solucion.tex` becomes "el archivo solucion punto tex".
- Spell out math notation in the language of the response:
  - Θ(n) → "theta de n" / "theta of n"; O(1) → "O de 1" / "O of 1".
  - Subscripts: pₖ → "p sub k".
  - Ranges: p₁..pₖ → "p sub 1 hasta p sub k" / "p sub 1 through p sub k"; 1..n → "1 a n" / "1 to n".
  - Symbols: = → "igual a" / "equals", > → "mayor que" / "greater than", ≤ → "menor o igual que" / "at most".
- Expand abbreviations and markers that read badly: "Round #771" → "Round 771", "Div. 2" → "División 2" / "Division 2", "403" in an error stays as "error 403".
- Numbered list items: read the number as a word ending in a period ("Uno." / "One.") so the pause is clear.
- Parentheses that only hold an aside: turn them into a clause set off with commas or a colon.

These are spoken renderings of what is written, not rewrites. Do not summarize, shorten, or rephrase the response; read what was actually said.

## Running it

Write the cleaned text to a file in the scratchpad directory rather than passing it inline, since long text and quote characters are fragile as a shell argument. Then run `say -v <voice> -f <file>` with a timeout of at least five minutes, and wait for it to finish before replying, since the user is listening for it now.

If there is no preceding response to read (this is the first turn), say so instead of running `say` on nothing.
