# Companion Equipment Management Enhancement — Agent Conversations Log

> **Feature branch:** `feature/companion-equipment`
> **Created:** 2026-03-07

This file preserves cross-agent communication for context durability. When
context windows compact, this log ensures decisions, coordination, and
rationale are never lost.

**Every agent on a team MUST log their SendMessage exchanges here.**

**Rules:**
1. Log ALL exchanges, including "no concerns" / "no constraints" responses
2. Log the date, sender, recipient, content summary, and outcome
3. An empty section for a team phase means the team process was skipped
4. "APPROVED — no issues" is a valid and valuable finding; it must be logged
5. This file is the audit trail that proves peer review actually happened

---

## Design Team Conversations

_game-designer + lore-master exchanges during Phase 2._

### 2026-03-07 — Initial Lore Check: Companion Equipment Feature Scope

**From:** game-designer → **To:** lore-master

> Flagged the feature scope for lore awareness: per-slot equipment storage
> (19 slots), trade window behavior, !equipment display, slot-aware commands,
> equipment persistence through death/dismissal, and combat stat integration.
> Noted this is primarily a mechanics/systems feature with minimal lore
> implications — no new NPCs, zones, quests, or faction changes. Asked if
> lore-master sees any concerns.

**Response from** lore-master:

> APPROVED with one recommendation. No hard stops. Key points:
> - Trade interaction: Has EQ precedent (merchants, quest turn-ins). No issue.
> - Equipment persistence through death: The RIGHT call. Companions are recruited
>   real Norrathians, not summoned constructs. Persistent gear is consistent.
> - Combat stats from equipment: Fully consistent. Full 19-slot parity makes
>   companions behave like actual EQ characters.
> - RECOMMENDATION: Class/race equipment restrictions should be enforced.
>   Silently letting a Magician equip plate armor would be lore-breaking.
>   Items have race/class flags in EQ; companions should respect them.

**Outcome:** PRD updated to incorporate lore-master feedback:
- Added Goal #7: Class/race equipment validation
- Changed Non-Goal from "no class/race restrictions" to "advanced restriction
  edge cases out of scope" (basic class/race enforcement is now in scope)
- Added class/race check to Slot Resolution mechanics
- Added Open Question #8 for architect re: NPC class/race bitmask mapping
- Added two acceptance criteria for class/race restriction enforcement

### 2026-03-07 — Full PRD Lore Review (Revised with Class/Race Restrictions)

**From:** game-designer → **To:** lore-master

> Sent revised PRD incorporating lore-master feedback on class/race restrictions.
> Requested final sign-off before architect handoff.

**Response from** lore-master:

> APPROVED. Task #2 (Lore review) marked completed by lore-master.
> Class/race restriction feedback incorporated successfully.

**Outcome:** Lore sign-off recorded. PRD ready for architect handoff.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-07 — Protocol Research Complete: Companion Equipment

**From:** protocol-agent → **To:** architect

> Task #2 complete. Key findings:
>
> 1. **No new opcodes needed.** All required protocol exists: OP_WearChange
>    for visual updates, existing trade opcodes for the equip flow.
>
> 2. **9 visual slots, 22 storable slots.** Titanium's TextureProfile has
>    materialCount=9 (Head, Chest, Arms, Wrist, Hands, Legs, Feet, Primary,
>    Secondary). The other 13 equipment slots (Charm, Ear1, Face, Ear2, Neck,
>    Shoulders, Back, Wrist2, Range, Finger1, Finger2, Waist, Ammo) are
>    stored and affect stats but generate no WearChange packet.
>
> 3. **Wrist2 has no visual.** slotWrist2 (ID=10) returns materialInvalid
>    from CalcMaterialFromSlot(). Both wrists store items, only Wrist1 shows
>    visual change. Existing EQEmu behavior — not a bug to fix here.
>
> 4. **Companion trade bypass is critical.** trading.cpp:652 — the
>    `if (tradingWith->IsCompanion())` block skips standard NPC item-return
>    logic after EVENT_TRADE fires. The Lua handler owns all return logic.
>    New slot-handling code must live in Lua, not C++ trade completion.
>
> 5. **The protocol layer is already complete.** companion.cpp:1171-1263
>    already implements GiveItem, RemoveItemFromSlot, LoadEquipment,
>    SaveEquipment, SendWearChange with correct OP_WearChange dispatch.
>    Work remaining is in Lua, not protocol.
>
> 6. **Trade window takes 4 items max.** TRADE_NPC_SIZE=4 — player can
>    trade up to 4 items at once to a companion.
>
> 7. **No server-to-server protocol impact.** Companion equipment is
>    zone-local. No ServerOP_* codes need changes.
>
> Full details in protocol-agent/dev-notes.md.

**Outcome:** Findings delivered to architect. Task #2 marked Complete.

### 2026-03-07 — Architect Protocol Review: Five Specific Questions

**From:** architect → **To:** protocol-agent

> Five questions: (1) Does OP_WearChange work for NPC entities? (2) Trade window
> constraints? (3) Any packet concerns for chat-based !equipment display? (4) Is
> the item Slots bitmask version-agnostic? (5) Any other client-side constraints?

**Response from** protocol-agent:

> All five confirmed or flagged:
> 1. OP_WearChange works for NPC spawns — packet carries spawn_id only, no
>    entity-type field. 9 visual material slots; Wrist2 has no visual (materialInvalid).
> 2. Trade cap = 4 items (TRADE_NPC_SIZE=4). Money offered alongside items is
>    silently consumed by the companion bypass — Lua handler should check and
>    return currency. No other trade quirks.
> 3. client:Message() → OP_ChannelMessage — fully Titanium-supported, no concerns.
> 4. Slots bitmask is server-side and version-agnostic. item:Slots() returns raw
>    DB value; no Titanium translation needed.
> 5. Two extra flags: (a) InspectResponse supports 22 slots in Titanium (not
>    relevant for chat-based display). (b) C++ equipment range is 22 slots (0–21
>    including Charm/Ear1/Ear2); PRD's 19-slot list omits those three — Lua
>    display just needs to match PRD scope.

**Outcome:** Architect's assessment confirmed — no new opcodes, structs, or
client modifications needed. 4-item trade cap and 9-slot visual limitation
noted as design constraints.

### 2026-03-07 — Architect Consultation: Config-Expert Questions

**From:** architect → **To:** config-expert

> Five questions for config-expert assessment:
> 1. Should class/race restriction enforcement be toggleable via rules?
> 2. Any existing rules related to NPC equipment or companion trading?
> 3. Should equipment persistence through death be toggleable?
> 4. Any existing Companions category rules that relate to equipment?
> 5. What rule values would the architect need for this feature?

**Response from** config-expert:

> Complete assessment delivered in `config-expert/dev-notes.md`. Key findings:
>
> 1. **No existing equipment rules** in the Companions category (24 rules checked,
>    none equipment-related).
> 2. **Bot system analog found:** `Bots:AllowBotEquipAnyClassGear` and
>    `Bots:AllowBotEquipAnyRaceGear` provide exact naming/behavior precedent.
> 3. **Three new rules recommended:**
>    - `Companions:EnforceClassRestrictions` (bool, default true)
>    - `Companions:EnforceRaceRestrictions` (bool, default true)
>    - `Companions:EquipmentPersistsThroughDeath` (bool, default true)
> 4. **One PRD suggestion rejected:** `EquipmentPersistsThroughDismissal` NOT
>    recommended as a separate rule — dismissal persistence is handled by the
>    companion identity/DB persistence system (`DismissedRetentionDays` already
>    governs this).
> 5. **Config-first verdict:** Feature CANNOT be achieved through config alone.
>    All equipment features require C++ and/or Lua changes. Rules gate behavior,
>    not replace code.

**Outcome:** Architect accepted all three recommended rules. Config-expert's
recommendation to NOT add `EquipmentPersistsThroughDismissal` accepted — avoids
confusing interaction with `DismissedRetentionDays`. Separate class/race toggles
accepted (allows independent control per Bot system precedent).

### 2026-03-07 — Architect Protocol Follow-up: Five Specific Questions

**From:** architect → **To:** protocol-agent

> Five specific verification questions:
> 1. Does OP_WearChange work for NPC entities (not just players)?
> 2. Any trade window constraints beyond the 4-item limit?
> 3. Any packet concerns for chat-based !equipment display?
> 4. Is the item Slots bitmask version-agnostic across clients?
> 5. Any other client-side constraints the architect should know?

**Response from** protocol-agent:

> All five confirmed:
> 1. OP_WearChange works for NPC spawns — packet uses spawn_id only, no
>    entity-type field. 9 visual material slots; Wrist2 = materialInvalid.
> 2. Trade cap = 4 items (TRADE_NPC_SIZE=4). Money alongside items is silently
>    consumed by companion bypass — Lua should check and return currency.
> 3. client:Message() → OP_ChannelMessage — fully Titanium-supported, no concern.
> 4. Slots bitmask is server-side, version-agnostic. item:Slots() returns raw DB
>    value. No Titanium translation needed.
> 5. Two additional notes: (a) InspectResponse supports 22 slots (not relevant
>    for chat-based display). (b) C++ equipment range is 22 slots (0–21);
>    PRD's 19-slot list omits Charm/Ear1/Ear2 — cosmetic decision, not protocol.

**Outcome:** All protocol concerns resolved. Money-in-trade flag added to
architecture plan as Task 9. 22-slot vs 19-slot discrepancy noted as PRD design
choice (display 19, store 22).
---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Equipment persists through companion death — no corpse/loot drop | game-designer, lore-master | 2026-03-07 | Lore-master confirmed companions are recruited Norrathians, not summoned constructs. Persistent gear is thematically correct. |
| 2 | Basic class/race restrictions enforced; advanced restrictions (deity, expansion, level) deferred | game-designer, lore-master | 2026-03-07 | Lore-master flagged that unrestricted equipment would be lore-breaking. PRD revised to add Goal #7 and acceptance criteria. |
| 3 | Populate m_inv InventoryProfile with ItemInstance objects (bot system pattern) to fix combat stat integration | architect, protocol-agent, config-expert | 2026-03-07 | CalcItemBonuses reads from m_inv which companions never populate. Bot system proves m_inv.PutItem works for non-player entities. |
| 4 | Three separate toggleable rules (class, race, death persistence) instead of one combined rule | architect, config-expert | 2026-03-07 | Follows Bot system precedent of separate class/race toggles. Gives server admins granular control. |
| 5 | No EquipmentPersistsThroughDismissal rule — persistence tied to companion identity/DB system | architect, config-expert | 2026-03-07 | Config-expert recommended against separate rule — dismissal persistence is governed by existing DismissedRetentionDays rule and DB row lifetime. |
| 6 | No new opcodes or protocol changes — all work is C++ engine and Lua script | architect, protocol-agent | 2026-03-07 | Protocol-agent confirmed all required opcodes exist. Companion trade bypass in trading.cpp delegates item handling to Lua. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |

