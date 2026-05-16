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
| `communications` | Drafting and design helpers for church comms (announcements, social posts, newsletters, visual assets) |

## Skills

| Skill | Claude.ai | Claude Code | Lives under |
|-------|-----------|-------------|-------------|
| `screenshot-to-vcard` | ✅ | ✅ | `communications` plugin |

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

## Conventions

- License: MIT (see `LICENSE`).
- Versioning: marketplace and every plugin track the same `version` for now.
  Split per-plugin versions later if release cadence diverges.
- Plugin names are short and unprefixed (e.g. `communications`, not
  `church-communications`) — the marketplace `church-skills@` namespace
  already scopes them.
