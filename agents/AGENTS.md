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
bootstrap-agent → design team (game-designer + lore-master) → architect → implementation experts → game-tester
```

### 1. Bootstrap

> Use the bootstrap-agent to set up a workspace for [feature description]

Creates a feature branch in `eqemu/`, sets up `claude/project-work/<branch>/`
folders for all agents, copies templates.

### 2. Design (game-designer + lore-master team)

> Spawn the design team: game-designer and lore-master as teammates

The game-designer and lore-master are spawned together as a team. The
game-designer leads PRD creation while the lore-master provides lore review,
faction verification, and era compliance checks via `SendMessage`.

The PRD is not handed off until the lore-master signs off on lore continuity.

Output: `project-work/<branch>/game-designer/prd.md`

### 3. Plan (architect)

> Use the architect to assess the PRD and create the implementation plan

Deep-dives the codebase, performs 4 review passes (feasibility, simplicity,
antagonistic, integration), writes the architecture doc at
`project-work/<branch>/architect/architecture.md`. Assigns tasks to experts.

### 4. Implement (expert team)

> Spawn the implementation team with all assigned experts as teammates

The architect's implementation sequence names which experts are needed.
Spawn all assigned experts together as a team. They coordinate via
`SendMessage` — notifying teammates when dependencies are complete,
flagging cross-system issues, and confirming integration points.

Experts work through the task list in dependency order, updating
status.md as they complete each task.

### 5. Validate (game-tester)

> Use the game-tester to build a test plan and validate the implementation

The game-tester reads the PRD, architecture plan, and completed work to
produce a **detailed test plan** with two parts:
1. **Server-side validation** — DB integrity, script syntax, log analysis
   (executed by the game-tester directly)
2. **In-game testing guide** — step-by-step instructions for the user to
   manually validate gameplay, NPC interactions, and data correctness
   using the Titanium client (since AI cannot play the game)

If FAIL: game-tester logs blockers in status.md, user dispatches the
responsible expert to fix, then re-validates.

### 6. Complete

> Review status.md and merge the feature branch

After game-tester reports PASS:
1. Review `status.md` — all tasks Complete, no open Blockers
2. Merge the feature branch: `cd /mnt/d/Dev/EQ/eqemu && git checkout main && git merge <branch-name>`
3. Rebuild the server if C++ changed
4. Mark the feature as done in status.md (set all phases to Complete)

## Agent Catalog

### Workflow

| Agent | Model | Use When |
|-------|-------|----------|
| **bootstrap-agent** | sonnet | Starting a new feature — creates branch and workspace |

### Design Team (spawned together, plan mode)

| Agent | Model | Use When |
|-------|-------|----------|
| **game-designer** | opus | Leads PRD creation — mechanics, balance, player experience |
| **lore-master** | sonnet | Reviews PRD for lore continuity, faction accuracy, era compliance |

These two agents are always spawned as teammates during the Design phase.
They coordinate via `SendMessage`. The game-designer drives; the lore-master
reviews and flags issues. The PRD requires lore-master sign-off before handoff.

### Advisory (read-only, plan mode)

| Agent | Model | Use When |
|-------|-------|----------|
| **architect** | opus | Assessing PRDs, planning cross-system implementation, assigning expert tasks |

### Implementation Team (spawned together, write access)

| Agent | Model | Use When |
|-------|-------|----------|
| **c-expert** | sonnet | Modifying server C++ — combat, spells, AI, bots, networking, entity systems |
| **lua-expert** | sonnet | Writing new quest scripts, encounter scripts, lua_modules, lua_mod hooks |
| **perl-expert** | sonnet | Maintaining existing Perl scripts, planning Perl → Lua migration |
| **data-expert** | sonnet | Querying/modifying database — NPCs, items, loot, spawns, faction, rules |
| **config-expert** | sonnet | Tuning via rules, eqemu_config.json, login.json, .env settings |
| **infra-expert** | sonnet | Docker, compose files, Makefile, build pipeline, virtualization, tooling |

These experts are spawned together as teammates during the Implementation phase.
Only spawn the experts the architect assigned tasks to. They coordinate via
`SendMessage` — notifying when dependencies complete, flagging cross-system
issues, and confirming integration points.

### Validation

| Agent | Model | Use When |
|-------|-------|----------|
| **game-tester** | sonnet | Building test plans, server-side validation, writing in-game testing guides |

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
