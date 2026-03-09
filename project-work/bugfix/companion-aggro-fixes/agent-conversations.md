# Agent Conversations — companion-aggro-fixes

## Architecture Team Conversations

### Note on team composition

This bugfix was dispatched directly to the architect as a solo investigation
task (BUG-009). The protocol-agent and config-expert were not consulted
because:

- **protocol-agent**: No client-server protocol issues. The bug is entirely
  server-side in the hate list management code. No packets, opcodes, or
  Titanium constraints are involved.
- **config-expert**: No rule or config changes needed. The bug is a missing
  virtual method override in the C++ class hierarchy. This cannot be solved
  with rules, config, or any non-code approach.

### Architect findings (solo investigation)

**Root cause identified:** `Companion` class does not override
`IsOfClientBotMerc()`, causing it to return `false`. The
`WipeHateList(true)` function in `mob_ai.cpp:1074` purges all non-client,
non-bot, non-merc entries from NPC hate lists every AI tick. Companions are
caught in this purge because they appear as plain NPCs to this check.

**Secondary issue:** SmartAggroList in `hate_list.cpp:481-506` does not
recognize companions as valid tank targets, preferring to route aggro to
clients/bots/mercs even when a companion has the highest hate.

**Fix:** 2 method overrides in `companion.h` + 6 lines in `hate_list.cpp`.
Pure C++, assigned to c-expert.
