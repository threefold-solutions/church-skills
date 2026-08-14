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

    # A refusal must be atomic. Asserting only the non-zero exit misses the case where
    # plugins listed BEFORE the conflicting one were already copied in — leaving the
    # target mutated, with an ownership marker, and unregistered because the
    # marketplace write never runs.
    if python3 - "$TMP_REPO" "$ROOT_DIR" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
source_root = Path(sys.argv[2])

incoming = {
    plugin["name"]
    for plugin in json.loads(
        (source_root / ".agents" / "plugins" / "marketplace.json").read_text()
    )["plugins"]
}
# The pre-seeded conflicting plugin is the only thing that may exist in the target.
strays = sorted(
    p.name
    for p in (target / "plugins").iterdir()
    if p.is_dir() and p.name in incoming and p.name != "communications"
)
if strays:
    raise SystemExit(f"refused install still copied plugins into the target: {strays}")
if (target / ".agents" / "plugins" / "marketplace.json").exists():
    raise SystemExit("refused install wrote a marketplace file")
PY
    then
        pass "Codex repo install leaves no partial state after refusing"
    else
        fail "Codex repo install mutated the target despite refusing"
    fi
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

# The surface-agnostic scan has to recognise a tool name in every spelling a skill
# author might reach for, and stay quiet on ordinary prose. Both halves matter: a
# formatting variant that slips through defeats the check, and a false positive on
# "read the file" makes it unusable. Runs against a throwaway copy of the repo, so the
# real tree is never touched.
SELFTEST_ROOT="$(mktemp -d)"
tar -cf - --exclude=./.git --exclude=./dist --exclude=./node_modules . \
    | (cd "$SELFTEST_ROOT" && tar -xf -)
PROBE="$SELFTEST_ROOT/plugins/advisory/skills/staff-review/SKILL.md"
cp "$PROBE" "$SELFTEST_ROOT/probe.bak"
selftest_failures=0

check_case() {
    local line="$1" expected="$2" actual
    cp "$SELFTEST_ROOT/probe.bak" "$PROBE"
    printf '\n%s\n' "$line" >> "$PROBE"
    if "$SELFTEST_ROOT/scripts/validate.sh" >/dev/null 2>&1; then actual="PASS"; else actual="FLAG"; fi
    if [[ "$actual" != "$expected" ]]; then
        echo "  expected $expected, got $actual: $line"
        selftest_failures=$((selftest_failures + 1))
    fi
}

# Claude Code names, in every formatting a skill author might use.
check_case 'Use the Read tool to open the artifact.' FLAG
check_case 'Use the `Read` tool to open the artifact.' FLAG
check_case 'Use the **Read** tool to open the artifact.' FLAG
check_case 'Use the _Read_ tool to open the artifact.' FLAG
check_case 'Use the [Read](https://docs.claude.com) tool.' FLAG
check_case 'Save it with the **Write** tool.' FLAG
check_case 'Ask via AskUserQuestion.' FLAG
# Codex names — binding a shared skill to Codex is exactly as broken.
check_case 'Use `apply_patch` to update the review.' FLAG
check_case 'Run exec_command to inspect the tree.' FLAG
check_case 'Call **view_image** on the mockup.' FLAG
check_case 'Use update_plan to track the rounds.' FLAG
check_case 'Use request_user_input to ask what to review.' FLAG
# Claude.ai web names. These are snake_case, so they regress the moment underscore
# handling treats an identifier as emphasis.
check_case 'Call present_files with the vCard.' FLAG
check_case 'Ask with ask_user_input_v0 first.' FLAG
# Ordinary prose must stay clean, or the check is unusable.
check_case 'Read the file carefully before judging.' PASS
check_case 'Write a concise summary of the debate.' PASS
check_case '*Edit* nothing; the panel only reviews.' PASS
check_case 'Apply the patch the panel recommends.' PASS
check_case 'Open the mockup and read what it says.' PASS

if [[ "$selftest_failures" -eq 0 ]]; then
    pass "surface-agnostic scan catches every tool-name spelling without false positives"
else
    fail "surface-agnostic scan mismatched on $selftest_failures case(s)"
fi
rm -rf "$SELFTEST_ROOT"

if [[ "$ERRORS" -gt 0 ]]; then
    echo ""
    echo "$ERRORS installation test(s) failed"
    exit 1
fi

echo ""
echo "All installation tests passed."
