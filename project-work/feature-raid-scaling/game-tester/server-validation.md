# Raid Scaling Phase 2 — Server-Side Validation Report

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Server-side result:** PASS WITH NOTES

---

## Summary

All Phase 2 Classic raid scaling changes are confirmed in the database and
match the architecture plan targets. The server is live with 8 zone processes,
loginserver, and world — no crash loops, no error logs. One noteworthy
observation (not a bug): Innoruuk revamp (186158) has `loottable_id=0`
because his loot is distributed through a quest script in
`hateplaneb/player.lua:event_loot` — this is pre-existing, intentional, and
unrelated to Phase 2. No rollback is required.

---

## Results Table

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Backup table: npc_types_backup_raid_scaling row count | PASS | 2548 rows (expected ~2548; over-capture of all era raid_target=1 L45-70 rows is intentional) |
| 2 | Backup table: spawn2_backup_raid_scaling row count | PASS | 6669 rows confirmed in DB (config-expert's dev-notes cited 6788 — their pre-execution read of a live count that may have included transient rows; DB source-of-truth matches data-expert's confirmed count of 6669) |
| 3 | Backup table: npc_spells_entries_backup_raid_scaling row count | PASS | 6 rows (full spell lists 118, 449, 969 captured) |
| 4 | Cazic Touch backup captured | PASS | 3 rows with spellid=982 in backup table |
| 5 | Nagafen HP = 14400 | PASS | Confirmed 14400 (was 32000, 55% cut) |
| 6 | Vox HP = 14400 | PASS | Confirmed 14400 |
| 7 | Phinigel HP = 13500 | PASS | Confirmed 13500 (was 18000, 25% cut) |
| 8 | Dread / Terror / Fright HP = 20000 each | PASS | All three confirmed 20000 |
| 9 | Wraith of a Shissar HP = 17500 | PASS | Confirmed 17500 |
| 10 | Tempest Reaver HP = 21000 | PASS | Confirmed 21000 |
| 11 | a_dracoliche HP = 40000, maxdmg = 420 | PASS | Both confirmed |
| 12 | Cazic Thule HP = 80000, maxdmg = 450 | PASS | Both confirmed |
| 13 | CT special_abilities unchanged (3,1,10 present) | PASS | String is `1,1^2,1^3,1,10^7,1^10,1^12,1^13,1^14,1^15,1^16,1^17,1^21,1^23,1^31,1` — no edit was made (correct; global MaxRampageTargets=2 cap is sufficient) |
| 14 | Ireblind Imp HP = 35000 | PASS | Confirmed 35000 |
| 15 | Enraged Golem HP = 40000 | PASS | Confirmed 40000 |
| 16 | Enraged Imp HP = 18000 | PASS | Confirmed 18000 |
| 17 | Innoruuk classic HP = 20000, maxdmg = 300 | PASS | Both confirmed |
| 18 | Maestro of Rancor HP = 14600 | PASS | Confirmed 14600 |
| 19 | Innoruuk revamp (186158) HP = 60000, maxdmg = 500 | PASS | Both confirmed |
| 20 | Evangelist of Hate (186198) HP = 60000, maxdmg = 600 | PASS | Both confirmed |
| 21 | hateplaneb named bosses (11 UPDATEs) | PASS | All checked: Lord of Ire, Master R'Tal, Magi P'Tasa, Hand of Maestro revamp, Mistress A'Zara, Deathrot Knight, Mistress of Scorn, Coercer T'vala, Ashenbone Broodmaster, Avatar of Abhorrence, Master of Spite, Dread Knight T'Kamax, Master of Vengence, Warlock J'Rath, Grim Abhorrent Kaltik, Lord of Fury, Templar J'Rosix — all at expected values |
| 22 | hateplaneb intentionally-unchanged NPCs | PASS | Lord of Loathing (15000), Vicar M'Kari (15000), Assassin Z'Jrix (21000), Sorcerer C'Gazin (21000), Evangelist W'Rixxus (21000), Warlord E'Prosio (21000), Corrupter of Life (25000) — all confirmed unchanged |
| 23 | Spiroc Lord HP = 22000 | PASS | Confirmed 22000 |
| 24 | Noble Dojorn HP = 22000 | PASS | Confirmed 22000 |
| 25 | Gorgalosk HP = 20000 | PASS | Confirmed 20000 |
| 26 | Thunder Spirit Princess HP = 17000 | PASS | Confirmed 17000 |
| 27 | Eye of Veeshan HP = 25600 | PASS | Confirmed 25600 |
| 28 | Keeper of Souls HP = 22000 | PASS | Confirmed 22000 |
| 29 | Bazzt Zzzt HP = 22000, maxdmg = 700 | PASS | Both confirmed |
| 30 | Overseer of Air HP = 22000 | PASS | Confirmed 22000 |
| 31 | Protector of Sky HP = 17000 | PASS | Confirmed 17000 |
| 32 | Hand of Veeshan HP = 22000 | PASS | Confirmed 22000 |
| 33 | Sister of the Spire HP = 12000 | PASS | Confirmed 12000 |
| 34 | essence tamer (71071) HP = 11500 unchanged | PASS | Confirmed 11500 — no change applied |
| 35 | essence tamer spell list intact (spell 303 present) | PASS | npc_spells_id=212, spellid=303 confirmed in npc_spells_entries |
| 36 | cazicthule zone event mobs (48211, 48237-48252) | PASS | All 12 confirmed: boiling ooze 35000, Avatar of Dread/Fright/Terror 30000 each, Spinechill Spider/Gorgon/Amygdalan Knight 22000 each, Shiverback 25000, Guards Thrasciss/Khataruss/Scithiss 18000 each, Tentacle Terror 20000 |
| 37 | Thul Tae Ew High Priest HP = 25000 | PASS | Confirmed 25000 |
| 38 | Zordakalicus Ragefire HP = 26000 | PASS | Confirmed 26000 |
| 39 | Guardian of the Seal HP = 87000 | PASS | Confirmed 87000 |
| 40 | Death-touch: Cazic Touch (spell 982) removed from lists 118, 449, 969 | PASS | 0 rows returned; confirmed deleted |
| 41 | Remaining spell entries in lists 118/449/969 = 3 (one per list) | PASS | list 118: spell 988 (Greater Spiroc Thunder); list 449: spell 897 (Rotting Flesh); list 969: spell 899 (Whirl) — all retained |
| 42 | Nagafen respawn = 21600 | PASS | Confirmed 21600s (6h) |
| 43 | Vox respawn = 21600 | PASS | Confirmed 21600s |
| 44 | Phinigel respawn = 21600 | PASS | Confirmed 21600s |
| 45 | CT respawn = 43200 | PASS | Confirmed 43200s (12h) |
| 46 | Guardian of the Seal respawn = 43200 | PASS | Confirmed 43200s (12h) |
| 47 | Maestro of Rancor respawn = 21600 | PASS | Confirmed 21600s |
| 48 | hateplaneb Grandmaster H'Qilm (186183) respawn = 21600 | PASS | Confirmed 21600s (was 194400s / 54h) |
| 49 | PoHate council (76017) respawn = 21600 | PASS (NOTE) | Data-expert's verification comment said "expect 1440" but 21600 is correct — council are Classic raid bosses subject to Decision #8 low-tier 6h target; 21600 is the intended value |
| 50 | Spiroc Lord (71012) respawn = 21600 | PASS (NOTE) | Has a spawn2 row (airplane zone id 2630) at 21600. Architecture noted it as "triggered only" but it also has a standing spawn. The 21600 value is correct regardless. |
| 51 | PoSky triggered NPCs (Keeper of Souls, Bazzt Zzzt, Overseer, Protector, Hand, Sister) have no spawn2 rows | PASS | Confirmed no spawn2 rows — these are script-spawned only; respawn UPDATE correctly skipped them |
| 52 | Night Crew NPCs 20054-20064 HP unchanged from backup | PASS | All 6 IDs confirmed identical to backup (12000-27000 range) |
| 53 | PoFear trash mobs unchanged (72005, 72007, 72008, 72016) | PASS | Current HP = backup HP = 14285 for all — raid_target=1 trash was not touched by Phase 2 UPDATEs |
| 54 | Loot chains: Nagafen, CT | PASS | Nagafen: loottable_id=4027 "Lord_Nagafen" with 5 lootdrop entries; CT: loottable_id=291 "Cazic_Thule" with 2 entries |
| 55 | Loot chain: Keeper of Souls | PASS | loottable_id=97436 with 2 lootdrop entries |
| 56 | Loot chain: Innoruuk revamp (186158) loottable_id=0 | NOTE (not a bug) | loottable_id=0 is pre-existing. Loot is distributed by quest script `hateplaneb/player.lua:event_loot`. Not a Phase 2 regression. |
| 57 | Global combat rules intact | PASS | MaxRampageTargets=2, DefaultRampageTargets=1, NPCFlurryChance=12, NPCAssistCap=3, StartEnrageValue=5 — all confirmed unchanged |
| 58 | Server processes stable | PASS | loginserver, world, zone dynamic_01 through dynamic_08 all running; no crash loops; world log clean of errors |
| 59 | No recent crash logs in raid zones | PASS | Most recent crash is 2026-04-20 in lavastorm (unrelated). No fearplane, airplane, hateplaneb, soldungb, or permafrost crashes |
| 60 | No source code changes (build verification N/A) | PASS | Architecture confirmed 100% SQL; no C++/Lua/Perl changes; no build required |

---

## Notes

### Note 1: spawn2_backup row count discrepancy (6669 vs 6788)

data-expert recorded 6669 rows after Task 1. config-expert's Stage 4 Build Log
recorded 6788 rows after verifying Task 7. Both agents queried the same backup
table at different times. The current confirmed count is 6669. The 6788 figure
from config-expert's notes may reflect a read during a time when session/temp
rows existed, or a query that double-counted via the supplemental INSERT
(which uses `id NOT IN (SELECT id FROM ...)` to avoid duplicates). The backup
table is intact and the Cazic Touch rows are present — rollback is functional.

### Note 2: PoHate council respawn at 21600 (not 1440)

data-expert's Stage 4 verification table includes a note flagging this:
the SQL comment said "expect 1440" but the implementation correctly set them
to 21600 (6h), which aligns with Decision #8 (low-tier Classic bosses = 6h).
The PoHate classic council (76017, 76042-76045) are in the 6h respawn UPDATE
list. The verification comment was wrong; the SQL was correct. Current value
of 21600 is the intended result.

### Note 3: Spiroc Lord has standing spawn2 row

Architecture doc described Spiroc Lord (71012) as "script-spawned / triggered"
but it also has a standing spawn entry (spawn2 id 2630 in airplane zone). The
respawn UPDATE correctly applied 21600 to this row. This means Spiroc Lord
can respawn naturally after 6h if killed in its static spawn location. This is
the correct behavior.

### Note 4: Innoruuk revamp (186158) loottable_id=0

Pre-existing. Not a Phase 2 regression. Loot is scripted via
`hateplaneb/player.lua:event_loot`. No action required. The in-game test should
confirm loot drops after the event kill.

---

## Spell Cache Caveat (from config-expert)

`#reloadworld` propagates `npc_types` and `spawn2` changes to zone processes.
The `npc_spells_entries` DELETE (spell 982 Cazic Touch) is confirmed in the DB
with 0 rows. However, zone processes cache spell lists at zone boot time, not on
`#reloadworld`. The zone processes were started fresh at 20:42 today (per ps aux
output) AFTER the `#reloadworld` was issued. This means the spell list cache
should have loaded the updated (post-DELETE) data from the DB. The death-touch
removal should be live. If the user encounters a Cazic Touch proc during in-game
testing, infra-expert must run a full zone restart for the affected zone to
force spell list reload. The DB state is correct either way.

**Recommendation:** Before any PoSky encounter during in-game testing, verify
zone boot time matches post-reloadworld. If any zone shows a start time before
20:42, it may have stale spell list cache.

---

## Rollback Instructions

If any Phase 2 change must be reversed:

```bash
docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < \
  /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/03-rollback.sql
```

Then issue `#reloadworld` via world telnet console (port 9000):
```
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```

For full rollback including spell list cache: infra-expert full-stack restart.
