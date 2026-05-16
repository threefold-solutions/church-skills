# AGENTS.md

Project instructions for OpenAI Codex CLI.

## Project Overview

`church-skills` is a plugin marketplace of AI skills for churches and
ministries, distributed as both Claude Code plugins and Codex plugins. Each
plugin focuses on one ministry domain.

## Plugins

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
# Future: ./scripts/install-codex.sh --user
```

A cross-platform installer script lives on the roadmap; for now, follow the
README's manual install steps.

## Repo layout

See [`CLAUDE.md`](./CLAUDE.md) for the full structure and conventions — this
file mirrors the same project context for Codex.
