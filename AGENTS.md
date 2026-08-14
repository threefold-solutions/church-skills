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
| `advisory` | Simulated advisory panels that pressure-test church-facing decisions from multiple staff perspectives |
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

## Surface-agnostic skill bodies

Plugin skills are shared by Claude Code and Codex from the same `SKILL.md`. A skill
body must describe the required outcome and let the active surface bind it to a native
capability — never name a tool from one specific surface, and always state what to do
when the capability is unavailable.

The `allowed-tools:` frontmatter field is exempt (Codex ignores it), as is the
`claude-ai-skills/` tree.

`./scripts/validate.sh` checks the **tool-name** half against a denylist of known tool
names — inherently incomplete, since surfaces add tools — and fails the build on a
violation. It only *warns* about a missing fallback, because whether one is present and
correct is a judgment about prose rather than something a regex can decide — so a green
validator is not evidence that a skill degrades gracefully. See
[`CLAUDE.md`](./CLAUDE.md) for examples.

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
