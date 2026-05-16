# CLAUDE.md

This file gives Claude Code context when working in this repository.

## Project Overview

`church-skills` is a Claude Code plugin marketplace of skills built for churches
and ministries. Each plugin focuses on one ministry domain (communications,
sermon prep, volunteer care, etc.) and ships with the slash commands and skills
that domain needs.

Distributed as both Claude Code plugins and Codex plugins.

## Architecture

```
.claude-plugin/
  marketplace.json          # Lists every plugin in this repo

.agents/plugins/
  marketplace.json          # Codex / cross-platform plugin registry

plugins/
  <plugin-name>/
    .claude-plugin/
      plugin.json           # Claude Code plugin manifest
    .codex-plugin/
      plugin.json           # Codex plugin manifest
    README.md
    commands/               # Slash commands (*.md with YAML frontmatter)
    skills/
      <skill-name>/
        SKILL.md            # Skill definition with YAML frontmatter
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
