---
name: wire-up
description: Wires an environment's Claude and Codex setup up to date, following the procedure for the kind of environment it is run in. Detects whether this is a machine you own or an ephemeral devspaces pod, and follows only that procedure.
disable-model-invocation: true
---

Bring this environment's setup up to date: the skills, the `git` subcommands they drive, and whatever else this kind of environment's own procedure covers. Which parts of a setup are yours to touch is itself one of the things that differs, so that is the target file's business rather than this one's.

**How that is done depends on the environment, and the procedures are not interchangeable.** On a machine you own, the two repos install themselves through symlinks and their own installers. In an ephemeral pod there is no persistent `~`, symlinked skills silently fail to load, and running those installers damages a working setup. Applying the wrong one leaves an environment that looks installed and is not.

So this skill only routes. Work out which environment you are in, read the one file for it, and follow that file alone. Do not blend two procedures, and do not fall back on what you remember about the other.

## Pick the target

Load the [[environment]] skill and work out which environment this is by its rule, then read the one file for it:

| Environment | Procedure |
|---|---|
| `owned-machine` | `targets/owned-machine.md` |
| `devspaces` | `targets/devspaces.md` |

Where that rule says to stop and ask, stop and ask. Guessing wrong here leaves a broken setup on a machine you cannot reset.

Nothing outside the chosen file applies. Read it in full before acting on any part of it, then report as it says.

If you cannot read files here (this skill was pasted as a prompt rather than loaded), say so and ask the user for the target file, naming the one you need. Do not reconstruct the procedure from memory.
