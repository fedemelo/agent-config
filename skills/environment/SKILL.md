---
name: environment
description: "The rule for working out which kind of environment a session runs in: an ephemeral devspaces pod, or a machine you own. Other skills reference it so they all detect it the same way, and none of them asks. Use when what a task has to do depends on the kind of environment it runs in."
---

Work out which kind of environment this session is running in. Detect it rather than asking, when the environment answers plainly.

There are two. A skill that branches on them names them as they are named here:

| Environment | What it is |
|---|---|
| `owned-machine` | A host with a persistent home directory that you administer: your laptop, your desktop. |
| `devspaces` | An ephemeral, prompt-seeded devspaces pod. `~` is rebuilt from the pod image on every start, so only the mounted share survives a restart. |

A pod has both `/mnt/personal` and `/etc/claude-code/`. Anything with neither is the other row, which is the one to pick for a cloud or Codex session too: the test is whether this is a pod, so `owned-machine` is every answer except that one.

A `devspaces` executable on `PATH` is not a signal. An owned machine can have the CLI to drive pods from outside, and treating it as one made every laptop with the CLI look half like a pod.

**If the signals disagree, one present and the other not, stop and ask the user which it is.** That is a pod whose image has moved, or a host that resembles one. Do not guess: a skill only branches here when the two paths do different things to the machine, so the wrong answer costs more than the question, which costs one round trip.

This rule answers that one question and no other. A skill that needs a finer distinction, such as which agent CLI is on `PATH` or whether a share is writable, asks that itself once this is settled, and says where it does.
