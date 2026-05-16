#!/usr/bin/env bash
# Refresh local Claude Code cache for the church-skills marketplace.
set -euo pipefail

MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/church-skills"
CACHE_DIR="$HOME/.claude/plugins/cache/church-skills"
INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"

if [[ ! -d "$MARKETPLACE_DIR" ]]; then
    echo "Marketplace not installed."
    echo "Run in Claude Code: /plugin marketplace add Threefold-Solutions/church-skills"
    exit 1
fi

command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }

echo "Refreshing church-skills marketplace..."
git -C "$MARKETPLACE_DIR" fetch origin
git -C "$MARKETPLACE_DIR" reset --hard origin/main

python3 - "$MARKETPLACE_DIR" "$CACHE_DIR" "$INSTALLED_FILE" <<'PY'
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

marketplace_dir = Path(sys.argv[1])
cache_dir = Path(sys.argv[2])
installed_file = Path(sys.argv[3])
now = datetime.now(timezone.utc).isoformat()
git_sha = subprocess.check_output(["git", "-C", str(marketplace_dir), "rev-parse", "HEAD"], text=True).strip()


def load_json(path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text())


updated = []
for plugin_dir in sorted((marketplace_dir / "plugins").iterdir()):
    if not plugin_dir.is_dir():
        continue
    plugin_json_path = plugin_dir / ".claude-plugin" / "plugin.json"
    if not plugin_json_path.is_file():
        continue
    plugin_json = json.loads(plugin_json_path.read_text())
    name = plugin_json["name"]
    version = plugin_json["version"]
    plugin_cache = cache_dir / name
    dest = plugin_cache / version

    if plugin_cache.exists():
        for old_version in plugin_cache.iterdir():
            if old_version.is_dir() and old_version.name != version:
                shutil.rmtree(old_version)

    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(plugin_dir, dest)
    updated.append((name, version, str(dest)))
    print(f"  updated: {name}/{version}")

if cache_dir.exists():
    live_names = {name for name, _version, _dest in updated}
    for cached_plugin in cache_dir.iterdir():
        if cached_plugin.is_dir() and cached_plugin.name not in live_names:
            shutil.rmtree(cached_plugin)
            print(f"  removed orphan: {cached_plugin.name}")

installed = load_json(installed_file, {"version": 2, "plugins": {}})
plugins = installed.setdefault("plugins", {})
plugins = {key: value for key, value in plugins.items() if not key.endswith("@church-skills")}
for name, version, dest in updated:
    plugins[f"{name}@church-skills"] = [
        {
            "scope": "project",
            "installPath": dest,
            "version": version,
            "installedAt": now,
            "lastUpdated": now,
            "gitCommitSha": git_sha,
            "projectPath": str(Path.home()),
        }
    ]
installed["plugins"] = plugins
installed_file.parent.mkdir(parents=True, exist_ok=True)
installed_file.write_text(json.dumps(installed, indent=2) + "\n")

print("Updated plugin registrations.")
PY

echo "Restart Claude Code to fully reload plugin definitions."
