# Project Status

## Active Features

| Feature | Phase | Branch | Status |
|---------|-------|--------|--------|
| companion-aggro-fixes | Implementation | bugfix/companion-aggro-fixes | BUG-009 thru BUG-012 fixes deployed, BUG-013/014 fix deployed pending validation |
| companion-levelup-fixes | Complete | bugfix/companion-levelup-fixes | Merged to main |
| companion-ai-stances | Complete | feature/companion-ai-stances | Merged to main |
| companion-experience | Validation | bugfix/companion-experience | BUG-001 fix confirmed working, remaining tests pending |
| group-chat-addressing | Complete | feature/group-chat-addressing | Merged to main |
| companion-equipment | Complete | feature/companion-equipment | All bugs resolved, validated in-game |

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
