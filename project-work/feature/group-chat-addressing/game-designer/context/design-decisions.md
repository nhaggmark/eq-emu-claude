# Design Decisions — Group Chat Companion Addressing

## Why /gsay instead of a custom command?

Using `/gsay` with `@name` syntax was chosen over alternatives like `/companion`
or `/cc` because:
1. /gsay is already bound to EQ macros — no client changes needed
2. Players already know where group chat is — zero learning curve
3. The @ convention is intuitive (modern messaging influence)
4. It works within Titanium client constraints (no new opcodes or UI)

## Why substring matching?

Full-name matching would require typing "Guard Iskarr" or "guard_iskarr" — too
long for combat. Substring matching means `@isk` is enough. The risk of
ambiguous matches (e.g., `@a` matching multiple companions) is acceptable
because it's a small group (max 5 companions) and the player controls who
they recruit.

## Why silent failure on unmatched names?

Alternatives considered:
- Error message per unmatched name → too noisy in combat macros
- Suppress entire message on any mismatch → too strict, punishes typos
- Silent failure for unmatched, proceed for matched → best balance

The chosen approach means a macro with 3 commands works even if one companion
was dismissed. The remaining commands still fire.

## Why stagger conversational responses?

Five simultaneous LLM responses in group chat would be unreadable. The 1-2s
stagger creates a natural "speaking order" effect. Random within that range
avoids a mechanical feel. Order determined by LLM response completion time
(whichever finishes first speaks first) adds organic variation.

## Open design tensions

1. **Prefix list maintenance:** The hardcoded prefix list (Guard, Captain, etc.)
   will need updates as new companion types are recruited from different zones.
   Config-file approach is cleaner but adds complexity. Left as architect decision.

2. **Non-owner addressing:** Should other players be able to @mention your
   companions? The 1-3 player design means this is a real scenario (your friend
   wants to tell your healer companion to heal them). Left as open question.
