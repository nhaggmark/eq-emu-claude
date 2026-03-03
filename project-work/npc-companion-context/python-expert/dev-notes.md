# Python Expert Dev Notes — NPC Companion Context

## Stage 1: Plan (2026-03-03)

### Task
Implement companion prompt handling in the NPC-LLM sidecar. When `is_companion=true`,
the sidecar must switch from standard NPC prompt framing to companion-specific framing.

### Files to Modify

1. **`app/models.py`** — Add all companion fields to `ChatRequest` Pydantic model
2. **`app/prompt_assembler.py`** — Detect `is_companion=true` and build companion-specific
   system prompt with modified Layer 1 (identity), new companion layer, and adjusted layers
3. **`app/prompt_builder.py`** — Update legacy `build_system_prompt()` for companion fallback

### Companion Fields from Lua Bridge (22 fields)
All sent as optional with defaults in the JSON payload:
- `is_companion` (bool, default false)
- `companion_type` (int|null) — 0=loyal, 1=mercenary
- `companion_stance` (int|null) — 0/1/2
- `companion_name` (str|null)
- `time_active_seconds` (int|null)
- `time_active_description` (str|null)
- `evolution_tier` (int|null) — 0/1/2
- `recruited_zone_short` (str|null)
- `recruited_zone_long` (str|null)
- `original_role` (str|null)
- `zone_type` (str|null) — outdoor/dungeon/city/indoor
- `time_of_day` (str|null) — dawn/day/dusk/night/fixed_lighting
- `is_luclin_fixed_light` (bool, default false)
- `in_combat` (bool, default false)
- `hp_percent` (int|null)
- `recently_damaged` (bool, default false)
- `group_members` (list|null) — [{name, race, class_id, level, is_companion}]
- `group_size` (int|null)
- `recent_kills` (str|null) — comma-separated NPC names
- `race_culture_id` (int|null)
- `type_framing` (str|null) — full companion/mercenary framing text from Lua
- `evolution_context` (str|null) — identity evolution text from Lua
- `unprompted` (bool, default false)

### Approach
1. Add all fields to `ChatRequest` with Optional types and defaults (backwards-compatible)
2. In `PromptAssembler.assemble()`, check `req.is_companion`:
   - If true: replace Layer 1 (identity) with companion-specific identity
   - Replace Layer 2 (global context) with companion framing (type_framing + evolution_context)
   - Add companion situation layer (zone, group, activity)
   - Keep Layers 5+ (faction, quest, soul, memory, rules) with minor adjustments
3. In legacy `build_system_prompt()`, add similar companion branching as fallback

### Key Design Decisions
- The Lua bridge already sends rich `type_framing` and `evolution_context` strings that
  contain the complete companion personality framing. The sidecar should USE these directly
  rather than re-deriving them. This avoids duplicating the race/culture logic.
- The companion identity replaces the standard NPC identity — the NPC is no longer
  "Guard Liben, a level 50 Human Warrior in West Freeport" but rather
  "Guard Liben, a companion in [Player]'s adventuring party, formerly a guard in West Freeport"
- Non-companion behavior must be completely preserved.

## Stage 2: Research (2026-03-03)

Pydantic v2 (2.10.4) is used. Optional fields with defaults are fully backwards-compatible.
Pattern: `field: type | None = None` or `field: bool = False`.
Verified against existing code patterns in models.py.

## Stage 3: Socialize (2026-03-03)

Solo implementation — no teammates to coordinate with on this task. The Lua side is
confirmed working and sending all companion fields. This is pure sidecar-side work.

## Stage 4: Build (2026-03-03)

### Implementation Log

#### 4.1 — models.py: Add companion fields to ChatRequest
Added 22 companion fields with Optional types and sensible defaults.

#### 4.2 — prompt_assembler.py: Companion-aware prompt assembly
- When `req.is_companion` is true, Layer 1 uses companion identity framing
- Layer 2 uses `type_framing` and `evolution_context` from the Lua bridge
- New companion situation block (zone awareness, group, activity hints)
- Layers 5-8 preserved with minor companion adjustments

#### 4.3 — prompt_builder.py: Legacy fallback companion support
Updated `build_system_prompt()` to handle companion framing as fallback path.
