---
name: dictation-vocab
description: Reviews the word list that the user's local Whisper dictation passes to Whisper, using their logged dictations. Finds words Whisper gets wrong, proves each fix by transcribing the saved audio again, and updates the list once the user approves. Use when the user asks to review or tune their dictation vocabulary, or says dictation keeps getting a word wrong.
environment: owned-machine
audience: user
---

# dictation-vocab

The user's dictation passes a comma-separated word list to Whisper as its initial prompt, which pulls its spelling toward those words. This skill keeps that list matched to how the user actually talks.

## Where things are

`~/.hammerspoon/dictation.lua` is the dictation itself. Read it first: it names every path below and holds the exact `whisper-cli` arguments. Trust it over this file if they disagree.

- The word list: `vocabularyPath`, one line, comma-separated. It may be a link into a repo, so write to the file it points to (`realpath`), never replace the link, and tell the user to commit the change.
- The log: `logPath`, one line per dictation: `recording<TAB>language<TAB>text`.
- The audio: `<recording>.wav` in `recordingsDir`, kept for the last 50 dictations only.
- The models: `models` and `vadModel`.

## Steps

1. **Read the evidence.** Load the word list and the whole log. The usual misses are English terms inside Spanish speech, so read the `es` lines most closely. Done when every log line has been read.
2. **List suspects.** A suspect is a word that reads as a mangled English term or a mangled name of a product, library or project (`finetunint`, `Chagipiti`), or a correct term that keeps coming up and isn't in the list. Also list words in the list that never appear in the log: those may be dropped. When a suspect is unclear, ask the user what they said. Never guess a project name.
3. **Prove each change.** For each suspect with audio, transcribe the clip twice with the arguments from `dictation.lua`: once with the current list, once with the proposed one. A change is proven when the second run spells the term right and nothing else in the clip gets worse. Keep suggestions without audio apart, and say they are unproven.
4. **Propose.** Show a table: term, add or drop, the log lines behind it, and the transcript before and after. Keep the list under about 60 terms. Whisper reads only about 220 tokens of prompt, and rare terms in a long list start showing up where the user never said them.
5. **Apply** only the changes the user approves, by rewriting the word list. Done when it holds exactly the approved list.

The log and the audio are the user's private speech. Read them locally, and quote only the lines you need as evidence.
