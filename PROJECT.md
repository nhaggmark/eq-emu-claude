# EQ — Custom EverQuest Server Project

## Vision & Goals

A custom EverQuest server running Classic through Shadows of Luclin, designed for a small group of friends (1-6 players). Built on the EQEmu open-source emulator with the Titanium client.

**The defining feature**: a companion recruitment system that lets you convince any NPC in the world to join your party. This replaces the need for a full raid force and makes all content — from group dungeons to raid bosses — accessible to a small group.

### Goals

1. **Recruit-Any-NPC Companion System** — NPCs can be persuaded to join your party based on faction, charisma, quests, or other in-game mechanics. The signature feature.
2. **Small-Group Viability** — Rebalance encounters, loot, and progression so 1-6 players can experience all Classic-Luclin content meaningfully.
3. **Custom Loot & Economy** — Fresh drop tables, new items, rebalanced merchants and tradeskills.
4. **Custom Quests & Story** — New quest lines and NPC dialogue that tie into the companion system and give the world more life.
5. **Class & Combat Tuning** — Adjusted spells, AAs, and combat formulas appropriate for small-group play.
6. **Era Lock** — Classic, Kunark, Velious, Luclin only. No content from later expansions.
7. **Functionality Catalog** — Identify and catalog all functionality across C++, Perl, Lua, and MariaDB to understand the full system and surface improvement opportunities.
8. **Python Modernization** — Migrate all Perl scripting and as much C/C++ functionality as feasible to Python, modernizing the codebase for maintainability and extensibility.

---

## Web Resources & References

### EQEmu Ecosystem

| Resource | URL | Description |
|----------|-----|-------------|
| EQEmu Docs | https://docs.eqemu.dev/ | Official docs: server ops, database schema (200+ tables), quest API, scripting, client support |
| EQEmu GitHub | https://github.com/EQEmu/Server | Source code, issues, releases |
| EQEmu Discord | https://discord.gg/QHsm7CD | Community support |
| akk-stack Dev Guide | https://docs.eqemu.dev/akk-stack/operate/development/ | Dev builds, Spire dev mode, build tooling (Ninja, ccache, Clang) |

### Lore & World Reference

| Resource | URL | Description |
|----------|-----|-------------|
| EverQuest Lore Wiki | https://everquest.fandom.com/wiki/Lore | Ages of Norrath, race/deity histories, expansion storylines |
| EQ Atlas | https://www.eqatlas.com | Classic-era zone maps and layouts |
| Allakhazam/ZAM | https://everquest.allakhazam.com | Item, spell, and quest lookups |

### Database & Content

| Resource | URL | Description |
|----------|-----|-------------|
| PEQ Database | https://www.peqtgc.com/phpPEQ/ | Browse ProjectEQ content online |
| Spire GitHub | https://github.com/Akkadius/spire | Spire source and issues |
| akk-stack GitHub | https://github.com/Akkadius/akk-stack | Deployment stack source |

### Local Tools (via akk-stack)

All verified working. Local IP: `192.168.1.86`. Credentials in `akk-stack/.env`.

| Tool | URL | Auth | Purpose |
|------|-----|------|---------|
| Spire | http://192.168.1.86:3000 | JWT — POST `/auth/login` with `{"username":"admin","password":"<SPIRE_ADMIN_PASSWORD>"}` | Primary admin interface, content editors, quest API explorer |
| Spire Dev FE | http://192.168.1.86:8080 | (same JWT) | Spire frontend dev server (hot-reload) |
| Spire Dev BE | http://192.168.1.86:3010 | (same JWT) | Spire backend dev server |
| PEQ Editor | http://192.168.1.86:8081 | HTTP Basic — `PEQ_EDITOR_PROXY_USERNAME` / `PEQ_EDITOR_PROXY_PASSWORD` | Web-based content editing |
| PHPMyAdmin | http://192.168.1.86:8082 | HTTP Basic — `PHPMYADMIN_USERNAME` / `PHPMYADMIN_PASSWORD` | Direct database access |
| MariaDB | 192.168.1.86:3306 | `MARIADB_USER` / `MARIADB_PASSWORD` (or `root` / `MARIADB_ROOT_PASSWORD`) | MySQL CLI — 231 tables in `peq` database |
| FTP (Quests) | 192.168.1.86:21 | `quests` / `FTP_QUESTS_PASSWORD` | Quest script upload — maps to `server/quests/` |
| SSH | 192.168.1.86:2222 | `SERVER_PASSWORD` | Container shell (prefer `docker exec` instead) |

### Local Repositories

All cloned as forks for customization:

| Directory | Stack | Purpose |
|-----------|-------|---------|
| `eqemu/` | C++, Perl, Lua → Python | Server source — world, zone, login, chat, query servers |
| `akk-stack/` | Docker, Perl, Make | Containerized deployment and build toolchain |
| `spire/` | Go, Vue.js | Web admin toolkit — 237 CRUD controllers, 126 frontend pages |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    EQ Client (Titanium)                  │
│                   Ports: 5998, 9001, 7000-7030           │
└──────────────┬──────────────────────────────┬────────────┘
               │                              │
┌──────────────▼──────────┐    ┌──────────────▼────────────┐
│      Login Server       │    │       World Server        │
│   (Authentication)      │    │   (Coordination, Chat)    │
│   Port: 5998            │    │   Port: 9001              │
└─────────────────────────┘    └──────────────┬────────────┘
                                              │
                               ┌──────────────▼────────────┐
                               │      Zone Servers         │
                               │  (Gameplay, Combat, AI)   │
                               │  Ports: 7000-7030         │
                               │  Perl/Lua Quest Scripts   │
                               └──────────────┬────────────┘
                                              │
                               ┌──────────────▼────────────┐
                               │     MariaDB (peq db)      │
                               │  Items, NPCs, Spells,     │
                               │  Loot, Quests, Zones      │
                               │  Port: 3306               │
                               └──────────────┬────────────┘
                                              │
               ┌──────────────────────────────┼─────────────────┐
               │                              │                 │
┌──────────────▼──────┐  ┌───────────────────▼──┐  ┌──────────▼────────┐
│   Spire (:3000)     │  │  PEQ Editor (:8081)  │  │ PHPMyAdmin (:8082)│
│  Admin, Editors,    │  │  Content Editing     │  │ Direct DB Access  │
│  Server Management  │  │                      │  │                   │
└─────────────────────┘  └──────────────────────┘  └───────────────────┘
```

**akk-stack** wraps all of this in Docker Compose — one `make up` brings everything online.

### Development Flow

- Edit content (items, NPCs, loot, spells) via **Spire** or **PEQ Editor**
- Write quest scripts (Perl/Lua, migrating to Python) in `server/quests/` — hot-reloadable
- Modify server behavior by editing **eqemu** C++ source, rebuild via `make init-build`
- Customize deployment by editing **akk-stack** docker-compose and Makefiles
- Customize admin tools by editing **spire** Go/Vue.js source

### Key Config Files

| File | Purpose |
|------|---------|
| `akk-stack/.env` | Ports, passwords, feature toggles, IP address |
| `server/eqemu_config.json` | Server runtime config (DB, ports, zones, login) |
| `server/login.json` | Login server config |

### Docker Containers

| Container | Purpose |
|-----------|---------|
| `akk-stack-eqemu-server-1` | World, zone, login servers + Spire |
| `akk-stack-mariadb-1` | MariaDB database |
| `akk-stack-phpmyadmin-proxy-1` / `akk-stack-phpmyadmin-1` | PHPMyAdmin + nginx proxy |
| `akk-stack-peq-editor-proxy-1` / `akk-stack-peq-editor-1` | PEQ Editor + nginx proxy |
| `akk-stack-ftp-quests-1` | FTP server for quest scripts |
| `akk-stack-fail2ban-server-1` / `akk-stack-fail2ban-mysqld-1` | Intrusion prevention |

---

## Feature Roadmap

### Phase 0: Foundation

- [x] Get akk-stack running locally on WSL2
- [x] Verify Titanium client can connect and play
- [x] Set up dev build pipeline (edit eqemu source → build in container → deploy)
- [x] Enable all admin services (Spire, PEQ Editor, PHPMyAdmin, FTP, MariaDB CLI)
- [x] Verify all admin interface credentials and connectivity
- [ ] Familiarize with Spire, PEQ Editor, and basic server admin
- [ ] Lock expansion content to Classic through Luclin

### Phase 1: Functionality Catalog

- Map all C++ server systems (combat, AI, pathing, spells, AAs, trade skills, etc.)
- Catalog all Perl quest scripts — what each does, which zones/NPCs they cover
- Catalog all Lua quest scripts and how they differ from the Perl equivalents
- Document MariaDB schema usage — which tables drive which systems, stored procedures, triggers
- Produce a cross-reference matrix: system → language → files → purpose
- Identify candidates for Python migration (high-value, low-risk targets first)
- Identify dead code, duplication, and consolidation opportunities

### Phase 2: Python Modernization

- Evaluate Python integration options (embedded interpreter vs. external scripting vs. replacing Perl/Lua runtime)
- Set up Python scripting runtime alongside existing Perl/Lua in zone servers
- Migrate all Perl quest scripts to Python equivalents
- Identify C++ subsystems suitable for Python migration (tooling, content pipelines, admin utilities first)
- Migrate feasible C++ functionality to Python, starting with lowest-risk systems
- Maintain backward compatibility during transition (Perl scripts continue to work until fully replaced)
- Update development docs and quest-writing guides for Python

### Phase 3: Small-Group Viability

- Audit and rebalance encounter difficulty for 1-6 players
- Adjust XP rates and progression curve
- Tune loot tables so gear progression feels rewarding at small scale
- Ensure all Classic-Luclin content is reachable (keys, flags, access quests)

### Phase 4: Companion Recruitment System

- Design the recruitment mechanic (persuasion, faction, quests, charisma checks?)
- Implement NPC-to-companion conversion (leveraging existing bot/mercenary systems as foundation)
- Build companion AI behavior (tanking, healing, DPS roles based on NPC class)
- Create companion management UI (dismiss, assign roles, set behavior)
- Balance companion power scaling to avoid trivializing content

### Phase 5: Custom Loot & Economy

- Design new items unique to the server
- Rework drop tables for era-appropriate content
- Rebalance merchants and tradeskills
- Create incentives tied to the companion system (gear for companions?)

### Phase 6: Custom Quests & Story

- Write new quest lines that integrate with the companion system
- Add NPC dialogue and personality to recruitable NPCs
- Create story arcs spanning Classic through Luclin
- Reference EQ lore wiki for world-consistent storytelling

### Phase 7: Class & Combat Tuning

- Rebalance spells and abilities for small-group dynamics
- Adjust AAs for Luclin-era cap
- Tune combat formulas (melee, mitigation, resist rates)
- Ensure all classes feel viable in a small group + companions setup

### Phase 8: Polish & Deploy

- Set up remote server deployment via akk-stack
- Configure backups (database + quests)
- Playtest full progression Classic through Luclin
- Iterate based on play experience

> Phase 0 must come first. Phase 1 (functionality catalog) should happen early — it informs both the Python modernization (Phase 2) and all gameplay phases. Phase 2 can overlap with Phase 3 (small-group viability). Phases 4-7 are somewhat independent, though Phase 4 (the companion system) is the keystone feature that everything else builds around.

---

## Development Workflow

### Local Development (WSL2)

- akk-stack runs in Docker on this machine (IP: `192.168.1.86`)
- `make up` / `make down` to start/stop the server stack
- Prefer `docker exec akk-stack-eqemu-server-1 bash -c "<cmd>"` over interactive SSH
- Quest scripts edited directly in `server/quests/` or via FTP (`192.168.1.86:21`) — hot-reloadable
- Database content edited via Spire (`http://192.168.1.86:3000`) or PEQ Editor (`http://192.168.1.86:8081`)
- Direct SQL via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'<password>' peq -e "SQL"`
- C++ server changes: edit in `eqemu/`, rebuild via `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- Spire changes: edit in `spire/`, dev servers at `:8080` (frontend) and `:3010` (backend)

### Testing

- Connect Titanium client to `192.168.1.86`
- Use Spire dashboard to monitor zones, players, and processes
- GM commands in-game for testing (spawn NPCs, grant items, teleport)
- Server logs in `server/logs/` for debugging

### Remote Deployment

- Clone akk-stack to remote Linux server
- Configure `.env` with production IPs, ports, and passwords
- `make install` for fresh setup, `make up` for ongoing
- Backups via `make backup-dropbox-*` or manual `make mysql-backup`
- Friends connect via remote server IP on port 5998 (login) / 9001 (world)

### Version Control

- All three repos (eqemu, akk-stack, spire) are local forks for custom modifications
- Quest scripts and custom content tracked separately
- Database changes exported/versioned as SQL dumps or tracked via Spire audit logs
