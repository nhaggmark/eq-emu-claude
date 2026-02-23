---
name: load-topography
description: Mandatory topography loading for architecture and planning work
---

## MANDATORY: Load Topography Docs Before Any Work

You MUST read all four topography documents **before** absorbing the PRD,
making any technical decisions, or responding to any questions. These docs
are the ground truth for the codebase. Do not rely on training data for
file locations, function names, table schemas, or system architecture.

**Read these four files immediately (use the Read tool):**

1. `/mnt/d/Dev/EQ/claude/docs/topography/C-CODE.md` — Server architecture,
   entity hierarchy, rule system, combat, spells, networking, bots, scripting
   interface, repository pattern, build pipeline

2. `/mnt/d/Dev/EQ/claude/docs/topography/LUA-CODE.md` — Quest scripting,
   event handlers, API namespace (~950 functions), encounter system, lua_mod
   hooks, module system, file resolution order

3. `/mnt/d/Dev/EQ/claude/docs/topography/PERL-CODE.md` — Legacy quest system,
   event subs, magic globals, plugin system, 877 quest functions, file
   resolution paths

4. `/mnt/d/Dev/EQ/claude/docs/topography/SQL-CODE.md` — All 250 database
   tables, key chains (spawns, loot, faction), column counts, relationships,
   rule system tables

**Do this BEFORE step 1 of your workflow.** Read all four, then proceed.

If you skip this step, your architecture decisions will be based on stale
training data instead of the actual codebase. This is not optional.
