# BUG-003: NPC Companion HP/Mana Regen Drastically Slowed (Possible Regression)

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-04-28
> **Feature:** companion-rez
> **Status:** Open

---

## Observed Behavior

When sitting/resting, NPC companion HP and mana regen rates have dropped dramatically. Previously, companions regenerated at a rate closely matching the player's own. Now, gsay reports show companion mana increasing by approximately 1% per report tick — drastically slower than expected.

The user is uncertain whether the regression is in:
- The actual regeneration tick rate, OR
- The reporting cadence (gsay output) — i.e., regen could be correct but reports are coming less often

User's verbatim report:
> "Mana and health regen seem to be screwed up again. When sitting I have my NPC companions gsay reporting their mana levels and for a long time the pace of their regen closely matched my own. It's back to being extremely slow, like 1% every report. I'm not sure if it's the actual regen that's messed up or the reporting but something appears to have changed in there."

The phrase "back to being extremely slow" indicates this was a previously-known bug that had been fixed. The recent companion-rez V2 changes may have reverted that fix.

## Expected Behavior

When sitting/resting, NPC companions regenerate HP and mana at a rate comparable to the player's own — fast enough that gsay reports show meaningful percentage changes (well above 1% per report).

## Reproduction Steps

1. Sit down with NPC companions also sitting (`!sit` or whatever command sets them)
2. With companion gsay reporting enabled, observe mana % and HP % over time
3. Compare regen pace to the player's own
4. Notice companion regen reports showing ~1% increments per report — drastically below the prior baseline

## Evidence

- Reproduces after V2 companion-rez fix
- The user's prior baseline ("for a long time") indicates the player has historical data to compare against
- Possible causes:
  - **Fix B** in V2 routed `ResurrectFromCorpse` through `Spawn(owner)`. If that path differs from manual setup in how regen-tick state is initialized, regen could be slower.
  - **Fix A** changed `Death()` to clear `membername[]` slot. Could affect group-based regen bonuses (e.g., spirit of wolf or other group buffs that depend on group membership tracking).
  - **R4 alive guards** added in `Companion::Process()`. If the guard accidentally short-circuits the regen tick, that would explain it.
  - **Reporting cadence** — gsay reporting may be on a separate timer that got affected.

## Affected Systems

- [x] C++ server source → c-expert (regen tick, AI Process loop, group regen bonuses)
- [x] Lua quest scripts → lua-expert (gsay reporting cadence — if it's Lua-driven)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

## Investigation Hints

- Investigate `Companion::Process()` regen tick — V2 added an alive-guard return for R4 (dead-cleric self-rez). Verify the guard doesn't short-circuit before regen runs.
- Check `Mob::Process` or `Mob::CalcManaRegen` / `Mob::CalcHPRegen` — has anything in the call chain regressed?
- Check how regen rate is computed for companions — is it scaled by group membership, level delta vs owner, or other factors that V2 could have affected?
- Search for prior regen fix — likely in companion.cpp or a related custom file. Diff against current state.
- Check the gsay reporting interval — is it driven by a timer? Has the timer cadence changed?
- Differentiate "actual regen" from "reporting cadence" by independent measurement (e.g., observe `mana` field changes via SQL polling, then compare to gsay report frequency).

## Severity Justification

**High** — companions need to regen at reasonable speed to be playable. 1%/report cadence makes downtime between fights unbearable, defeats the purpose of having a healer/caster companion. This is a sustained-play regression, not edge case.

## Cross-Reference

This bug pattern (regression caused by a refactor) ties into the new MEMORY.md feedback `feedback_refactor_regression_discipline.md` entry. The architect should consider whether the V3 fix needs to enumerate ALL adjacent functionality (visibility, regen, AI tick, gsay, group buffs, etc.) before changing anything else in `Companion::Process` or `Spawn`.
