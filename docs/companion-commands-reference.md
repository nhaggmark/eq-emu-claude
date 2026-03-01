# Companion Commands Reference

> **Last updated:** 2026-02-28
> **System:** Recruit-Any-NPC Companion System

---

## Player Commands (Chat-Based)

All commands are spoken to an NPC via `/say`. Recruitment commands target
non-companion NPCs. Management commands target your active companion.

### Recruitment

| Command | Effect |
|---------|--------|
| `recruit` | Attempt to recruit the targeted NPC |
| `join me` | " |
| `come with me` | " |
| `travel with me` | " |
| `adventure with me` | " |
| `will you join` | " |
| `join my party` | " |
| `join my group` | " |
| `come along` | " |
| `follow me` | " |

**Handler:** `companion.lua:attempt_recruitment()` via `global_npc.lua`

### Dismissal

| Command | Effect |
|---------|--------|
| `dismiss` | Dismiss companion (suspended, re-recruitable with +10% bonus) |
| `leave` | " |
| `goodbye` | " |
| `farewell` | " |
| `release` | " |

**Handler:** `companion.lua:handle_command()` → `Companion::Dismiss()`

### Stance

| Command | Stance | Behavior |
|---------|--------|----------|
| `passive` | PASSIVE (0) | Disengages from combat, follows owner |
| `balanced` | BALANCED (1) | Default; fights alongside player |
| `stance` | BALANCED (1) | Alias for balanced |
| `aggressive` | AGGRESSIVE (2) | Actively pursues and attacks enemies |

**Handler:** `companion.lua:handle_command()` → `Companion::SetStance()`

### Movement

| Command | Mode | Behavior |
|---------|------|----------|
| `follow` | FOLLOW | Trails owner at 100-unit distance |
| `guard` | GUARD | Holds current position |
| `stay` | GUARD | Alias for guard |

**Handler:** `companion.lua:handle_command()` → `lua_companion.cpp:SetGuardMode()`

### Equipment

| Command | Effect |
|---------|--------|
| `show equipment` | Display all equipped items with slot names |
| `show gear` | Alias for show equipment |
| `inventory` | Alias for show equipment |
| `give me your <slot>` | Return item from specific slot to player |
| `give me everything` | Return all equipped items to player |

**Valid slot names:** charm, ear1, head, face, ear2, neck, shoulder, arms,
back, wrist1, wrist2, range, hands, primary, secondary, finger1, finger2,
chest, legs, feet, waist, ammo

**Handler:** `companion.lua:handle_command()` → `Companion::ShowEquipment()` /
`GiveSlot()` / `GiveAll()`

---

## Implementation Files

| File | Role |
|------|------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Recruitment + management command routing |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | Culture dialogue templates for LLM |
| `akk-stack/server/quests/global/global_npc.lua` | Event hook — intercepts player say events |
| `eqemu/zone/companion.cpp` | Core companion class (~1835 lines) |
| `eqemu/zone/companion.h` | Companion class definition |
| `eqemu/zone/companion_ai.cpp` | Class-specific spell AI (16 classes) |
| `eqemu/zone/lua_companion.cpp` | Lua API bindings (14 methods) |

---

## Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| COMPANION_STANCE_PASSIVE | 0 | No combat |
| COMPANION_STANCE_BALANCED | 1 | Default combat |
| COMPANION_STANCE_AGGRESSIVE | 2 | Aggressive combat |
| COMPANION_TYPE_COMPANION | 0 | Loyal companion |
| COMPANION_TYPE_MERCENARY | 1 | Faction-dependent hire |
