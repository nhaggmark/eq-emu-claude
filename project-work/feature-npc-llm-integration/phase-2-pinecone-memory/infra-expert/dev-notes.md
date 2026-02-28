# NPC Conversation Memory (Pinecone Integration) — Dev Notes: Infra Expert

> **Feature branch:** `feature/npc-llm-integration`
> **Agent:** infra-expert
> **Task(s):** Task #5 — Update Docker config (Pinecone env vars, dependencies, Dockerfile)
> **Date started:** 2026-02-24
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 5 | Update Docker infrastructure for Pinecone and sentence-transformers support | None (independent) | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `npc-llm-sidecar/requirements.txt` | 4 | fastapi, uvicorn, llama-cpp-python, pydantic — no torch |
| `docker-compose.npc-llm.yml` | 54 | Phase 1 env vars, 6GB memory limit, CUDA GPU reservation |
| `npc-llm-sidecar/Dockerfile` | 46 | 2-stage CUDA build: devel for build, runtime for final image |
| `akk-stack/.env` | 102 | Phase 2 Pinecone vars existed as commented-out placeholders |

### Key Findings

- Dockerfile is a 2-stage build. Stage 1 (`nvidia/cuda:12.4.1-devel`) installs all Python packages. Stage 2 (`nvidia/cuda:12.4.1-runtime`) copies `/usr/local/lib/python3.11/dist-packages` from Stage 1.
- CPU-only torch must be installed BEFORE `pip install -r requirements.txt` in Stage 1 to prevent sentence-transformers from triggering a CUDA torch download.
- `requirements.txt` must list `torch` so that when pip processes it after the CPU install, it sees the requirement as satisfied (skips re-download).
- `.env` already had commented Pinecone placeholder lines — replaced with full Phase 2 block.

### Implementation Plan

| File | Action | What Changes |
|------|--------|-------------|
| `npc-llm-sidecar/requirements.txt` | Modify | Add pinecone-client>=5.0.0, sentence-transformers>=3.0.0, torch>=2.0.0 |
| `npc-llm-sidecar/Dockerfile` | Modify | Add CPU torch install step before requirements.txt install in builder stage |
| `docker-compose.npc-llm.yml` | Modify | Add 8 Pinecone/memory env vars in environment block |
| `akk-stack/.env` | Modify | Replace Phase 1 placeholder comment with full Phase 2 Pinecone section |

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `pip install torch --index-url https://download.pytorch.org/whl/cpu` | Architecture.md + PyTorch install docs | Yes | Standard CPU-only install method |
| `${VAR:-default}` in Compose env block | Architecture.md confirms this syntax | Yes | Empty default `${VAR:-}` passes empty string when .env var unset |
| `pinecone-client>=5.0.0` package name | Architecture.md | Yes | v5+ required for serverless index support |

### Plan Amendments

Plan confirmed — no amendments needed.

---

## Stage 3: Socialize

Task #5 is marked independent in architecture.md. No blocking dependencies on other implementation tasks. Python-expert's Tasks 1–4 and lua-expert's Task 4 are all independent parallel work.

No cross-agent concerns: env vars are additive, Dockerfile change is isolated to builder stage.

---

## Stage 4: Build

### Implementation Log

#### 2026-02-24 — requirements.txt

**What:** Added pinecone-client>=5.0.0, sentence-transformers>=3.0.0, torch>=2.0.0 with explanatory comment
**Where:** `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/requirements.txt` lines 5–10
**Why:** sentence-transformers and pinecone-client are the new Phase 2 dependencies. torch is listed explicitly to signal version intent and prevent sentence-transformers from re-pulling a CUDA build when pip resolves dependencies.
**Notes:** torch is intentionally unpinned to avoid CPU wheel URL mismatch. The Dockerfile CPU install step ensures the correct wheel is already present before requirements.txt is processed.

#### 2026-02-24 — Dockerfile

**What:** Added CPU-only PyTorch install step before the main `pip install -r requirements.txt` in the builder stage
**Where:** `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/Dockerfile` lines 14–18
**Why:** sentence-transformers, when installed via requirements.txt, checks for torch and if absent pulls a CUDA build (~2GB). Installing CPU torch first (~200MB) satisfies the requirement before requirements.txt is processed.
**Notes:** This only runs in Stage 1 (builder). Stage 2 (runtime) copies all dist-packages wholesale, so the CPU torch is correctly present in the final image.

#### 2026-02-24 — docker-compose.npc-llm.yml

**What:** Added 8 new environment variables in the npc-llm service environment block
**Where:** `/mnt/d/Dev/EQ/akk-stack/docker-compose.npc-llm.yml` lines 37–46
**Why:** Architecture specifies these 8 vars for controlling Pinecone connection and memory behavior. All have safe defaults so the container starts in Phase 1 stateless mode if PINECONE_API_KEY is empty.
**Notes:** MEMORY_SCORE_THRESHOLD defaults to 0.4 (not 0.7 as in PRD) per architect's recommendation: 0.7 is too strict for all-MiniLM-L6-v2 cosine scores. Configurable via .env.

#### 2026-02-24 — .env

**What:** Replaced Phase 1 commented-out Pinecone placeholders with full Phase 2 section
**Where:** `/mnt/d/Dev/EQ/akk-stack/.env` lines 100–104
**Why:** User needs clear Pinecone setup instructions. Included note about index creation requirements (dimension=384, cosine, aws us-east-1).
**Notes:** PINECONE_API_KEY is intentionally left empty — user must fill in their own key. MEMORY_ENABLED=true is the default; setting this to false is the single-switch disable.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/npc-llm-sidecar/requirements.txt` | Modified | Added Phase 2 deps: pinecone-client, sentence-transformers, torch |
| `akk-stack/npc-llm-sidecar/Dockerfile` | Modified | CPU PyTorch pre-install step in builder stage |
| `akk-stack/docker-compose.npc-llm.yml` | Modified | 8 Pinecone/memory env vars added |
| `akk-stack/.env` | Modified | Phase 2 Pinecone config section (PINECONE_API_KEY, PINECONE_INDEX, MEMORY_ENABLED) |

---

## Open Items

- [ ] MEMORY_SCORE_THRESHOLD (0.4) should be tuned up during integration testing if irrelevant memories surface
- [ ] User must create Pinecone index manually (dimension=384, cosine, aws, us-east-1) before memory works
- [ ] Architecture notes 6GB memory limit may need increase to 8GB if sentence-transformers runtime footprint exceeds headroom — monitor during testing

---

## Context for Next Agent

Task #5 is complete. All Docker infrastructure changes for Phase 2 Pinecone memory are in place:

1. `requirements.txt` lists all three new deps
2. `Dockerfile` builder stage installs CPU torch before requirements.txt to prevent CUDA torch pull
3. `docker-compose.npc-llm.yml` has all 8 Pinecone/memory env vars with safe defaults
4. `.env` has PINECONE_API_KEY (empty), PINECONE_INDEX=npc-memory, MEMORY_ENABLED=true

The container will start in stateless Phase 1 mode until the user adds their Pinecone API key.
Task #7 (integration testing, blocked on this task) is the next dependent step.
