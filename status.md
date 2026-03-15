# Project Status

## Active Features

| Feature | Phase | Branch | Status |
|---------|-------|--------|--------|
| companion-aggro-fixes | Complete | bugfix/companion-aggro-fixes | Merged to main — all fixes validated |
| improved-companion-stats | Implementation | feature/improved-companion-stats | !stats command + !equipment enhancement deployed |
| companion-levelup-fixes | Complete | bugfix/companion-levelup-fixes | Merged to main |
| companion-ai-stances | Complete | feature/companion-ai-stances | Merged to main |
| companion-experience | Validation | bugfix/companion-experience | BUG-001 fix confirmed working, remaining tests pending |
| group-chat-addressing | Complete | feature/group-chat-addressing | Merged to main |
| companion-equipment | Complete | feature/companion-equipment | All bugs resolved, validated in-game |
| npc-companion-realistic-stats | Complete | feature/npc-companion-realistic-stats | Merged to main — 5 phases + audit fixes + BUG-017/018 fixes, 16 suites 242+ tests |
| companion-group-commands | Complete | feature/companion-group-commands | Merged to main — 9 group chat commands + IsSitting binding + BUG-019/020 fixes, 17 suites |
| companion-group-debugging | Complete | bugfix/companion-group-debugging | Merged to main — BUG-021/022 fixed, 14 tests |
| companion-behavior-improvements | Complete | feature/companion-behavior-improvements | Merged to main — BUG-023/024/025/026/027 fixed |
| companion-recruitment-overhaul | Complete | feature/companion-recruitment-overhaul | Merged to main — two-track recruitment, Lua/C++ contract aligned, BUG-028 fixed |
| companion-authenticity-audit | Complete | feature/companion-authenticity-audit | Merged to main — 17-gap report, all gaps addressed |
| companion-authenticity-fixes | Complete | feature/companion-authenticity-fixes | Merged to main — GAP-01 through GAP-06 (crits, spell targeting, defensive skills, stats, spell priorities, melee damage) |
| companion-authenticity-phase3-4 | Complete | feature/companion-authenticity-phase3-4 | Merged to main — GAP-07/09/10/12/13/14/17 (caster spells, luabind, commentary, level-up, attack skills) |
| companion-audit-pass2 | Complete | feature/companion-audit-pass2 | Merged to main — companion_spell_sets priorities, cleric heals, contract fixes, constructor scaling, 164+ new tests |

## Bug Reports

| ID | Title | Severity | Feature | Status |
|----|-------|----------|---------|--------|
| BUG-001 | No XP gain when companion deals killing blow | Critical | companion-experience | Fix confirmed in-game |
| BUG-002 | Companion combat hits not shown in "Other's Hit" windows | High | companion-equipment | Resolved |
| BUG-003 | Item lost when companion cannot equip it | Critical | companion-equipment | Resolved |
| BUG-004 | Equipping compatible item fails when slot already occupied | High | companion-equipment | Resolved |
| BUG-005 | Compatible item falsely rejected by class/race restriction | High | companion-equipment | Resolved |
| BUG-006 | Balanced stance companion attacks when player merely targets mob | High | companion-ai-stances | Resolved |
| BUG-007 | Companion disappears from group interface on level up | Critical | companion-levelup-fixes | Resolved |
| BUG-008 | Companions drop from group interface when zoning | Critical | companion-levelup-fixes | Resolved |
| BUG-009 | Companion NPCs generate zero hate/aggro on mobs | Critical | companion-aggro-fixes | Fix deployed, pending validation |
| BUG-010 | Companion level reverts to base NPC level on zone-in | Critical | companion-aggro-fixes | Fix deployed, pending validation |
| BUG-011 | Zone crash when companion dies in combat | Critical | companion-aggro-fixes | Fix deployed (ValidateMember self-healing) |
| BUG-012 | Companion loses equipment on death/re-recruitment | High | companion-aggro-fixes | Fix deployed (is_dismissed state management) |
| BUG-013 | Dead companion re-recruitment blocked without DB cleanup | High | companion-aggro-fixes | Fix deployed, pending validation |
| BUG-014 | Caster/healer combat positioning and casting broken | Critical | companion-aggro-fixes | Fix deployed, pending validation |
| BUG-015 | Companion ranged attack flags not set when bow/arrows equipped | High | improved-companion-stats | Open |
| BUG-016 | Stackable item quantity lost when trading to companion | Medium | improved-companion-stats | Open |
| BUG-017 | Companion caster mana percentage chat messages show wrong values | High | npc-companion-realistic-stats | Resolved |
| BUG-018 | Equipment trade to companion produces duplicate items when replacing gear | Critical | npc-companion-realistic-stats | Resolved |
| BUG-019 | Wizard companion spams damage shield out of combat | High | companion-group-commands | Resolved |
| BUG-020 | Companion NPCs cast buffs while sitting/meditating | High | companion-group-commands | Resolved |
| BUG-021 | @all !assist produces stack trace error in console | Critical | companion-group-debugging | Resolved |
| BUG-022 | !tome command does not move companions to player location | High | companion-group-debugging | Resolved |
| BUG-023 | Rogue companion takes too wide a circle for backstab positioning | Medium | companion-behavior-improvements | Resolved |
| BUG-024 | Caster companions should announce LOM at 15% mana | Medium | companion-behavior-improvements | Resolved |
| BUG-025 | !buffs command only buffs player instead of all party members | High | companion-behavior-improvements | Resolved |
| BUG-026 | Caster companions lose LOS when positioning at fixed distance | High | companion-behavior-improvements | Resolved |
| BUG-027 | Companions should always regenerate mana at meditation rates | High | companion-behavior-improvements | Resolved |
| BUG-028 | Previously recruited NPC refuses re-recruitment after group wipe | Critical | companion-recruitment-overhaul | Resolved — data recovered, Death() hardened with direct SQL fallback |
