#!/usr/bin/env bash
# Validate church-skills plugin manifests, skill frontmatter, and shell examples.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - "$ROOT_DIR" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
errors = []
warnings = []


def rel(path):
    return str(path.relative_to(root))


def load_json(path: Path):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        errors.append(f"{rel(path)}: missing")
    except json.JSONDecodeError as exc:
        errors.append(f"{rel(path)}: invalid JSON at line {exc.lineno}: {exc.msg}")
    return None


def frontmatter(path):
    lines = path.read_text().splitlines()
    if not lines or lines[0].strip() != "---":
        errors.append(f"{rel(path)}: missing opening YAML frontmatter delimiter")
        return None

    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            key, value = match.groups()
            fields[key] = value.strip().strip("\"'")

    errors.append(f"{rel(path)}: missing closing YAML frontmatter delimiter")
    return None


def require_fields(path, data, fields):
    for field in fields:
        if field not in data:
            errors.append(f"{rel(path)}: missing required field '{field}'")


def validate_marketplaces():
    claude_path = root / ".claude-plugin" / "marketplace.json"
    codex_path = root / ".agents" / "plugins" / "marketplace.json"
    claude = load_json(claude_path)
    codex = load_json(codex_path)

    if claude is not None:
        require_fields(claude_path, claude, ["name", "metadata", "plugins"])
        marketplace_version = claude.get("metadata", {}).get("version")
        for plugin in claude.get("plugins", []):
            name = plugin.get("name")
            source = plugin.get("source")
            version = plugin.get("version")
            if not name or not source:
                errors.append(f"{rel(claude_path)}: plugin entry missing name or source")
                continue
            plugin_dir = root / source
            plugin_json_path = plugin_dir / ".claude-plugin" / "plugin.json"
            if not plugin_dir.is_dir():
                errors.append(f"{rel(claude_path)}: plugin '{name}' source does not exist: {source}")
                continue
            plugin_json = load_json(plugin_json_path)
            if plugin_json is None:
                continue
            if plugin_json.get("name") != name:
                errors.append(f"{rel(plugin_json_path)}: name does not match marketplace entry '{name}'")
            if marketplace_version and version != marketplace_version:
                errors.append(
                    f"{rel(claude_path)}: plugin '{name}' version {version!r} does not match marketplace version {marketplace_version!r}"
                )
            if plugin_json.get("version") != version:
                errors.append(
                    f"{rel(plugin_json_path)}: version {plugin_json.get('version')!r} does not match marketplace entry {version!r}"
                )

    if codex is not None:
        require_fields(codex_path, codex, ["name", "interface", "plugins"])
        for plugin in codex.get("plugins", []):
            name = plugin.get("name")
            source = plugin.get("source", {})
            path_value = source.get("path") if isinstance(source, dict) else None
            if not name or not path_value:
                errors.append(f"{rel(codex_path)}: Codex plugin entry missing name or source.path")
                continue
            plugin_dir = root / path_value
            plugin_json_path = plugin_dir / ".codex-plugin" / "plugin.json"
            if not plugin_dir.is_dir():
                errors.append(f"{rel(codex_path)}: plugin '{name}' source.path does not exist: {path_value}")
                continue
            plugin_json = load_json(plugin_json_path)
            if plugin_json is None:
                continue
            if plugin_json.get("name") != name:
                errors.append(f"{rel(plugin_json_path)}: name does not match Codex marketplace entry '{name}'")
            if "interface" not in plugin_json:
                errors.append(f"{rel(plugin_json_path)}: missing interface metadata for Codex plugin display")
            skills_path = plugin_json.get("skills")
            if skills_path and not (plugin_dir / skills_path).is_dir():
                errors.append(f"{rel(plugin_json_path)}: skills path does not exist: {skills_path}")

            claude_plugin_json_path = plugin_dir / ".claude-plugin" / "plugin.json"
            claude_plugin_json = load_json(claude_plugin_json_path)
            if claude_plugin_json and claude_plugin_json.get("version") != plugin_json.get("version"):
                errors.append(
                    f"{rel(plugin_json_path)}: version {plugin_json.get('version')!r} does not match {rel(claude_plugin_json_path)}"
                )


def validate_skill_file(path, require_allowed_tools):
    fields = frontmatter(path)
    if fields is None:
        return

    skill_name = path.parent.name
    if fields.get("name") != skill_name:
        errors.append(f"{rel(path)}: frontmatter name {fields.get('name')!r} does not match directory '{skill_name}'")
    if not fields.get("description"):
        errors.append(f"{rel(path)}: missing description")
    if require_allowed_tools and "allowed-tools" not in fields:
        errors.append(f"{rel(path)}: missing allowed-tools for plugin skill")

    line_count = len(path.read_text().splitlines())
    if line_count > 300 and "<!-- cache:start -->" not in path.read_text():
        warnings.append(f"{rel(path)}: {line_count} lines; consider splitting or marking static reference content for caching")


# Plugin skills are shared by multiple agent surfaces (Claude Code, Codex CLI).
# A skill body must describe the required outcome and let the active surface bind it
# to a native capability — never name a tool from one specific surface. The frontmatter
# `allowed-tools` field is exempt: it is a declaration to the surface, not an
# instruction to the model. Skills under claude-ai-skills/ are exempt entirely, since
# that tree is deliberately bound to Claude.ai web tooling.

# Names with no plain-English meaning are flagged wherever they appear. The rule is
# symmetric — binding a shared skill to Codex is exactly as broken as binding it to
# Claude Code — so every surface's identifiers belong here.
#
# This is a denylist, and a denylist of tool names is inherently incomplete: surfaces add
# tools, and no list here can know tomorrow's. It catches what authors actually reach for,
# which is worth having, but it is a net rather than a proof. Add names as they appear —
# and do not let a green run stand in for a human noticing that a body names a tool.
SURFACE_BOUND_NAMES = {
    "Claude Code": ["AskUserQuestion", "NotebookEdit", "TodoWrite", "WebFetch", "WebSearch"],
    "Claude.ai web": ["ask_user_input_v0", "present_files"],
    "Codex": [
        "apply_patch",
        "exec_command",
        "view_image",
        "update_plan",
        "request_user_input",
    ],
}
SURFACE_BOUND_ALWAYS = (
    r"\b(" + "|".join(n for names in SURFACE_BOUND_NAMES.values() for n in names) + r")\b"
)

# Names that are also ordinary words ("read the file", "write it out") are only flagged
# where the text is clearly naming a tool, not using the verb. Two such forms:
# inline code (`Read`) and an explicit "Read tool" / "Write tools" phrasing.
GENERIC_TOOL_NAMES = r"Read|Write|Edit|Bash|Glob|Grep|Task|WebFetch|WebSearch|AskUserQuestion|NotebookEdit|TodoWrite"
SURFACE_BOUND_IN_CODE = rf"`({GENERIC_TOOL_NAMES})`"
SURFACE_BOUND_AS_TOOL = rf"\b({GENERIC_TOOL_NAMES})`?\s+tools?\b"


# Whether a skill states a fallback is a judgment about prose, not something a regex can
# decide — a check satisfied by typing the word "fallback" would only manufacture false
# confidence. So this is a WARNING, and the docs claim enforcement only for tool names.
CAPABILITY_REFERENCE = r"(?i)\bnative\b[^.\n]{0,60}\bcapabilit(?:y|ies)\b"
FALLBACK_LANGUAGE = r"(?i)\b(?:cannot|can't|unable|lacks?|does not|doesn't|without|fallback|instead|degrade)\b"


def warn_missing_fallback(path):
    """Flag a capability reference whose section never says what to do without it."""
    lines = path.read_text().splitlines()

    # Group lines into markdown sections; a fallback usually sits a few lines below the
    # capability reference but inside the same section.
    sections = []
    current = []
    for idx, line in enumerate(lines, start=1):
        if line.startswith("#") and current:
            sections.append(current)
            current = []
        current.append((idx, line))
    if current:
        sections.append(current)

    for section in sections:
        hit = next(
            (idx for idx, line in section if re.search(CAPABILITY_REFERENCE, line)), None
        )
        if hit is None:
            continue
        if not any(re.search(FALLBACK_LANGUAGE, line) for _, line in section):
            warnings.append(
                f"{rel(path)}:{hit}: names a native capability but the section never says what to "
                "do when it is unavailable; confirm the skill degrades instead of stalling"
            )


def validate_surface_agnostic(path):
    text = path.read_text()
    lines = text.splitlines()

    # Drop frontmatter so `allowed-tools` does not trip the scan.
    body_start = 0
    if lines and lines[0].strip() == "---":
        for idx, line in enumerate(lines[1:], start=2):
            if line.strip() == "---":
                body_start = idx
                break

    for offset, line in enumerate(lines[body_start:], start=body_start + 1):
        # Markdown styling must not be an escape hatch: `Read`, **Read**, _Read_ and
        # [Read](url) all name the same tool. Match the inline-code form against the raw
        # line (its backticks are the signal), and everything else against a copy with
        # link syntax and emphasis markers stripped.
        plain = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", line)
        plain = re.sub(r"[*`]+", "", plain)
        # Strip underscores only where they delimit emphasis (_Read_), never inside an
        # identifier — collapsing apply_patch to applypatch would hide the very names
        # below, snake_case being how both Codex and Claude.ai web tools are spelled.
        plain = re.sub(r"(?<![A-Za-z0-9])_+|_+(?![A-Za-z0-9])", "", plain)

        for pattern, subject in (
            (SURFACE_BOUND_ALWAYS, plain),
            (SURFACE_BOUND_IN_CODE, line),
            (SURFACE_BOUND_AS_TOOL, plain),
        ):
            match = re.search(pattern, subject)
            if match:
                errors.append(
                    f"{rel(path)}:{offset}: names surface-specific tool {match.group(1)!r}; "
                    "describe the outcome and let the active surface bind a native capability"
                )
                break
        if "/mnt/user-data" in line:
            errors.append(
                f"{rel(path)}:{offset}: references the Claude.ai web path /mnt/user-data; "
                "plugin skills must not assume one surface's filesystem"
            )


def validate_command_file(path):
    fields = frontmatter(path)
    if fields is None:
        return
    if not fields.get("description"):
        errors.append(f"{rel(path)}: missing description")


def validate_shell_fences(path):
    lines = path.read_text().splitlines()
    in_shell = False
    fence_start = 0
    block = []

    for idx, line in enumerate(lines, start=1):
        opener = re.match(r"^```(bash|sh|shell)\s*$", line)
        if opener and not in_shell:
            in_shell = True
            fence_start = idx
            block = []
            continue
        if in_shell and line.startswith("```"):
            result = subprocess.run(["bash", "-n"], input="\n".join(block), text=True, capture_output=True)
            if result.returncode != 0:
                detail = result.stderr.strip().splitlines()
                suffix = f": {detail[0]}" if detail else ""
                errors.append(f"{rel(path)}:{fence_start}: invalid shell code fence{suffix}")
            in_shell = False
            continue
        if in_shell:
            block.append(line)

    if in_shell:
        errors.append(f"{rel(path)}:{fence_start}: unclosed shell code fence")


def validate_skills_and_commands():
    for path in sorted((root / "plugins").glob("*/skills/*/SKILL.md")):
        validate_skill_file(path, require_allowed_tools=True)
        validate_surface_agnostic(path)
        warn_missing_fallback(path)
        validate_shell_fences(path)

    for path in sorted((root / "claude-ai-skills").glob("*/SKILL.md")):
        validate_skill_file(path, require_allowed_tools=False)
        validate_shell_fences(path)

    for path in sorted((root / "plugins").glob("*/commands/*.md")):
        validate_command_file(path)
        validate_surface_agnostic(path)
        validate_shell_fences(path)

    for path in sorted((root / "scripts").glob("*.sh")):
        result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
        if result.returncode != 0:
            detail = result.stderr.strip().splitlines()
            suffix = f": {detail[0]}" if detail else ""
            errors.append(f"{rel(path)}: invalid shell syntax{suffix}")


validate_marketplaces()
validate_skills_and_commands()

for warning in warnings:
    print(f"WARN: {warning}")

if errors:
    print("Validation failed:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)

print("Validation passed.")
PY
