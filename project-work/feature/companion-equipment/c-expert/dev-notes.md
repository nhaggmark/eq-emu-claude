# Companion Equipment Management Enhancement — Dev Notes: C Expert

> **Feature branch:** `feature/companion-equipment`
> **Agent:** c-expert
> **Task(s):** 3, 4, 5, 6, 10
> **Date started:** 2026-03-07
> **Current stage:** Build (Tasks 3, 4, 5, 6 complete — Task 10 blocked pending task 1 commit)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 4 | Enhance ShowEquipment to display all 19 slots | — | Complete |
| 5 | Add slot name aliases to SlotNameToSlotID | — | Complete |
| 3 | Fix combat stat integration: populate m_inv with ItemInstance | 1 (rules) | Complete |
| 6 | Death handler equipment clear gated on EquipmentPersistsThroughDeath rule | 1 (rules) | Complete |
| 10 | Rebuild server and validate all changes | All other tasks | Pending (blocked by #1 commit, #8) |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/companion.h` | 1–370 | Companion class: m_equipment[EQUIPMENT_COUNT], GiveItem/RemoveItemFromSlot/LoadEquipment/ShowEquipment/SlotNameToSlotID signatures |
| `zone/companion.cpp` | 1–1450 | Full implementation: constructor at line 44, Death at 323, GiveItem at 1183, RemoveItemFromSlot at 1199, LoadEquipment at 1215, SlotNameToSlotID at 1286, ShowEquipment at 1318 |
| `zone/bot.cpp` | 44–55, 4075–4090 | Bot pattern: m_inv.SetInventoryVersion(MobVersion::Bot) in constructor, m_inv.PutItem(slot_id, *inst) after CreateItem |
| `common/emu_versions.h` | 72–95 | MobVersion enum: NPC, Bot, Merc, NPCMerchant etc. |
| `common/inventory_profile.h` | 92–250 | PutItem(slot_id, inst): line 125, DeleteItem(slot_id): line 138 |
| `common/shareddb.h` | 125–142 | CreateItem(item_id, charges, aug1..6, attuned): returns EQ::ItemInstance* (heap-allocated, caller owns) |
| `game-designer/prd.md` | full | 19-slot display order, alias table |
| `architect/architecture.md` | full | Gap analysis, change details, bot.cpp:4083 reference |

### Key Findings

- `m_inv` is inherited from `Mob`, already present — just never initialized for companions
- Bot uses `MobVersion::Bot`; companions should use `MobVersion::NPC` (NPC-derived, non-PC)
- `database.CreateItem(item_id)` returns a heap-allocated `ItemInstance*` — caller must `delete`
- `m_inv.PutItem(slot, *inst)` takes a const ref — safe to delete inst immediately after
- `m_inv.DeleteItem(slot)` handles cleanup of the internal copy
- SlotNameToSlotID: had most aliases, missing helm/helmet, mask, necklace, arm, cloak/cape, leftwrist/rightwrist, ranged/bow, hand/gloves, main, off, leftfinger/rightfinger, torso, leg, foot, ammunition/arrows
- ShowEquipment: was only showing occupied slots — needed full 19-slot PRD format

---

## Stage 4: Build

### Implementation Log

#### 2026-03-07 — Task 5: Add slot name aliases

**What:** Added all missing PRD aliases to `SlotNameToSlotID()` and updated the error message in `GiveSlot()` to list canonical 19-slot names.
**Where:** `zone/companion.cpp:1292-1313` (SlotNameToSlotID), `zone/companion.cpp:1374-1379` (GiveSlot error message)
**Why:** PRD requires case-insensitive alias support for `!unequip` command; e.g., `!unequip helm` and `!unequip helmet` must work alongside `!unequip head`.
**Notes:** All aliases are unambiguous (no collisions). Existing aliases preserved.

#### 2026-03-07 — Task 4: Rewrite ShowEquipment

**What:** Replaced loop-only-occupied-slots approach with static table of 19 slot entries, always displaying all slots with "(empty)" for unoccupied ones.
**Where:** `zone/companion.cpp:1318-1360`
**Why:** PRD requires full 19-slot view. Players need to see gaps in companion gear.
**Notes:** Charm, Ear1, Ear2 intentionally omitted from display per PRD (still stored/apply stats). Format uses `%-12s` for label alignment matching PRD example.

**Commit:** `8d6bb9c20` — `feat(companion-equipment): full 19-slot ShowEquipment display and expanded slot aliases`

#### 2026-03-07 — Task 3: Populate m_inv with ItemInstance

**What:** Four changes:
1. Constructor: `m_inv.SetInventoryVersion(MobVersion::NPC)` + `SetGMInventory(false)`
2. `GiveItem`: `database.CreateItem(item_id)` → `m_inv.PutItem(slot, *inst)` → `delete inst`
3. `RemoveItemFromSlot`: `m_inv.DeleteItem(slot)`
4. `LoadEquipment`: same CreateItem + PutItem pattern inside the row loop

**Where:** `zone/companion.cpp:94-98` (constructor), `1195-1200` (GiveItem), `1218-1220` (RemoveItemFromSlot), `1245-1251` (LoadEquipment)
**Why:** `CalcItemBonuses()` reads from `GetInv().GetItem(slot)` — if m_inv is empty, all equipment stats are zero. This is the root cause of Gap 1. Bot system proves the pattern works for non-player entities.
**Notes:** `database.CreateItem` returns heap-allocated ptr; must delete after PutItem copies it. Pattern is identical to bot.cpp:4083.

#### 2026-03-07 — Task 6: Death handler equipment clear

**What:** Added rule-gated equipment clear block at top of `Companion::Death()`. If `RuleB(Companions, EquipmentPersistsThroughDeath)` is false, iterates all slots, clears m_equipment[], equipment[], m_inv, saves DB, recalcs. Returns items to owner via SummonItem.
**Where:** `zone/companion.cpp:330-347`
**Why:** PRD Goal 6 says equipment survives death by default. Rule allows server admin to change this behavior.
**Notes:** Default is `true` (persist), so existing behavior is unchanged. Equipment is returned to owner (not dropped on corpse) when rule is false.

**Commit:** `31d8757a1` — `feat(companion-equipment): wire m_inv for stat integration and add death persistence rule`

---

## Open Items

- [ ] Task 10 (rebuild): blocked until config-expert commits ruletypes.h (task 1) and lua-expert completes task 8
- [ ] After rebuild: verify CalcItemBonuses actually applies stats by checking #showstats before/after equip

---

## Context for Next Agent

Tasks 3, 4, 5, 6 are committed on `feature/companion-equipment` in `eqemu/`. All changes are in `zone/companion.cpp`. The three new Companion rules are already in `common/ruletypes.h` working tree (not yet committed — config-expert owns that).

Task 10 (rebuild) requires:
1. Task 1 committed (config-expert — ruletypes.h)
2. Task 8 complete (lua-expert — class/race checks in event_trade)

To do the rebuild:
```
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

Then restart the server. The build will pick up all C++ changes including the new rules.
