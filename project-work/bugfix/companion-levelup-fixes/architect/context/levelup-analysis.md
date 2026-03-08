# Companion Level-Up Code Path Analysis

## Complete Call Chain

```
Companion::AddExperience(xp)
  m_companion_xp += xp
  while (CheckForLevelUp()) { leveled = true; }
  if (leveled) { owner->Message("grown stronger... level N") }

Companion::CheckForLevelUp()
  current_level = GetLevel()
  max_level = owner->GetLevel() - MaxLevelOffset (clamped 1-60)
  if (current_level >= max_level) return false
  xp_needed = GetXPForNextLevel()  // level * level * 1000
  if (m_companion_xp < xp_needed) return false
  m_companion_xp -= xp_needed
  new_level = current_level + 1
  ScaleStatsToLevel(new_level)     // <-- see below
  LoadCompanionSpells()            // re-query companion_spell_sets for new level
  SetHP(GetMaxHP())                // full heal
  SetMana(GetMaxMana())            // full mana
  Save()                           // persist to companion_data table
  return true

Companion::ScaleStatsToLevel(current_level)
  scale = (float)current_level / (float)m_recruited_level
  SetLevel(current_level)          // <-- calls NPC::SetLevel (see below)
  STR = (int32)(m_base_str * scale)
  STA = (int32)(m_base_sta * scale)
  // ... all stats ...
  max_hp = (int64)(m_base_hp * scale)
  base_hp = max_hp
  max_mana = (int64)(m_base_mana * scale)
  CalcBonuses()                    // recalc max HP/mana/AC from base + bonuses

NPC::SetLevel(in_level, command=false)
  if (in_level > level)
    SendLevelAppearance()          // OP_LevelAppearance to nearby clients (ding visual)
  level = in_level
  SendAppearancePacket(AppearanceType::WhoLevel, in_level)
    // BUG: default params whole_zone=false, target=nullptr
    // Since companion is not a client, this packet is NEVER sent
```

## Bugs Found

### BUG A: WhoLevel appearance packet never broadcast
NPC::SetLevel() calls SendAppearancePacket(WhoLevel, level) with default
args (whole_zone=false). Since the companion is not a Client, the packet
never reaches any client. The client's group window never learns the
companion's new level.

### BUG B: SendHPUpdate() never called
After level-up, the companion's HP/maxHP change dramatically, but no HP
update packet is sent to group members. The group window HP bar becomes
stale/invalid.

### BUG C: No group update sent
No OP_GroupUpdate is sent to refresh the group window after level-up.
The client's cached group data becomes stale.

## Comparison with Bot Level-Up

Bot level-up (bot.cpp:3990-4018) does ALL of these correctly:
1. CalcBotStats()          -- recalc stats
2. SendLevelAppearance()   -- ding visual
3. SetHP/SetMana           -- heal to full
4. SendHPUpdate()          -- update group HP bars *** MISSING IN COMPANION ***
5. SendAppearancePacket(WhoLevel, level, TRUE, TRUE) -- broadcast level *** WRONG PARAMS IN COMPANION ***
6. AI_AddBotSpells()       -- reload spells

## Comparison with Merc Level-Up

Client::UpdateMercLevel() (merc.cpp:5622):
1. UpdateMercStats()       -- recalc stats
2. SendAppearancePacket(WhoLevel, GetLevel(), TRUE, TRUE) -- broadcast level

