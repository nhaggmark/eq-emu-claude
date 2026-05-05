-- Migration: Fix Druid Root spells mis-tagged as Snare in companion_spell_sets
-- Feature: feature/companion-snare-ai
-- Date: 2026-05-03
-- Author: data-expert
--
-- Problem:
--   Druid companion spell set contains two Root-line spells that were tagged
--   spell_type=128 (SpellType_Snare) instead of spell_type=4 (SpellType_Root).
--   The underlying spells in spells_new have effectid=99 (Root / immobilize),
--   NOT effectid=3 (MovementSpeed / Snare).
--
--   This is a data mis-tag. The AI_AttemptMovementControl unified gate introduced
--   by this feature covers both SpellType_Snare and SpellType_Root, so the
--   mis-tag is functionally benign — but the data is inaccurate and would cause
--   confusion in future audits.
--
--   Spell 3192 (Earthen Roots) is correctly tagged spell_type=4 for Ranger (class_id=4).
--   Only the Druid (class_id=6) entries were mis-tagged.
--
-- Broader audit results (2026-05-03):
--   - spell_type=128 with effectid != 3 audit: found 3 rows.
--       * Druid (class_id=6) spell_id=3192 and 3447 — genuine mis-tags (fixed here).
--       * Bard (class_id=8) spell_id=1758 (Selo's Assonant Strain) — FALSE POSITIVE.
--         The snare effect is in effectid1=3 (not effectid2). spell_type=128 is correct.
--   - spell_type=4 with effectid != 99 audit: zero rows found. Root direction is clean.
--
-- Backup of rows BEFORE update:
--   id=776  class_id=6 min_level=61 max_level=63 spell_id=3192 spell_type=128 stance=0 priority=5 min_hp_pct=0 max_hp_pct=0
--   id=782  class_id=6 min_level=64 max_level=65 spell_id=3447 spell_type=128 stance=0 priority=5 min_hp_pct=0 max_hp_pct=0
--
-- Idempotent: WHERE spell_type = 128 ensures re-running after the fix is a no-op.

UPDATE companion_spell_sets
SET spell_type = 4
WHERE class_id = 6
  AND spell_id IN (3192, 3447)
  AND spell_type = 128;

-- Verification: should return 3 rows all with spell_type=4
-- SELECT cs.spell_id, cs.class_id, cs.spell_type, sn.name, sn.effectid2
-- FROM companion_spell_sets cs
-- JOIN spells_new sn ON cs.spell_id = sn.id
-- WHERE cs.spell_id IN (3192, 3447)
-- ORDER BY cs.class_id, cs.spell_id;
