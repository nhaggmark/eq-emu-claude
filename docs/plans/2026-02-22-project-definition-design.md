# Project Definition Design

**Date**: 2026-02-22
**Status**: Approved

## Context

Kicking off a custom EverQuest server project using three open-source codebases:
- **EQEmu** — C++/Perl/Lua/MariaDB game server emulator
- **akk-stack** — Docker Compose deployment and build toolchain
- **Spire** — Go/Vue.js web admin and content editing toolkit

All three are cloned locally as forks for potential heavy customization.

## Decision

Create a single PROJECT.md in the `claude/` folder as a living reference document (Approach A). This file serves as the north star for the project — vision, resources, architecture, roadmap, and workflow in one place.

## Key Design Choices

- **Scope**: Classic through Shadows of Luclin only (4 expansions), era-locked
- **Client**: Titanium (Oct 2006)
- **Player Count**: 1-6 (small friend group)
- **Signature Feature**: Recruit-any-NPC companion system — convince NPCs to join your party, making all content accessible without a full raid force
- **Customization**: Full — loot/economy, quests/story, class/combat rebalancing
- **Modernization**: Catalog all functionality across C++/Perl/Lua/MariaDB; migrate Perl and feasible C++ to Python
- **Infrastructure**: Local dev on WSL2, remote deploy for play sessions
- **Document Structure**: Single PROJECT.md with 5 sections (Vision, Resources, Architecture, Roadmap, Workflow)

## Alternatives Considered

- **Approach B (Minimal Vision + Separate Docs)**: Rejected — too many files to maintain for a solo/small project
- **Approach C (Wiki-Style Knowledge Base)**: Rejected — adds friction for a project just getting started; can evolve into this later
