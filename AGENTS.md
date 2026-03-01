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
┌─────────────┐    ┌─────────────────┐    ┌───────────────────┐    ┌──────────────────────┐    ┌──────────────┐    ┌────────────┐
│  BOOTSTRAP   │───▶│  DESIGN TEAM     │───▶│  ARCHITECTURE TEAM │───▶│  IMPLEMENTATION TEAM  │───▶│  GAME-TESTER  │───▶│  COMPLETE   │
│  (Phase 1)   │    │  (Phase 2)       │    │  (Phase 3)         │    │  (Phase 4)            │    │  (Phase 5)    │    │  (Phase 6)  │
└─────────────┘    └─────────────────┘    └───────────────────┘    └──────────────────────┘    └──────────────┘    └────────────┘
  Solo agent         Team spawn             Team spawn               Scoped team spawn             Solo agent         User action
  sonnet             opus + sonnet          opus + 2× sonnet         sonnet × (arch-assigned)      sonnet
```

### IMPORTANT: Team Spawn Rules

1. **Bootstrap is MANDATORY.** Always start with bootstrap-agent. Never manually create project-work folders.
2. **Multi-agent phases MUST use Claude Code agent teams.** Use `TeamCreate` → `Task` with `team_name` → `SendMessage` for coordination.
3. **All inter-agent exchanges MUST be logged** to `agent-conversations.md`. Even "no concerns" reviews.
4. **Shut down teams after each phase.** Use `SendMessage type="shutdown_request"` then `TeamDelete`.

### Team Lifecycle Per Phase

```
TeamCreate(team_name, description)
  → Task(agent1, team_name=...) + Task(agent2, team_name=...)
  → TaskCreate(tasks for the team)
  → Agents work via SendMessage + TaskUpdate
  → COMMIT GATE (orchestrator verifies all repos clean — see below)
  → SendMessage(type="shutdown_request") to each agent
  → Agents WIP-commit before approving shutdown (see below)
  → TeamDelete
  → DIRTY TREE GATE (orchestrator verifies all repos clean before next phase)
```

### Agent Shutdown Protocol (MANDATORY)

When an agent receives `shutdown_request`, it MUST do the following
BEFORE approving shutdown:

1. Check `git status` in every repo it modified during this phase
2. If ANY uncommitted changes exist:
   - Stage only the files it changed (explicit paths, never `git add -A`)
   - Commit with message: `WIP: <agent-name> - <brief task description>`
   - Push to the feature branch
3. Only THEN approve the shutdown via `shutdown_response`

Agents that did not modify any files may approve shutdown immediately.

### Orchestrator Phase Transition Gates (MANDATORY)

Every phase transition follows this exact sequence. No exceptions.

```
1. COMMIT GATE — Before shutting down the current team:
   Orchestrator runs in ALL repos (eqemu/, akk-stack/, claude/):
     git status
     git log --oneline -3
   If ANY repo has uncommitted changes → STOP. Do not proceed.
   Either the responsible agent commits, or the orchestrator
   asks the user how to proceed. Never discard uncommitted work.

2. TEAM SHUTDOWN — SendMessage(type="shutdown_request") to each agent,
   then TeamDelete after all agents confirm shutdown.

3. DIRTY TREE GATE — Before creating the next team:
   Orchestrator runs in ALL repos (eqemu/, akk-stack/, claude/):
     git status
   If ANY repo has uncommitted or untracked changes → STOP.
   Resolve before proceeding. A dirty tree at phase start means
   the previous phase left orphaned work.

4. TEAM CREATE — TeamCreate for the next phase.
```

The orchestrator NEVER skips steps 1 or 3. If a gate fails, the orchestrator
reports the state to the user and waits for instructions.

---

## Phase 1: Bootstrap (MANDATORY)

```
╔══════════════════════════════════════════════════════════════════════╗
║  BOOTSTRAP — MANDATORY ENTRY POINT                                 ║
║  Agent: bootstrap-agent (sonnet)                                   ║
║  Mode: write access                                                ║
║  Skills: superpowers:using-superpowers                             ║
║                                                                    ║
║  ⚠ NEVER skip this phase. Never manually create project-work      ║
║    folders. Skipping leads to naming inconsistencies, missing      ║
║    templates, and broken agent handoffs.                           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  User prompt: "Use bootstrap-agent to set up [feature]"            ║
║                                                                    ║
║  ┌──────────────────────────────────────────────────┐              ║
║  │ 1. Derive branch name (kebab-case)               │              ║
║  │    "companion recruitment" → feature/companion-recruitment       ║
║  │                                                  │              ║
║  │ 2. Create feature branch in eqemu/               │              ║
║  │    git checkout -b <branch-name>                 │              ║
║  │                                                  │              ║
║  │ 3. Create project-work folder tree               │              ║
║  │    (11 agent folders + context/ subfolders)      │              ║
║  │                                                  │              ║
║  │ 4. Create tmp folder                             │              ║
║  │    claude/tmp/<branch-name>/ (gitignored)        │              ║
║  │                                                  │              ║
║  │ 5. Copy & initialize templates                   │              ║
║  │    (see Template Flow below)                     │              ║
║  │                                                  │              ║
║  │ 6. Report + hand off to design team              │              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  ├── eqemu/ branch: feature/<branch-name>                          ║
║  ├── akk-stack/ branch: feature/<branch-name>                      ║
║  ├── claude/ branch: feature/<branch-name>                         ║
║  ├── claude/tmp/<branch-name>/  (gitignored temp storage)          ║
║  └── claude/project-work/<branch-name>/                            ║
║      ├── status.md               ◄── templates/status.md           ║
║      ├── agent-conversations.md  ◄── templates/agent-conversations ║
║      ├── game-designer/                                            ║
║      │   ├── prd.md              ◄── templates/prd.md              ║
║      │   └── context/                                              ║
║      ├── lore-master/                                              ║
║      │   ├── lore-notes.md       ◄── templates/lore-notes.md      ║
║      │   └── context/                                              ║
║      ├── architect/                                                ║
║      │   ├── architecture.md     ◄── templates/architecture.md    ║
║      │   └── context/                                              ║
║      ├── c-expert/                                                 ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      ├── lua-expert/                                               ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      ├── perl-expert/                                              ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      ├── data-expert/                                              ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      ├── config-expert/                                            ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      ├── protocol-agent/                                           ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      ├── infra-expert/                                             ║
║      │   ├── dev-notes.md        ◄── templates/dev-notes.md       ║
║      │   └── context/                                              ║
║      └── game-tester/                                              ║
║          ├── test-plan.md        ◄── templates/test-plan.md       ║
║          └── context/                                              ║
║                                                                    ║
║  HANDOFF: "Spawn the design team — game-designer + lore-master"    ║
║  status.md: Bootstrap=Complete, Current phase=Design               ║
╚══════════════════════════════════════════════════════════════════════╝
         │
         ▼
```

## Phase 2: Design

```
╔══════════════════════════════════════════════════════════════════════╗
║  DESIGN TEAM  (Claude Code agent team)                             ║
║  Coordination: SendMessage                                         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  TEAM SETUP:                                                       ║
║  TeamCreate(team_name="<branch>-design",                           ║
║             description="Design team for <feature>")               ║
║  Task(name="game-designer", team_name="<branch>-design", ...)      ║
║  Task(name="lore-master", team_name="<branch>-design", ...)        ║
║  TaskCreate(subject="Write PRD", owner="game-designer")            ║
║  TaskCreate(subject="Review PRD for lore", owner="lore-master")    ║
║                                                                    ║
║  Full spawn commands:                                              ║
║  TeamCreate: team_name="<branch>-design",                          ║
║              description="Design team for <feature>"               ║
║                                                                    ║
║  Task: subagent_type="general-purpose", name="game-designer",      ║
║        team_name="<branch>-design", mode="plan",                   ║
║        prompt="[Read claude/agents/game-designer.md and paste      ║
║                its FULL contents here as the agent's instructions]  ║
║                Feature: <description>.                             ║
║                Work dir: claude/project-work/<branch>/"             ║
║                                                                    ║
║  Task: subagent_type="general-purpose", name="lore-master",        ║
║        team_name="<branch>-design", mode="plan",                   ║
║        prompt="[Read claude/agents/lore-master.md and paste        ║
║                its FULL contents here as the agent's instructions]  ║
║                Feature: <description>.                             ║
║                Work dir: claude/project-work/<branch>/"             ║
║                                                                    ║
║  TaskCreate: subject="Write PRD", owner="game-designer"            ║
║  TaskCreate: subject="Review PRD for lore compliance",             ║
║              owner="lore-master", addBlockedBy=["PRD task ID"]     ║
║                                                                    ║
║  User prompt: "Create the design team and spawn game-designer      ║
║                and lore-master as teammates"                       ║
║                                                                    ║
║  ┌─────────────────────────────┐  SendMessage  ┌────────────────┐  ║
║  │ GAME-DESIGNER (opus)        │◄────────────▶│ LORE-MASTER     │  ║
║  │ Mode: plan (read-only)      │               │ (sonnet)        │  ║
║  │ Skills: superpowers:        │               │ Mode: plan      │  ║
║  │   using-superpowers         │               │ Skills: super-  │  ║
║  │                             │               │   powers:using- │  ║
║  │                             │               │   superpowers   │  ║
║  │ LEADS:                      │               │                 │  ║
║  │ • Brainstorm (skill)        │               │ REVIEWS:        │  ║
║  │ • Write PRD sections        │  ──────────▶  │ • Era compliance│  ║
║  │ • Present approaches        │  "review this"│ • Faction       │  ║
║  │ • Finalize PRD              │               │   accuracy      │  ║
║  │                             │  ◀──────────  │ • NPC character │  ║
║  │                             │  "APPROVED /  │ • Zone          │  ║
║  │                             │   ISSUE /     │   authenticity  │  ║
║  │                             │   SUGGESTION" │ • Deity/race    │  ║
║  │                             │               │   accuracy      │  ║
║  └─────────────────────────────┘               └────────────────┘  ║
║                                                                    ║
║  LORE REFERENCES (both agents):                                    ║
║  • https://everquest.fandom.com/wiki/Lore  — Ages of Norrath      ║
║  • https://www.eqatlas.com                 — Classic zone maps     ║
║  • https://everquest.allakhazam.com        — Items, spells, quests ║
║                                                                    ║
║  FLOW:                                                             ║
║  1. game-designer messages lore-master with feature concept        ║
║  2. lore-master researches and sends lore context proactively      ║
║  3. game-designer brainstorms (superpowers:brainstorming skill)    ║
║  4. game-designer sends PRD sections → lore-master reviews         ║
║  5. Iterate until lore-master approves all sections                ║
║  6. game-designer sends full PRD for final lore sign-off           ║
║  7. lore-master approves → game-designer declares PRD ready        ║
║                                                                    ║
║  GATE: PRD cannot hand off without lore-master sign-off            ║
║                                                                    ║
║  INPUTS:                                                           ║
║  ├── templates/prd.md (pre-copied to game-designer/prd.md)        ║
║  ├── claude/PROJECT.md                                             ║
║  ├── claude/docs/topography/*.md                                   ║
║  └── akk-stack/server/quests/ (existing patterns)                  ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  ├── game-designer/prd.md          ◄── FILLED IN (all sections)    ║
║  ├── game-designer/context/        ◄── Design notes, brainstorm    ║
║  ├── lore-master/lore-notes.md     ◄── FILLED IN (research,        ║
║  │                                      reviews, sign-off)         ║
║  ├── lore-master/context/          ◄── Raw lore research artifacts ║
║  ├── agent-conversations.md        ◄── Design team SendMessage log ║
║  └── status.md                     ◄── Design=Complete             ║
║                                                                    ║
║  TEAM CLEANUP:                                                     ║
║  SendMessage(type="shutdown_request") to game-designer             ║
║  SendMessage(type="shutdown_request") to lore-master               ║
║  TeamDelete                                                        ║
║                                                                    ║
║  HANDOFF: "Create the architecture team and spawn architect,       ║
║            protocol-agent, and config-expert as teammates"         ║
║  status.md: Design=Complete, Current phase=Architecture            ║
║  Handoff log: "design team → architect" + lore-master sign-off     ║
╚══════════════════════════════════════════════════════════════════════╝
         │
         ▼
```

## Phase 3: Architecture

```
╔══════════════════════════════════════════════════════════════════════╗
║  ARCHITECTURE TEAM  (Claude Code agent team)                       ║
║  Coordination: SendMessage                                         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  TEAM SETUP:                                                       ║
║  TeamCreate(team_name="<branch>-architecture",                     ║
║             description="Architecture team for <feature>")         ║
║  Task(name="architect", team_name="<branch>-architecture", ...)    ║
║  Task(name="protocol-agent", team_name="...", ...)                 ║
║  Task(name="config-expert", team_name="...", ...)                  ║
║  TaskCreate(subject="Write architecture plan", owner="architect")  ║
║  TaskCreate(subject="Advise on client feasibility",                ║
║             owner="protocol-agent")                                ║
║  TaskCreate(subject="Advise on rules/config", owner="config-expert")║
║                                                                    ║
║  Full spawn commands:                                              ║
║  TeamCreate: team_name="<branch>-architecture",                    ║
║              description="Architecture team for <feature>"         ║
║                                                                    ║
║  Task: subagent_type="general-purpose", name="architect",          ║
║        team_name="<branch>-architecture", mode="plan",             ║
║        prompt="[Read claude/agents/architect.md and paste its      ║
║                FULL contents here as the agent's instructions]      ║
║                PRD at: claude/project-work/<branch>/                ║
║                game-designer/prd.md"                               ║
║                                                                    ║
║  Task: subagent_type="general-purpose", name="protocol-agent",     ║
║        team_name="<branch>-architecture",                          ║
║        prompt="[Read claude/agents/protocol-agent.md and paste     ║
║                its FULL contents here as the agent's instructions]  ║
║                Wait for questions from the architect                ║
║                via SendMessage."                                   ║
║                                                                    ║
║  Task: subagent_type="general-purpose", name="config-expert",      ║
║        team_name="<branch>-architecture",                          ║
║        prompt="[Read claude/agents/config-expert.md and paste      ║
║                its FULL contents here as the agent's instructions]  ║
║                Wait for questions from the architect                ║
║                via SendMessage."                                   ║
║                                                                    ║
║  TaskCreate: subject="Write architecture plan", owner="architect"  ║
║  TaskCreate: subject="Advise on client feasibility",               ║
║              owner="protocol-agent"                                ║
║  TaskCreate: subject="Advise on rule/config alternatives",         ║
║              owner="config-expert"                                 ║
║                                                                    ║
║  User prompt: "Create the architecture team and spawn architect,   ║
║                protocol-agent, and config-expert as teammates"     ║
║                                                                    ║
║  ┌───────────────────────┐                                         ║
║  │ ARCHITECT (opus)      │        SendMessage                      ║
║  │ Mode: plan            │◄──────────────────────┐                 ║
║  │ LEADS — ultimate      │                       │                 ║
║  │ arbiter of all        │   ┌───────────────────┴──────────┐      ║
║  │ architecture          │   │                              │      ║
║  │ decisions             │   │  ┌────────────────────────┐  │      ║
║  │                       │──▶│  │ PROTOCOL-AGENT         │  │      ║
║  │ Absorbs PRD           │   │  │ (sonnet)               │  │      ║
║  │ Deep-dives code       │   │  │                        │  │      ║
║  │ Determines approach   │   │  │ ADVISES ON:            │  │      ║
║  │ 4 review passes       │   │  │ • Titanium client caps │  │      ║
║  │ Writes architecture   │   │  │ • Opcode availability  │  │      ║
║  │ Assigns tasks         │   │  │ • Packet constraints   │  │      ║
║  │                       │   │  │ • Wire format limits   │  │      ║
║  │ ASKS:                 │   │  └────────────────────────┘  │      ║
║  │ "Can the client do X?"│   │                              │      ║
║  │ "Does a rule exist?"  │   │  ┌────────────────────────┐  │      ║
║  │ "What's the simplest  │   │  │ CONFIG-EXPERT          │  │      ║
║  │  approach?"           │──▶│  │ (sonnet)               │  │      ║
║  │                       │   │  │                        │  │      ║
║  └───────────────────────┘   │  │ ADVISES ON:            │  │      ║
║                              │  │ • Existing rule values  │  │      ║
║                              │  │ • Config alternatives   │  │      ║
║                              │  │ • Rule design for new   │  │      ║
║                              │  │   code changes          │  │      ║
║                              │  └────────────────────────┘  │      ║
║                              └──────────────────────────────┘      ║
║                                                                    ║
║  FLOW:                                                             ║
║  1. architect absorbs PRD, flags gaps                              ║
║  2. architect deep-dives code (topography + actual source)         ║
║  3. architect → config-expert: "What can be done with rules?"      ║
║  4. architect → protocol-agent: "Client feasibility for X?"        ║
║  5. Advisors research and respond with specific findings           ║
║  6. architect determines approach (least-invasive-first)           ║
║  7. Four review passes (advisors consulted on feasibility          ║
║     and antagonistic passes)                                       ║
║  8. architect writes architecture doc                              ║
║  9. architect updates status.md + hands off                        ║
║                                                                    ║
║  DECISION FRAMEWORK (agent assignment):                            ║
║  ┌────────────────────────────────────┬─────────────────────┐      ║
║  │ Need                               │ Agent               │      ║
║  ├────────────────────────────────────┼─────────────────────┤      ║
║  │ Tune a number                      │ config-expert       │      ║
║  │ Change server config               │ config-expert       │      ║
║  │ Add/modify game content            │ data-expert         │      ║
║  │ Add NPC behavior/dialogue          │ lua-expert          │      ║
║  │ Override combat/XP formulas        │ lua-expert          │      ║
║  │ Change core server logic           │ c-expert            │      ║
║  │ Client-server protocol work        │ protocol-agent      │      ║
║  │ Change deployment/build            │ infra-expert        │      ║
║  │ Maintain Perl scripts              │ perl-expert         │      ║
║  └────────────────────────────────────┴─────────────────────┘      ║
║                                                                    ║
║  INPUTS:                                                           ║
║  ├── game-designer/prd.md              (the approved PRD)          ║
║  ├── lore-master/lore-notes.md         (lore constraints)          ║
║  ├── claude/docs/topography/*.md       (5 topography docs)         ║
║  └── eqemu/ source code               (Grep/Read actual files)     ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  ├── architect/architecture.md  ◄── FILLED IN (all sections)       ║
║  │   ├── Executive Summary                                         ║
║  │   ├── Existing System Analysis (current state + gap)            ║
║  │   ├── Technical Approach (layers, data model, code changes)     ║
║  │   ├── Implementation Sequence (ordered, agent-assigned tasks)   ║
║  │   ├── Risk Assessment (technical, compat, performance)          ║
║  │   ├── Review Passes (4 passes documented)                       ║
║  │   └── Validation Plan (for game-tester)                         ║
║  ├── architect/context/         ◄── Code analysis, feasibility     ║
║  ├── agent-conversations.md     ◄── Architecture team exchanges    ║
║  └── status.md                  ◄── Architecture=Complete,         ║
║      ├── Implementation Tasks table populated                      ║
║      ├── Handoff log: architecture team → implementation team      ║
║      ├── Decision Log entries                                      ║
║      └── Open Questions (if any)                                   ║
║                                                                    ║
║  NOTE: protocol-agent and config-expert may also appear in the     ║
║  implementation team if the architect assigns them tasks. They      ║
║  serve dual roles: advisors during planning, implementers during   ║
║  execution.                                                        ║
║                                                                    ║
║  TEAM CLEANUP:                                                     ║
║  SendMessage(type="shutdown_request") to architect                 ║
║  SendMessage(type="shutdown_request") to protocol-agent            ║
║  SendMessage(type="shutdown_request") to config-expert             ║
║  TeamDelete                                                        ║
║                                                                    ║
║  HANDOFF: "Create the implementation team and spawn [assigned      ║
║            experts] as teammates"                                  ║
║  status.md: Architecture=Complete, Current phase=Implementation    ║
╚══════════════════════════════════════════════════════════════════════╝
         │
         ▼
```

## Phase 4: Implementation

```
╔══════════════════════════════════════════════════════════════════════╗
║  IMPLEMENTATION TEAM  (Claude Code agent team)                     ║
║  Coordination: SendMessage + TaskCreate/TaskUpdate                 ║
║  ONLY spawn agents listed in architecture.md "Required             ║
║  Implementation Agents" — never the full roster                    ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  TEAM SETUP:                                                       ║
║  TeamCreate(team_name="<branch>-implementation",                   ║
║             description="Implementation team for <feature>")       ║
║  # Spawn ONLY assigned experts:                                    ║
║  Task(name="<expert>", team_name="<branch>-implementation", ...)   ║
║  # Create tasks from architecture plan:                            ║
║  TaskCreate per task, with addBlockedBy for dependencies           ║
║                                                                    ║
║  Full spawn commands:                                              ║
║  TeamCreate: team_name="<branch>-implementation",                  ║
║              description="Implementation team for <feature>"       ║
║                                                                    ║
║  # Spawn ONLY the experts the architect assigned tasks to:         ║
║  Task: subagent_type="general-purpose", name="<expert-name>",      ║
║        team_name="<branch>-implementation",                        ║
║        prompt="[Read claude/agents/<expert-name>.md and paste its  ║
║                FULL contents here as the agent's instructions]      ║
║                Architecture plan at: claude/project-work/<branch>/ ║
║                architect/architecture.md                           ║
║                Your tasks: [list from architecture plan]"          ║
║                                                                    ║
║  NOTE on mode: architect and protocol-agent use mode="plan"        ║
║  during architecture phase. Implementation experts do NOT set      ║
║  mode (they need write access). Check each agent's frontmatter     ║
║  permissionMode field — only set mode="plan" if it says plan.      ║
║                                                                    ║
║  # Create tasks from the architecture plan's implementation        ║
║  # sequence:                                                       ║
║  TaskCreate: subject="<task description>",                         ║
║              owner="<assigned-expert>",                             ║
║              addBlockedBy=[<dependency task IDs>]                  ║
║  # ... one per task in the implementation sequence                 ║
║                                                                    ║
║  User prompt: "Create the implementation team and spawn            ║
║                [agent-a] and [agent-b] as teammates"               ║
║  (names come from architect's Required Implementation Agents)      ║
║                                                                    ║
║  ┌─────────── AGENT POOL (spawn only what's needed) ─────────┐    ║
║  │                                                            │    ║
║  │  c-expert       — C++ server, combat, AI, networking       │    ║
║  │  lua-expert     — Lua quests, lua_modules, mod hooks       │    ║
║  │  perl-expert    — Perl script maintenance, migration       │    ║
║  │  data-expert    — DB: NPCs, items, loot, spawns            │    ║
║  │  config-expert  — Rules, eqemu_config, login.json          │    ║
║  │  protocol-agent — Packets, opcodes, client protocol        │    ║
║  │  infra-expert   — Docker, compose, Makefile, builds        │    ║
║  │                                                            │    ║
║  │  Example: if architect assigns tasks to only data-expert   │    ║
║  │  and config-expert, spawn ONLY those two.                  │    ║
║  │                                                            │    ║
║  └────────────────────────────────────────────────────────────┘    ║
║                                                                    ║
║  ALL EXPERTS share these traits:                                   ║
║  • Skills: superpowers:using-superpowers                           ║
║  • Anti-slop: Context7 → query-docs before writing code            ║
║  • Fallback: WebFetch from trusted domain-specific sources         ║
║  • Mode: write access (can edit files, run commands)               ║
║  • 4-stage workflow: Plan → Research → Socialize → Build           ║
║  • NO CODE UNTIL STAGE 4 — plan and verify first                   ║
║                                                                    ║
║  EACH EXPERT'S 4-STAGE WORKFLOW:                                   ║
║                                                                    ║
║  ┌─── STAGE 1: PLAN ──────────────────────────────────┐            ║
║  │  1. Read status.md — find assigned tasks            │            ║
║  │  2. Read architecture.md — task details & deps      │            ║
║  │  3. Read PRD — player perspective                   │            ║
║  │  4. Check deps — blocking tasks Complete?           │            ║
║  │     ├── YES → proceed                               │            ║
║  │     └── NO → SendMessage to blocking teammate       │            ║
║  │  5. Read relevant source code / data                │            ║
║  │  6. Write implementation plan → dev-notes.md §1     │            ║
║  └────────────────────────┬────────────────────────────┘            ║
║                           ▼                                         ║
║  ┌─── STAGE 2: RESEARCH ──────────────────────────────┐            ║
║  │  7. Verify every API/pattern against docs:          │            ║
║  │     • Context7 (resolve-library-id → query-docs)    │            ║
║  │     • WebFetch fallback (domain-specific sources)    │            ║
║  │     • Read actual source to confirm signatures      │            ║
║  │  8. Study existing code patterns — naming, style,   │            ║
║  │     conventions. Adopt existing patterns over new.   │            ║
║  │  9. Augment plan with verified info → dev-notes §2  │            ║
║  └────────────────────────┬────────────────────────────┘            ║
║                           ▼                                         ║
║  ┌─── STAGE 3: SOCIALIZE ─────────────────────────────┐            ║
║  │ 10. SendMessage plan to relevant teammates          │            ║
║  │ 11. Incorporate feedback → consensus plan §3        │            ║
║  │ 12. Log conversations → agent-conversations.md      │            ║
║  └────────────────────────┬────────────────────────────┘            ║
║                           ▼                                         ║
║  ┌─── STAGE 4: BUILD ─────────────────────────────────┐            ║
║  │ 13. Update status.md → "In Progress"                │            ║
║  │ 14. Implement from consensus plan                   │            ║
║  │     Log each change → dev-notes.md §4               │            ║
║  │ 15. Update status.md → "Complete"                   │            ║
║  │ 16. Commit to feature branch                        │            ║
║  │ 17. SendMessage → notify dependent teammates        │            ║
║  │ 18. Report completion to user                       │            ║
║  └─────────────────────────────────────────────────────┘          ║
║                                                                    ║
║  COMMIT PROTOCOL (MANDATORY — varies by expert):                   ║
║                                                                    ║
║  BEFORE committing, ALWAYS run:                                    ║
║    git status                                                      ║
║    git diff --stat                                                 ║
║  Review the output. Only stage files YOU changed.                  ║
║  NEVER use `git add -A` or `git add .` — always add files         ║
║  by explicit path.                                                 ║
║                                                                    ║
║  • c-expert, lua-expert, perl-expert, protocol-agent →             ║
║    cd /mnt/d/Dev/EQ/eqemu                                         ║
║    git add <specific-files> && git commit                          ║
║  • data-expert →                                                   ║
║    cd /mnt/d/Dev/EQ/claude                                         ║
║    git add <specific-files> && git commit                          ║
║  • config-expert, infra-expert →                                   ║
║    cd /mnt/d/Dev/EQ/akk-stack                                     ║
║    git add <specific-files> && git commit                          ║
║                                                                    ║
║  If `git status` shows unexpected changes you didn't make,         ║
║  STOP and report to the team lead. Do not commit other             ║
║  agents' work or unrecognized files.                               ║
║                                                                    ║
║  SPECIAL COORDINATION:                                             ║
║  • protocol-agent ←→ infra-expert: packet capture tooling          ║
║  • protocol-agent → user: "Packet Capture Request" for in-game     ║
║    actions during live analysis                                    ║
║  • c-expert ←→ data-expert: table schemas for repository queries   ║
║  • c-expert ←→ lua-expert: C++ changes requiring script updates    ║
║  • c-expert → user: "Rebuild server" reminder after C++ changes    ║
║                                                                    ║
║  INPUTS:                                                           ║
║  ├── game-designer/prd.md           (player perspective)           ║
║  ├── architect/architecture.md      (task details, deps, guidance) ║
║  ├── status.md                      (task assignments, progress)   ║
║  └── claude/docs/topography/*.md    (codebase reference)           ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  ├── eqemu/ source changes          (committed to feature branch)  ║
║  ├── akk-stack/ infra changes       (if infra-expert involved)     ║
║  ├── <agent>/dev-notes.md           (filled-in dev log per expert) ║
║  ├── <agent>/context/               (raw research artifacts)       ║
║  ├── agent-conversations.md         (impl team SendMessage log)    ║
║  └── status.md                      ◄── All tasks = Complete       ║
║                                                                    ║
║  TEAM CLEANUP:                                                     ║
║  SendMessage(type="shutdown_request") to each expert               ║
║  TeamDelete                                                        ║
║                                                                    ║
║  HANDOFF: "All implementation tasks complete. Use the game-tester  ║
║            to build a test plan and validate the implementation"   ║
║  status.md: Implementation=Complete, Current phase=Validation      ║
╚══════════════════════════════════════════════════════════════════════╝
         │
         ▼
```

## Phase 5: Validation

```
╔══════════════════════════════════════════════════════════════════════╗
║  GAME-TESTER                                                       ║
║  Agent: game-tester (sonnet)                                       ║
║  Mode: write access                                                ║
║  Skills: superpowers:using-superpowers                             ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  User prompt: "Use the game-tester to build a test plan and        ║
║                validate the implementation"                        ║
║                                                                    ║
║  ┌──────────────────────────────────────────────────┐              ║
║  │ 1. BUILD TEST PLAN (two parts)                   │              ║
║  │                                                  │              ║
║  │  ┌─────────────────────────────────────────────┐ │              ║
║  │  │ PART 1: Server-Side Validation              │ │              ║
║  │  │ (game-tester executes directly)             │ │              ║
║  │  │                                             │ │              ║
║  │  │ • DB integrity — FK consistency, orphans    │ │              ║
║  │  │ • Quest script syntax — Lua/Perl checks     │ │              ║
║  │  │ • Log analysis — errors in server logs      │ │              ║
║  │  │ • Rule validation — values exist & in range │ │              ║
║  │  │ • Spawn verification — valid NPC refs       │ │              ║
║  │  │ • Loot chain — npc → loottable → items      │ │              ║
║  │  │ • Build verification — C++ compiles clean   │ │              ║
║  │  └─────────────────────────────────────────────┘ │              ║
║  │                                                  │              ║
║  │  ┌─────────────────────────────────────────────┐ │              ║
║  │  │ PART 2: In-Game Testing Guide               │ │              ║
║  │  │ (user executes with Titanium client)        │ │              ║
║  │  │                                             │ │              ║
║  │  │ Per acceptance criterion:                   │ │              ║
║  │  │ • Prerequisites (level, zone, items)        │ │              ║
║  │  │ • Numbered steps with expected results      │ │              ║
║  │  │ • Pass/Fail criteria                        │ │              ║
║  │  │ • GM commands for fast setup                │ │              ║
║  │  │ • Edge cases from antagonistic review       │ │              ║
║  │  │ • Rollback instructions                     │ │              ║
║  │  └─────────────────────────────────────────────┘ │              ║
║  │                                                  │              ║
║  │ 2. EXECUTE server-side validation                │              ║
║  │                                                  │              ║
║  │ 3. WRITE results to game-tester/test-plan.md      │              ║
║  │                                                  │              ║
║  │ 4. UPDATE status.md                              │              ║
║  │    ├── PASS → handoff to completion              │              ║
║  │    └── FAIL → add Blockers, name responsible     │              ║
║  │              expert for each issue               │              ║
║  │                                                  │              ║
║  │ 5. REPORT to user                                │              ║
║  │    • Server-side results summary                 │              ║
║  │    • In-game testing guide                       │              ║
║  │    • Any blockers needing expert fixes            │              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  VALIDATION TOOLKIT:                                               ║
║  ┌──────────────────────────────────────────────────┐              ║
║  │ DB:    docker exec akk-stack-mariadb-1 mysql ... │              ║
║  │ Lua:   docker exec ... luajit -bl FILE           │              ║
║  │ Perl:  docker exec ... perl -c FILE              │              ║
║  │ Logs:  akk-stack/server/logs/                    │              ║
║  │ Build: docker exec ... ninja -j$(nproc)          │              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  INPUTS:                                                           ║
║  ├── game-designer/prd.md           (acceptance criteria)          ║
║  ├── architect/architecture.md      (validation plan, changes)     ║
║  └── status.md                      (completed tasks, notes)       ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  ├── game-tester/test-plan.md    ◄── Full test plan + results      ║
║  └── status.md                   ◄── Validation result             ║
║                                                                    ║
║                  ┌───────────────────────┐                         ║
║                  │ Server-side result?   │                         ║
║                  └─────────┬─────────────┘                         ║
║                    ┌───────┴───────┐                               ║
║                    ▼               ▼                                ║
║              ┌──────────┐   ┌──────────┐                           ║
║              │   PASS   │   │   FAIL   │                           ║
║              └────┬─────┘   └────┬─────┘                           ║
║                   │              │                                  ║
║                   ▼              ▼                                  ║
║            Handoff to      Blockers added                          ║
║            completion      to status.md →                          ║
║                            user dispatches                         ║
║                            responsible expert →                    ║
║                            re-validate                             ║
╚══════════════════════════════════════════════════════════════════════╝
         │ (on PASS)
         ▼
```

## Phase 6: Completion

```
╔══════════════════════════════════════════════════════════════════════╗
║  COMPLETION                                                        ║
║  Actor: User (not an agent)                                        ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  IMPLEMENTATION COMPLETE (agents can check these):                  ║
║  ┌──────────────────────────────────────────────────┐              ║
║  │ □ All implementation tasks marked Complete       │              ║
║  │ □ No open Blockers in status.md                  │              ║
║  │ □ game-tester server-side validation: PASS       │              ║
║  │ □ User completed in-game testing guide: PASS     │              ║
║  │ □ All changes committed and pushed to feature    │              ║
║  │   branch in ALL repos (eqemu/, akk-stack/,       │              ║
║  │   claude/)                                       │              ║
║  │ □ Server rebuilt (if C++ changed)                │              ║
║  │ □ All phases marked Complete in status.md        │              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  MERGE & CLEANUP (USER-INITIATED ONLY):                            ║
║  ┌──────────────────────────────────────────────────┐              ║
║  │ The orchestrator NEVER initiates merge or branch │              ║
║  │ cleanup. These happen ONLY when the user         │              ║
║  │ explicitly confirms the feature is done.         │              ║
║  │                                                  │              ║
║  │ □ User confirmed feature is complete             │              ║
║  │ □ Feature branch merged to main in ALL repos     │              ║
║  │ □ Main pushed to origin in ALL repos             │              ║
║  │ □ Stale feature branches deleted (local + remote)│              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  NOTE: Merge and branch cleanup happen ONLY when the user          ║
║  explicitly confirms the feature is done. The orchestrator          ║
║  never merges or cleans up branches on its own.                    ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  └── status.md  ◄── All phases Complete, merge date recorded       ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## Bug Fix Workflow

Bug fixes follow the **same pipeline as features**. This guarantees
consistent execution: branch isolation, workspace, audit trail, peer
review, validation, and commit/push.

### Two entry points, one pipeline

| Situation | What the orchestrator does |
|-----------|--------------------------|
| **Bugs within a feature context** | Handled inside the existing feature workspace and branch. Orchestrator dispatches the relevant phase. |
| **Standalone bugs (no active feature)** | Orchestrator creates a new bug-fix feature. Runs the full pipeline from Phase 1. |

In both cases the orchestrator is a dispatcher only — it does not triage,
diagnose, select agents, or evaluate complexity. The engineers do that.

### Standalone bug-fix pipeline

Standalone bugs (reported by user or discovered outside a feature) are
treated as a new feature:

```
┌─────────────┐    ┌─────────────────┐    ┌───────────────────┐    ┌──────────────────────┐    ┌──────────────┐    ┌────────────┐
│  BOOTSTRAP   │───▶│  DESIGN TEAM     │───▶│  ARCHITECTURE TEAM │───▶│  IMPLEMENTATION TEAM  │───▶│  GAME-TESTER  │───▶│  COMPLETE   │
│  (Phase 1)   │    │  (Phase 2)       │    │  (Phase 3)         │    │  (Phase 4)            │    │  (Phase 5)    │    │  (Phase 6)  │
└─────────────┘    └─────────────────┘    └───────────────────┘    └──────────────────────┘    └──────────────┘    └────────────┘
```

Each phase is lighter than a full feature but follows the same structure:

| Phase | Bug-fix equivalent |
|-------|--------------------|
| **Bootstrap** | bootstrap-agent creates workspace and branch (e.g. `bugfix/companion-equipment-persistence`) |
| **Design** | game-designer documents the bugs: reproduction steps, expected vs actual behavior, acceptance criteria. Replaces PRD. |
| **Architecture** | architect triages affected systems, diagnoses root causes, plans the fix approach across files/repos. Replaces full architecture doc. |
| **Implement** | Assigned experts implement the fixes as specified by the architect. |
| **Validate** | game-tester verifies all bugs are resolved via reproduction steps. |
| **Complete** | Commit and push all affected repos to feature branch. Merge and branch cleanup only when user confirms completion. |

### Why bugs use the full pipeline

The old bug workflow gave the orchestrator triage and diagnosis
responsibilities. This violated the orchestrator's role as a state machine
and led to:
- Orchestrator making technical decisions it shouldn't make
- No branch isolation (fixes applied to dirty working trees)
- No commit/push discipline (work lost when sessions end)
- No audit trail (no workspace, no agent conversations logged)

The full pipeline prevents all of these.

### Batching

Multiple related bugs can be grouped into a single bug-fix feature
(e.g. "companion system bug fixes"). The design phase documents all bugs,
the architecture phase plans all fixes, and implementation addresses them
together. This is more efficient than running the pipeline per-bug.

---

## Template Flow

Seven templates are copied by bootstrap-agent and filled by subsequent agents:

```
claude/templates/                     claude/project-work/<branch>/
┌──────────────────────┐              ┌──────────────────────────────────┐
│                      │   COPY &     │                                  │
│  status.md           │ ──INIT───▶  │  status.md                       │
│                      │              │  Filled by: ALL agents           │
│                      │              │  Tracks: phases, tasks, handoffs,│
│                      │              │    questions, blockers, decisions │
└──────────────────────┘              └──────────────────────────────────┘
┌──────────────────────┐              ┌──────────────────────────────────┐
│  agent-              │   COPY &     │                                  │
│  conversations.md    │ ──INIT───▶  │  agent-conversations.md          │
│                      │              │  Filled by: ALL team agents      │
│                      │              │  Logs: SendMessage exchanges,    │
│                      │              │    decisions, unresolved threads  │
└──────────────────────┘              └──────────────────────────────────┘
┌──────────────────────┐              ┌──────────────────────────────────┐
│                      │   COPY &     │                                  │
│  prd.md              │ ──INIT───▶  │  game-designer/prd.md            │
│                      │              │  Filled by: game-designer        │
│                      │              │  Reviewed by: lore-master         │
│                      │              │  Sections: problem, goals, UX,   │
│                      │              │    mechanics, systems, criteria   │
└──────────────────────┘              └──────────────────────────────────┘
┌──────────────────────┐              ┌──────────────────────────────────┐
│                      │   COPY &     │                                  │
│  lore-notes.md       │ ──INIT───▶  │  lore-master/lore-notes.md       │
│                      │              │  Filled by: lore-master          │
│                      │              │  Sections: research, era review, │
│                      │              │    PRD reviews, decisions,        │
│                      │              │    final sign-off                 │
└──────────────────────┘              └──────────────────────────────────┘
┌──────────────────────┐              ┌──────────────────────────────────┐
│                      │   COPY &     │                                  │
│  architecture.md     │ ──INIT───▶  │  architect/architecture.md       │
│                      │              │  Filled by: architect            │
│                      │              │  Sections: summary, analysis,    │
│                      │              │    approach, sequence, risks,    │
│                      │              │    review passes, validation     │
└──────────────────────┘              └──────────────────────────────────┘
┌──────────────────────┐              ┌──────────────────────────────────┐
│                      │   COPY &     │                                  │
│  dev-notes.md        │ ──INIT───▶  │  <expert>/dev-notes.md (×7)      │
│                      │              │  Filled by: each implementation  │
│                      │              │    expert assigned to a task     │
│                      │              │  4 stages: Plan, Research,       │
│                      │              │    Socialize, Build              │
└──────────────────────┘              └──────────────────────────────────┘
┌──────────────────────┐              ┌──────────────────────────────────┐
│                      │   COPY &     │                                  │
│  test-plan.md        │ ──INIT───▶  │  game-tester/test-plan.md        │
│                      │              │  Filled by: game-tester          │
│                      │              │  Sections: server-side checks,   │
│                      │              │    in-game guide, blockers,       │
│                      │              │    rollback instructions          │
└──────────────────────┘              └──────────────────────────────────┘

Template initialization (bootstrap-agent):
  • Replace [Feature Name] with actual name
  • Replace <branch-name> with actual branch
  • Replace [Agent Name] / [agent-name] in dev-notes.md with each expert's name
  • Replace YYYY-MM-DD dates in status.md bootstrap row
  • Set bootstrap phase to Complete, current phase to Design
  • Verify architecture.md PRD path reads game-designer/prd.md
```

---

## Shared Context (all agents)

```
┌─────────────────────────────────────────────────────────────────────┐
│  CONTEXT loaded by every agent:                                     │
│  • CLAUDE.md — project context (repos, paths, conventions)          │
│    Auto-injected into every session. No skill invocation needed.    │
│  • superpowers:using-superpowers — problem-solving metaskill        │
│                                                                     │
│  ANTI-SLOP DOCTRINE (implementation experts only):                  │
│  1. Context7 resolve-library-id → query-docs → then write code     │
│  2. Fallback: WebFetch from trusted sources per domain              │
│     • C++: cppreference.com, cmake.org, docs.eqemu.dev             │
│     • Protocol: cppreference.com, tcpdump.org, wiki.wireshark.org  │
│     • Infra: docs.docker.com, gnu.org/make, ninja-build.org        │
│                                                                     │
│  TOPOGRAPHY DOCS (read by architect + implementation experts):      │
│  • claude/docs/topography/C-CODE.md                                 │
│  • claude/docs/topography/PROTOCOL-CODE.md                          │
│  • claude/docs/topography/LUA-CODE.md                               │
│  • claude/docs/topography/PERL-CODE.md                              │
│  • claude/docs/topography/SQL-CODE.md                               │
│                                                                     │
│  CONTEXT DURABILITY PRINCIPLE:                                      │
│  Every agent writes hard-earned context to persistent files so it   │
│  survives context window compaction. Templates enforce this:        │
│  • dev-notes.md   — 4 stages: plan, research, socialize, build     │
│  • lore-notes.md  — lore research, era review, PRD review log      │
│  • test-plan.md   — validation checks, in-game guide, results      │
│  • agent-conversations.md — all SendMessage exchanges logged        │
│  • context/       — raw artifacts (captures, dumps, excerpts)       │
│                                                                     │
│  WORK PROTECTION RULES (ALL agents MUST follow):                    │
│                                                                     │
│  1. NEVER use `git add -A` or `git add .`                           │
│     Always add files by explicit path. Review `git status` first.   │
│                                                                     │
│  2. NEVER run destructive git ops without backing up first           │
│     Before ANY reset, checkout --, clean, or index rebuild:          │
│     tar czf /tmp/repo-backup-$(date +%s).tar.gz .                   │
│     A 30-second backup beats hours of rework.                        │
│                                                                     │
│  3. ALWAYS check for dirty tree before destructive git ops           │
│     Run `git diff --stat` and `git status` BEFORE any checkout,     │
│     reset, clean, or index rebuild. If the tree has uncommitted      │
│     changes → STOP and report to team lead. Never overwrite a        │
│     dirty working tree.                                              │
│                                                                     │
│  4. NEVER take destructive action without asking                     │
│     Commands that can destroy uncommitted work require               │
│     confirmation from the team lead or user first:                   │
│     git checkout -- ., git reset --hard, git clean, rm -rf           │
│                                                                     │
│  5. WIP commit before shutdown                                       │
│     Before approving any shutdown_request, check `git status`.       │
│     If dirty, commit with `WIP: <agent-name> - <task>` prefix.      │
│     Uncommitted work is unprotected work.                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Agent Roster (12 agents)

```
┌────────────────┬─────────┬────────────┬──────────────────────────────────────┐
│ Agent          │ Model   │ Mode       │ Domain                               │
├────────────────┼─────────┼────────────┼──────────────────────────────────────┤
│ bootstrap-agent│ sonnet  │ write      │ Branch + workspace creation          │
├────────────────┼─────────┼────────────┼──────────────────────────────────────┤
│ game-designer  │ opus    │ plan       │ PRD: mechanics, balance, UX          │
│ lore-master    │ sonnet  │ plan       │ Lore review, faction, era compliance │
├────────────────┼─────────┼────────────┼──────────────────────────────────────┤
│ architect      │ opus    │ plan       │ Feasibility, task planning, review   │
├────────────────┼─────────┼────────────┼──────────────────────────────────────┤
│ c-expert       │ sonnet  │ write      │ C++ server: combat, spells, AI, net  │
│ lua-expert     │ sonnet  │ write      │ Lua quests, modules, mod hooks       │
│ perl-expert    │ sonnet  │ write      │ Perl scripts, migration planning     │
│ data-expert    │ sonnet  │ write      │ DB: NPCs, items, loot, spawns        │
│ config-expert  │ sonnet  │ write      │ Rules, eqemu_config, login.json      │
│ protocol-agent │ sonnet  │ write      │ Packets, opcodes, client protocol    │
│ infra-expert   │ sonnet  │ write      │ Docker, compose, Makefile, builds    │
├────────────────┼─────────┼────────────┼──────────────────────────────────────┤
│ game-tester    │ sonnet  │ write      │ Test plans, validation, QA           │
└────────────────┴─────────┴────────────┴──────────────────────────────────────┘
```

---

## Failure / Re-validation Loop

```
                    game-tester reports FAIL
                            │
                            ▼
                 ┌────────────────────┐
                 │ Blockers added to  │
                 │ status.md with     │
                 │ responsible expert │
                 └────────┬───────────┘
                          │
                          ▼
                 ┌────────────────────┐
                 │ User dispatches    │
                 │ responsible expert │
                 │ (ad-hoc, not full  │
                 │  team re-spawn)    │
                 └────────┬───────────┘
                          │
                          ▼
                 ┌────────────────────┐
                 │ Expert fixes issue │
                 │ commits to branch  │
                 └────────┬───────────┘
                          │
                          ▼
                 ┌────────────────────┐
                 │ User re-invokes    │
                 │ game-tester to     │
                 │ re-validate        │
                 └────────┬───────────┘
                          │
                          ▼
                 ┌────────────────────┐
                 │  PASS?             │
                 │  ├── YES → Phase 6 │
                 │  └── NO → loop     │
                 └────────────────────┘
```

---

## File Map (all workflow artifacts)

```
/mnt/d/Dev/EQ/
├── claude/
│   ├── AGENTS.md                      ◄── THIS FILE (workflow + agent catalog)
│   ├── CLAUDE.md                      ◄── Orchestrator instructions (auto-injected)
│   ├── README.md                      ◄── Human operations manual
│   ├── PROJECT.md                     ◄── Project vision, roadmap
│   ├── .gitignore
│   ├── agents/
│   │   ├── bootstrap-agent.md
│   │   ├── game-designer.md
│   │   ├── lore-master.md
│   │   ├── architect.md
│   │   ├── c-expert.md
│   │   ├── lua-expert.md
│   │   ├── perl-expert.md
│   │   ├── data-expert.md
│   │   ├── config-expert.md
│   │   ├── protocol-agent.md
│   │   ├── infra-expert.md
│   │   └── game-tester.md
│   ├── templates/
│   │   ├── status.md                  ◄── Workflow tracker template
│   │   ├── agent-conversations.md     ◄── Cross-agent conversation log template
│   │   ├── prd.md                     ◄── PRD template
│   │   ├── lore-notes.md             ◄── Lore research & review template
│   │   ├── architecture.md            ◄── Architecture plan template
│   │   ├── dev-notes.md              ◄── Implementation dev log template (×7)
│   │   └── test-plan.md              ◄── Test plan & results template
│   ├── docs/
│   │   └── topography/
│   │       ├── C-CODE.md
│   │       ├── PROTOCOL-CODE.md
│   │       ├── LUA-CODE.md
│   │       ├── PERL-CODE.md
│   │       └── SQL-CODE.md
│   ├── tmp/                           ◄── Gitignored temp storage (large files)
│   │   └── <branch-name>/            ◄── Mirrors project-work feature names
│   └── project-work/
│       └── <branch-name>/             ◄── Created per feature
│           ├── status.md              ◄── Workflow tracker (all agents)
│           ├── agent-conversations.md ◄── SendMessage log (all team agents)
│           ├── game-designer/
│           │   ├── prd.md             ◄── PRD deliverable
│           │   └── context/
│           ├── lore-master/
│           │   ├── lore-notes.md      ◄── Lore research deliverable
│           │   └── context/
│           ├── architect/
│           │   ├── architecture.md    ◄── Architecture plan deliverable
│           │   └── context/
│           ├── c-expert/
│           │   ├── dev-notes.md       ◄── Dev log deliverable
│           │   └── context/
│           ├── lua-expert/
│           │   ├── dev-notes.md
│           │   └── context/
│           ├── perl-expert/
│           │   ├── dev-notes.md
│           │   └── context/
│           ├── data-expert/
│           │   ├── dev-notes.md
│           │   └── context/
│           ├── config-expert/
│           │   ├── dev-notes.md
│           │   └── context/
│           ├── protocol-agent/
│           │   ├── dev-notes.md
│           │   └── context/
│           ├── infra-expert/
│           │   ├── dev-notes.md
│           │   └── context/
│           └── game-tester/
│               ├── test-plan.md       ◄── Test plan deliverable
│               └── context/
├── eqemu/                             ◄── Server source (feature branches)
└── akk-stack/                         ◄── Docker deployment
```

---

## Status.md Lifecycle

The status.md file is the single source of truth for workflow progress.
Every agent reads and updates it.

```
Phase transitions through status.md:

Bootstrap ──▶ Design ──▶ Architecture ──▶ Implementation ──▶ Validation ──▶ Completion
   │            │            │                │                  │              │
   │            │            │                │                  │              │
   ▼            ▼            ▼                ▼                  ▼              ▼
 bootstrap   game-        architect        Each expert       game-tester     user
 -agent      designer                      updates own       updates with
 sets        sets         sets             task rows         PASS/FAIL
 Complete    Complete     Complete +       to Complete       result
             + updates    populates
             handoff      task table

Sections updated by phase:
┌──────────────────┬──────────────────────────────────────────────────┐
│ Section          │ Updated By                                       │
├──────────────────┼──────────────────────────────────────────────────┤
│ Workflow Status  │ Every agent (their own phase row)                │
│ Handoff Log      │ bootstrap, game-designer, architect, game-tester │
│ Implementation   │ architect (populates), experts (status updates)  │
│ Tasks            │                                                  │
│ Open Questions   │ Any agent that has unresolved questions          │
│ Blockers         │ game-tester (on FAIL), any agent (if blocked)   │
│ Decision Log     │ architect, experts (key decisions)               │
│ Completion       │ user (final checklist)                           │
│ Checklist        │                                                  │
└──────────────────┴──────────────────────────────────────────────────┘
```

---

## Ad-Hoc Usage

Not everything needs the full workflow. For quick tasks:

**Consult a single agent:**
> Use the game-designer to reason about companion power scaling

**Quick implementation:**
> Use the data-expert to add a new NPC to East Commonlands

**Validation after changes:**
> Use the game-tester to validate the loot table changes we just made
