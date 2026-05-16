#!/usr/bin/env bash
# Build distributable Claude.ai, Claude Code, and Codex artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"

python3 - "$ROOT_DIR" "$DIST_DIR" <<'PY'
import json
import shutil
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
dist = Path(sys.argv[2])


def load_json(path):
    return json.loads(path.read_text())


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def copytree(src, dest, ignore_names=()):
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest, ignore=shutil.ignore_patterns(*ignore_names))


def codex_plugins():
    plugins = []
    marketplace = load_json(root / ".agents" / "plugins" / "marketplace.json")
    for entry in marketplace.get("plugins", []):
        path_value = entry.get("source", {}).get("path")
        if not path_value:
            continue
        plugin_dir = root / path_value
        if (plugin_dir / ".codex-plugin" / "plugin.json").is_file():
            plugin_entry = dict(entry)
            plugin_entry["source"] = {"source": "local", "path": f"./plugins/{entry['name']}"}
            plugins.append((entry["name"], plugin_dir, plugin_entry))
    return marketplace, plugins


def claude_plugins():
    marketplace = load_json(root / ".claude-plugin" / "marketplace.json")
    plugins = []
    for entry in marketplace.get("plugins", []):
        plugin_dir = root / entry.get("source", "")
        if (plugin_dir / ".claude-plugin" / "plugin.json").is_file():
            plugins.append((entry["name"], plugin_dir, entry))
    return marketplace, plugins


if dist.exists():
    shutil.rmtree(dist)
dist.mkdir(parents=True)

codex_marketplace, codex = codex_plugins()
codex_dist = dist / "codex"
for name, plugin_dir, _entry in codex:
    copytree(plugin_dir, codex_dist / "plugins" / name, ignore_names=(".claude-plugin",))
codex_out = dict(codex_marketplace)
codex_out["plugins"] = [entry for _name, _plugin_dir, entry in codex]
write_json(codex_dist / "plugins" / "marketplace.json", codex_out)
if (root / "AGENTS.md").is_file():
    shutil.copy2(root / "AGENTS.md", codex_dist / "AGENTS.md")

claude_marketplace, claude = claude_plugins()
claude_dist = dist / "claude-code"
for name, plugin_dir, _entry in claude:
    copytree(plugin_dir, claude_dist / "plugins" / name, ignore_names=(".codex-plugin",))
write_json(claude_dist / "marketplace.json", claude_marketplace)

web_src = root / "claude-ai-skills"
web_dist = dist / "claude-ai-skills"
bundle_dist = dist / "claude-ai-bundles"
web_count = 0
if web_src.is_dir():
    web_dist.mkdir(parents=True, exist_ok=True)
    bundle_dist.mkdir(parents=True, exist_ok=True)
    for skill_dir in sorted(p for p in web_src.iterdir() if p.is_dir()):
        copytree(skill_dir, web_dist / skill_dir.name)
        bundle_path = bundle_dist / f"{skill_dir.name}.skill"
        with zipfile.ZipFile(bundle_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for path in sorted(skill_dir.rglob("*")):
                if path.is_file():
                    zf.write(path, path.relative_to(web_src))
        web_count += 1

print(f"Built Codex plugins: {len(codex)}")
print(f"Built Claude Code plugins: {len(claude)}")
print(f"Built Claude.ai skill bundles: {web_count}")
print(f"Output: {dist}")
PY
