# BUG-001: Phase 4a Tunare HP Scaling Applied to Wrong NPC ID

> **Severity:** High
> **Reported by:** game-tester
> **Date:** 2026-04-23
> **Feature:** raid-scaling / Phase 4a Velious non-ToV
> **Status:** Fix Applied (2026-04-23) — pending game-tester re-verification of PoG Tunare fight

---

## Observed Behavior

The Phase 4a implementation SQL updated NPC ID 127001 (`#_Tunare`) HP from
530,000 to 150,000. This NPC is the passive trigger NPC — it sits in a tree
in growthplane, immediately depops when attacked, and spawns the actual combat
boss (NPC ID 127098, also named `#Tunare`) via `eq.spawn2()` in its
`event_combat` handler.

The actual combat boss `#Tunare` (127098) is at 530,000 HP — unchanged from
PEQ default.

DB confirmation:
- 127001 `#_Tunare`: hp = 150,000 (scaled — WRONG TARGET)
- 127098 `#Tunare`: hp = 530,000 (unscaled — CORRECT TARGET, MISSED)

## Expected Behavior

NPC ID 127098 (`#Tunare`, the killable combat boss) should be at approximately
150,000 HP per the Phase 4a architecture target (72% cut from 530k).

NPC ID 127001 (`#_Tunare`, the passive trigger) HP does not matter for
gameplay — it depops before it can be killed. Setting it to 150k is harmless
but incorrect in intent.

## Reproduction Steps

1. Travel to growthplane
2. Engage `#_Tunare` (the NPC in the tree at approx -247, 1609, -40)
3. The NPC depops and spawns `#Tunare` (127098)
4. `#Tunare` (127098) will be at 530,000 HP — the original PEQ default

## Evidence

Script: `akk-stack/server/quests/growthplane/#_Tunare.lua` line 6:
`eq.spawn2(127098,0,0,-247,1609,-40,424);`

DB query result:
```
id     | name      | hp     | raid_target
127001 | #_Tunare  | 150000 | 1   (trigger, scaled wrong)
127098 | #Tunare   | 530000 | 1   (combat boss, unscaled)
```

## Affected Systems

- [x] Database / SQL -> data-expert

## Fix Required

data-expert should:
1. Add ID 127098 to `npc_types_backup_raid_scaling_velious_a` (INSERT the
   current row for 127098 — it was missed from the backup).
2. Apply: `UPDATE npc_types SET hp = 150000 WHERE id = 127098;`
3. No spawn2 change needed — 127098 is always script-spawned via eq.spawn2()
   and has no spawn2 row.
4. Optionally revert 127001 to 530k (it was harmlessly scaled but is not a
   kill target); recommend leaving at 150k since it causes no gameplay issue.

---

## Resolution

**Fixed by:** data-expert
**Date:** 2026-04-23
**SQL file:** `data-expert/sql/09-bug-001-tunare-fix.sql`

**Actions taken:**
1. Inserted pre-change row for NPC 127098 into `npc_types_backup_raid_scaling_velious_a` (9-column slim backup; hp=530000 captured before any change).
2. Applied `UPDATE npc_types SET hp = 150000 WHERE id = 127098;`
3. Issued `#reloadworld` via world telnet port 9000. Response: "Reloading World..."

**Verification:**
- Backup: 1 row in `npc_types_backup_raid_scaling_velious_a` WHERE id=127098, hp=530000
- Live: `npc_types` WHERE id=127098 now shows hp=150000, maxdmg=926, raid_target=1
- NPC 127001 left at hp=150000 (harmless; depops on engage; no gameplay impact)

**Pending:** game-tester re-verification of PoG Tunare fight (in-game test — engage trigger, confirm combat boss spawns at 150k HP).
