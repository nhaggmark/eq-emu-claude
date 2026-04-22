# Q13 Investigation — Classic-scope NPCs not captured by raid_target=1 with spawnentry

Date: 2026-04-21 (architect phase)
Database: peq (as of now)

## Summary

The game-designer audit joined `npc_types` with `spawnentry`+`spawn2` — this missed every
`raid_target=1` NPC that has no spawnentry row (i.e., is spawned by quest scripts or
triggered by another NPC's death). Audit flagged 10 NPCs via lore-master knowledge;
DB investigation confirms them plus several more Classic-zone triggered bosses.

## Classic-scope Q13 additions (Phase 2 in scope)

### Plane of Fear — triggered / scripted (in scope for Phase 2)

| ID | Name | Level | HP | Damage | Notes |
|----|------|-------|-----|--------|-------|
| 72069 | Ireblind_Imp | 60 | 139,500 | 62-252 | `raid_target=1`, no spawnentry. Triggered PoFear event mob. |
| 72106 | an_enraged_golem | 65 | 175,000 | 210-400 | `raid_target=1`, no spawnentry. **Wizard epic target** spawned by giving broken golem (72074) item. Confirmed from lore-master Q13 flag. |
| 72108 | Enraged_Imp | 60 | 25,000 | 100-440 | `raid_target=1`, no spawnentry. PoFear triggered event mob. |

### Plane of Sky — triggered / mid-tier (in scope for Phase 2)

| ID | Name | Level | HP | Damage | Notes |
|----|------|-------|-----|--------|-------|
| 71034 | Overseer_of_Air | 63 | 32,000 | 260-830 | `raid_target=1`, no spawnentry. Island mid-boss, script-spawned. |
| 71059 | Protector_of_Sky | 55 | 21,400 | 88-316 | `raid_target=1`, no spawnentry. Island 2 sub-boss (spawns when you kill all azaracks). |
| 71060 | the_Hand_of_Veeshan | 63 | 32,000 | 140-900 | `raid_target=1`, no spawnentry. |
| 71071 | an_essence_tamer | 56 | 11,500 | 68-264 | `raid_target=0`, no spawnentry. **Ranger epic Swirling Sphere source.** Uses spell 303 "Whirl till you hurl" — effect 64 (throw), not actually an instant-death despite lore-master description. Audit note: the "death touch" descriptor is wrong; this is a throw that can be survivable. |
| 71072 | Bazzt_Zzzt | 63 | 32,000 | 295-941 | `raid_target=1`, no spawnentry. **Casts Cazic Touch (spell 982, -100,000 HP damage = death-touch).** |
| 71075 | Keeper_of_Souls | 60 | 32,000 | 168-453 | `raid_target=1`, no spawnentry. **Casts Cazic Touch (spell 982).** |
| 71076 | #Sister_of_the_Spire | 63 | 17,000 | 59-192 | `raid_target=1`, no spawnentry. Island 7 farm-able boss per lore-master. |

### Lost Temple (cazicthule) — Avatar / Phantasmal event mobs (in scope)

| ID | Name | Level | HP | Damage | Notes |
|----|------|-------|-----|--------|-------|
| 48211 | #a_boiling_ooze | 58 | 140,750 | 115-381 | triggered event mob |
| 48237 | #Avatar_of_Dread | 60 | 84,000 | 125-425 | |
| 48239 | #Avatar_of_Fright | 60 | 84,000 | 125-425 | |
| 48240 | #Avatar_of_Terror | 60 | 84,000 | 161-446 | |
| 48245-48252 | Spinechill/Gorgon/Shiverback/Amygdalan Knight/Guards/Tentacle Terror | 58-60 | 37k-96k | 100-360 | Phantasmal Overlord retinue / spawned adds; in scope per signature-mechanic-preservation decision |

### Plane of Hate revamp (hateplaneb) — script-spawned Innoruuk + adds (in scope)

| ID | Name | Level | HP | Damage | Notes |
|----|------|-------|-----|--------|-------|
| 186158 | Innoruuk | 70 | 100,200 | 204-822 | `raid_target=1`, no spawnentry. Final Innoruuk spawn is script-triggered. |
| 186191-186198 | Banshees / Evangelist / Accompanist | 60-65 | 60k-200k | 120-1200 | Script-spawned event phase adds |

## Q13 resolution for Phase 2 Classic

The following additional NPC IDs (beyond `raid_target=1` + spawnentry) must be folded into
the Phase 2 scaling SQL:

**Triggered / scripted bosses in Classic zones:**
- 72069 Ireblind Imp (PoFear)
- 72106 an_enraged_golem (PoFear, Wizard epic)
- 72108 Enraged Imp (PoFear)
- 71034 Overseer_of_Air (PoSky)
- 71059 Protector_of_Sky (PoSky)
- 71060 the_Hand_of_Veeshan (PoSky)
- 71071 an_essence_tamer (PoSky, Ranger epic)
- 71072 Bazzt_Zzzt (PoSky — death-touch removal)
- 71075 Keeper_of_Souls (PoSky — death-touch removal)
- 71076 Sister_of_the_Spire (PoSky)
- 186158 Innoruuk (hateplaneb — triggered end-boss)
- 186191-186198 hateplaneb event add bosses (revamp Hate script adds)
- 48211, 48237, 48239, 48240, 48245-48252 cazicthule Avatars + retinue

## NPCs flagged OUT OF SCOPE (other eras, other phases)

- 85208 Xenevorash — **Kunark (Lake of Ill Omen)**, Monk epic. Defer to Phase 3.
- 448200 #Renux_Herkanor, 2033/12032/56172 Renux_Herkanor — Kunark Steamfont quest,
  multiple duplicate IDs. Defer to Phase 3 (Kunark architecture).
- 106008 Vessel_Drozlin — Cabilis East sewers. Kunark. Defer to Phase 3.
- 12172 Thrackin_Griften — W.Karana Enchanter epic. W.Karana is Classic but this is a
  Classic-Kunark epic step; HP 7875 is already in scaled-named range. **Defer unless lore flags.**
- 39069 Caradon, 39155 Kyrenna, 39165 Mummy_of_Glohnor — The Hole, Classic zone but SK
  epic (Kunark-era quest). `raid_target=0`, HP in scaled-named range already. Architect
  recommendation: leave these as-is for Phase 2 since they are not `raid_target=1`.
  Revisit in Phase 3 for SK epic playability.
- 51144/214078 a_tortured_soul — 10-11k HP, `raid_target=0`. Already named-tier.
- 20205 General_V`ghera (Kithicor, Rogue epic) — level 65 boss, 16k HP `raid_target=0`.
  Already named-tier. Defer, not in Phase 2 scaling pass.
- 448200 #Renux_Herkanor — L72, 500k HP, OOE per audit's level-70 cap rule. Out of scope.

## Flagged to user

- The hateplaneb "Evangelist_of_Hate" (186198, L65, 200k HP) is a DZ event boss,
  not standard PoHate. This is in scope as revamp PoHate content.
- The Kithicor "Night Crew" (20054-20064) levels 54-59, HP 12-27k — already in
  scaled-named range. **EXCLUDED per user override 2026-04-22 (Decision #20, Option B).**
  Treat as named-tier; no Phase 2 scaling action. Backup tables still capture them as
  part of the generic raid_target=1 superset (harmless over-capture).
