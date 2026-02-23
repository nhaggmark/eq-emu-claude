---
name: base-agent
description: Shared project context for all EQ agents
---

## Project: Custom EverQuest Server

Classic through Luclin, 1–6 players, Titanium client. Signature feature:
recruit-any-NPC companion system.

## Repositories

| Directory | Tech | Role |
|-----------|------|------|
| `eqemu/` | C++20, Perl, Lua | Server source (mounted into container as /home/eqemu/code/) |
| `akk-stack/` | Docker, Make | Deployment stack, runtime data, quest scripts |
| `spire/` | Go, Vue.js | Web admin toolkit |

## Key Paths

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
| Topography docs | `claude/docs/topography/` (C-CODE.md, PERL-CODE.md, LUA-CODE.md, SQL-CODE.md) |
| Project definition | `claude/PROJECT.md` |

## Build Cycle

1. Edit source on host
2. `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
3. Restart via Spire (http://192.168.1.86:3000) or `make restart` from akk-stack/

## Conventions

- Era lock: Classic, Kunark, Velious, Luclin only
- Lua preferred over Perl for new quest scripts
- All credentials in `akk-stack/.env` — never hardcode
- Commit messages describe "why" not "what"
