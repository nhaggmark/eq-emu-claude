# BUG-013: Dead companions cannot be re-recruited without manual DB cleanup

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-09
> **Feature:** companion-aggro-fixes
> **Status:** Open

---

## Observed Behavior

When a companion dies and the user tries to re-recruit them, recruitment
fails. The NPC says "will not join you" or "won't discuss recruitment again
so soon." Manual database intervention (clearing cooldowns, setting
is_dismissed=1) is required each time.

## Root Cause

The death path saves `is_suspended=1, is_dismissed=0`. The Lua recruitment
handler checks for existing companion_data records and rejects when it sees
an active (non-dismissed) record, before the C++ CreateFromNPC() fix ever
runs. Additionally, failed recruitment attempts re-set the cooldown timer,
compounding the problem.

## Expected Behavior

Dead companions should be seamlessly re-recruitable. When a companion has
died (is_suspended=1, cur_hp=0, times_died > 0), the recruitment system
should recognize this as a valid re-recruitment and reuse the existing
record with its equipment intact.

## Affected Systems

- [x] C++ server source -> c-expert
- [x] Lua quest scripts -> lua-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
