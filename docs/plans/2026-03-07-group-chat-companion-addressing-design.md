# Group Chat Companion Addressing

**Date:** 2026-03-07
**Status:** Approved

## Problem

Controlling recruited NPC companions in combat requires targeting each one
individually and using `/say` commands. This breaks combat flow — switching
targets mid-fight to issue orders or talk to companions is disruptive and
prevents effective macro creation.

## Solution

Intercept `/gsay` messages containing `@Name` patterns. Parse each mention,
match against recruited companions in the group, and route the command or
conversation without changing the player's target.

## Core Mechanics

### Addressing

- `@name` in `/gsay` targets companions by substring match (case-insensitive)
- Common NPC prefixes ("Guard", "Captain", "Lady", "Lord", "Sir", etc.) are
  stripped before matching
- If multiple companions match, all receive the command
- `@all` targets every recruited companion in the group
- Multiple `@name` tokens in one message are parsed independently
- Unmatched names fail silently — matched names still proceed
- The word "and" between `@` mentions is a separator, stripped from payload

### Payload Types

- **Commands** (`!` prefix): Route to existing `/say` command handler as if
  the player targeted that companion and spoke. Example: `@iskarr !follow`
- **Conversation** (no `!` prefix): Route to LLM sidecar conversation flow.
  Example: `@iskarr how's your day?`

### Response Routing

- Command feedback uses existing mechanisms (unchanged)
- LLM conversational responses come back in `/gsay` (group chat), matching
  the channel the player initiated from
- Existing `/say` targeting + conversation behavior is unchanged (responses
  stay in `/say`)
- When multiple companions respond conversationally, responses are staggered
  ~1-2 seconds apart

### Target Preservation

The player's current target is never changed. The system intercepts and
routes internally, simulating targeted interaction without modifying client
state.

## Examples

| Player types in `/gsay` | Result |
|--------------------------|--------|
| `@iskarr !follow` | Guard Iskarr follows the player |
| `@iskarr and @astrid !follow` | Guard Iskarr and Guard Astrid both follow |
| `@all !attack` | All companions attack |
| `@iskarr how's your day?` | LLM response from Iskarr in group chat |
| `@all how are you guys doing?` | Each companion responds in group chat, staggered |
| `@nobody !follow` | Silent failure, no match |
| `@iskarr and @nobody !follow` | Iskarr follows, "nobody" silently fails |

## Architecture

### Components

1. **Group chat interceptor** — Hook into `/gsay` message handler in C++.
   Detect messages containing `@` mentions and divert to the parser.

2. **@Name parser** — Extract `@name` tokens, resolve `@all`, separate
   the payload (command vs conversation), return list of
   (companion, payload) pairs.

3. **Companion name resolver** — Search the player's group for recruited
   companions matching the `@name` token (substring, case-insensitive,
   prefix-stripped).

4. **Command dispatcher** — For each (companion, payload) pair:
   - `!command` → invoke existing `/say` command processing
   - Conversation → invoke LLM sidecar with response channel set to group chat

5. **Response stagger** — Queue multiple LLM responses with 1-2 second
   delays between each.

6. **Combat context provider** (enhancement) — Feed current combat state
   into LLM prompt when player or companions are in combat, so
   conversational responses are contextually aware of the fight.

## Scope

### In scope (core feature)
- `@name` parsing and matching in `/gsay`
- `@all` broadcast
- Command routing (`!` commands)
- Conversational routing (LLM sidecar)
- Response in group chat channel
- Response staggering
- Target preservation

### Enhancement (after core works)
- Combat-aware LLM context for contextually appropriate responses
