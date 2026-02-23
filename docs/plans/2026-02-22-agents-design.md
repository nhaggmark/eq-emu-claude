# Agent System Design

**Date**: 2026-02-22
**Status**: Approved

## Context

The EQ project needs specialized Claude Code agents for different aspects of
development — game design, lore, C++ server code, Lua/Perl scripting, database
work, configuration, infrastructure, and validation. The user orchestrates agents
directly, using them individually or as coordinated teams.

## Decision

**Approach A: Shared Skill + Flat Agents.** A single `base-agent.md` skill provides
project context. Each agent is a standalone markdown file referencing that skill.
All source files live in `claude/` (version controlled in eq-emu-claude), with
symlinks from `.claude/` for Claude Code discovery.

### Alternatives Considered

- **Approach B (Layered Skills)**: Multiple composable skills. Over-engineered for
  10 agents; harder to understand what each agent knows.
- **Approach C (Monolithic)**: Full context in every agent file. Massive duplication;
  updating context means editing 10 files.

## File Layout

```
claude/
├── agents/
│   ├── AGENTS.md              Agent catalog and usage guide
│   ├── game-designer.md       Advisory: mechanics, balance, features
│   ├── lore-master.md         Advisory: dialogue, story, faction lore
│   ├── c-expert.md            Expert: C++ server source
│   ├── lua-expert.md          Expert: Lua quest scripts (preferred for new work)
│   ├── perl-expert.md         Expert: Perl quest maintenance
│   ├── data-expert.md         Expert: MariaDB/SQL database
│   ├── config-expert.md       Expert: rules, eqemu_config, .env
│   ├── infra-expert.md        Expert: Docker, compose, Makefile, build
│   └── game-tester.md         Validation: DB integrity, syntax, logs
├── skills/
│   └── base-agent.md          Shared project context skill
└── docs/topography/           Reference docs agents consult

.claude/
├── agents -> ../claude/agents  Symlink
└── skills -> ../claude/skills  Symlink
```

## Agent Design Decisions

### Permission Model

- **Advisory agents** (game-designer, lore-master): `permissionMode: plan`,
  read-only tools only. They research and recommend; don't write code.
- **Tech experts** (c-expert, lua-expert, perl-expert, data-expert, config-expert,
  infra-expert): Full tool access. Can read and write code in their domain.
- **Validation agent** (game-tester): Full tool access for running queries and
  reading logs, but instructions say to report findings, not make fixes.

### Model Selection

- **Opus** for agents requiring deep reasoning: game-designer, lore-master, c-expert
  (complex C++ codebase).
- **Sonnet** for agents doing focused, well-scoped work: lua-expert, perl-expert,
  data-expert, config-expert, infra-expert, game-tester.

### Shared Context via Skill

`base-agent.md` provides: project summary, repository layout, key paths, database
credentials, build cycle, and conventions (era lock, Lua preferred, etc.). Injected
via the `skills:` frontmatter field on every agent.

### Topography Docs as Reference

Agents are instructed to read the relevant topography doc before investigating.
This keeps agent definitions concise while giving them deep codebase knowledge
on demand.

## Implementation Tasks

1. Create `claude/skills/base-agent.md`
2. Create all 9 agent files in `claude/agents/`
3. Create `claude/agents/AGENTS.md` catalog
4. Create symlinks: `.claude/agents` → `claude/agents`, `.claude/skills` → `claude/skills`
5. Commit and push to eq-emu-claude
6. Verify agents are discoverable by Claude Code
