#!/usr/bin/env bash
# Smoke-test church-skills validation, build, and repo install behavior.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ERRORS=0

pass() {
    echo "OK: $1"
}

fail() {
    echo "FAIL: $1"
    ERRORS=$((ERRORS + 1))
}

echo "=== church-skills installation tests ==="

if "$ROOT_DIR/scripts/validate.sh"; then
    pass "repo validator passes"
else
    fail "repo validator failed"
fi

if "$ROOT_DIR/scripts/build-universal.sh" >/tmp/church-skills-build.log 2>&1; then
    pass "universal distribution builds"
else
    fail "universal distribution failed"
    sed -n '1,120p' /tmp/church-skills-build.log
fi

if python3 - "$ROOT_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
marketplace = json.loads((root / "dist" / "codex" / "plugins" / "marketplace.json").read_text())
for plugin in marketplace["plugins"]:
    path_value = plugin["source"]["path"]
    if not path_value.startswith("./plugins/"):
        raise SystemExit(f"bad path: {path_value}")
    plugin_dir = root / "dist" / "codex" / path_value[2:]
    if not plugin_dir.is_dir():
        raise SystemExit(f"missing plugin dir: {plugin_dir}")
PY
then
    pass "Codex distribution marketplace points to packaged plugins"
else
    fail "Codex distribution marketplace is invalid"
fi

TMP_REPO="$(mktemp -d)"
if "$ROOT_DIR/scripts/install-codex.sh" --repo "$TMP_REPO" >/tmp/church-skills-repo-install.log 2>&1; then
    if python3 - "$TMP_REPO" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
marketplace = json.loads((root / ".agents" / "plugins" / "marketplace.json").read_text())
names = {plugin["name"] for plugin in marketplace["plugins"]}
if "communications" not in names:
    raise SystemExit("communications plugin missing")
for plugin in marketplace["plugins"]:
    path_value = plugin["source"]["path"]
    if path_value.startswith("./plugins/") and not (root / path_value[2:]).is_dir():
        raise SystemExit(f"missing plugin dir: {path_value}")
marker = root / "plugins" / "communications" / ".church-skills-installed"
if not marker.is_file():
    raise SystemExit("install marker missing")
PY
    then
        pass "Codex repo install writes plugin and marketplace"
    else
        fail "Codex repo install output is invalid"
        sed -n '1,120p' /tmp/church-skills-repo-install.log
    fi
else
    fail "Codex repo install failed"
    sed -n '1,120p' /tmp/church-skills-repo-install.log
fi
rm -rf "$TMP_REPO"

TMP_REPO="$(mktemp -d)"
mkdir -p "$TMP_REPO/.agents/plugins"
cat > "$TMP_REPO/.agents/plugins/marketplace.json" <<'JSON'
{
  "name": "local-plugins",
  "interface": {
    "displayName": "Local Plugins"
  },
  "plugins": [
    {
      "name": "existing",
      "source": {
        "source": "local",
        "path": "./plugins/existing"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_USE"
      },
      "category": "Productivity"
    }
  ]
}
JSON
if "$ROOT_DIR/scripts/install-codex.sh" --repo "$TMP_REPO" >/tmp/church-skills-merge-install.log 2>&1; then
    if python3 - "$TMP_REPO" "$ROOT_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
source_root = Path(sys.argv[2])
plugins = json.loads((root / ".agents" / "plugins" / "marketplace.json").read_text())["plugins"]
names = {plugin["name"] for plugin in plugins}

# The pre-existing unrelated entry must survive the merge untouched.
if "existing" not in names:
    raise SystemExit(f"unrelated entry 'existing' was dropped: {sorted(names)}")

# Every church-skills plugin must be merged in, and nothing else invented.
expected = {
    plugin["name"]
    for plugin in json.loads(
        (source_root / ".agents" / "plugins" / "marketplace.json").read_text()
    )["plugins"]
}
if not expected <= names:
    raise SystemExit(f"church-skills plugins missing after merge: {sorted(expected - names)}")
if names - expected - {"existing"}:
    raise SystemExit(f"unexpected marketplace names: {sorted(names - expected - {'existing'})}")
PY
    then
        pass "Codex repo install preserves unrelated marketplace entries"
    else
        fail "Codex repo install did not preserve unrelated entries"
    fi
else
    fail "Codex repo install failed during merge test"
    sed -n '1,120p' /tmp/church-skills-merge-install.log
fi
rm -rf "$TMP_REPO"

TMP_REPO="$(mktemp -d)"
mkdir -p "$TMP_REPO/plugins/communications/.codex-plugin"
cat > "$TMP_REPO/plugins/communications/.codex-plugin/plugin.json" <<'JSON'
{
  "name": "communications",
  "version": "9.9.9",
  "description": "User plugin",
  "author": {
    "name": "Someone Else"
  }
}
JSON
if "$ROOT_DIR/scripts/install-codex.sh" --repo "$TMP_REPO" >/tmp/church-skills-refuse-install.log 2>&1; then
    fail "Codex repo install overwrote unrelated plugin"
else
    pass "Codex repo install refuses unrelated same-name plugin"
fi
rm -rf "$TMP_REPO"

TMP_HOME="$(mktemp -d)"
SKILLS_DIR="$TMP_HOME/.codex/skills"
mkdir -p "$SKILLS_DIR/screenshot-to-vcard" "$SKILLS_DIR/user-custom-skill"
cp "$ROOT_DIR/plugins/communications/skills/screenshot-to-vcard/SKILL.md" "$SKILLS_DIR/screenshot-to-vcard/SKILL.md"
cat > "$SKILLS_DIR/user-custom-skill/SKILL.md" <<'EOF'
---
name: user-custom-skill
description: stays
---

# User Skill
EOF
if HOME="$TMP_HOME" "$ROOT_DIR/scripts/install-codex.sh" --cleanup --yes >/tmp/church-skills-cleanup.log 2>&1; then
    if [[ -d "$SKILLS_DIR/screenshot-to-vcard" ]]; then
        fail "cleanup did not remove owned flat skill"
    elif [[ ! -d "$SKILLS_DIR/user-custom-skill" ]]; then
        fail "cleanup removed user-authored skill"
    else
        pass "cleanup removes only owned flat skills"
    fi
else
    fail "cleanup command failed"
    sed -n '1,120p' /tmp/church-skills-cleanup.log
fi
rm -rf "$TMP_HOME"

if [[ "$ERRORS" -gt 0 ]]; then
    echo ""
    echo "$ERRORS installation test(s) failed"
    exit 1
fi

echo ""
echo "All installation tests passed."
