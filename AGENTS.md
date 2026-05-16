# AGENTS.md

Project instructions for OpenAI Codex CLI.

## Project Overview

`church-skills` is a repository of AI skills built for churches and
ministries. It ships in two formats:

1. **Claude.ai web Skills** — `.skill` bundles under `claude-ai-skills/`.
2. **Claude Code + Codex plugins** — a plugin marketplace under `plugins/`.

Codex consumes the second tree via `.agents/plugins/marketplace.json`. The
first tree is not relevant to Codex.

## Plugins (Codex-visible)

| Plugin | Description |
|--------|-------------|
| `communications` | Drafting and design helpers for church comms (announcements, social posts, newsletters, visual assets) |

## Installation

### Repo-local (recommended)

This repo includes `.agents/plugins/marketplace.json`, which Codex reads on
startup. Cloning this repo and running Codex inside it makes every plugin
available automatically.

### Global

```bash
git clone https://github.com/Threefold-Solutions/church-skills
cd church-skills
./scripts/install-codex.sh --user
```

For a remote install without cloning first:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Threefold-Solutions/church-skills/main/scripts/install-all.sh)"
```

## Development checks

Run the validator after editing marketplaces, plugin manifests, commands, or
skills:

```bash
./scripts/validate.sh
```

The validator checks JSON manifests, marketplace source paths, aligned plugin
versions, skill frontmatter, plugin-skill `allowed-tools`, and shell code
fences inside skills or commands. GitHub Actions runs the same check for pushes
and pull requests to `main`.

Run the fuller installer smoke suite after changing distribution or install
plumbing:

```bash
./scripts/test-installation.sh
```

## Repo layout

See [`CLAUDE.md`](./CLAUDE.md) for the full structure and conventions — this
file mirrors the same project context for Codex.
