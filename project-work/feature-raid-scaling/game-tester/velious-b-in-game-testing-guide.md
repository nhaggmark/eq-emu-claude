# Raid Scaling Phase 4b (Velious ToV + Sleeper + Vulak + AoW) — In-Game Testing Guide

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Prerequisite:** Server-side validation is PASS. All DB values confirmed.

---

## Priority Order

Sessions are ordered by validation priority. Run them in this order:

1. **Session 1: Lord Vyemm (ToV)** — CRITICAL MECHANICS TEST. MR=1000 wall must
   still repel magic casters; 90k HP must be tractable. This validates the most
   important signature preservation (Decision #11) and the HP cut magnitude.

2. **Session 2: Aaryonar (ToV)** — Breath cone mechanic. Validates that the
   signature breath attack still functions normally with a tractable HP pool.

3. **Session 3: Sleeper's Tomb — Kildrukaun + Ancients** — Navigate the zone,
   engage Kildrukaun (MR=400, 85k HP). CRITICAL: confirm Ancient death does NOT
   trigger Sleeper Awake chain (Decision #12 live verification).

4. **Session 4: Master of the Guard (Sleeper's Tomb)** — 8-sentry wave encounter
   at 80k HP. Validates MotG signature mechanic is intact and fight is beatable.

5. **Session 5: Defender fight (ToV)** — Q37 override validation. 45k HP, 550
   maxdmg. Confirm tractable with small group.

6. **Session 6: Lendiniara the Keeper (ToV)** — Decision #38 live check: kill
   Lendiniara, then wait ~24h or use `#repop` to confirm 24h respawn.

7. **Session 7: Avatar of War (Kael)** — 120k HP endgame fight. Validate rampage
   6x6 cap (MaxRampageTargets=2 global rule) still fires correctly; no one-shot
   from rampage with 700 maxdmg cap.

8. **Session 8: Vulak`Aerr (ToV apex)** — 150k HP pinnacle fight. Must first clear
   the 6 North Wing altar dragons (or use GM spawn) then confirm Thylex spawns Vulak.

---

## Quick Setup Commands

```
-- Teleport to Temple of Veeshan (safe at Veeshan's Peak entry)
#zone templeveeshan

-- Teleport to Sleeper's Tomb
#zone sleeper

-- Teleport to Kael Drakkel
#zone kael

-- Set invulnerable for safe testing
#invul on / #invul off

-- Spawn NPC at location (use with caution in Sleeper to avoid waking Sleeper)
#spawn [npcid]

-- Get NPC stats on targeted mob
#showstats

-- Repop the current zone
#repop

-- Reload quest scripts (no server restart needed)
#reloadquests

-- Check faction
#faction [factionid] [value]

-- Instantly kill targeted NPC (for respawn timer testing)
#kill
```

---

## Session 1: Lord Vyemm — CRITICAL MR Wall + HP Check

**Priority: HIGHEST. Run this first.**

Lord Vyemm (124017) is the most important Phase 4b validation target. He was cut from
350k HP to 90k HP but his MR=1000 wall must be completely intact — magic casters and
enchanters should find Vyemm completely immune to magic. His maxdmg was cut from 1,200
to 700.

### Prerequisites

- Character level 60+ (ideally with a caster companion to test MR wall)
- Access to templeveeshan (zone directly or via `#zone templeveeshan`)
- If using GM mode: `#invul on` to navigate to Vyemm's wing safely

### Steps

1. Zone to templeveeshan: `#zone templeveeshan`
2. Navigate to Lord Vyemm's spawn point. He is at spawn2 id 25292 in templeveeshan.
   Use `#findnpc Vyemm` to locate him.
3. Check Vyemm's stats with `#showstats`: confirm HP around 90,000, MR around 1,000.
4. Target Vyemm and have a magic-damage caster attempt spells.
   - Expected: ALL magic spells are resisted (MR=1000 is a practical wall — even a
     level 70 caster with maxed spell focus should see near-100% resists).
   - Expected: The NPC says nothing; spells fizzle into "Your target resisted..."
5. Engage Vyemm in melee.
   - Expected: Hits land in the 250-700 damage range (mindmg 250, maxdmg 700).
   - Expected: The fight lasts several minutes with a small group — not a one-shot risk.
   - Expected: At 90k HP the fight is challenging but tractable; a tank + healer can
     sustain it.
6. Kill Vyemm.
   - Expected: Normal death loot drop behavior; no scripted events from Vyemm's death.

**Pass if:** MR=1000 wall functions (near-100% magic resist), melee hits are capped at 700,
HP pool requires genuine group effort but is clearable.

**Fail if:** Vyemm casts or takes spell damage consistently, or swings deal 1,200+ damage
(indicating maxdmg was not applied), or HP is above 100,000 or well above 90,000.

**GM commands for setup:**
```
#zone templeveeshan
#findnpc Vyemm
#invul on       -- move safely
#invul off      -- engage
```

---

## Session 2: Aaryonar — Breath Cone Mechanic

**Priority: HIGH.**

Aaryonar (124010, 95k HP, maxdmg 550) has a signature breath cone mechanic. This
session confirms the mechanic is still active after the HP cut.

### Prerequisites

- Access to templeveeshan
- Stand slightly to the side of Aaryonar when engaging to observe cone angle

### Steps

1. Locate Aaryonar: `#findnpc Aaryonar` in templeveeshan (spawn2 25285).
2. Check stats: `#showstats` — confirm HP ~95,000, maxdmg ~550, MR ~225.
3. Engage Aaryonar.
4. Position yourself directly in front of Aaryonar during the fight.
   - Expected: Breath attack fires periodically as a cone in front of him.
   - Expected: Stepping behind Aaryonar avoids the breath cone (classic positioning
     mechanic).
5. Observe 3-4 full attack rounds.
   - Expected: Melee hits in the 235-550 range.
   - Expected: Breath cone fires, dealing area damage to those in the cone.
6. Kill Aaryonar.

**Pass if:** Breath cone fires during combat (visible as AE damage hits on grouped
characters in front of the mob); melee hits are below 600.

**Fail if:** No breath attacks fire after several minutes of combat (indicating
special_abilities were accidentally wiped), or melee hits exceed 1,000.

---

## Session 3: Sleeper's Tomb — Kildrukaun + Ancients (Sleeper Safety Check)

**Priority: CRITICAL for non-regression.**

This session validates Kildrukaun (MR=400, 85k HP) and confirms that killing Ancients
does NOT activate the Sleeper Awake chain. Decision #12 requires the Kerafyrm/Sleeper
event remain isolated.

### Prerequisites

- Access to sleeper zone. Note: Sleeper's Tomb requires a Sleeper's Tomb key in the
  original game — use `#zone sleeper` or have the key.
- IMPORTANT: The 4 Warders are dormant (spawn_condition 1 = 0). You will NOT see them
  under normal conditions. DO NOT use `#spawncondition sleeper 1 1` during testing
  unless you have Kerafyrm-survival intent (see Sleeper Awake note below).

### Steps

1. Zone to sleeper: `#zone sleeper`
2. Locate Kildrukaun the Ancient: `#findnpc Kildrukaun`
3. Check stats: `#showstats` — confirm HP ~85,000, MR ~400.
4. Test MR=400 with a magic-using companion or character.
   - Expected: Moderate resist rate — not the full MR=1000 wall of Vyemm; some spells
     land, some resist. MR=400 means roughly 50-70% resists for an in-era caster.
   - This distinguishes Kildrukaun from the MR=1000 bosses and validates Decision #11
     (preserve signature MR values).
5. Engage and kill Kildrukaun.
   - Expected: Normal death; no unusual scripted events specific to Kildrukaun's death.
   - Expected: Kildrukaun does NOT send any signal to The Sleeper on death.

### CRITICAL: Ancient death does NOT trigger Sleeper Awake

After killing Kildrukaun (or any other Ancient), observe the following:
- No shout of "Warders, I have fallen" — that is Warder text, not Ancient text.
- No "I AM FREE!" message from The Sleeper.
- No zone-wide Kerafyrm spawn announcement.
- Kerafyrm does NOT appear in the zone.

The Ancients use a separate behavior: when Kerafyrm is ALREADY alive, Ancients
self-depop. Killing an Ancient in normal gameplay (no Kerafyrm up) triggers no chain.

6. After killing Kildrukaun, also engage Milas An`Rev (128040, 60k HP) as the
   accessible mid-tier boss.
   - Expected: HP ~60,000, fight tractable solo or with one companion.

**Pass if:** Kildrukaun has 85k HP, MR=400 creates moderate but not total spell
resistance, killing him triggers no Sleeper Awake text or Kerafyrm spawn.

**Fail if:** Any "I AM FREE!" text appears, or Kerafyrm spawns after Ancient deaths,
or Kildrukaun HP is above 100,000.

**GM emergency stop if Sleeper Awake accidentally fires:**
```
-- If you see "I AM FREE!" — Kerafyrm (128089) will spawn at -1499,-2344,-1052
-- DO NOT engage Kerafyrm (3.5M HP, Destroy death-touch instakill)
-- Immediately:
#invul on
#zone qeynos2   (or any safe zone)
-- Then ask an admin to reset spawn_condition_values for sleeper zone
```

---

## Session 4: Master of the Guard — 8-Sentry Wave Encounter

**Priority: HIGH.**

Master of the Guard (128145, 80k HP) uses a Lua-scripted wave encounter via
`akk-stack/server/quests/sleeper/encounters/motg.lua`. Every 3s, 50s, 50s, 50s it
signals 8 sentry NPCs to spawn visible sentries. This session validates MotG HP cut
does not break the encounter script.

### Prerequisites

- Access to sleeper zone
- Recommend 2-3 characters (or strong companion lineup) — the 8-sentry waves are the
  intended challenge

### Steps

1. Locate Master of the Guard: `#findnpc Master` in sleeper zone.
2. Check stats: `#showstats` — confirm HP ~80,000.
3. Engage Master of the Guard.
   - Expected: After 3 seconds, 8 sentries (#a_foreboding_sentry variants) spawn in the
     area and engage.
   - Expected: Additional sentry waves at ~50s intervals while MotG is alive.
4. Manage the sentry waves and kill MotG.
   - Expected: Sentries are killable individually; MotG does not regenerate from
     sentry kills.
   - Expected: Total fight time for a 2-player group should be 3-6 minutes.
5. Kill MotG.

**Pass if:** Sentry waves fire correctly (at least 2 waves during the fight), MotG HP
is ~80k, the encounter script is responsive.

**Fail if:** No sentry waves spawn (indicating encounter script broke on zone load),
MotG HP is above 100,000, or MotG fails to die within a reasonable timeframe for a
small group.

---

## Session 5: NToV Defender Fight — Q37 Override Validation

**Priority: MEDIUM-HIGH.**

The 4 Defenders (An Emerald Defender 124050, A Sky Defender 124051, An Onyx Defender
124052, A Lava Defender 124079) were included per user Q37 override. This session
validates HP=45,000 and maxdmg=550 make them tractable.

### Prerequisites

- Access to templeveeshan (Defenders patrol inside ToV)

### Steps

1. Zone to templeveeshan: `#zone templeveeshan`
2. Locate a Defender: `#findnpc Defender`
3. Check stats: `#showstats` — confirm HP ~45,000, maxdmg ~550.
4. Engage a Defender (use `#invul off` first).
   - Expected: Melee hits in the 225-550 range.
   - Expected: At 45k HP, a single tank + healer can handle the fight without excessive
     attrition.
5. Kill the Defender.
   - Note: Defender respawn is 16,200s (~4.5h) — short-tier respawn per Q37 decision.
     You can observe the respawn position is unchanged.

**Pass if:** HP ~45k confirmed via showstats or fight duration, maxdmg below 600.

**Fail if:** HP is at or near 120,000 (unchanged from PEQ default), or maxdmg exceeds 600.

---

## Session 6: Lendiniara the Keeper — Q38 Respawn Validation

**Priority: MEDIUM.**

Lendiniara the Keeper (124020, 80k HP) is the Sleeper's Tomb key talisman source.
Decision #38 applies the 24h endgame respawn (86,400s). This session validates both
the HP cut and the respawn behavior.

### Steps

1. Zone to templeveeshan: `#zone templeveeshan`
2. Locate Lendiniara: `#findnpc Lendiniara` (spawn2 25294)
3. Check stats: `#showstats` — confirm HP ~80,000.
4. Kill Lendiniara.
5. Note the kill timestamp.
6. After ~24 hours of real time (or if you want to spot-check): check if Lendiniara
   has respawned. With `#repop` you can force a repop to test the respawn immediately.
   - After `#repop`, Lendiniara should NOT respawn immediately (she just died). The zone
     repop forces all expired timers — if her respawn_time is 86400s, she won't be ready
     until 24h after death.

**Alternate test:** Use `#spawn 124020` to manually spawn a Lendiniara for the HP check.
Kill it. Then note that natural respawn is 24h.

**Pass if:** HP ~80k confirmed; natural respawn is ~24h (86,400s).

**Fail if:** HP is above 100,000, or natural respawn is shorter than 6 hours.

---

## Session 7: Avatar of War — Endgame Fight + Rampage Cap

**Priority: HIGH.**

Avatar of War (113457, 120k HP, mindmg 200, maxdmg 700) is the Kael endgame. The Phase
4a chain (Statue → Idol) must have been completed first to trigger the AoW spawn. AoW has
a rampage 6x6 special ability; the global `MaxRampageTargets=2` rule caps how many targets
get hit per rampage burst.

### Prerequisites

- Phase 4a Statue (113071, 50k HP) and Idol (113341, 130k HP) must be killable as a
  prerequisite chain. If AoW is not currently alive in Kael, you need to kill the Idol
  first to trigger the AoW spawn.
- Access to kael zone

### Steps

1. Zone to kael: `#zone kael`
2. Check if Avatar of War is currently alive: `#findnpc Avatar`
3. If AoW is not up, engage the Idol of Rallos Zek chain:
   a. Kill Statue of Rallos Zek (113071) — in the King Tormax wing.
   b. This triggers Idol of Rallos Zek (113341) to spawn.
   c. Kill the Idol — this triggers AoW (113457) to spawn via the Idol's `event_death_complete`.
4. Engage Avatar of War.
   - Check stats: confirm HP ~120,000, mindmg ~200, maxdmg ~700.
5. Observe the rampage mechanic:
   - Expected: AoW periodically rampages, hitting multiple targets.
   - Expected: Due to MaxRampageTargets=2, at most 2 additional targets beyond the
     primary are hit per rampage burst. This prevents wipe-level AE damage.
   - Expected: Individual rampage hits do not exceed ~700 damage.
6. Kill Avatar of War.
   - Expected: The fight takes 5-10 minutes for a 2-3 player group.

**Pass if:** HP ~120k, maxdmg confirmed below 800 (700 cap), rampage fires but does not
one-shot the group, fight is beatable.

**Fail if:** AoW does not spawn after Idol death (indicating Phase 4a event chain broke),
or HP is above 200,000, or rampage one-shots even a well-equipped character (indicating
damage cap did not apply or MaxRampageTargets is not capping burst).

---

## Session 8: Vulak`Aerr — ToV Pinnacle Fight + Thylex Spawn Mechanism

**Priority: HIGH.**

Vulak`Aerr (124155, 150k HP, mindmg 250, maxdmg 800) is the ToV pinnacle boss. He is
script-spawned by Thylex of Veeshan (124000) via a 60-second poll: when all 6 North Wing
altar dragons are dead and Vulak is not already up, Thylex spawns Vulak at coordinates
(-739.4, 517.2, 121, 510).

The 6 altar dragons are: Lady Mirenilla (124077), Lady Nevederia (124076), Lord Feshlak
(124008), Aaryonar (124010), Lord Kreizenn (124074), Lord Vyemm (124017).

### Prerequisites

- Access to templeveeshan
- Kill all 6 North Wing altar dragons before Vulak will spawn
- Note: Lord Koi`Doken (124103) is NOT an altar dragon; he is a Phase 4b boss in his
  own right but does NOT trigger Vulak.

### Option A: Full chain clear (recommended for complete validation)

1. Zone to templeveeshan: `#zone templeveeshan`
2. Kill all 6 North Wing altar dragons in any order. Use the Phase 4b HP targets as
   a reference — they range from 90k (Vyemm) to 120k (Nevederia):
   - Lady Mirenilla 124077: 95k HP
   - Lady Nevederia 124076: 120k HP
   - Lord Feshlak 124008: 110k HP
   - Aaryonar 124010: 95k HP
   - Lord Kreizenn 124074: 110k HP
   - Lord Vyemm 124017: 90k HP
3. Wait up to 60 seconds after the 6th dragon dies.
   - Expected: Thylex fires its tick, checks `entity_list` for the 6 altar dragons
     (none alive), checks that Vulak is not up, checks the `vulak` qglobal cooldown.
   - Expected: Vulak`Aerr spawns at approximately (-739, 517, 121) in templeveeshan.
4. Check Vulak stats: `#showstats` — confirm HP ~150,000, MR ~80, AC ~950.
5. Engage Vulak.
   - Expected: Hits in the 250-800 range.
   - Expected: Vulak is magic-vulnerable (MR=80). Magic casters should land most spells.
   - Expected: The fight is the hardest in-era encounter (150k HP vs AoW's 120k) but
     beatable by a 2-3 player group.
6. Kill Vulak.
   - Expected: Normal death loot behavior.
   - Expected: Thylex resets the `vulak` qglobal after 6 minutes and can spawn Vulak
     again after the 6 altar dragons respawn (24h each).

### Option B: GM spawn for quick HP check

```
#spawn 124155    -- spawns Vulak at your location
#showstats       -- confirm HP ~150,000
#invul on        -- do not engage if not ready
#kill            -- kill the test spawn
```

**Pass if:** Vulak spawns when all 6 altar dragons are dead, HP ~150k confirmed,
MR=80 means magic spells land consistently, maxdmg confirmed below 900 (800 cap).

**Fail if:** Vulak does not spawn after killing all 6 altar dragons and waiting 2
minutes (indicating Thylex script issue), or HP is above 200,000, or Thylex himself
has been accidentally killed (check `#findnpc Thylex` — he must be at 100 HP).

---

## Edge Cases to Test

### Edge Case 1: Vyemm MR vs. all spell schools

Vyemm's MR=1000 affects magic-based spells. Some spell types (fire, cold, disease,
poison) may resist based on the corresponding resist stat, not MR. Confirm that at
least the core magic-school resist (MR) wall is completely functional.

### Edge Case 2: Sleeper Warder dormancy

Confirm that using `#findnpc Warder` in sleeper zone returns no results under
current conditions. The Warders should not be visible or targetable with
spawn_condition 1 = 0.

```
#findnpc Nanzata
#findnpc Hraashna
-- Expected: "No NPC matching that name was found in this zone"
```

### Edge Case 3: Thylex immunity

Thylex of Veeshan (124000) has immunity flags (19/20/24/25/35) that prevent
targeting, charming, stunning, and direct kill. Verify Thylex cannot be targeted
and attacked:
- Target Thylex: he should not be targetable as a hostile.
- Expected: Thylex is a "no target" NPC — clicking on him should not initiate combat.

### Edge Case 4: AoW rampage with companions

If running AoW with Bot companions, the `MaxRampageTargets=2` global cap means at
most 2 bots (or players) are hit per rampage event. With 700 maxdmg, ensure your
bot healers can sustain incoming damage. The fight is survivable at this damage cap.

---

## Rollback Instructions

If any Phase 4b values appear wrong or cause server instability:

```sql
-- Rollback Phase 4b npc_types changes using backup table
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling_velious_b bk ON bk.id = nt.id
SET nt.hp = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg,
    nt.AC = bk.AC,
    nt.MR = bk.MR,
    nt.special_abilities = bk.special_abilities,
    nt.npcspecialattks = bk.npcspecialattks;

-- Rollback Phase 4b spawn2 respawntime changes using backup table
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling_velious_b bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance = bk.variance;

-- Then issue: #reloadworld (in-game GM command) or use Spire restart
```

The rollback script is also at:
`claude/project-work/feature-raid-scaling/data-expert/sql/12-velious-b-rollback.sql`

After rollback, issue `#reloadworld` or perform a full-stack restart via Spire
(http://192.168.1.86:3000) to flush all zone NPC caches.
