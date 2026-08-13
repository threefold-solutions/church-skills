# church-skills

AI skills and plugins built for churches and ministries — by [Threefold Solutions](https://github.com/Threefold-Solutions).

> **Status:** early. First skill (`screenshot-to-vcard`) ships in both formats; more on the way. Expect breaking changes until `v1.0.0`.

## Overview

`church-skills` ships in two formats so it works for everyone on your team:

- **Claude.ai web Skills** — for staff using Claude in a browser (claude.ai). Distributed as `.skill` bundles.
- **Claude Code + Codex plugins** — for developers and power users running Claude Code or OpenAI Codex CLI. Distributed as a plugin marketplace.

Both formats live in the same repo so a skill ported between them stays in sync.

## What's inside

| Skill / Plugin | Claude.ai Skill | Claude Code Plugin | Description |
|---|---|---|---|
| `screenshot-to-vcard` | ✅ | ✅ (under `communications`) | Convert a screenshot of contact info into a downloadable `.vcf` vCard |
| `staff-review` | ✅ (as `church-staff-review`) | ✅ (under `advisory`) | Six church staff personas react, debate, and deliver a unified recommendation on anything that touches church operations |

More on the roadmap: sermon prep, volunteer care, service planning, discipleship, pastoral care.

## Install

### Claude.ai (web)

1. Clone or download this repo.
2. Zip the skill folder you want — for example:
   ```bash
   cd claude-ai-skills
   zip -r screenshot-to-vcard.skill screenshot-to-vcard
   ```
3. Upload the resulting `.skill` file to claude.ai via **Settings → Capabilities → Skills**.

### Claude Code

```text
/plugin marketplace add Threefold-Solutions/church-skills
/plugin install communications@church-skills
/plugin install advisory@church-skills
```

To browse the full marketplace: `/plugin marketplace browse church-skills`.

### OpenAI Codex CLI

Repo-local (plugins load automatically whenever Codex runs inside this repo):

```bash
git clone https://github.com/Threefold-Solutions/church-skills
cd church-skills
codex
```

Install into another repo:

```bash
./scripts/install-codex.sh --repo /path/to/your-repo
```

Install globally for Codex:

```bash
./scripts/install-codex.sh --user
```

Remote one-liner:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Threefold-Solutions/church-skills/main/scripts/install-all.sh)"
```

## Development

Validate manifests and skills before opening a PR:

```bash
./scripts/validate.sh
```

Build distributable artifacts:

```bash
./scripts/build-universal.sh
```

Run the full install smoke suite:

```bash
./scripts/test-installation.sh
```

The same checks run in GitHub Actions for pushes and pull requests to `main`.

## Repo structure

```
claude-ai-skills/                   # Claude.ai web Skills (.skill bundles, unzipped)
  <skill-name>/
    SKILL.md

.claude-plugin/marketplace.json     # Claude Code marketplace manifest
.agents/plugins/marketplace.json    # Codex / cross-platform plugin registry
plugins/                            # Claude Code + Codex plugins
  <plugin-name>/
    .claude-plugin/plugin.json
    .codex-plugin/plugin.json
    commands/
    skills/
      <skill-name>/SKILL.md
```

A skill may live in one or both trees:

- **`claude-ai-skills/<name>/SKILL.md`** uses Claude.ai web tooling (`ask_user_input_v0`, `present_files`, `/mnt/user-data/outputs/`).
- **`plugins/<plugin>/skills/<name>/SKILL.md`** uses Claude Code tooling (`AskUserQuestion`, `Write`, normal filesystem paths).

See [`CLAUDE.md`](./CLAUDE.md) or [`AGENTS.md`](./AGENTS.md) for the full conventions.

## Contributing

Issues and PRs welcome — especially from church staff sharing real workflows that would benefit from a skill.

## License

MIT — see [LICENSE](./LICENSE).
