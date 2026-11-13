#!/bin/bash
# Memory per app, largest first, as "MB<TAB>processes<TAB>app".
# MEM from top is the physical footprint Activity Monitor shows; ps's RSS undercounts compressed memory.
# A process inside a .app bundle counts toward the outermost bundle, so helpers add up to their app.
set -euo pipefail

footprints=$(top -l 1 -stats pid,mem | awk 'seen { print $1, $2 } /^PID/ { seen = 1 }' | sort -k1,1)
paths=$(ps -axo pid=,comm= | sed 's/^ *//' | sort -k1,1)

join <(echo "$footprints") <(echo "$paths") | awk '
function megabytes(size,  unit) {
  unit = substr(size, length(size))
  gsub(/[^0-9.]/, "", size)
  if (unit == "G") return size * 1024
  if (unit == "K") return size / 1024
  if (unit == "B") return size / 1048576
  return size
}
{
  mb = megabytes($2)
  $1 = $2 = ""
  path = substr($0, 3)
  if (match(path, /[^\/]+\.app\//)) app = substr(path, RSTART, RLENGTH - 5)
  else { n = split(path, parts, "/"); app = parts[n] }
  total[app] += mb
  count[app]++
}
END { for (app in total) printf "%.0f\t%d\t%s\n", total[app], count[app], app }
' | sort -rn
