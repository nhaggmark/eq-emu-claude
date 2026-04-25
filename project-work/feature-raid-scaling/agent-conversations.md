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

## Phase 5a Architecture Team Conversations

### 2026-04-22 — architect → protocol-agent: Phase 5a Q1-Q10 feasibility questions

**From:** architect → **To:** protocol-agent

Ten targeted feasibility questions: (Q1) Luclin DZ/instance mechanics for all Phase 5a zones, (Q2) Khati Sha zone confirmation, (Q3) Yaemiu elite trash zone boundary, (Q4) Emperor Ssraeshza add-wave mechanism, (Q5/Q9) full DT sweep across all Phase 5a spell lists, (Q6) event-control NPC enumeration, (Q7) MobHealth overflow at 1.25M HP, (Q8) Luclin-specific Titanium client quirks, (Q10) respawn change wire impact.

**Response from** protocol-agent (DB-verified):

Q1: All Phase 5a zones are standard static. `zone` table has no `instancetype` column on this PEQ version — DZ system post-dates Luclin. `#reloadworld` sufficient. Zero DZ opcodes in scope.

Q2: Khati Sha 154145 is script-spawned in `acrylia` (confirmed by quest script location). No spawn2 rows. No VT variant. Phase 5a only, no 5a/5b split needed.

Q3: All Yaemiu-pattern mobs (Eom_*, Pli_*, Zun_*, etc.) spawn exclusively in `vexthal`. Zero in any Phase 5a zone. Phase 5b only.

Q4: Emperor adds are script-spawned only — 4× Ssraezsha from Blood/Golem `event_combat`, 5× shissar_wraith from Emperor `event_death_complete`. Spell 2310 "Rage of Ssraeshza" = SPA11 haste + SPA79 AC debuff + SPA114 ATK debuff — no SPA 46 (SummonPet). `special_abilities 32` = Leash (movement constraint, param0=290 distance). Decision #11 safe — no spell-list changes needed.

Q5/Q9: Full DT sweep across all 30 Phase 5a spell list IDs (mana=0, cast_time=0, SPA 0, value ≤ −10000) returned zero rows. No DT spells in Phase 5a. Seru's `O` npcspecialattks = MeleeImmunityExceptBane (SpecialAbility 22, `npc.cpp:1948`), not a DT flag. Seru's spell 2061 "Torturing Winds" = −300 HP, cast_time=2000 — not instant kill.

Q6: Event-control NPCs to exclude from Phase 5a SQL: 162269 (ssratemple keycheck, 999M HP), 176110 (umbral #Keymaster, 99M HP), 160177/160178 (katta Bella/Heracus Helsin, 1M HP L1), 162065 (Emperor placeholder, no-target), 162260 (#EmpCycle controller). 12× griegsend untargetable trigger NPCs and Akheva flavor/environmental NPCs excluded automatically by raid_target=0.

Q7: `npc_types.hp` is `bigint(20)`. `MobHealth` sends `(int)GetHPRatio()` — percentage only. 1.25M HP is wire-identical to 30k HP. No overflow.

Q8: Zero Luclin-specific Titanium client quirks affecting scaling. Vertical geometry, lighting, faction-war NPCs, Vah Shir/shissar models — all client-side rendering, unaffected by npc_types changes. All Phase 5a zones ruleset=1 except griegsend which has a duplicate row at ruleset=0 (two zone table entries for griegsend — flag for config-expert).

Q10: Same as Phases 2-4b. spawn2.respawntime is server-internal; zero client opcodes fire from the change.

**Outcome:** All 10 questions answered. Phase 5a confirmed 100% SQL. Protocol-agent consultation complete.

---

### 2026-04-22 — protocol-agent → architect: Phase 5a protocol consultation complete

**From:** protocol-agent → **To:** architect

Delivered full Phase 5a Luclin non-VT protocol consultation.

**Summary:** Phase 5a is 100% server-side. Zero opcode additions, struct modifications, or Titanium translation layer changes required. All 8 Phase 5a zones (ssratemple, akheva, griegsend, sseru, katta, thedeep, acrylia, umbral) are standard static zones with no DZ/expedition usage. Zero HP-percentage event hooks found — boss HP can be freely reduced without breaking any scripted thresholds.

**Key scripted encounters confirmed safe:**
- Emperor Ssraeshza event chain (EmpCycle qglobals + unique_spawn + signalwith) — kill-gate is NPC-presence based, not HP-based
- Vyzh`dra multi-form chain (Cursed/Exiled/Banished/Glyphed/Runed) — same qglobal + spawn2 pattern as Kerafyrm Phase 4b
- Shei Vinitras spawn-swap + 5-min periodic add rewave — standard spawn-swap, server-side timer
- Grieg Veneficus dual-guardian entity-presence gate — same pattern as VP/Vulak
- Lord Inquisitor Seru placeholder→real boss timer-swap — same as Tunare Phase 4a
- Khati Sha periodic combat adds (every 2 min) — server-side timer spawns
- Burrower Beast wave event (The Deep) — proximity-triggered waves, no DZ

**Three architect flags raised:**
1. **Flag A — EmpCycle timers need perl-expert:** `$EmpRepopTime` (3-5 day respawn) and `$BloodCoolDownTime` (3-4h failure cooldown) in `#EmpCycle.pl` are Perl locals, not SQL/rule_values. Tuning requires perl-expert edit.
2. **Flag B — Shei Vinitras two NPC IDs:** Audit catalogs 179157 (merchant trigger form). Real fight boss is 179032. Both may need separate UPDATE rows with different HP targets.
3. **Flag C — Vyzh`dra intermediate forms:** 162206 is the kill target. 162232 (Exiled), 162214 (Banished), 162261 (Glyphed serpent), 162253 (Runed serpent) are pre-event chain forms. Emperor placeholder 162065 should be excluded from scaling SQL.

**Outcome:** Consultation delivered to architect. Awaiting architect's follow-up if any.

---

## Phase 4b Architecture Team Conversations

### 2026-04-22 — architect → config-expert: Phase 4b config posture consult

**From:** architect → **To:** config-expert

Six questions: (1) rule_values drift check, (2) zone-scoped rulesets for templeveeshan/sleeper, (3) endgame-specific globals and MR-cap/dragon-breath rules, (4) signature-mechanics rule interactions, (5) respawn timer rules, (6) data_buckets/spawn_conditions posture for Sleeper's Tomb awake event.

**Response from** config-expert:

Zero concerns across all six questions. Confirmed:
1. rule_values count = 1,112 — no drift since Phase 2 baseline.
2. templeveeshan and sleeper both ruleset=1, min_status=0, expansion=2. No custom ruleset overrides.
3. All seven prior-pass globals intact. No dragon-breath modifier, no MR-cap rule exists. `Combat:DragonPunchBaseDamage=12` is monk skill, unrelated to dragon NPCs. Vyemm MR=1000 is npc_types.MR only — no rule can override it.
4. No `RaidTargetFlurryMultiplier` or equivalent rule. `Bots:DisableSpecialAbilitiesAtMaxMelee` applies to Bots only. `Spells:CharmDisablesSpecialAbilities=false`. No rule amplifies special_abilities on raid_target NPCs.
5. No respawn clamp or randomization rules. BUT: all 10 Phase 4b bosses have zero standing spawn2 rows — event-triggered/condition-gated only. Decision #8 endgame=24h has no applicable rows to update. No spawn2 timer changes needed for Phase 4b.
6. Kerafyrm awake state is spawn_conditions only (condition_id=1 value=0 dormant, condition_id=2 value=1 active). Zero data_buckets and zero variables entries. No config concern. Per Decision #12 Kerafyrm is out of Phase 4b scope.
Bonus: death-touch sweep of all 9 Phase 4b bosses with spell lists = zero rows. No npc_spells_entries DELETEs needed. Zone-restart caveat does not apply.

**Outcome:** Config posture confirmed. Phase 4b is 100% SQL, no rule changes, no config changes. #reloadworld sufficient post-SQL. Config-expert role identical to Phases 2/3/4a. Full findings in `config-expert/dev-notes.md` Phase 4b section.

### 2026-04-22 — architect → config-expert: Phase 4b spawn2 scope correction

**From:** architect → **To:** config-expert

Scope correction: config-expert's "all 10 Phase 4b bosses have zero spawn2 rows" was accurate for the 10 headline bosses examined but full Phase 4b scope is 47 NPCs. Only AoW (113457) and Vulak (124155) have zero spawn2 rows. The other 45 have 1-3 rows each. Phase 4b WILL update spawn2.respawntime for ~32 rows to 86,400s. All core rule/config findings (zero rule changes, zero MR-cap, zero death-touch, etc.) still hold — scope error only. Implementation tasks B9/B10: #reloadworld + smoke-verify 47 npc_types rows + ~32 spawn2 rows + untouched-verification on Kerafyrm trio/spell 1948/spawn_conditions/Defenders.

**Response from** config-expert:

Acknowledged. dev-notes.md Phase 4b section updated with scope correction. Core findings unchanged; spawn2 zero-rows claim amended to: only AoW and Vulak have no spawn2 rows; 45 other Phase 4b NPCs have standing rows and ~32 will be updated to 86,400s. Config-expert role updated: smoke verification now covers both npc_types HP/damage (47 NPCs) and spawn2.respawntime (~32 rows) per architect's UPDATE list, plus untouched-verification items.

**Outcome:** Correction incorporated. No rule or config impact — purely a spawn2 scope clarification.

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

**Response from** data-expert (2026-04-22):

> Tasks 1-6 fully applied and verified. DB state confirmed:
> - Backup tables: all three exist (npc_types: 2548 rows, spawn2: 6669 rows, npc_spells_entries: 6 rows)
> - Nagafen (32040): hp=14400; Vox (73057): hp=14400; CT (72003): hp=80000/maxdmg=450
> - Innoruuk hateplaneb (186158): hp=60000/maxdmg=500
> - Spell 982 in lists 118/449/969: 0 rows (confirmed deleted)
> - All post-change verification queries passed
> - Commit 0de6639 pushed to feature/raid-scaling; working tree clean
> Config-expert cleared to proceed with Tasks 7 and 8.

**Response from** config-expert (2026-04-22):

> Tasks 7 and 8 complete. All smoke checks pass.
> - #reloadworld issued via world telnet console (port 9000) — response: "Reloading World..."
> - Nagafen (32040): HP 14,400 / respawn 21,600s (6h) ✓
> - Vox (73057): HP 14,400 ✓
> - CT (72003): HP 80,000 ✓
> - Innoruuk revamp (186158): HP 60,000 ✓
> - Keeper of Souls (71075): HP 22,000 ✓
> - Spiroc Lord (71012): HP 22,000 ✓
> - Enraged Golem (72106): HP 40,000 ✓
> - Spell 982 in lists 118/449/969: 0 rows ✓
> Flag: npc_spells_entries spell list cache loads at zone boot, not on #reloadworld.
> DB deletions confirmed but a running PoSky zone that already cached those lists
> still has spell 982 in memory. If death-touch is observed in-game after player
> zones into PoSky, infra-expert Task 9 (full restart) is required.
> Changes committed and pushed (commit 41ebfc4).

**Outcome:** Tasks 7-8 complete. All Phase 2 SQL changes are live and verified.
One pending risk: PoSky spell list cache requires zone boot to clear — death-touch
removal only guaranteed after PoSky zone process restarts. Task 9 (infra-expert
full restart) is conditional on whether player observes death-touch in-game.

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

---

## Architecture Team — Phase 3: Kunark (2026-04-22)

### 2026-04-22 — protocol-agent Phase 3 initial read to architect

**From:** protocol-agent  
**To:** architect  
**Date:** 2026-04-22

> Phase 2 was fully server-side (confirmed). For Phase 3 Kunark I've completed
> my consultation. Initial read: Phase 3 is also fully server-side — no protocol
> concerns. Specific items I investigated:
>
> 1. **Phara Dar HP-event add-wave script** — `quest::setnexthpevent(N)` uses HP
>    percentage not absolute value, so scaling HP from 681k to ~120k preserves
>    the 80/60/40/20% add-wave triggers exactly. No protocol impact.
>
> 2. **Venril Sathir two-form transition** — `spawn2`/`depop` pattern in Perl script.
>    Client sees standard DeleteSpawn/NewSpawn packets. HP scaling on both form IDs
>    safe. No protocol impact.
>
> 3. **VP door-gate** — `veeshan/player.pl` checks entity presence for 5 outer
>    dragons and calls `quest::forcedooropen()`, which sends `OP_MoveDoor`. No DZ
>    or Expedition API involved. Standard open zone. No protocol impact.
>
> 4. **No DZ/Expedition for any Kunark encounter** — All VP scripts and Karnor
>    scripts surveyed. None use MovePCDynamicZone or ServerOP_Expedition*. VP is
>    a flat open zone.
>
> 5. **npcspecialattks trimming (Trakanon flurry, etc.)** — same server-side AI
>    pattern as Phase 2 CT rampage trim. No protocol impact.
>
> **Full findings in:** `protocol-agent/dev-notes.md` Phase 3 section.
>
> **Phase 3 verdict: 100% server-side SQL, identical conclusion to Phase 2.
> No opcode additions, no struct changes, no Titanium translation layer changes.**

**Outcome:** Phase 3 protocol consultation complete. Architect cleared to proceed
with Kunark architecture plan without protocol blockers.

---

### 2026-04-22 — architect Q&A: Phase 3 Kunark scope questions

**From:** architect  
**To:** protocol-agent  
**Date:** 2026-04-22

Three questions on Phase 3 Kunark scope (Trakanon variants, VP revamp IDs
108040-108053, epic-adjacent NPCs, chardok/outdoor dragons):

1. Any client-visibility concerns with HP scaling (e.g. Trakanon 454k → 50-70k)?
2. VP revamp variants (108040-108053) — any Titanium model/size/packet quirk?
3. Script-spawned NPC variants inheriting modified npc_types values — any concern?

---

**From:** protocol-agent  
**To:** architect  
**Date:** 2026-04-22

All three questions: no concerns. Full answers:

**Q1:** `MobHealth` sends integer 0-100 percentage only. `NewSpawn_Struct.curHp` is
uint8 percentage. `/consider` is level-derived. `npc_types.hp` is bigint(20) — no
overflow. HP scaling from any value is invisible to the Titanium client. Confirmed.

**Q2:** VP dragon race IDs are standard Titanium-era models. NPC IDs (108040-108053)
are internal server values — never appear in any client packet (entity IDs are used
in-zone). `NewSpawn_Struct` size is fixed regardless of NPC stats. No DZ/instance
protocol — VP is standard open zone with `OP_MoveDoor` door-gate (already confirmed
in Phase 3 pre-consultation). No Titanium-specific quirk.

**Q3:** `quest::spawn2(npc_id)` reads `npc_types` from the zone's in-memory cache
(populated at boot / `#reloadworld`). Script-spawn path uses the same NPC construction
codepath as static spawns. Client sees a standard `NewSpawn_Struct` event. SQL changes
to `npc_types` take effect on next script spawn after `#reloadworld`.

**Implication for data-expert:** triggered-only NPCs (no spawn2 table row) silently
skip `spawn2.respawntime` UPDATEs, but `npc_types.hp`/`maxdmg` UPDATEs still apply
and take effect on next script spawn. Same pattern as Phase 2 Q13 Enraged Golem.

**Outcome:** All Phase 3 changes remain SQL-only. No opcode additions, struct changes,
or Titanium translation layer changes needed. Architect cleared to proceed with
`kunark-architecture.md`.

---

### 2026-04-22 — Config-expert Phase 3 architect Q&A (4 direct questions)

**From:** architect → **To:** config-expert

> 1. Confirm no new rule_values added since Phase 2 apply (2026-04-22) affecting Kunark tuning.
> 2. Confirm SQL via npc_types/spawn2/npc_spells_entries remains the correct mechanism.
> 3. Any rule_values with Kunark-era semantics? Zone-scoped rules on kaesora/karnor's/chardok/veeshan?
> 4. Decision #5 says 12h for VP/Trakanon/outdoor Kunark dragons — confirm reading.

**Response from** config-expert → architect (2026-04-22):

> **Q1 — No new rules since Phase 2:** Confirmed via live DB query. All prior-pass
> globals unchanged: NPCFlurryChance=12, MaxRampageTargets=2, NPCAssistCap=3,
> StartEnrageValue=5, GlobalLootMultiplier=2, CurrentExpansion=3,
> AllowRaidTargetBlind=false. Total rule_values count: 1,112. No Kunark-specific
> entries added. Note: `Combat:DefaultRampageTargets` returns two rows (both value=1)
> — pre-existing duplicate artifact, not a new change.
>
> **Q2 — SQL remains the correct mechanism:** Confirmed. No config-layer lever
> emerged for Kunark. Keyword search for Kunark/VP/Dragon/Raid in rule_values
> returns only general-purpose rules already catalogued in Phase 2. No zone-aware
> or era-aware tuning rules exist in the rule system.
>
> **Q3 — No zone-scoped rules:** Confirmed none. EQEmu rule system has no per-zone
> scoping. veeshan, sebilis, karnor, and chardok all use `zone.ruleset=1` ("default")
> — same as 217 other standard zones. No custom ruleset applied to any Kunark raid zone.
>
> **Q4 — 12h for Kunark mid-tier confirmed:** Decision #5 text is explicit:
> "12h mid (PoSky, Trak, VP, most Velious)." 43,200s is the correct target for
> Trakanon, all VP revamp variants (108040-108053), and outdoor Kunark dragons.
>
> **Additional flags for architecture planning:**
>
> - **VP dual spawn2 populations:** Both revamp (108040-108053, ~75-81h) and classic
>   (108509-108517, ~18-24h) variants have standing spawn2 rows. Data-expert must
>   scope all UPDATEs by NPC ID list, not zone-sweep. Classic variants may not need
>   the 12h treatment since they're already shorter.
>
> - **Chardok Royals already at 1.5h (5,400s):** Queen Velazul (103055), Overking
>   Bathezid (103056), Prince Selrach Di'zok (103080). These are BELOW the 12h
>   mid-tier target — architect should decide: leave at 1.5h, bump to 12h for
>   consistency, or treat as a separate short-respawn tier.
>
> - **Fabled exclusion in Chardok:** `#The_Fabled_Prince_Selrach_Di'zok` (ID 103218,
>   HP 1.5M) has a spawn2 in chardok. Same `name NOT LIKE '#The_Fabled%'` filter
>   as Phase 2 recommended.
>
> - **No Kunark death-touch spell-list issues found:** No 0-cast-time instakill
>   analogous to PoSky spell 982 identified in VP/Sebilis/Karnor/Chardok data.
>   No npc_spells_entries DELETEs anticipated — but verify Trakanon/VP dragon
>   spell lists if architect finds 0-cast-time outliers.

**Outcome:** All four questions confirmed. Phase 3 uses identical SQL-only pattern
as Phase 2. Three decision flags handed to architect: VP dual-population scoping
(data-expert must use NPC ID list), Chardok Royals respawn direction, Fabled
exclusion filter. Config-expert Phase 3 implementation role: post-SQL #reloadworld
via world telnet port 9000, smoke verification — same as Phase 2 Tasks 7-8.

---

### 2026-04-22 — architect Phase 3 Kunark architecture complete

**From:** architect (to orchestrator)  
**Date:** 2026-04-22

Phase 3 Kunark architecture complete. Summary of findings and deliverables:

**Deliverables:**
- `architect/kunark-architecture.md` (505 lines) — full architecture plan mirroring Phase 2 structure
- `architect/context/kunark-db-investigation.md` (149 lines) — live DB confirmation of every Kunark raid_target NPC, VP condition-gated variant resolution, Q13 Kunark NPC disposition, and death-touch audit results

**Key technical findings:**
1. **VP variants definitively resolved via `spawn_condition_values`:** revamp (108040-108053) live under condition 2=1 (VeeshanNew enabled), classic (108509-108517) dormant under condition 1=0 (VeeshanOld disabled). Per Decision #5 we scale only revamp; classic backed up for safety only. VP respawn UPDATE must scope `s2._condition = 2` to avoid touching dormant rows.

2. **Zero death-touch spells in Kunark raid bosses.** DB query for Cazic-Touch-profile spells (mana=0, cast_time=0, effect < -10000) returned empty. Highest damage DD: Nexona's Dragon Harm Touch at -4000 HP / 45s recast — signature mechanic per Decision #11. No `npc_spells_entries` DELETEs needed. **Phase 3 is 100% SQL UPDATEs against npc_types + spawn2 only.**

3. **Q13 Kunark NPC resolution:** Xenevorash (85208), Vessel Drozlin (106008), Thrackin Griften (12172), Caradon (39069), Kyrenna (39155), Mummy of Glohnor (39165), both Tortured Soul variants (51144, 214078) — ALL at named-tier HP already. No Phase 3 action needed for any of them. The Tangrin (78070) also named-tier and raid_target=0, deferred.

4. **Renux Herkanor multi-ID:** 2033 (Classic qeynos2 L61), 12032 (Classic qey2hh1 L51), 56172 (dormant dup), and 448200 (L72 500k HP, raid_target=1, script-spawned Monk epic terminus). Only 448200 is in-question for Kunark scope — flagged to user.

5. **Triggered Trakanon (#Trakanon 89181):** 16k HP already (half the standard Trakanon). No HP change needed. Captured in backup for safety.

**Implementation task count:** 9 (K1-K9), same structure as Phase 2's 10 tasks.

**Required agents for implementation phase:**
- data-expert (primary — Tasks K1-K5, K9)
- config-expert (Tasks K6-K7 — #reloadworld + smoke verify)
- infra-expert (Task K8, conditional — full-stack restart if #reloadworld fails, unlikely since no npc_spells_entries changes)

**NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent.

**TWO USER DECISIONS REQUIRED BEFORE IMPLEMENTATION:**
- **Decision #21:** Chardok Royals (103055/103056/103080) currently respawn at 1.5h. Decision #5 mid-tier says 12h. Options A/B/C — architect recommends A (leave at 1.5h; "short tier" treats royals as already appropriately tuned).
- **Decision #22:** Renux Herkanor 448200 (L72 500k HP, Monk epic Kunark terminus). Options A/B — architect recommends A (include, apply HP cut; L72 is a PEQ scripting artifact and gating Monk epic on small-group server is intended unblock per Phase 2 precedent).

**Outcome:** Architecture complete. Status.md updated with Phase 3 task table, two new Open Questions (#21, #22), two new Decision Log entries (pending user resolution), and Phase 3 handoff log. Ready to hand to orchestrator for user decision gate → then implementation team dispatch.

---

### 2026-04-22 — architect clarifying questions on Phase 3 finalization

**From:** architect  
**To:** protocol-agent  
**Date:** 2026-04-22

Phase 3 architecture doc and DB investigation committed (commit fb9c562).
Two clarifying questions:

1. Trakanon flurry: plan does NOT edit npcspecialattks/special_abilities per
   Decision #11 — relying on global NPCFlurryChance=12 cap. Confirm no edit needed?
2. VP door-gate partial-state: if dragon is GM-depopped mid-fight without dying,
   does entity-presence check handle it cleanly?

---

**From:** protocol-agent  
**To:** architect  
**Date:** 2026-04-22

**Q1:** Confirmed — no flurry-string edit needed. `NPCFlurryChance=12` caps all NPCs
server-wide including Trakanon. Leaving `SERFMCNDf` intact is correct per Decision #11.

**Q2:** Door-gate re-checks entity presence live at each click via
`entity_list->IsMobSpawnedByNpcTypeID()` — no persistent "dragon killed" state cached.
This means a GM-depopped dragon (removed from entity list while still alive) is treated
as absent, so the door may open prematurely. Conversely `#repopzone` re-locks the door.
Both are pre-existing behaviors in the script unrelated to Phase 3 HP scaling.
Normal kill path (all five outer dragons die → entity list empty → door opens) works
correctly. Flagged as a one-liner risk note candidate in the architecture doc; no Phase 3
action needed.

**Outcome:** Architecture doc confirmed clean from protocol layer. Phase 3
consultation complete with no remaining open items.

---

### 2026-04-22 — Config-expert Phase 3 flags resolved (architect close-out)

**From:** architect → **To:** config-expert

> All three flags folded into architecture doc:
> 1. VP dual populations — resolved via spawn_condition_values (condition 2=1 for revamp, condition 1=0 for classic dormant). Phase 3 respawn UPDATE scopes `s2._condition = 2`.
> 2. Chardok Royals — flagged as Decision #21 (A=leave 1.5h / B=12h / C=6h). Architect recommends A.
> 3. Fabled Prince Selrach exclusion — added as explicit addendum (commit d937ec8). Phase 3 UPDATEs are ID-list-scoped so Fabled rows won't leak in regardless.
> 4. No death-touch in Kunark confirmed independently — zero npc_spells_entries DELETEs. Highest DD is Nexona Dragon Harm Touch -4000 HP / 45s recast (signature mechanic, keep per Decision #11).
> Phase 3 architecture complete. Config-expert implementation role: Tasks K6 (#reloadworld) and K7 (smoke verify) — same as Phase 2 Tasks 7-8. Awaiting user decisions #21 and #22 before implementation dispatch.

**Response from** config-expert (acknowledged):

> All flags resolved cleanly. VP spawn_condition_values approach is the right
> scoping mechanism — `s2._condition = 2` is precise and avoids any classic
> variant contamination. No concerns with the architecture as described.
> Standing by for implementation dispatch after user decisions #21 and #22.

**Outcome:** Phase 3 architecture consultation fully closed. All config-expert
flags incorporated. Two user decisions (#21 Chardok respawn, #22 Renux Herkanor
448200) remain before implementation team can be dispatched. Config-expert role
confirmed as Tasks K6-K7 (identical to Phase 2 Tasks 7-8).

---

### 2026-04-22 — architect Phase 3 architecture finalized (commit 054ba8a)

**From:** architect  
**To:** protocol-agent  
**Date:** 2026-04-22

Both protocol-agent confirmations locked into architecture doc:
1. Trakanon flurry — no special_abilities edit; SERFMCNDf preserved per Decision #11.
2. VP door-gate GM-depop edge case — added as one-line risk table row, flagged pre-existing.

Architecture doc final: `architect/kunark-architecture.md` (536 lines, commit 054ba8a).
Waiting on user decisions #21 (Chardok Royals respawn) and #22 (Renux Herkanor 448200)
before implementation dispatch.

**Outcome:** Phase 3 architecture complete. Protocol-agent consultation role for
Phase 3 closed. No open items.

---

## Architecture Team — Phase 4a: Velious non-ToV (2026-04-22)

### 2026-04-22 — protocol-agent Phase 4a initial assessment to architect

**From:** protocol-agent
**To:** architect
**Date:** 2026-04-22

Delivered Phase 4a Velious non-ToV protocol consultation. Summary:

**Verdict: 100% server-side, zero Titanium client protocol impact — same as Phases 2 and 3.**

Key findings:

1. **Coldain Ring War (ring_war.lua):** Uses `eq.spawn_condition()` to toggle 21 wave
   conditions + `eq.signal()` / timers for wave pacing. No DZ, no Expedition, no special
   client opcodes. Client sees only normal NewSpawn_Struct / DeleteSpawn_Struct per wave
   mob. Wave-mob HP scaling is pure SQL. `wave_cooldown_time = 5*60*1000` is a Lua local —
   lua-expert can reduce it if architect wants to address the small-group throughput problem.

2. **Kael faction gating:** `King_Tormax.lua` uses server-side `GetFaction()` check — no
   client-cached faction state. Faction data is server-only. Client sees NPC speech /
   trade results only.

3. **Statue→Idol→Avatar spawn chain:** Both scripts use `eq.unique_spawn()` — standard
   `NewSpawn_Struct` to client. Same pattern as VP Phase 3 door-gate (`quest::forcedooropen` +
   entity presence). Avatar has a 1-hour depop timer (server-side only).

4. **Plane of Growth Tunare:** `#_Tunare.lua` spawns fight form (127098) on combat via
   `eq.spawn2()` with zone-wide aggro, then depops tree form. Standard spawn-swap — same
   pattern as VS form-transition in Phase 3.

5. **No DZ/Expedition anywhere in Velious non-ToV:** Grepped greatdivide, kael,
   growthplane, skyshrine, westwastes, necropolis. Zero DZ/Expedition usage.

Flag for architect: Ring War wave-mob scaling and wave-timer reduction require data-expert
(SQL) + lua-expert (script edit) respectively. Architect should decide scope of Ring War
work for Phase 4a vs. deferral.

Full findings in `protocol-agent/dev-notes.md` Phase 4a section.

**Outcome:** Phase 4a protocol consultation complete. Architect cleared to proceed
with Velious non-ToV architecture plan without protocol blockers.

---

### 2026-04-22 — architect Phase 4a targeted feasibility questions → protocol-agent

**From:** architect
**To:** protocol-agent
**Date:** 2026-04-22

Four targeted questions on Phase 4a client feasibility:
1. Kael Avatar chain (Statue→Idol→Avatar): any client-visible state if we scale Statue/Idol in 4a and hold Avatar for 4b?
2. Plane of Growth event-control NPCs (`a_warm_light` L1 1M HP, `a_thifling_focuser` L65 1M HP): any Titanium anomaly from unusual level/HP combination?
3. Dragon Necropolis Jaled Dar's Shade (3M HP, turn-in NPC not kill target): any client display concern?
4. Icewell Keep (thurgadinb): standard zone or DZ/instance? Dain Frostreaver IV is there.
5. Ring War Lua changes: does client care about wave count reduction?
6. Respawn timer UPDATEs: any Ring War interaction?
7. Any Velious-specific opcodes/structs to know about?

---

### 2026-04-22 — protocol-agent response to architect Phase 4a feasibility questions

**From:** protocol-agent
**To:** architect
**Date:** 2026-04-22

All four questions answered. Summary:

**Q1 — Kael Avatar chain staggered scaling:** Clean. Chain is `eq.unique_spawn()` on
`event_death_complete` — standard `NewSpawn_Struct` per step. No client-cached phase
state. Scaling Statue (113071) and Idol (113341) in 4a while holding Avatar (113457)
for 4b creates zero client anomaly.

**Q2 — Growth event-control NPCs (L1/L65 at 1M HP):** No client anomaly. Titanium
renders HP as uint8 percentage — no level/HP coherence check. `/consider` shows green
(L1) or level-appropriate con (L65). Cosmetically expected for event mobs. Leave as-is.

**Q3 — Jaled Dar's Shade at 3M HP:** No client concern. `MobHealth` sends
`(int)GetHPRatio()` — 3M HP and 30k HP are identical on the wire (percentage only).
`/consider` shows red (L70 same-level), which is correct for an unkillable turn-in
guardian. Leave at 3M HP.

**Q4 — thurgadinb:** Standard static outdoor zone, not a DZ/instance. Confirmed no
`MovePCDynamicZone` in any thurgadinb script. Dain Frostreaver IV (129003) is a normal
static spawn. HP scaling via `npc_types` UPDATE is identical to any outdoor boss.

**Q5 — Ring War Lua wave changes:** No client impact. `eq.spawn_condition()` is
server-internal state — no opcode to client. Client only sees NewSpawn/DeleteSpawn
per wave mob. No client concept of "wave N of 21."

**Q6 — Respawn timer / Ring War interaction:** Zero interaction. Ring War uses
`spawn_condition` gating (not `spawn2.respawntime`) for wave mobs. Narandi's
out-of-event respawn (spawn2) is an independent system. Changing Narandi's respawntime
to 24h has no effect on Ring War event mechanics.

**Q7 — Velious-specific opcodes:** None. All Phase 4a zones use standard
`ZoneChange_Struct` → `ZoneServerInfo_Struct` entry flow. No Velious-era opcode
was added to the Titanium client. All scripted mechanics resolve to standard
spawn/despawn/combat packets.

**Phase 4a verdict: zero client protocol impact. Proceed with confidence.**

**Outcome:** Architect cleared on all four questions. Phase 4a architecture can
proceed without any protocol-layer constraints or workarounds.

---

### 2026-04-22 — Config-expert Phase 4a consultation to architect

**From:** config-expert
**To:** architect
**Date:** 2026-04-22

Delivered Phase 4a Velious non-ToV config consultation. Queried live DB: all
Velious non-ToV zone ruleset/min_status, rule_values for any Velious/Ring/Coldain/
event keywords, full deduped raid_target=1 NPC stats for kael/skyshrine/growthplane/
mischiefplane/westwastes/eastwastes/sleeper, and read `ring_war.lua` in full.

**Core finding: Phase 2/3 config conclusions carry forward unchanged. No new rules.
SQL-only. #reloadworld via world telnet port 9000. No npc_spells_entries DELETEs
anticipated for Phase 4a.**

Key flags for architect:

1. **All Velious non-ToV zones: ruleset=1, min_status=0.** No custom ruleset on any zone.
   PoM and PoG are standard zones — the maze is geometry, not a server rule.

2. **Lord Yelinak dupe:** Two rows in skyshrine — ID 114106 (500k HP) and ID 114618
   (297k HP), both L70, both at 259,200s. Data-expert must scope by ID; architect
   should determine which is live.

3. **Sir Elmonious Falmont (120133):** 400k HP, **3,667 maxdmg** at L70. Extreme
   maxdmg — architect decision needed on trim.

4. **All-Seeing Eye (126374):** 1,200s (20min) respawn in PoM — anomalously short for
   a raid boss. Likely event-triggered. Verify before including in respawn changes.

5. **PoG population:** 80+ raid_target=1 entries, most are named trash (16-32k HP,
   18h respawn). True bosses are Tunare (127001) and Guardian of Tunare (127007).
   `a_warm_light` (127004, L1, 1M HP) and `a_thifling_focuser` (127005/127006, L65,
   1M HP) are suspicious — architect should verify before cutting.

6. **Sleeper placeholder NPCs:** Many `sleeper` raid_target=1 NPCs are scripted
   dead-body/event entities (IDs 128057-128088, names `Area8mob6dead`, `StaticShoutOne`,
   `A_warning`, etc.) at HP=11, level=1. Any data-expert UPDATE on sleeper MUST exclude
   these — e.g. `AND n.hp > 1000 AND n.level > 10`.

7. **Ring War: one Lua tunable.** `wave_cooldown_time = 5 * 60 * 1000` at
   `ring_war.lua:26` — 5 minutes between waves. It is a Lua local, not a rule or DB
   column. Reducing it requires lua-expert. No death-touch or spell 982 equivalent in
   any Ring War NPC. Wave-mob HP cuts follow standard npc_types UPDATE pattern.
   `ringtenmaster` (118173) is a pure script controller (raid_target=0, npc_spells_id=0).

**Config-expert Phase 4a implementation role:** Identical to Phases 2 and 3 — no rule
changes, no config file changes, post-SQL #reloadworld, smoke verification.

Full findings in `config-expert/dev-notes.md` Phase 4a section.

**Outcome:** Config consultation delivered to architect. Awaiting architect response /
any follow-up questions before Phase 4a architecture doc is finalized.

---

### 2026-04-22 — Architect targeted rule check (5 questions) + config-expert response

**From:** architect → **To:** config-expert
**Date:** 2026-04-22

Five targeted questions (budget: expected "all Phase 2/3 patterns hold"):
1. Confirm rule_values count ~1,112 and all prior-pass globals unchanged since Phase 2.
2. Any Velious-zone-scoped rulesets (kael, skyshrine, growthplane, templeveeshan, westwastes, eastwastes, greatdivide, thurgadinb)?
3. Any rules affecting Ring War wave-spawn cadence, fort-event respawn timers, or signal-based events?
4. Any faction-scaling rules (Character:FactionHitRate, Character:FactionOverride) that interact with Velious faction gates?
5. Any other non-default Velious-adjacent tunable?

**Response from** config-expert → architect (2026-04-22):

Live DB re-queried to confirm. All five clean:

**Q1:** rule_values count = 1,112 (exact). All seven prior-pass globals verified unchanged:
NPCFlurryChance=12, MaxRampageTargets=2, NPCAssistCap=3, StartEnrageValue=5,
GlobalLootMultiplier=2, CurrentExpansion=3, AllowRaidTargetBlind=false. Zero drift.

**Q2:** All Velious zones confirmed ruleset=1, min_status=0: kael, skyshrine, growthplane,
mischiefplane, westwastes, eastwastes, sleeper, templeveeshan, greatdivide, thurgadinb.
No zone overrides anywhere in the table.

**Q3:** Zero rules for Ring War. `wave_cooldown_time = 5 * 60 * 1000` at `ring_war.lua:26`
is a Lua local — not a rule, not a DB column. `eq.spawn_condition()` and `eq.signal()` are
pure engine calls with no rule-layer backing.

**Q4:** No `Character:FactionHitRate` or `Character:FactionOverride` rules exist in the
table at all. Faction rules present are threshold band definitions only (Ally=1100,
Warmly=750, Kindly=500, Indifferently=0, Apprehensively=-100, Dubiously=-500,
Threateningly=-750). Velious faction gates operate through `npc_faction_id` / `faction_list`
/ `faction_list_mod` tables — pure DB data, zero rule-layer interaction. Decision #14 stands.

**Q5:** Nothing non-default and Velious-adjacent. No Kael/Skyshrine/Growth/ToV-adjacent
rule in the table. All custom rules are companions-system or expansion-lock entries already
catalogued.

**Outcome:** All Phase 2/3 patterns confirmed for Phase 4a. SQL-only, zero rule changes,
zero config file changes. Config-expert consultation for Phase 4a architecture is complete.

---

### 2026-04-23 — architect spawned for Phase 4a, verified prior consultations

**From:** architect (team `raid-scaling-velious-a-architecture`)
**Date:** 2026-04-23

On spawn, architect reviewed:
- agent-conversations.md to confirm prior (2026-04-22) Phase 4a consultations from
  protocol-agent and config-expert. Both consultations delivered complete findings.
  Architect incorporated findings directly into architecture doc Addenda section without
  redundant re-consultation.
- Architect sent fresh consultation to lore-master for Phase 4a scoped task:
  - Q8 Coldain Ring War (architect-assigned) — A/B/C recommendation
  - Coldain Prayer Shawl raid-tier assessment
  - Faction-gate confirmations (Yelinak, Dain, Tormax)
  - Ring 8/Ring 9 UX softening scope check
  - Idol of Rallos Zek spawn chain confirmation
  - Velious Epic 1.0 steps re-confirmation

Also re-sent (for completeness/record) scoped consultations to protocol-agent and
config-expert with Phase 4a-specific framing. Prior 2026-04-22 responses are authoritative
per agent-conversations.md entries and have been folded into architect doc.

**Outcome:** Architect proceeds with architecture doc drafting. Waiting on lore-master
Q8 final recommendation before finalizing Decision #23. Draft recommendation (Option B+
wave-skip) is in the doc pending lore-master review.

---

### 2026-04-23 — architect DB investigation of Velious non-ToV content

**From:** architect
**Date:** 2026-04-23

Architect ran comprehensive DB investigation of Velious non-ToV raid NPCs. Key findings
documented at `architect/context/velious-a-db-investigation.md`:

- **~35 in-scope raid-tier bosses** confirmed live with active spawn2 (or script-spawn
  in Idol/Narandi cases)
- **Zero death-touch-profile spells** on Phase 4a bosses (DB sweep vs Phase 2 spell 982
  pattern: mana=0, cast_time=0, damage <= -10,000) — zero rows returned. No
  `npc_spells_entries` DELETEs needed.
- **Lord Yelinak dual variants** (114106 500k HP, 114618 297k HP) BOTH live with
  independent spawn2 rows, both `_condition=0`. Recommendation: scale both to 110k HP.
- **Narandi's spawn2** uses `_condition=16, cond_value=1` (script-gated to Ring War wave
  15 completion). Respawn 749999s is effectively dead time — the event drives it.
- **Ring War wave composition** via `spawn_conditions`: 13 wave conditions (RingWarWave1
  through Wave15) + condition 16 = Narandi. ~190 total Kromrif giants across waves.
  Lua drives pacing via 5-min timer. `wave_cooldown_time = 5 * 60 * 1000` is a Lua local.
- **Event-trigger NPCs** confirmed: a_warm_light (L1, 1M HP, 2-9 dmg, 8 spawn2 rows),
  a_thifling_focuser (2 NPC IDs, 1M HP each, 4 total spawn2 rows). Leave untouched per
  audit.
- **Jaled Dar's Shade (3M HP uncombattable)** confirmed per lore-master. Leave untouched.
- **High-damage signature spells** preserved (no DT): Velketor's Sunstrike (-1800) /
  Superior Sundering (-2000) 7s cast time, Tunare/PoG boss Summer's Flame (-1600),
  Winter's Frost (-1375), Kelorek Entomb in Ice (-1000) 0-cast 18s recast, Faleniel Ice
  Rain (-1000) 0-cast 35s recast. All survive Decision #11 preservation filter.

Full Phase 4a target value table and SQL sketch in architecture doc.

**Outcome:** DB layer cleared for implementation dispatch (after Decision #23 resolution
via lore-master response).


---

### 2026-04-23 — architect adopts lore-master Q8 recommendation over original draft

**From:** architect → **To:** lore-master, protocol-agent, config-expert (FYI)
**Date:** 2026-04-23

Lore-master delivered comprehensive Q8 resolution + Phase 4a sign-off. Architect adopts
their Lever 1 (SQL wave-mob HP cuts) + conditional Lever 2 (Lua cooldown bump) approach
over my original Option B+ wave-skip draft.

**Key insights adopted:**

1. **Wave count corrected from 21 to 13.** Phase 1 catalog cited P99 wiki's 21 waves; live
   `ring_war.lua:9-12` says 13 mob waves + Narandi = 14 conditions. DB confirmed.

2. **No overall event timeout.** Only per-wave 5-min cooldowns. This changes the design
   space: reducing wave-mob HP to make each wave clearable is viable without breaking
   event pacing. My draft assumed a time constraint that doesn't exist.

3. **8 Kromrif wave-mob IDs exclusive to greatdivide.** Architect DB sweep confirmed zero
   ID-sharing with static zone or other zones. Kromrif Captain (118130), Recruit (118160),
   Warrior (118150), General (118120), Priest (118209), Warlord (118158), Veteran (118156),
   High Priest (118210). Clean scope.

4. **Seneschal Aldikar HP bump (10k→30k)** — prevents AOE overflow from failing event.
   Lore-master Flag 2.

5. **Decision #2 (trash/named untouched) applies to standing-zone content, not scripted
   event waves.** Lore-master endorses Kromrif wave-mob HP cuts.

6. **Prayer Shawl NOT raid-tier** — confirmed my DB + script review finding. 8-shawl chain
   is turn-in driven; no raid bosses required.

7. **Plane of Mischief Jester (126012) recommended for exclusion** — lore-master flagged
   as era-boundary. **Decision #27 raised** for user.

8. **Ring 8/9 UX** — lore-master agrees out of Phase 4a scope.

**Architect revised approach:**

- **Default implementation: Lever 1 SQL-only** — extends `npc_types` UPDATE list by 9 rows
  (8 Kromrif + Seneschal). Same team as Phases 2/3 (data-expert + config-expert). lua-expert
  moves to CONDITIONAL-only.
- **Lever 2 conditional fallback** — one-line `ring_war.lua:26` edit only if game-tester
  validation shows ≥3 consecutive waves overlapping + user approval.

**Implications:**
- Implementation task count: 9 default tasks (V1-V9), 2 conditional (V10-V11)
- Implementation team simpler: data-expert + config-expert default; lua-expert+infra-expert
  conditional-only
- Event identity preserved: 13 waves, 5-min cadence, lore-consistent "epic multi-wave defense"
- Event duration ~45-90 min (longer than my draft's ~30-35 min but lore-consistent)

**Architecture doc and status.md updated.** User decisions expanded from #23-26 to #23-27
(adding Jester inclusion Q). Commit inbound.

**Outcome:** Lore-master Q8 consultation complete and adopted. Phase 4a architecture is
ready for user approval on decisions #23-27 before implementation dispatch.

---

## Implementation Team Conversations (Phase 4a Velious non-ToV)

### 2026-04-22 — data-expert → config-expert: SQL applied, ready for reload + smoke verify

**From:** data-expert → **To:** config-expert

**Summary:** Phase 4a SQL applied (all 63 verification checks passed). Requesting
`#reloadworld` and smoke verification of 12 key NPCs including both Yelinak variants
(Q24 confirmation), a Kromrif wave mob (Q23 Lever 1 confirmation), and AoW/Vulak
exclusion safety check (must remain at 900k/890k HP respectively).

**What data-expert completed before this message:**
- Backup tables created: `npc_types_backup_raid_scaling_velious_a` (46 rows),
  `spawn2_backup_raid_scaling_velious_a` (227 rows)
- 46 `npc_types` HP/damage UPDATEs applied (Kael 4 + Skyshrine 6 + PoG 9 + PoM 1
  + outdoor dragons 4 + WW 3 + Velketor 2 + Sirens 2 + misc 3 + Narandi/Dain/Chamberlain 3
  + Ring War wave mobs 8 + Seneschal 1)
- 15 `spawn2.respawntime` UPDATEs to 43200s
- All 63 post-change verification checks: PASS
- AoW (113457) confirmed 900,000 HP — NOT touched
- Vulak'Aerr (124155) confirmed 890,000 HP — NOT touched
- SQL files committed and pushed to `feature/raid-scaling`

**Outcome:** Awaiting config-expert reload + smoke verify response.

---

## Architecture Team Conversations (Phase 4b Velious ToV + Sleeper + Vulak + AoW)

### 2026-04-22 — architect → protocol-agent: Phase 4b feasibility consult

**From:** architect → **To:** protocol-agent

**Summary:** Architect requested Phase 4b protocol consultation on 7 questions:
1. ToV / Sleeper's Tomb — static zone or DZ/Expedition?
2. Kerafyrm / Sleeper Awake event isolation — can Warder HP scaling accidentally trigger it?
3. Vulak`Aerr altar-summon event — any client protocol concerns?
4. AoW chain closure — Phase 4b completing Statue→Idol→AoW staggered scaling safe?
5. MobHealth percentage behavior for ultra-high HP (Kerafyrm 3.5M untouched)
6. Vyemm MR=1000 + special_abilities flag 42 — client visibility concern?
7. Any Titanium-era protocol quirks for `sleeper` / `templeveeshan` zones?

**From:** protocol-agent → **To:** architect

**Summary:** All 7 questions answered from source examination of quest scripts and
prior protocol topography work. Key findings:

1. **ToV + ST: standard static zones.** Grep of all scripts in both zone dirs: zero
   hits for DZ/expedition APIs. Entry via standard `ZoneChange_Struct` → `ZoneServerInfo_Struct`.
   Same `#reloadworld` / repop refresh applies as Phase 4a zones.

2. **Kerafyrm awakening: behavioral gate only. HP scaling cannot trigger it.**
   All 4 Warder scripts (`#Hraashna`, `#Nanzata`, `#Ventani`, `#Tukaarak`) check
   `entity_list` to confirm all 4 are dead before calling `quest::signalwith(128094, 66, 0)`.
   The signal chain (`#The_Sleeper` → `quest::spawn2(128089)` → `#Kerafyrm`) fires only
   on actual gameplay kills. Client-visible packets are standard: `OP_MoveDoor` (door 46),
   `NewSpawn_Struct`, `DeleteSpawn_Struct`. Decision #12 is fully safe.

3. **Vulak summoning: entity-presence check, not altar items.**
   `#Thylex_of_Veeshan.pl` checks `GetMobByNpcTypeID()` for 6 specific lords (124077,
   124076, 124008, 124010, 124074, 124017) all being absent, then `quest::spawn2(124155)`.
   Client sees standard `NewSpawn_Struct`. HP scaling on those 6 lords does not affect
   the presence check. Thylex_of_Veeshan is not a kill target — flag for architect to
   exclude from scaling SQL.

4. **AoW chain closure: no new concern.** Same `eq.unique_spawn()` / `event_death_complete`
   pattern confirmed safe in Phase 4a.

5. **MobHealth ultra-high HP: percentage-only, no wire impact.** Confirmed from mob.cpp:1500.

6. **Vyemm MR=1000: server-side only.** `MR` column never sent to client. Invisible on wire.

7. **No zone-specific Titanium quirks** in either zone. Standard static-zone flows.

**Overall verdict:** Phase 4b is 100% server-side (SQL). Zero opcode additions, zero
struct changes, zero Titanium translation layer changes. Same conclusion as Phases 2, 3, 4a.

**Outcome:** Architect has full protocol clearance for Phase 4b. Thylex_of_Veeshan flagged
as coordinator NPC to exclude from scaling SQL. Full findings in
`protocol-agent/dev-notes.md` Phase 4b section.


---

### 2026-04-23 — architect → lore-master: Phase 4b Sleeper/ToV/Vulak keying + signature mechanics

**From:** architect → **To:** lore-master

**Summary:** Architect dispatched 10-question Phase 4b consult covering:
1. Sleeper Awake boundary — is scaling 4 Warders acceptable under Decision #12? (Option A: scale; Option B: leave all 4 at 200k; Option C: scale 3 of 4)
2. Vulak altar-summon chain specifics — which 6 dragons gate the altars?
3. ToV keying confirmation (per velious-chains.md Section 3, expected no key)
4. Sleeper's Tomb keying (Lendiniara 124020 talisman role)
5. Vulak / ToV Epic 1.0 dependency check (per Section 5, expected none)
6. NToV mid-tier named (Midayor cluster + L65-66 group) quest-chain ties
7. AoW quest chain / non-loot progression ties
8. NToV Defenders (124050/51/52/79) — confirm out-of-scope per audit + Decision #2
9. Signature mechanics to preserve per Phase 4b boss (Vyemm MR-wall, Telkorenar/Gozzrem MR-walls, Kildrukaun MR=400, Dagarn HP-regen, Vyskudra Lightning Breath, MotG 8-sentry wave, Ancient Kerafyrm-alive depop, Aaryonar breath)
10. Respawn tier confirmation (24h endgame per Decision #8) — any lore reason to preserve 72h for specific bosses?

**Full DB investigation submitted:** `architect/context/velious-b-db-investigation.md` with complete Kerafyrm awake chain code trace (all 4 Warder `.pl` files + `#The_Sleeper.pl` + `#Kerafyrm.pl`). Verified trigger is `quest::signalwith(128094, 66)` on last-Warder death, driven by `GetMobByNpcTypeID` count checks NOT HP thresholds. HP scaling isolated from awake trigger at the code level.

**Architect working assumption** (pending lore-master response): Option A for Decision #36 (scale Warders normally; Kerafyrm trio untouched per Decision #12; awake event becomes reachable for small group but event consequence preserved).

**Outcome:** Awaiting lore-master response. Draft architecture doc submitted with Option A as default; addenda section will incorporate lore-master answer when received.

---

### 2026-04-23 — architect → config-expert: Phase 4b rule/config posture

**From:** architect → **To:** config-expert

**Summary:** Architect dispatched 6-question Phase 4b consult covering:
1. rule_values drift check (expect 1,112, zero new rules since Phase 4a)
2. Zone-scoped rulesets for sleeper + templeveeshan (endgame zones — re-verify)
3. Endgame-specific globals (raid MR cap, dragon-breath damage modifier, etc.)
4. Signature-mechanics rule interactions (could any rule amplify special_abilities?)
5. Respawn timer rule clamps (86,400s valid for all spawn2 rows?)
6. Data buckets / spawn_conditions posture for Kerafyrm awake state

**Architect working assumption** (pending config-expert response): zero config changes; Phase 2/3/4a pattern holds. rule_values count 1,112 unchanged. sleeper + templeveeshan on ruleset=1 default. Kerafyrm state stored in qglobal `kerafyrm` (set 1/2/3 per Kerafyrm `.pl` scripts), not in data_buckets or config files.

**Outcome:** Awaiting config-expert response. Draft architecture doc submitted with zero-change default; addenda section will incorporate config-expert answer when received.

---

### 2026-04-23 — lore-master → architect: Phase 4b full sign-off (10 questions answered)

**From:** lore-master → **To:** architect

**Summary:** Comprehensive 10-question Phase 4b lore review delivered. Key findings:

1. **Decision #36 — Option A (scale Warders) is the lore-correct interpretation of Decision #12.** Scaling the Warders is the intended way to make the Sleeper's Tomb experience reachable for a small group. Kerafyrm himself and permanent-consequence scripts are what Decision #12 protects — NOT the Warder barrier.

2. **Vulak altar-summon correction:** audit's "six altars" is INCORRECT. Real mechanic: Thylex alive + all North Wing Lords/Ladies (Aaryonar/Mirenilla/Nevederia/Feshlak/Kreizenn/Vyemm) dead → Vulak spawns. **Lord Koi`Doken is NOT a Vulak trigger** despite being a Phase 4b boss. No altar NPCs exist.

3. **ToV keying — confirmed unkeyed** (L46+ only). "Key of Veeshan" from Tormax/Yelinak/Dain is for **Veeshan's Peak (Kunark)**, NOT ToV.

4. **Sleeper's Tomb keying — confirmed no new Phase 4b keying.** Lendiniara talisman drop is standard loot-table. Jaled Dar access is pre-existing rogue/levitate puzzle.

5. **No Epic 1.0 dependency** on any Phase 4b boss (Vulak, AoW, ToV lords).

6. **CRITICAL: East Wing named are quest-drop sources.** Dozekar (Tears) + Midayor cluster (Symbols) gate Skyshrine armor via Halls of Testing turn-ins. Phase 4b's 40-50k HP cuts on all 16 mid-tier named are REQUIRED — under-scaling would break Skyshrine armor progression. Loot tables preserved per Decision #3.

7. **AoW is loot-only** — no non-loot progression dependency.

8. **NToV Defenders (124050/51/52/79) CONFIRMED out of scope** per Decision #2.

9. **Signature mechanics list:**
   - Vyemm: Scream of Chaos PBAE (12s), Call of the Zero (6s), MR=1000 preserved
   - Aaryonar: Disempowering Breath + **assist-link to all NToV dragons (structural pull-order mechanic — must be pulled first)**
   - Lendiniara: BOTH talisman source AND Halls of Testing turn-in NPC; unslowable flag + Silver Breath preserved
   - Warders: each has distinct breath (DB-verified: Nanzata/Frost, Ventani/Mesmerizing+Freezing, Tukaarak/Mesmerizing, Hraashna/Acid)
   - Ancients: each distinct breath (Zeixshi-Kar/Fire, Kildrukaun/Typhoon+Slow, Vyskudra/Lightning+Dispel, Tjudawos/unconfirmed)
   - Dagarn HP-regen, Gozzrem/Telkorenar CoV-allied, MotG 8-sentry wave — all preserved
   - Vulak: flags 5/31/42 preserved; 4 items drop per Decision #3

10. **Respawn tier 24h CONFIRMED with one exception:** Thylex_of_Veeshan (124000) respawn 258,000s (~71.67h) is mechanically load-bearing for Vulak re-engagement. **DO NOT change Thylex respawn.** DB-verified Thylex is already out of Phase 4b respawn UPDATE list.

**Era compliance:** Phase 4b content is all Scars of Velious (era-locked). Ancients are original Velious NPCs.

**Lore sign-off: Phase 4b scope approved.** User should be advised the Warder kills trigger the permanent Kerafyrm event on this server — this is not a lore violation; it is the intended storyline climax.

**Outcome:** Architect incorporated all findings into `architect/velious-b-architecture.md`:
- Executive summary clarified (Koi`Doken not a Vulak trigger; Vulak trigger is 6 North Wing Lord/Lady, not altar system)
- Risk Assessment expanded: Aaryonar assist-link preservation + East Wing quest-drop dependency
- Validation Plan expanded: Aaryonar assist smoke test added
- Decision #36 formalized as architect + lore-master joint recommendation (Option A)
- Thylex respawn exception documented
- Full lore-master addendum recorded in architecture doc

---

## Architecture Team Conversations (Phase 5a Luclin non-VT)

### 2026-04-22 — architect → config-expert (Phase 5a initial scoping consult)

Architect sent 10-question consultation covering: rule_values posture (Q1), zone ruleset verification across all Phase 5a zones (Q2), death-touch sweep for Luclin boss spell lists (Q3), instance/DZ posture (Q4), data_buckets/quest globals interactions (Q5), Emperor Ssraeshza event-gated respawn mechanism (Q6), evolved burrower respawn target (Q7), OOE NPC filtering for shrouded minion / necromantic shade / Netherbian Swarmfiend (Q8), spawn_conditions for Luclin zones (Q9), spells_new Luclin DT cross-check (Q10).

**Response (2026-04-22) summary:**
- rule_values count = 1,112 (zero drift from Phase 4b baseline). No Luclin-specific rules.
- All Phase 5a zones (ssratemple, akheva, griegsend, acrylia, sseru) have ruleset=1, min_status=0, insttype=0. No DZ configuration — dynamic_zones table has 0 rows.
- DT sweep clean: no spell 982 (Cazic Touch) on any Luclin non-VT raid boss spell list. (Architect ran broader sweep separately and found Touch of Vinitras spell 2859 in list 196 — handled by Phase 5a Decision #16-pattern DELETE.)
- Critical spawn2 finding: Many Phase 5a bosses are EVENT-ONLY (zero spawn2 rows): Emperor 162227, Arch Lich Rhag`Zadune 162177, Vyzh`dra Cursed/Exiled/Banished 162206/232/214, Shei Vinitras primary 179032 (variant 179157 has spawn2), Spirit of Akelha`Ra 179144, Akhevan Warders 158087-94, Grieg Veneficus main 163075. HP cuts on zero-spawn2 bosses land in npc_types and take effect on next event spawn — `#reloadworld` sufficient.
- Standing-spawn bosses: Lord Seru (sseru, 259,200s), High Priest of Ssraeshza + Xerkizh (ssratemple, 259,200s), Itraer Vius (akheva, 210,924s), Shar Vinitras (akheva, 10,800s), Thought Horror Overfiend (thedeep, 194,400s), Nathyn Illuminious + Lcea Katta (katta, 194,400s / 258,750s).
- VT boundary confirmed: 158xxx VT bosses are vexthal with 468,720s respawn — Phase 5b only. Va_Dyn_Khar 158081 in vexthal at 21,600s — flagged for architect Phase 5a/5b verification (architect confirmed vexthal = Phase 5b).
- `#reloadworld` mechanism unchanged: world telnet port 9000.

**Outcome:** Pattern carryover confirmed. Architect proceeded with SQL-only design.

### 2026-04-22 — architect → protocol-agent (Phase 5a initial scoping consult)

Architect sent 10-question consultation covering: Luclin DZ/instance mechanics (Q1), Khati Sha zone confirmation for 5a/5b boundary (Q2), Yaemiu elite trash zone confirmation (Q3), Emperor Ssraeshza add-wave mechanic (Q4), DT audit follow-up (Q5), event-control NPC presence in Luclin (Q6), MobHealth packet behavior at 1.25M HP (Q7), Luclin-specific Titanium quirks (Q8), DT audit summary request (Q9), respawn change wire impact (Q10).

**Initial response + flags + full Q1-Q10 response (2026-04-22):**

**All 10 questions answered + 3 architect flags:**

Q1: All Phase 5a zones static, no instancetype column on this PEQ version. Standard ZoneChange_Struct entry. `#reloadworld` propagates normally. OP_ExpeditionLockoutTimers/OP_DzCompass post-Luclin, not in scope.

Q2: Khati Sha 154145 — script-spawned (no spawn2), script lives in `acrylia/`. Confirmed zone = acrylia. No VT variant. The 155xxx Khati_Sha named in sharvahl are unrelated Vah Shir trainers L45-50.

Q3: Yaemiu mob pattern (Eom_*, Pli_*, Zun_*, etc.) spawns exclusively in vexthal. Zero in any Phase 5a zone. Phase 5b only.

Q4: Emperor adds are SCRIPT-spawned, not spell-summoned:
- Blood/Golem combat adds: `#Blood_of_Ssraeshza.lua` and `#Ssraeshzian_Blood_Golem.lua` use `eq.spawn2` in event_combat to spawn 4× Ssraezsha (162280) when engaged.
- Post-death wraiths: `#Emperor_Ssraeshza_.pl` `EVENT_DEATH_COMPLETE` uses `quest::spawn2` x5 for A_shissar_wraith (162210).
- Spell list 227 contains spell 2310 "Rage of Ssraeshza": SPA 11 (haste +10%), SPA 79 (-4000 AC debuff), SPA 114 (-95 ATK debuff). NO summon (SPA 46), NO DT. Cast=0, mana=0, recast=60s. Wire format standard.
- Emperor's special_abilities `32,1,290`: ability 32 = Leash, param 290 = leash distance. Server-side AI behavior only.
- All add mechanics preserved without spell-list edits. Decision #11 safe.

Q5/Q9: DT sweep complete across all 30 Phase 5a spell list IDs. Mana=0 cast=0 SPA 0 effect_base_value1 ≤ -10000 → ZERO ROWS. Lord Seru's `O` flag = MeleeImmunityExceptBane (SpecialAbility 22), not DT. Seru's spell 2061 "Torturing Winds" mana=0 cast=2000ms (2s cast, NOT instant) value=-300, not DT.

Q6: Event-control exclusion list:
- 162269 keycheck (ssratemple, 999M HP, instance gate)
- 176110 #Keymaster (umbral, 99M HP, key gate)
- 160177 Bella_Helsin + 160178 Heracus_Helsin (katta, L1 1M HP, untargetable=24)
- 162065 Emperor_Ssraeshza placeholder (no-target, 6516 HP, depopped at real spawn)
- 162260 #EmpCycle (controller NPC, 4375 HP, untargetable)
- Plus 12× Grieg_VeneficusTrigger* untargetable proximity NPCs (excluded by raid_target=0)
- Plus Akheva environmental flavor NPCs (Shadows, A_rock, Altar_Invis 179148-179172, untargetable=1)
- Plus Itraer Vius depop form 179154 (650 HP, untargetable=1)

Q7: npc_types.hp = bigint(20). MobHealth packet sends (int)GetHPRatio() — uint8 percentage server-side. 1.25M and 1.2M HP identical to 30k on wire. No overflow.

Q8: Zero Luclin-specific Titanium quirks affecting scaling. Multi-floor geometry / lighting / faction states / Vah Shir + shissar models all unaffected by HP/damage column changes.

Q10: spawn2.respawntime changes are server-internal. Client sees only DeleteSpawn_Struct/NewSpawn_Struct. Zero opcode firing from respawntime change.

**Three architect flags:**

**Flag A — EmpCycle timers require perl-expert, not SQL:**
`$EmpRepopTime = int(rand(2880)) + 4320` (3-5 day post-kill respawn) and `$BloodCoolDownTime = int(rand(60)) + 180` (3-4h failure cooldown) are Perl local variables in `#EmpCycle.pl`, not rule_values. SQL cannot tune them. If user wants softer cycle, perl-expert task needed. → **Phase 5a Decision #52 covers; default Option A keeps native.**

**Flag B — Shei Vinitras has TWO npc_type IDs:**
Audit catalog lists 179157 (#Shei_Vinitras_, merchant form, 400k HP, only-immunities special_abilities, no spell list). Real fight boss is **179032 #Shei_Vinitras (no underscore)** — L64, 690k HP, 273-700 dmg, has spell list 179. Both need separate npc_types HP UPDATE rows. Architect can scale merchant deeper (so trigger-kill not raid-tier itself) and scale real boss to standard target. → **Phase 5a Data Model includes BOTH 179032 and 179157.**

**Flag C — Vyzh`dra trio is multi-form chain via `#cursed_controller.pl`:**
162206 Cursed = final boss; 162232 Exiled + 162214 Banished = intermediate forms; 162261 glyph-covered serpent + 162253 rune-covered serpent = chain stepping stones. All raid_target=1. Audit only listed 162206. Architect must decide which IDs receive boss-tier scaling vs which are pre-event mobs. → **Phase 5a Decision #50 covers serpent inclusion (architect default INCLUDE per chain interpretation); Vyzh`dra trio all in scope.**

**Outcome:** Phase 5a is 100% server-side. Zero protocol changes. Architect incorporated:
- Decision #50 (rune/glyph serpents) created based on Flag C
- Decision #52 (EmpCycle respawn) created based on Flag A; default Option A keeps native
- Shei Vinitras dual-form scaling per Flag B
- Event-control NPC exclusion list per Q6
- Khati Sha = acrylia (resolves audit's "grimling?")
- Yaemiu = vexthal-only (Phase 5b)

### 2026-04-23 — architect → lore-master (Phase 5a lore consult — initial 17 questions)

Architect sent 17-question consultation covering: Emperor add-wave mechanic lore (Q1), Vyzh`dra trio zone split lore (Q2), Khati Sha zone confirmation (Q3), Lord Inquisitor Seru / Lcea Katta faction-war mechanic (Q4), Ring of the Shissar quest dependency (Q5), VT key Phase 3 Planes Rift drop (Q6), Akheva Sacrificed Remains chain (Q7), Grieg's End keying (Q8), Grimling War event boundary (Q9), Umbral Plains and Doomshade lore (Q10), Thought Horror Overfiend mechanics (Q11), Khati Sha zone lore (Q12), Epic 1.0 dependency (Q13), respawn tier exceptions (Q14), signature mechanics per boss (Q15), faction gates for scaling (Q16), overall lore sign-off (Q17).

### 2026-04-23 — architect → lore-master (Phase 5a lore consult — 6-question follow-up ping)

Architect sent follow-up after 25 hours pinging on highest-priority items: Emperor cycle mechanic confirmation (Q1), Vyzh`dra rune/glyph serpent inclusion (Q2), Touch of Vinitras DT removal lore acceptance (Q3), Ring of the Shissar quest preservation under HP cuts (Q4 / Q5 from initial), Doomshade quest dependency (Q6 / Q10 from initial), Lord Inquisitor Seru MR=800 preservation (Q7 / Q15 from initial).

**Response: PENDING as of 2026-04-23.** Architect proceeded with `luclin-chains.md` as primary lore reference; default recommendations stand. Decisions #50/#51/#52 surfaced for user. Architecture doc records sign-off as pending; addendum will be added if lore-master findings require corrections.


### 2026-04-25 — lore-master → architect (Phase 5a lore consultation COMPLETE — APPROVED)

Lore-master delivered comprehensive 17-question Phase 5a sign-off plus reference doc filing at `lore-master/luclin-non-vt-additions.md`. Full Q&A summary in architecture doc Addenda section. Highlights:

- **Q1 Emperor mechanic CANONICAL.** Snake/golem add wave: 8 aggro-linked snakes (4 mez + 4 offtank, 2 non-mez heal-debuffers), respawn every 2-2.5min. Golem death → Emperor spawn 3-6min. Cold-only slow + Ssra bane weapons required. Shissar wraiths drop Planes Rift from loot tables. Phase 5a HP cut safe.

- **Q2 Vyzh`dra zone ALL ssratemple.** Cycle trigger: 7 Taskmasters + 1 Warden Mekuzh + 2 Rhozths killed within 1 hour → Glyph Serpent → Exiled → Cursed. Recovery chain: Rune Serpent + Banished. **Decision #50 resolved Option A (INCLUDE) — joint architect+lore-master recommendation.**

- **Q3 Touch of Vinitras DELETE APPROVED.** No lore objection. Cursed list 197 verified clean. **CRITICAL CROSS-CHECK:** spell 2859 also appears in list 179 (Shei Vinitras REAL). Per Q15: PRESERVE Shei's DT — it's her signature. Phase 5a DELETE correctly scoped to list 196 only.

- **Q4 Seru/Katta:** HP scaling safe; faction war preserved. No add-spawn mechanic on Lord Seru. Bella/Heracus correctly excluded.

- **Q5 Ring of the Shissar:** Phase 5a scope confirmed. Pre-Emperor named (Insignia drops) IN; Commanders/Mekuzh OUT.

- **Q6 VT key Planes Rift:** No HP condition; drops from wraith loot tables.

- **Q7 Akheva chain:** Spirit of Akelha`Ra Decision #57 confirmed.

- **Q8 Grieg's End:** OOE 163051/52 confirmed. 5 key-drop named OUT of scope.

- **Q9 Grimling War event:** OUT of Phase 5a (matches architect default).

- **Q10 Doomshade:** Phase 5a scope confirmed. Dark Masters (176042) raid_target=0 elite-trash, NOT scope.

- **Q11 Thought Horror:** Feeblemind + Thought Drain signature. List 204 preserved.

- **Q12 Khati Sha:** Acrylia confirmed. No Beastlord 1.0 epic dependency. Architect script audit confirmed 2-phase event uses only elite-trash adds (5-9.5k HP) — no lua-expert needed.

- **Q13 Epic 1.0:** ZERO conflicts (matches Velious finding).

- **Q14 Respawn exceptions:** None. Emperor + Vyzh`dra cycle script-spawned (no spawn2 update). Grieg standard 24h.

- **Q15 Signature mechanics:** comprehensive list across all 13 named bosses — all preserved by Phase 5a SQL-only approach.

- **Q16 Lord Seru MR=800:** PRESERVE confirmed.

- **Q17 LORE SIGN-OFF APPROVED.** Phase 5a scope confirmed with notes. Era-compliant. Scripted encounters verified SQL-safe.

**Architect-discovered additional finding (cross-check during lore-master review):**
- A_Spiritual_Arcanist 154153 (L68, 150k HP, raid_target=1, acrylia, script-spawned, no spawn2). Audit-missed. Architect adds Decision #59 (default INCLUDE in Phase 5a, HP target 45k pending user confirmation).

**Outcome:** Architect incorporated 5 adjustments into `architect/luclin-a-architecture.md` (Addenda section + Decision #59 surfaced). Status.md updated to reflect Decision #50 RESOLVED + Decision #59 OPEN.


### 2026-04-25 — lore-master → architect (Decision #59 refinement: Spiritual Arcanist 154153 = Khati Sha Phase 2 wrong-choice penalty)

Lore-master clarified A_Spiritual_Arcanist 154153 is **NOT** one of the three outer Acrylia raids (Ring of Fire / Vah Shir Captive / Burrower remain separate). She is the **Khati Sha event Phase 2 "wrong choice penalty" combat target**:

- Phase 2 of Khati Sha event presents two arcanists: 154151 V1 + 154152 V2 (both 75k HP, raid_target=0)
- Player uses `/tar a_spiritual_arcanist00` to pick correct rescue target
- **Save correct V1** → 4 deathguards spawn → killing them opens final seal to Khati Sha (Phase 3)
- **Save wrong V2** → 4 deathguards spawn + forces fight against 154153 (raid_target=1 penalty boss)

**Architect script audit confirms** (`#Raidman.lua`):
- spawns 154151 (V1, 75k) + 154152 (V2, 75k) + 8× a_diseased_grimling (154129)
- 154129.lua signals 154151 (signal 9) on grimling death — succeed path
- 154159.lua signals 154152 (signal 8) on death — fail path
- 154153 is the wrong-choice combat fight via separate trigger

Spell list 956 (used by 154153): Grip of Mortal Reality (-500 dmg), Grip of Mental Reality (-500 mana). No DT.

**Joint architect+lore-master recommendation:** Phase 5a INCLUDE 154153 with HP target **150k → 40k** (per lore-master "reasonable wrong-choice penalty"). 154151 + 154152 OUT of scope (raid_target=0 quest NPCs).

**Decision #59 refined.** Architect updated architecture doc and status.md accordingly. Lore sign-off acknowledged on architect adjustments 1-5; no lore objections to any of Decisions #50/#59/#60/#61/#62.

---

## Phase 5a Implementation Team Conversations

### 2026-04-22 — config-expert → data-expert: Dependency gate BLOCK

**From:** config-expert → **To:** data-expert

Pre-reload DB gate check failed. Phase 5a backup tables (`npc_types_backup_raid_scaling_luclin_a`, `spawn2_backup_raid_scaling_luclin_a`, `npc_spells_entries_backup_raid_scaling_luclin_a`) do not exist. Emperor Ssraeshza (162227) HP = 1,250,500 (unscaled). Lord Seru (159691) HP = 1,201,500 (unscaled). Last confirmed backup table in DB is `npc_types_backup_raid_scaling_velious_b` — only Phase 5a is missing.

Context: Docker stack was restarting when config-expert first connected; prior phases intact.

perl-expert L13 IS confirmed complete — `#EmpCycle.pl:3` reads `int(rand(7200)) + 79200`.

Config-expert standing by. Will issue `#reloadworld` and run L-smoke as soon as data-expert confirms L1-L9 complete and backup table row counts are valid (41 / ~22-23 / 1).

**Outcome:** Awaiting data-expert response.

### 2026-04-22 — config-expert → team-lead: Phase 5a blocked on data-expert SQL

**From:** config-expert → **To:** team-lead

Relayed dependency gate block status. data-expert L1-L9 SQL not applied. perl-expert L13 complete. Config-expert blocked on L-reload and L-smoke until data-expert confirms SQL applied.

**Outcome:** Team-lead informed. Awaiting data-expert.

---

## Phase 5a Implementation Team Conversations — data-expert round

### 2026-04-22 — data-expert → perl-expert: L13 task details + coordination

**From:** data-expert → **To:** perl-expert

Notified perl-expert that Phase 5a SQL is fully applied and committed. Provided exact L13 edit details: `#EmpCycle.pl` line 3, `int(rand(2880)) + 4320` → `int(rand(7200)) + 79200`. Noted `$BloodCoolDownTime` is NOT edited. Requested `perl -c` syntax check before commit, commit to `akk-stack/` on `feature/raid-scaling` branch, and ping config-expert after.

**Outcome:** perl-expert was already confirmed complete per config-expert's earlier message (L13 read `int(rand(7200)) + 79200` at time of config-expert's DB gate check). No action needed from perl-expert — already done.

### 2026-04-22 — data-expert → config-expert: SQL complete, ready for L10/L11

**From:** data-expert → **To:** config-expert

Notified config-expert that Phase 5a SQL is applied:
- 41 npc_types UPDATEs complete
- ~17-18 spawn2 respawn UPDATEs to 86400s complete
- Touch of Vinitras DELETE from list 196 confirmed (list 179 preserved per Decision #60)
- All verification checks passed (Emperor Leash, Lord Seru MR=800, Spirit of Akelha`Ra 1M HP, vexthal NPCs untouched, event-control NPCs untouched)
- Backup tables: 45/80/1 rows

Instructed config-expert to proceed with L10 (`#reloadworld`) and L11 (smoke verify), then ping infra-expert for full-stack restart (required per architecture for npc_spells_entries DELETE zone-cache flush).

**Outcome:** config-expert unblocked for L10/L11.

### 2026-04-22 — config-expert → infra-expert: full-stack restart request (zone spell cache flush)

**From:** config-expert → **To:** infra-expert

L-reload and L-smoke complete (71 checks PASS). Requested full-stack restart to flush akheva zone process spell list 196 cache. Touch of Vinitras spell 2859 confirmed gone from DB (list 196 = 0 rows), but zone-memory may still hold it until akheva zone process restarts. Same pattern as Phase 2 Cazic Touch DELETE. Architecture doc flags restart as required for Phase 5a.

**Outcome:** infra-expert notified. Restart pending.

### 2026-04-22 — config-expert → data-expert: L-smoke PASS confirmation

**From:** config-expert → **To:** data-expert

All 71 checks PASS. Noted Grieg variant 163231 HP = 162,500 (unchanged, respawn-only per arch doc — expected). Infra restart dispatched.

**Outcome:** data-expert informed of clean all-clear.

### 2026-04-22 — team-lead → config-expert: Phase 5a all-clear acknowledged

**From:** team-lead → **To:** config-expert

Confirmed L-reload + L-smoke PASS. Flagged that backup table row counts exceeded architecture estimates (45 npc_types vs expected 41; 80 spawn2 vs expected ~22-23). Requested discrepancy be logged for record. config-expert tasks complete; stand by for game-tester re-verify if needed post-restart.

**Row count discrepancy note (logged per team-lead request):**

| Table | Actual rows | Architecture estimate | Delta |
|-------|-------------|----------------------|-------|
| `npc_types_backup_raid_scaling_luclin_a` | 45 | 41 | +4 |
| `spawn2_backup_raid_scaling_luclin_a` | 80 | ~22-23 | +57 |
| `npc_spells_entries_backup_raid_scaling_luclin_a` | 1 | 1 | 0 |

The npc_types delta of +4 and the large spawn2 delta suggest data-expert captured additional rows in the backup SELECT beyond the architecture doc's scope estimate. This is a safety over-capture (more rows backed up than strictly needed) — not a data integrity concern. Architecture doc's spawn2 estimate explicitly noted "~22-23 standing-spawn rows + ~51 pre-Emperor rows captured for safety," which accounts for the larger actual count (51 pre-Emperor rows + remaining standing-spawn rows = ~80 total). The npc_types +4 may reflect additional NPC IDs included in the backup IN clause. No rollback risk — backup covers more ground than estimated. Data-expert to clarify if needed.

**Outcome:** Discrepancy documented. No action required from config-expert.

### 2026-04-22 — infra-expert → config-expert: full-stack restart complete

**From:** infra-expert → **To:** config-expert

Full-stack restart complete. All containers up, shared_memory/loginserver/world running, 8 zone processes (dynamic_01–08) registered with world. Post-restart DB spot-check: list 196 returns 0 rows for spell 2859; list 179 returns 1 row. Akheva zone spell list 196 cache is clean — spell 2859 cannot be loaded from DB. Server ready for game-tester validation.

**Outcome:** Zone-spell cache flush confirmed. Phase 5a server-side work complete. Ready for game-tester.

### 2026-04-22 — data-expert → config-expert: late confirmation (post-completion)

**From:** data-expert → **To:** config-expert

Confirmed that the initial gate check failure was caused by the Docker restart window — SQL was already applied and persisted on the MariaDB volume before the restart. Re-verified backup tables (45/80/1) and sample NPC HP values post-restart.

**Outcome:** Timeline clarified. No action needed — L-reload and L-smoke were already complete when this message arrived.

---

## Architecture Team Conversations (Phase 5b Luclin VT)

### 2026-04-22 — architect → protocol-agent: Phase 5b VT 13-question consultation

**From:** architect → **To:** protocol-agent

13-question consultation covering: Aten Ha Ra encounter scripts (Q1), ID resolution 158096 vs 158006 (Q2), vexthal DZ/instance status (Q3), DT spell sweep across all VT spell lists (Q4), Akhevan Warders zone confirmation (Q5), Yaemiu trash boundary (Q6), VT key turn-in NPC exclusions (Q7), event-control NPCs (Q8), VT door/key mechanics (Q9), MobHealth percentage check at 1.9M HP (Q10), Diabo trio encounter linkage (Q11), 5a/5b boundary backwards check (Q12), Khati Sha VT variant verification (Q13).

### 2026-04-22 — protocol-agent → architect: Phase 5b full 13-question response

**From:** protocol-agent → **To:** architect

**Q1 — Aten Ha Ra encounter scripts:**
Three-script system: `#Aten_Ha_Ra.pl` (158006 aggro), `#Aten_Ha_Ra_.pl` (158096 non-aggro), `#Aten_Trigger.pl` (controller). Aten_Trigger polls entity list every 60s: if all 9 inner bosses (158007–158015) absent AND qglobal "aten" not set → spawns non-aggro form 158096 (with 48h depop timer). If inner bosses present AND aggro Aten not up → spawns aggro form 158006 (1s qglobal check timer on spawn, depops if qglobal set). On kill of either form: `quest::setglobal("aten",1,3,"M$spawntime")` with ~1.8h variance. Architecture comparison to Emperor cycle: similar qglobal + entity-check pattern, but simpler — no EmpCycle equivalent, no Blood gate. This is closest to the Phase 4b Vulak/Thylex chain (entity-presence controller + script-spawned boss). No add-waves. No post-mortem spawns. No combat-timer bomb.

**Q2 — Aten Ha Ra ID resolution (158006 vs 158096):**
Both are live kill targets, NOT placeholder vs real. The Aten_Trigger chooses which form to spawn based on whether inner bosses are up:
- 158006 (#Aten_Ha_Ra) = the DESTROY form — spawns when inner bosses are still alive and players have made it to the boss room while the wing is active. Has DT spell 1948 "Destroy" in list 229. `#Aten_Ha_Ra.pl` script.
- 158096 (#Aten_Ha_Ra_) = the non-aggro form — spawns when inner bosses are all dead. Has 48h depop timer. Uses list 540 (clean, no DT). `#Aten_Ha_Ra_.pl` script.
Both have 1,901,500 HP. This is NOT the same as Shei Vinitras (179032 fight vs 179157 merchant) — in VT, BOTH forms are kill-target bosses that spawn under different encounter conditions. Both need HP scaling. Note: 158096 has NO spawn2 rows (script-only via Aten_Trigger quest::spawn2). 158006 has a spawn2 row in `overthere` at 640s — but this is a PEQ DB artifact (see Q12 finding below).

**Q3 — vexthal DZ/instance status:**
Confirmed standard static zone. `vexthal/player.lua` is 3 lines (illegal-bind guard only). Zero DZ/expedition API in any vexthal script. `dynamic_zones` table has 0 rows per Phase 5a config-expert confirmation. Entry via standard `ZoneChange_Struct` → `ZoneServerInfo_Struct` flow.

**Q4 — DT spell sweep across all VT spell lists:**
CONFIRMED: Spell 1948 "Destroy" in npc_spells_id=229 (NPC 158006 #Aten_Ha_Ra). PBAE DT: mana=0, cast_time=0, recast_delay=-1 (unlimited), effectid1=0 (SE_CurrentHP), effect_base_value1=-100,000, targettype=4 (PBAE — hits multiple targets). List 540 (158096) is clean — no spell 1948. Fling (spell 2167, effectid1=0, value=-1, targettype=2 PBAE) appears in lists 229, 230, 231, 234, 540 — this is a proximity knockback, NOT a DT (1 HP loss). Shadow Warding 5 (spell 2144) in list 236 (Akhevan Warders) — effectid1=83 (spell mitigation buff), not a DT. No other DT-profile spells found across any VT list including all Yaemiu spell lists (8, 9, 1, 2, 448, 1472, 1473, 1353, 237, 238, 239, 233). Complete DT sweep: one hit, list 229 only.

**Q5 — Akhevan Warders zone confirmation:**
Confirmed vexthal-zoned. Warders 158087–94 have NO spawn2 rows at all (DB query returns NULL respawntime). They are script-only spawns via boss EVENT_SPAWN `quest::spawn2` calls and `quest::depopall` on boss death. HP UPDATE on `npc_types.hp` for all 8 IDs is valid and safe. No `spawn2.respawntime` UPDATE needed or possible.

**Q6 — Yaemiu trash spawn boundary — IMPORTANT FINDING:**
Yaemiu mobs (158000–158086 range) have NO vexthal spawn2 rows. DB query shows their spawn2 entries are in `nurga` (76 distinct NPCs) and `overthere` (76 distinct NPCs) — not vexthal. They exist in vexthal exclusively via script-spawning: (a) `akhevan_trigger.lua` proximity traps spawn random Yaemiu from a pool of 30 IDs, (b) boss scripts (Thall Va Xakra 158016/158125) pull nearby Yaemiu to assist via MoveTo(). This has a critical implication: since Yaemiu have spawn2 rows in `nurga` and `overthere` as well as vexthal-script-only, a SQL UPDATE on `npc_types.hp` will affect ALL instances of the NPC wherever it spawns, including nurga/overthere. This is actually correct behavior — same logic as Velious outdoor-dragon HP cuts affecting both outdoor zones. The `spawn2.respawntime` UPDATE should target ONLY vexthal-specific rows — but since there are no vexthal spawn2 rows for Yaemiu, the only tunable respawn path is via changes to the akhevan_trigger script's depop timer (Lua-only, not SQL). Current akhevan_trigger depop is 30 minutes per spawned Yaemiu — no respawn row exists.

**Q7 — VT key turn-in NPCs INSIDE vexthal:**
No VT key turn-in NPCs inside vexthal. The shard assembly quest is handled entirely outside vexthal: Spirit of Akelha`Ra (179144) in akheva (excluded per Decision #30/57, untouched at 1M HP). The completed VT key item (item 8010 "Palace Key") is the keyitem for a single door in vexthal (doorid=45, VTDOOR302). No turn-in NPC inside vexthal itself. HP scaling on any VT boss does not break the door-key mechanic.

**Q8 — Event-control NPCs in vexthal:**
Three non-fight NPCs confirmed:
- 158095 `#Aten_Trigger` — L90, 50,000,000 HP, raid_target=0. Event controller — EXCLUDE. Note: its only spawn2 row is in `dulak` zone (respawntime=400s), not vexthal. It populates vexthal via some other mechanism (likely static spawn or script). Untouchable.
- 158128 `shade_trigger` — L55, 1,913 HP, raid_target=0. Proximity trap trigger — EXCLUDE.
- 158129 `akhevan_trigger` — L55, 1,913 HP, raid_target=0. Proximity trap trigger (the one running `akhevan_trigger.lua`) — EXCLUDE.

**Q9 — VT door/key mechanics:**
DB query of `doors WHERE zone='vexthal'` returns 39 doors total. Only ONE has keyitem != 0: doorid=45, name=VTDOOR302, keyitem=8010 ("Palace Key"), lockpick=-1 (unpickable). All other 38 VT doors have keyitem=0 (no key required). The Palace Key (item 8010) is dropped by bosses/looted in VT and is NOT summoned/given by any NPC that will be scaled. HP scaling on VT bosses does not alter door-key mechanics — items drop from loottables, which are unchanged per Decision #3.

**Q10 — MobHealth percentage at 1,901,500 HP:**
No issue. MobHealth uses `(int)GetHPRatio()` — a 0-100 integer percentage regardless of absolute HP. The uint8 field handles any HP value from 1 to bigint(20) max identically. 1,901,500 HP renders identically to 90,000 HP on the wire — both send a uint8 percentage. Confirmed safe per Phase 2 analysis (the MobHealth uint8 percentage pattern is the same for all phases).

**Q11 — Diabo trio encounter linkage:**
No scripted sequential dependency between Diabo NPCs. Confirmed by examining all boss scripts — each script only manages its own warder guards (spawn on EVENT_SPAWN, depopall on EVENT_DEATH_COMPLETE). No inter-boss signaling. No "all three must die" entity check. The "Diabo trio" terminology refers to the three 1st-floor boss rooms (158014 #Diabo_Xi_Va + warders 158088; 158015 #Diabo_Xi_Xin + warders 158088; 158012 #Diabo_Xi_Xin_Thall + warders 158089). No sequential dependency. Same independent-boss pattern as VP outer dragons (Phase 3). All scalable independently.
Special abilities of note:
- 158013 (#Kaas_Thox_Xi_Ans_Dyek): `42,1` — CounterAvoidDamage + `31,1` — PacifyImmunity. No protocol impact.
- 158011 (#Thall_Xundraux_Diabo): `5,1,20` — Flurry 20%. Server-side AI only.
- 158012 (#Diabo_Xi_Xin_Thall): `3,1,20` — Rampage 20%, `6,1` — TripleAttack.
- 158016/158125 (#Thall_Va_Xakra): `3,1,30` — Rampage 30%. All server-side.

**Q12 — Phase 5a/5b boundary backwards check:**
IMPORTANT FINDING: All inner VT bosses (158006–158016, 158125) have their spawn2 rows in `overthere` zone (respawntime=640s), NOT vexthal. The Yaemiu trash (158000–158086) have spawn2 rows in `nurga` and `overthere`. Va_Dyn_Khar (158081) has a spawn2 row in `nurga` at 960s. `#Aten_Trigger` (158095) has its spawn2 row in `dulak` at 400s. ZERO vexthal spawn2 rows exist for any 158xxx NPC. This means:
1. `spawn2.respawntime` UPDATE for VT inner bosses must target `overthere` zone rows, not vexthal. Architect's SQL for spawn2 updates needs `WHERE zone='overthere'` scoped to these NPC IDs.
2. Va_Dyn_Khar `spawn2.respawntime` UPDATE targets `nurga` zone row.
3. Yaemiu trash have no respawntime UPDATE path via spawn2 (no vexthal spawn2 rows); depop timers in akhevan_trigger.lua (Lua-only) control how long trap-spawned Yaemiu persist.
4. No 158xxx NPCs were overlooked between Phase 5a and 5b — the Phase 5a boundary was correctly set (Phase 5a explicitly excluded all 158xxx per confirmation notes).

**Q13 — Khati Sha VT variant verification:**
Confirmed NO 158xxx Khati Sha variant. DB query for `name LIKE '%khati%sha%'` returns: 154145 (Khati_Sha_the_Twisted, the acrylia Phase 5a boss — now at 90k HP per Phase 5a), 154161 (Fabled variant, excluded by max_expansion filter), 155219/155223/155236/155242 (Khati_Sha_Marook/Guraat/Mylia/Jaarin — Vah Shir trainers L45-50, not raid targets). Zero 158xxx results. Decision #55 confirmed correct.

**Phase 5b Protocol Summary — all 13 questions answered:**
Phase 5b is 100% server-side. Zero opcode changes. One DT DELETE (spell 1948, list 229). Critical spawn2 zone correction: VT boss respawn rows are in `overthere`, not `vexthal` — SQL must scope correctly.

**Outcome:** Architect unblocked for Phase 5b architecture doc.

### 2026-04-22 — architect → config-expert: formal 12-question Phase 5b config brief

**From:** architect → **To:** config-expert

Formal 12-question advisory request covering: rule drift check, zone ruleset, DZ check, DT sweep (headline bosses + all Yaemiu trash), respawn philosophy 24h alignment, #reloadworld behavior, hp bigint overflow check, backup table naming, spawn conditions, out-of-era/Fabled exclusion, and cumulative rule drift summary for project record.

### 2026-04-22 — config-expert → architect: 12-question response

**From:** config-expert → **To:** architect

**Q1:** rule_values=1,112. Zero drift. Confirmed.

**Q2:** vexthal: ruleset=1, expansion=3, insttype=0, version=0. Default ruleset, Luclin era, not a DZ zone.

**Q3:** dynamic_zones table 0 rows. No DZ/expedition config for vexthal.

**Q4 — DT HIT:** Spell 1948 "Destroy" (cast_time=0, mana=0, effect_base_value1=-100,000) in npc_spells_id=229 (#Aten_Ha_Ra non-destroy, NPC 158006). min_hp=0, max_hp=0 — fires at any HP level. Full DT profile. **data-expert: DELETE FROM npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948.** Destroy variant (158096, list 540) is clean. All other VT boss spells (2144 Shadow Warding, 2157 Word of Command, 2162 Black Winds, 2163 Lure of Shadows, 2164 Silence, 2167 Fling) are clean — none DT profile. Zone-restart caveat: infra-expert full restart required post-SQL to flush in-memory list 229.

**Q5:** VT trash spell lists 1, 2, 8, 9, 448, 1472, 1473 audited. Lists 448/1472/1473 empty. Lists 1/2/8/9 are standard class libraries — largest negative value -2,740 (wizard DD with cast_time=7000, mana=640). No DT profile anywhere.

**Q6:** No rule or config concern with 24h on wing bosses. spawn2 UPDATE to 86,400s is clean. Aten Ha Ra has no spawn2 rows — Perl-hardcoded at ~1.8-2.0h (`$spawntime = 6480 + rand(720)`). SQL cannot change it. perl-expert required if 24h alignment is desired for AHR.

**Q7:** #reloadworld handles npc_types and spawn2 cleanly. Exception: spell 1948 DELETE requires full zone restart (same precedent as Phase 2 PoSky and Phase 5a Akheva).

**Q8:** npc_types.hp is bigint(20). 1,901,500 is well within range. Titanium client renders percentage — no overflow risk.

**Q9:** Backup naming confirmed: `_raid_scaling_luclin_b`. Three tables: npc_types_backup_raid_scaling_luclin_b, spawn2_backup_raid_scaling_luclin_b, npc_spells_entries_backup_raid_scaling_luclin_b.

**Q10:** spawn_conditions and spawn_condition_values for vexthal: both 0 rows. All spawn2 rows use _condition=0, cond_value=1 (unconditional default). No VP-style condition filtering. No accidental variant hits.

**Q11:** Only out-of-era flag: NPC 158095 #Aten_Trigger (L90, 50M HP, raid_target=0). Must be excluded from npc_types UPDATEs. raid_target=1 scope guard covers it; `AND level < 70` adds safety. No Fabled NPCs in VT range. npc_types has no expansion columns.

**Q12:** Zero rule_values changes across entire project (Phases 2-5b). Pure data-layer work throughout.

**Outcome:** Architect has all inputs for Phase 5b architecture doc. One DT DELETE (list 229, spell 1948) required — adds npc_spells_entries backup table and zone-restart requirement to Phase 5b.

