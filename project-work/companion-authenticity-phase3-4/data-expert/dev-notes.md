# Companion Authenticity Phase 3-4 — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-authenticity-phase3-4`
> **Agent:** data-expert
> **Task(s):** #5 — GAP-07: Audit all caster class spell list priorities
> **Date started:** 2026-03-15
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 5 | GAP-07: Audit all caster class spell list priorities | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | What You Found |
|------|----------------|
| npc_spells (DB) | IDs: Wizard=2, Necro=3, Mage=4, Enchanter=5, Paladin=8, SK=9 |
| npc_spells_entries (DB) | Priority distribution for all 6 lists — see Key Findings |

### Key Findings

**Priority distribution summary:**

| List | ID | Total Spells | Distinct Priorities | Max Priority | At Priority=1 | Verdict |
|------|----|-------------|---------------------|--------------|----------------|---------|
| Wizard | 2 | 81 | 24 | 24 | 52 | GOOD — nukes at 2-24, roots at 2-5, buffs at 1 |
| Necromancer | 3 | 68 | 22 | 56 | 23 | GOOD — snares 51-56, lifetaps 10-20, DoTs 6, nukes 5 |
| Magician | 4 | 54 | 1 | 1 | 54 | BROKEN — all 54 spells at priority=1 |
| Enchanter | 5 | 121 | 4 | 15 | 112 | PARTIAL — mez(2048) all at 1, charm(4096) mostly at 1; only Gravity Flux & Command of Druzzil at 15 |
| Paladin | 8 | 41 | 1 | 1 | 41 | BROKEN — all 41 spells at priority=1; heals must lead |
| Shadow Knight | 9 | 48 | 1 | 1 | 48 | BROKEN — all 48 spells at priority=1; lifetaps & snares must lead |

**Wizard (ID 2) — Already correct.** Uses escalating priorities per spell level tier
(priority=2 for lowest tier nukes, up to 24 for top-tier nukes). Roots at 2-5.
Buffs/dispels at 1. This is the reference model for casters.

**Necromancer (ID 3) — Already correct.** Snares (type 128) at 51-56 (highest — core
combat role), lifetaps (type 64) at 10-20 (core damage/sustain), DoTs (type 256) at 6,
nukes (type 1) at 5. Roots at 2-3. Buffs/fears at 1.

**Magician (ID 4) — Needs fix.** All DD nukes, pet-type spells, buffs, dispels at
priority=1. Spell breakdown:
- type=1: 36 spells — DD nukes (Burst of Flame through Sun Vortex) + 3 Malo-group
  debuffs (Malaise, Malaisement, Malosi/Malosini/Malosinia) + Raging Servant
- type=8: 14 spells — mage armor shields (self-buffs)
- type=256: 2 spells — Elemental Maelstrom, Wrath of the Elements (pet-related AE)
- type=512: 2 spells — Nullify Magic, Annul Magic

**Enchanter (ID 5) — Needs partial fix.** The existing prioritization is incomplete:
- type=1 (debuffs/utility): Gravity Flux at 15, Fear spells at 2, rest at 1
- type=4 (roots): Paralyzing Earth at 3, Immobilize at 2, rest at 1
- type=4096 (charm): Command of Druzzil at 15, Beguile/Charm at 2, rest at 1
- type=2048 (mez): ALL 9 mez spells at priority=1 — WRONG, mez is primary role
- type=8 (buffs): all at 1 — correct
- type=256 (DoTs): all at 1
- type=512 (dispel): all at 1
Fix: elevate mez to priority 18, charm to 12, slow/debuff utility (Tash, Cripple, etc.) to 10,
AoE/fear to 5, roots to 3, DoTs to 2, everything else stays at 1.

**Paladin (ID 8) — Needs fix.** Spell breakdown:
- type=1: 5 spells — 1 DD nuke (Flame of Light), 4 stuns (Holy Might, Force, Quellious'
  Word of Tranquility, Force of Akilae; effectid1=21)
- type=2: 11 spells — heals (Minor Healing through Light of Nife, Ethereal/Celestial/Supernal Cleansing)
- type=4: 4 spells — roots
- type=8: 16 spells — self-buffs (Holy Armor, Valor, Divine Glory, Symbol series, etc.)
- type=512: 1 spell — Nullify Magic
- type=1024: 4 spells — Yaulp series (self-buff proc enhancers)
Fix: heals at 20, stuns at 10, DD nuke at 8, roots at 5, Yaulp buffs at 3, buffs at 1.

**Shadow Knight (ID 9) — Needs fix.** Spell breakdown:
- type=1: 18 spells — STR debuffs/ATK debuffs (Despair/Siphon Strength/Scream of Hate
  series with effectid1=10), fear spells (Fear/Invoke Fear; effectid1=23), 1 enfeeblement
  (Wave of Enfeeblement; effectid1=4), 4 DD nukes (Spear of Disease/Pain/Plague/Decay;
  effectid1=0)
- type=8: 8 spells — self-buffs (Grim Aura, Banshee Aura, skins, Cloaks)
- type=64: 10 spells — lifetaps (Lifetap through Touch of Innoruuk)
- type=128: 5 spells — snares/darkness (Clinging through Festering Darkness)
- type=256: 6 spells — DoTs (Disease Cloud through Ignite Blood)
- type=512: 1 spell — Nullify Magic
Fix: lifetaps at 20 (core sustain/damage), snares at 12 (critical utility), DoTs at 8,
STR debuffs at 6, DD nukes at 5, fear at 3, enfeeblement at 2, buffs at 1.

### Implementation Plan

For each broken/partial list:
1. SELECT current state to verify row counts before UPDATE
2. Apply UPDATE statements grouped by spell type/subtype
3. Verify with SELECT after each list

**Priority hierarchy model:**

| Class | Primary Role | Priorities |
|-------|-------------|-----------|
| Magician | DD nukes | Nukes 5-18 (tiered by level range), buffs 1 |
| Enchanter | CC (mez/charm) | Mez 18, charm 12, debuffs 10, fear 5, roots 3, DoTs 2, buffs 1 |
| Paladin | Healer + tank | Heals 20, stuns 10, nuke 8, roots 5, Yaulp 3, buffs 1 |
| Shadow Knight | Lifetap + snare | Lifetaps 20, snares 12, DoTs 8, STR debuffs 6, nukes 5, fear 3, buffs 1 |

**Files to create:**
- `claude/project-work/companion-authenticity-phase3-4/data-expert/context/gap07_caster_spell_priorities.sql`
- `claude/project-work/companion-authenticity-phase3-4/data-expert/context/gap07_validation.sql`

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| MariaDB UPDATE WHERE IN | Context7 /mariadb-corporation/mariadb-docs | Yes | Standard syntax confirmed |
| START TRANSACTION / COMMIT | Context7 /mariadb-corporation/mariadb-docs | Yes | Confirmed: START TRANSACTION; ... COMMIT; |
| autocommit behavior | Same as GAP-05 — autocommit=ON confirmed in prior work | Yes | Safe to wrap in explicit transaction |

### Plan Amendments

Plan confirmed — no amendments. The `spellid` column name (not `spells_id`) was already
confirmed by GAP-05 work. UPDATE syntax using WHERE npc_spells_id = X AND type = Y and
WHERE spellid IN (...) is verified and correct.

---

## Stage 3: Socialize

No blocking dependencies. This is pure database data — no C++ or Lua changes required.
Same self-contained scope as GAP-05. No teammates need to confirm before proceeding.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-15 — Audited all 6 caster lists; found 4 need fixes

**Wizard (ID 2):** ALREADY CORRECT. 24 distinct priorities, nukes tiered 2-24 by level.
No changes needed.

**Necromancer (ID 3):** ALREADY CORRECT. 22 distinct priorities, snares lead at 51-56,
lifetaps at 10-20, DoTs at 6. No changes needed.

**Magician (ID 4):** NEEDS FIX. All 54 spells at priority=1.
**Enchanter (ID 5):** NEEDS PARTIAL FIX. Mez at priority=1 (wrong — it's their primary role).
**Paladin (ID 8):** NEEDS FIX. All 41 spells at priority=1, heals must lead.
**Shadow Knight (ID 9):** NEEDS FIX. All 48 spells at priority=1, lifetaps must lead.

#### 2026-03-15 — Created migration script and applied to live database

**Where:** `claude/project-work/companion-authenticity-phase3-4/data-expert/context/gap07_caster_spell_priorities.sql`

**Magician priority logic:**
The wizard list uses per-spell escalating priority tied to spell level tier (older spells lower,
newer higher). Mage nukes follow the same pattern. Rather than using a flat "all nukes = 5" like
the simpler healer fix, the mage list tiers nukes by level range to match the wizard reference.
Type=256 (pet AE nukes — Elemental Maelstrom, Wrath of the Elements) get priority=3.
Malo debuffs (Malaise family, type=1) are important setup — priority=10.
Mage buffs/dispels stay at 1.

**Enchanter priority logic:**
Mez (type=2048) is THE primary combat tool for enchanters — elevated to 18.
Charm (type=4096) is risky but powerful — elevated to 12.
Tash/debuff/slow spells are critical setup — elevated to 10.
Fear spells (type=1, effectid1=23) provide CC fallback — priority=5.
Existing Gravity Flux (priority=15) is a good disruption tool — left alone.
Roots at 3, DoTs at 2, buffs/dispels at 1.

Note on Enchanter type=8 spells: many have minlevel=0 which means they are always-eligible
self-buffs (Runes, Haste, etc.). These must stay at priority=1 — they're support spells,
not combat priorities.

**Paladin priority logic:**
Paladin is a hybrid healer/tank. Heals lead at 20 (same as shaman). Stuns (effectid1=21)
are the paladin's signature crowd control — priority=10. The single DD nuke (Flame of Light)
at priority=8. Roots at 5. Yaulp (type=1024, self-proc buff) at 3. All other buffs at 1.

**SK priority logic:**
SK is a lifetap-centric class — lifetaps (type=64) lead at 20.
Darkness snares (type=128) are critical for holding mobs — priority=12.
DoTs (type=256) are secondary damage over time — priority=8.
STR debuffs (type=1, effectid1=10: Despair/Siphon Strength/Scream of Hate/Shadow
Vortex/Shroud of Hate/Abduction/Torrent series/Aura of Pain) at priority=6.
DD nukes (type=1, effectid1=0: Spear of Disease/Pain/Plague/Decay) at priority=5.
Fear spells (type=1, effectid1=23: Fear, Invoke Fear) at priority=3.
Enfeeblement (type=1, effectid1=4: Wave of Enfeeblement) at priority=2.
Buffs/dispels at 1.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `claude/project-work/companion-authenticity-phase3-4/data-expert/context/gap07_caster_spell_priorities.sql` | Created | Migration + verification queries |
| `claude/project-work/companion-authenticity-phase3-4/data-expert/context/gap07_validation.sql` | Created | Standalone validation script |

---

## Open Items

None.

---

## Context for Next Agent

Task is fully complete. Migration applied to live `peq` database.

**Lists changed:** Magician (ID 4), Enchanter (ID 5), Paladin (ID 8), Shadow Knight (ID 9).
**Lists unchanged:** Wizard (ID 2) and Necromancer (ID 3) were already correctly prioritized.

**Key fact for game-tester:** No server rebuild or restart required. Changes take effect on
next zone load. To test: zone into an area with a mage companion and verify they nuke targets
rather than buffing themselves first. With a paladin companion, get a group member low on HP
and confirm the paladin heals before stunning. With an SK companion, confirm lifetaps fire
before DoTs. With an enchanter companion and an add, confirm they mez the add first.
