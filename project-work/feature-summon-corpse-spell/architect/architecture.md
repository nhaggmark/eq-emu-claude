# Universal Summon Corpse Spell — Architecture & Implementation Plan

> **Feature branch:** `feature/summon-corpse-spell`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-05-03
> **Status:** Approved — ready for implementation

---

## Executive Summary

Add 12 class-flavored "Summon Corpse" spells (one per casting-capable class), each a free, level-1, 0-mana, 6-second-cast, 3-minute-cooldown self-target spell that pulls the caster's own corpse to their feet within the same zone. The mechanical effect reuses the existing `SE_SummonCorpse` SPA (effect ID 91), which is already class-agnostic at the engine level — no class gate exists in the C++ handler. Implementation is **DB-first**: 12 rows in `spells_new`, 12 scroll items in `items`, vendor entries in `merchantlist`, an idempotent auto-scribe migration into `character_spells`, and one new rule (`Spells:UniversalSummonCorpseCooldown`). Three small, contained C++ changes are required: (a) register the new rule, (b) decouple the recast timer from the no-corpse no-op so a quick "do I have a corpse here?" check doesn't burn the 3-minute cooldown, and (c) consult the rule from the recast block (keyed on `spell_category`) so operators can hot-tune via `#reloadrules` without a content patch. No new opcodes, no protocol changes, no quest scripts.

**One BLOCKING precondition — must be resolved before data-expert can begin spell row inserts:** Titanium's `SPELL_ID_MAX = 9999` (`common/patches/titanium_limits.h:329`) caps spell IDs that the wire format can transport; spells with IDs > 9999 are silently dropped from `OP_PlayerProfile.spell_book[]`. The `spells_new` table currently has only 3 unused IDs in the sub-9999 range (1348, 5093, 9412). We need 12. **Data-expert task 0** (added below) reclaims 9+ additional IDs by deleting truly-unused sub-9999 spell rows (no character has them scribed, no item points to them). This is the gating dependency for the entire feature.

## Existing System Analysis

### Current State

**Spell engine (`eqemu/zone/spells.cpp` ~7530 lines, `eqemu/zone/spell_effects.cpp` ~10709 lines).** The cast pipeline is:
`CastSpell()` → `CastedSpellFinished()` → `SpellFinished()` → `SpellOnTarget()` → `Mob::SpellEffect()` (which is the giant switch on `effect_id`). The `SE_SummonCorpse = 91` handler at `spell_effects.cpp:1793-1868` already implements summon-corpse mechanics for any client caster — it performs group/raid validation when targeting another player, level-cap validation against the SPA's `effect_value`, calls `entity_list.GetCorpseByOwner(TargetClient)`, and either calls `corpse->Summon(...)` or sends `CORPSE_CANT_SENSE`. The handler is **NOT class-gated**. Bots are gated separately via `RuleB(Bots, AllowCommandedSummonCorpse)` at `spells.cpp:1912-1917`.

**Recast timer system.** `spells_new.recast_time` (uint32 milliseconds) drives per-spell cooldowns. In `Mob::SpellFinished` at `spells.cpp:2817-2841`, when `recast_time > 1000`, the engine starts a player-timer `pTimerSpellStart + spell_id` for `recast_time / 1000` seconds. The check happens AFTER `SpellOnTarget` (which calls `SpellEffect`), so post-effect state is available when the timer is set. Timer entries can be cleared via `GetPTimers().Clear(&database, pTimerSpellStart + spell_id)` (used elsewhere at `spells.cpp:7218-7266`).

**Linked timers (cross-spell shared cooldowns) via `EndurTimerIndex` (a.k.a. `spells_new.timer_id`).** This is an int8 with valid slots 1–19. **All 19 slots are currently occupied** (per config-expert DB audit). The 12 new spells therefore cannot use linked-timer sharing. Not a problem since each spell is class-restricted — a character can never have more than one of the 12 in their spellbook anyway. Set `timer_id = 0` for all 12.

**Scroll-scribe path.** `Client::OPMemorizeSpell` at `client_process.cpp:1164-1248` handles scribe (validates that `item->Scroll.Effect == m->spell_id` and class equippability), then calls `Client::ScribeSpell(spell_id, slot)` at `spells.cpp:6002-6024`, which writes `m_pp.spell_book[slot]` and persists via `database.SaveCharacterSpell(character_id, spell_id, slot_id)`. The `character_spells` table has 3 columns: `(id, slot_id, spell_id)`.

**Auto-scribe delivery (Titanium-confirmed).** `LoadCharacterSpellBook` (`zonedb.cpp:597-627`) reads all `character_spells` rows on every zone-in into `m_pp.spell_book[]`. `OP_PlayerProfile` (`client_packet.cpp:1717-1723`) delivers the full 400-slot array to the Titanium client. **No live push opcode is required** — a SQL INSERT into `character_spells` while a player is logged out is sufficient; the spell appears on next login. (`OP_NewSpellbook` and `OP_SpellSlotChange` do not exist in the Titanium opcode table per protocol-agent's audit.)

**Titanium spellbook capacity.** `SPELLBOOK_SIZE = 400` (`titanium_limits.h:329`). 50 pages × 8 spells. The migration writes to the lowest free slot per character; even maxed-out characters won't exceed 400 in practice.

**Titanium spell ID ceiling.** `SPELL_ID_MAX = 9999` (`titanium_limits.h:329`). Spells with IDs > 9999 are silently dropped from the wire format (`titanium.cpp:1392-1408`). Server-side `MemorizeSpell` also blocks IDs out of range (`client.cpp:3543`). **All 12 new spell IDs MUST be ≤ 9999.**

**Rule system.** `RULE_INT(Category, Name, default, "doc")` macros in `eqemu/common/ruletypes.h` generate the rule at compile time; rules are seeded from `rule_values` at server boot via `RuleManager`. `Spells:` category exists at `ruletypes.h:425`, ends at `RULE_CATEGORY_END()` at line 549. `#reloadrules` re-reads `rule_values` into the in-memory rule cache without requiring a server restart, so a rule consulted dynamically at cast time is hot-tunable. Active ruleset on this server is `ruleset_id = 1` (`default`).

**Bard handling.** `IsBardSong(spell_id)` in `common/spdat.cpp:855-871` returns true iff `spells[spell_id].classes[Class::Bard - 1] < 255` AND not a discipline. Inside `Mob::SpellFinished` at `spells.cpp:1472-1498`, if a Bard casts a song-classified spell from a gem slot, the engine engages bard-song-mode UNLESS `buff_duration == 0xFFFF`, which is an explicit short-circuit at line 1475 — when this hits, the engine logs and falls through, **`bard_song_mode` is never set true**, and the cast follows the identical post-cast path as any non-Bard cast (including `SendSpellBarEnable`). Protocol-agent confirmed in their follow-up audit that this is a complete bypass, not a partial one. The 3-minute cooldown still applies normally.

**Multi-corpse selection.** `EntityList::GetCorpseByOwner(Client*)` at `entity.cpp:2027-2037` walks `corpse_list` (a `std::map<uint16, Corpse*>` keyed by entity ID) and returns the first match by name. Entity IDs are assigned monotonically, so first-found-by-name is **oldest corpse first**, not most-recent-first.

### Gap Analysis

What's missing between current state and PRD requirements:

1. **No spell ID headroom for 12 new spells in the Titanium-safe range.** Reclamation needed (data-expert task 0).
2. **No spell rows.** 12 new spells_new rows must be created (one per casting class).
3. **No scroll items.** 12 new `items` rows (itemtype = 9 / Scroll).
4. **No vendor entries.** `merchantlist` rows for every starting-city class spell vendor that supports each of the 12 classes.
5. **No auto-scribe migration.** Existing characters of the 12 classes must have the spell pre-scribed on next login.
6. **No tunable cooldown rule.** `Spells:UniversalSummonCorpseCooldown` does not exist.
7. **No-op-no-cooldown UX missing.** Engine currently sets the recast timer regardless of whether SummonCorpse actually summoned anything — a "did I leave a corpse here?" probe burns the cooldown.

## Technical Approach

### Architecture Decision

Apply the least-invasive-first principle. Per-layer breakdown:

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| Spell ID reclamation (delete unused sub-9999 rows) | SQL (DELETE on spells_new) | Required to fit within Titanium's `SPELL_ID_MAX = 9999`. Strictly safer than introducing a per-client opcode rewrite. |
| 12 new spells | SQL (spells_new) | Reuses existing SE_SummonCorpse SPA — no engine change for the effect itself. |
| 12 new scroll items | SQL (items) | Standard scroll-item pattern (itemtype=9, scrolleffect=spell_id). |
| Vendor placement | SQL (merchantlist) | Standard vendor inventory pattern; no new merchant NPCs. |
| Auto-scribe for existing chars | SQL migration (character_spells) | One-time INSERT...SELECT per class; idempotent. Titanium delivers via OP_PlayerProfile on next zone-in — no server push. |
| Cooldown rule | C++ (ruletypes.h add) + SQL (rule_values seed) | Standard rule pattern. Operator-tunable hot via `#reloadrules`. |
| Rule-driven cooldown override | C++ (spells.cpp:2817-2841 — read rule when spell has the Universal-Summon-Corpse `spell_category`) | One-line conditional inside the existing recast block. Keyed on `spell_category` (per config-expert recommendation), NOT `IsEffectInSpell(SE_SummonCorpse)` which would also leak into existing NEC/SHM summon-corpse spells. |
| No-op cooldown decouple | C++ (spell_effects.cpp + spells.cpp + mob.h — bool flag) | ~10-line patch in 3 files. Engine supports it cleanly via the post-SpellEffect ordering of the recast block. |
| Bard song-mode bypass | SQL only (`buff_duration = 0xFFFF` on Bard variant; defensively on all 12) | Engine has an explicit short-circuit; we just set the trigger value. Protocol-agent confirmed identical wire behavior to non-Bard casts. |
| Lua/Perl scripts | None | Quest-script system is not involved. |
| Server config / Docker | None | No infra changes. |

### Data Model

#### Spell ID allocation strategy

**Goal:** 12 contiguous (or nearly contiguous) spell IDs ≤ 9999.

**Source pool:**
- 3 currently unused gaps: **1348, 5093, 9412**.
- 9+ more reclaimed by data-expert via the procedure below.

**Reclamation procedure (data-expert task 0):**

```sql
-- Find spells_new rows in [1, 9999] that are referenced by NOTHING.
SELECT s.id, s.name
FROM spells_new s
WHERE s.id BETWEEN 1 AND 9999
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.spell_id = s.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.scrolleffect = s.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.clickeffect = s.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.proceffect = s.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.worneffect = s.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.focuseffect = s.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.bardeffect = s.id)
  AND NOT EXISTS (SELECT 1 FROM npc_spells_entries nse WHERE nse.spellid = s.id)
  AND NOT EXISTS (SELECT 1 FROM aa_rank_effects are WHERE are.effect_id = 132 AND are.base_value = s.id)
  -- Add any other spell-id reference site you know of
LIMIT 50;
```

The data-expert reviews the candidate list (typically these are old PoP+ test spells, deprecated entries, or duplicates that survived previous schema work) and selects 9+ for deletion. Exclude any spell with effects that reference player-experience-affecting SPAs unless the data-expert is confident no live system uses them.

**Backup before delete:** Per MEMORY.md work-protection rules, dump the 9+ rows to a backup SQL file (`claude/tmp/feature-summon-corpse-spell/reclaimed-spells-backup.sql`) before DELETE.

**Final allocation:** Once 12+ IDs are available, data-expert assigns them to the 12 classes. Recommend grouping (e.g., the 3 found gaps + 9 contiguous reclaimed IDs) for human readability, but not required.

#### New `spells_new` rows (12 total)

Schema reference: `eqemu/common/spdat.h:1599-1820`. Critical fields per row:

| Field | Value | Notes |
|-------|-------|-------|
| `name` | per class — see PRD §Class Spell Names table | Lore-master final names |
| `cast_time` | `6000` | 6 seconds, ms |
| `recovery_time` | `2500` | Standard for utility spells |
| `recast_time` | `180000` | 3 minutes default; rule may override at cast time |
| `mana` | `0` | Free |
| `effect_id1` | `91` | SE_SummonCorpse |
| `effect_base_value1` | `255` | Max corpse-owner level cap (uint8 max; covers any level) |
| `formula1` | `100` | Standard for fixed-value SPAs |
| `effect_id2..12` | `254` | Blank/no-effect sentinel |
| `classes[N]` | `1` for the spell's class, `255` for all others | Per PRD §Appendix |
| `target_type` | `6` (`ST_Self`) | `eqemu/zone/spdat.h` SpellTargetType enum |
| `buff_duration` | `0xFFFF` (`65535`) | Defensive for all 12; mandatory for Bard variant to bypass bard-song-mode (verified by protocol-agent) |
| `buff_duration_formula` | `0` | No buff |
| `resist_type` | `0` | No resist check (self-target) |
| `skill` | match class casting skill (Conjuration/Alteration/Divination/Singing for Bard) | Cosmetic only |
| `goodEffect` | `1` | Beneficial |
| `descnum` / `effect_description_id` | reuse from existing Necromancer summon-corpse row | Cosmetic |
| `new_icon` | clone from existing Necromancer summon-corpse row | Reuse — no new art |
| `casting_animation` | clone from existing Necromancer summon-corpse row | Reuse |
| `timer_id` (`EndurTimerIndex`) | `0` | All 19 shared-timer slots are taken; do NOT share. Each spell tracked independently via `pTimerSpellStart + spell_id`. |
| `spell_category` | new category ID (recommend e.g. `200`) | Used by C++ rule-override predicate to discriminate from existing NEC/SHM summon-corpse spells. Data-expert verifies the chosen value is unused via `SELECT DISTINCT spell_category FROM spells_new ORDER BY 1` — pick a value not currently in the result set. |
| `is_discipline` | `0` | Spell, not discipline |
| `deity_agnostic` | `1` | Not deity-restricted |
| `min_resist`, `max_resist` | `0` | No resist |
| `not_focusable` | `1` | Cooldown should not be focus-reduced |
| `no_block` | `1` | Cannot be blocked |

#### New `items` rows (12 scrolls)

| Field | Value |
|-------|-------|
| `Name` | "Scroll: <Spell Name>" — e.g., "Scroll: Spectral Translocation" |
| `itemtype` | `9` (ItemTypeScroll) |
| `scrolleffect` | <new spell ID> |
| `scrolltype` | clone from a comparable level-1 scroll item |
| `scrolllevel` | `1` |
| `classes` | bitmask for the spell's single class (CLR=2, PAL=4, RNG=8, SHD=16, DRU=32, BRD=128, SHM=512, NEC=1024, WIZ=2048, MAG=4096, ENC=8192, BST=16384) |
| `races` | `65535` (all races; the class restricts naturally) |
| `slots` | `1048584` (cursor + general inventory standard for scrolls — verify against existing scroll items) |
| `price` | trivial copper (e.g., `1000` = 10 silver — match existing level-1 scroll prices) |
| `nodrop` | `0` (tradeable) |
| `norent` | `0` |
| `weight` | `1` |
| `idfile` | clone from existing summon-corpse scroll model |

Item IDs: data-expert allocates 12 IDs in a custom range — recommend `1000001-1000012` or a free range adjacent to existing custom items.

#### `merchantlist` entries

For each class, identify every starting-city class spell vendor (see context/source-spike-findings.md §8 for the city-by-class table). For each (class, city) pair, INSERT one merchantlist row:

```sql
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
VALUES (<vendor_npc.merchant_id>, <next free slot>, <scroll_item_id>, 0, 1, 0, 100);
```

Data-expert task includes producing the full enumeration (likely 30-50 rows total). The lore-master decision in `lore-notes.md` Final Sign-Off authorizes "every starting-city class spell vendor" — no faction-gating.

#### `character_spells` auto-scribe migration

Idempotent SQL, run once at server start (or as a manual migration step), one INSERT block per class. Pseudocode (data-expert finalizes):

```sql
-- For each of the 12 classes, insert the new spell at the lowest free slot for every existing character of that class.
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       (SELECT COALESCE(MAX(cs2.slot_id), -1) + 1 FROM character_spells cs2 WHERE cs2.id = cd.id),
       <NEW_SPELL_ID_FOR_THIS_CLASS>
FROM character_data cd
WHERE cd.class_ = <CLASS_ID>
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM character_spells cs
      WHERE cs.id = cd.id AND cs.spell_id = <NEW_SPELL_ID_FOR_THIS_CLASS>
  );
```

Class IDs (per PRD §Appendix and `eqemu/common/classes.h`): CLR=2, PAL=3, RNG=4, SHD=5, DRU=6, BRD=8, SHM=10, NEC=11, WIZ=12, MAG=13, ENC=14, BST=15. (WAR=1, MNK=7, ROG=9 excluded.)

Idempotency: the `NOT EXISTS` clause makes the migration safe to re-run. The `MAX(slot_id) + 1` subquery guarantees no slot collision per character. Per protocol-agent: no server push needed; spells appear on next zone-in via `OP_PlayerProfile`. **Migration must run while affected characters are logged out** (or be followed by a `#kick` for any logged-in characters, since the in-memory `m_pp.spell_book[]` won't reflect the DB change until next zone-in).

**Slot cap guard:** Subquery floor at `MIN(MAX(slot_id) + 1, 399)` to avoid writing to slot 400+ (Titanium SPELLBOOK_SIZE = 400). In practice no character on this server is anywhere near 400 scribed spells, but defensive cap is cheap.

#### `rule_values` row

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES (1, 'Spells:UniversalSummonCorpseCooldown', '180',
        'Cooldown in seconds for the universal summon corpse spell line. 0 disables. Default 180 (3 min). Hot-reloadable via #reloadrules.');
```

Ruleset 1 is the default and only active ruleset on this server (config-expert verified).

### Code Changes

#### C++ Changes

**File: `eqemu/common/ruletypes.h`** — register the new rule (1 line, inserted before `RULE_CATEGORY_END()` at line 549, after the last existing `Spells` rule):

```cpp
RULE_INT(Spells, UniversalSummonCorpseCooldown, 180,
    "Cooldown in seconds for the Universal Summon Corpse spell line (the 12 class-flavored level-1 self-summon spells). 0 disables. Default 180. Hot-reloadable via #reloadrules.")
```

**File: `eqemu/zone/mob.h`** — declare a per-Mob bool to flag a no-op cast:

```cpp
// near other transient cast-state members
bool m_summon_corpse_was_noop{false};
```

**File: `eqemu/zone/spell_effects.cpp`** — set the flag in the no-corpse branch of the SummonCorpse case (around line 1851):

```cpp
else {
    // No corpse found in the zone
    MessageString(Chat::LightBlue, CORPSE_CANT_SENSE);
    if (TargetClient == CastToClient()) {
        m_summon_corpse_was_noop = true;
    }
}
```

(Only set the flag when self-targeting — the existing NEC/SHM cross-player summon-corpse behavior is preserved unchanged. Cross-player no-op casts continue to set the cooldown.)

**File: `eqemu/zone/spells.cpp`** — modify the recast block at lines 2817-2841 to (a) consult the rule (keyed on `spell_category`, per config-expert), and (b) skip the timer Start if `m_summon_corpse_was_noop` is set:

```cpp
} else if (spells[spell_id].recast_time > 1000 && !spells[spell_id].is_discipline) {
    int recast = spells[spell_id].recast_time / 1000;

    // Rule override for the universal summon-corpse line
    // Discriminator: spell_category (data-expert assigns a unique value to all 12 new spells; existing
    // NEC/SHM summon-corpse spells retain their stock spell_category and are unaffected by this rule).
    static const int kUniversalSummonCorpseCategory = /* matches new spells' spell_category */;
    if (spells[spell_id].spell_category == kUniversalSummonCorpseCategory) {
        int rule_cd = RuleI(Spells, UniversalSummonCorpseCooldown);
        if (rule_cd >= 0) {
            recast = rule_cd;
        }
        if (m_summon_corpse_was_noop) {
            m_summon_corpse_was_noop = false;
            recast = 0;
        }
    }

    if (spell_id == SPELL_LAY_ON_HANDS) {
        recast -= GetAA(aaFervrentBlessing) * 420;
    } else if (IsHarmTouchSpell(spell_id)) {
        recast -= GetAA(aaTouchoftheWicked) * 420;
    }
    // ... rest of existing focus-reduction logic ...
    if (recast > 0) {
        CastToClient()->GetPTimers().Start(pTimerSpellStart + spell_id, recast);
    }
}
```

The `if (recast > 0)` guard already exists in the original code, so the noop case (`recast = 0`) skips the Start cleanly. The `kUniversalSummonCorpseCategory` constant is set during c-expert's task in coordination with data-expert (both must agree on the value).

#### Lua/Script Changes

None. The spell uses the standard spell engine, not quest hooks.

#### Database Changes

Summarized above in §Data Model. Migration file structure (data-expert finalizes):

0. **Spell ID reclamation:** DELETE 9+ unused sub-9999 spell rows. Backup first.
1. INSERT 12 spells_new rows.
2. INSERT 12 items rows.
3. INSERT N merchantlist rows.
4. INSERT 12 character_spells INSERT...SELECT batches (one per class).
5. INSERT 1 rule_values row.

Ordering matters: spell rows must exist before items.scrolleffect and character_spells rows reference them (logically; PEQ has no enforced FKs). **Single transaction recommended** so any failure rolls back atomically. **Reclamation step (0) should be in its own transaction with explicit verification** before the rest is applied — undoing a delete after a downstream commit is harder than undoing a single-pass migration.

#### Configuration Changes

None to `eqemu_config.json` or `login.json`. The new rule is a DB row in `rule_values` and a compile-time `RULE_INT` in `ruletypes.h` (the binary needs to recognize the rule key).

## Implementation Sequence

Tasks are ordered by dependency. Each task names exactly one expert.

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 0 | **CRITICAL PRECONDITION:** Reclaim 9+ sub-9999 spell IDs in `spells_new` via the SQL audit query in §Data Model. Backup deleted rows to `claude/tmp/feature-summon-corpse-spell/reclaimed-spells-backup.sql`. Combined with the 3 known gaps (1348, 5093, 9412), produce a final list of 12 spell IDs for the new spells. | data-expert | — | DB audit + DELETE + backup |
| 1 | Add `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, ...)` to `eqemu/common/ruletypes.h` before `RULE_CATEGORY_END()` at line 549. Confirm clean `ninja` build. | config-expert | — | 1 line + build |
| 2 | Identify the existing Necromancer summon-corpse row in `spells_new` (likely spell ID 3 "Lesser Summon Corpse" or similar — verify via `SELECT id, name, new_icon, casting_animation, descnum, effect_description_id, spell_category FROM spells_new WHERE effectid1 = 91 ORDER BY id`). Capture all the cosmetic fields plus the spell_category (so the new universal spells can pick a DIFFERENT category, not collide). Author the chosen `spell_category` constant for the new spells. Share with c-expert. | data-expert | 0 | DB query + capture |
| 3 | Author the 12 new `spells_new` INSERT statements, one per class, using values from the §Data Model table, the IDs from task 0, and the cloned icon/animation from task 2. Save to `data-expert/migrations/01-insert-spells.sql`. | data-expert | 2 | 12 INSERT rows |
| 4 | Add `bool m_summon_corpse_was_noop{false};` to `eqemu/zone/mob.h`. Set it in `eqemu/zone/spell_effects.cpp` no-corpse branch (~line 1851) when `TargetClient == CastToClient()`. Read it in `eqemu/zone/spells.cpp` recast block (~line 2817-2841) gated on the spell_category constant from task 2; also add the `RuleI(Spells, UniversalSummonCorpseCooldown)` override. | c-expert | 1, 2 | ~15 lines across 3 files + build |
| 5 | Author the 12 new `items` INSERT statements (scroll items). Save to migration file. | data-expert | 3 | 12 INSERT rows |
| 6 | Enumerate every starting-city class spell vendor's `npc_types.merchant_id` for each of the 12 classes (per the city table in `architect/context/source-spike-findings.md §8`). Author the merchantlist INSERTs. Save to migration file. | data-expert | 5 | ~30-50 INSERT rows |
| 7 | Author the auto-scribe migration: 12 idempotent `INSERT INTO character_spells SELECT ...` blocks with `NOT EXISTS` and `MIN(MAX(slot_id) + 1, 399)` subqueries, one per class, using the 12 new spell IDs. Save to migration file. | data-expert | 3 | 12 INSERT...SELECT blocks |
| 8 | Author the rule_values seed row for `Spells:UniversalSummonCorpseCooldown`. Save to migration file. | config-expert | 1 | 1 INSERT |
| 9 | Bundle the new-content SQL (tasks 3, 5, 6, 7, 8) into a single transactional migration. Test against a DB snapshot (data-expert workspace). Verify idempotency by running twice. Verify scribe migration affects exactly the correct character set (count by class). | data-expert | 3, 5, 6, 7, 8 | Migration test |
| 10 | Rebuild zone/world binaries (`docker exec ... ninja -j$(nproc)`). Restart full stack per MEMORY.md startup order (shared_memory → loginserver → world → zones). Apply migration. | infra-expert | 4, 9 | Build + restart |
| 11 | Hand off to game-tester for validation. | (architect dispatches) | 10 | — |

**No protocol-agent task in implementation phase** — protocol-agent's research is already complete and recorded. **No lua-expert or perl-expert task** — no quest scripts are touched.

**Sequencing note:** Task 0 (reclamation) is gating; nothing else can start until 12 IDs are available. Tasks 1, 4 (config/c-expert) can run in parallel with tasks 0, 2 (data-expert) up until task 4 needs the spell_category constant from task 2.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Spell ID reclamation deletes a row that turns out to be referenced.** | Medium during reclamation | High — deleted spell silently disappears for any user/system referencing it | Audit query covers all known reference sites (character_spells, all 6 item effect columns, npc_spells_entries, aa_rank_effects). Backup before delete. Data-expert reviews each candidate name before approving. Single dedicated transaction so rollback is fast. |
| Bard variant accidentally engages bard-song-mode | Eliminated by `buff_duration = 0xFFFF` | High if missed | Set `buff_duration = 0xFFFF` defensively on all 12 spells. Game-tester explicitly verifies Bard variant casts as a one-shot spell with normal SendSpellBarEnable behavior. Protocol-agent confirmed wire behavior is identical to non-Bard casts. |
| Auto-scribe migration writes to slot >= 400 | Very low | Medium — DB row exists but Titanium client doesn't render | `MIN(MAX(slot_id) + 1, 399)` defensive cap. |
| Recast timer rule override leaks into existing NEC/SHM summon-corpse line | Low if `spell_category` discriminator is unique | Medium — operator unintentionally retunes high-level spell cooldowns | Use a NEW `spell_category` value for the 12 new spells (data-expert verifies value is unused via `SELECT DISTINCT spell_category FROM spells_new`). NEC/SHM existing spells retain their stock category. |
| Migration runs before the new spells_new rows are loaded into shared memory | Low | High — character_spells references unknown spell_id; client may fail to load spellbook | shared_memory must run before world starts (already standard in startup order per MEMORY.md). Verify in infra-expert task. The new spells_new rows must be inserted BEFORE shared_memory starts (i.e., DB migration runs before `make restart` step 1). |
| `m_summon_corpse_was_noop` flag survives across casts | Low | Medium — next cast skips its cooldown unintentionally | Always reset the flag in the recast block (already in design — `m_summon_corpse_was_noop = false;` on read). |
| Existing players surprised by the spell appearing in spellbook | Low | Low (UX) | PRD explicitly approves silent auto-scribe — no MOTD. Document in release notes for ops. |
| Necromancer player's existing high-level summon-corpse line shares a `timer_id` with new spells | None — `timer_id = 0` for new spells; all 19 EndurTimerIndex slots are taken by other spells anyway | High if shared | Game-tester verifies casting the new spell does NOT block the high-level NEC summon-corpse spell and vice versa. |
| Reclaimed spell ID is reused for one of our new spells, and a logged-in client still has the OLD spell cached locally | Low | Low — client expects spell name X, server now sends summon-corpse | Recommend reclaimed IDs be selected from rows not present in any character_spells row. Bounce all sessions before applying (already implied by full-stack restart). |

### Compatibility Risks

- **Existing NEC/SHM summon-corpse spells:** PRD §Acceptance Criteria explicitly requires no regression. `spell_category` discriminator keeps the new rule from leaking into them. Their `recast_time` is unaffected.
- **Existing Bot summon-corpse via `RuleB(Bots, AllowCommandedSummonCorpse)`:** New SE_SummonCorpse handler change (`m_summon_corpse_was_noop` flag) only sets the flag when `TargetClient == CastToClient()`. Bot-commanded summon casts on a player's corpse should never trigger the noop branch since the target is the player, not the bot. Game-tester to confirm.
- **Companion system:** Companions do not leave lootable corpses (they suspend/restore via the custom Companion subsystem). The PRD explicitly states the new spell does NOT summon companion corpses. Architecturally, the SE_SummonCorpse handler calls `entity_list.GetCorpseByOwner(Client*)` which only iterates `IsPlayerCorpse()` corpses — companion corpses are filtered out by definition. **Verified safe.**
- **Auto-scribe on a deleted character:** Migration filters `cd.deleted_at IS NULL`. Soft-deleted characters are skipped.
- **A character of one of the 12 classes that already has the spell scribed:** `NOT EXISTS` guard makes the migration idempotent.

### Performance Risks

- **Per-cast overhead:** The added `spell_category == kUniversalSummonCorpseCategory` check + `RuleI` lookup runs once per spell cast, only when `recast_time > 1000`. Negligible.
- **Migration cost:** A single ALTER-style INSERT...SELECT against `character_data` (~thousands of rows for an old server, far fewer for this 1-3 player server). Sub-second on this scale.
- **Spellbook UI render:** Adding 1 spell to the spellbook is trivial.
- **Memory:** 12 additional rows in shared memory (each ~3KB based on `SPDat_Spell_Struct` size) = ~36KB. Negligible.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes, with one critical precondition (spell ID reclamation). All other technical questions resolved through source-code research and protocol/config consultation:
- `SE_SummonCorpse` is NOT class-gated — confirmed in `spell_effects.cpp:1793-1868`.
- Bard `buff_duration = 0xFFFF` bypass is a complete bypass, not partial — confirmed by protocol-agent in their follow-up audit.
- Cooldown rule keyed on `spell_category` discriminates from existing NEC/SHM line cleanly — config-expert confirmed.
- Auto-scribe via SQL only is sufficient; no live push opcode needed — protocol-agent confirmed via `LoadCharacterSpellBook` + `OP_PlayerProfile` analysis.
- No-op-no-cooldown decouple is achievable via the cast pipeline ordering (SpellEffect runs before recast timer set).

**Hardest residual unknown:** None blocking, but the data-expert reclamation step requires careful judgment per candidate row. Mitigation: backup-before-delete and a thorough audit query covering all known reference sites.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes, with one element worth re-justifying:

- **Reuse SE_SummonCorpse** — could not be simpler.
- **12 spell rows, not 1 row with 12 classes** — required for per-class spell names.
- **`buff_duration = 0xFFFF` short-circuit** — uses the engine's intended escape hatch.
- **`spell_category` discriminator vs. spell-ID range-check** — `spell_category` is cleaner because it stays correct if the spell IDs are reshuffled later. Config-expert recommended this; matches my preference.
- **Rule + DB row vs. row-only** — one extra line of code in exchange for `#reloadrules` hot-tunability. Worth it.
- **No-op-no-cooldown C++ change** — could be skipped (PRD authorizes accepting the wart). Counter-argument: it's ~10 lines across 3 files, contained, and meaningfully improves player UX. **Keep it.**

**Re-justification of spell ID reclamation:** Could we instead use IDs > 9999? No — Titanium drops them silently. The architecture has no other path within the constraint. Reclamation is the only viable approach unless we abandon the feature for this client.

**Things considered and rejected:**
- Adding a new `EntityList::GetMostRecentCorpseByOwner()` method — YAGNI.
- Per-class animations — PRD explicitly rejects scope creep.

### Pass 3: Antagonistic

**What could go wrong?** Steel-manned threats:

1. **Reclamation deletes a "rare drop" spell that nobody currently has but is in some loot table.** Mitigation: audit query covers `lootdrop_entries` (transitively via items). Edge: if a quest reward is on the deleted spell, it would silently fail. Add `quest_globals` and `tasks.reward_id_list` to the audit. Pre-deploy: data-expert manually reviews candidate names against quest-script content (~5 mins).
2. **Player exploits zone-edge to summon corpse just outside playable bounds.** Existing engine concern; not new.
3. **Player casts and gets killed mid-cast, then casts again from second corpse-runner instance.** Standard interrupt rules apply.
4. **Player exploits the group/raid check to summon a friend's corpse.** `target_type = ST_Self` (value 6) forces `spell_target = this` in the `SingleTarget` case at `spells.cpp:1910-1922`. The SE_SummonCorpse handler then sees `TargetClient == CastToClient()` regardless of player intent. Self-only enforced.
5. **A NEW character mid-tutorial casts the spell with no corpse, hits the no-op branch, spam-casts.** Still has 6s cast time. Not exploitable; chat spam at worst.
6. **A Bard player gets confused that the spell does NOT auto-pulse like other Bard spells.** UX risk — mitigate via spell description text.
7. **`spell_category` collision with a future spell or a row we haven't audited.** Data-expert verifies the chosen value is unused via `SELECT DISTINCT spell_category FROM spells_new`. Choose a value above all current categories (e.g., 200+).
8. **Player has 60 active buffs, cast fails because no buff slot.** N/A — `buff_duration = 0xFFFF` means no buff is granted.
9. **Server crash mid-migration.** Single transaction wrapper rolls back atomically. Idempotent guards enable safe re-run.
10. **Operator sets `Spells:UniversalSummonCorpseCooldown = 0` to disable cooldown for testing, forgets to revert.** Acceptable — same surface as any other rule. Document in release notes.
11. **Operator deletes the new rule_values row, expects the engine default of 180.** Yes — `RuleI(Spells, UniversalSummonCorpseCooldown)` returns the compile-time default if the row is absent. Safe.
12. **Existing high-level NECROMANCER who already has Greater Summon Corpse scribed gets the new spell auto-scribed.** Migration uses `MAX(slot_id) + 1`, so the new spell appends after existing scribed spells. No displacement.
13. **Player logged in during migration — migration affects them but in-memory `m_pp.spell_book[]` doesn't reflect the change.** Mitigation: full-stack restart in infra-expert task forces all sessions to re-login. Or: kick affected sessions before migration.
14. **Reclaimed spell ID later turns out to have been used by some quest script's `quest::scribespells(level)` mass-scribe.** Audit `quests/` directory for `castspell`, `scribespells`, `traindiscs` calls referencing the candidate IDs. Data-expert task 0 includes this grep. Already in scope.
15. **Player who just deleted a character of one of the 12 classes — migration runs the same day, character is soft-deleted, no row written.** Filter handles this.

### Pass 4: Integration

**Sequencing dependencies:**
- Task 0 (reclamation) gates everything content-related (tasks 2, 3, 5, 6, 7, 9). Until 12 IDs are reserved, no spell row work can begin.
- Task 1 (rule registration) is independent of task 0.
- Task 2 (capture clone-source row + assign new spell_category) blocks task 4 (c-expert needs the constant).
- Tasks 1 and 4 (C++ changes) need a rebuild before any DB migration is meaningful — but the migration can be authored independently. Rebuild + migration must both complete before game-tester validates.
- Task 9 (transactional migration bundle) requires tasks 3, 5, 6, 7, 8 done.
- Task 10 (build + deploy) is the final integration step.

**Cross-agent handoffs:**
- c-expert depends on data-expert for the `spell_category` constant. Coordinate via `agent-conversations.md`.
- config-expert (rule definition + rule_values seed) and c-expert (rule consumption) edit different files in the same area. config-expert's `RULE_INT` registration in `ruletypes.h` is independent; the consumption happens in c-expert's `spells.cpp` edit.

**No circular dependencies. No missing prereqs. Validation has full coverage** of the PRD acceptance criteria (see §Validation Plan).

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | 4 | Owns the C++ engine edits: `mob.h`, `spell_effects.cpp`, `spells.cpp`. Must coordinate `spell_category` constant with data-expert. |
| **data-expert** | 0, 2, 3, 5, 6, 7, 9 | Owns spell ID reclamation (task 0 — critical precondition), all spells_new / items / merchantlist / character_spells migration work. Dominant role in this feature. |
| **config-expert** | 1, 8 | Owns rule registration (`ruletypes.h` + `rule_values` seed row). |
| **infra-expert** | 10 | Owns the build + restart cycle. |
| **game-tester** | (post-implementation) | Validates the PRD acceptance criteria. |

**NOT required for implementation phase:** lua-expert, perl-expert (no scripts touched), protocol-agent (research already complete).

## Validation Plan

The game-tester verifies all PRD §Acceptance Criteria items. Specifically:

- [ ] **Spell ID range.** Verify all 12 new spell IDs are ≤ 9999 via `SELECT id FROM spells_new WHERE name LIKE '%Summon Corpse%' OR name IN (...)`. Cross-check against the 12 names in PRD §Class Spell Names.
- [ ] **Reclamation regression check.** For each reclaimed spell ID, verify no character has it scribed (`SELECT * FROM character_spells WHERE spell_id IN (<reclaimed>)`), no item effect references it (search 6 effect columns), no NPC spell list references it.
- [ ] **New character — vendor purchase.** For each of the 12 classes, create a fresh character. Visit the canonical class spell vendor in their starting city. Verify the appropriate scroll appears in inventory at trivial copper cost. Buy and scribe; verify spell appears in spellbook at level 1.
- [ ] **Existing character — auto-scribe.** Pre-migration, identify (or create then save) an existing character of each of the 12 classes. Apply migration. Log in. Verify the spell is scribed in spellbook with no UI message.
- [ ] **Cast mechanics.** Mem the spell into a gem slot, target nothing (or self), cast. Verify: 6-second cast bar, 0 mana consumed, no reagent prompt, no target-required prompt, no fizzle.
- [ ] **Successful summon (in-zone corpse exists).** Die in a zone, return, cast spell. Verify corpse appears at caster's feet, lootable.
- [ ] **No-corpse no-op message.** Cast in a zone where the caster has no corpse. Verify message *"You feel a bit disoriented..."* (CORPSE_CANT_SENSE) or equivalent. Verify the recast timer did NOT trigger (cast again immediately and confirm no "spell not ready" message).
- [ ] **Cooldown applies on successful summon.** Successfully summon a corpse, then attempt to recast within 3 minutes. Verify "spell not ready" message. Wait until 3 minutes elapses; verify spell castable again.
- [ ] **Damage interrupt.** Begin cast in combat (have an NPC attack you mid-cast). Verify cast is interrupted and spell does not consume the recast timer.
- [ ] **Movement interrupt for non-Bards.** Mem and begin cast, walk forward. Verify cast fizzles (engine-standard) for all 11 non-Bard classes.
- [ ] **Bard cast while moving — known behavior.** Bard casts while walking. Confirm the cast completes (engine permits this for Bards by class-design). Verify the spell is single-cast (does NOT auto-repeat or engage song window). Verify gem-cooldown timer applies normally.
- [ ] **Self-target enforcement.** With another player or companion targeted, cast the spell. Verify `target_type = ST_Self` overrides the target and the spell summons the caster's own corpse (not the target's).
- [ ] **No regression on Necromancer high-level summon-corpse.** Existing NEC character with Greater Summon Corpse memmed: cast it on a group member's corpse. Verify it works exactly as before. Verify casting the new low-level NEC variant does NOT trigger the high-level spell's recast timer (independent timer state).
- [ ] **No regression on Shaman summon-corpse.** Same test as above for Shaman.
- [ ] **No regression on the rule scope.** Adjust `Spells:UniversalSummonCorpseCooldown` to 30 via `#rules set`. Cast the new low-level NEC spell. Verify the cooldown is now 30s. Cast the high-level Necromancer Greater Summon Corpse — verify it still uses its OWN recast_time (NOT the rule). Confirms `spell_category` discriminator works.
- [ ] **Class restriction enforcement.** Create a Warrior, Monk, or Rogue character. Attempt to scribe any of the 12 scrolls. Verify the scroll cannot be scribed (class restriction in items.classes bitmask).
- [ ] **Multi-corpse scenario.** Die twice in the same zone (without summoning the first corpse). Cast the spell. Verify ONE corpse summons (engine default — oldest corpse first per `GetCorpseByOwner`). Wait for cooldown, cast again. Verify the second corpse summons.
- [ ] **Cross-zone — no false summon.** Have a corpse in zone A, travel to zone B, cast in zone B. Verify "no corpse in this zone" path. Verify cooldown NOT triggered. Travel back to zone A. Verify the corpse is still there.
- [ ] **Rule live-tunable via #reloadrules.** Update `rule_values` row to `'30'`, run `#reloadrules`, verify next cast cooldown is 30 seconds. Reset to 180.
- [ ] **End-to-end PRD acceptance scenario.** Per PRD §Example Scenario: high-level wizard dies deep in a dungeon, returns to entrance, casts Spectral Translocation. Corpse appears at caster's feet. Loot, re-equip, continue session.

**Sustained-play test** (per `feedback_refactor_regression_discipline.md`): At least one 30-minute sustained play session per class variant after implementation, exercising death-cast cycle multiple times to surface any tick-rate or registration-drift bugs. Confirm the cooldown timer survives a zone change cleanly (player crosses zone line, the timer state persists since it's stored in `pTimers`).

---

> **Next step:** Spawn the implementation team with ONLY: **c-expert, data-expert, config-expert, infra-expert**. Do not spawn lua-expert, perl-expert, or protocol-agent — they have no assigned tasks. game-tester is spawned separately as a solo agent during the Validation phase.

