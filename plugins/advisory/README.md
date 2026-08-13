# advisory

Simulated advisory panels that pressure-test church-facing decisions from multiple
staff perspectives before you commit.

The premise: the people who will actually live with a decision — the secretary who
maintains the calendar, the exec pastor who signs the invoice, the kids director who
just needs her page to not break — disagree with each other in useful ways. A panel
that surfaces that disagreement is worth more than a summary that smooths it over.

## Installation

### Claude Code

```text
/plugin marketplace add Threefold-Solutions/church-skills
/plugin install advisory@church-skills
```

### Codex CLI

Cloning the `church-skills` repo and running Codex inside it loads this plugin
automatically via `.agents/plugins/marketplace.json`.

To install this plugin into another repo:

```bash
./scripts/install-codex.sh --repo /path/to/your-repo
```

## Skills

| Skill | Description |
|-------|-------------|
| `staff-review` | Six church staff personas react, debate, and deliver a unified recommendation on anything that touches church operations |

### `staff-review`

Six personas — church secretary, senior pastor, worship/creative director,
communications director, executive pastor, children's ministry director — run a
three-round process over whatever you put in front of them:

1. **Individual reactions** — each member's honest first take
2. **The debate** — members push back on each other; the real tensions surface here
3. **Rachel's unified recommendation** — do this / don't do this / still debating

Point it at a screenshot, a mockup, a pricing page, a feature proposal, marketing
copy, or just a question:

```text
/advisory:staff-review is $47/month too much for a church of 200?
/advisory:staff-review ./designs/onboarding-v3.png
```

It also auto-invokes on phrasings like "would this work for a church?" or "what would
church staff think of this?".

A Claude.ai web version ships at
[`claude-ai-skills/church-staff-review/`](../../claude-ai-skills/church-staff-review/)
for staff using Claude in a browser. It carries the skill name `church-staff-review`
there, since the standalone bundle has no plugin namespace to supply the church
context.

## Commands

_Slash commands land here as they ship._

## License

MIT — see the [repo LICENSE](../../LICENSE).
