# Feature Brief — Raid Scaling for Small-Group Play

## Goal
Extend the server's small-group scaling from overland/group content into raid content. Make all Classic-Luclin raid bosses and raid-tier quest chains (including epics) beatable by a 1 player + 5 companion group, with occasional scaling flex when humans join.

## Difficulty Philosophy
- **Trash / named mobs:** current difficulty is good — *do not touch*
- **Raid bosses:** slightly harder than current named mobs, not overwhelmingly so
- **Tiered curve:** early raids are *mechanically harder* (positioning, add management, coordination); endgame raids are *peak mastery* (preparation matters, mistakes punish, represents the real wall)

## Group Composition Assumption
- Baseline: 1 player + 5 companions (~6 effective bodies)
- Humans may join occasionally — scaling should remain playable when headcount flexes up

## Scope
**Bosses:** every raid-tier NPC across Classic, Kunark, Velious, Luclin.

**Quest raid experiences — all in scope:**
- Epic 1.0 quests for every class
- Plane of Sky trials / island key progression
- Kael / Temple of Veeshan / Sleeper's Tomb keying
- Vex Thal key shard quest
- Faction-gated raid access (Skyshrine, Thurgadin, Kael, etc.)
- Miscellaneous raid-tier quests (Ring of Fire, Tunare avatar, etc.)

## Loot Philosophy
Keep stock drop tables. Raid kills remain loot pinatas — a solo player gets showered in gear. Lean into the "earned reward" feel.

## Respawn / Lockout
Reduce raid respawn timers across the board to the 6-24 hour range. Small-group-friendly without making kills feel trivial.

## Delivery — Phased
Each phase is a separate pipeline run. Phase 1 is the decision point.

1. **Phase 1 — Audit** → deliverable: comprehensive document cataloging every raid boss and raid quest chain, with its current scaling state (scaled by prior pass / partially scaled / untouched / special-case). First task for game-designer.
2. **Phase 2 — Classic** raids + Classic epics (Fear, Hate, Sky, Nagafen, Vox, dragons, relevant epic steps)
3. **Phase 3 — Kunark** (Trakanon, Veeshan's Peak, relevant epic steps)
4. **Phase 4 — Velious** (NToV, ToV, Kael, Sleeper's Tomb, AoW, Velious dragons)
5. **Phase 5 — Luclin** (Ssraeshza, Vex Thal, Luclin raid content)

After Phase 1, the user decides whether to continue the project as one sustained effort or split the era phases into separate projects.

## Success Criteria
- **Phase 1 (audit):** every raid encounter and quest raid chain catalogued with scaling status and a recommended action
- **Phases 2-5 (fixes):** every boss/quest chain with a scaling gap is patched; game-tester spot-checks a representative sample per phase; user confirms feel matches the difficulty philosophy

## Out of Scope
- Changes to trash or named difficulty in raid zones
- Loot table redesign
- New raid content or mechanics (we're scaling existing encounters, not redesigning them)

---

## Important Notes for game-designer

- Phase 1 is an AUDIT phase. The deliverable is a scaling-status document, not code changes.
- The user must be consulted after Phase 1 before continuing to Phase 2.
- Prior scaling work exists for overland/group content. The audit should reference it to identify gaps — what was already addressed, what was missed, what was only partially done.
- See `status.md` for the full decision log and phased delivery plan.
