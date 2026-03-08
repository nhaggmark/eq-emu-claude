# Design Notes — Companion AI Stances

## Key Design Decisions

### 1. Passive suppresses ALL actions (including beneficial spells)
Passive means truly inert. The companion doesn't self-heal, doesn't buff,
doesn't do anything. This is the strongest possible interpretation of
"passive" and gives the player the most control. If players want a companion
that heals itself but doesn't attack, that's a future "defensive" stance.

### 2. Flee behavior is retained
Companions keep their NPC flee behavior because it adds personality. A
warrior companion won't flee, but a wizard might. This creates emergent
tactical considerations. Made it toggleable via rule value suggestion in
case it proves frustrating.

### 3. Aggressive scans for player-hostile targets, not companion-original-hostile
Critical distinction: a recruited Qeynos guard in Aggressive stance attacks
what's hostile to the PLAYER, not what was hostile to Qeynos. The companion
adopts the player's faction perspective on recruitment.

### 4. No artificial delay on stance transitions
Stance changes are immediate (next AI tick). Considered adding a "transition
time" (e.g., 1-second delay to feel more realistic) but rejected it — in
emergency situations (switching to Passive to stop a bad pull), even 1 second
matters for a small group's survival.

### 5. Balanced = reactive only, no seeking
Balanced companions don't actively seek combat. They only respond when the
group is attacked. This is important for dungeon gameplay where accidental
pulls are deadly for small groups. The player controls engagement pace.

## Research Sources

- `companion.lua` — existing stance commands (cmd_passive, cmd_balanced,
  cmd_aggressive) already call SetStance(). Lua side appears complete.
- `companion-commands-reference.md` — full command catalog, confirmed stance
  constants (0=passive, 1=balanced, 2=aggressive)
- `C-CODE.md` topography — NPC AI subsystem (Process(), AI_Process(), aggro.cpp,
  hate_list.cpp), entity hierarchy (Companion → NPC → Mob)
- `companion_data` table has a `stance` column (seen in check_dismissed_record
  SELECT query) — persistence infrastructure likely exists

## Open Questions for Architect
See PRD Open Questions section. The biggest unknown is how deeply the merc AI
system's stance handling can be reused vs. needing companion-specific logic.
