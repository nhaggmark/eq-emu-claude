# EQ Server Agents

Custom Claude Code agents for the EQ server project. Each agent is a specialist
that can be consulted individually or coordinated as a team.

## Setup

Agent and skill source files live in `claude/` (version controlled). Claude Code
needs symlinks to discover them:

```bash
ln -s ../claude/agents /mnt/d/Dev/EQ/.claude/agents
ln -s ../claude/skills /mnt/d/Dev/EQ/.claude/skills
```

## Agent Catalog

### Advisory (read-only, plan mode)

| Agent | Model | Use When |
|-------|-------|----------|
| **game-designer** | opus | Designing features, balancing encounters, planning loot/economy, companion system mechanics |
| **lore-master** | opus | Writing quest dialogue, NPC personalities, story arcs, faction lore, era-lock compliance |
| **architect** | opus | Planning cross-system features, breaking designs into expert tasks, deciding which layer owns a change |

### Tech Experts (write access)

| Agent | Model | Use When |
|-------|-------|----------|
| **c-expert** | opus | Modifying server C++ — combat, spells, AI, bots, networking, entity systems |
| **lua-expert** | sonnet | Writing new quest scripts, encounter scripts, lua_modules, lua_mod hooks |
| **perl-expert** | sonnet | Maintaining existing Perl scripts, planning Perl → Lua migration |
| **data-expert** | sonnet | Querying/modifying database — NPCs, items, loot, spawns, faction, rules |
| **config-expert** | sonnet | Tuning via rules, eqemu_config.json, login.json, .env settings |
| **infra-expert** | sonnet | Docker, compose files, Makefile, build pipeline, deployment |

### Validation

| Agent | Model | Use When |
|-------|-------|----------|
| **game-tester** | sonnet | Verifying changes — DB integrity, script syntax, log analysis, rule validation |

## Shared Skill

All agents load `base-agent` via the `skills:` field, which provides project
context (repos, paths, conventions, build cycle).

## Usage Examples

**Consult a single agent:**
> Use the game-designer to design the companion recruitment mechanic

**Plan a feature:**
> Have the architect break down the companion system into tasks for the experts

**Chain agents:**
> Have the game-designer spec out a loot rebalance, then the data-expert implement it

**Team swarm:**
> Use the lua-expert and data-expert together to add a new quest with custom loot

**Validation after changes:**
> Use the game-tester to validate the loot table changes we just made
