# Lore Deep Dive: Data Extraction Summary

This directory contains structured lore data extracted from the PEQ database and quest scripts for use in building a comprehensive NPC lore bible.

## Files in This Directory

| File | Contents |
|---|---|
| `01-zone-overview.md` | All Classic-Luclin zones with NPC counts, level ranges, and zone connections map |
| `02-faction-system.md` | Faction mechanics explained + major city faction profiles with quest dialog |
| `03-zone-npc-census.md` | Per-zone NPC population summaries, grouped by faction |
| `04-quest-dialog-samples.md` | Representative NPC dialog from 6 major cities, sampled from quest scripts |
| `05-faction-relationship-matrix.md` | Concrete faction hit data, racial/deity modifiers, cross-city relationships |

## Raw Data Files (in `/mnt/d/Dev/EQ/claude/tmp/lore-deep-dive/`)

| File | Contents | Rows |
|---|---|---|
| `all_factions.tsv` | Complete faction list (id, name, base) | 2,106 |
| `city_npcs_raw.tsv` | City NPC roster with race/class/level/faction | ~2,600 |
| `city_npcs_detailed.tsv` | Extended city NPC data including quest/merchant flags | ~2,600+ |
| `city_faction_mods.tsv` | City faction racial/class/deity modifiers | partial |

## What Was Extracted

### 1. Zone Census
- **113 Classic-Luclin zones** catalogued with NPC counts, level ranges, racial variety, faction counts
- Zone-to-zone connections mapped as a readable graph
- Expansion grouping (Classic 0, Kunark 1, Velious 2, Luclin 3)

### 2. Faction Data
- **2,105 total factions** in the database
- Major city factions profiled with IDs, base standing, and relationships
- Racial starting modifiers for key factions (r# codes decoded)
- Deity modifiers mapped to deity names (d# codes decoded)
- NPC faction kill chains showing what killing one NPC does to related factions

### 3. NPC Populations
- Top 60+ factions by NPC count in Classic-Luclin zones
- City-by-city NPC breakdown with race/class distribution
- Hostile creature presence near each major city documented
- Dungeon-by-dungeon summary with primary faction/theme

### 4. Quest Dialog
Sampled from 6 cities (3-5 scripts each):
- **Freeport**: Captain Hazran, Cain Darkmoore, Guard Alayle — political intrigue dialog
- **Qeynos**: Dranom Ghenson, Guard Deregan, Faldor Hendrys — civic life dialog
- **Halas**: Cappi McTarnigal (White Rose rogues) — clan/criminal dialog
- **Neriak**: Guard Lumpin, High Priestess Alexandria, Lokar To-Biath — Innoruuk devotion dialog
- **Cabilis**: Harbinger Glosk, Master Kyvix — Iksar militarism/necromancy dialog
- **Katta Castellum**: Autarkic Lord Sfarosh — Luclin mystery/vampire dialog
- **Shadow Haven**: Adept Arnthus — neutral hub dialog

### 5. Key Lore Findings

**The Freeport Civil War**: Three guilds (Militia, Knights of Truth, Steel Warriors) are in active political conflict. Faction system mechanically encodes their alliances. An undercover agent (Guard Alayle) creates narrative depth.

**Neriak's Theology**: Innoruuk worship is not just flavor — NPCs explicitly command players to kill clergy of Rodcet Nife (healing god). The theological conflict is mechanically real.

**Iksar Hierarchical Society**: Cabilis uses rank titles (apprentice → dark binder → occultist → revenant) instead of names. NPCs only address characters by rank. Guild and military are mutually reinforcing.

**The Qeynos Underground**: Circle of Unseen Hands (thieves' guild) and Corrupt Qeynos Guards exist in tension with legitimate Qeynos. Killing city guards benefits criminals.

**Velious Three-Way War**: Coldain + Dragons vs. Giants. Hard faction choices.

**Luclin Political Complexity**: Katta Castellum vs. Sanctus Seru represents an ancient ideological split (Combine Empire loyalists vs. Seru loyalists). The Eye of Seru faction appears in BOTH cities — suggesting ongoing espionage.

**Froglok Evolution**: Two distinct froglok factions (Frogloks of Guk = Classic, Frogloks of Kunark = Kunark). Different species, both have undead counterparts in their dungeons.

## Scope Notes

- Zone data includes only `version = 0` (default zone versions)
- Expansion filter: `expansion BETWEEN 0 AND 3` (Classic through Luclin)
- Quest scripts sampled from ~20 NPCs across 9 zones
- Faction_list_mod uses short codes (r# = race, c# = class, d# = deity) decoded where possible

## Database Access for Follow-up Queries

```
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq
```

Key query patterns:
```sql
-- Lookup all NPCs in a zone
SELECT nt.name, nt.race, nt.class, nt.level, fl.name AS faction
FROM spawn2 s2
JOIN spawnentry se ON s2.spawngroupID = se.spawngroupID
JOIN npc_types nt ON se.npcID = nt.id
LEFT JOIN npc_faction nf ON nt.npc_faction_id = nf.id
LEFT JOIN faction_list fl ON nf.primaryfaction = fl.id
WHERE s2.zone = 'zoneshortname'
ORDER BY nt.level;

-- Lookup faction relationships
SELECT fl2.name AS faction_affected, nfe.value AS hit_amount
FROM npc_faction nf
JOIN npc_faction_entries nfe ON nf.id = nfe.npc_faction_id
JOIN faction_list fl2 ON nfe.faction_id = fl2.id
WHERE nf.id = <npc_faction_id>;
```
