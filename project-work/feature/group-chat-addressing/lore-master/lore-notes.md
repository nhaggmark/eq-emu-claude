# Group Chat Companion Addressing — Lore Notes

> **Feature branch:** `feature/group-chat-addressing`
> **Author:** lore-master
> **Date started:** 2026-03-07

---

## Feature Concept

Quality-of-life communication feature allowing players to address recruited
NPC companions via `@Name` in `/gsay` without changing their target. Purely
mechanical — no new NPCs, zones, factions, items, or narrative content. The
only lore-touching elements are the example scenario (Sebilis, Kunark era)
and the NPC name prefix stripping list.

---

## Lore Research

### Zones

| Zone | Short Name | Lore Context | Source |
|------|-----------|--------------|--------|
| Old Sebilis | `sebilis` | Ancient capital of the Iksar Empire, destroyed by Trakanon after Emperor Ganak's death. Currently occupied by Froglok clans (Frogloks of Sebilis faction) and undead Iksar remnants. Kunark-era content. | PEQ database, EQ Lore Wiki |

### NPCs & Characters

| NPC | Zone | Role | Faction | Lore Notes | Source |
|-----|------|------|---------|------------|--------|
| Sebilite Juggernaut | Old Sebilis | Golem/construct mob | Sebilite | Confirmed in-game mob name. Drops Kunark spell scrolls, associated with path to Trakanon's lair. | PEQ database |

### Factions

No factions directly affected by this feature. Companion addressing is
faction-agnostic — it routes commands regardless of faction standing.

### Deities & Races

No deity or racial considerations. The feature is a communication mechanism
that does not reference or depend on any deity or racial content.

### Historical Context

No historical context required. The feature does not introduce or reference
any timeline events or expansion arcs.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| `/gsay` chat channel | Classic | Yes | Has existed since EQ launch |
| `@` syntax | N/A (server-side) | Yes | Client sends raw text unaware of special meaning; no Titanium opcode changes |
| `!command` system | Existing | Yes | Routes existing commands through new channel, no new functionality |
| Sebilis example scenario | Kunark | Yes | All mob names, zone layout references, and atmospheric descriptions verified accurate |
| NPC prefix list | Classic-Luclin | Yes | All prefixes (Guard, Captain, etc.) attested in PEQ database for Classic-Luclin NPCs |

**Hard stops:** None. No era violations found anywhere in the PRD.

---

## PRD Section Reviews

### Review: Complete PRD (all sections)

- **Date:** 2026-03-07
- **Verdict:** APPROVED
- **Approved items:**
  - Era compliance: /gsay is Classic-era, @-syntax is server-side only, no post-Luclin references
  - Sebilis example scenario: Sebilite Juggernauts, Iksar necromancers, zone layout references all confirmed accurate to Kunark lore
  - Companion dialogue examples: Tone matches EQ's terse, atmospheric style; content accurate to zone population
  - Level 45 SK appropriate for Sebilis (zone scales roughly 40-55 in PEQ databases)
  - Overall feature concept: Purely mechanical, no lore concerns
- **Issues found:**
  - None blocking
- **Suggestions offered:**
  - Add five NPC title prefixes to the stripping list based on PEQ database audit: **Lieutenant**, **Warden**, **Keeper**, **Deputy**, **Sergeant**
  - Four rarer prefixes noted for future consideration if list becomes configurable: Hierophant, Squire, Brother, Sheriff
  - Note for architect: zone short name for Sebilis is `sebilis` internally (players call it just "Sebilis" colloquially, which the PRD does correctly)
- **Game-designer response:** Prefix list updated to include the five recommended additions. PRD status changed to Approved.

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | Add Lieutenant, Warden, Keeper, Deputy, Sergeant to prefix strip list | Attested in PEQ database for Classic-Luclin city NPCs (Felwithe, Qeynos, Erudin, Cabilis, Rivervale, Shar Vahl) | Keeping original shorter list — would miss common recruitable NPC prefixes |
| 2 | Defer Hierophant, Squire, Brother, Sheriff | Rarer prefixes; better handled by configurable prefix list (architect decision) | Adding all immediately — overcomplicates initial implementation |

---

## Final Sign-Off

- **Date:** 2026-03-07
- **Verdict:** APPROVED
- **Summary:** The PRD is lore-clean. It introduces no narrative content, no new NPCs or zones, and no era-inappropriate references. The Sebilis example scenario is accurate to Kunark lore in all details (mob names, zone layout, atmospheric descriptions, level appropriateness). The NPC prefix stripping list has been expanded with five additional Classic-Luclin title prefixes verified against the PEQ database. No blocking lore concerns exist.
- **Remaining concerns:** None. The feature is purely mechanical and does not touch lore-sensitive systems.

---

## Context for Next Phase

**For the architect and implementation team:**

1. **Zone naming:** The PRD example references "Sebilis" — the internal zone short name is `sebilis`. Use this for any zone-specific logic or testing.

2. **Prefix list extensibility:** The lore-master identified at least 9 additional NPC title prefixes beyond the original list. Consider making the prefix strip list configurable (rule value, config file, or database table) rather than hardcoded, to accommodate future companion recruitment from diverse zones and cultures.

3. **No lore constraints on implementation:** This feature has no lore-sensitive implementation requirements. The architect has full freedom on technical approach. The only lore touchpoint is ensuring companion names display correctly in group chat (using the companion's actual in-game name as the speaker).
