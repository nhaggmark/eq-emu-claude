# BUG-001: Re-recruitment Blocked by Level Cap (and Cooldowns + Dismissed Flag)

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-04-27
> **Feature:** companion-rerecruit
> **Status:** Open

---

## Observed Behavior

Cannot re-recruit Lydl the Great in East Freeport after the companion has
previously been recruited and then died or was dismissed. The system reports
the NPC is "too low level" and refuses to allow re-recruitment.

## Expected Behavior

Once an NPC has been recruited as a companion at any point, the player must
ALWAYS be able to re-recruit that NPC after death, dismissal, or any other
drop-out condition. The companion is re-recruited with their gear and level
intact.

**User-stated invariant (verbatim):**
> "Once an NPC has been recruited as a companion at any point, the player
> must ALWAYS be able to re-recruit that NPC after death, dismissal, or any
> other drop-out condition. The companion is re-recruited with their gear
> and level intact. There must be no level rules around re-recruiting. The
> whole point of the companion system is that a player can recruit an NPC at
> level 5 and take them through the entire game."

## Reproduction Steps

1. Recruit Lydl the Great in East Freeport as a companion
2. Allow the companion to die OR use the dismiss command
3. Attempt to re-recruit Lydl the Great (use the recruit command — check
   `claude/docs/companion-commands-reference.md` for the correct syntax)
4. Observe: system refuses with "too low level" error

## Evidence

User-reported. No log excerpts captured yet — architect should collect logs
during triage.

## Affected Systems

- [x] C++ server source → c-expert (level cap enforcement logic)
- [x] Lua quest scripts → lua-expert (recruit script)
- [x] Database / SQL → data-expert (data_buckets cooldown entries)
- [x] Rules / Configuration → config-expert (any rule_values gating recruitment)
- [ ] Perl quest scripts → perl-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

---

## Scope Note

This bug is one of three known re-recruitment blockers. All three must be
fixed as a single coordinated change so the re-recruitment invariant holds
completely:

1. **Level caps** — today's reported blocker (Lydl "too low level")
2. **Cooldown timers** — `data_buckets` companion cooldowns are keyed on
   `character_id=0` (per MEMORY.md `reference_companion_cooldown_clearing`);
   cooldowns must be deleted by key pattern, not by column filter
3. **Dismissed flag** — persists incorrectly after death/dismissal, blocking
   future recruitment attempts

## Approach

TDD per user request. Engineers write tests first that prove the invariant
holds for all three blockers, then implement to make tests pass.

## Reference Docs

- MEMORY.md: `project_companion_rerecruit_pain` — full description of known
  re-recruitment pain points
- MEMORY.md: `reference_companion_cooldown_clearing` — data_buckets cooldown
  key pattern and deletion approach
- Companion Lua binding: `eqemu/zone/lua_companion.cpp`
- Global NPC handler: `akk-stack/server/quests/global/global_npc.lua`
- Client extensions: `akk-stack/server/quests/lua_modules/client_ext.lua`
