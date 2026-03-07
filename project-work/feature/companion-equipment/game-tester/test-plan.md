# Companion Equipment Management Enhancement — Test Plan

> **Feature branch:** `feature/companion-equipment`
> **Author:** game-tester
> **Date:** 2026-03-07
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

This test plan covers the Companion Equipment Management Enhancement feature,
which upgrades the companion equipment system to:
- Display all 19 slots in `!equipment` with item names or "(empty)"
- Return only the displaced slot's item when trading (not a random item)
- Prefer empty slots for multi-slot items (rings, wrists)
- Enforce class/race restrictions on equipped items
- Apply equipped item stats to companion combat performance (critical fix)
- Persist equipment through death and dismissal
- Support slot name aliases in `!unequip`
- Return money traded to companions with a message

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all implementation tasks Complete (dev-notes confirmed)
- [x] Acceptance criteria identified: 19 criteria from PRD

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | DB: rule_values — 3 new Companions rules present | PASS | EnforceClassRestrictions, EnforceRaceRestrictions, EquipmentPersistsThroughDeath all present with value 'true' |
| 2 | DB: companion_inventories schema | PASS | Schema correct: id, companion_id, slot_id, item_id, charges, aug_slot_1-5 |
| 3 | DB: companion_inventories FK integrity (item_id → items) | PASS | No orphaned item references |
| 4 | DB: companion_inventories FK integrity (companion_id → companion_data) | PASS | No orphaned companion_id references |
| 5 | DB: duplicate slot entries per companion | PASS | 0 duplicates found |
| 6 | DB: total Companions rules in DB | PASS | 27 rules (24 existing + 3 new) |
| 7 | Lua syntax: global_npc.lua | PASS | Clean compile (luajit at /home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit) |
| 8 | Lua syntax: companion.lua module | PASS | Clean compile |
| 9 | Log: shared_memory startup | PASS | Loaded 1,028 rules, no errors |
| 10 | Log: zone startup | PASS | Loaded 1,028 rules, no errors, connected to world |
| 11 | Log: loginserver startup | PASS | Started cleanly, world registered |
| 12 | Log: world startup | PASS | Warnings are pre-existing IP mismatch (LAN server), unrelated to feature |
| 13 | Log: crashes directory | WARN | 5 pre-existing crash logs from other sessions/zones; none from dynamic_01; none from today |
| 14 | Code: ShowEquipment 19-slot display | PASS | Static table of 19 slots matches PRD order exactly |
| 15 | Code: SlotNameToSlotID aliases | PASS | All PRD aliases present (helm, helmet, mask, necklace, cloak, cape, torso, body, gloves, hand, leftwrist, rightwrist, ranged, bow, ring1, ring2, leftfinger, rightfinger, main, mainhand, offhand, off, boots, foot, belt, ammunition, arrows) |
| 16 | Code: m_inv population in GiveItem | PASS | CreateItem → PutItem → delete pattern present |
| 17 | Code: m_inv clear in RemoveItemFromSlot | PASS | GetInv().DeleteItem(slot) present |
| 18 | Code: m_inv population in LoadEquipment | PASS | CreateItem → PutItem per row, on every companion load |
| 19 | Code: m_inv init in constructor | PASS | SetInventoryVersion(MobVersion::NPC) + SetGMInventory(false) |
| 20 | Code: Death handler rule gate | PASS | RuleB(Companions, EquipmentPersistsThroughDeath) gates equipment clear; default true preserves gear |
| 21 | Code: companion_find_slot empty-slot preference | PASS | Two-pass: empty first, fallback to first match |
| 22 | Code: class/race restriction check in event_trade | PASS | eq.get_rule + IsEquipable check present before GiveItem |
| 23 | Code: money return message in event_trade | PASS | All 4 coin types returned with "[Name] has no use for money." message |
| 24 | Build: zone binary timestamp | PASS | Zone rebuilt 2026-03-07 17:39 (today) |
| 25 | Build: rule count at runtime | PASS | 1,028 rules loaded in zone and shared_memory |

### Database Integrity

**Tables checked:**
- `rule_values` — 3 new Companions rules confirmed present
- `companion_inventories` — 1 row for companion_id=8, item_id=7010 (Rusty Shortened Spear, valid FK to items)
- No orphaned item_id references
- No duplicate (companion_id, slot_id) pairs

**Queries run:**
```sql
-- Verify 3 new rules exist
SELECT rule_name, rule_value FROM rule_values
WHERE rule_name LIKE 'Companions:Enforce%' OR rule_name LIKE 'Companions:Equipment%';

-- Check for orphaned item references
SELECT ci.companion_id, ci.item_id FROM companion_inventories ci
LEFT JOIN items i ON ci.item_id = i.id WHERE i.id IS NULL;

-- Check for orphaned companion references
SELECT ci.companion_id FROM companion_inventories ci
LEFT JOIN companion_data cd ON ci.companion_id = cd.id WHERE cd.id IS NULL;

-- Check for duplicate slot entries
SELECT companion_id, slot_id, COUNT(*) FROM companion_inventories
GROUP BY companion_id, slot_id HAVING COUNT(*) > 1;
```

**Findings:** No integrity issues. All data consistent.

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `quests/global/global_npc.lua` | Lua | PASS | Clean compile via vcpkg luajit |
| `quests/lua_modules/companion.lua` | Lua | PASS | Clean compile |

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| `shared_memory.log` | None | — | Rules loaded (1,028) including 3 new ones |
| `zone_dynamic_01.log` | None | — | Zone started cleanly, 1,028 rules loaded |
| `loginserver.log` | None | — | Started cleanly |
| `world.log` | IP address warnings | Low | Pre-existing LAN/WAN IP mismatch; not feature-related |
| `logs/crashes/` | 5 pre-existing crash files | WARN | All from previous sessions in different zones (firiona, freporte, natimbi, qeynos2, timorous); none from today; not related to this feature |

### Rule Validation

| Rule | Category | Value | Valid Range | Result |
|------|----------|-------|-------------|--------|
| Companions:EnforceClassRestrictions | bool | true | true/false | PASS |
| Companions:EnforceRaceRestrictions | bool | true | true/false | PASS |
| Companions:EquipmentPersistsThroughDeath | bool | true | true/false | PASS |

### Spawn Verification

N/A — this feature adds no new NPCs, spawn points, or grids.

### Loot Chain Validation

N/A — this feature adds no new loot tables or drops.

### Build Verification

- **Build command:** `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS (user confirmed build is clean; zone binary timestamp 2026-03-07 17:39 confirms today's rebuild)
- **Errors:** None

---

## Part 2: In-Game Testing Guide

### Prerequisites

Before running any test, set up a GM character with appropriate level and access.
All tests assume you have a recruiteable NPC companion available and can open
trade windows with them.

**Recommended test setup:**

```
#level 50
#zone commonlands
```

Find a companion you have previously recruited (or recruit one fresh for testing).
If you need to spawn test items, use `#summonitem [id]` below.

**Key item IDs for testing:**

| Item | ID | Notes |
|------|-----|-------|
| Rusty Short Sword | 5013 | Low-damage weapon (4 dmg, 28 dly) — any class |
| Fine Steel Long Sword | 5350 | Better weapon (6 dmg, 28 dly) — classes 413 |
| Mithril Helm | 1112 | Warrior/Paladin/Ranger/Shadow Knight helm (class 33695) |
| Banded Helm | 3053 | Multi-class helm (class 33695, AC 8) |
| Totemic Helm | 4947 | Shaman only (class 512, race 25346) |
| Cryosilk Cap | 1211 | Druid/Monk/Bard/Rogue cap — NOT warrior/plate (class 15360) |
| Emerald Ring | 10045 | Ring — all classes/races, slots 98304 (Finger1 + Finger2) |
| Mithril Breastplate | 4309 | Chest armor — warrior/paladin types (class 33183) |
| Iron Ration | 13005 | Food — slots bitmask 0, not equippable |
| Rusty Shortened Spear | 7010 | Already in test companion's Primary slot |

**Decoding class bitmask:**
- Warrior=1, Cleric=2, Paladin=4, Ranger=8, Shadow Knight=16, Druid=32, Monk=64, Bard=128, Rogue=256, Shaman=512, Necromancer=1024, Wizard=2048, Magician=4096, Enchanter=8192, Beastlord=16384
- Class 65535 = all classes

---

### Test 1: !equipment Shows All 19 Slots

**Acceptance criterion:** `!equipment` displays all 19 slots with current item name or "(empty)" for each slot.

**Prerequisite:** Any character with a recruited companion.

**Steps:**
1. Target your recruited companion.
2. Type `!equipment`.
3. Read the output in the chat window.

**Expected result:**
```
[Companion Name]'s Equipment:
  Head         (empty)
  Face         (empty)
  Neck         (empty)
  Shoulders    (empty)
  Chest        (empty)
  Back         (empty)
  Arms         (empty)
  Wrist 1      (empty)
  Wrist 2      (empty)
  Hands        (empty)
  Finger 1     (empty)
  Finger 2     (empty)
  Legs         (empty)
  Feet         (empty)
  Waist        (empty)
  Primary      (empty)
  Secondary    (empty)
  Range        (empty)
  Ammo         (empty)
```
(Any occupied slots show the item name instead of "(empty)")

**Pass if:** All 19 slots appear in the correct order, with item names for occupied slots and "(empty)" for empty ones.

**Fail if:** Output shows fewer than 19 slots, missing slot labels, wrong format, or any Lua error.

**GM commands for setup:**
```
#summonitem 5013
```
(Equip via trade window to have at least one occupied slot for visual verification)

---

### Test 2: !gear Alias Works

**Acceptance criterion:** `!gear` produces identical output to `!equipment`.

**Prerequisite:** Same as Test 1.

**Steps:**
1. Target your companion.
2. Type `!gear`.
3. Compare output to `!equipment` output.

**Pass if:** Output is identical to `!equipment`.
**Fail if:** Command not recognized or output differs.

---

### Test 3: Trade Window Equips Item to Correct Slot

**Acceptance criterion:** Player can equip items on a companion via the trade window, with items going into the correct equipment slot based on item type.

**Prerequisite:** Character with a companion. Have a Banded Helm (ID 3053) in inventory.

**GM commands:**
```
#summonitem 3053
```

**Steps:**
1. Target your companion.
2. Open trade window (right-click companion → Trade or use /trade).
3. Place the Banded Helm in the trade window.
4. Confirm the trade.
5. Type `!equipment` to check the result.

**Expected result:** Head slot shows "Banded Helm". All other slots unchanged.

**Pass if:** `!equipment` shows "Banded Helm" in the Head slot.
**Fail if:** Item goes to a wrong slot, is returned to player, or causes an error.

---

### Test 4: Trading Into Occupied Slot Returns Only That Slot's Item

**Acceptance criterion:** When equipping into an occupied slot, only the item in that specific slot is returned — not items from other slots.

**Prerequisite:** Companion with a Banded Helm already in Head slot (from Test 3). Have a Mithril Helm (ID 1112) and a Rusty Short Sword (ID 5013) equipped in Primary slot.

**GM commands:**
```
#summonitem 1112
#summonitem 5013
```
(Equip Rusty Short Sword via trade first so Primary slot is occupied.)

**Steps:**
1. Verify companion has Banded Helm (Head) and Rusty Short Sword (Primary) equipped.
   - Type `!equipment` to confirm.
2. Open trade window with companion.
3. Place the Mithril Helm in the trade window.
4. Confirm the trade.
5. Check your inventory — the Banded Helm should appear on your cursor or in bags.
6. Type `!equipment` to verify Mithril Helm is now in Head slot.
7. Verify the Rusty Short Sword is STILL in the Primary slot — it must NOT have been returned.

**Pass if:** Only the Banded Helm was returned (Head slot displaced). Rusty Short Sword remains in Primary.
**Fail if:** Both Banded Helm AND Rusty Short Sword were returned, OR Rusty Short Sword was returned instead of Banded Helm.

---

### Test 5: Trading Into Empty Slot Returns Nothing

**Acceptance criterion:** When equipping into an empty slot, no item is returned to the player.

**Prerequisite:** Companion with Mithril Helm in Head slot. Fine Steel Long Sword (ID 5350) available. Secondary slot is empty.

**GM commands:**
```
#summonitem 5350
```

**Steps:**
1. Verify companion's Secondary slot is empty (`!equipment`).
2. Open trade window with companion.
3. Place Fine Steel Long Sword in trade window.
4. Confirm trade.
5. Check inventory — nothing should appear on cursor or in bags.
6. Type `!equipment` — Fine Steel Long Sword should be in Secondary slot.

**Pass if:** No item returned, Fine Steel Long Sword appears in Secondary slot.
**Fail if:** Any item appears in inventory, or the sword goes to Primary slot displacing the existing weapon.

**Note:** The Fine Steel Long Sword (slots 24576 = Primary + Secondary bitmask) can go to either Primary or Secondary. If Primary is occupied, it should go to Secondary (empty-slot preference). If Primary is also empty, it may go to Primary.

---

### Test 6: Multi-Slot Empty-Slot Preference (Rings)

**Acceptance criterion:** Items that can go in multiple slots (rings) prefer empty slots. Finger 2 is used if Finger 1 is occupied.

**Prerequisite:** Companion with Finger 1 occupied by an Emerald Ring. Finger 2 empty. Second Emerald Ring available.

**GM commands:**
```
#summonitem 10045
#summonitem 10045
```
(Trade the first one to put it in Finger 1. Then trade the second one.)

**Steps:**
1. Trade the first Emerald Ring to companion — it should go to Finger 1 (both empty, picks first).
   - Verify: `!equipment` shows Finger 1 = Emerald Ring, Finger 2 = (empty).
2. Trade the second Emerald Ring to companion.
3. Check `!equipment`.

**Expected result:** Second ring goes to Finger 2 (empty slot preference). First ring stays in Finger 1. Nothing is returned.

**Pass if:** After step 2, Finger 1 = Emerald Ring (first one), Finger 2 = Emerald Ring (second one). No item returned.
**Fail if:** Second ring displaces Finger 1 ring and returns it, or goes to wrong slot.

---

### Test 7: Multi-Slot Fallback When All Slots Occupied (Rings)

**Acceptance criterion:** If both multi-slot slots are occupied, the item displaces the first slot.

**Prerequisite:** Companion with both Finger 1 and Finger 2 occupied by Emerald Rings (from Test 6). Third ring or different ring item available.

**GM commands:**
```
#summonitem 10045
```

**Steps:**
1. Verify both Finger 1 and Finger 2 have Emerald Rings (`!equipment`).
2. Trade a third Emerald Ring to companion.
3. Check inventory — one Emerald Ring should appear (from Finger 1).
4. Type `!equipment` — Finger 1 should have the new ring, Finger 2 unchanged.

**Pass if:** The Finger 1 ring is returned to player, new ring goes to Finger 1. Finger 2 unchanged.
**Fail if:** Wrong ring returned, wrong slot displaced, or no ring returned.

---

### Test 8: Non-Equippable Item Rejected with Message

**Acceptance criterion:** Items that cannot be equipped in any slot are returned to the player with an appropriate message.

**Prerequisite:** Iron Ration (ID 13005, slots=0) in inventory.

**GM commands:**
```
#summonitem 13005
```

**Steps:**
1. Open trade window with companion.
2. Place Iron Ration in trade window.
3. Confirm trade.
4. Watch for message in chat.

**Expected result:** Companion says "[Name] cannot equip that item." The Iron Ration appears on your cursor or in your inventory.

**Pass if:** Iron Ration is returned with rejection message. Companion equipment unchanged.
**Fail if:** Item is consumed (disappeared), no message appears, or item ends up equipped somehow.

---

### Test 9: Class-Restricted Item Rejected on Wrong-Class Companion

**Acceptance criterion:** Items with class restrictions cannot be equipped on companions of the wrong class.

**Prerequisite:** A warrior or non-shaman companion. Totemic Helm (ID 4947, class 512 = Shaman only).

**GM commands:**
```
#summonitem 4947
```

**Steps:**
1. Verify your companion is NOT a Shaman (use `#showstats` while targeting companion to see class).
2. Open trade window with companion.
3. Place Totemic Helm in trade window.
4. Confirm trade.

**Expected result:** Message: "[Companion Name] cannot use that item (class/race restricted)." Totemic Helm returned to player.

**Pass if:** Item rejected with message, returned to player.
**Fail if:** Item gets equipped on non-Shaman companion.

**Note:** If your test companion IS a Shaman, find a warrior companion for this test, or use a Cryosilk Cap (ID 1211, class 15360 — only classes 10-14, no warriors) on a warrior companion.

**Alternative (Cryosilk Cap on Warrior):**
```
#summonitem 1211
```
Trade Cryosilk Cap to a Warrior companion. Should be rejected.

---

### Test 10: Class-Appropriate Item Accepted

**Acceptance criterion:** A companion CAN equip items they meet the class requirements for.

**Prerequisite:** A warrior companion. Banded Helm (ID 3053, class 33695 includes warrior).

**GM commands:**
```
#summonitem 3053
```

**Steps:**
1. Confirm companion is a warrior class (use `#showstats` while targeting).
2. Trade Banded Helm to warrior companion.
3. Verify it equips successfully via `!equipment`.

**Pass if:** Banded Helm appears in Head slot.
**Fail if:** Item is rejected with class/race restriction message when the companion SHOULD be able to use it.

---

### Test 11: Equipment Stats Apply to Combat (Critical Fix Validation)

**Acceptance criterion:** Equipped weapons affect companion melee damage output; equipped armor affects companion AC.

**This is the most important functional test.** The core bug fixed by this feature was that equipment stats were NEVER applied to companions.

**Prerequisite:** Companion with NO equipment. Access to a weak weapon and a strong weapon.

**GM commands:**
```
#summonitem 5013
#summonitem 5350
```

**Steps:**

**Part A — Weapon test (DPS comparison):**
1. Note companion's current AC and attack stats: target companion, type `#showstats`. Note the "Damage" and related stats.
2. Equip Rusty Short Sword (ID 5013, 4 dmg, 28 delay) via trade window.
3. Target companion again, type `#showstats`. Note any stat change.
4. Find a suitable target mob and let companion fight. Observe melee damage numbers in chat.
5. Unequip: type `!unequip primary`.
6. Equip Fine Steel Long Sword (ID 5350, 6 dmg, 28 delay) via trade window.
7. Target companion, type `#showstats`. Note stat change.
8. Let companion fight same level of target. Compare damage numbers.

**Expected result:** Companion deals measurably more damage with Fine Steel Long Sword than with Rusty Short Sword. `#showstats` should show different damage values between the two weapons.

**Part B — Armor test (AC):**
1. Note companion's current AC from `#showstats`.
2. Equip Mithril Breastplate (ID 4309, AC 17) via trade window.
3. Check `#showstats` again — AC value should increase.

**Pass if:**
- `#showstats` shows stat changes after equipping/unequipping items.
- Companion's AC increases after equipping armor.
- Companion deals different (higher) damage with better weapons.

**Fail if:**
- `#showstats` shows identical stats regardless of equipped items.
- No observable difference in companion combat effectiveness between different weapons.
- This indicates m_inv is still not being populated (critical regression).

---

### Test 12: !unequip head (Slot Name Command)

**Acceptance criterion:** `!unequip <slot>` removes the item from the specified slot and returns it to the player's inventory.

**Prerequisite:** Companion with Banded Helm in Head slot.

**Steps:**
1. Equip Banded Helm in companion's Head slot (trade window).
2. Verify via `!equipment`.
3. Type `!unequip head`.
4. Check inventory — Banded Helm should appear on cursor or in bags.
5. Type `!equipment` — Head slot should show "(empty)".

**Pass if:** Item returned to player, slot now empty.
**Fail if:** Command not recognized, wrong item returned, item not returned.

---

### Test 13: !unequip Slot Name Aliases

**Acceptance criterion:** Slot names are case-insensitive and accept documented aliases.

**Prerequisite:** Companion with items in Head, Primary, Legs, Waist, Finger 1 slots.

**Steps (test each alias):**
1. `!unequip helm` — should work same as `!unequip head`
2. `!unequip helmet` — should work same as `!unequip head`
3. `!unequip mainhand` — should work same as `!unequip primary`
4. `!unequip HEAD` — should work (case-insensitive)
5. `!unequip ring1` — should work same as `!unequip finger1`
6. `!unequip belt` — should work same as `!unequip waist`
7. `!unequip boots` — should work same as `!unequip feet`
8. `!unequip bow` — should work same as `!unequip range`

**Re-equip between each test as needed using trade window.**

**Pass if:** All aliases are recognized and unequip the correct slot.
**Fail if:** Any alias returns "Unknown slot name" error.

---

### Test 14: !unequip with Invalid Slot Name

**Acceptance criterion:** Invalid slot names produce a helpful error message listing valid names.

**Steps:**
1. Target companion.
2. Type `!unequip blarg`.

**Expected result:** Error message listing valid slot names (head, face, neck, shoulders, chest, back, arms, wrist1, wrist2, hands, finger1, finger2, legs, feet, waist, primary, secondary, range, ammo).

**Pass if:** Helpful error message appears with list of valid slots.
**Fail if:** No message, server error, or unclear response.

---

### Test 15: !unequip When Slot is Empty

**Acceptance criterion:** If the slot was already empty, the player sees a message: "[Companion Name] has nothing equipped in that slot."

**Steps:**
1. Verify companion has nothing in the Face slot (`!equipment`).
2. Type `!unequip face`.

**Expected result:** Message "[Companion Name] has nothing equipped in that slot." (or similar). No item appears in inventory.

**Pass if:** Appropriate "nothing equipped" message shown. No crash or error.
**Fail if:** No message, server error, or wrong slot cleared.

---

### Test 16: !unequip all

**Acceptance criterion:** `!unequip all` removes all equipped items and returns them to the player's inventory (as space permits).

**Prerequisite:** Companion with multiple items equipped (at least 3-4 slots).

**Steps:**
1. Equip multiple items across different slots (trade window).
2. Verify via `!equipment`.
3. Type `!unequip all`.
4. Check inventory — all equipped items should appear.
5. Type `!equipment` — all slots should show "(empty)".

**Pass if:** All items returned to player, all slots now empty.
**Fail if:** Items disappear (not returned), some items not returned, companion keeps items, inventory error.

---

### Test 17: Equipment Persists Through Death

**Acceptance criterion:** Equipment persists through companion death (gear intact after resurrection/respawn).

**Steps:**
1. Equip at least one item on companion.
2. Type `!equipment` to record what is equipped.
3. Kill the companion (use `#kill` while targeting companion, or let it die in combat).
4. Wait for companion to respawn/be resurrected per normal death mechanics.
5. Target companion after respawn.
6. Type `!equipment`.

**Expected result:** Same items are still equipped after respawn. No items lost.

**Pass if:** Equipment matches pre-death state exactly.
**Fail if:** Equipment slots are empty, items are missing, or items appear on a corpse.

**GM commands:**
```
#kill
```
(Kill yourself to kill companion if needed, or use companion in combat vs a strong mob)

---

### Test 18: Equipment Persists Through Dismissal and Re-Recruitment

**Acceptance criterion:** Equipment persists through companion dismissal (re-recruiting restores gear).

**Steps:**
1. Equip at least one item on companion. Record equipped items.
2. Type `!dismiss` to dismiss the companion.
3. Find the SAME NPC (same spawn location) and recruit them again (`!recruit`).
4. Target the companion.
5. Type `!equipment`.

**Expected result:** Same items are equipped on the re-recruited companion as before dismissal.

**Pass if:** Equipment fully restored on re-recruitment.
**Fail if:** Equipment slots are empty after re-recruitment, or wrong items appear.

**Note:** Must recruit the SAME NPC instance, not a different NPC of the same type. Each companion NPC has a unique companion_id — only that specific NPC retains their gear.

---

### Test 19: Money in Trade Window Returned with Message

**Acceptance criterion:** Money traded to a companion is returned to the player with an explanatory message.

**Steps:**
1. Open trade window with companion.
2. Place some coins in the trade window (platinum, gold, silver, and/or copper).
3. Also place one equippable item (so trade window has both money and an item).
4. Confirm the trade.

**Expected result:** Money is returned to your purse. Message "[Companion Name] has no use for money." is shown. The equippable item IS equipped (money rejection doesn't block items).

**Pass if:** All coin denominations returned, message shown, items still equipped.
**Fail if:** Money is silently consumed, no message shown, item not equipped.

**Alternative (money only):**
1. Open trade window.
2. Place only platinum coins, no items.
3. Confirm trade.
4. Money should be returned with message.

---

### Test 20: Visual Appearance Updates on Equip

**Acceptance criterion:** Companion visual appearance updates when items are equipped or unequipped in visible slots.

**Prerequisite:** Visible-slot item — any head, chest, arms, legs, feet, hands, primary, secondary armor or weapon.

**Steps:**
1. Note companion's current visual appearance.
2. Equip a helm (head slot) via trade window.
3. Observe companion's model — helm should appear on their head.
4. Type `!unequip head`.
5. Companion model should revert to bare-head appearance.

**Pass if:** Visual change is visible on equip, reverts on unequip.
**Fail if:** No visual change when equipping visible slots.

**Note:** Non-visible slots (Neck, Finger, Waist, etc.) will not trigger visual changes — this is expected.

---

### Test 21: Non-Owner Cannot Trade Equipment

**Prerequisite:** Two characters. Character B is NOT the owner of the companion.

**Steps:**
1. Have Character A recruit a companion.
2. Log in Character B.
3. Character B opens trade window with Character A's companion.
4. Places an item in the trade window and confirms.

**Expected result:** Item is returned to Character B. Message "Only [Name]'s owner can give them equipment."

**Pass if:** Item rejected, returned to non-owner, message shown.
**Fail if:** Item equips on companion, no message, or server error.

---

### Test 22: Equipment Visible After Zone

**Acceptance criterion:** Equipment persists after zone crossing.

**Steps:**
1. Equip one or more items on companion.
2. Zone to a different zone (e.g., `#zone freeport`).
3. Companion should follow or be recalled.
4. Type `!equipment` in the new zone.

**Expected result:** All equipped items still shown.

**Pass if:** Equipment unchanged after zone.
**Fail if:** Equipment lost on zone.

---

## Edge Case Tests

### Test E1: Trade 4 Items to Same Slot Simultaneously

**Risk from architecture plan:** "If player trades 4 items at once, all to same slot: each goes to Head slot in sequence. First displaces existing, second displaces first trade, etc. Only the last helmet ends up equipped."

**Steps:**
1. Summon 4 different head-slot items:
   ```
   #summonitem 3053
   #summonitem 1112
   #summonitem 4947
   #summonitem 1211
   ```
   Note: Items 4947 (Totemic Helm, Shaman only) and 1211 (Cryosilk Cap) may be rejected by class restrictions depending on companion class. Use only class-appropriate items.
2. Open trade window with companion.
3. Place all 4 (class-compatible) helms in the trade window.
4. Confirm trade.

**Expected result:** Items are processed in sequence (item1, item2, item3, item4). Each displaces the previous one. The 3 displaced items are returned to your cursor/inventory (stacked on cursor). The last item remains equipped. No items disappear.

**Pass if:** Exactly 3 items returned, 1 item equipped in Head slot. No item duplication.
**Fail if:** Items disappear, server crash, wrong number of items returned.

---

### Test E2: NO DROP Item Equip and Return

**Risk from architecture plan:** "NO DROP items on companions: When unequipped, they return to the player who equipped them."

**Steps:**
1. Find a NO DROP item in your possession (any lore-drop gear with "NO DROP" flag).
2. Equip it on companion via trade window.
3. Verify via `!equipment`.
4. Type `!unequip [slot]` to unequip it.

**Expected result:** NO DROP item returns to your inventory/cursor. No item loss.

**Pass if:** NO DROP item equips successfully, returns to player on unequip.
**Fail if:** NO DROP item cannot be equipped, is destroyed on unequip, or changes drop status.

---

### Test E3: Rule Toggle - EnforceClassRestrictions Off

**Risk from architecture plan:** "If EnforceClassRestrictions is toggled from true to false while the server is running, previously-rejected items could now be equipped."

**GM commands:**
```
#reloadrules
```

**Steps:**
1. From game client as GM, open database and set `Companions:EnforceClassRestrictions` to `false`.
2. Run `#reloadrules` in-game.
3. Try to equip a class-restricted item on a companion that previously couldn't use it (e.g., Totemic Helm on warrior).

**Expected result:** Item equips successfully when restriction is off.

**Pass if:** Item equips when rule is false; item rejected when rule is true.
**Fail if:** Rule has no effect, or rule change crashes server.

**Cleanup:** Reset rule back to `true` via database after testing.

---

### Test E4: !unequip all with Full Inventory

**Risk from architecture plan:** "Player's inventory full during unequip all: GiveAll uses SummonItem which places items on cursor if inventory is full."

**Steps:**
1. Fill your inventory bags completely (no free slots).
2. Equip multiple items on companion.
3. Type `!unequip all`.

**Expected result:** Items should appear on cursor (stacking or overflowing). Items should NOT be destroyed. If the c-expert added inventory capacity checking, a warning message should appear when capacity is exceeded.

**Pass if:** No items are lost; they appear on cursor or a warning message is shown about remaining equipped items.
**Fail if:** Items disappear (destroyed), server error, or crash.

---

### Test E5: No Item Duplication Verification

**Risk:** Any equip/unequip/trade flow could potentially dupe items.

**Steps:**
1. Place exactly 1 Banded Helm and 1 Mithril Helm in your inventory.
2. Trade Banded Helm to companion (Head slot).
3. Trade Mithril Helm to companion (Head slot) — Banded Helm should be returned.
4. Count: you should have exactly 1 Banded Helm in inventory, companion has 1 Mithril Helm.
5. Type `!unequip head` — you should now have 1 Banded Helm + 1 Mithril Helm. Companion has 0.
6. Verify counts match: 2 helms in inventory, 0 on companion.

**Pass if:** Exact expected counts at every step. No extra items appear.
**Fail if:** Any extra copy of an item appears at any step.

---

### Test E6: Multiple Companions — No Cross-Contamination

**Risk from architecture plan:** "Multiple companions with different equipment — no cross-contamination."

**Steps:**
1. Recruit 2 different companions (Companion A and Companion B).
2. Equip Banded Helm on Companion A, Fine Steel Long Sword on Companion B.
3. Check `!equipment` on Companion A — should only show Banded Helm.
4. Check `!equipment` on Companion B — should only show Fine Steel Long Sword.

**Pass if:** Each companion's equipment is independent; no items bleed between companions.
**Fail if:** Equipment from one companion appears on another.

---

## Rollback Instructions

If something goes wrong during testing, restore previous state:

**Database rollback (remove the 3 new rules):**
```sql
-- Run via docker exec or PhpMyAdmin (http://192.168.1.86:8082)
DELETE FROM rule_values
WHERE rule_name IN (
    'Companions:EnforceClassRestrictions',
    'Companions:EnforceRaceRestrictions',
    'Companions:EquipmentPersistsThroughDeath'
);
```

**Quest script rollback:**
```bash
# Revert global_npc.lua and companion.lua to previous version
cd /mnt/d/Dev/eq/akk-stack
git checkout feature/companion-equipment -- server/quests/global/global_npc.lua
git checkout feature/companion-equipment -- server/quests/lua_modules/companion.lua
```

**C++ rollback (revert companion.cpp to pre-feature state):**
```bash
cd /mnt/d/Dev/eq/eqemu
git log --oneline -5  # find the pre-feature commit
git revert HEAD  # or git checkout <pre-feature-commit> -- zone/companion.cpp
# Then rebuild:
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

**If companion equipment table has bad data:**
```sql
-- Clear all companion equipment for a specific companion_id
DELETE FROM companion_inventories WHERE companion_id = [id];
```

---

## Blockers

No blockers found from server-side validation. The following are observations
that may need attention depending on in-game test results:

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| — | No server-side blockers found | — | — | — |

---

## Recommendations

- The `!unequip all` inventory-full behavior (Test E4) was flagged by the architect as a potential issue. The c-expert's dev-notes mention that `GiveAll` in C++ iterates all slots without checking inventory capacity. Monitor during in-game testing — if items are lost (not just cursor-stacked), this needs a c-expert fix.

- There is 1 pre-existing companion equipment row in the DB (companion_id=8, item_id=7010, Rusty Shortened Spear in Legs slot). After the server restarts with the new binary, this item's stats should now apply via m_inv population on LoadEquipment. This is the desired retroactive behavior per the architecture doc.

- The existing crash logs in `logs/crashes/` are from previous sessions in other zones (firiona, freporte, natimbi, qeynos2, timorous) and appear to pre-date this feature. No crashes from today or from the dynamic_01 zone were found.

- Test 11 (Equipment Stats Apply to Combat) is the most critical in-game test. If stats are not applying, the m_inv population fix needs to be re-examined. Use `#showstats` before and after equipping items to confirm the AC and attack stats change.

- The dev-notes for lua-expert listed Task 8 (class/race checks) as "blocked" but the code inspection confirms it IS fully implemented in global_npc.lua (lines 199-211). The dev-notes were not updated after implementation completed.

---

## Server-Side Validation Summary

**Overall result: PASS WITH WARNINGS**

All functional implementation is confirmed present and correct:
- 3 new rule_values rows inserted and verified
- Zone loaded 1,028 rules (including new ones)
- global_npc.lua and companion.lua pass syntax checks
- All C++ changes verified in source (m_inv population, ShowEquipment 19 slots, slot aliases, death handler, class/race check in Lua, money return in Lua)
- Zone binary rebuilt today (17:39)
- No DB integrity issues
- No crash logs from today's session

Warnings:
- 5 pre-existing crash logs from previous sessions in other zones (not feature-related)
- World IP address warnings are pre-existing LAN configuration (not feature-related)
- Task 8 completion was not reflected in lua-expert dev-notes but IS implemented in code

**In-game testing required for:**
- Equipment stat integration (Test 11) — must verify AC/damage changes after equip
- Trade window slot replacement correctness (Tests 3-7)
- Class/race restriction rejection with exact messages (Tests 9-10)
- Equipment persistence through death and dismissal (Tests 17-18)
- !unequip all inventory-full behavior (Test E4)
