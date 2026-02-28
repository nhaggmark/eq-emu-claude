# NPC LLM Integration — Dev Notes: infra-expert

> **Feature branch:** `feature/npc-llm-integration`
> **Agent:** infra-expert
> **Task(s):** #3 — Design Docker deployment for LLM sidecar
> **Date started:** 2026-02-23
> **Current stage:** Stage 3: Complete — architect confirmed all decisions. Awaiting implementation phase dispatch.

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Design Docker deployment for LLM sidecar | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/docker-compose.yml` | 246 | Base service definitions. Network named `backend` (driver: bridge from `NETWORKS_DRIVER`). Named volumes: build-cache, spire-assets, eqemu-var-log, mariadb-var-log. All services on `backend` network except fail2ban (host mode). |
| `akk-stack/docker-compose.dev.yml` | 18 | Dev overrides: eqemu-server uses v16-dev image, adds shared-pkg and go-build-cache volumes. Pattern: override only what changes. |
| `akk-stack/.env` | 89 | `NETWORKS_DRIVER=bridge`, `VOLUMES_DRIVER=local`, `IP_ADDRESS=192.168.1.86`, `TZ=US/Eastern`. No LLM keys yet. |
| `claude/docs/plans/2026-02-23-llm-npc-integration-plan.md` | 806 | Section 10 (Deployment Topology): plan suggests `akk-stack_default` network — INCORRECT. Actual network is `backend` within compose (external name `akk-stack_backend`). Sidecar port: 8100. Model file: mistral-7b-instruct-v0.3.Q4_K_M.gguf. Memory limit: 8GB. |
| `claude/project-work/feature-npc-llm-integration/game-designer/prd.md` | 479 | Phase 1 is stateless (no Pinecone). Endpoints: `POST /v1/chat`, `GET /v1/health`. No Pinecone API key needed for Phase 1. Python sidecar: FastAPI + llama-cpp-python. |

### Key Findings

1. **Network name**: Within compose files the network is called `backend`. Docker names it `akk-stack_backend` externally. The integration plan incorrectly states `akk-stack_default` — this must be corrected.

2. **Lua connectivity**: The integration plan's Appendix B shows `sidecar_url = "http://akk-stack-npc-llm:8100"`. Since all containers share the `backend` network, Docker DNS resolves service names directly. The Lua `io.popen`/curl call in the eqemu-server container reaches the sidecar via `http://npc-llm:8100` (service name, no project prefix needed within compose).

3. **Compose override pattern**: The project uses `docker-compose.yml` (base) + `docker-compose.dev.yml` (dev overrides). For the sidecar I should create a new `docker-compose.npc-llm.yml` override that can be included selectively, rather than polluting the base compose. This allows the feature to be opt-in during development and keeps production safe.

4. **Model file location**: The GGUF model file (~4GB) lives on the host at `D:\Dev\EQ\akk-stack\npc-llm-sidecar\models\`. This path is on the D: drive (Windows host, accessed via WSL). All volume mounts in this project use paths relative to the `akk-stack/` directory, so `./npc-llm-sidecar/models:/models` is correct.

5. **Phase 1 is stateless**: No Pinecone. No `PINECONE_API_KEY` needed yet. The compose config should include the env var placeholder commented out, ready for Phase 2, but not required now.

6. **GPU passthrough**: The host has no confirmed GPU available for Docker. For CPU inference, the `deploy.resources` limits approach is used for memory cap. GPU support via `deploy.resources.reservations.devices` (NVIDIA) is noted for future use but not active in Phase 1.

7. **Dockerfile needed**: No existing Python sidecar container in `akk-stack/containers/`. Need to create `akk-stack/npc-llm-sidecar/` directory with:
   - `Dockerfile` — Python 3.11 slim + FastAPI + llama-cpp-python
   - `app/` — Python application code (Phase 4 build, not infra-expert's job)
   - `models/` — empty dir with `.gitkeep` (model file downloaded separately, gitignored)
   - `config/` — zone cultural context JSON (populated by lua-expert or config-expert)

8. **Health check**: `GET /v1/health` returns `{"status": "ok", "model_loaded": true}`. Docker healthcheck polls this. The check must use `curl` (available in the sidecar Python container via install) or `wget`.

9. **Restart policy**: `unless-stopped` — consistent with all other akk-stack services.

10. **Port exposure**: Port 8100 should NOT be exposed externally (no `${IP_ADDRESS}:8100:8100`). The sidecar is internal-only. The eqemu-server container reaches it via Docker DNS over the `backend` network. No external port binding needed.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/docker-compose.npc-llm.yml` | Create | New compose overlay defining the `npc-llm` service |
| `akk-stack/npc-llm-sidecar/Dockerfile` | Create | Python 3.11 slim image with FastAPI + llama-cpp-python |
| `akk-stack/npc-llm-sidecar/models/.gitkeep` | Create | Placeholder so dir is tracked; model file gitignored |
| `akk-stack/npc-llm-sidecar/config/.gitkeep` | Create | Placeholder for zone cultural context config |
| `akk-stack/.gitignore` (or new `.gitignore` in subdir) | Create | Ignore `*.gguf` model files |
| `akk-stack/.env` | Modify | Add `LLM_MODEL_PATH`, `LLM_MAX_TOKENS`, `LLM_TEMPERATURE`, `LLM_PORT` (with commented Pinecone placeholders for Phase 2) |
| `akk-stack/Makefile` | Modify | Add `up-llm` and `down-llm` targets |

**Change sequence:**
1. Create `npc-llm-sidecar/` directory scaffold (Dockerfile, models/, config/)
2. Add `.gitignore` rules for model files
3. Write `docker-compose.npc-llm.yml`
4. Add env vars to `.env`
5. Add Makefile targets
6. Validate with `docker compose -f docker-compose.yml -f docker-compose.npc-llm.yml config`

**What to test:**
- `docker compose config` renders without errors
- Service appears on `backend` network
- Memory limit applies
- Health check endpoint syntax is valid

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `deploy.resources.limits.memory` | Context7 /docker/compose | Yes | Valid in Compose spec. Sets hard memory limit on container. Value: `8g` or `8192m`. |
| `deploy.resources.reservations.devices` (GPU) | Context7 /docker/compose | Yes | Valid for NVIDIA GPU passthrough. Requires `nvidia-container-toolkit` on host. Uses `driver: nvidia`, `count: 1`, `capabilities: [gpu]`. Not active in Phase 1. |
| `healthcheck.test` format | Context7 /docker/compose | Yes | `["CMD", "curl", "-f", "http://localhost:8100/v1/health"]`. Interval/timeout/retries standard. Start period needed for model load (~60s). |
| `restart: unless-stopped` | Context7 /docker/compose | Yes | Standard restart policy. Consistent with other akk-stack services. |
| Network `backend` reference | Live docker inspect | Yes | `docker network ls` confirms `akk-stack_backend` exists. Within compose, referenced as `backend:` under service networks and top-level networks. |
| `build.context` + `dockerfile` | Context7 /docker/compose | Yes | `build: context: ./npc-llm-sidecar` is valid. Dockerfile picked up automatically if named `Dockerfile`. |
| Compose override file merging | Context7 /docker/compose | Yes | Multiple `-f` flags merge services. Top-level `networks:` and `volumes:` sections merge additively. |

### Plan Amendments

**Amendment 1**: The `deploy.resources.limits.memory` key is only honored by Docker Swarm in strict mode and by default Docker engine when using `--compatibility` flag with plain `docker compose`. For local development without Swarm, the memory limit is advisory via `mem_limit` at the service level (pre-Compose v2 style) OR via `deploy.resources.limits.memory` which Docker Compose v2 respects without Swarm. Verification: Docker Compose v2 docs confirm `deploy.resources` is respected for `docker compose up` without Swarm. Use `deploy.resources.limits.memory: 8g` — this is correct.

**Amendment 2**: `healthcheck.start_period` is needed. Loading a 4GB GGUF model takes 30–90 seconds. Without `start_period`, Docker will mark the container unhealthy immediately on startup. Set `start_period: 90s`.

**Amendment 3**: The sidecar's `curl` dependency for the healthcheck — use `CMD-SHELL` form instead of `CMD` array if the Python base image doesn't have curl. Better: install `curl` in the Dockerfile, OR use Python's built-in to avoid an extra package. Use `CMD-SHELL` with Python one-liner as fallback. Primary: install curl in Dockerfile (simpler healthcheck syntax).

### Verified Plan

See Implementation Plan above with these amendments:
- Use `deploy.resources.limits.memory: 8g` (Compose v2 honors this)
- Add `start_period: 90s` to healthcheck
- Install `curl` in Dockerfile for healthcheck use
- `PYTHONUNBUFFERED=1` env var in container for clean logging

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Docker deployment design for LLM sidecar — ready for architecture doc | Does the npc-llm service name align with the Lua bridge config? Any concerns about the compose overlay approach vs inline addition? |

### Feedback Received

**From architect (2026-02-23):**

Architect requested answers to 7 specific questions before writing the architecture doc:
1. Separate compose file vs addition to existing?
2. Base image for Python FastAPI + llama-cpp-python sidecar?
3. Model file location and mounting strategy?
4. How does eqemu-server reach the sidecar? Port?
5. Is `curl` installed in eqemu-server container? (CRITICAL for Lua io.popen)
6. Memory and CPU limits?
7. Health check configuration?

**Live verifications performed:**
- `curl` confirmed at `/usr/bin/curl` (v7.88.1) inside `akk-stack-eqemu-server-1` — Lua `io.popen`/curl approach is valid
- eqemu-server container OS: Debian GNU/Linux 12 (bookworm)
- Host CPU count: 12 cores
- Host RAM: ~8GB total, ~4.3GB currently free — TIGHT FIT for Mistral 7B Q4_K_M (~4-6GB needed)

**RAM constraint flagged to architect**: With only ~8GB total host RAM and ~4.3GB currently free, the 8g memory limit for the sidecar is the entire host capacity. The existing akk-stack containers (mariadb, eqemu-server, spire, etc.) are already consuming ~3.7GB. Running Mistral 7B Q4_K_M requires a host with 16GB RAM or swapping to a smaller model (Mistral 7B Q2 ~2.5GB, or Phi-2 ~1.7GB).

**Container image recommendation**: Custom Dockerfile based on `python:3.11-slim` rather than a pre-built llama-cpp-python image. The pre-built images (`ghcr.io/abetlen/llama-cpp-python`) are large (~3-5GB) and the CPU-only variant is sufficient for Phase 1. Custom Dockerfile gives control over dependencies and is consistent with existing akk-stack container build pattern.

### Consensus Plan

_All architect questions answered. Design confirmed with one critical amendment: RAM constraint means the 8g memory limit may not be achievable without swapping containers or upgrading host RAM. Architect must address this in the architecture doc._

**Agreed approach:**

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/docker-compose.npc-llm.yml` | Create | New compose overlay for npc-llm service |
| `akk-stack/npc-llm-sidecar/Dockerfile` | Create | python:3.11-slim + curl + FastAPI + llama-cpp-python |
| `akk-stack/npc-llm-sidecar/requirements.txt` | Create | Python deps (python-expert populates app/, infra creates requirements stub) |
| `akk-stack/npc-llm-sidecar/models/.gitkeep` | Create | Placeholder; *.gguf gitignored |
| `akk-stack/npc-llm-sidecar/config/.gitkeep` | Create | Placeholder for zone_cultures.json |
| `akk-stack/npc-llm-sidecar/app/.gitkeep` | Create | Placeholder for Python app (python-expert's domain) |
| `akk-stack/npc-llm-sidecar/.gitignore` | Create | Ignore *.gguf, *.bin, models/* |
| `akk-stack/.env` | Modify | Add LLM_MODEL_PATH, LLM_PORT, LLM_MAX_TOKENS, LLM_TEMPERATURE |
| `akk-stack/Makefile` | Modify | Add up-llm, down-llm, build-llm targets |

**Change sequence (final):**
1. Create npc-llm-sidecar/ directory scaffold
2. Write docker-compose.npc-llm.yml
3. Add env vars to .env
4. Add Makefile targets
5. Validate with `docker compose config`

---

## Stage 4: Build

### Task #5: Create Docker deployment files — COMPLETE (2026-02-23)

**Files created/modified:**

| File | Action | Notes |
|------|--------|-------|
| `akk-stack/docker-compose.npc-llm.yml` | Created | Compose overlay with npc-llm service on backend network |
| `akk-stack/npc-llm-sidecar/.gitignore` | Extended | Added models/*.bin, models/*.safetensors, !models/.gitkeep |
| `akk-stack/npc-llm-sidecar/models/.gitkeep` | Already present | Created by python-dev agent |
| `akk-stack/npc-llm-sidecar/config/.gitkeep` | Created | Placeholder for zone_cultures.json |
| `akk-stack/.env` | Modified | Added LLM_MODEL_PATH, LLM_PORT, LLM_MAX_TOKENS, LLM_TEMPERATURE |
| `akk-stack/Makefile` | Modified | Added up-llm, down-llm, build-llm targets |

**Compose validation:**
`docker compose -f docker-compose.yml -f docker-compose.npc-llm.yml config` — PASS

Resolved npc-llm service confirms:
- memory limit: 8589934592 (8 GB)
- healthcheck: CMD curl -sf http://localhost:8100/v1/health
- start_period: 1m30s (90s)
- volumes: models and config read-only
- network: backend
- No external port binding

**Note on python-dev agent:** The python-dev agent already created `npc-llm-sidecar/Dockerfile`, `requirements.txt`, `app/` directory with all Python files, and `models/.gitkeep`. The Dockerfile uses `app.main:app` entry point (correct for the subdirectory structure). No changes to those files were needed.

---

### Task #6: Verify curl in eqemu-server container — COMPLETE (2026-02-23)

**Commands run:**
```
docker exec akk-stack-eqemu-server-1 which curl
  → /usr/bin/curl

docker exec akk-stack-eqemu-server-1 curl --version
  → curl 7.88.1 (x86_64-pc-linux-gnu) libcurl/7.88.1 OpenSSL/3.0.15 ...
  → Release-Date: 2023-02-20, security patched: 7.88.1-10+deb12u8
  → Protocols: dict file ftp ftps gopher ... http https ...
```

**Finding:** curl 7.88.1 is installed at `/usr/bin/curl` inside the eqemu-server container. Supports HTTP/HTTPS. The Lua `io.popen`/curl approach for calling the LLM sidecar is fully validated.

**No workaround needed.** The `llm_bridge.lua` curl command will work as designed in the architecture doc.

---

## Deployment Design (for architect reference)

### Compose Overlay: `docker-compose.npc-llm.yml`

```yaml
# docker-compose.npc-llm.yml
# LLM sidecar for NPC conversation feature (Phase 1: Foundation)
# Usage: docker compose -f docker-compose.yml -f docker-compose.npc-llm.yml up -d
# Dev:   docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.npc-llm.yml up -d

networks:
  backend:
    driver: ${NETWORKS_DRIVER}

services:
  npc-llm:
    build:
      context: ./npc-llm-sidecar
    container_name: akk-stack-npc-llm-1
    restart: unless-stopped
    networks:
      - backend
    # No external port binding — internal only via Docker DNS
    # eqemu-server reaches sidecar at http://npc-llm:8100
    environment:
      - MODEL_PATH=${LLM_MODEL_PATH:-/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf}
      - LLM_PORT=${LLM_PORT:-8100}
      - MAX_TOKENS=${LLM_MAX_TOKENS:-200}
      - TEMPERATURE=${LLM_TEMPERATURE:-0.7}
      # Phase 2+ (Pinecone memory — not needed for Phase 1)
      # - PINECONE_API_KEY=${PINECONE_API_KEY}
      # - PINECONE_INDEX=${PINECONE_INDEX}
      - PYTHONUNBUFFERED=1
      - TZ=${TZ:-US/Eastern}
    volumes:
      - ./npc-llm-sidecar/models:/models:ro          # GGUF model file (read-only)
      - ./npc-llm-sidecar/config:/config:ro           # Zone cultural context JSON
      - ./server/logs:/logs                           # Sidecar logs alongside server logs
    deploy:
      resources:
        limits:
          memory: 8g                                  # Mistral 7B Q4_K_M needs ~4-6GB
        # GPU passthrough (future Phase 3 — requires nvidia-container-toolkit on host)
        # reservations:
        #   devices:
        #     - driver: nvidia
        #       count: 1
        #       capabilities: [gpu]
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8100/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s    # Model load takes 30-90s; don't fail-fast on startup
```

### Dockerfile: `npc-llm-sidecar/Dockerfile`

```dockerfile
FROM python:3.11-slim

# Install curl (needed for Docker healthcheck) and build tools for llama-cpp-python
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
# llama-cpp-python compiled for CPU (no CUDA) — swap for CUDA build in Phase 3
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 8100

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8100"]
```

### `npc-llm-sidecar/requirements.txt` (advisory — python-expert implements)

```
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
llama-cpp-python>=0.2.56
pydantic>=2.0.0
# Phase 2+:
# sentence-transformers>=2.6.0
# pinecone-client>=3.0.0
```

### `.env` additions

```bash
###########################################################
# NPC LLM Sidecar
###########################################################
LLM_MODEL_PATH=/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf
LLM_PORT=8100
LLM_MAX_TOKENS=200
LLM_TEMPERATURE=0.7
# Phase 2+ (Pinecone memory):
# PINECONE_API_KEY=
# PINECONE_INDEX=
```

### `.gitignore` addition (in `npc-llm-sidecar/`)

```
# Model files are large binaries — download separately
*.gguf
*.bin
*.safetensors
models/*
!models/.gitkeep
```

### Makefile targets (to be added)

```makefile
## Start LLM sidecar alongside main stack
up-llm:
	docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.npc-llm.yml up -d

## Stop LLM sidecar only
down-llm:
	docker compose -f docker-compose.yml -f docker-compose.npc-llm.yml stop npc-llm

## Rebuild LLM sidecar image
build-llm:
	docker compose -f docker-compose.yml -f docker-compose.npc-llm.yml build npc-llm
```

### How Lua Reaches the Sidecar

The eqemu-server container and npc-llm container are both on the `backend` network. Docker's internal DNS resolves the service name `npc-llm` to the container's IP. The Lua bridge config uses:

```lua
sidecar_url = "http://npc-llm:8100"
```

This is consistent with the integration plan Appendix B (`http://akk-stack-npc-llm:8100`) but the service name within Docker DNS is just `npc-llm` (the compose service name), not the container name. The container name `akk-stack-npc-llm-1` is the external name but Docker DNS resolves the service name `npc-llm` within the network. The Lua config should use `http://npc-llm:8100`.

### Directory Structure to Create

```
akk-stack/
  npc-llm-sidecar/
    Dockerfile
    requirements.txt          (advisory — implemented by python-expert)
    .gitignore
    models/
      .gitkeep               (model file downloaded here, not committed)
    config/
      .gitkeep               (zone_cultures.json placed here by lua/config expert)
    app/                     (Python application — python-expert's domain)
      .gitkeep
```

---

## Open Items

- [ ] Architect to confirm `npc-llm` as service name (Lua bridge config must match)
- [ ] Architect to confirm compose overlay approach vs inline in base compose
- [ ] Confirm whether `curl` is already available inside eqemu-server container (affects Lua `io.popen` curl command — separate from sidecar healthcheck)
- [ ] Model download instructions for README/ops doc (model is not committed to repo)
- [ ] GPU CUDA instructions deferred to Phase 3 — note in ops doc when time comes
- [ ] Phase 2: add `PINECONE_API_KEY` and `PINECONE_INDEX` to `.env` when Pinecone integration starts

---

## Context for Next Agent

If another agent picks up implementation from this design:

1. **Network**: The internal Docker network is named `backend` in compose files. External Docker name is `akk-stack_backend`. Do not use `akk-stack_default` — that name is wrong.

2. **Compose overlay**: The sidecar goes in `docker-compose.npc-llm.yml`. This is a third overlay alongside `docker-compose.yml` (base) and `docker-compose.dev.yml` (dev). All three are combined with `-f` flags.

3. **Service name matters**: The compose service is named `npc-llm`. Docker DNS resolves this within the `backend` network. The Lua sidecar URL must be `http://npc-llm:8100`. The container name is `akk-stack-npc-llm-1` but that's only used externally.

4. **Model file**: Not in repo. Must be downloaded to `akk-stack/npc-llm-sidecar/models/` before starting the container. Command: `wget https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3.Q4_K_M.gguf -O akk-stack/npc-llm-sidecar/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf`

5. **Phase 1 is stateless**: No Pinecone. Env vars for Pinecone are commented out in the compose file. Python app only needs FastAPI + llama-cpp-python.

6. **Memory limit**: `deploy.resources.limits.memory: 8g` — Docker Compose v2 honors this without Swarm. The Mistral 7B Q4_K_M model needs ~4-6GB RAM.

7. **Health check start_period**: 90 seconds. Model loading is slow. Without this, Docker marks the container unhealthy immediately and may restart it in a loop.
