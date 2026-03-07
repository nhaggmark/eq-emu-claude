# Companion Experience System — Research Notes

## Existing Companion Infrastructure (from codebase review)

### C++ Classes
- `Companion` inherits from `NPC` (zone/companion.h, zone/companion.cpp)
- Has full XP/leveling infrastructure already:
  - `m_companion_xp` (uint32) — accumulated XP
  - `AddExperience(uint32 xp)` — adds XP and checks for level-up
  - `CheckForLevelUp()` — checks against threshold, triggers scaling
  - `GetXPForNextLevel()` — formula: `level * level * 1000`
  - `ScaleStatsToLevel(uint8)` — proportional stat scaling
- Has class-specific AI for all 15 Classic-Luclin classes
- Has stances: Passive, Balanced, Aggressive
- Has persistence: Save/Load to companion_data table
- Has equipment system, buff save/restore, history tracking

### Existing Rules (common/ruletypes.h, lines 1181-1203)
- `Companions::XPContribute` (bool, default true) — count in group split
- `Companions::XPSharePct` (int, default 50) — % of share to companion
- `Companions::MaxLevelOffset` (int, default 1) — cap = player_level - this
- Plus ~15 other rules for recruitment, death, retention, etc.

### BUG-001 Root Cause Analysis
- `NPC::Death()` in attack.cpp determines kill credit at line 2614
- `give_exp = hate_list.GetDamageTopOnHateList(this)` — gets top damage dealer
- Lines 2620-2640: Owner resolution chain handles pets and bots
- Lines 2653-2655: `give_exp_client` set only if `give_exp->IsClient()`
- **Bug:** Companion is not a Client, not a Pet (no HasOwner()), and not
  specially handled → give_exp_client = nullptr → no XP distributed
- Fix needs companion to resolve through ownership chain to owner client

### Group XP Split (exp.cpp)
- `Group::SplitExp()` at line 1123 already has companion-aware code
- Lines 1188-1194: Iterates companions to call `RecordKill()`
- Comment says "XP share to companions handled by AddExperience() called
  from client.cpp on kill" — but this wiring appears incomplete

### EQ XP Mechanics (from research)
- Group bonus: 2% per additional member (Classic era)
- XP split based on proportional accumulated XP
- Con system: gray = 0%, green = 25%, light blue = 50%, blue+ = full
- ZEM (Zone Experience Modifier): base 75, dungeons 80+
- Hell levels exist at certain progression points
