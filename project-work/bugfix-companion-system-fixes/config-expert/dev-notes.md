# Companion System Bug Fixes — Dev Notes: Config Expert

> **Feature branch:** `bugfix/companion-system-fixes`
> **Agent:** config-expert
> **Task(s):** #3 — Advise architect on rule/config alternatives for companion bugs
> **Date started:** 2026-03-01
> **Current stage:** Research complete — waiting to socialize with architect

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Advise architect on rule/config alternatives for companion bugs | None | In Progress |

---

## Stage 1: Plan

Read PRD, topography docs, queried rule_values, grepped ruletypes.h, and verified Docker/config
state for all three bugs.

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/docs/topography/C-CODE.md` | All | Rule System section: 47 categories, ~1186 rules, RuleI/RuleR/RuleB macros, accessed via `rule_values` table |
| `claude/docs/topography/SQL-CODE.md` | All | Rule System section: `rule_sets` + `rule_values` tables, how rules are stored and loaded |
| `eqemu/common/ruletypes.h` | 1181-1203 | Custom `Companions` category with 22 rules — none cover equipment display, equipment persistence, or LLM connectivity |
| `rule_values` table (DB) | Full query | Verified live rule values match ruletypes.h; Companions category has 22 live rules |
| Docker containers | `docker ps` | `akk-stack-npc-llm-1` is Up 3+ hours, status: healthy, port 8100/tcp |
| Docker networking | `docker inspect` | Both `npc-llm` and `eqemu-server` on same `akk-stack_backend` network; npc-llm at 172.18.0.9 |
| DNS resolution | `getent hosts npc-llm` from inside eqemu container | Resolves to 172.18.0.9 — DNS is working |
| LLM sidecar health | `curl http://npc-llm:8100/v1/health` from inside eqemu container | Returns: `{"status":"ok","model_loaded":true,...,"chromadb_connected":true}` |

### Key Findings

**Bug 1 (LLM Chat):** The sidecar IS running and reachable. This is NOT a Docker/config problem.
- Container: `akk-stack-npc-llm-1`, healthy, 3+ hours uptime
- DNS: `npc-llm` resolves to `172.18.0.9` from inside eqemu container
- Health check: model loaded, ChromaDB connected, 6 collections
- The failure is in the Lua code path (curl call, JSON parsing, or response handling in `llm_bridge.lua`)
- No config or rule change can fix this — it requires Lua code investigation

**Bug 2 (Equipment Display):** No rule exists for companion equipment array selection or wear change behavior.
- Searched ruletypes.h for: companion, equipment, wear, inventory — no matching rules for this behavior
- The `Companions` category (lines 1181-1203) has 22 rules covering: enable/disable, scaling,
  cooldowns, faction, XP, regen — nothing about equipment array routing or visual update
- `Inventory` category rules cover augments, bank loading, item transformation — not NPC/companion wear
- This is a pure C++ code bug: `GiveItem()` writes to `m_equipment[]`, but `GetEquipmentMaterial()`
  reads from `NPC::equipment[]`. Two arrays, wrong one read.
- No config-first alternative exists.

**Bug 3 (Equipment Persistence):** No rule exists for companion equipment load-on-spawn behavior.
- `LoadEquipment()` is declared and implemented but never called — this is a code omission
- No rule controls when/whether equipment is loaded from `companion_inventories` on zone-in
- The `Companions` category has no rules touching the load lifecycle
- No config-first alternative exists. The fix requires calling `LoadEquipment()` from the correct
  lifecycle method.

### Implementation Plan (Advisory Only)

My role is advisory. No config changes are needed for any of the three bugs.

**Assessment by bug:**

1. **LLM Chat** — NO config/rule change needed or applicable. The sidecar is healthy. The bug
   is in Lua (`llm_bridge.lua` curl/JSON handling). This belongs to the lua-expert.

2. **Equipment Display** — NO config/rule change needed or applicable. This is a C++ array
   routing bug. Belongs to c-expert. No new rules needed.

3. **Equipment Persistence** — NO config/rule change needed or applicable. This is a C++ call
   site omission. Belongs to c-expert. No new rules needed.

**One potential new rule to consider (optional, not required for bug fixes):**
If the architect wants a future tunable for equipment persistence behavior (e.g., toggle or slot
mask), that would be a new rule in the `Companions` category. But this is NOT required to fix
the bugs.

---

## Stage 2: Research

All findings above are from direct database queries, Docker inspection, and grep of source code —
not from training data. Verified live.

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| Companions rule category | `eqemu/common/ruletypes.h` lines 1181-1203 | Yes | 22 rules, none for equipment display/persistence |
| Inventory rule category | `eqemu/common/ruletypes.h` lines 1042-1052 | Yes | Augments/bank only, not companion equipment |
| Live rule values | `rule_values` table, direct DB query | Yes | Matches ruletypes.h defaults |
| npc-llm sidecar health | `curl http://npc-llm:8100/v1/health` from inside eqemu container | Yes | Healthy, model loaded, ChromaDB connected |
| Docker networking | `docker inspect` + `getent hosts` | Yes | Both containers on akk-stack_backend, DNS resolves |

### Plan Amendments

Plan confirmed — no amendments needed. Research confirms advisory assessment.

---

## Stage 3: Socialize

Awaiting architect contact. Will message architect proactively with findings since they are
blocking for the architecture plan.

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Rule/config assessment for all 3 bugs | See SendMessage below |

---

## Open Items

- [ ] Wait for architect to message or receive this advisory

---

## Context for Next Agent

If another agent picks this up after context compaction:

1. Config-expert's role for these bugs is ADVISORY ONLY — no config changes needed for any bug.
2. The LLM sidecar (npc-llm container) is healthy and reachable from inside eqemu container.
   Bug 1 is a Lua code issue, not a Docker/config issue.
3. No rules exist in the `Companions` category (or any other) that affect equipment display,
   equipment persistence, or LLM connectivity.
4. All three bugs require C++ or Lua code changes — no config-first alternative exists.
5. See `agent-conversations.md` for the architect conversation log.
