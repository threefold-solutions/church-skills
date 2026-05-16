#!/usr/bin/env bash
# Install church-skills plugins for Codex globally or into another repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "/tmp")"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "/tmp")"
REPO_SLUG="${CHURCH_SKILLS_REPO:-Threefold-Solutions/church-skills}"
REPO_REF="${CHURCH_SKILLS_REF:-main}"
ARCHIVE_URL="${CHURCH_SKILLS_ARCHIVE_URL:-https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REPO_REF}}"
BOOTSTRAP_DIR=""

usage() {
    cat <<'EOF'
Usage:
  scripts/install-codex.sh --repo /path/to/repo
  scripts/install-codex.sh --user
  scripts/install-codex.sh --cleanup [--yes]

Options:
  --repo PATH   Copy Codex plugins into PATH/plugins and merge entries into
                PATH/.agents/plugins/marketplace.json. Existing church-skills
                plugin installs are replaced; unrelated plugins are preserved.

  --user        Register the GitHub marketplace with Codex, populate the Codex
                plugin cache, and enable every church-skills plugin globally.
                Requires the codex CLI and git.

  --cleanup     Remove legacy flat ~/.codex/skills entries only when their
                SKILL.md content exactly matches a current church-skills plugin
                skill. User-authored skills are preserved.

  --yes         Skip confirmation in --cleanup.
  --help        Show this help text.
EOF
}

cleanup_bootstrap() {
    if [[ -n "$BOOTSTRAP_DIR" && -d "$BOOTSTRAP_DIR" ]]; then
        rm -rf "$BOOTSTRAP_DIR"
    fi
}
trap cleanup_bootstrap EXIT

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "error: required command not found: $cmd" >&2
        exit 1
    fi
}

bootstrap_repo() {
    if [[ -f "$ROOT_DIR/scripts/build-universal.sh" ]]; then
        return
    fi

    BOOTSTRAP_DIR="$(mktemp -d)"
    local extracted=""

    if [[ -z "${CHURCH_SKILLS_ARCHIVE_URL:-}" ]] && command -v git >/dev/null 2>&1; then
        local clone_url="https://github.com/${REPO_SLUG}.git"
        extracted="$BOOTSTRAP_DIR/church-skills"
        echo "Bootstrap source: git clone $clone_url@$REPO_REF" >&2
        if ! git clone --quiet --branch "$REPO_REF" --single-branch "$clone_url" "$extracted" 2>/dev/null; then
            rm -rf "$extracted"
            extracted=""
        fi
    fi

    if [[ -z "$extracted" ]]; then
        require_cmd curl
        require_cmd tar
        echo "Bootstrap source: curl $ARCHIVE_URL" >&2
        curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$BOOTSTRAP_DIR"
        extracted="$(find "$BOOTSTRAP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    fi

    if [[ -z "$extracted" || ! -f "$extracted/scripts/build-universal.sh" ]]; then
        echo "error: failed to bootstrap church-skills from $REPO_SLUG@$REPO_REF" >&2
        exit 1
    fi

    ROOT_DIR="$extracted"
}

hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        echo "error: sha256sum or shasum is required" >&2
        return 1
    fi
}

skill_md_name() {
    local skill_md="$1"
    [[ -f "$skill_md" ]] || { echo ""; return; }
    awk '
        /^---[[:space:]]*$/ { fm++; next }
        fm == 1 && /^name:[[:space:]]*/ {
            sub(/^name:[[:space:]]*/, "")
            gsub(/^["'\'']|["'\'']$/, "")
            print
            exit
        }
        fm >= 2 { exit }
    ' "$skill_md"
}

cleanup_legacy_user_skills() {
    local assume_yes="${1:-false}"
    local skills_home="$HOME/.codex/skills"
    if [[ ! -d "$skills_home" ]]; then
        echo "no ~/.codex/skills/ directory - nothing to clean up"
        return 0
    fi

    local candidates=()
    local skill_dir
    for skill_dir in "$ROOT_DIR"/plugins/*/skills/*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        local skill_name target skill_md source_hash target_hash fm_name
        skill_name="$(basename "$skill_dir")"
        target="$skills_home/$skill_name"
        skill_md="$target/SKILL.md"
        [[ -f "$skill_md" ]] || continue

        fm_name="$(skill_md_name "$skill_md")"
        [[ "$fm_name" == "$skill_name" ]] || continue
        source_hash="$(hash_file "$skill_dir/SKILL.md")"
        target_hash="$(hash_file "$skill_md")"
        if [[ "$source_hash" == "$target_hash" ]]; then
            candidates+=("$target")
        fi
    done

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "no legacy church-skills flat skills found in $skills_home"
        return 0
    fi

    echo "found ${#candidates[@]} legacy church-skills flat skill(s) to remove:"
    local target
    for target in "${candidates[@]}"; do
        echo "  $target"
    done

    if [[ "$assume_yes" != "true" ]]; then
        if [[ ! -t 0 ]]; then
            echo "stdin is not a terminal - re-run with --yes to confirm removal."
            return 1
        fi
        local answer=""
        printf "remove these directories? [y/N] "
        read -r answer
        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) ;;
            *) echo "aborted - nothing removed."; return 0 ;;
        esac
    fi

    local removed=0
    for target in "${candidates[@]}"; do
        rm -rf "${target:?}"
        echo "removed: $target"
        removed=$((removed + 1))
    done
    echo "cleaned up $removed legacy skill director$([ "$removed" -eq 1 ] && echo "y" || echo "ies")"
}

install_repo_plugins() {
    local target_repo="$1"
    python3 - "$ROOT_DIR" "$target_repo" <<'PY'
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

source_root = Path(sys.argv[1])
target_root = Path(sys.argv[2])
source_marketplace = source_root / ".agents" / "plugins" / "marketplace.json"
target_marketplace = target_root / ".agents" / "plugins" / "marketplace.json"
marker_name = ".church-skills-installed"


def load_json(path, default=None):
    if not path.exists():
        return default
    return json.loads(path.read_text())


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def is_safe_to_replace(path):
    if not path.exists():
        return True
    if (path / marker_name).is_file():
        return True
    plugin_json = path / ".codex-plugin" / "plugin.json"
    if not plugin_json.is_file():
        return False
    try:
        data = json.loads(plugin_json.read_text())
    except json.JSONDecodeError:
        return False
    if data.get("repository") == "https://github.com/Threefold-Solutions/church-skills":
        return True
    author = data.get("author") or {}
    return author.get("url") == "https://github.com/Threefold-Solutions"


marketplace = load_json(source_marketplace)
if not marketplace:
    raise SystemExit(f"missing source marketplace: {source_marketplace}")

incoming_plugins = []
installed = []
for entry in marketplace.get("plugins", []):
    name = entry.get("name")
    path_value = (entry.get("source") or {}).get("path")
    if not name or not path_value:
        continue
    source_plugin = source_root / path_value
    if not (source_plugin / ".codex-plugin" / "plugin.json").is_file():
        continue
    target_plugin = target_root / "plugins" / name
    if not is_safe_to_replace(target_plugin):
        raise SystemExit(
            f"refusing to replace existing plugin directory not owned by church-skills: {target_plugin}"
        )
    if target_plugin.exists():
        shutil.rmtree(target_plugin)
    shutil.copytree(source_plugin, target_plugin)
    (target_plugin / marker_name).write_text(
        "installed_by=church-skills\n"
        f"installed_at={datetime.now(timezone.utc).isoformat()}\n"
    )
    plugin_entry = dict(entry)
    plugin_entry["source"] = {"source": "local", "path": f"./plugins/{name}"}
    incoming_plugins.append(plugin_entry)
    installed.append(name)

existing = load_json(
    target_marketplace,
    {"name": "local-plugins", "interface": {"displayName": "Local Plugins"}, "plugins": []},
)
incoming_names = {plugin["name"] for plugin in incoming_plugins}
kept = [plugin for plugin in existing.get("plugins", []) if plugin.get("name") not in incoming_names]
merged = {
    "name": existing.get("name") or marketplace.get("name") or "local-plugins",
    "interface": existing.get("interface") or marketplace.get("interface") or {"displayName": "Local Plugins"},
    "plugins": kept + incoming_plugins,
}
write_json(target_marketplace, merged)

for name in installed:
    print(f"installed plugin: {target_root / 'plugins' / name}")
print(f"updated marketplace: {target_marketplace}")
PY
}

install_user_plugins() {
    require_cmd codex
    require_cmd git

    local config_file="$HOME/.codex/config.toml"
    local marketplace_name="church-skills"
    local marketplace_clone="$HOME/.codex/.tmp/marketplaces/$marketplace_name"
    local cache_root="$HOME/.codex/plugins/cache/$marketplace_name"

    mkdir -p "$HOME/.codex"
    [[ -f "$config_file" ]] || touch "$config_file"

    if grep -q '^\[marketplaces\.church-skills\]' "$config_file" 2>/dev/null; then
        echo "marketplace already registered - upgrading..."
        codex plugin marketplace upgrade "$marketplace_name" 2>&1 | sed 's/^/  /'
    else
        echo "registering church-skills marketplace..."
        codex plugin marketplace add "$REPO_SLUG" 2>&1 | sed 's/^/  /'
    fi

    if [[ ! -d "$marketplace_clone" ]]; then
        echo "error: marketplace clone missing at $marketplace_clone" >&2
        echo "       codex plugin marketplace add should have created it." >&2
        return 1
    fi

    local commit_hash
    commit_hash="$(git -C "$marketplace_clone" rev-parse --short=8 HEAD 2>/dev/null)"
    [[ -n "$commit_hash" ]] || { echo "error: could not read marketplace commit hash" >&2; return 1; }

    echo "populating Codex cache (commit $commit_hash)..."
    rm -rf "$cache_root"

    local installed=0
    local plugin_dir
    for plugin_dir in "$marketplace_clone"/plugins/*; do
        [[ -d "$plugin_dir" ]] || continue
        [[ -f "$plugin_dir/.codex-plugin/plugin.json" ]] || continue
        local plugin_name dest
        plugin_name="$(basename "$plugin_dir")"
        dest="$cache_root/$plugin_name/$commit_hash"
        mkdir -p "$dest"
        cp -R "$plugin_dir"/. "$dest/"
        rm -rf "$dest/.claude-plugin"
        printf 'installed_by=church-skills\ncommit=%s\n' "$commit_hash" > "$dest/.church-skills-installed"
        echo "  installed: $plugin_name"
        installed=$((installed + 1))
    done

    local enabled=0
    for plugin_dir in "$marketplace_clone"/plugins/*; do
        [[ -d "$plugin_dir" ]] || continue
        [[ -f "$plugin_dir/.codex-plugin/plugin.json" ]] || continue
        local plugin_name
        plugin_name="$(basename "$plugin_dir")"
        if grep -qF "[plugins.\"${plugin_name}@church-skills\"]" "$config_file"; then
            continue
        fi
        printf '\n[plugins."%s@church-skills"]\nenabled = true\n' "$plugin_name" >> "$config_file"
        enabled=$((enabled + 1))
    done

    [[ "$enabled" -eq 0 ]] || echo "enabled $enabled plugin entr$([ "$enabled" -eq 1 ] && echo "y" || echo "ies") in $config_file"
    echo "installed $installed church-skills plugin(s) globally for Codex."
    echo "Restart Codex to load the updated plugin cache."
}

main() {
    case "${1:-}" in
        --help|-h)
            usage
            ;;
        --repo)
            [[ $# -ge 2 ]] || { echo "error: --repo requires a target path" >&2; exit 1; }
            bootstrap_repo
            require_cmd python3
            local target_repo
            target_repo="$(cd "$2" && pwd)"
            install_repo_plugins "$target_repo"
            ;;
        --user)
            bootstrap_repo
            install_user_plugins
            cleanup_legacy_user_skills "true"
            ;;
        --cleanup)
            bootstrap_repo
            local assume_yes=false
            if [[ "${2:-}" == "--yes" || "${2:-}" == "-y" ]]; then
                assume_yes=true
            fi
            cleanup_legacy_user_skills "$assume_yes"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
