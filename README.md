# EQ — Developer's Manual

Human-friendly instructions for running the custom EverQuest server and doing piecemeal development work without Claude. For project vision, roadmap, and architecture, see [PROJECT.md](PROJECT.md).

---

## What This Project Is

A custom EverQuest server (Classic through Luclin, 1–6 players, Titanium client) with a signature recruit-any-NPC companion system. Built on three forked open-source projects:

| Directory | What It Is | When You Touch It |
|-----------|-----------|-------------------|
| `eqemu/` | Server source (C++20, Perl, Lua) | Changing server behavior, combat, AI, spells |
| `akk-stack/` | Docker deployment stack | Infrastructure, config, starting/stopping services |
| `spire/` | Web admin toolkit (Go, Vue.js) | Customizing the admin UI |

---

## Prerequisites

- WSL2 (Ubuntu) with Docker Desktop running
- Titanium client (Oct 2006) installed and pointed at `192.168.1.86`
- Git with access to your `nhaggmark/` forks

---

## Directory Layout

```
D:\Dev\EQ\                              (WSL: /mnt/d/Dev/EQ/)
├── akk-stack/                          Docker stack, Makefile, .env, compose files
│   ├── server/                         Runtime data (mounted as /home/eqemu/server/)
│   │   ├── eqemu_config.json           Main server config
│   │   ├── login.json                  Login server config
│   │   ├── quests/                     Perl/Lua quest scripts (hot-reloadable)
│   │   ├── logs/                       Server logs
│   │   ├── maps/                       Zone geometry and pathing
│   │   ├── plugins/                    Shared Perl/Lua plugins
│   │   ├── lua_modules/                Shared Lua modules
│   │   └── bin/                        Symlinks → eqemu/build/bin/
│   ├── assets/                         Deployment scripts (mounted as /home/eqemu/assets/)
│   ├── data/mariadb/                   MariaDB database files (872 MB)
│   └── backup/database/                DB backups (timestamped .tar.gz)
├── eqemu/                              Server C++ source (mounted as /home/eqemu/code/)
│   └── build/bin/                      Compiled binaries (world, zone, loginserver, etc.)
├── spire/                              Admin UI source (Go, Vue.js)
├── claude/                             Project docs, agent system, templates (separate git repo)
│   ├── CLAUDE.md                       Orchestrator instructions (auto-injected into every session)
│   ├── AGENTS.md                       Full workflow pipeline + agent catalog
│   ├── README.md                       This file — human operations manual
│   ├── PROJECT.md                      Vision, roadmap, architecture
│   ├── agents/                         Agent definitions (12 .md files)
│   ├── templates/                      Workflow templates (7 templates)
│   ├── docs/topography/                Codebase reference docs (C++, Protocol, Lua, Perl, SQL)
│   ├── docs/plans/                     Design docs and implementation plans
│   ├── project-work/                   Per-feature working directories
│   └── tmp/                            Gitignored temp storage (large/transient files)
├── install-media/                      Installation resources
└── servers/                            Reserved for future dev/prod server configs
```

## Where Your Files Actually Live

All project data lives on `D:\Dev\EQ` — nothing important is hidden elsewhere.

### On D: (your files — bind-mounted into Docker)

| What | Host Path (under `D:\Dev\EQ\`) | Container Path | Notes |
|------|-------------------------------|----------------|-------|
| C++ source code | `eqemu/` | `/home/eqemu/code/` | Edit on host, build in container |
| Compiled binaries | `eqemu/build/bin/` | `/home/eqemu/code/build/bin/` | `world`, `zone`, `loginserver`, etc. |
| Server runtime | `akk-stack/server/` | `/home/eqemu/server/` | Configs, quests, logs, maps |
| Binary symlinks | `akk-stack/server/bin/` | `/home/eqemu/server/bin/` | Point to `eqemu/build/bin/` (resolve inside container only) |
| Quest scripts | `akk-stack/server/quests/` | `/home/eqemu/server/quests/` | Perl/Lua, organized by zone |
| Server logs | `akk-stack/server/logs/` | `/home/eqemu/server/logs/` | Zone, world, login server logs |
| Deployment scripts | `akk-stack/assets/` | `/home/eqemu/assets/` | Symlink creator, cron, SSH |
| MariaDB data | `akk-stack/data/mariadb/` | `/var/lib/mysql/` | 872 MB — the actual database |
| DB backups | `akk-stack/backup/database/` | — | `.tar.gz` snapshots from `make mysql-backup` |
| Stack config | `akk-stack/.env` | — | Passwords, ports, IP, feature toggles |
| Docker compose | `akk-stack/docker-compose*.yml` | — | Service definitions |
| Project docs | `claude/` | — | README, PROJECT.md, plans |

### In Docker volumes (disposable caches — not on D:)

These live inside Docker's internal storage. They regenerate automatically if deleted and don't contain project data.

| Volume | Container Path | What | Regenerates? |
|--------|---------------|------|--------------|
| `akk-stack_build-cache` | `/home/eqemu/.ccache/` | C++ compilation cache | Yes (first rebuild slower) |
| `akk-stack_go-build-cache` | `/home/eqemu/.cache/` | Go/Spire build cache | Yes |
| `akk-stack_shared-pkg` | `/home/eqemu/pkg/` | Shared packages | Yes |
| `akk-stack_eqemu-var-log` | `/var/log/` | Container system logs | Yes |
| `akk-stack_mariadb-var-log` | MariaDB `/var/log/` | MariaDB system logs | Yes |
| `akk-stack_spire-assets` | `/home/eqemu/.cache/` | Spire asset cache | Yes |

To inspect Docker volumes: `docker volume ls --filter name=akk`

---

## Starting and Stopping

All `make` commands run from `akk-stack/`:

```bash
cd /mnt/d/Dev/EQ/akk-stack
```

| Action | Command |
|--------|---------|
| Start everything | `make up` |
| Stop everything | `make down` |
| Restart | `make restart` |
| Watch running processes | `make watch-processes` |
| Shell into container | `make bash` |
| Show credentials and URLs | `make info` |
| MySQL console | `make mc` |
| Database backup | `make mysql-backup` |

The stack automatically uses `docker-compose.dev.yml` overrides when `ENV=development` is set in `.env` (current setting). This gives you the `v16-dev` image with Clang, Ninja, and ccache.

---

## Admin Interfaces

All credentials live in `akk-stack/.env`. Run `make info` to see them printed out.

| Service | URL | What It's For |
|---------|-----|---------------|
| Spire | http://192.168.1.86:3000 | Primary admin: NPC/item/spell editors, server management, quest API explorer |
| PEQ Editor | http://192.168.1.86:8081 | Classic web-based content editor (HTTP Basic auth) |
| PHPMyAdmin | http://192.168.1.86:8082 | Direct SQL access to the `peq` database (HTTP Basic auth) |
| MariaDB | 192.168.1.86:3306 | CLI/GUI database client access |
| FTP (quests) | 192.168.1.86:21 | Upload quest scripts (user: `quests`, passive ports 30000–30049) |
| SSH | 192.168.1.86:2222 | Container shell (prefer `make bash` or `docker exec` instead) |

---

## Common Activities

### Edit quest scripts

Quest scripts live in `akk-stack/server/quests/`. They're organized by zone name.

1. Edit Perl (`.pl`) or Lua (`.lua`) files directly on the host in `akk-stack/server/quests/`
2. In-game, type `#reloadquests` to hot-reload without restarting the server
3. Alternatively, upload scripts via FTP to `192.168.1.86:21`

### Edit database content (NPCs, items, spells, loot, zones)

Pick whichever tool fits the task:

- **Spire** (http://192.168.1.86:3000) — Best for browsing and visual editing. Has dedicated editors for NPCs, items, spells, loot tables, merchants, zones, and more.
- **PEQ Editor** (http://192.168.1.86:8081) — Simpler web editor, good for quick NPC/item lookups and edits.
- **PHPMyAdmin** (http://192.168.1.86:8082) — Raw SQL. Use when you need to run queries, bulk updates, or inspect table structure.
- **MySQL CLI** — `make mc` from `akk-stack/` for a command-line MySQL prompt.

### Edit server configuration

Key config files in `akk-stack/server/`:

| File | What It Controls |
|------|-----------------|
| `eqemu_config.json` | Server name, DB connection, zone ports, rule values, logging |
| `login.json` | Login server settings |

Edit on host, then restart the relevant server process via Spire or by restarting the stack.

### Build C++ server changes

The dev build pipeline mounts your local `eqemu/` fork into the container. You edit on the host, build inside Docker.

**First time only** (sets up CMake/Ninja/vcpkg — takes ~30 minutes):

```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/ && make init-dev-build"
```

**After editing C++ source:**

```bash
# Option A: one-liner from host
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j\$(nproc)"

# Option B: from inside the container
make bash
# then:
cd ~/code/build && ninja -j$(nproc)
# or use the alias:
n
```

Incremental builds take seconds (ccache). After building:

1. Create symlinks if binary names changed: `perl ~/assets/scripts/create-symlinks.pl` (inside container)
2. Restart servers via Spire dashboard or `make restart` from host
3. Test with Titanium client

**Key paths inside the container** (see [Where Your Files Actually Live](#where-your-files-actually-live) for the full map):

### Back up the database

```bash
cd /mnt/d/Dev/EQ/akk-stack && make mysql-backup
```

Backups land in `akk-stack/backup/database/` as timestamped `.tar.gz` files.

### Test in-game

1. Launch Titanium client pointed at `192.168.1.86`
2. Log in (login server on port 5998, world on 9001)
3. Useful GM commands:
   - `#reloadquests` — hot-reload quest scripts
   - `#zone <shortname>` — teleport to a zone
   - `#summonitem <id>` — create an item
   - `#spawn <npctype_id>` — spawn an NPC

### Monitor and debug

- **Server logs:** `akk-stack/server/logs/`
- **Spire dashboard:** http://192.168.1.86:3000 — shows running zones, connected players, process status
- **Process list:** `make watch-processes` from `akk-stack/`

---

## Port Reference

| Port(s) | Service |
|----------|---------|
| 2222 | SSH |
| 3000–3010 | Spire |
| 3306 | MariaDB |
| 5998–5999, 6000 | Login/World servers |
| 7000–7030 | Zone servers |
| 8080 | Spire dev frontend (hot-reload) |
| 8081 | PEQ Editor |
| 8082 | PHPMyAdmin |
| 9000–9001, 9500 | UCS/QueryServ |

---

## Docker Details

Two compose files combine automatically when `ENV=development`:

- `docker-compose.yml` — All services (eqemu-server, mariadb, spire, editors, FTP, fail2ban)
- `docker-compose.dev.yml` — Overrides: v16-dev image, dev volumes, `SPIRE_DEV=true`

Container names follow the pattern `akk-stack-<service>-1`:

| Container | Role |
|-----------|------|
| `akk-stack-eqemu-server-1` | World, zone, login servers + Spire |
| `akk-stack-mariadb-1` | Database |
| `akk-stack-peq-editor-1` / `-proxy-1` | PEQ Editor + auth proxy |
| `akk-stack-phpmyadmin-1` / `-proxy-1` | PHPMyAdmin + auth proxy |
| `akk-stack-ftp-quests-1` | FTP for quest scripts |

---

## Environment Configuration

Current state in `akk-stack/.env`:

| Setting | Value | Meaning |
|---------|-------|---------|
| `ENV` | `development` | Uses v16-dev image with build tools |
| `SPIRE_DEV` | `true` | Enables Spire dev features |
| `IP_ADDRESS` | `192.168.1.86` | LAN IP for all services |
| `TZ` | `US/Eastern` | Timezone |
| `PORT_RANGE_LOW/HIGH` | `7000/7030` | Zone server port range (30 zones max) |

A backup of the original production `.env` is saved at `claude/.env-bak`.

---

## Project Docs in This Folder

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Orchestrator instructions + project context (auto-injected into every session) |
| [PROJECT.md](PROJECT.md) | Vision, goals, roadmap (Phases 0–8), architecture, web resources |
| [README.md](README.md) | This file — manual operations reference |
| [AGENTS.md](AGENTS.md) | Full agent workflow pipeline + agent catalog |
| [docs/plans/](docs/plans/) | Design docs and implementation plans |
| [templates/](templates/) | 7 workflow templates (status, PRD, architecture, dev-notes, lore-notes, test-plan, agent-conversations) |
| [.env-bak](.env-bak) | Snapshot of original production .env before dev mode switch |

---

## Quick Reference

```bash
# Start the server stack
cd /mnt/d/Dev/EQ/akk-stack && make up

# Stop the server stack
cd /mnt/d/Dev/EQ/akk-stack && make down

# Shell into the server container
cd /mnt/d/Dev/EQ/akk-stack && make bash

# Build C++ changes (from host)
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j\$(nproc)"

# MySQL console
cd /mnt/d/Dev/EQ/akk-stack && make mc

# Back up database
cd /mnt/d/Dev/EQ/akk-stack && make mysql-backup

# View all credentials
cd /mnt/d/Dev/EQ/akk-stack && make info
```
