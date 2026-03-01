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
- Dispatch bug-fix features through the same pipeline as regular features

### The orchestrator does NOT:

- Write PRDs, architecture docs, implementation code, or test plans
- Research the codebase on behalf of agents
- Make design, architecture, or implementation decisions
- Triage, diagnose, or evaluate bug complexity (engineers do this)
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
6. Complete     → commit/push ALL repos, merge to main, branch cleanup
```

Between phases: shut down the current team, then create the next one.

### Bug Fix Workflow Summary

Bug fixes use the **same pipeline as features**. Standalone bugs (not part
of an active feature) are treated as a new bug-fix feature. The orchestrator
dispatches the pipeline — engineers own triage, diagnosis, and all decisions.

```
1. Bootstrap    → bootstrap-agent (workspace + branch, e.g. bugfix/companion-fixes)
2. Design       → game-designer documents bugs, repro steps, acceptance criteria
3. Architecture → architect triages affected systems, diagnoses root causes, plans fixes
4. Implement    → assigned experts implement fixes
5. Validate     → game-tester verifies all bugs resolved
6. Complete     → commit/push ALL repos, merge to main, branch cleanup
```

Multiple related bugs can be batched into a single bug-fix feature.

### Commit/Push Discipline

Phase 6 (Complete) MUST include commit and push across ALL affected repos
(eqemu/, akk-stack/, claude/). This is the final step of every feature and
bug-fix workflow. Work that is not committed and pushed is not protected.

## Project Context

Custom EverQuest server: Classic through Luclin, 1–3 players, Titanium client.
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
| Titanium client | `/mnt/d/EQ` (crash logs, client data) |

### Build Cycle

1. Edit source on host
2. `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
3. Restart via Spire (http://192.168.1.86:3000) or `make restart` from akk-stack/

### Temporary File Storage

`claude/tmp/` is gitignored and available for storing large or transient files
that should not be version controlled: database dumps, backups, packet captures,
build artifacts, large query results, etc.

Organize by feature name to mirror `project-work/`:
```
claude/tmp/<feature-name>/        ← e.g., tmp/small-group-scaling/
```

Use `tmp/` instead of `context/` when the file is:
- Large (>100KB) — database exports, backups, binary dumps
- Transient — intermediate results, scratch data, one-time analysis
- Reproducible — can be regenerated from source or database

Use `context/` (in `project-work/<feature>/`) when the file is:
- Small and should persist with the project record
- Needed by other agents as a reference artifact
- Part of the feature's audit trail

### Conventions

- Era lock: Classic, Kunark, Velious, Luclin only
- Lua preferred over Perl for new quest scripts
- All credentials in `akk-stack/.env` — never hardcode
- Prefer `docker exec` over interactive shell
- Commit messages describe "why" not "what"
