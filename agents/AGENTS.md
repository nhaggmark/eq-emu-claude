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

## Feature Workflow

For new features and projects, follow this pipeline:

```
bootstrap-agent → game-designer → architect → implementation experts → game-tester
```

### 1. Bootstrap

> Use the bootstrap-agent to set up a workspace for [feature description]

Creates a feature branch in `eqemu/`, sets up `claude/project-work/<branch>/`
folders for all agents, copies templates.

### 2. Design (game-designer)

> Use the game-designer to fill out the PRD

Brainstorms with you, asks clarifying questions, writes the PRD at
`project-work/<branch>/game-designer/prd.md`. No code — pure design.

### 3. Plan (architect)

> Use the architect to assess the PRD and create the implementation plan

Deep-dives the codebase, performs 4 review passes (feasibility, simplicity,
antagonistic, integration), writes the architecture doc at
`project-work/<branch>/architect/architecture.md`. Assigns tasks to experts.

### 4. Implement (experts)

> Dispatch tasks to [agent] per the architect's implementation sequence

Experts execute their assigned tasks in dependency order.

### 5. Validate (game-tester)

> Use the game-tester to validate the implementation

Server-side checks: DB integrity, script syntax, log analysis.

## Agent Catalog

### Workflow

| Agent | Model | Use When |
|-------|-------|----------|
| **bootstrap-agent** | sonnet | Starting a new feature — creates branch and workspace |

### Advisory (read-only, plan mode)

| Agent | Model | Use When |
|-------|-------|----------|
| **game-designer** | opus | Designing features, brainstorming mechanics, writing PRDs |
| **lore-master** | sonnet | Writing quest dialogue, NPC personalities, story arcs, faction lore |
| **architect** | opus | Assessing PRDs, planning cross-system implementation, assigning expert tasks |

### Tech Experts (write access)

| Agent | Model | Use When |
|-------|-------|----------|
| **c-expert** | sonnet | Modifying server C++ — combat, spells, AI, bots, networking, entity systems |
| **lua-expert** | sonnet | Writing new quest scripts, encounter scripts, lua_modules, lua_mod hooks |
| **perl-expert** | sonnet | Maintaining existing Perl scripts, planning Perl → Lua migration |
| **data-expert** | sonnet | Querying/modifying database — NPCs, items, loot, spawns, faction, rules |
| **config-expert** | sonnet | Tuning via rules, eqemu_config.json, login.json, .env settings |
| **infra-expert** | sonnet | Docker, compose files, Makefile, build pipeline, deployment |

### Validation

| Agent | Model | Use When |
|-------|-------|----------|
| **game-tester** | sonnet | Verifying changes — DB integrity, script syntax, log analysis, rule validation |

## Shared Context

- **base-agent** skill — project context (repos, paths, conventions) loaded by all agents
- **superpowers:using-superpowers** skill — problem-solving metaskill loaded by all agents
- **Context7 + WebFetch** — anti-slop doctrine on all implementation experts
- **Topography docs** — `claude/docs/topography/` referenced by all agents

## Project Work Structure

Each feature gets its own folder under `claude/project-work/`. Every agent
gets a `context/` subfolder for working notes, research, and intermediate
results. A `status.md` at the root tracks the workflow.

```
claude/project-work/<branch-name>/
├── status.md                  ← Workflow tracker (status, handoffs, questions, decisions)
├── game-designer/
│   ├── prd.md                 ← PRD (from template)
│   └── context/               ← Design research, brainstorm notes
├── architect/
│   ├── architecture.md        ← Implementation plan (from template)
│   └── context/               ← Code analysis, feasibility notes
├── lore-master/
│   └── context/
├── c-expert/
│   └── context/
├── lua-expert/
│   └── context/
├── perl-expert/
│   └── context/
├── data-expert/
│   └── context/
├── config-expert/
│   └── context/
├── infra-expert/
│   └── context/
└── game-tester/
    └── context/               ← Validation results, test logs
```

Templates live in `claude/templates/` (prd.md, architecture.md, status.md).

## Ad-Hoc Usage

Not everything needs the full workflow. For quick tasks:

**Consult a single agent:**
> Use the game-designer to reason about companion power scaling

**Quick implementation:**
> Use the data-expert to add a new NPC to East Commonlands

**Validation after changes:**
> Use the game-tester to validate the loot table changes we just made
