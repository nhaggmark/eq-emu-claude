# EQ Project — Claude Code Instructions

## Orchestrator Role

When working on features that follow the agent workflow (see `claude/AGENTS.md`),
the orchestrator session (this session) is a **state
manager and dispatcher only**. It does NOT do feature work directly.

### The orchestrator DOES:

- Invoke the bootstrap-agent to set up workspaces
- Create teams (`TeamCreate`) and spawn agents (`Task` with `team_name`)
- Create and assign tasks (`TaskCreate`, `TaskUpdate`)
- Relay messages between the user and agent teams
- Monitor progress via `TaskList` and agent messages
- Shut down teams (`SendMessage` type `shutdown_request`, then `TeamDelete`)
- Update `status.md` phase transitions between teams

### The orchestrator does NOT:

- Write PRDs, architecture docs, implementation code, or test plans
- Research the codebase on behalf of agents
- Make design, architecture, or implementation decisions
- Fill in templates or agent deliverables
- Self-certify reviews that belong to a peer agent (e.g. lore review)
- Bypass the workflow by doing an agent's job "because it's faster"

### Why this matters

When the orchestrator does agent work directly, it:
1. Skips peer review (lore-master never reviews, advisors never consulted)
2. Leaves `agent-conversations.md` empty (no audit trail of decisions)
3. Concentrates all context in one window instead of distributing it
4. Makes the agent definitions, templates, and workflow docs dead weight
5. Prevents agents from catching errors the orchestrator might miss (e.g. the
   architect catching that 99.2% of NPCs have manual stats)

### When it's OK to work directly

- Ad-hoc tasks that don't follow the feature workflow (quick DB queries,
  one-off config changes, exploratory research)
- Retrospectives, documentation updates, workflow improvements
- Tasks the user explicitly asks to be done without the agent workflow
- Infrastructure/tooling work outside the feature pipeline

## Workflow Reference

- **Full pipeline + agent catalog:** `claude/AGENTS.md`
- **Project definition:** `claude/PROJECT.md`
- **Operations manual:** `claude/README.md`

## Feature Workflow Summary

Every feature follows this pipeline. The orchestrator dispatches each phase
but never performs the work itself.

```
1. Bootstrap    → bootstrap-agent (solo)
2. Design       → TeamCreate → game-designer + lore-master
3. Architecture → TeamCreate → architect + protocol-agent + config-expert
4. Implement    → TeamCreate → assigned experts from architecture plan
5. Validate     → game-tester (solo)
6. Complete     → user merges branch
```

Between phases: shut down the current team, then create the next one.

## Project Context

Custom EverQuest server: Classic through Luclin, 1–6 players, Titanium client.
Signature feature: recruit-any-NPC companion system.

### Repositories

| Directory | Tech | Role |
|-----------|------|------|
| `eqemu/` | C++20, Perl, Lua | Server source (mounted into container as /home/eqemu/code/) |
| `akk-stack/` | Docker, Make | Deployment stack, runtime data, quest scripts |
| `spire/` | Go, Vue.js | Web admin toolkit |

### Key Paths

| What | Path |
|------|------|
| C++ source | `eqemu/` |
| Quest scripts (Perl/Lua) | `akk-stack/server/quests/` |
| Lua modules | `akk-stack/server/lua_modules/` |
| Perl plugins | `akk-stack/server/plugins/` |
| Server configs | `akk-stack/server/eqemu_config.json`, `login.json` |
| Database | MariaDB `peq` db, 250 tables, accessible via `docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq` |
| Built binaries | `eqemu/build/bin/` |
| Server logs | `akk-stack/server/logs/` |
| Topography docs | `claude/docs/topography/` (C-CODE.md, PROTOCOL-CODE.md, PERL-CODE.md, LUA-CODE.md, SQL-CODE.md) |
| Project definition | `claude/PROJECT.md` |

### Build Cycle

1. Edit source on host
2. `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
3. Restart via Spire (http://192.168.1.86:3000) or `make restart` from akk-stack/

### Conventions

- Era lock: Classic, Kunark, Velious, Luclin only
- Lua preferred over Perl for new quest scripts
- All credentials in `akk-stack/.env` — never hardcode
- Prefer `docker exec` over interactive shell
- Commit messages describe "why" not "what"
