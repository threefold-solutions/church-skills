#!/usr/bin/env bash
# Install or refresh church-skills across detected local AI tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "/tmp")"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "/tmp")"
REPO_SLUG="${CHURCH_SKILLS_REPO:-Threefold-Solutions/church-skills}"
REPO_REF="${CHURCH_SKILLS_REF:-main}"
ARCHIVE_URL="${CHURCH_SKILLS_ARCHIVE_URL:-https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${REPO_REF}}"
BOOTSTRAP_DIR=""
FORCE=false

if [[ "${1:-}" == "--force" || ! -t 0 ]]; then
    FORCE=true
fi

usage() {
    cat <<'EOF'
Usage:
  scripts/install-all.sh [--force]

Installs church-skills for detected local tools:
  - Codex CLI: installs and enables the Codex marketplace globally.
  - Claude Code: refreshes the marketplace cache if already installed, or
    prints the /plugin marketplace add command if not.

Remote install:
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Threefold-Solutions/church-skills/main/scripts/install-all.sh)"
EOF
}

cleanup() {
    if [[ -n "$BOOTSTRAP_DIR" && -d "$BOOTSTRAP_DIR" ]]; then
        rm -rf "$BOOTSTRAP_DIR"
    fi
}
trap cleanup EXIT

bootstrap_if_needed() {
    if [[ -f "$ROOT_DIR/scripts/install-codex.sh" ]]; then
        return
    fi

    BOOTSTRAP_DIR="$(mktemp -d)"
    local extracted=""

    if [[ -z "${CHURCH_SKILLS_ARCHIVE_URL:-}" ]] && command -v git >/dev/null 2>&1; then
        local clone_url="https://github.com/${REPO_SLUG}.git"
        extracted="$BOOTSTRAP_DIR/church-skills"
        echo "Bootstrap source: git clone $clone_url@$REPO_REF"
        if ! git clone --quiet --branch "$REPO_REF" --single-branch "$clone_url" "$extracted" 2>/dev/null; then
            rm -rf "$extracted"
            extracted=""
        fi
    fi

    if [[ -z "$extracted" ]]; then
        command -v curl >/dev/null 2>&1 || { echo "error: curl required for remote install" >&2; exit 1; }
        command -v tar >/dev/null 2>&1 || { echo "error: tar required for remote install" >&2; exit 1; }
        echo "Bootstrap source: curl $ARCHIVE_URL"
        curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$BOOTSTRAP_DIR"
        extracted="$(find "$BOOTSTRAP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    fi

    if [[ -z "$extracted" || ! -f "$extracted/scripts/install-codex.sh" ]]; then
        echo "error: failed to bootstrap church-skills from $REPO_SLUG@$REPO_REF" >&2
        exit 1
    fi

    ROOT_DIR="$extracted"
}

detect_platforms() {
    HAVE_CODEX=false
    HAVE_CLAUDE=false

    if command -v codex >/dev/null 2>&1 || [[ -d "$HOME/.codex" ]]; then
        HAVE_CODEX=true
    fi
    if [[ -d "$HOME/.claude" ]]; then
        HAVE_CLAUDE=true
    fi
}

print_detection() {
    echo "Platform detection:"
    if $HAVE_CODEX; then
        echo "  Codex CLI .... found"
    else
        echo "  Codex CLI .... not found"
    fi
    if $HAVE_CLAUDE; then
        echo "  Claude Code .. found (~/.claude exists)"
    else
        echo "  Claude Code .. not found"
    fi
    echo ""
}

confirm() {
    $FORCE && return 0
    printf "Proceed with install/refresh for detected tools? [y/N] "
    local answer=""
    read -r answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) echo "aborted."; exit 0 ;;
    esac
}

install_codex() {
    echo "=== Codex CLI ==="
    if ! command -v codex >/dev/null 2>&1; then
        echo "  Codex config directory exists, but the codex binary is not on PATH."
        echo "  Skipping global install."
        echo ""
        return
    fi
    "$ROOT_DIR/scripts/install-codex.sh" --user
    echo ""
}

refresh_claude() {
    echo "=== Claude Code ==="
    local marketplace_dir="$HOME/.claude/plugins/marketplaces/church-skills"
    if [[ -d "$marketplace_dir" ]]; then
        "$ROOT_DIR/scripts/refresh-plugins.sh"
    else
        echo "  Marketplace is not installed yet."
        echo "  In Claude Code, run:"
        echo "    /plugin marketplace add Threefold-Solutions/church-skills"
    fi
    echo ""
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

bootstrap_if_needed
detect_platforms
print_detection

if ! $HAVE_CODEX && ! $HAVE_CLAUDE; then
    echo "No supported local tool installs detected."
    exit 0
fi

confirm

$HAVE_CODEX && install_codex
$HAVE_CLAUDE && refresh_claude

echo "Done."
