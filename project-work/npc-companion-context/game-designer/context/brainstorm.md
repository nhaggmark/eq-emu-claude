# NPC Companion Context — Brainstorming Session
> Date: 2026-03-02

## Feature Summary

**Problem:** When NPCs are recruited as companions, they keep talking as if
they're still in their original role (guard on patrol, merchant behind counter).
They have no awareness that they've joined the player's group.

**Goal:** Recruitment should be a turning point. Companions keep their memories
and personality but gain awareness of being in a group. They should feel like
real traveling companions, not NPCs on a leash.

## Core Design Principles (from discussion)

1. **Identity shift, not identity replacement.** A guard who becomes a
   companion is "Bob, who used to be a guard, now adventuring with you."
   Their origin is backstory, not their current reality. They're a group
   member first.

2. **Situational awareness.** Companions should be aware of the zone,
   what you're doing, what you've been fighting. Camping gnolls in a
   forest should produce different conversation than resting in a city.
   They are *present* in the moment.

3. **Personality variety is the joy.** Different companions should feel
   meaningfully different. Race, class, hometown, faction ties — all of
   this shapes how they see and talk about the world. An Erudite and a
   Troll should have wildly different takes on the same situation.

4. **Emergent characters.** The LLM invents details (a daughter, a grudge,
   a fear) and the memory system makes those inventions stick. Companions
   should grow and evolve as their characters emerge through conversation.
   The companion context should amplify this, not constrain it — more
   room to develop the character through a richer ongoing relationship.

5. **Natural conversation cadence.** Player initiates most conversations.
   Unprompted companion commentary is rare and surprising. Should feel
   like traveling with a real person, not a chatbot.

6. **Start focused, don't over-scope.** The core deliverable is shifting
   the conversational context when an NPC becomes a companion. Don't
   build preference systems, opinion mechanics, or complex relationship
   tracking yet. Get past banal NPC scripts first and see how far we
   can get.

## Q&A Record

### Q1: How chatty should companions be?
**Answer:** Mostly player-initiated conversation. Very occasional unprompted
commentary. Should feel natural, like traveling with a real person who's
mostly focused on the journey but occasionally says something interesting.

### Q2: What depth of conversation?
**Answer:** (Implied from discussion) Lengthy dialog is the goal — the user
wants to enjoy extended back-and-forth conversations while solo'ing. Both
banter and deeper threads should be possible.

### Q3: Should companions be situationally aware?
**Answer:** Yes. They should be aware of the zone, what you're doing, what
you're fighting. If camping gnolls in the woods, the conversation should be
topical. They should approach conversation as a group member, not as their
former role.

### Q4: How much personality variety between companions?
**Answer:** Very different. The joy is in the variety. EverQuest has deep
lore — race, class, culture, hometown — and that should come through in how
different companions talk and see the world.

### Q5: How much should the companion's role shift after recruitment?
**Answer:** Their origin becomes backstory, not their current identity.
They're a group member who happens to have been a guard, not a guard who
happens to be following you.

### Q6: What about the current system works well?
**Answer:** The emergent character system. As the LLM makes things up, it
becomes canon via the memory system. Characters grow and evolve through
conversation. The companion feature should amplify this — more relationship
depth means more room for character development.

### Q7: Should we build preference/opinion systems?
**Answer:** No, not yet. Start focused — get the conversational context
shift working and see how far it gets us. Don't over-scope.

## Feature Brief (for agent handoff)

### What
When an NPC is recruited as a companion, their LLM conversational context
should shift to reflect their new role as a group member. They retain all
memories and personality but gain awareness of:
- Being part of the player's group
- The current zone and situation
- Their origin as backstory rather than current identity

### Why
Currently, recruited companions talk as if they're still performing their
original role (guarding, merchanting, etc.). This breaks immersion and
makes companions feel like NPCs on a leash rather than traveling partners.

### Success Criteria
- A recruited guard talks like a former guard adventuring with you, not a
  guard on patrol
- Companions reference the current zone and activity in conversation
- Different companions (by race, class, origin) feel meaningfully different
  to talk to
- Emergent character details from the LLM continue to accumulate and
  persist via the memory system
- Unprompted companion commentary is rare and natural
- Player-initiated conversations can be extended and feel natural
- The feature works within the existing soul/memory/LLM infrastructure
  (likely a conditional prompt adjustment when companion status is active)

### Out of Scope (for now)
- Companion preference/opinion systems
- Mechanical effects from companion mood or attitude
- Complex relationship tracking or loyalty mechanics
- Companion-to-companion interaction
- Milestone conversation triggers
