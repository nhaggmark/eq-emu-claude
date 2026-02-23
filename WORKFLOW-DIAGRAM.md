# EQ Server — Feature Workflow Diagram

> **Last updated:** 2026-02-22
> **Source of truth:** Agent definitions in `claude/agents/`, templates in `claude/templates/`

---

## Pipeline Overview

```
┌─────────────┐    ┌─────────────────┐    ┌───────────────────┐    ┌──────────────────────┐    ┌──────────────┐    ┌────────────┐
│  BOOTSTRAP   │───▶│  DESIGN TEAM     │───▶│  ARCHITECTURE TEAM │───▶│  IMPLEMENTATION TEAM  │───▶│  GAME-TESTER  │───▶│  COMPLETE   │
│  (Phase 1)   │    │  (Phase 2)       │    │  (Phase 3)         │    │  (Phase 4)            │    │  (Phase 5)    │    │  (Phase 6)  │
└─────────────┘    └─────────────────┘    └───────────────────┘    └──────────────────────┘    └──────────────┘    └────────────┘
  Solo agent         Team spawn             Team spawn               Team spawn                    Solo agent         User action
  sonnet             opus + sonnet          opus + 2× sonnet         sonnet × N                    sonnet
```

---

## Phase 1: Bootstrap

```
╔══════════════════════════════════════════════════════════════════════╗
║  BOOTSTRAP                                                         ║
║  Agent: bootstrap-agent (sonnet)                                   ║
║  Mode: write access                                                ║
║  Skills: base-agent, superpowers:using-superpowers                 ║
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
║  │ 4. Copy & initialize templates                   │              ║
║  │    (see Template Flow below)                     │              ║
║  │                                                  │              ║
║  │ 5. Report + hand off to design team              │              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  ├── eqemu/ branch: feature/<branch-name>                          ║
║  └── claude/project-work/<branch-name>/                            ║
║      ├── status.md          ◄── templates/status.md                ║
║      ├── game-designer/                                            ║
║      │   ├── prd.md         ◄── templates/prd.md                   ║
║      │   └── context/                                              ║
║      ├── lore-master/                                              ║
║      │   └── context/                                              ║
║      ├── architect/                                                ║
║      │   ├── architecture.md ◄── templates/architecture.md         ║
║      │   └── context/                                              ║
║      ├── c-expert/                                                 ║
║      │   └── context/                                              ║
║      ├── lua-expert/                                               ║
║      │   └── context/                                              ║
║      ├── perl-expert/                                              ║
║      │   └── context/                                              ║
║      ├── data-expert/                                              ║
║      │   └── context/                                              ║
║      ├── config-expert/                                            ║
║      │   └── context/                                              ║
║      ├── protocol-agent/                                           ║
║      │   └── context/                                              ║
║      ├── infra-expert/                                             ║
║      │   └── context/                                              ║
║      └── game-tester/                                              ║
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
║  DESIGN TEAM  (spawned as teammates)                               ║
║  Coordination: SendMessage                                         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  User prompt: "Spawn the design team: game-designer and            ║
║                lore-master as teammates"                           ║
║                                                                    ║
║  ┌─────────────────────────────┐  SendMessage  ┌────────────────┐  ║
║  │ GAME-DESIGNER (opus)        │◄────────────▶│ LORE-MASTER     │  ║
║  │ Mode: plan (read-only)      │               │ (sonnet)        │  ║
║  │ Skills: base-agent,         │               │ Mode: plan      │  ║
║  │   superpowers:using-        │               │ Skills: base-   │  ║
║  │   superpowers               │               │   agent, super- │  ║
║  │                             │               │   powers        │  ║
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
║  HANDOFF: "Use the architect to assess technical feasibility"      ║
║  status.md: Design=Complete, Current phase=Architecture            ║
║  Handoff log: "design team → architect" + lore-master sign-off     ║
╚══════════════════════════════════════════════════════════════════════╝
         │
         ▼
```

## Phase 3: Architecture

```
╔══════════════════════════════════════════════════════════════════════╗
║  ARCHITECTURE TEAM  (spawned as teammates)                         ║
║  Coordination: SendMessage                                         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  User prompt: "Spawn the architecture team: architect,             ║
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
║  ├── claude/docs/topography/*.md       (4 topography docs)         ║
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
║  HANDOFF: "Spawn the implementation team — [list of assigned       ║
║            experts] as teammates"                                  ║
║  status.md: Architecture=Complete, Current phase=Implementation    ║
╚══════════════════════════════════════════════════════════════════════╝
         │
         ▼
```

## Phase 4: Implementation

```
╔══════════════════════════════════════════════════════════════════════╗
║  IMPLEMENTATION TEAM  (spawned as teammates)                       ║
║  Coordination: SendMessage                                         ║
║  Only spawn experts the architect assigned tasks to                ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  User prompt: "Spawn the implementation team with all assigned     ║
║                experts as teammates"                               ║
║                                                                    ║
║  ┌──────────────────── AVAILABLE EXPERTS ─────────────────────┐    ║
║  │                                                            │    ║
║  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    ║
║  │  │ c-expert     │  │ lua-expert   │  │ perl-expert  │     │    ║
║  │  │ (sonnet)     │  │ (sonnet)     │  │ (sonnet)     │     │    ║
║  │  │ C++ server   │  │ Lua quests,  │  │ Perl scripts │     │    ║
║  │  │ combat, AI,  │  │ lua_modules, │  │ maintenance, │     │    ║
║  │  │ networking   │  │ mod hooks    │  │ migration    │     │    ║
║  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │    ║
║  │         │                 │                  │             │    ║
║  │         │      SendMessage (all ◄──▶ all)    │             │    ║
║  │         │                 │                  │             │    ║
║  │  ┌──────┴───────┐  ┌─────┴────────┐  ┌─────┴────────┐    │    ║
║  │  │ data-expert  │  │config-expert │  │protocol-agent│    │    ║
║  │  │ (sonnet)     │  │ (sonnet)     │  │ (sonnet)     │    │    ║
║  │  │ DB: NPCs,    │  │ Rules,       │  │ Packets,     │    │    ║
║  │  │ items, loot, │  │ eqemu_config,│  │ opcodes,     │    │    ║
║  │  │ spawns       │  │ login.json   │  │ client caps  │    │    ║
║  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │    ║
║  │         │                 │                  │             │    ║
║  │         │                 │                  │             │    ║
║  │  ┌──────┴─────────────────┴──────────────────┴───────┐    │    ║
║  │  │              infra-expert (sonnet)                 │    │    ║
║  │  │  Docker, compose, Makefile, build pipeline,       │    │    ║
║  │  │  virtualization, tooling, packet capture setup     │    │    ║
║  │  └───────────────────────────────────────────────────┘    │    ║
║  │                                                            │    ║
║  └────────────────────────────────────────────────────────────┘    ║
║                                                                    ║
║  ALL EXPERTS share these traits:                                   ║
║  • Skills: base-agent, superpowers:using-superpowers               ║
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
║  │  8. Augment plan with verified info → dev-notes §2  │            ║
║  └────────────────────────┬────────────────────────────┘            ║
║                           ▼                                         ║
║  ┌─── STAGE 3: SOCIALIZE ─────────────────────────────┐            ║
║  │  9. SendMessage plan to relevant teammates          │            ║
║  │ 10. Incorporate feedback → consensus plan §3        │            ║
║  │ 11. Log conversations → agent-conversations.md      │            ║
║  └────────────────────────┬────────────────────────────┘            ║
║                           ▼                                         ║
║  ┌─── STAGE 4: BUILD ─────────────────────────────────┐            ║
║  │ 12. Update status.md → "In Progress"                │            ║
║  │ 13. Implement from consensus plan                   │            ║
║  │     Log each change → dev-notes.md §4               │            ║
║  │ 14. Update status.md → "Complete"                   │            ║
║  │ 15. Commit to feature branch                        │            ║
║  │ 16. SendMessage → notify dependent teammates        │            ║
║  │ 17. Report completion to user                       │            ║
║  └─────────────────────────────────────────────────────┘          ║
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
║  Skills: base-agent, superpowers:using-superpowers                 ║
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
║  CHECKLIST:                                                        ║
║  ┌──────────────────────────────────────────────────┐              ║
║  │ □ All implementation tasks marked Complete       │              ║
║  │ □ No open Blockers in status.md                  │              ║
║  │ □ game-tester server-side validation: PASS       │              ║
║  │ □ User completed in-game testing guide: PASS     │              ║
║  │ □ Feature branch merged to main                  │              ║
║  │   cd /mnt/d/Dev/EQ/eqemu && git checkout main && │              ║
║  │   git merge <branch-name>                        │              ║
║  │ □ Server rebuilt (if C++ changed)                │              ║
║  │ □ All phases marked Complete in status.md        │              ║
║  └──────────────────────────────────────────────────┘              ║
║                                                                    ║
║  OUTPUTS:                                                          ║
║  └── status.md  ◄── All phases Complete, merge date recorded       ║
╚══════════════════════════════════════════════════════════════════════╝
```

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
│  SKILLS loaded by every agent:                                      │
│  • base-agent — project context (repos, paths, conventions)         │
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
└─────────────────────────────────────────────────────────────────────┘
```

---

## Agent Roster (11 agents)

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
│   ├── WORKFLOW-DIAGRAM.md            ◄── THIS FILE
│   ├── PROJECT.md                     ◄── Project vision, roadmap
│   ├── agents/
│   │   ├── AGENTS.md                  ◄── Agent catalog + workflow docs
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
│   │       ├── LUA-CODE.md
│   │       ├── PERL-CODE.md
│   │       └── SQL-CODE.md
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
