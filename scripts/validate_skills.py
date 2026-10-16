#!/usr/bin/env python3
"""Validate skill packaging: cross-runtime invocation policy, manifests, and prompt coverage."""

import argparse
import ast
import json
import re
import sys
from pathlib import Path


PLUGIN_NAME = "fedemelo"
MARKETPLACE_NAME = "fedemelo-agent-config"

REFERENCE = re.compile(r"\[\[([a-z0-9-]+)\]\]")

PROSE_STANDARD = "plain-english"

# `audience: others` in the frontmatter declares that someone other than the user reads this
# skill's output, so the prose standard governs it. Declared per skill rather than listed here,
# or a skill added later is uncovered until somebody remembers to add it, which is exactly the
# gap this check exists to close. Neither runtime reads the key: Claude ignores what it does not
# know, as Codex already does with disable-model-invocation.
AUDIENCE_KEY = "audience"
AUDIENCE_VALUES = ("user", "others")
AUDIENCE_OTHERS = "others"

# `environment: devspaces` says a skill only works in one kind of environment, so the installers
# link it only there. The default is `any`: a skill that names no environment runs everywhere. The
# point of the key is context rather than tidiness, since every installed skill spends its
# description on every session, and one that cannot run here can never repay it. Neither runtime
# reads it, as with audience and disable-model-invocation.
ENVIRONMENT_KEY = "environment"
ENVIRONMENT_ANY = "any"
ENVIRONMENT_VALUES = (ENVIRONMENT_ANY, "owned-machine", "devspaces")

# The concrete environments, the ones an installer can be running in. `any` describes a skill, not
# a machine, so it is not among them.
ENVIRONMENT_TARGETS = tuple(value for value in ENVIRONMENT_VALUES if value != ENVIRONMENT_ANY)

# The skill holding the detection rule. Referencing it is what makes a skill a router.
ENVIRONMENT_SKILL = "environment"

# A skill that routes reaches its per-environment procedures as `targets/<name>.md`, and its own
# body is the only index of them.
TARGET_REFERENCE = re.compile(r"`targets/([a-z0-9-]+\.md)`")

# Values our YAML never uses. Rejecting them keeps the hand-rolled parser below honest: a file
# reaching for a real YAML feature fails loudly instead of being read as something else.
UNSUPPORTED_VALUES = "[{|>&*!"


class YamlError(Exception):
    pass


def scalar(value, number):
    if value[0] in UNSUPPORTED_VALUES:
        raise YamlError(f"line {number}: unsupported YAML value starting with {value[0]!r}")
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    if value in ("true", "false"):
        return value == "true"
    return value


def parse_simple_yaml(text):
    """Parse the flat or one-level-nested mapping of scalars our YAML is limited to.

    Hand-rolled so the repo and its tests stay dependency-free. Duplicate keys raise, which
    PyYAML would silently accept by keeping the last one.
    """
    root = {}
    section = None
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())
        if indent not in (0, 2):
            raise YamlError(f"line {number}: indented {indent}, expected 0 or 2")
        if ":" not in line:
            raise YamlError(f"line {number}: expected 'key: value'")

        key, _, value = line.strip().partition(":")
        key, value = key.strip(), value.strip()
        if not key:
            raise YamlError(f"line {number}: empty key")

        target = root if indent == 0 else section
        if target is None:
            raise YamlError(f"line {number}: indented under no section")
        if key in target:
            raise YamlError(f"line {number}: duplicate key {key!r}")

        if not value:
            if indent != 0:
                raise YamlError(f"line {number}: sections nested more than one level are not supported")
            section = target[key] = {}
            continue

        target[key] = scalar(value, number)
        if indent == 0:
            section = None
    return root


def parse_frontmatter(text):
    if not text.startswith("---\n"):
        raise YamlError("must open with YAML frontmatter")
    end = text.find("\n---", 4)
    if end < 0:
        raise YamlError("frontmatter is never closed")
    return parse_simple_yaml(text[4:end])


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate key {key!r}")
        result[key] = value
    return result


def load_json(path, label, errors):
    if not path.is_file():
        errors.append(f"{label}: required file is missing")
        return None
    try:
        value = json.loads(path.read_text(), object_pairs_hook=reject_duplicate_keys)
    except (json.JSONDecodeError, ValueError) as error:
        errors.append(f"{label}: invalid JSON ({error})")
        return None
    if not isinstance(value, dict):
        errors.append(f"{label}: must hold a JSON object")
        return None
    return value


def read_allowlist(path):
    if not path.is_file():
        return set()
    lines = (line.strip() for line in path.read_text().splitlines())
    return {line for line in lines if line and not line.startswith("#")}


def renderable_skills(path, errors):
    """The skills copy_prompt.py can title, read out of its INCLUDED and NAMED_ONLY tables.

    A skill missing from both makes `make <skill>` exit with an error, which nothing else
    catches until someone runs it.
    """
    if not path.is_file():
        errors.append("copy_prompt.py: required file is missing")
        return None

    tables = {}
    for node in ast.parse(path.read_text()).body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and target.id in ("INCLUDED", "NAMED_ONLY"):
            try:
                tables[target.id] = ast.literal_eval(node.value)
            except ValueError:
                errors.append(f"copy_prompt.py: {target.id} is not a literal table")
                return None

    missing = {"INCLUDED", "NAMED_ONLY"} - tables.keys()
    if missing:
        errors.append(f"copy_prompt.py: no {' or '.join(sorted(missing))} table")
        return None
    return set(tables["INCLUDED"]) | set(tables["NAMED_ONLY"])


def check_no_commands(root, errors):
    commands = root / "commands"
    if commands.is_dir() and any(commands.rglob("*")):
        errors.append("commands/ is reserved: a workflow belongs in skills/, not in a custom command")


def check_hook_registration(root, errors):
    """Every hook this repo installs has to be registered in the settings it merges.

    install.sh links all of hooks/*.py, and checks the other direction only: that a hook named in
    settings.json exists on disk. This is the gap that leaves. A hook added to the directory and
    never named here is linked, never registered, and silently never runs, which looks exactly like
    a hook that ran and declined to block. A module starting with _ is imported by the hooks rather
    than run as one, so it is not registered anywhere.
    """
    hooks_dir = root / "hooks"
    if not hooks_dir.is_dir():
        errors.append("hooks/ is required")
        return

    settings = load_json(root / "settings.json.example", "settings.json.example", errors)
    if settings is None:
        return

    events = settings.get("hooks")
    commands = ""
    if isinstance(events, dict):
        for groups in events.values():
            for group in groups if isinstance(groups, list) else []:
                for hook in group.get("hooks", []) if isinstance(group, dict) else []:
                    if isinstance(hook, dict):
                        commands += str(hook.get("command", "")) + "\n"

    for script in sorted(p.name for p in hooks_dir.glob("*.py") if not p.name.startswith("_")):
        if script not in commands:
            errors.append(
                f"settings.json.example: never registers hooks/{script}, so the installer links it "
                f"and nothing ever runs it"
            )


def check_marketplace(manifest, label, expected_source, errors):
    if manifest.get("name") != MARKETPLACE_NAME:
        errors.append(f"{label}: name must be {MARKETPLACE_NAME!r}")

    plugins = manifest.get("plugins")
    entry = None
    if isinstance(plugins, list):
        entry = next((p for p in plugins if isinstance(p, dict) and p.get("name") == PLUGIN_NAME), None)

    if entry is None:
        errors.append(f"{label}: must list the {PLUGIN_NAME!r} plugin")
    elif entry.get("source") != expected_source:
        errors.append(f"{label}: {PLUGIN_NAME!r} must be sourced from {expected_source!r}")


def check_manifests(root, errors):
    claude = load_json(root / ".claude-plugin" / "plugin.json", ".claude-plugin/plugin.json", errors)
    if claude is not None and claude.get("name") != PLUGIN_NAME:
        errors.append(f".claude-plugin/plugin.json: name must be {PLUGIN_NAME!r}")

    codex = load_json(root / ".codex-plugin" / "plugin.json", ".codex-plugin/plugin.json", errors)
    if codex is not None:
        if codex.get("name") != PLUGIN_NAME:
            errors.append(f".codex-plugin/plugin.json: name must be {PLUGIN_NAME!r}")
        if codex.get("skills") != "./skills/":
            errors.append(".codex-plugin/plugin.json: skills must be './skills/'")

    label = ".claude-plugin/marketplace.json"
    manifest = load_json(root / ".claude-plugin" / "marketplace.json", label, errors)
    if manifest is not None:
        check_marketplace(manifest, label, ".", errors)

    label = ".agents/plugins/marketplace.json"
    manifest = load_json(root / ".agents" / "plugins" / "marketplace.json", label, errors)
    if manifest is not None:
        check_marketplace(manifest, label, {"source": "local", "path": "."}, errors)


def check_policy(path, name, should_be_explicit, frontmatter, errors):
    """Claude and Codex must reach the same answer, and it must be the one the allowlist states."""
    claude_explicit = frontmatter.get("disable-model-invocation", False)
    if not isinstance(claude_explicit, bool):
        errors.append(f"{name}: disable-model-invocation must be true or false")
        return

    policy_path = path / "agents" / "openai.yaml"
    if not policy_path.is_file():
        errors.append(f"{name}: agents/openai.yaml is required, or Codex ignores the policy entirely")
        return
    try:
        policy = parse_simple_yaml(policy_path.read_text())
    except YamlError as error:
        errors.append(f"{name}: agents/openai.yaml {error}")
        return

    interface = policy.get("interface")
    if not isinstance(interface, dict):
        errors.append(f"{name}: agents/openai.yaml needs an interface section")
    else:
        for field in ("display_name", "short_description"):
            value = interface.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{name}: agents/openai.yaml needs a non-empty interface.{field}")

    section = policy.get("policy")
    allow_implicit = section.get("allow_implicit_invocation") if isinstance(section, dict) else None
    if not isinstance(allow_implicit, bool):
        errors.append(f"{name}: agents/openai.yaml needs policy.allow_implicit_invocation, true or false")
        return

    codex_explicit = not allow_implicit
    if claude_explicit != codex_explicit:
        errors.append(
            f"{name}: the runtimes disagree, explicit-only is {claude_explicit} for Claude "
            f"and {codex_explicit} for Codex"
        )
    elif claude_explicit != should_be_explicit:
        listing = "listed in" if should_be_explicit else "absent from"
        errors.append(f"{name}: explicit-only is {claude_explicit} but the skill is {listing} explicit-only-skills.txt")


def check_skill(path, name, skills, explicit, renderable, audiences, environments, errors):
    text = (path / "SKILL.md").read_text()
    try:
        frontmatter = parse_frontmatter(text)
    except YamlError as error:
        errors.append(f"{name}: SKILL.md {error}")
        return

    if frontmatter.get("name") != name:
        errors.append(f"{name}: frontmatter name must match the directory")

    description = frontmatter.get("description")
    if not isinstance(description, str) or not description.strip():
        errors.append(f"{name}: frontmatter needs a non-empty description")

    for reference in dict.fromkeys(REFERENCE.findall(text)):
        if reference not in skills:
            errors.append(f"{name}: [[{reference}]] does not name a skill")

    if renderable is not None and name not in renderable:
        errors.append(f"{name}: copy_prompt.py has no title for it, add one to INCLUDED or NAMED_ONLY")

    # A misspelled value would read as "not others" and quietly drop the prose check, so the
    # key is held to the two words it can be rather than tested for one of them.
    audience = frontmatter.get(AUDIENCE_KEY)
    if audience is not None:
        if audience in AUDIENCE_VALUES:
            audiences[name] = audience
        else:
            errors.append(f"{name}: {AUDIENCE_KEY} must be one of {', '.join(AUDIENCE_VALUES)}, not {audience!r}")

    # Recorded for every skill, declared or not, so the reference check below can compare any two
    # of them without caring which bothered to name an environment.
    environment = frontmatter.get(ENVIRONMENT_KEY, ENVIRONMENT_ANY)
    if environment in ENVIRONMENT_VALUES:
        environments[name] = environment
    else:
        environments[name] = ENVIRONMENT_ANY
        errors.append(f"{name}: {ENVIRONMENT_KEY} must be one of {', '.join(ENVIRONMENT_VALUES)}, not {environment!r}")

    check_targets(path, name, text, errors)
    check_router_scope(path, name, environments[name], text, errors)
    check_policy(path, name, name in explicit, frontmatter, errors)


def check_targets(path, name, text, errors):
    """A routing skill and its targets/ directory have to agree on which files exist.

    The body is the only index: nothing else lists them, so a target renamed on disk leaves the
    skill routing to a path that is not there, and one the body stopped naming is read by nobody.
    Both fail silently, in the environment nobody tested.
    """
    directory = path / "targets"
    named = set(TARGET_REFERENCE.findall(text))
    present = {file.name for file in directory.glob("*.md")} if directory.is_dir() else set()

    for missing in sorted(named - present):
        errors.append(f"{name}: routes to targets/{missing}, which does not exist")
    for unused in sorted(present - named):
        errors.append(f"{name}: targets/{unused} exists but the skill never routes to it")


def check_router_scope(path, name, scope, text, errors):
    """A skill that routes on the environment has to be installed in all of them.

    Two ways to get this wrong, and neither announces itself. Referencing [[environment]] says the
    skill does not yet know where it is, which only a skill installed everywhere can ask; scoped,
    it is missing from exactly the environment it was meant to identify, and nothing is left to
    read the routing table and say so. Carrying a target named for another environment is the same
    mistake at file level: that file is then unreachable, and a skill with a target per environment
    is a router, so the scope is what is wrong rather than the target.
    """
    if scope == ENVIRONMENT_ANY:
        return

    if ENVIRONMENT_SKILL in REFERENCE.findall(text):
        errors.append(
            f"{name}: is {ENVIRONMENT_KEY}: {scope} but references [[{ENVIRONMENT_SKILL}]], so it "
            f"routes on an environment it is not installed in"
        )

    for file in sorted((path / "targets").glob("*.md")):
        if file.stem in ENVIRONMENT_TARGETS and file.stem != scope:
            errors.append(
                f"{name}: is {ENVIRONMENT_KEY}: {scope} but carries targets/{file.name}, which only "
                f"the {file.stem} environment reads"
            )


def check_environment_references(skills_root, environments, errors):
    """A skill may only reference one that is installed wherever it is.

    An installer leaves out the skills scoped to another environment, so the file behind the
    reference is simply absent there. Nothing expands a reference at runtime, and a missing one
    does not announce itself: the model reads a rule it cannot load and carries on without it.
    """
    for name, scope in sorted(environments.items()):
        for reference in sorted(references_of(skills_root, name)):
            target = environments.get(reference, ENVIRONMENT_ANY)
            if target in (ENVIRONMENT_ANY, scope):
                continue
            errors.append(
                f"{name} ({ENVIRONMENT_KEY}: {scope}) references [[{reference}]] "
                f"({ENVIRONMENT_KEY}: {target}), which is not installed there"
            )


def references_of(skills_root, name):
    path = skills_root / name / "SKILL.md"
    if not path.is_file():
        return set()
    return set(REFERENCE.findall(path.read_text()))


def reaches_standard(skills_root, name, standard):
    """Whether the skill names the standard, or names a skill that names it.

    One hop, not the whole graph. open-pr writes its description by following pr-description,
    which is where the standard is named, so requiring the reference in both places would be
    duplication the DRY rule forbids. Following the graph any further makes the check useless:
    address-review reaches plain-english through commit -> land -> open-pr -> pr-description,
    a chain about committing that never puts the standard in front of the model addressing a
    review, so an unbounded walk reports a skill as covered while the prose goes unguided.
    """
    references = references_of(skills_root, name)
    if standard in references:
        return True
    return any(standard in references_of(skills_root, reference) for reference in references)


def check_prose_standard(skills_root, skills, audiences, errors):
    if PROSE_STANDARD not in skills:
        errors.append(f"{PROSE_STANDARD} is required: skills reference it as the prose standard")
        return

    for name, audience in sorted(audiences.items()):
        if audience != AUDIENCE_OTHERS or reaches_standard(skills_root, name, PROSE_STANDARD):
            continue
        errors.append(
            f"{name}: declares {AUDIENCE_KEY}: {AUDIENCE_OTHERS} but never reaches "
            f"[[{PROSE_STANDARD}]], so the standard is never loaded"
        )


def check_skills(root, errors):
    skills_root = root / "skills"
    if not skills_root.is_dir():
        errors.append("skills/ is required")
        return

    directories = sorted(p for p in skills_root.iterdir() if p.is_dir() and not p.name.startswith("."))
    skills = {p.name for p in directories if (p / "SKILL.md").is_file()}
    for path in directories:
        if path.name not in skills:
            errors.append(f"{path.name}: skill directory has no SKILL.md")

    explicit = read_allowlist(root / "explicit-only-skills.txt")
    for name in sorted(explicit - skills):
        errors.append(f"explicit-only-skills.txt: names {name!r}, which is not a skill")

    renderable = renderable_skills(root / "copy_prompt.py", errors)
    audiences, environments = {}, {}
    for name in sorted(skills):
        check_skill(skills_root / name, name, skills, explicit, renderable, audiences, environments, errors)

    check_prose_standard(skills_root, skills, audiences, errors)
    check_environment_references(skills_root, environments, errors)


def validate(root):
    errors = []
    check_no_commands(root, errors)
    check_hook_registration(root, errors)
    check_manifests(root, errors)
    check_skills(root, errors)
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    errors = validate(parser.parse_args().root.resolve())

    if errors:
        print("Skill validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Skill validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
