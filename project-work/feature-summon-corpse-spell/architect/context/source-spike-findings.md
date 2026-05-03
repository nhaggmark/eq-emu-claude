# Source-Spike Findings — Universal Summon Corpse Spell

> Author: architect
> Date: 2026-05-03
> Purpose: Reference artifact for implementation experts. Cites every file:line touched during architecture-phase research so c-expert / data-expert / config-expert can verify the architecture against current source state.

---

## 1. Summon Corpse SPA — already class-agnostic

- **SPA constant:** `SE_SummonCorpse = 91` — `eqemu/common/spdat.h:1155`
  > `constexpr int SummonCorpse = 91; // implemented`
- **Effect handler:** `eqemu/zone/spell_effects.cpp:1793-1868`, `case SpellEffect::SummonCorpse`
- **Class gating:** NONE in the handler. The only restrictions are:
  - Caster must not be `IsNPC()` (line 1799). Bots get a separate gate via `RuleB(Bots, AllowCommandedSummonCorpse)` at `spells.cpp:1912-1917`.
  - When targeting another player, target must be group/raid member of caster (lines 1807-1833).
  - Effect_value (the SPA's base1) is treated as a max-level cap on the corpse owner: `if (TargetClient->GetLevel() <= effect_value)` at line 1838.
- **Implication:** The 12 new spells can use SPA 91 directly. No C++ changes are required to remove a class gate — there is no class gate. Set `effect_base_value1 >= 65` to cover max player level on this server.
- **No-corpse path:** `MessageString(Chat::LightBlue, CORPSE_CANT_SENSE);` at line 1851. This is the player-facing message; `CORPSE_CANT_SENSE` is the eqstr used.

## 2. Recast timer mechanics

- **Recast value source:** `spells_new.recast_time` (milliseconds), read at `eqemu/zone/spells.cpp:2817-2841` inside `Mob::SpellFinished`.
- **Storage:** Player timer slot `pTimerSpellStart + spell_id`, started via `CastToClient()->GetPTimers().Start(pTimerSpellStart + spell_id, recast)` at line 2839. `pTimerSpellStart = 5000` (`eqemu/common/ptimer.h:65`).
- **Timer-id share:** `spells_new.timer_id` (int8) shares cooldowns across spells in the same family — used by `LinkedSpellReuseTimer` at lines 1801, 1822. For the new spells we leave `timer_id = 0` (no cross-share with NEC/SHM existing summon-corpse line, so the new spell doesn't trigger their cooldown or vice versa).
- **Existing recast threshold:** Logic only runs when `recast_time > 1000` ms (line 2817).
- **Clear API:** `GetPTimers().Clear(&database, pTimerSpellStart + spell_id)` — used elsewhere in `eqemu/zone/spells.cpp:7218,7231,7248,7264`.
- **Sequencing:** `SpellFinished` calls `SpellOnTarget` → `Mob::SpellEffect` (where SummonCorpse case fires) BEFORE the recast timer is set later in `SpellFinished`. So a flag set inside the SummonCorpse handler can be inspected at line 2817 to skip the timer.Start call.

### Implication for "no-op = no cooldown" decoupling

A small, contained C++ change in two places enables the design preference:

1. In the SummonCorpse case at `spell_effects.cpp:1851` (the `else { MessageString(...CORPSE_CANT_SENSE...); }` branch), set a per-Mob bool flag `m_summon_corpse_was_noop = true`.
2. In the recast block at `spells.cpp:2817-2841`, check the flag before the recast timer Start call: if set AND the spell uses SE_SummonCorpse, skip the Start call and clear the flag.

This is ~10 lines of change in two files. PRD authorizes accepting the wart if the engine cannot decouple — but the engine CAN, so we do.

## 3. Multi-corpse selection order

- **Function:** `EntityList::GetCorpseByOwner(Client*)` at `eqemu/zone/entity.cpp:2027-2037`.
- **Behavior:** Walks `corpse_list` (a `std::map<uint16, Corpse*>` keyed by **entity ID**) and returns the first match by name.
- **Insight:** Entity IDs are assigned monotonically as entities are added to the entity list. **First match in iteration order = oldest entity ID = oldest corpse**, NOT most recent. This contradicts the PRD's design preference for "most recent first."
- **Decision:** Accept current engine behavior for v1 (oldest corpse first). Adding a "most recent first" pass would require refactoring `GetCorpseByOwner` (touches existing NEC/SHM behavior — out of scope for this feature). Document in PRD release notes: "If you have multiple corpses in this zone, the spell summons the oldest first; cast again after cooldown to summon the next."
- **Alternative considered:** Add `EntityList::GetMostRecentCorpseByOwner(Client*)` and modify the SummonCorpse SPA path to use it for self-target only. Rejected on YAGNI: the PRD calls this a "design preference," not a hard requirement, and the simpler answer (oldest-first) is engine-consistent.

## 4. Bard scribed-spell routing

- **`IsBardSong(spell_id)` definition:** `eqemu/common/spdat.cpp:855-871`. Returns true iff `spells[spell_id].classes[Class::Bard - 1] < UINT8_MAX (255)` AND not a discipline.
- **Implication:** Any spell with Bard at classes8 < 255 is treated as a "song" by the engine. The Bard variant of the new summon-corpse spell will be flagged as a song.
- **Bard-song-mode branch:** `eqemu/zone/spells.cpp:1472-1498` inside `Mob::SpellFinished`.
  - Outer guard: `if (GetClass() == Class::Bard) { if (IsBardSong(spell_id) && slot < CastingSlot::MaxGems) { ... }}`
  - **Critical short-circuit at line 1475:** `if (spells[spell_id].buff_duration == 0xFFFF) { LogSpells("...not applying bard logic because duration..."); }` — falls through, `bard_song_mode` stays false.
  - ELSE branch: applies pulsing-song logic and sets `bard_song_mode = true`.
- **Resolution:** Set `buff_duration = 0xFFFF` on the Bard variant. This bypasses the song-mode path. Cast then proceeds through `SingleTarget` → `SpellOnTarget` → `SpellEffect` like the other 11 classes.
- **Recommendation:** Set `buff_duration = 0xFFFF` defensively on **all 12 spells** (uniformity, no per-class divergence in the row schema). It's a no-op for the 11 non-Bard variants since `IsBardSong` returns false for them.
- **Known wart:** Line 1472 comment "// bard's can move when casting any spell..." — Bards by engine design can move while casting any spell, this is a Bard player-class property, not a spell property. Cannot be cleanly suppressed. Document in release notes: "Bards may cast Dirge of Homecoming while moving; standard cast-interrupt rules apply for damage/stun, but the movement-interrupt rule that other casters experience does not apply to Bards."

## 5. Rule registration

- **Category:** `RULE_CATEGORY(Spells)` at `eqemu/common/ruletypes.h:425`.
- **Pattern:** `RULE_INT(Spells, RuleName, default_int, "description")`. Example existing rule: `RULE_INT(Spells, TranslocateTimeLimit, 0, "...")` at line 432.
- **Collision check:** Grepped ruletypes.h for "SummonCorpse" — only existing match is `RULE_BOOL(Bots, AllowCommandedSummonCorpse, true, ...)` at line 898. No collision with `Spells:UniversalSummonCorpseCooldown`.
- **Recommended rule:** `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "Cooldown in seconds for the Universal Summon Corpse spell line. 0 disables cooldown. Default 180 (3 minutes).")`
- **rule_values DB row:** `INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES (1, 'Spells:UniversalSummonCorpseCooldown', '180', 'Cooldown in seconds for the universal summon corpse spell line. Set 0 to disable.')` — included in the data-expert migration so it's visible immediately to operators.

## 6. Scroll items & auto-scribe

- **Scroll item type:** `items.itemtype = 9` (ItemTypeScroll, see `eqemu/common/item_data.h:67` enum order).
- **Scroll effect linkage:** `items.scrolleffect` holds the spell ID; `items.scrolltype` and `items.scrolllevel` define the item-effect type and level.
- **Scribe flow (player-initiated):** Client sends `OP_MemorizeSpell` with `scribing = memSpellScribing` (`eqemu/zone/client_process.cpp:1164-1248`). Handler validates that `item->Scroll.Effect == m->spell_id` (line 1221) and that the item is class-equippable (line 1213-1216 with `RuleB(Character, RestrictSpellScribing)`). On success: `ScribeSpell(spell_id, slot)` (line 1222) which writes `m_pp.spell_book[slot]` and persists via `database.SaveCharacterSpell` (`eqemu/zone/spells.cpp:6002-6024`).
- **`character_spells` schema:** `(id INT, slot_id SMALLINT, spell_id SMALLINT)` per `eqemu/common/repositories/base/base_character_spells_repository.h:21-25`. `id` = character_id; `slot_id` = 0-based spellbook slot; `spell_id` = FK to spells_new.id.
- **Auto-scribe migration logic (data-expert design):** For each character whose class is one of the 12 casting classes, INSERT into character_spells the appropriate spell_id at the lowest unused slot_id (subquery: `MAX(slot_id) + 1` per character, or scan for first gap). Skip rows that already exist (idempotent).

### Spellbook slot layout note

`EQ::spells::SPELLBOOK_SIZE` is the cap (architecturally 720 for Titanium-era characters, but data-expert should verify against `common/spells.h` constants). The migration must not write to slots >= SPELLBOOK_SIZE; protocol-agent confirmed (or to be confirmed in agent-conversations).

## 7. Animation / icon

- **Icon field:** `spells_new.new_icon` (int16) — `eqemu/common/spdat.h:1663`. Reuse the existing Necromancer summon-corpse spell's icon ID for all 12 (data-expert task — clone-mutate from the existing row).
- **Casting animation field:** `spells_new.casting_animation` (uint8) at `spdat.h:1651`. Reuse from existing Necromancer summon-corpse spell row.
- **No bespoke art:** Per PRD §Open Questions §6 and §7, reuse one icon/animation across all 12. Avoids art-pipeline scope creep. Uniformity is a feature, not a bug — players will recognize the cast-bar visual across class variants.

## 8. Vendor placement (lore-master decision recorded)

- All 12 scrolls go on the **standard class spell vendor** in each starting city for that class.
- No faction-gated guild vendor placement.
- Rationale per `lore-master/lore-notes.md` "Final Sign-Off" section + PRD §Open Questions §5.
- Implementation: `merchantlist` rows. `npc_types.merchant_id` chains the vendor NPC to the merchantlist. Data-expert task: find each starting-city class spell vendor's merchant_id (per-class, per-city), and add a merchantlist row for the appropriate scroll.

### Starting-city class spell vendor mapping (data-expert reference)

| Class | Starting Cities (Classic-Luclin) |
|-------|----------------------------------|
| Cleric | Erudin, Felwithe, Halas, Kaladim, Qeynos (N), Rivervale, Surefall Glade, Freeport |
| Druid | Greater Faydark, Misty Thicket, Qeynos (S), Surefall Glade |
| Shaman | Cabilis, Halas, Grobb, Oggok, Shar Vahl |
| Necromancer | Erudin (Paineel), Neriak, Cabilis |
| Wizard | Erudin, Felwithe, Freeport, Qeynos, Neriak (also possible) |
| Magician | Erudin, Felwithe, Freeport, Qeynos, Neriak |
| Enchanter | Erudin, Felwithe, Freeport, Qeynos, Neriak, Ak'Anon, Shar Vahl |
| Paladin | Felwithe, Freeport, Halas, Kaladim, Qeynos, Erudin |
| Shadow Knight | Cabilis, Neriak, Freeport (PoP+; in Classic, Neriak/Cabilis only) |
| Ranger | Greater Faydark, Surefall Glade, Qeynos |
| Beastlord | Cabilis, Shar Vahl |
| Bard | Felwithe, Freeport, Kelethin (GFay), Qeynos |

Data-expert: this list is illustrative; reconcile against `start_zones` table and the per-zone spell vendor NPC inventory. The architectural requirement is "scroll appears on the standard level-1 class spell vendor for every starting city that supports the class as a starting city."

---

## File-touch summary for implementation experts

| Layer | Files | Owner |
|-------|-------|-------|
| C++ (rule definition) | `eqemu/common/ruletypes.h` (1 RULE_INT line, ~line 466 in Spells category) | config-expert |
| C++ (no-op cooldown decouple) | `eqemu/zone/spell_effects.cpp` (set flag in SummonCorpse case, ~line 1851); `eqemu/zone/spells.cpp` (check flag before line 2839 timer.Start); `eqemu/zone/mob.h` (declare bool m_summon_corpse_was_noop) | c-expert |
| C++ (rule-driven cooldown override, optional — pending config-expert) | `eqemu/zone/spells.cpp:2817-2841` | c-expert |
| SQL — spells_new | 12 new rows | data-expert |
| SQL — items | 12 new scroll items (itemtype=9, scrolleffect=spell_id, classes bitmask = single class) | data-expert |
| SQL — merchantlist | N rows = sum across all starting-city class vendors | data-expert |
| SQL — character_spells migration | One INSERT...SELECT per class (12 total) | data-expert |
| SQL — rule_values | 1 INSERT for the new rule | config-expert |
| Build & deploy | Rebuild zone binary; restart full stack | infra-expert |

---

## 9. Post-Consultation Updates (added 2026-05-03 after protocol-agent + config-expert replies)

### Spell ID range — BLOCKING

- **Titanium constant:** `SPELL_ID_MAX = 9999` at `eqemu/common/patches/titanium_limits.h:329`
- **Wire enforcement:** `titanium.cpp:1392-1408` silently writes `0xFFFFFFFFU` to spell_book entries with id > 9999
- **Server enforcement:** `client.cpp:3543` `MemorizeSpell` rejects out-of-range ids
- **Current DB state:** Only 3 unused IDs in [1, 9999]: **1348, 5093, 9412**. Need 12.
- **Resolution:** data-expert task 0 (added) reclaims 9+ unused sub-9999 spell rows. Audit query in architecture.md §Data Model. Backup before delete.

### Bard `buff_duration = 0xFFFF` — FULL bypass confirmed

- Protocol-agent's initial analysis suggested `SendSpellBarEnable` would be skipped after Bard cast (bard_song_mode behavioral quirk).
- **Protocol-agent's follow-up (commit `040fa20`) corrected this:** `buff_duration = 0xFFFF` causes `bard_song_mode` to never be set true (line 1475 logs and falls through). The cast takes the **identical** non-bard post-cast path including `SendSpellBarEnable`, `MemorizeSpell(memSpellSpellbar, ...)`, and gem cooldown display. No behavioral difference between Bard and non-Bard casts at the wire level.

### `spell_category` as the rule discriminator

- Per **config-expert recommendation**, the C++ rule-override is keyed on `spells_new.spell_category` (not `IsEffectInSpell(SE_SummonCorpse)` which would also leak into existing NEC/SHM summon-corpse spells, and not spell-ID range which is fragile across ID shuffles).
- The 12 new spells receive a NEW unique `spell_category` value (data-expert chooses an unused integer; verify via `SELECT DISTINCT spell_category FROM spells_new ORDER BY 1`).
- Existing NEC/SHM summon-corpse spells retain their stock `spell_category`, so the rule does not affect them.

### `EndurTimerIndex` (timer_id) slots are exhausted

- Per config-expert DB audit: all 19 valid slots are occupied.
- Decision: `timer_id = 0` for all 12 new spells (no shared cooldown). Each spell tracked independently in `pTimerSpellStart + spell_id`.
- Not a problem because each spell is class-restricted — a character can never have more than one of the 12.

### Auto-scribe via SQL only — confirmed

- Protocol-agent verified: `LoadCharacterSpellBook` (`zonedb.cpp:597`) reads all `character_spells` rows on every zone-in. `OP_PlayerProfile` delivers the full 400-slot array via `client_packet.cpp:1717-1723`.
- No live push opcode required. SQL INSERT into `character_spells` is sufficient. Spells appear on next login.
- `OP_NewSpellbook` and `OP_SpellSlotChange` do not exist in the Titanium opcode table.

### Active ruleset

- `ruleset_id = 1` (`default`) only. Other rulesets exist but are not used by zones on this server. (config-expert verified.)
