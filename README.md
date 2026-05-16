# church-skills

Claude Code and Codex plugins built for churches and ministries — by [Threefold Solutions](https://github.com/Threefold-Solutions).

> **Status:** early. The first plugin (`communications`) is being scaffolded. Expect breaking changes until `v1.0.0`.

## Overview

`church-skills` is a plugin marketplace. Each plugin focuses on one ministry
domain and ships the slash commands and skills that domain needs. Install one,
some, or all — depending on what your church team actually does.

| Plugin | Description | Status |
|--------|-------------|--------|
| `communications` | Drafting and design helpers for church comms (announcements, social posts, newsletters, visual assets) | Scaffolding |

More plugins (sermon prep, volunteer care, service planning, discipleship,
pastoral care) on the roadmap.

## Install

### Claude Code

```text
/plugin marketplace add Threefold-Solutions/church-skills
/plugin install communications@church-skills
```

To browse: `/plugin marketplace browse church-skills`.

### OpenAI Codex CLI

Repo-local (plugins load whenever you run Codex inside this repo):

```bash
git clone https://github.com/Threefold-Solutions/church-skills
cd church-skills
codex
```

Global install script is on the roadmap.

## Repo structure

```
.claude-plugin/marketplace.json   # Claude Code marketplace manifest
.agents/plugins/marketplace.json  # Codex / cross-platform registry
plugins/<name>/                   # One directory per plugin
```

See [`CLAUDE.md`](./CLAUDE.md) or [`AGENTS.md`](./AGENTS.md) for the full
layout and conventions.

## Contributing

Issues and PRs welcome — especially from church staff sharing real workflows
that would benefit from a skill.

## License

MIT — see [LICENSE](./LICENSE).
