# Companion System Bug Fixes — Dev Notes: Lua Expert

> **Feature branch:** `bugfix/companion-system-fixes`
> **Agent:** lua-expert
> **Task(s):** Task 3 — Diagnose and fix LLM chat
> **Date started:** 2026-03-01
> **Current stage:** Stage 4: Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Diagnose and fix LLM chat: find failure in llm_bridge.lua generate_response(), fix it, add logging | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `lua_modules/llm_bridge.lua` | 219 | Main investigation target. generate_response() at lines 164-217 uses io.popen(curl). Three nil-return paths before the response is returned. No eq.log() calls at any failure path. |
| `lua_modules/llm_config.lua` | 39 | sidecar_url="http://npc-llm:8100", timeout_seconds=10. |
| `lua_modules/llm_faction.lua` | 51 | Faction level → tone/instruction table. No single quotes in any strings. |
| `global/global_npc.lua` | 209 | Entry point. gen_ok/ctx_ok pcall wrappers. Thinking emote sent BEFORE generate_response. is_eligible() called twice (harmless for companions). |
| `eqemu/zone/lua_parser.cpp` | ~1500 | luaL_openlibs(L) at line 1072 — all standard libs including io are open. No lua_sethook instruction limits. No coroutines in zone parser. |
| `eqemu/common/eqemu_logsys.h` | 360 | Log categories: Quests=20, QuestDebug=38, QuestErrors=87. |
| DB: logsys_categories | — | QuestErrors (87): log_to_console=1, log_to_file=0, log_to_gmsay=1. Console logs go to zone file logs. |

### Key Findings

1. **io.popen works** in standalone luajit inside the eqemu container. Full simulation of generate_response() returns correct sidecar response.
2. **Sidecar responds correctly**: JSON body builds properly, curl command succeeds, decoded.response is populated.
3. **Shell escaping is correct**: gsub("'", "'\\''") handles apostrophes properly — tested with "what's your name?" message.
4. **json.null works**: Encodes as null, passes to sidecar, response decoded correctly.
5. **No instruction limits** in zone Lua state. No SIGCHLD interference. PATH includes /usr/bin/curl.
6. **Seccomp active** (mode 2 BPF filter) but allows fork/exec since luajit works from same container.
7. **Zero diagnostic logging** in current code — failure path is completely invisible.
8. **Likely failure point**: io.popen() returns nil OR returns empty string in zone process. Static analysis cannot confirm which — must add logging.
9. **eq.log(87, msg)** (QuestErrors) goes to zone console log AND gmsay. This is the correct category for LLM failures.

### Implementation Plan

**Primary fix:** Add eq.log() diagnostic calls at EVERY nil-return path in generate_response(). This makes future failures visible in zone logs.

**Robustness fix:** If io.popen() returns nil (i.e., the zone process cannot spawn subprocesses), fall back to os.execute() + temp file approach. This handles the edge case where io.popen specifically fails in the daemon environment.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| io.popen(cmd) | lua.org/manual/5.1, tested in container | Yes | Works in standalone luajit. Behavior in zone daemon not yet confirmed. |
| os.execute(cmd) | lua.org/manual/5.1 | Yes | Returns 0 on success. Alternative to io.popen for temp-file approach. |
| io.open(path, mode) | lua.org/manual/5.1 | Yes | Can read temp file written by os.execute. |
| os.tmpname() | lua.org/manual/5.1 | Yes | Returns temp file path, unique per call. |
| eq.log(category, msg) | lua_general.cpp:6167, tested | Yes | cat 87 = QuestErrors → console + gmsay. |
| json.decode / json.encode | tested in container | Yes | lua_modules/json.lua — works correctly with null values. |

### Plan Amendments

After research: **No change to primary approach**. The fallback (os.execute + temp file) is an additional robustness measure, not a replacement. The diagnostic logging is the critical addition.

NOTE on os.tmpname(): Per Lua 5.1 manual, os.tmpname() returns a tmp filename but does NOT create the file. On POSIX systems the pattern is `/tmp/lua_XXXXXX`. After os.execute writes to it, we read it and os.remove() it.

### Verified Plan

Modify `llm_bridge.generate_response()`:

1. Add eq.log(87, ...) at every nil-return path so failures are visible in zone logs.
2. Use os.execute + temp file as fallback if io.popen returns nil (handle=nil case).
3. Keep the silent-to-player behavior — all logging goes to server logs only.
4. Add one success-path log at QuestDebug level (38, gmsay only) so we can confirm working state.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Task 3 status update | Independent tasks — no blocking dependencies. No coordination needed. |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| — | Task 3 is independent of Tasks 1+2 | Proceeding independently |

### Consensus Plan

**Agreed approach:** Add eq.log() diagnostics at all nil-return paths + os.execute fallback for io.popen=nil case.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Modify | generate_response(): add eq.log at each nil path, add os.execute fallback |

**Change sequence (final):**
1. Add `local LOG_ERRORS = 87` constant at top of generate_response
2. Add eq.log at io.popen=nil path (new fallback: os.execute + temp file)
3. Add eq.log at empty result path
4. Add eq.log at JSON decode failure path
5. Add eq.log at decoded.response=nil path
6. Add eq.log success path (QuestDebug=38) for confirmation

---

## Stage 4: Build

### Implementation Log

#### 2026-03-01 — Added diagnostic logging and io.popen fallback to generate_response()

**What:** Modified `llm_bridge.generate_response()` to:
- Add eq.log(87, ...) at each nil-return path for zone-log visibility
- Add os.execute + temp file fallback if io.popen returns nil
- Add eq.log(38, ...) success path for confirmation
- Preserve the silent-to-player behavior (no error spam in chat)

**Where:** `akk-stack/server/quests/lua_modules/llm_bridge.lua` lines 164-217

**Why:** The code works in standalone luajit but fails silently in the zone process. The diagnostic logging will reveal which path is failing. The io.popen fallback handles the edge case where io.popen doesn't work in the daemon environment.

**Notes:**
- eq.log(87) = QuestErrors → appears in zone log console + gmsay to GMs in zone
- eq.log(38) = QuestDebug → appears only as gmsay to GMs in zone
- os.tmpname() + os.execute fallback creates a temp file, reads it, then removes it
- The temp file approach is safe: zone process has write access to /tmp

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Zero visibility into failure | No eq.log() calls at nil-return paths | Added eq.log(87) at all nil-return paths |
| io.popen may return nil in zone daemon | Unknown zone process restriction | Added os.execute + temp file fallback |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Modified | generate_response(): diagnostic logging + io.popen fallback |

---

## Open Items

- [ ] After deployment: user needs to speak to companion and check zone log for eq.log output to confirm which path was failing
- [ ] If os.execute fallback triggers, investigate WHY io.popen fails in zone process

---

## Context for Next Agent

If another agent needs to pick up this work:

1. **The bug**: companion shows thinking emote but no LLM response. generate_response() returns nil silently.
2. **What we know**: code works in standalone luajit in container. Sidecar is healthy. Static analysis found no bug.
3. **The fix applied**: Added eq.log(87) at all nil-return paths in generate_response(). Added os.execute+temp file fallback if io.popen returns nil.
4. **Testing**: After #reloadquest, user speaks to companion. Check zone log at `/home/eqemu/server/logs/zone/qeynos2_*.log` for `[QuestErrors]` entries from llm_bridge.
5. **If still failing**: Check which eq.log message appears to narrow down the path. If "io.popen returned nil", the os.execute fallback should kick in automatically.
