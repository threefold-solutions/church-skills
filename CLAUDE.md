# CLAUDE.md

This file gives Claude Code context when working in this repository.

## Project Overview

`church-skills` is a repository of AI skills built for churches and ministries.
It ships in two formats so the same content can serve both audiences:

1. **Claude.ai web Skills** — `.skill` bundles for staff using Claude in a
   browser (claude.ai).
2. **Claude Code + Codex plugins** — a plugin marketplace for developers and
   power users.

A skill may live in one or both trees. When it lives in both, the Claude.ai
copy uses web-skill tooling (`ask_user_input_v0`, `present_files`,
`/mnt/user-data/outputs/`) and the Claude Code copy uses Code tooling
(`AskUserQuestion`, `Write`, normal filesystem paths).

## Architecture

```
claude-ai-skills/                # Claude.ai web Skills (.skill bundles)
  <skill-name>/
    SKILL.md

.claude-plugin/
  marketplace.json               # Claude Code marketplace manifest

.agents/plugins/
  marketplace.json               # Codex / cross-platform plugin registry

plugins/                         # Claude Code + Codex plugins
  <plugin-name>/
    .claude-plugin/
      plugin.json                # Claude Code plugin manifest
    .codex-plugin/
      plugin.json                # Codex plugin manifest
    README.md
    commands/                    # Slash commands (*.md with YAML frontmatter)
    skills/
      <skill-name>/
        SKILL.md                 # Skill definition with YAML frontmatter
```

### Plugin components

**Commands** (`commands/*.md`) define user-invoked slash commands. YAML
frontmatter at the top sets `description`, `argument-hint`, and
`allowed-tools`.

**Skills** (`skills/<name>/SKILL.md`) are auto-invoked behaviors. YAML
frontmatter sets `name`, `description` (WHEN to activate), and
`allowed-tools`.

## Plugins

| Plugin | Description |
|--------|-------------|
| `advisory` | Simulated advisory panels that pressure-test church-facing decisions from multiple staff perspectives |
| `communications` | Drafting and design helpers for church comms (announcements, social posts, newsletters, visual assets) |

## Skills

| Skill | Claude.ai | Claude Code | Lives under |
|-------|-----------|-------------|-------------|
| `screenshot-to-vcard` | ✅ | ✅ | `communications` plugin |
| `staff-review` | ✅ | ✅ | `advisory` plugin |

`staff-review` is the one skill whose two copies carry different names. The Claude.ai
bundle is `church-staff-review`, because a standalone `.skill` has no plugin namespace
to supply the church context; under the plugin, `advisory/` already does.

## Adding a new skill

- **Claude.ai-only skill**: drop a folder at
  `claude-ai-skills/<skill-name>/SKILL.md`. Distribute by zipping the folder
  to `<skill-name>.skill` and uploading to claude.ai.
- **Claude Code skill**: place it under the relevant plugin at
  `plugins/<plugin>/skills/<skill-name>/SKILL.md` and add `allowed-tools:` to
  its frontmatter.
- **Both**: keep both copies in sync. The Claude.ai copy uses
  `ask_user_input_v0` / `present_files` / `/mnt/user-data/outputs/`; the
  Claude Code copy uses `AskUserQuestion` / `Write` / normal paths.

## Adding a new plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json` and
   `.codex-plugin/plugin.json`.
2. Add a `README.md` for the plugin documenting its commands and skills.
3. Register the plugin in `.claude-plugin/marketplace.json` and
   `.agents/plugins/marketplace.json`.
4. Bump the marketplace `version` (semver) so existing users see the update.
5. Run `./scripts/test-installation.sh` before opening a PR.

## Development checks

Run the repo validator after editing marketplaces, plugin manifests, commands,
or skills:

```bash
./scripts/validate.sh
```

The validator checks:

- JSON syntax and required marketplace/plugin manifest fields.
- Marketplace source paths and plugin `plugin.json` files exist.
- Claude marketplace versions, Claude plugin versions, and Codex plugin
  versions stay aligned.
- Skill frontmatter has `name` and `description`; plugin skills also require
  `allowed-tools`.
- Shell code fences in skills/commands parse with `bash -n`.

GitHub Actions runs the same check on pushes and pull requests to `main`.

Run the fuller installer smoke suite after changing distribution or install
plumbing:

```bash
./scripts/test-installation.sh
```

That suite runs the validator, builds `dist/`, verifies Codex marketplace
paths, tests repo install/merge behavior, refuses to overwrite unrelated
same-name plugins, and confirms legacy flat-skill cleanup only removes owned
church-skills content.

## Distribution scripts

- `./scripts/build-universal.sh` builds ignored artifacts under `dist/`:
  Codex plugins, Claude Code plugins, Claude.ai skill folders, and `.skill`
  bundles.
- `./scripts/install-codex.sh --repo /path/to/repo` copies Codex plugins into
  another repo and merges `.agents/plugins/marketplace.json`.
- `./scripts/install-codex.sh --user` registers and enables the marketplace
  globally for Codex.
- `./scripts/install-all.sh` bootstraps from GitHub and installs or refreshes
  detected local tools.
- `./scripts/refresh-plugins.sh` refreshes Claude Code's marketplace cache when
  the marketplace is already installed.

## Conventions

- License: MIT (see `LICENSE`).
- Versioning: marketplace and every plugin track the same `version` for now.
  Update `.claude-plugin/marketplace.json`,
  `plugins/<plugin>/.claude-plugin/plugin.json`, and
  `plugins/<plugin>/.codex-plugin/plugin.json` together. Split per-plugin
  versions later if release cadence diverges.
- Plugin names are short and unprefixed (e.g. `communications`, not
  `church-communications`) — the marketplace `church-skills@` namespace
  already scopes them.
- Long plugin skills should stay focused. If a skill grows past roughly 300
  lines of mostly static reference material, split it into narrower skills or
  mark the static block with `<!-- cache:start -->` / `<!-- cache:end -->`.
