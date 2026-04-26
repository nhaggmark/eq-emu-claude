# Raid Scaling Phase 5b (Luclin VT — FINAL PHASE) — In-Game Testing Guide

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Zone:** `vexthal` (Vex Thal)
> **Prerequisite for all sessions:** Character at level 65+ with Elemental Armor-tier gear
> (or use `#level 65` + `#summonitem` for test kit). VT access requires the Scepter of
> Shadows key. Use `#zone vexthal` for direct access if needed.

---

## Testing Priority Order

Sessions are ordered by criticality. Complete Session 1 before anything else — it is the
gate test for whether the spell cache flush was successful.

1. **Aten Ha Ra Destroy-form cache flush** (CRITICAL — gate test)
2. **Aten Ha Ra non-Destroy form** (primary encounter validation)
3. **9 inner-VT boss sample** (boss HP + Warder add wave)
4. **Akhevan Warders** (direct add-wave test)
5. **Va_Dyn_Khar Palace Key cycle** (respawn preservation)
6. **Yaemiu trash tier sample** (HP cut without respawn change)
7. **A_burrower_parasite in thedeep** (Q68=A audit-leak closure)

---

## Session 1 — Aten Ha Ra Destroy-Form Cache Flush (CRITICAL)

**What this tests:** Q67=B DELETE of spell 1948 (Destroy, -100,000 HP PBAE DT) from list
229. The DELETE is confirmed in the database, but the in-memory spell list 229 cache must
have been flushed by the vexthal zone restart (task LB13b). This test confirms it.

**Why it is the gate test:** If Destroy fires during this session, the cache is stale and
all Aten Ha Ra testing must stop until infra-expert performs a full-stack restart.

**Prerequisite:** 9 inner-VT gating bosses must still be alive (or at least 1 of 158007/
158008/158009/158010/158011/158012/158013/158014/158015 must be up) for Aten_Trigger to
spawn the Destroy form (158006). Do NOT clear all 9 bosses before this test.

**Steps:**
1. Zone into vexthal with `#zone vexthal`
2. Use `#goto` to position near the Aten_Trigger location (1153.3, -0.4, 235.3)
3. Verify at least 1 inner-VT boss is still alive (use `#findnpc Kaas_Thox_Xi` or similar)
4. Wait for the Aten_Trigger (158095) to spawn the Destroy form. The trigger fires every
   60 seconds. If Aten Ha Ra (Destroy) (NPC 158006) is already up, proceed to step 5.
5. Target NPC 158006 and note HP with `#showstats` — **Expected: 180,000 HP**
6. Engage 158006. Combat should begin normally.
7. **Watch for 3-4 combat rounds.** Specifically watch for a spell cast named "Destroy"
   or any instant -100,000 HP event.

**Pass if:**
- 158006 engages in normal melee/spell combat without casting "Destroy"
- HP at engage confirms 180,000

**Fail if:**
- Any character takes a -100,000 HP "Destroy" hit (cache flush failed)
- 158006 HP is anything other than 180,000

**If FAIL:** Stop all Aten testing. Dispatch infra-expert for full-stack server restart
to flush the vexthal zone process spell cache. After restart, repeat this test.

**GM setup commands:**
- `#zone vexthal` — zone directly to vexthal
- `#goto 1153 0 235` — approximate Aten_Trigger location
- `#findnpc Aten_Ha_Ra` — locate the Aten NPC once spawned
- `#showstats` — confirm HP of targeted NPC
- `#kill` — end the fight quickly if needed

---

## Session 2 — Aten Ha Ra Full Kill (Non-Destroy Form)

**What this tests:** After clearing all 9 gating bosses, Aten_Trigger spawns the
non-Destroy form (158096). Confirm HP = 180,000 and that spell list 540 spells fire
(Word of Command self-heal, Silence, Fling) but no Destroy.

**Prerequisite:** All 9 inner-VT bosses (158007-158015) must be dead. Complete Sessions
3 and 4 first (killing the inner bosses), then return here.

**Steps:**
1. Confirm all 9 inner-VT bosses are dead (use `#findnpc` for each or wait for respawn
   timers to confirm they are gone)
2. Wait up to 60 seconds for Aten_Trigger (158095) to spawn the non-Destroy form
3. Target 158096 and use `#showstats` — **Expected: 180,000 HP, spell list 540**
4. Engage. Watch for:
   - **Word of Command self-heal** on Aten (heals ~3,000 HP during fight — expected)
   - **Silence** effect on party members (expected — signature mechanic per Decision #11)
   - **Fling** knockback (expected — signature mechanic)
5. Kill 158096. After kill, note the qglobal lockout timer fires (108-120 minute cooldown
   before Aten_Trigger re-evaluates and can respawn Aten)

**Pass if:**
- 158096 HP = 180,000 at engage
- No "Destroy" instakill fires during the fight
- Word of Command, Silence, and/or Fling mechanics observed
- Kill completes without group wipe

**Fail if:**
- Destroy fires (cache flush failure — see Session 1 remediation)
- HP at engage does not match 180,000
- Aten_Trigger fails to spawn 158096 after all gating bosses confirmed dead (script
  evaluation issue — investigate #Aten_Trigger.pl)

---

## Session 3 — 9 Inner-VT Boss Sample (2-3 Bosses)

**What this tests:** HP and Akhevan Warder add waves for a sample of the 9 gating bosses.
Test Kaas_Thox_Xi_Aten_Ha_Ra (158007, most adds), Diabo_Xi_Va (158014, fewest adds), and
one of the damage outlier trims (158015 Diabo_Xi_Xin).

**Steps:**

**Test boss 1: Kaas_Thox_Xi_Aten_Ha_Ra (158007)**
1. `#findnpc Kaas_Thox` and target
2. `#showstats` — **Expected: 160,000 HP, maxdmg 800**
3. Engage. On aggro, watch for Akhevan_Warder (158087) spawns: **2 Warders expected**
4. Verify Warder HP: target a Warder and `#showstats` — **Expected: 80,000 HP**
5. Kill boss and both Warders

**Test boss 2: Diabo_Xi_Va (158014)**
1. `#findnpc Diabo_Xi_Va` and target
2. `#showstats` — **Expected: 85,000 HP**
3. Engage. Watch for Akhevan_Warder (158088) spawns: **5 Warders expected**
4. Verify Warder HP at 80,000 each
5. Kill boss and Warders

**Test boss 3: Diabo_Xi_Xin (158015, damage trim check)**
1. `#findnpc Diabo_Xi_Xin` (not Diabo_Xi_Xin_Thall) and target
2. `#showstats` — **Expected: 90,000 HP, maxdmg 650** (trimmed from 1,200)
3. Engage. Watch maximum melee hit values — no single hit should approach 1,200+
4. Kill

**Pass if:**
- All HP values match architecture targets
- Akhevan Warder counts match per-boss expectations (2/5 Warders respectively)
- Warder HP = 80,000 each
- Diabo_Xi_Xin maximum melee swings stay below 700 (well within 650 cap)

**Fail if:**
- Any HP value differs from target (indicates DB cache not refreshed — `#reloadworld`)
- Warder HP above 80,000 (indicates Phase 5b UPDATE did not apply to Warder IDs)
- Melee hits on 158015 exceeding ~700+ consistently (damage cap not applied)

**Note on respawn:** All 9 inner-VT bosses now respawn at 86,400s (24h). After killing
for this session, they will not be back for 24 hours. If testing must be repeated, use
`#spawn 158007` etc. to re-spawn for additional test rounds.

---

## Session 4 — Akhevan Warder Direct Test (Va_Xi_Aten_Ha_Ra Add Wave)

**What this tests:** The largest Warder add wave in the zone — Va_Xi_Aten_Ha_Ra (158009)
summons 14 Warders of type 158094 on engage. This was the biggest small-group blocker
pre-Phase 5b (14 x 901,000 HP = 12.6M Warder HP pool).

**Steps:**
1. `#findnpc Va_Xi_Aten_Ha_Ra` and target 158009
2. `#showstats` — **Expected: 130,000 HP, maxdmg 750**
3. Engage. Count Akhevan_Warder spawns — **14 Warders (NPC 158094) expected**
4. Spot-check 2-3 Warder HP: **Expected: 80,000 HP each**
5. Confirm the group can start working through the Warder wave with normal combat
   (14 x 80k = 1.12M total Warder HP pool — clearable in ~8-15min at scaled group DPS)
6. Kill Va_Xi_Aten_Ha_Ra and all 14 Warders

**Pass if:**
- 158009 HP = 130,000, maxdmg 750
- Approximately 14 Warder 158094 spawns appear on engage
- All Warders at 80,000 HP
- Group can viably work through the add wave (not an instant wipe)

**Fail if:**
- Any Warder HP above 80,000 (indicates UPDATE for 158094 not applied)
- Warder count dramatically different from 14 (script behavior changed)

---

## Session 5 — Va_Dyn_Khar Palace Key Cycle

**What this tests:** Va_Dyn_Khar (158081) HP cut and Palace Key drop preserved. Respawn
at 21,600s (6h) must be confirmed unchanged per Decision #74.

**Steps:**
1. `#findnpc Va_Dyn_Khar` and target 158081
2. `#showstats` — **Expected: 60,000 HP**
3. Engage and kill Va_Dyn_Khar
4. Confirm **Palace Key (item 8010)** drops from the corpse
5. If Palace Key drops: equip or verify the key allows passage through the keyed door
   (door keyitem=8010) in the inner palace section

**Optional — respawn timer verification (if you can afford a 6-hour wait):**
- Note the time of kill
- Return after 6 hours; confirm Va_Dyn_Khar has respawned
- (Alternatively, trust server-side validation which confirmed 21,600s in spawn2)

**Pass if:**
- 158081 HP = 60,000
- Palace Key (item 8010) drops from the corpse
- Key functions on the inner palace door

**Fail if:**
- HP does not match 60,000
- Palace Key does not drop (loot chain regression — check loottable 20537)

---

## Session 6 — Yaemiu Trash Tier Sample

**What this tests:** Level-tiered HP cuts across the 5 Yaemiu tiers (Eom/Pli/Zun/Zov/Qua)
and the shadow-type NPCs. Respawn timers must be UNCHANGED (Decision #2: trash respawns
preserved for natural attrition gameplay).

**Steps:**

**Eom-tier (L66):**
1. Find any Eom_* Yaemiu — `#findnpc Eom_Centien` or similar
2. `#showstats` — **Expected: 25,000 HP** (Eom_Centien, Eom_Thall, etc.)
3. Engage and kill. Note respawn time — **Expected: ~1,710s (28.5 min) or 3,240s (54 min)**

**Pli-tier (L64):**
1. Find any Pli_* Yaemiu
2. `#showstats` — **Expected: 22,000 HP** (most Pli variants)
3. Kill. Confirm respawn unchanged from natural cadence

**Zun-tier (L61):**
1. Find any Zun_* Yaemiu
2. `#showstats` — **Expected: 18,000 HP**

**Qua-tier (L55):**
1. Find any Qua_* Yaemiu
2. `#showstats` — **Expected: 11,000 HP**

**Shadow-type (trap-spawned Yaemiu):**
1. Walk into areas with shade_trigger (158128) proximity traps
2. When a shadow Yaemiu spawns, `#showstats` — should match level-tier HP:
   - a_writhing_shadow (L66) → **25,000 HP**
   - a_mass_of_shadows (L61) → **18,000 HP**
   - a_pool_of_shadows (L58) → **15,000 HP**
   - a_living_shadow (L55) → **12,000 HP**

**Pass if:**
- Each tier is at its target HP (per architecture's level-tiered schedule)
- Yaemiu respawn within normal cadence (~28-54 min for standing spawns)
- Trap-spawned shadows appear at correct HP when proximity triggers fire

**Fail if:**
- Any Yaemiu HP above 50,000 (pre-scaled values) — indicates UPDATE did not apply
- Respawn dramatically faster or slower than natural (regression in spawn2 timing)

---

## Session 7 — A_burrower_parasite in thedeep (Q68=A Audit-Leak Closure)

**What this tests:** The Phase 5a audit-leak NPC (164089) in thedeep zone at 90,000 HP.
This NPC drops Glowing Orb of Luclinite (item 22196), the Phase 4 VT key component.

**Prerequisite:** The script-spawned NPC requires triggering via `thedeep/A_burrower_parasite.pl`.
Check if it spawns naturally or must be triggered.

**Steps:**
1. `#zone thedeep` to travel to The Deep
2. Use `#spawn 164089` if NPC is not already present (script-spawned, may need trigger)
3. Target the A_burrower_parasite and `#showstats` — **Expected: 90,000 HP**
4. Engage and kill
5. Confirm Glowing Orb of Luclinite (item 22196) drops at 100% chance (as per loot table)

**Pass if:**
- 164089 HP = 90,000
- Glowing Orb of Luclinite drops

**Fail if:**
- HP does not match 90,000 (UPDATE for 164089 not applied or cache issue)
- Glowing Orb does not drop (loot table regression)

---

## Edge Cases and Known Behaviors

**Aten Ha Ra dual-form sequencing:**
If players engage Aten 158006 (Destroy form) before clearing all 9 gating bosses post-Phase 5b,
they will face 158006 at 180,000 HP without the Destroy DT (Q67=B DELETE confirmed). This
is different from pre-Phase 5b behavior (180k HP + Destroy = wipe regardless). Post-Phase 5b,
attempting 158006 before boss clear is no longer instantly lethal.

This behavior is INTENDED per Q67=B decision (PBAE DT removal = small-group unblock).
The natural encounter flow is still to clear the 9 gating bosses first (Aten_Trigger
spawns 158096 non-Destroy form after full clear), but even the "wrong" sequence now
permits completion with enough effort.

**Akhevan Warder depop on boss death:**
Akhevan Warders are script-spawned by each boss on aggro and despawn when the boss dies
(per architecture's Warder Add-Wave Map). If a boss is killed while Warders are alive,
the Warders should despawn. Test this incidentally during Sessions 3 and 4.

**Thall Va Xakra train-pull (both 158016 and 158125):**
Both Thall Va Xakra forms use train-pull scripts that pull existing Yaemiu trash mobs
to the boss's location every 30 seconds. This behavior is HP-independent. After Phase 5b:
- The boss HP is 80,000 (down from 900,000) — much more tractable
- The pulled Yaemiu trash mobs are also scaled down (18k-25k HP at Zun/Eom tier)
- The train-pull mechanic itself is UNCHANGED (Decision #11)

During any Thall Va Xakra fight, expect waves of Yaemiu trash to converge on the boss
location. The scaled HP on both boss and trash makes this encounter significantly more
manageable.

**Aten Ha Ra post-kill lockout:**
After killing either Aten form, the qglobal lockout `aten` is set for 108-120 minutes.
Aten_Trigger will not re-evaluate spawn conditions during this window. This behavior
is UNCHANGED (Q70=A decision: preserve native ~2h respawn lockout).

---

## Rollback Instructions

If any critical failure is found and the Phase 5b changes need to be rolled back:

1. Run `18-luclin-b-rollback.sql` via:
   ```
   docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < /path/to/18-luclin-b-rollback.sql
   ```
2. The rollback script restores all Phase 5b npc_types UPDATEs from the backup table,
   restores spawn2 respawn timers, and re-inserts the spell 1948 row into list 229
3. Issue `#reloadworld` after rollback
4. Restart the vexthal zone process to re-load the restored spell list 229 cache

**Note:** Rollback only covers Phase 5b changes. All Phase 5a/4b/4a/3/2 changes remain
intact and are unaffected by the Phase 5b rollback script.
