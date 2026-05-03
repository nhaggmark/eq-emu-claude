# Universal Summon Corpse Spell — Dev Notes: Protocol Agent

> **Feature branch:** `feature/summon-corpse-spell`
> **Agent:** protocol-agent
> **Task(s):** Protocol feasibility assessment — 5 questions for architect
> **Date started:** 2026-05-03
> **Current stage:** Complete (research-only; no implementation)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Protocol feasibility: spell ID range, spellbook capacity | — | Complete |
| 2 | Protocol feasibility: auto-scribe migration delivery | — | Complete |
| 3 | Protocol feasibility: scroll scribe class-gate | — | Complete |
| 4 | Protocol feasibility: Bard spell-gem routing | — | Complete |
| 5 | Protocol feasibility: cooldown client hint | — | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/patches/titanium_limits.h` | 329–330 | `SPELL_ID_MAX = 9999`, `SPELLBOOK_SIZE = 400` |
| `common/patches/titanium.cpp` | 1392–1408 | spell_book encoding: spells > SPELL_ID_MAX written as 0xFFFFFFFF |
| `common/patches/titanium.cpp` | 1262–1276 | OP_MemorizeSpell encode: slot translated for HT/LoH, reduction NOT forwarded |
| `common/patches/titanium_structs.h` | 409–414 | Titanium MemorizeSpell_Struct includes reduction field |
| `common/patches/titanium_ops.h` | full | OP_LinkedReuse has no entry — opcode unmapped for Titanium |
| `eq_packet_structs.h` | 416–433 | MemorizeSpell_Struct + LinkedSpellReuseTimer_Struct |
| `zone/zonedb.cpp` | 597–627 | LoadCharacterSpellBook: reads character_spells rows → m_pp.spell_book[] |
| `zone/client_packet.cpp` | 1717–1723 | OP_PlayerProfile sent on zone-in containing full spell_book[] |
| `zone/client.cpp` | 3532–3560 | MemorizeSpell: validates spell_id <= SpellIdMax before sending |
| `zone/client_process.cpp` | 1164–1248 | OPMemorizeSpell: class level check, scroll scribe path |
| `zone/spells.cpp` | 6002–6025 | ScribeSpell: updates m_pp.spell_book[], calls MemorizeSpell for live update |
| `zone/spells.cpp` | 1419–1427 | Recast check: pTimerSpellStart + spell_id (server-side) |
| `zone/spells.cpp` | 1467–1498 | Bard casting path: IsBardSong → bard_song_mode |
| `zone/spells.cpp` | 1800–1825 | Post-cast: bard_song_mode vs. normal — MemorizeSpell sent in both |
| `common/spdat.cpp` | 855–871 | IsBardSong: returns true if `spell.classes[Bard-1] < UINT8_MAX && !is_discipline` |
| `common/spdat.cpp` | 2370–2387 | IsPulsingBardSong: returns false if `recast_time > 0` (no song-loop) |
| `common/eq_limits.cpp` | 1136–1148 | Titanium SpellIdMax = 9999 in DynamicLookup table |

### Key Findings

See Stage 2 below for the full verified answers.

---

## Stage 2: Research — Protocol Assessment

### Q1: Spellbook Capacity and Spell ID Range

**Titanium hard limits (from `titanium_limits.h`):**
- `SPELL_ID_MAX = 9999` — absolute ceiling for spell IDs the Titanium client can display
- `SPELLBOOK_SIZE = 400` — 400 spellbook slots (50 pages × 8 spells)

**Current database state:**
- Max spell ID in `spells_new`: **42,602** (far above 9,999)
- Spell IDs in use below 9,999: **9,982 out of 9,999** possible
- Only **3 gaps** exist in the sub-9,999 range: IDs **1348, 5093, 9412**

**Wire format enforcement (`titanium.cpp:1392–1408`):**
```cpp
if (emu->spell_book[r] <= spells::SPELL_ID_MAX)
    eq->spell_book[r] = emu->spell_book[r];
else
    eq->spell_book[r] = 0xFFFFFFFFU;  // silently dropped
```

**Server-side MemorizeSpell guard (`client.cpp:3543–3551`):**
```cpp
if (!EQ::ValueWithin(spell_id, 3, EQ::spells::DynamicLookup(ClientVersion(), GetGM())->SpellIdMax) && spell_id != UINT32_MAX)
    return;  // server won't send OP_MemorizeSpell for IDs > 9999
```

**CORRECTION (added 2026-05-03 same-day, after architect re-audit):** The "3 gaps" finding below is INCORRECT. A live DB audit by the architect (run as `SELECT id FROM spells_new WHERE id BETWEEN 1 AND 9999 ORDER BY id` then set-difference against [1, 9999]) found **16 unused IDs**: `1, 2, 1348, 5093, 9412, 9413, 9414, 9415, 9416, 9417, 9418, 9419, 9420, 9421, 9422, 9423`. Excluding IDs 1 and 2 (conventionally reserved as sentinel values), there are **14 unambiguously usable IDs**. We need 12. **No reclamation is required.** The original audit below missed the contiguous unused block at 9412–9423. The user caught this discrepancy and the architecture was amended same-day to drop the reclamation step. The architecture now assigns the 12 new spells to IDs `1348, 5093, 9412–9421` with `9422` and `9423` as future headroom. Credit to the user for catching the undercount: their challenge ("why does this have to be a lossy operation? these are net new spells") prompted the re-audit. Lesson for future protocol research: when reporting "N free IDs in a range", always run the actual set-difference query against the live DB rather than sampling gaps in the dense midrange — set-difference is O(rows) and definitive, sampling can miss contiguous unused blocks at range edges.

---

**Original (incorrect) verdict, preserved for the audit trail:**

**VERDICT — BLOCKING CONSTRAINT:** The 12 new spell IDs must be ≤ 9,999. With only 3 gaps available in that range and 12 spells needed, there is **insufficient headroom** in the current sub-9,999 ID space. The data-expert must resolve this before spell IDs can be assigned. Options:
1. Identify and reclaim IDs from `spells_new` rows that are not in use by any character or item (spells assigned to no character in `character_spells`, no scroll in `items.scroll_effect`), then delete those rows to open slots.
2. Or use IDs > 9,999 and accept that the Titanium client cannot see them. This would mean the feature is **not deliverable as designed** for the Titanium client.

The spellbook slot count (400) is not a concern — existing characters are unlikely to have 400+ spells scribed, and the 12 new spells will occupy 12 of those 400 slots.

---

### Q2: Auto-Scribe Migration Delivery

**How the spellbook reaches the Titanium client:**

1. At login/zone-in, `LoadCharacterSpellBook` reads all `character_spells` rows for the character into `m_pp.spell_book[]` (zonedb.cpp:597–627).
2. `OP_PlayerProfile` is sent to the client containing the full `spell_book[400]` array (client_packet.cpp:1717–1723).
3. The Titanium translation layer copies spells with IDs ≤ 9,999 into the wire format; IDs > 9,999 become 0xFFFFFFFF.
4. The client renders the spellbook from this payload — **no additional opcode push is needed**.

**VERDICT — NO SPECIAL OPCODE NEEDED:** A SQL migration that inserts rows into `character_spells` is sufficient. On the player's next login (or zone-in after a `#reloadcharacter` equivalent), `LoadCharacterSpellBook` will pick up the new rows and they will appear in the spellbook. There is no need for an online/live push packet; the auto-scribe only needs to happen before the player next logs in.

**Sequencing requirement:** The `spells_new` rows must exist before the migration runs over `character_spells` (the data-expert already noted this in the PRD; confirmed here as a protocol-level hard dependency — `IsValidSpell()` is called during LoadCharacterSpellBook and invalid spell IDs are skipped).

---

### Q3: Scroll Handoff — Class-Gated Scribe Quirks

**Server-side class validation (`client_process.cpp:1212–1219`):**
```cpp
if (item && RuleB(Character, RestrictSpellScribing) && !item->IsEquipable(GetRace(), GetClass())) {
    MessageString(Chat::Red, CANNOT_USE_ITEM);
    break;
}
```

`RestrictSpellScribing` is a rule that gates whether the item's `classes` bitmask is enforced during scribing. If it's disabled (false), any class can scribe any scroll — but the spell level check still applies separately.

**Additional class check at memorize level (`client_process.cpp:1189–1203`):**
```cpp
if (m->scribing != memSpellForget && (!IsPlayerClass(GetClass()) || GetLevel() < spells[m->spell_id].classes[GetClass() - 1])) {
    // SPELL_LEVEL_TO_LOW message
    return;
}
```

This checks that the player's class can learn the spell (level < 255 = usable). For our spells each will have only its own class set to level 1 (all others at 255). A wrong-class player attempting to scribe the scroll would fail this check.

**Titanium client-side filtering:** The Titanium client filters merchant inventory by the item's `classes` bitmask before display. A scroll with only Wizard's class bit set will not appear in the merchant window for a Cleric. This prevents cross-class purchase attempts at the client layer before the server is even involved.

**VERDICT — NO PROTOCOL QUIRK:** The server's class enforcement is reliable. If `RestrictSpellScribing` is enabled (recommended), the `classes` bitmask on the scroll item is the authoritative gate. No Titanium-specific weirdness exists in this path. Each scroll should have only the correct class bit set.

---

### Q4: Bard Spell-Gem Routing

**This is the most complex protocol question. Full analysis follows.**

**`IsBardSong` definition (`spdat.cpp:855–871`):**
```cpp
bool IsBardSong(uint16 spell_id) {
    return spell.classes[Class::Bard - 1] < UINT8_MAX && !spell.is_discipline;
}
```

Any spell scribable by a Bard (classes[Bard] != 255) and not a discipline is classified as a "bard song." This includes the new "Dirge of Homecoming" spell if it has Bard at level 1.

**Runtime consequence (`spells.cpp:1472–1498`):**
```cpp
if (GetClass() == Class::Bard) {
    if (IsBardSong(spell_id) && slot < CastingSlot::MaxGems) {
        // bard_song_mode = true (if not pulsing)
    }
}
```

**`IsPulsingBardSong` check (`spdat.cpp:2376–2384`):**
```cpp
bool IsPulsingBardSong(uint16 spell_id) {
    if (spell.recast_time > 0 || ...) return false;
    return true;
}
```

Because the new spell will have `recast_time = 180000` (180s cooldown), `IsPulsingBardSong` returns **false**. Therefore `bardsong` is never set, the song-loop does not start. The `bard_song_mode` flag is still set to true (line 1495), which means:

1. The Bard is allowed to move during the cast (correct — Bards can always move)
2. After cast completes, `CheckSongSkillIncrease` is called instead of `CheckIncreaseSkill`
3. `SendSpellBarEnable` is NOT called (only called in the non-bard_song_mode branch)
4. `MemorizeSpell(slot, spell_id, memSpellSpellbar, ...)` IS called from both branches

**Spellbook scribing:** The Bard scribes the spell from the spellbook exactly like any other class — via `OPMemorizeSpell` → `ScribeSpell`. There is no song-window distinction at the scribing stage. Songs and spells are stored identically in `character_spells` / `m_pp.spell_book[]`.

**Memorization:** The Bard memorizes into a normal spell-gem slot (CastingSlot::Gem1–Gem9). There is no separate song-window memory slot — songs and spells share the same 9 gem slots on the Titanium client.

**VERDICT — FUNCTIONAL BUT WITH ONE BEHAVIORAL DIFFERENCE:**

The Bard's "Dirge of Homecoming" will behave like a bard song in one respect: `SendSpellBarEnable` is not called after a successful cast (see spells.cpp:1818). This means after the Bard casts the spell, the spell bar may not immediately re-enable for non-song casting. However, since `MemorizeSpell(memSpellSpellbar, ...)` IS sent (line 1804), the gem re-display with the 3-minute cooldown timer still fires.

**Recommendation for data-expert:** To avoid `IsBardSong` returning true, the Bard-class spell can be given `is_discipline = 1` — but that changes its slot type to the discipline window, which is wrong. The cleaner approach is to accept the bard_song_mode behavior as a minor quirk: the Bard's version of the spell functions correctly (casts, summons corpse, enters cooldown) but the spell bar re-enable packet is skipped. The Bard can still cast other spells normally after.

**Alternative if the behavior is unacceptable:** Set the Bard class level in the new spell to 255 (non-scribable), and instead use an existing approach for utility spells. However, this would mean Bards don't get the spell at all, which conflicts with the PRD. The architect should decide whether the minor bard_song_mode behavioral difference is acceptable.

---

### Q5: PvP / Zone-Restriction Broadcast — Client Hint

**Server-side only:** The same-zone restriction (corpse and caster must be in the same zone) is enforced entirely server-side. The spell engine applies it at the point the summon-corpse effect is evaluated. There is no client-side hint available for "grey out the spell button if conditions aren't met" in the Titanium client.

**Cooldown display:** When the 3-minute cooldown is active, the spell gem displays a greying animation triggered by the `OP_MemorizeSpell` packet with `scribing = memSpellSpellbar` and the `reduction` field. However, the Titanium ENCODE for `OP_MemorizeSpell` does NOT forward the `reduction` field (titanium.cpp:1267–1275 — the `OUT(reduction)` call is absent). The gem will grey out for the recast period but using the spell data's base `recast_time` from the client's local spell cache, not the server-specified `reduction` value.

**VERDICT — SERVER-SIDE FAILURE MESSAGE IS SUFFICIENT:** No client protocol change is needed to communicate the zone-restriction. When the spell is cast with no qualifying corpse, the server sends a text message ("You have no corpse in this zone.") via the normal messaging path. The Titanium client has no mechanism to grey out a spell button based on zone conditions, and we should not attempt to use one. The cast-and-fail-with-message pattern is consistent with how the existing Necromancer Summon Corpse works.

**Cooldown enforcement summary:**
- Server enforces via `pTimerSpellStart + spell_id` timer (`GetPTimers()`)
- `OP_LinkedReuse` is NOT mapped in `titanium_ops.h` — the opcode is unknown to Titanium
- The Titanium client's gem greying is driven by local recast data from its spell cache, not server push
- Server will block premature recasts with `SPELL_RECAST` message regardless of client state

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Protocol findings summary | Spell ID blocking constraint, Bard routing advisory |

### Feedback Received

_(pending architect response)_

### Consensus Plan

_(to be filled after architect review)_

---

## Stage 4: Build

Not applicable — this is a research-only task. No files are created or modified by the protocol-agent.

---

## Open Items

- [x] **RESOLVED 2026-05-03 same-day — finding was incorrect; see Q1 CORRECTION above.** Live DB audit by architect found 14 unambiguously usable IDs in [1, 9999] (not 3). 12 needed; no reclamation required. Architecture amended; spell IDs assigned to `1348, 5093, 9412–9421`.
- [ ] **Advisory: Bard bard_song_mode quirk.** Architect to decide whether the missing `SendSpellBarEnable` after Bard cast is acceptable. It does not prevent the spell from working but may cause a minor visual inconsistency in spell bar re-enable timing.
- [ ] Architect confirm: is the `OP_LinkedReuse` silence for Titanium a known/acceptable pattern for other cooldown spells on this server?

---

## Context for Next Agent

If another agent needs protocol context:

1. **Titanium spell ID hard limit is 9,999.** Spells > 9,999 are silently dropped from the spellbook wire format and from `OP_MemorizeSpell`. This is enforced in `titanium.cpp` and `client.cpp:3543`. The DB has 14 unambiguously usable IDs in the sub-9,999 range (per architect's same-day re-audit — see Q1 CORRECTION above). The earlier "3 gaps" claim was an undercount that missed the contiguous block at 9412–9423; do not propagate that figure.

2. **Auto-scribe works via DB only.** Inserting rows into `character_spells` is sufficient. No live push is needed; spells appear on next login via `OP_PlayerProfile`.

3. **Bard spell becomes a "bard song" at runtime.** Any spell with Bard class < 255 in `spells_new` triggers `IsBardSong()`. With a non-zero `recast_time`, `IsPulsingBardSong()` returns false so the song-loop doesn't start. The spell casts correctly but skips `SendSpellBarEnable` in the post-cast path. The 3-minute cooldown gem-grey still fires.

4. **Cooldown is server-enforced only for Titanium.** `OP_LinkedReuse` (timer_id path) is unmapped in `titanium_ops.h`. Cooldown enforcement is exclusively via `pTimerSpellStart + spell_id` server timer. Client gem-greying is driven by the spell's `recast_time` field in the client's local spell cache.

5. **Class-gated scroll scribing is reliable.** Server enforces via item `classes` bitmask (when `RestrictSpellScribing` rule is on) and via spell `classes[GetClass()-1] < 255` level check. Titanium client filters merchant inventory by classes bitmask client-side.
