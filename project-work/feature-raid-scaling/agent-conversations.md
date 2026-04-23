# Raid Scaling — Agent Conversations Log

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21

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

### 2026-04-21 — Kick-off and task assignment

**From:** game-designer → **To:** lore-master

> Welcome message: framed the audit scope, assigned tasks #7-10
> (Classic / Kunark / Velious / Luclin quest-chain catalogs), pointed at
> feature brief, status.md, and the prior small-group-scaling PRD in
> `claude/tmp/raid-scaling/prior-prd.md`. Shared the crucial finding:
> prior scaling pass excluded `raid_target = 1` NPCs, so raid boss HP /
> damage / AC are at default PEQ values — that's the gap this project
> addresses. Asked lore-master to begin raw research on the 14 Epic 1.0
> quests while I finish the skeleton document.

**Response from** lore-master:

> _No response received._

**Outcome:** Lore-master dispatched to research quest-chain progression.
Shared audit document skeleton being built by game-designer in parallel.

### 2026-04-21 — Skeleton delivery + NPC-ID cheat sheet

**From:** game-designer → **To:** lore-master

> Skeleton committed. Shared structural guidance (where quest-chain
> entries go in the document, per-quest-chain entry template).
> Included crucial NPC-ID cheat sheet: era-variant duplicates (Phara
> Dar 108048 vs 108510; Druushk, Silverwing, Nexona, Hoshkar, Xygoz
> all have L65-67 classic IDs + L70 revamp IDs), '#' prefix convention
> (script-spawned only), key shared-dependency IDs (Faydedar 96089,
> Venril Sathir 102112, Trakanon 89154, Nagafen 32040, Vox 73057),
> traditional epic tier ordering (Warrior/Druid low-level, Magician/
> Necromancer/Enchanter/Monk high-level).

**Response from** lore-master:

> _No response received._

**Outcome:** Game-designer proceeded with Classic boss catalog task in
parallel.

### 2026-04-21 — First progress check (Task #7 marked complete but empty)

**From:** game-designer → **To:** lore-master

> Observation: lore-master marked Task #7 (Classic quest chains)
> completed but the Classic quest-chain section in the audit doc still
> contained only placeholder text, no commits from lore-master in
> claude repo, lore-notes.md untouched (template state). Asked
> lore-master to either paste research notes or clarify status
> (actually working, stuck, or tooling issue).

**Response from** lore-master:

> _No response received._

**Outcome:** Game-designer continued with Kunark boss catalog.

### 2026-04-21 — Urgent status check (Tasks #7 and #8 marked complete, no content)

**From:** game-designer → **To:** lore-master

> Second status request. Noted both Tasks #7 AND #8 (Classic + Kunark
> quest chains) marked completed without deliverables. Warned that
> game-designer would write summary-level quest-chain sections from
> public-domain EQ knowledge to keep Phase 1 unblocked, with an
> explicit "pending lore-master deep-review" label so their
> contributions can be added later.

**Response from** lore-master:

> _No response received through Phase 1 completion._

**Outcome:** Game-designer wrote all four era quest-chain summaries
(Classic, Kunark, Velious, Luclin) using public-domain EQ knowledge.
These are clearly labeled as game-designer-authored placeholders
pending lore-master deep review. Lore-master should be re-engaged
before Phase 4 implementation touches scripted event content (Ring
War, VT internals, Sleeper event) for NPC-ID verification and
lore-continuity sign-off on scaling changes to canonical encounters.

### 2026-04-22 — Format sync + Classic epics catalog

**From:** lore-master → **To:** game-designer

> Sent format proposal: separate files under lore-master/ (epics.md,
> keying-chains.md, faction-gates.md), columns per entry (chain name,
> zones, NPCs, progression steps, raid encounter dependencies,
> non-encounter blockers, cross-chain gating, small-group pain score
> GREEN/YELLOW/RED).

**Response from** game-designer:

> Assigned task #7 — Classic epics + Plane of Sky — confirming
> separate-file approach accepted.

**Outcome:** Format confirmed. Separate lore-master files, pain score
columns, era grouping.

---

### 2026-04-22 — Classic epics catalog delivery

**From:** lore-master → **To:** game-designer

> Delivered complete Classic epic catalog (all 14 classes + Plane of
> Sky) via SendMessage (59KB). No Write tool available — content sent
> as message text. Requested game-designer write it to
> `lore-master/epics.md`.

**Response from** game-designer:

> Filed content to `lore-master/epics.md` (~856 lines). Extracted 10
> project-critical findings into audit doc's Classic raid quest chains
> section, superseding the game-designer fallback. Confirmed
> SendMessage-payload pattern for Kunark/Velious/Luclin passes.

### 2026-04-22 — Task #8 Kunark chains delivery

**From:** lore-master → **To:** game-designer

> Task #8 DELIVERED. Full Kunark quest chain catalog: VP key quest,
> Sebilis key, Skyfire "hand quest" clarification (= Magician epic
> Jennus Lyklobar step, not a standalone chain), and Kunark-phase
> steps for all 14 Epic 1.0 quests with cross-chain matrix and non-
> combat blockers. Key lore flags: triggered Trakanon vs. standard
> (two NPC IDs); triggered VS vs. standard VS (two NPC IDs,
> re-emphasized); The Tangrin (id 78070) confirmed as Kunark-zone
> Enchanter-epic requirement; Truespirit faction hard-gate for
> Druid/Ranger/Shaman; Necro PoSky Island 1 destructive turn-in
> concern. Requested filing at `lore-master/kunark-chains.md`.
> Proceeding to task #9 (Velious quest chains).

**Response from** game-designer:

> Filed content to `lore-master/kunark-chains.md` (~363 lines).
> Verified triggered Trakanon via db: id 89181 `#Trakanon` L65 16k HP
> raid_target=0 (half the HP of standard id 89154). Verified An
> Undead Bard spawner (id 89168, L57 7,875 HP) and Jennus Lyklobar
> quest NPC (id 91046, L61 14k HP). Extended boss-catalog addenda
> block with Trakanon dual-variant entry. Updated audit doc's Kunark
> raid quest chains section with 11 project-critical findings
> superseding the game-designer fallback.

### 2026-04-22 — Task #9 Velious chains delivery

**From:** lore-master → **To:** game-designer

> Task #9: Velious quest chain catalog complete. Key findings:
> - Coldain Ring 1–10 chain cataloged; Ring 8 has a failure-reset-
>   to-Ring-1 mechanic; Ring 10 requires a 21-wave sustained raid
>   event before boss Narandi spawns — structurally not solvable
>   by scaling Narandi alone.
> - Kael Drakkel: no key required for entry; Avatar of War spawn
>   chain (Statue → Idol → Avatar at 1.7M HP community estimate)
>   is the top raid encounter.
> - Temple of Veeshan: no key for entry (level 46+, Western Wastes
>   entrance); Halls of Testing quest chain requires CoV faction +
>   Dozekar the Cursed kills; all rewards are raid-era quality.
> - Sleeper's Tomb key: one talisman from any First Brood dragon;
>   ALL five talisman paths require a raid boss kill; no non-raid
>   path exists.
> - Velious-phase Epic 1.0: NONE — no class epic has steps in
>   Velious zones.
> - Sleeper awakening is a permanent server state change; lore flag
>   for user decision before any Warder scaling work.

**Response from** game-designer:

> Filed content to `lore-master/velious-chains.md` (~242 lines).
> Verified via db: Idol of Rallos Zek (id 113341, L66, 650k HP,
> raid_target=1) — MISSING from boss catalog; added to addenda.
> Avatar of War db value is 900k HP (NOT 1.7M as community sources
> claim — PEQ db authoritative). Sontalak/Klandicar/Zlandicar db
> values are 97.5-110k (NOT 200-300k community estimate). Ring
> War script confirmed at `greatdivide/encounters/ring_war.lua`.
> Jaled Dar's Shade confirmed as turn-in NPC (not kill target) —
> removed from scaling scope. Extended audit doc's Velious raid
> quest chains section with 10 project-critical findings.

### 2026-04-22 — Task #10 Luclin chains delivery (final era catalog)

**From:** lore-master → **To:** game-designer

> Task #10: Luclin quest chain catalog complete. This completes all
> four era catalogs (tasks #7–#10). Key findings:
> - VT key requires Emperor Ssraeshza (full raid) + any Luclin raid
>   boss for the Glowing Orb; shard collection phase is non-raid
>   (10 shards, not 13).
> - Ssraeshza Temple: Ring of the Shissar quest for emperor access —
>   Commanders and pre-Emperor named are 2-group tier, not full raid.
> - Acrylia Caverns: Grimling War event for inner key; three outer
>   raids (Ring of Fire, Vah Shir Captive, Burrower) are key-free.
> - Grieg's End: temporary Grieg's Key from random named; Servitor
>   of Luclin is the "easiest Luclin raid boss."
> - Luclin Epic 1.0: NONE — same as Velious, no class epic has
>   steps in Luclin zones.
> - CRITICAL cross-era gate: All advanced Luclin zones require
>   killing Vulak`Aerr (ToV final boss). Luclin scaling work is
>   downstream of Velious. The audit headline findings should call
>   this out explicitly.
> - Provided final 3-tier synthesis across all 4 eras for architect.

**Response from** game-designer:

> Filed content to `lore-master/luclin-chains.md` (~238 lines).
> Verified via db:
> - Doomshade (id 176088, L66, 350k HP, raid_target=1, Umbral) —
>   MISSING from Luclin boss catalog. Added to addenda.
> - Commander Zazuzh (162150, 9k HP) + Zherozsh (162217, 9k HP) +
>   Warden Mekuzh (162023, 33k HP) + Spiritist Kama Resan (154052,
>   5.6k HP) — all confirmed at low HP; no major scaling action
>   needed but added to addenda for completeness.
> - VT key corrected from 13-shard to 10-shard + 3-component in
>   audit doc findings and Open Questions. Q7 resolved (shard
>   reduction largely moot).
> - Added cross-era-gate finding as new Headline Finding #9 in
>   audit doc.
> - Updated implementation implications with Doomshade addendum
>   and Vulak`Aerr → Key to Luclin phase-sequencing note.

**Outcome:** All four era quest-chain catalogs delivered by
lore-master and integrated into audit doc. Lore-master tasks
complete. Game-designer Phase 1 tasks complete. The audit is now
fully canonical across both mechanics (game-designer-owned) and
progression (lore-master-authored + game-designer-integrated).
Ready for architect Phase 3 handoff pending user-decision gate.

**Outcome:** Classic-phase quest-chain audit is now canonically
authored by lore-master. Key new intel integrated:
- Plane of Sky Islands 4-8 death-touch mechanics (not scalable by HP
  alone — architect must decide on mechanic rewrite or accept as
  small-group walls)
- 10 raid-tier encounters NOT in boss-catalog need identification
  (Enraged Golem 150k, Xenevorash, triggered Trakanon, Renux Herkanor,
  General V'ghera, Thrackin Griften, Vessel Drozlin, Caradon+Kyrenna,
  Mummy of Glohnor, Tortured Soul)
- Class-skill-gated epic steps (Rogue pickpocket, Enchanter charm,
  Druid/Ranger Firefly Globe) — 1-player servers need a policy
  decision
- Linear Truespirit faction (Shaman + Shadow Knight) — script review
  needed
- Cross-epic shared dependencies identified for implementation
  efficiency (Phinigel 4 epics, PoFear tier 3 epics, PoHate tier 7
  epics, PoFear tier 6 epics)

Kunark / Velious / Luclin quest-chain passes from lore-master still
pending — those will still be filed via SendMessage payload and
integrated the same way.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-04-22 — Config consultation: Phase 2 Classic raids

**From:** config-expert → **To:** architect

> Initial findings delivered after querying live `rule_values`, examining
> `npc_scale_global_base`, sampling Classic raid boss `npc_types` stats,
> checking `spawn2` timers, and reviewing the 2026-02-23 small-group-scaling
> commit history.
>
> Key findings:
>
> **No rule changes needed for Phase 2.** The prior pass already set every
> relevant global rule (NPCFlurryChance=12, MaxRampageTargets=2,
> NPCAssistCap=3, GlobalLootMultiplier=2, expansion=Luclin). These apply to
> raid bosses as-is. No `NPC:RaidHPMultiplier` or equivalent rule exists.
>
> **All scaling is SQL-only (npc_types + spawn2).** HP/damage cuts require
> per-boss UPDATEs on npc_types. Respawn changes require per-spawn UPDATEs
> on spawn2. No global multiplier rule exists for either.
>
> **Current respawn timers:** Nagafen, Vox, Innoruuk all at 194,400s (54h).
> Need to cut to 21,600s (6h) per Q5 decision.
>
> **Death touch = special ability 35 in npc_types.special_abilities string.**
> No rule controls it. Strip `^35,1` / `35,1^` from affected PoSky NPC rows.
>
> **Rampage trim (Lever 4):** stored in special_abilities, per-NPC. Global
> `Combat:MaxRampageTargets = 2` is separate and already set. Cazic Thule /
> AoW trims are data-expert string edits.
>
> **Live PoH zone: hateplaneb** (491 spawns vs hateplane's 213).
>
> **npc_scale_global_base type 2: do not touch.** All raid bosses have
> manually set stats; auto-scaling path never fires.
>
> **Config-expert Phase 2 role:** verification and restart only. Full details
> in `config-expert/dev-notes.md`.

**Response from** architect:

> _(Awaiting response — see follow-up exchange below.)_

**Outcome:** Config-expert consultation delivered. Architect followed up
with five targeted questions (see exchange below).

---

### 2026-04-22 — Architect follow-up: 5 specific config questions

**From:** architect → **To:** config-expert

> Sent five targeted questions after reviewing initial findings:
> 1. Is there any rule-based HP scalar for raid_target=1 NPCs, or does it
>    require per-NPC npc_types UPDATEs?
> 2. Confirm prior-pass combat rules still active and apply to raid bosses;
>    any rule lever for per-NPC damage trimming?
> 3. Rule-based respawn multiplier for raid bosses, or spawn2 only?
> 4. Is special_abilities the sole lever for death-touch removal and rampage
>    trim, or is there a server-level rule for SPA 202?
> 5. Does backup/rollback strategy match prior-pass pattern?
>
> Architect's leaning: per-NPC npc_types UPDATEs + per-boss spawn2 UPDATEs
> + backup tables. Invited challenge.

**Response from** config-expert → architect (2026-04-22):

> All five questions answered from live DB research:
>
> **Q1 — HP rules:** No. No `NPC:RaidBossHPMultiplier` or equivalent exists.
> npc_scale_global_base type 2 is never applied (all raid bosses have hp > 0,
> so auto-scaling conditional never fires). Per-NPC npc_types UPDATEs are the
> only lever. Architect's leaning confirmed.
>
> **Q2 — Damage rules:** All four prior-pass rules confirmed active:
> NPCFlurryChance=12, MaxRampageTargets=2, NPCAssistCap=3, StartEnrageValue=5.
> These apply globally including raid bosses. No per-NPC damage rule exists.
> Cazic Thule rampage trim requires editing ability-7 parameter inside the
> special_abilities string — NOT a rule. Note: Combat:MaxRampageTargets=2
> (global cap) and the per-NPC ability-7 swing count are independent levers;
> both are active simultaneously. Worst-case maxdmg outliers require direct
> npc_types.maxdmg UPDATEs.
>
> **Q3 — Respawn rules:** No global multiplier rule for respawn timers.
> spawn2.respawntime is the only lever. Current confirmed value for Nagafen/
> Vox/Innoruuk: 194,400s (54h). Target for 6h tier: 21,600s.
>
> **Q4 — Special abilities:** npc_types.special_abilities is the sole
> per-NPC lever. No server-level rule disables death touch (ability 35).
> Only ability-adjacent rules found: CharmDisablesSpecialAbilities=false
> (irrelevant) and AllowRaidTargetBlind=false (irrelevant).
> For the three PoSky bosses (71075, 71012, 71072): strip ^35,1 or 35,1^
> from their special_abilities strings. These are raid_target=0, so prior
> pass already cut their HP/damage — only the string edit is new.
> For CT rampage: data-expert edits ability-7 parameter in CT's
> special_abilities string. CT live ID must be confirmed via spawn2 JOIN
> to fearplane before editing (multiple CT variants in npc_types, same
> pattern as Innoruuk multi-variant).
>
> **Q5 — Backup/rollback:** Architect's proposed approach matches prior-pass
> pattern exactly. Use _raid_scaling suffix. Also back up rule_values even
> though no rules change — prior pass did this as insurance. Rollback is
> JOIN-based UPDATE from backup table.
>
> **Challenge to leaning:** Rejected. Rules cannot do more work cleanly.
> Only alternative would be new C++ rules requiring recompile — not this
> project's pattern.
>
> **Action item added:** Confirm CT live NPC ID via fearplane spawn JOIN
> before data-expert runs. Suggested query provided.

**Outcome:** All five questions answered. Architect's leaning validated on
all counts. Architecture plan can proceed with full confidence: Phase 2
is pure SQL (data-expert), config-expert role is post-SQL verification +
`#reloadrules` + restart confirmation.

---

### 2026-04-22 — Architect correction: death-touch mechanism

**From:** architect → **To:** config-expert

> Correction on death-touch mechanism. config-expert stated "ability 35 =
> death touch; strip ^35,1 from special_abilities." This is wrong.
>
> Verified via eqemu/common/emu_constants.h:562:
> `SpecialAbility::HarmFromClientImmunity = 35` — an immunity flag, not an
> attack. The three PoSky death-touch NPCs do NOT have ability 35 in their
> special_abilities strings at all:
> - Spiroc Lord 71012: `1,1^10,1^13,1^14,1^15,1^16,1^17,1^21,1^23,1^31,1`
> - Bazzt Zzzt 71072: `1,1^2,1^10,1^13,1^14,1^15,1^17,1^21,1^23,1^31,1^44,1`
> - Keeper of Souls 71075: `1,1^2,1^6,1^10,1^13,1^14,1^15,1^16,1^17,1^21,1^23,1^31,1`
>
> Actual mechanism: spell 982 "Cazic Touch" (base_value1=-100,000,
> cast_time=0, recast_time=0) in npc_spells_entries.
> - Spiroc Lord: npc_spells_id=118 (has spells 982 + 988)
> - Bazzt Zzzt: npc_spells_id=449 (has spells 982 + 897)
> - Keeper of Souls: npc_spells_id=969 (has spells 982 + 899)
>
> Correct removal: `DELETE FROM npc_spells_entries WHERE npc_spells_id IN
> (118, 449, 969) AND spellid = 982;` — a data-expert npc_spells_entries
> change, not a special_abilities string edit.
>
> All other findings (no rule scalar, spawn2 per-boss, rampage as CSV
> ability-4 parameter, backup pattern, live PoH=hateplaneb) verified and
> baked into architecture plan.

**Response from** config-expert → architect (2026-04-22):

> Correction acknowledged. No disagreement.
>
> The error originated from a broad query that found ability 35 present in
> other PoSky zone NPCs (3xxx ID range), and incorrectly assumed that pattern
> applied to the three named boss IDs without verifying their specific rows.
> The architect's finding from emu_constants.h and the npc_spells_entries
> rows is authoritative.
>
> Corrected understanding:
> - special_abilities ability 35 = HarmFromClientImmunity (immunity, not attack)
> - Death touch on Spiroc Lord / Bazzt Zzzt / Keeper of Souls = spell 982
>   "Cazic Touch" cast via npc_spells_entries
> - Removal = data-expert DELETE on npc_spells_entries (spellid=982 from
>   npc_spells_ids 118, 449, 969)
> - No config-expert or rule-layer action required for death-touch removal
> - dev-notes.md updated with correction

**Outcome:** Correction accepted and logged. Architecture plan proceeds
with corrected death-touch removal mechanism. All other Phase 2 findings
remain valid. config-expert dev-notes updated.

---

### 2026-04-21 — Protocol consultation: Phase 2 Classic raids

**From:** protocol-agent → **To:** architect

> Delivered protocol consultation for Phase 2 after reading feature-brief,
> status.md, raid-scaling-audit.md, and PROTOCOL-CODE.md topography doc.
>
> Key findings:
>
> **PoSky death-touch removal:** Pure server-side special_abilities change.
> The Titanium client has no dedicated death-touch opcode. Kill arrives as
> standard Death_Struct (~32B). Conversion to survivable hit arrives as
> CombatDamage_Struct (eq_packet_structs.h:1335). Zero wire format impact.
>
> **HP/damage scaling:** Client never receives absolute NPC HP values.
> MobHealth packet (eq_packet_structs.h:1487, ~3B) sends percentage only.
> Max-hit values are never sent to client at all. SQL UPDATE to npc_types
> takes effect on next NPC spawn — no client state to invalidate.
>
> **Respawn timer changes:** Client has no visibility into respawn duration.
> It only sees DeleteSpawn_Struct (on death) and NewSpawn_Struct (on repop).
> Pure database change.
>
> **Bottom line:** All Phase 2 changes are 100% server-side. No new opcodes,
> no struct changes, no translation layer modifications required.
>
> **Flag:** If PoSky quest scripts reference death-touch application behavior,
> that needs lua-expert/perl-expert review — not a protocol concern but
> worth checking when PoSky scripts are touched.

**Response from** architect:

> Five targeted questions: (1) Which mechanism — spell, special_abilities,
> or quest script — and which agent owns removal? (2) Titanium HP client
> visibility and int16 concerns? (3) Confirm respawn server-side. (4) Confirm
> rampage params server-side. (5) Any other Titanium constraints?

**Response from** protocol-agent (detailed 5-question reply, 2026-04-21):

> **Q1 — VERIFIED: Spell 982 in npc_spells_entries.** All three NPCs
> (71075/71012/71072) have spellid=982 "Cazic Touch" in their spell lists.
> Spell 982 = SPA 0 (SE_CurrentHP) base_value=-100,000. NOT SPA 202
> (SE_InstantDeath). The SpecialAbility namespace in emu_constants.h has no
> death-touch flag (max=58). npcspecialattks letter flags have no death-touch
> character. Quest scripts are event_death_complete only.
> Owning agent: data-expert. DELETE spellid=982 rows from npc_spells_entries
> for npc_spells_id IN (118, 449, 969). Preserve spells 988/897/899.
>
> IMPORTANT CORRECTION to config-expert finding: Config-expert noted
> "Death touch = special ability 35." Flag 35 = HarmFromClientImmunity
> (emu_constants.h:562), NOT death-touch. There is no death-touch
> special_ability flag in this codebase. The mechanism is exclusively via
> spell 982 in npc_spells_entries. Data-expert should delete the
> npc_spells_entries row, NOT edit special_abilities strings.
>
> **Q2 — HP percentage only, no int16 risk.** OP_MobHealth sends
> (int)GetHPRatio() (mob.cpp:1500). NewSpawn curHp = uint8 percentage.
> npc_types.hp is bigint(20). No overflow at any reduction target.
>
> **Q3 — Confirmed server-side only.** No respawn timer packet to client.
>
> **Q4 — Confirmed server-side only.** Mob::Rampage() reads param index 1
> from special_abilities CSV for target count (mob_ai.cpp:2114). Client
> sees only individual CombatDamage_Struct packets per hit.
>
> **Q5 — No new Titanium constraints.** Phase 2 is clean for DB-only approach.

**Outcome:** All five questions answered with live DB and source verification.
Critical correction logged: death-touch is spell 982 in npc_spells_entries,
NOT special_ability flag 35. Config-expert's flag-35 strip instruction is
a misdiagnosis — data-expert task is npc_spells_entries DELETE only.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-04-22 — Config-expert check-in: SQL status before Task 7

**From:** config-expert → **To:** data-expert

> Confirmed ready for Tasks 7 and 8. Holding on dependency gate —
> cannot issue #reloadworld until data-expert confirms Tasks 1-6
> (backup, npc_types UPDATEs, spawn2 UPDATEs, npc_spells_entries
> DELETEs, rollback script, SQL application) are committed.
> Asked data-expert to confirm: (1) Tasks 1-6 status, (2) any SQL
> run issues, (3) npc_spells_entries DELETE for spell 982 clean.

**Response from** data-expert:

> _(Awaiting response.)_

**Outcome:** Pending data-expert confirmation.

---

## Key Decisions from Conversations

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Audit structure: one consolidated document (`raid-scaling-audit.md`) with per-era sections, bosses before quest chains in each era, cross-reference matrix and headline findings at the end | game-designer | 2026-04-21 | Single document keeps context together for architect in Phase 3; per-era splits were considered but rejected as fragmenting — can split later if size becomes unwieldy |
| 2 | Classification: `raid_target = 1` flag in PEQ is over-inclusive (includes raid-zone trash like Plane of Fear scarelings). Audit classifies each as BOSS / EVENT MOB / ELITE TRASH. Only BOSS + some EVENT MOB entries target for scaling | game-designer | 2026-04-21 | Flag count of 878 raid_targets across Classic-Luclin is dominated by trash-in-raid-zones; true boss count is a fraction of that |
| 3 | Fabled (`#The_Fabled_*`) NPCs at level 70+ flagged as OUT OF ERA, no action | game-designer | 2026-04-21 | Post-Luclin anniversary content; expansion lock should prevent them from spawning |
| 4 | Game-designer writes summary-level quest-chain sections when lore-master contributions didn't arrive; flagged as "pending lore-master deep-review" | game-designer | 2026-04-21 | Lore-master marked all 4 quest-chain tasks completed without adding content to audit doc or sending notes. Phase 1 unblockable without quest-chain coverage (architect needs to know which bosses are quest-required before scaling). Summary-level sections are sufficient for Phase 2 architect triage; lore-master should be re-engaged before Phase 4 implementation of scripted events |
| 5 | PRD prefers per-boss targeted UPDATEs over global npc_scale_global_base type 2 modification | game-designer | 2026-04-21 | Boss HP is manually set per NPC, and recommended cuts vary 2× to 92% by boss. Global scaling would force all bosses to same ratio, which is wrong — Vulak needs 83% cut while Faydedar needs 40%. Per-boss SQL reference pattern is architect-friendly |
| 6 | Plane of Sky Islands 4-8 death-touch mechanics are a separate scaling problem | game-designer + lore-master | 2026-04-22 | Lore-master's epic catalog identified death-touch on Keeper of Souls (Island 4, every 30s), Spiroc Lord (Island 5), Queen Bee (Island 6). Vanilla EQ death-touch is instant-kill regardless of HP/AC. HP scaling alone won't fix these encounters — architect must investigate whether death-touch can be converted to a high-but-survivable hit, or accept Islands 4-8 remain walls |
| 7 | Lore-master Classic epics catalog delivered as SendMessage payload due to Write-tool unavailability | game-designer + lore-master | 2026-04-22 | Lore-master's content filed to `lore-master/epics.md` by game-designer mechanical write. Same pattern to be used for Kunark/Velious/Luclin passes |

---

## Unresolved Threads

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |

### 2026-04-22 — Architect DB verification of death-touch mechanism

**From:** architect (DB investigation)

> After config-expert said "death touch = ability 35 in special_abilities", architect
> queried live DB to verify. Findings contradict that claim:
>
> The three PoSky death-touch NPCs have NO ability 35 in their special_abilities strings:
>  - 71012 Spiroc Lord:   `1,1^10,1^13,1^14,1^15,1^16,1^17,1^21,1^23,1^31,1`
>  - 71072 Bazzt Zzzt:    `1,1^2,1^10,1^13,1^14,1^15,1^17,1^21,1^23,1^31,1^44,1`
>  - 71075 Keeper of Souls:`1,1^2,1^6,1^10,1^13,1^14,1^15,1^16,1^17,1^21,1^23,1^31,1`
>
> Additionally, `SpecialAbility::HarmFromClientImmunity = 35` per
> `eqemu/common/emu_constants.h:562` — that is an IMMUNITY flag, not an attack.
>
> The actual death-touch mechanism is **spell 982 "Cazic Touch"** cast via the NPC
> spell list:
>  - Spell 982: effectid1=0 (HP damage), effect_base_value1=-100000, mana=0, cast_time=0,
>    recast_time=0, targettype=5 (single target). 100k damage on a 60-level player with
>    ~4k HP is instant kill.
>  - Spell list 118 (Spiroc Lord): spell 982 "Cazic Touch" + 988 "Greater Spiroc Thunder"
>  - Spell list 449 (Bazzt Zzzt): spell 982 "Cazic Touch" + 897 "Rotting Flesh"
>  - Spell list 969 (Keeper of Souls): spell 982 "Cazic Touch" + 899 "Whirl Until You Hurl"
>
> **Death-touch removal for Phase 2 should be:**
> ```sql
> DELETE FROM npc_spells_entries
> WHERE npc_spells_id IN (118, 449, 969) AND spellid = 982;
> ```
> — NOT editing special_abilities strings.
>
> **Correction filed:** config-expert's ability-35 hypothesis is incorrect for PoSky.
> The real lever is `npc_spells_entries`. Architecture plan updated accordingly.
> Data-expert owns the DELETE.

**Outcome:** Death-touch removal mechanism corrected in architecture plan. No further
consultation needed on this point — the DB proves the mechanism. Config-expert's other
findings (no rule exists, backup pattern, rampage as special_abilities CSV) remain correct.

---

### 2026-04-22 — Architect PoH layout verification via DB + quest scripts

**From:** architect (DB + script investigation)

> PoH layout verification for Decision #3 ("use whichever is live"):
>
>  - hateplane (zoneid 76): 213 spawn_points, 61 unique NPCs. Only accessible via
>    `zone_points` from `potactics` (PoP zone — not Titanium-era).
>  - hateplaneb (zoneid 186): 491 spawn_points, 189 unique NPCs. Accessible via:
>      1. `oasis/player.lua:4` — clicking door 20 in Oasis triggers MovePCDynamicZone("hateplaneb")
>      2. `oasis/a_wayward_kiraikuei.lua` — Rogue epic DZ expedition to hateplaneb
>      3. `zone_points` from `potimeb` (PoP, not Titanium)
>
> **Conclusion:** Live Titanium-accessible Plane of Hate is `hateplaneb`. This
> matches config-expert's finding (491 vs 213 spawns). Phase 2 PoH scaling targets
> hateplaneb.
>
> The classic `hateplane` spawn list remains populated in DB but is unreachable from
> Titanium classic-era travel paths. Architect recommendation: scale hateplaneb boss IDs
> only; leave hateplane IDs untouched as "reserved" (user can re-enable classic layout
> in future by adding a zone_points entry). Backup table should include both for safety.

**Outcome:** hateplaneb is the live Classic PoH for Phase 2. Scope confirmed.
