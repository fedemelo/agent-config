#!/usr/bin/env bash
# Tests copy_prompt.py, which renders a skill's prompt plus the standards it has to obey, and the
# Makefile targets that copy it. Rendering cases run with --stdout and the clipboard cases run
# against a PATH holding stubs, so the real clipboard is never written to.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool="$repo_root/copy_prompt.py"

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

pass=0; fail=0

check() {
  if [ "$2" = "$3" ]; then printf '  PASS %s\n' "$1"; pass=$((pass+1))
  else printf '  FAIL %s\n       got:  %s\n       want: %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi
}

render() { python3 "$tool" "$1" --stdout; }

titles() { render "$1" | grep -E '^[A-Z][A-Z ]+$'; }

note() { render "$1" | sed -n '/^REFERENCED DOCUMENTS NOT INCLUDED$/,$p'; }

skill_dirs() { (cd "$repo_root/skills" && printf '%s\n' */ | sed 's:/$::' | sort); }

echo "=== a skill renders as titled blocks, followed by the standards it obeys ==="
check "the titles are the skill and the three documents it obeys, in order of mention" \
  "$(titles local-review | tr '\n' '|')" \
  "LOCAL REVIEW GUIDELINES|PLAIN ENGLISH STANDARD|PR TARGET RULES|COMMENT HYGIENE STANDARD|"
check "each block is fenced with triple quotes" "$(render local-review | grep -c '^"""$')" "8"
check "a title is followed by a blank line" \
  "$(render local-review | grep -A1 '^LOCAL REVIEW GUIDELINES$' | tail -1)" ""
check "a skill referencing nothing renders alone" \
  "$(titles plain-english | tr '\n' '|')" "PLAIN ENGLISH STANDARD|"

echo "=== the metadata is dropped and the content is not ==="
check "no frontmatter fence" "$(render local-review | grep -c '^---$')" "0"
check "no name field" "$(render local-review | grep -c '^name: local-review$')" "0"
check "no description field" "$(render local-review | grep -c '^description:')" "0"
check "no disallowed-tools field" "$(render local-review | grep -c '^disallowed-tools:')" "0"
check "the first line of the prompt survives" \
  "$(render local-review | sed -n 4p)" "Act as an expert staff engineer reviewing a pull request."
check "the references stay written as they are in the skill" \
  "$(render local-review | grep -c '\[\[comment-hygiene\]\]')" "1"

echo "=== what the prompt cannot run without travels with it, all the way down and once each ==="
check "a standard's own standards come too" "$(titles open-pr | tr '\n' '|')" \
  "OPEN PR GUIDELINES|PR DESCRIPTION STANDARD|PLAIN ENGLISH STANDARD|REFERENCED DOCUMENTS NOT INCLUDED|"
check "a standard reached twice is rendered once" \
  "$(titles address-review | grep -c 'PLAIN ENGLISH STANDARD')" "1"
check "a cycle between standards terminates" \
  "$(titles pr-description | tr '\n' '|')" "PR DESCRIPTION STANDARD|PLAIN ENGLISH STANDARD|"
check "a skill the prompt runs on travels too, not just standards" \
  "$(titles daily-update | tr '\n' '|')" \
  "DAILY UPDATE GUIDELINES|WORK SUMMARY GUIDELINES|PLAIN ENGLISH STANDARD|"
check "nothing is left out of a bundle that includes every reference" \
  "$(titles daily-update | grep -c 'NOT INCLUDED')" "0"

echo "=== a procedure followed as its own step is named, not pasted ==="
check "address-review does not drag the commit chain in" \
  "$(titles address-review | tr '\n' '|')" \
  "ADDRESS REVIEW GUIDELINES|PLAIN ENGLISH STANDARD|PR TARGET RULES|COMMENT HYGIENE STANDARD|REFERENCED DOCUMENTS NOT INCLUDED|"
check "a skill whose only reference is guidelines renders alone" \
  "$(titles todo | tr '\n' '|')" "TODO GUIDELINES|REFERENCED DOCUMENTS NOT INCLUDED|"
check "nothing left out means no note" "$(titles local-review | grep -c 'NOT INCLUDED')" "0"

echo "=== the note explains the reference it left out ==="
check "it names the reference as the prompt writes it" "$(note todo | grep -c '\[\[land\]\]')" "1"
check "it gives the title the document would have had" "$(note todo | grep -c 'LAND GUIDELINES')" "1"
check "it says the omission was deliberate" "$(note todo | grep -c 'left out on purpose')" "1"
check "it says to ask the user" "$(note todo | grep -c 'ask the user to provide it')" "1"
check "it forbids guessing" "$(note todo | grep -c 'Do not guess')" "1"
check "it reads as singular for one omission" "$(note todo | grep -c 'That document was')" "1"
check "it reads as plural for several" "$(note land | grep -c 'Those documents were')" "1"
check "it names the first omission" "$(note land | grep -c '\[\[open-pr\]\]')" "1"
check "it names the second omission" "$(note land | grep -c '\[\[commit\]\]')" "1"
check "it is fenced like any other block" "$(note todo | grep -c '^"""$')" "1"

echo "=== every skill is renderable and reachable ==="
for skill in $(skill_dirs); do
  check "$skill renders" "$(render "$skill" >/dev/null 2>&1; echo $?)" "0"
done
check "make list names every skill" \
  "$(cd "$repo_root" && make list | sort | tr '\n' ' ')" "$(skill_dirs | tr '\n' ' ')"
check "no title is left behind for a skill that is gone" \
  "$(cd "$repo_root" && python3 -B -c 'import copy_prompt as c; print(" ".join(sorted(set(c.TITLES) - set(c.available()))))')" ""
check "no skill is both included and named-only" \
  "$(cd "$repo_root" && python3 -B -c 'import copy_prompt as c; print(" ".join(sorted(set(c.INCLUDED) & set(c.NAMED_ONLY))))')" ""

echo "=== a name that is not a skill fails loudly ==="
check "an unknown skill exits non-zero" "$(render nope >/dev/null 2>&1; echo $?)" "1"
check "the error lists the skills" "$(render nope 2>&1 >/dev/null | grep -c 'local-review')" "1"
check "no skill argument exits non-zero" \
  "$(python3 "$tool" --stdout >/dev/null 2>&1; echo $?)" "1"

echo "=== without --stdout the prompt goes to a clipboard tool ==="
# Only the stub directory is on PATH, so the tool a case provides is the only one found and the
# machine's own pbcopy is out of reach. python3 is called by path for the same reason.
python3_bin="$(command -v python3)"
mkdir -p "$ROOT/working" "$ROOT/none" "$ROOT/broken"
printf '#!/bin/sh\n/bin/cat > "%s/clipboard"\n' "$ROOT" > "$ROOT/working/xclip"
printf '#!/bin/sh\necho "Error: Can'"'"'t open display" >&2\nexit 1\n' > "$ROOT/broken/xclip"
chmod +x "$ROOT/working/xclip" "$ROOT/broken/xclip"

copy() { PATH="$ROOT/$1" "$python3_bin" "$tool" local-review 2>"$ROOT/stderr"; }
reported() { cat "$ROOT/stderr"; }

out="$(copy working)"; code=$?
check "it exits zero" "$code" "0"
check "the rendered prompt is what the tool was handed" \
  "$(head -2 "$ROOT/clipboard" | tr '\n' '|')" '"""|LOCAL REVIEW GUIDELINES|'
check "the prompt is not printed as well" "$(echo "$out" | grep -c 'LOCAL REVIEW GUIDELINES')" "0"
check "it reports what it copied" "$(echo "$out" | grep -c '^Copied to clipboard: local-review,')" "1"

echo "=== with no clipboard tool it prints the prompt instead of failing ==="
out="$(copy none)"; code=$?
check "it still exits zero" "$code" "0"
check "the prompt is on stdout" "$(echo "$out" | grep -c '^LOCAL REVIEW GUIDELINES$')" "1"
check "the reason names the tools it looked for" "$(reported | grep -c 'pbcopy, wl-copy, xclip, xsel')" "1"
check "it still says what the bundle holds" "$(reported | grep -c '^Included: local-review,')" "1"
check "the notes stay off stdout, so a pipe gets the prompt alone" \
  "$(echo "$out" | grep -c 'Included:')" "0"
check "no traceback" "$(reported | grep -c Traceback)" "0"

echo "=== a clipboard tool that fails is reported, not raised ==="
out="$(copy broken)"; code=$?
check "it exits zero" "$code" "0"
check "the prompt is on stdout" "$(echo "$out" | grep -c '^LOCAL REVIEW GUIDELINES$')" "1"
check "the tool's own error is passed on" "$(reported | grep -c "Can't open display")" "1"
check "no traceback" "$(reported | grep -c Traceback)" "0"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
