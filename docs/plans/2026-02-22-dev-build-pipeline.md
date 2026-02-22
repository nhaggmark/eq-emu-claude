# Dev Build Pipeline Implementation Plan

> **Status:** COMPLETED 2026-02-22. All 7 tasks executed successfully. Titanium client verified connecting to custom-built binaries.

**Goal:** Set up a development build pipeline so we can edit eqemu source locally, compile inside akk-stack's container, and run our custom binaries.

**Architecture:** Replace akk-stack's bundled `code/` directory with our local `eqemu/` fork via docker-compose volume mount. Switch to development mode (`ENV=development`) which uses the `v16-dev` image with full build toolchain. Run `make init-dev-build` inside the container to set up cmake/ninja, then build with the `n` alias.

**Tech Stack:** Docker Compose, CMake, Ninja, Clang, ccache, MariaDB, Perl 5.32.1

---

### Task 1: Back up current working state

Before making any changes, back up the current server state in case we need to roll back.

**Step 1: Back up the database**

Run from the akk-stack directory on the host:

```bash
cd /mnt/d/Dev/EQ/akk-stack && make mysql-backup
```

Expected: A `.tar.gz` file appears in `backup/database/`.

**Step 2: Verify backup exists**

```bash
ls -la /mnt/d/Dev/EQ/akk-stack/backup/database/
```

Expected: A file like `peq-02-22-2026.tar.gz`.

---

### Task 2: Switch akk-stack to development mode

**Files:**
- Modify: `/mnt/d/Dev/EQ/akk-stack/.env`

**Step 1: Stop the running stack**

```bash
cd /mnt/d/Dev/EQ/akk-stack && make down
```

Expected: All containers stop.

**Step 2: Update .env to development mode**

Change these two values in `.env`:

```
ENV=development
SPIRE_DEV=true
```

**Step 3: Verify the changes**

```bash
grep -E '^(ENV|SPIRE_DEV)=' /mnt/d/Dev/EQ/akk-stack/.env
```

Expected:
```
ENV=development
SPIRE_DEV=true
```

---

### Task 3: Mount the local eqemu fork as the code volume

The key change: instead of using akk-stack's bundled `code/` directory, mount our local `eqemu/` fork. This way edits in `/mnt/d/Dev/EQ/eqemu/` are immediately visible inside the container.

**Files:**
- Modify: `/mnt/d/Dev/EQ/akk-stack/docker-compose.yml`

**Step 1: Change the code volume mount**

In `docker-compose.yml`, in the `eqemu-server` service's `volumes` section, change:

```yaml
      - ./code:/home/eqemu/code:delegated
```

to:

```yaml
      - ../eqemu:/home/eqemu/code:delegated
```

**Step 2: Do the same in docker-compose.dev.yml**

In `docker-compose.dev.yml`, change the same line:

```yaml
      - ./code:/home/eqemu/code:delegated
```

to:

```yaml
      - ../eqemu:/home/eqemu/code:delegated
```

**Step 3: Verify both files**

```bash
grep 'eqemu.*code' /mnt/d/Dev/EQ/akk-stack/docker-compose.yml /mnt/d/Dev/EQ/akk-stack/docker-compose.dev.yml
```

Expected: Both files show `../eqemu:/home/eqemu/code:delegated`.

---

### Task 4: Pull dev image and bring up the stack

**Step 1: Pull the development container image**

```bash
cd /mnt/d/Dev/EQ/akk-stack && docker-compose -f docker-compose.yml -f docker-compose.dev.yml pull
```

Expected: Downloads `eqemulator/eqemu-server:v16-dev` image (the dev image has Clang, Ninja, ccache, and other build tools pre-installed).

**Step 2: Build any local container images**

```bash
cd /mnt/d/Dev/EQ/akk-stack && docker-compose -f docker-compose.yml -f docker-compose.dev.yml build
```

Expected: Builds mariadb, fail2ban, and proxy containers.

**Step 3: Bring up the stack**

```bash
cd /mnt/d/Dev/EQ/akk-stack && make up
```

Expected: Containers start. The `make up` command will automatically use both compose files since `ENV=development`.

**Step 4: Verify the code mount**

```bash
cd /mnt/d/Dev/EQ/akk-stack && docker-compose exec eqemu-server bash -c "ls ~/code/CMakeLists.txt && git -C ~/code remote -v"
```

Expected: Shows the CMakeLists.txt exists and the git remote is `nhaggmark/EQEmu` (our fork, not the bundled copy).

---

### Task 5: Initialize the development build

**Step 1: SSH into the container**

```bash
cd /mnt/d/Dev/EQ/akk-stack && make bash
```

This drops you into a bash shell inside the eqemu-server container as the `eqemu` user.

**Step 2: Run the dev build initialization**

Inside the container:

```bash
cd ~/ && make init-dev-build
```

This will:
- Set up cmake with Ninja generator
- Configure Clang compiler with debug symbols
- Set up ccache for build caching
- Configure the dedicated Perl 5.32.1
- Create `~/code/build/` directory with the cmake configuration

Expected: CMake configuration completes without errors. You'll see output about detected compilers, found libraries, and build configuration.

**Step 3: Run the first build**

Inside the container:

```bash
n
```

This runs `cd ~/code/build && ninja -j$(expr $(nproc) - 2)`.

Expected: Full compilation of all server binaries. This will take a while on first build (10-30+ minutes depending on CPU). Subsequent builds will be fast thanks to ccache. Look for successful compilation of: `world`, `zone`, `loginserver`, `ucs`, `queryserv`, `shared_memory`, `eqlaunch`.

**Step 4: Exit the container**

```bash
exit
```

---

### Task 6: Verify the custom binaries are active

**Step 1: SSH back in and check symlinks**

```bash
cd /mnt/d/Dev/EQ/akk-stack && make bash
```

Inside the container:

```bash
ls -la ~/server/bin/world ~/server/bin/zone ~/server/bin/loginserver
```

Expected: Symlinks pointing to `~/code/build/bin/` (not pre-compiled binaries).

**Step 2: Restart the server processes via Spire**

Open Spire in your browser at `http://192.168.1.86:3000` and restart the server processes (world, zones, login), or from inside the container:

```bash
cd ~/server && ./bin/world &
```

**Step 3: Connect with the Titanium client**

Launch EverQuest with the Titanium client and verify you can log in and play. This confirms the custom-built binaries are working correctly.

**Step 4: Exit the container**

```bash
exit
```

---

### Task 7: Verify the edit-build-test cycle

This confirms the full development workflow works end-to-end.

**Step 1: Make a trivial change to the eqemu source**

On the host, edit a log message or comment in a file. For example, in `/mnt/d/Dev/EQ/eqemu/world/main.cpp`, add a comment near the top of the file:

```cpp
// Custom EQ Server - Development Build
```

**Step 2: Rebuild inside the container**

```bash
cd /mnt/d/Dev/EQ/akk-stack && make bash
```

Inside the container:

```bash
n
```

Expected: Ninja detects the changed file and only recompiles what's needed. Should take seconds, not minutes.

**Step 3: Verify the change took effect**

Restart the world server and check logs to confirm the new binary is running.

**Step 4: Revert the trivial change**

Remove the test comment from `world/main.cpp` — we don't want noise in version control.

---

## Summary: Daily Development Workflow

After this setup is complete, the daily workflow is:

1. Edit code in `/mnt/d/Dev/EQ/eqemu/` using your preferred editor on the host
2. SSH into the container: `cd /mnt/d/Dev/EQ/akk-stack && make bash`
3. Build: `n`
4. Restart affected server processes (via Spire or manually)
5. Test in-game with Titanium client
6. Repeat
