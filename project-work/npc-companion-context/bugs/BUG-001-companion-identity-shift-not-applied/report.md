# BUG-001: Companion Identity Shift Not Applied — Guard Gives Boilerplate NPC Dialogue

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-03
> **Feature:** npc-companion-context
> **Status:** Root Cause Confirmed — Sidecar Fix Required

---

## Root Cause (Confirmed 2026-03-03)

The Lua side is fully working. `is_companion=true` and all 22 companion
context fields are correctly built and sent to the sidecar. Confirmed via
in-game diagnostic: `[DEBUG] build_context ok: is_companion=true npc=Guard Liben`.

The NPC-LLM sidecar (`akk-stack/npc-llm-sidecar/app/`) has ZERO handling
for companion context fields. `prompt_builder.py`, `context_providers.py`,
`models.py`, and `main.py` contain no references to `is_companion`,
`companion_type`, `type_framing`, `evolution_context`, or any companion
field. The payload is received and silently ignored. The sidecar builds
its system prompt using only standard NPC fields regardless of companion status.

**Fix required in:** `akk-stack/npc-llm-sidecar/app/` (Python)

**Secondary issue:** Guard_Liben.lua local script fires on "hail" alongside
global_npc.lua, producing two responses. Separate from the sidecar framing
bug — may need a C++ fix to skip EventNPCLocal for companions.

---

## Observed Behavior

A recruited NPC companion (Guard Liben, a Qeynos guard) responds to player
conversation with full boilerplate NPC dialogue. When the player says "Good
job in that fight!" the guard responds: "I am but a humble guard, sworn to
protect and serve the city of Qeynos. It is my duty to stand watch at the
gate and warn travelers of the dangers that lurk in the hills to the north."

When asked "Are you a part of my group?" the guard explicitly denies being
a companion: "I am no companion, merely a guardian of these streets."

The debug log shows `llm_bridge: response OK for NPC Guard Liben player=Chelon`,
confirming the LLM bridge is firing and returning a response — but the
companion context layer is not shifting the NPC's identity from guard role
to group member role.

## Expected Behavior

Per PRD acceptance criterion #1: "A recruited companion responds to
conversation as a group member, not as their original role. A former guard
does not say 'Move along, citizen' or refer to their patrol duties as
current activity."

Guard Liben should speak as a group member who formerly served as a guard,
referencing that role in past tense if at all. The companion context fields
(is_companion, identity_shift, type_framing, race_culture) should be present
in the sidecar payload and the sidecar should use them to frame the response.

## Reproduction Steps

1. Rebuild server with C++ changes and start all processes
2. Log in with a GM character, run `#reloadquests`
3. Recruit Guard Liben (or any Qeynos guard) as a companion
4. Say "Good job in that fight!" or any conversational prompt
5. Observe the response — guard gives boilerplate NPC dialogue instead of
   companion-framed response

## Evidence

- Screenshot: `C:\Users\nhagg\Pictures\Screenshots\Screenshot 2026-03-03 055355.png`
- Debug log in chat window shows: `[Quest Debug] [lua_log] llm_bridge: response OK for NPC Guard Liben player=Chelon`
- The llm_bridge IS firing (response OK) but the companion context is either:
  (a) not being built/attached to the payload, or
  (b) built but the sidecar is ignoring it, or
  (c) the companion detection in llm_bridge.lua is not triggering for this NPC

## Affected Systems

- [x] Lua quest scripts → lua-expert (3 bugs fixed, all verified working)
- [ ] C++ server source → c-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [x] Infrastructure / Docker → infra-expert (sidecar Python code needs companion prompt handling)
