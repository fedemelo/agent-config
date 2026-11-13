---
name: memory-check
description: Diagnoses what is using this Mac's memory when it runs low, and says which apps to close or restart. Reads only, never closes or kills anything. Use when the user says the computer is slow, out of memory, swapping, or under memory pressure, or asks what is eating their RAM.
environment: owned-machine
audience: user
---

# memory-check

Find what is using this Mac's memory and say what to do about it. **Change nothing**: never quit, kill, or restart anything, even when the fix is obvious. The user acts on the report.

## Gather

Run these together:

- `sysctl -n hw.memsize kern.memorystatus_vm_pressure_level kern.memorystatus_level vm.swapusage`: total RAM in bytes, pressure (1 normal, 2 warning, 4 critical), percent free, and swap in use.
- `vm_stat`: multiply "Pages occupied by compressor" by the page size in its header to get compressed memory.
- `uptime`: days since the last restart.
- `scripts/memory-by-app.sh` in this skill's directory: memory per app, largest first, as MB, process count, and name. Helper processes count toward their app, so Chrome's renderers add up to Chrome.

Then look closer only at what the top of that list makes worth it:

- **Chrome**, if it's near the top: count its tabs with `pgrep -xq "Google Chrome" && osascript -e 'tell application "Google Chrome" to count tabs of windows'`. The `pgrep` guard matters, since the script would otherwise launch Chrome. Safari and Arc work the same way under their own names.
- **A command-line name with many processes** (`claude`, `node`, `python`, `-zsh`): list them with `ps -axo pid,rss,etime,command | grep <name>` to see which are old sessions or forgotten servers, and their working directories with `lsof -a -d cwd -p <pid>` when that tells them apart.
- **Docker, OrbStack, or a VM**: their memory is set aside for the VM and is not freed by closing containers. Say so.

## Judge

Compare each app with what it normally uses. These are the usual culprits:

| Sign | Likely cause | What to suggest |
|---|---|---|
| WindowServer over about 2 GB, or any system process far above normal, with uptime of weeks | A leak that grows until restart | Restart the Mac, or log out and in for WindowServer |
| A browser with many tabs | Each tab is a process | Close tabs, mainly ones with video, maps, or web apps |
| Many `claude`, `node`, or `python` processes, some days old | Agent sessions or dev servers left running | Close the old ones, naming them by directory |
| `mds_stores` or `mdworker` high | Spotlight indexing, usually after a big copy or update | Wait; it settles by itself |
| `kernel_task` high | Often thermal throttling or file cache, not a leak | Usually nothing |
| Low free memory but pressure normal and no swap | macOS keeps memory full of cache on purpose | Nothing is wrong |

Memory pressure, not free memory, says whether there is a problem. Free memory near zero is normal. Swap of several GB, or pressure at warning or critical, is the problem.

## Report

Keep it short. One line on the state, then a table, then at most three bullets.

```
Pressure: warning · 31 GB of 32 GB used · 6.2 GB swap · up 214 days

| App | Memory | Processes |
|---|---|---|
| WindowServer | 8.1 GB | 1 |
| Google Chrome | 5.4 GB | 46 (38 tabs) |
| claude | 3.0 GB | 15 |

- WindowServer normally uses under 1 GB. After 214 days without a restart this is almost certainly a leak: restart the Mac.
- Chrome has 38 tabs open. Closing most of them frees around 4 GB.
```

- Show about eight rows, largest first, in GB above 1 GB. Leave out apps under 200 MB unless they're part of the answer.
- Each bullet names the app, why it's the suspect, and the one action that fixes it. Put the action that frees the most first.
- If pressure is normal and nothing stands out, say so in one line and skip the bullets.
