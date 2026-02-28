# NPC Conversation Memory (Pinecone Integration) — Test Plan

> **Feature branch:** `feature/npc-llm-integration`
> **Author:** game-tester
> **Date:** YYYY-MM-DD
> **Server-side result:** _PASS / PASS WITH WARNINGS / FAIL_

---

## Test Summary

_Brief overview of what's being tested and which systems are affected._

### Inputs Reviewed

- [ ] PRD at `game-designer/prd.md`
- [ ] Architecture plan at `architect/architecture.md`
- [ ] status.md — all implementation tasks Complete
- [ ] Acceptance criteria identified: _N criteria_

---

## Part 1: Server-Side Validation

_Checks the game-tester executes directly. Run every applicable check._

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | | PASS / WARN / FAIL | |
| 2 | | PASS / WARN / FAIL | |

### Database Integrity

_FK consistency, orphaned records, invalid references for modified tables._

**Queries run:**
```sql
-- Example: verify all new NPC spawn references are valid
```

**Findings:**

### Quest Script Syntax

_Lua/Perl syntax checks on all new or modified scripts._

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| | Lua / Perl | PASS / FAIL | |

### Log Analysis

_Errors found in `akk-stack/server/logs/` after restart._

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| | | | |

### Rule Validation

_New/changed rule values exist and are within valid range._

| Rule | Category | Value | Valid Range | Result |
|------|----------|-------|-------------|--------|
| | | | | |

### Spawn Verification

_Spawn points reference valid NPCs, grids, and zones._

### Loot Chain Validation

_Complete chains from npc_types → loottable → lootdrop → items._

### Build Verification

_C++ compiles cleanly (if source was modified)._

- **Build command:** `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS / FAIL
- **Errors:** _None / list errors_

---

## Part 2: In-Game Testing Guide

_Step-by-step instructions for the user to manually verify with the
Titanium client. One test case per acceptance criterion._

### Prerequisites

_Character setup, zone access, items needed across all tests._

**GM setup commands:**
```
#level [n]
#summonitem [id]
#goto [zone] [x] [y] [z]
```

---

### Test 1: [What you're testing]

**Acceptance criterion:** _Quote from PRD_

**Prerequisite:** _Character level, zone, items needed_

**Steps:**
1.
2.
3.

**Expected result:**

**Pass if:**
**Fail if:**

**GM commands for setup:**
```
```

---

### Test 2: [What you're testing]

_Repeat structure for each acceptance criterion..._

---

### Edge Case Tests

_Tests derived from the architecture plan's antagonistic review._

### Test E1: [Edge case description]

**Risk from architecture plan:** _Quote the risk_

**Steps:**
1.
2.

**Pass if:**
**Fail if:**

---

## Rollback Instructions

_If something goes wrong during testing, how to restore previous state._

```bash
# Sidecar rollback — revert to Phase 1 sidecar without memory
# Database rollback
# Quest script rollback
# Config rollback
```

---

## Blockers

_Issues found that must be fixed before the feature can ship._

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| | | Critical / High / Medium | | |

---

## Recommendations

_Non-blocking observations, suggestions, or improvements noticed during testing._

-
