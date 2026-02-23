# EQEmu Client-Server Protocol Topography

## Summary

The EQEmu protocol layer handles all communication between the Titanium client (Oct 2006) and the server cluster. It comprises four subsystems: the **opcode system** (627 internal opcodes defined via X-macros), **packet structures** (~397 packed C structs totaling 6,566 lines), **client packet dispatch** (344 handler registrations across 17,356 lines), and **server-to-server talk** (239 `ServerOP_*` codes for zone↔world communication). The Titanium client patch translates between internal formats and the Titanium wire protocol via 112 encode/decode methods in a 3,923-line translation layer.

All paths below are relative to `eqemu/`.

---

## 1. Architecture Overview

### Packet Flow: Client → Server

```
Titanium Client
    ↓ UDP (ports 7000-7030)
common/net/eqstream.cpp          — Reliable UDP: sequencing, fragmentation, ACK/NAK
    ↓
common/eq_stream_ident.h         — Identifies client version from handshake
    ↓
common/patches/titanium.cpp      — Translates Titanium wire format → internal structs
    ↓
zone/client_packet.cpp           — Dispatches opcode to handler method (344 handlers)
    ↓
zone/*.cpp                       — Gameplay logic processes the request
```

### Packet Flow: Server → Client

```
zone/*.cpp                       — Gameplay logic creates response
    ↓
common/patches/titanium.cpp      — Translates internal structs → Titanium wire format
    ↓
common/net/eqstream.cpp          — Reliable UDP: sequencing, fragmentation
    ↓ UDP
Titanium Client
```

### Server-to-Server Communication

```
zone process ←→ world process    — TCP using ServerPacket with ServerOP_* codes
                                   Defined in common/servertalk.h (1,783 lines)
                                   Serialized via cereal library for complex structs
```

---

## 2. Opcode System

### Source Files

| File | Lines | Role |
|------|-------|------|
| `common/emu_oplist.h` | 630 | Master opcode list (X-macro definitions) |
| `common/emu_opcodes.h` | 49 | Enum wrapper, includes emu_oplist.h |
| `common/patches/titanium_ops.h` | 137 | Titanium client opcode number mappings |
| `common/patches/sof_ops.h` | — | Secrets of Faydwer mappings |
| `common/patches/sod_ops.h` | — | Seeds of Destruction mappings |
| `common/patches/uf_ops.h` | — | Underfoot mappings |
| `common/patches/rof_ops.h` | — | Rain of Fear mappings |
| `common/patches/rof2_ops.h` | — | Rain of Fear 2 mappings |

### How Opcodes Work

Opcodes are defined via X-macros in `emu_oplist.h`:

```cpp
// emu_oplist.h — each line defines one internal opcode
N(OP_PlayerProfile)
N(OP_SpawnAppearance)
N(OP_ChannelMessage)
N(OP_CastSpell)
// ... 627 total
```

Each client version maps these to its own wire opcode numbers via `*_ops.h` files. The Titanium client uses `titanium_ops.h` for its mappings.

### Opcode Count: 627 Internal Opcodes

**By Category (major groups):**

| Category | Count | Examples |
|----------|-------|---------|
| Spawn/Entity | ~45 | `OP_NewSpawn`, `OP_DeleteSpawn`, `OP_SpawnAppearance`, `OP_MobHealth` |
| Combat/Damage | ~30 | `OP_Damage`, `OP_Death`, `OP_Action`, `OP_CombatAbility` |
| Spell/Buff | ~35 | `OP_CastSpell`, `OP_BuffFadeMsg`, `OP_MemorizeSpell`, `OP_ManaChange` |
| Item/Inventory | ~40 | `OP_ItemPacket`, `OP_MoveItem`, `OP_DeleteItem`, `OP_Consume` |
| Trade/Merchant | ~20 | `OP_TradeRequest`, `OP_ShopRequest`, `OP_TradeAccept` |
| Group/Raid | ~35 | `OP_GroupUpdate`, `OP_RaidAction`, `OP_GroupFollow` |
| Zone/Movement | ~30 | `OP_ZoneChange`, `OP_ClientUpdate`, `OP_ZoneEntry` |
| Chat/Social | ~25 | `OP_ChannelMessage`, `OP_Emote`, `OP_RandomReq` |
| Guild | ~25 | `OP_GuildCreate`, `OP_GuildInvite`, `OP_GuildMOTD` |
| AA/Skills | ~20 | `OP_AAAction`, `OP_SkillUpdate`, `OP_GMTrainee` |
| Bazaar/Barter | ~15 | `OP_BazaarSearch`, `OP_BuyerItems`, `OP_TraderShop` |
| Character Data | ~20 | `OP_PlayerProfile`, `OP_CharCreate`, `OP_ZonePlayerToBind` |
| Loot/Corpse | ~15 | `OP_LootRequest`, `OP_LootItem`, `OP_MoneyOnCorpse` |
| Pet | ~10 | `OP_PetCommands`, `OP_PetBuffs`, `OP_Charm` |
| Quest/Task | ~15 | `OP_TaskDescription`, `OP_CompletedTasks`, `OP_TaskHistoryReply` |
| Door/Object | ~10 | `OP_ClickDoor`, `OP_ClickObject`, `OP_MoveDoor` |
| Tribute | ~10 | `OP_TributeInfo`, `OP_SelectTribute`, `OP_GuildTributeActive` |
| Login/World | ~15 | `OP_SendLoginInfo`, `OP_EnterWorld`, `OP_LogServer` |
| Misc Systems | ~50+ | `OP_Track`, `OP_Inspect`, `OP_Who`, `OP_Petition`, `OP_Bug`, `OP_LFGuild` |

---

## 3. Titanium Translation Layer

### Source Files

| File | Lines | Role |
|------|-------|------|
| `common/patches/titanium.cpp` | 3,923 | Encode/decode between internal and Titanium wire format |
| `common/patches/titanium.h` | 52 | Class declaration |
| `common/patches/titanium_ops.h` | 137 | Opcode number mappings |
| `common/patches/titanium_structs.h` | — | Titanium-specific struct variants |

### Encode/Decode Methods

The `Titanium` class in `titanium.cpp` provides methods that convert between the server's internal packet structures and the Titanium client's wire format. Some packets are identical (pass-through), others require field reordering, padding changes, or size adjustments.

**112 registered encode/decode methods** (68 ENCODE + 2 EAT_ENCODE + 42 DECODE) handle the packets where Titanium's wire format differs from internal format. All other packets pass through unchanged. The macros are defined as:

- `ENCODE(OP_*)` — Translates internal struct → Titanium wire format (server→client)
- `DECODE(OP_*)` — Translates Titanium wire format → internal struct (client→server)
- `EAT_ENCODE(OP_*)` — Suppresses a packet (prevents it from reaching the Titanium client)

### Supported Client Versions

| Patch Version | Files | Status |
|---------------|-------|--------|
| **Titanium** | `titanium.*`, `titanium_ops.h` | **Our target client** |
| Secrets of Faydwer (SoF) | `sof.*`, `sof_ops.h` | Supported |
| Seeds of Destruction (SoD) | `sod.*`, `sod_ops.h` | Supported |
| Underfoot (UF) | `uf.*`, `uf_ops.h` | Supported |
| Rain of Fear (RoF) | `rof.*`, `rof_ops.h` | Supported |
| Rain of Fear 2 (RoF2) | `rof2.*`, `rof2_ops.h` | Supported |

### Client Identification

`common/eq_stream_ident.h` detects the client version from the initial handshake packet, then routes to the appropriate patch adapter. For our server, all connections should identify as Titanium.

---

## 4. Client Packet Dispatch

### Source File

| File | Lines | Role |
|------|-------|------|
| `zone/client_packet.cpp` | 17,356 | All client opcode handler implementations |

### Dispatch Architecture

Two-tier dispatch system:

1. **ConnectingOpcodes** (24 entries) — Handles packets during login/zone-in before the client is fully connected. Stored as a `std::map` for sparse lookup.

2. **ConnectedOpcodes** (320 entries) — Handles all gameplay packets after the client is in-zone. Stored as a static array indexed by opcode for O(1) lookup.

All handlers are methods on the `Client` class named `Handle_OP_*` (e.g., `Client::Handle_OP_CastSpell`).

### Handler Categories (344 Total)

#### Connecting Phase (24 handlers)
Handles login, zone entry, character selection:
- `Handle_Connect_OP_ZoneEntry` — Initial zone entry
- `Handle_Connect_OP_SetServerFilter` — Client message filters
- `Handle_Connect_OP_SendAATable` — Request AA data
- `Handle_Connect_OP_ReqNewZone` — Request zone data
- `Handle_Connect_OP_ClientReady` — Client ready signal
- `Handle_Connect_OP_WearChange` — Initial equipment appearance

#### Movement & Position (~15 handlers)
- `Handle_OP_ClientUpdate` — Player position update (most frequent packet)
- `Handle_OP_AutoAttack` — Toggle melee
- `Handle_OP_AutoFire` — Toggle ranged
- `Handle_OP_Jump` — Jump action
- `Handle_OP_Camp` — Camp/logout
- `Handle_OP_Consent` — Corpse consent
- `Handle_OP_ConsiderCorpse` — Consider a corpse

#### Combat (~20 handlers)
- `Handle_OP_Damage` — Process damage packets
- `Handle_OP_CombatAbility` — Disc/ability use
- `Handle_OP_Taunt` — Taunt skill
- `Handle_OP_InstillDoubt` — Intimidate
- `Handle_OP_RazzleNPC` — Pick pocket
- `Handle_OP_Assist` — Assist target
- `Handle_OP_AssistGroup` — Group assist

#### Spellcasting & Buffs (~25 handlers)
- `Handle_OP_CastSpell` — Cast spell request
- `Handle_OP_MemorizeSpell` — Memorize/scribe
- `Handle_OP_BuffRemoveRequest` — Cancel buff
- `Handle_OP_BlockedBuffs` — Block buff list
- `Handle_OP_PetCommands` — Pet control
- `Handle_OP_Charm` — Charm/release

#### Items & Inventory (~25 handlers)
- `Handle_OP_MoveItem` — Inventory management
- `Handle_OP_DeleteItem` — Destroy item
- `Handle_OP_ItemLinkClick` — Item link inspection
- `Handle_OP_Consume` — Eat/drink
- `Handle_OP_AugmentItem` — Augment management
- `Handle_OP_MultiMoveItem` — Bulk move
- `Handle_OP_MoveCoin` — Currency movement

#### Trade & Merchant (~15 handlers)
- `Handle_OP_TradeRequest` — Initiate trade
- `Handle_OP_TradeAcceptClick` — Accept trade
- `Handle_OP_CancelTrade` — Cancel trade
- `Handle_OP_ShopRequest` — Open merchant
- `Handle_OP_ShopPlayerBuy` — Buy from merchant
- `Handle_OP_ShopPlayerSell` — Sell to merchant
- `Handle_OP_Parcel` — Parcel system

#### Group & Raid (~20 handlers)
- `Handle_OP_GroupInvite` / `Handle_OP_GroupInvite2` — Group invite
- `Handle_OP_GroupFollow` / `Handle_OP_GroupFollow2` — Accept invite
- `Handle_OP_GroupDisband` — Leave/disband
- `Handle_OP_GroupMakeLeader` — Transfer leadership
- `Handle_OP_GroupMentor` — XP mentoring
- `Handle_OP_RaidAction` — All raid operations
- `Handle_OP_DelegateAbility` — Delegate MA/puller

#### Guild (~20 handlers)
- `Handle_OP_GuildCreate` — Create guild
- `Handle_OP_GuildInvite` — Invite player
- `Handle_OP_GuildRemove` — Remove member
- `Handle_OP_GuildMOTD` — Set MOTD
- `Handle_OP_GuildBank` — Guild bank operations
- `Handle_OP_GuildTribute` — Guild tribute

#### Chat & Social (~15 handlers)
- `Handle_OP_ChannelMessage` — All chat channels
- `Handle_OP_Emote` — Emotes
- `Handle_OP_Animation` — Animations
- `Handle_OP_FaceChange` — Character appearance
- `Handle_OP_WhoAllRequest` — /who all
- `Handle_OP_RandomReq` — /random

#### Zone & Door (~15 handlers)
- `Handle_OP_ZoneChange` — Zone transition
- `Handle_OP_ClickDoor` — Door interaction
- `Handle_OP_ClickObject` — Object interaction
- `Handle_OP_ClickObjectAction` — Object follow-up

#### Loot & Corpse (~10 handlers)
- `Handle_OP_LootRequest` — Open corpse
- `Handle_OP_LootItem` — Loot item
- `Handle_OP_EndLootRequest` — Close corpse
- `Handle_OP_MoneyOnCorpse` — Loot money

#### Bazaar & Barter (~10 handlers)
- `Handle_OP_Bazaar` — Bazaar operations
- `Handle_OP_BuyerItems` — Buyer mode
- `Handle_OP_TraderShop` — Trader mode

#### AA & Skills (~10 handlers)
- `Handle_OP_AAAction` — AA purchase/use
- `Handle_OP_LeadershipExpToggle` — Toggle leadership XP
- `Handle_OP_UpdateLeadershipAA` — Spend leadership AA

#### Quest & Task (~10 handlers)
- `Handle_OP_TaskTimers` — Task tracking
- `Handle_OP_CompletedTasks` — Completed tasks

#### Tribute (~10 handlers)
- `Handle_OP_TributeItem` — Tribute items
- `Handle_OP_SelectTribute` — Select tribute ability
- `Handle_OP_GuildTributeActive` — Activate guild tribute

#### Misc (~30+ handlers)
- `Handle_OP_Track` — Tracking
- `Handle_OP_Inspect` / `Handle_OP_InspectAnswer` — Inspect
- `Handle_OP_Petition` / `Handle_OP_PetitionBug` — GM petition
- `Handle_OP_Report` — Report player
- `Handle_OP_LFGuild` — Looking for guild
- `Handle_OP_Bug` — Bug report
- `Handle_OP_Bandolier` — Equipment sets
- `Handle_OP_PotionBelt` — Potion belt

### Handler Validation Patterns

Common validation at the top of handlers:

```cpp
// Size validation — reject malformed packets
if (app->size != sizeof(SomeStruct)) { return; }

// GM permission check
if (!this->GetGM()) { return; }

// Death/incapacitation check
if (GetHP() <= 0) { return; }

// Zone flag/level check
if (!HasZoneFlag(target_zone)) { Message(Chat::Red, "You need a key..."); return; }

// Anti-cheat: position validation, speed checks, item slot bounds
```

---

## 5. Packet Structures

### Source File

| File | Lines | Role |
|------|-------|------|
| `common/eq_packet_structs.h` | 6,566 | All client↔server packet structure definitions |

### Critical Design Rules

1. **`#pragma pack(1)`** — The entire file uses byte-aligned packing (no padding). Every struct is a direct wire-format representation.

2. **Variable-length packets** — Several structs end with `[0]` or `[1]` arrays:
   - `ChannelMessage_Struct.message[0]`
   - `Tracking_Struct.Entrys[0]`
   - `RaidMembers_Struct.members[1]`
   - `BulkItemPacket_Struct.SerializedItem[0]`

3. **Bitfield packing** — Position updates use aggressive bitfield compression:
   - Coordinates: 19 bits each (±262,143 range)
   - Heading: 12 bits (0–4095)
   - Deltas: 13 bits each
   - Animation: 10 bits

4. **Cereal serialization** — Some newer packets use the Cereal library instead of raw bytes:
   - `ParcelMessaging_Struct`
   - `BazaarSearchMessaging_Struct`

5. **Polymorphic packets** — `ItemPacket_Struct` uses `PacketType` enum to handle 14 different item operations with one struct.

### Structure Catalog by Category

#### Player Character Data

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `PlayerProfile_Struct` | 943 | ~19,568B | Complete character profile (largest struct) |
| `Spawn_Struct` | 217 | ~120B | Generic spawn representation (NPC/PC/corpse) |
| `NewSpawn_Struct` | 342 | 385+B | New spawn entering zone (wraps Spawn_Struct) |
| `CharCreate_Struct` | 671 | ~140B | Character creation data |
| `ClientZoneEntry_Struct` | 347 | — | Zone entry confirmation |

**PlayerProfile_Struct** is the largest and most important struct. Key nested data:
- `binds[5]` (BindStruct) — 5 bind locations
- `buffs[BUFF_COUNT]` (SpellBuff_Struct) — 42 active buffs
- `spell_book[]` — All scribed spells
- `mem_spells[]` — Memorized spell gems
- `skills[MAX_PP_SKILL]` — ~100 skills
- `aa_array[MAX_PP_AA_ARRAY]` — 240 AA ranks
- `groupMembers[6][64]` — Group roster
- `bandoliers[]`, `potionbelt`, `disciplines`, `tributes[]`

**Spawn_Struct** field `NPC` determines type: 0=player, 1=NPC, 2=PC corpse, 3=NPC corpse.

#### Position Updates

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `PlayerPositionUpdateServer_Struct` | 1392 | ~24B | Server→Client position (bitfield-packed) |
| `PlayerPositionUpdateClient_Struct` | 1420 | ~46B | Client→Server position |
| `SpawnPositionUpdate_Struct` | 1441 | ~12B | Compact position update |
| `DeleteSpawn_Struct` | 1177 | ~5B | Remove spawn (`Decay`: 0=vanish, 1=sparklies) |
| `BecomeCorpse_Struct` | 1379 | — | Death position |

#### Combat & Damage

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `CombatDamage_Struct` | 1335 | ~23B | Damage message (melee or spell) |
| `Action_Struct` | 1310 | ~30B | Spell cast action (particles, animations) |
| `Death_Struct` | 1367 | ~32B | Death event |
| `Consider_Struct` | 1351 | ~28B | /consider response |
| `Animation_Struct` | 1300 | ~4B | Set animation |

Key field: `CombatDamage_Struct.type` — 231 (0xE7) means spell damage, otherwise skill ID for melee. `special`: 2=Rampage, 1=Wild Rampage.

#### Spell Casting & Buffs

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `CastSpell_Struct` | 489 | ~32B | Cast request (slot, spell_id, target) |
| `BeginCast_Struct` | 481 | ~8B | Cast animation start |
| `SpellBuff_Struct` | 534 | ~36B | Active buff data |
| `SpellBuffPacket_Struct` | 552 | ~48B | Buff with entity/slot info |
| `BuffRemoveRequest_Struct` | 561 | ~8B | Cancel buff |
| `MemorizeSpell_Struct` | 416 | ~16B | Memorize/scribe (1=mem, 0=scribe, 2=unmem) |
| `SpellEffect_Struct` | 502 | ~28B | Visual effect tracking |
| `ManaChange_Struct` | 463 | ~16B | Mana/stamina update |
| `PetBuff_Struct` | 568 | ~248B | Pet's 30 buff slots |
| `BlockedBuffs_Struct` | 575 | ~86B | 20 blocked spell IDs |
| `Charm_Struct` | 440 | ~12B | Charm/release (1=charm, 0=release) |
| `LinkedSpellReuseTimer_Struct` | 429 | ~12B | Spell cooldown tracking |

#### Items & Inventory

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `ItemPacket_Struct` | 1590 | variable | Polymorphic item packet (14 subtypes) |
| `MoveItem_Struct` | 1619 | ~12B | Move item between slots |
| `DeleteItem_Struct` | 1612 | ~12B | Delete item |
| `Consume_Struct` | 1603 | ~12B | Eat/drink (type: 1=food, 2=water) |
| `InventorySlot_Struct` | 1628 | ~12B | Slot reference with augments |
| `MultiMoveItem_Struct` | 1647 | variable | Bulk move |
| `MoveCoin_Struct` | 1684 | ~20B | Currency between slots |
| `ItemViewRequest_Struct` | 3531 | ~48B | Item link click |
| `Parcel_Struct` | 2153 | ~216B | Send item via mail |

**ItemPacketType enum** (line 1543):

| Value | Name | Purpose |
|-------|------|---------|
| `0x00` | ViewLink | Item link inspection |
| `0x64` | Merchant | Merchant inventory |
| `0x65` | TradeView | Trade preview |
| `0x66` | Loot | Corpse loot |
| `0x67` | Trade | Active trade |
| `0x69` | CharInventory | Character inventory |
| `0x6A` | Limbo | Items in limbo |
| `0x6B` | WorldContainer | World container |
| `0x6C` | TributeItem | Tribute offering |
| `0x71` | Recovery | Item recovery |
| `0x73` | Parcel | Parcel system |

#### Trade & Merchant

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `TradeRequest_Struct` | 2583 | ~8B | Initiate trade |
| `TradeAccept_Struct` | 2589 | ~8B | Accept trade |
| `CancelTrade_Struct` | 2602 | ~8B | Cancel trade |
| `TradeBusy_Struct` | 2608 | ~12B | Target busy |
| `MerchantClick_Struct` | 2137 | ~24B | Open merchant window |
| `TradeCoin_Struct` | 1692 | ~12B | Offer currency |

**MerchantClick_Struct.tab_display** bitmask: 1=buy/sell, 2=recover, 4=parcel.

#### Group & Raid

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `GroupUpdate_Struct` | 2495 | ~452B | Group roster |
| `GroupJoin_Struct` | 2515 | ~452B | New member joins |
| `GroupFollow_Struct` | 2537 | ~132B | Invite interaction |
| `GroupLeaderChange_Struct` | 2545 | ~148B | Leadership transfer |
| `GroupMentor_Struct` | 2552 | ~68B | XP mentoring |
| `RaidGeneral_Struct` | 4875 | ~136B | Generic raid operation |
| `RaidAddMember_Struct` | 4883 | ~144B | Add to raid |
| `RaidCreate_Struct` | 4920 | ~72B | Create raid |
| `RaidMembers_Struct` | 4947 | variable | Full raid roster |
| `RaidMemberInfo_Struct` | 4926 | ~11+B | Single member (variable-length name) |
| `LeadershipAA_Struct` | 845 | ~128B | Combined group+raid AAs |
| `MarkNPC_Struct` | 4862 | ~72B | Mark NPC (1, 2, or 3) |
| `DelegateAbility_Struct` | 4843 | ~92B | Delegate MA/puller |

#### Zone Transitions

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `ZoneChange_Struct` | 1274 | ~88B | Zone transition request |
| `ZoneServerInfo_Struct` | 3661 | ~130B | Zone server IP and port |
| `ZonePoint_Entry` | 2449 | ~24B | Single zone point (doorway) |
| `ZonePoints` | 2459 | variable | Zone point list |
| `ZonePlayerToBind_Struct` | 5228 | — | Return to bind on death |

#### Chat & Messaging

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `ChannelMessage_Struct` | 1189 | 144+B | All chat (variable-length message) |
| `Emote_Struct` | 2681 | ~1,028B | Emote text |
| `RandomReq_Struct` | 2033 | ~8B | /random request |
| `RandomReply_Struct` | 2039 | ~76B | /random result |

#### Vitals & Appearance

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `LevelUpdate_Struct` | 1520 | ~12B | Level up notification |
| `ExpUpdate_Struct` | 1532 | ~8B | XP progress (0–330 ratio) |
| `MobHealth` | 1500 | ~3B | Health percentage |
| `Stamina_Struct` | 1511 | ~8B | Food/drink (127=full, 0=starving) |
| `SpawnAppearance_Struct` | 524 | ~8B | Appearance update |
| `FaceChange_Struct` | 2558 | ~24B | Facial features |

#### Skills & Training

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `GMTrainee_Struct` | 607 | ~448B | Trainer skill offer |
| `GMSkillChange_Struct` | 623 | ~12B | Request training |
| `GMTrainSkillConfirm_Struct` | 632 | ~73B | Training confirmation |
| `SkillUpdate_Struct` | 2464 | ~8B | Skill value update |

#### Bazaar & Barter

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `BazaarSearchCriteria_Struct` | 3072 | ~132B | Search filters |
| `BazaarSearchResults_Struct` | 3127 | ~152B | Search result |
| `BazaarWelcome_Struct` | 3064 | ~20B | Bazaar startup info |

#### Specialized

| Struct | Line | Size | Purpose |
|--------|------|------|---------|
| `Track_Struct` | 3634 | variable | Tracking result |
| `InspectResponse_Struct` | 2694 | ~1,860B | Inspect window (23 slots) |
| `Who_All_Struct` | 2652 | ~152B | /who filter |
| `EnvDamage2_Struct` | 3020 | ~29B | Environmental damage |
| `LFG_Struct` | 2047 | ~80B | Looking for group |
| `TimeOfDay_Struct` | 2128 | ~16B | EQ time |
| `AugmentItem_Struct` | 2670 | ~24B | Augment management |
| `ClientError_Struct` | 3624 | ~32KB | Client crash report |

### Key Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `BUFF_COUNT` | 42 | Max player buffs |
| `PET_BUFF_COUNT` | 30 | Max pet buffs |
| `BLOCKED_BUFF_COUNT` | 20 | Blocked spells |
| `MAX_GROUP_MEMBERS` | 6 | Group size |
| `MAX_PP_AA_ARRAY` | 240 | AA rank slots |
| `MAX_PP_SKILL` | ~100 | Skill count |
| `MAX_PP_LANGUAGE` | 28 | Language slots |
| `MAX_RECAST_TYPES` | 20 | Cooldown timers |
| `MAX_LEADERSHIP_AA_ARRAY` | 32 | Group (16) + Raid (16) AAs |

### Environmental Damage Types

| Code | Meaning |
|------|---------|
| `0xFA` | Lava |
| `0xFB` | Drowning |
| `0xFC` | Falling |
| `0xFD` | Trap/spike |

### Coin Types

| Value | Currency |
|-------|----------|
| 0 | Copper |
| 1 | Silver |
| 2 | Gold |
| 3 | Platinum |

### Slot Types (InventorySlot_Struct.Type)

| Value | Meaning |
|-------|---------|
| 0 | Worn/normal inventory |
| 1 | Bank |
| 2 | Shared bank |
| -1 | Delete |

---

## 6. Server-to-Server Protocol

### Source File

| File | Lines | Role |
|------|-------|------|
| `common/servertalk.h` | 1,783 | `ServerOP_*` opcode definitions and inter-server packet structures |

### Overview

Zone↔World communication uses TCP with `ServerPacket` objects carrying `ServerOP_*` operation codes. Complex payloads are serialized using the cereal C++ library. This is the backbone for cross-zone coordination: guild operations, tells, group/raid management, zone launches, and shared tasks.

### ServerOP Codes (239 Total)

**By Category:**

| Category | Count | Examples |
|----------|-------|---------|
| Zone Management | ~25 | `ServerOP_ZoneBootup`, `ServerOP_ZoneShutdown`, `ServerOP_ZoneStatus` |
| Player Routing | ~20 | `ServerOP_ClientList`, `ServerOP_ZoneToZoneRequest`, `ServerOP_RezzPlayer` |
| Guild Operations | ~20 | `ServerOP_GuildCreate`, `ServerOP_GuildInvite`, `ServerOP_GuildMOTD`, `ServerOP_OnlineGuildMembersResponse` |
| Group/Raid Cross-Zone | ~15 | `ServerOP_GroupFollow`, `ServerOP_RaidGroupLeader`, `ServerOP_RaidMOTD` |
| Chat/Messaging | ~15 | `ServerOP_ChannelMessage`, `ServerOP_EmoteMessage`, `ServerOP_OOCMute` |
| Login Server | ~15 | `ServerOP_LSInfo`, `ServerOP_LSStatus`, `ServerOP_LSPlayerJoinWorld` |
| Expedition/DZ | ~15 | `ServerOP_ExpeditionCreate`, `ServerOP_DzAddPlayer`, `ServerOP_DzSetCompass` |
| Shared Tasks | ~10 | `ServerOP_SharedTaskRequest`, `ServerOP_SharedTaskMemberlist` |
| GM/Admin | ~10 | `ServerOP_KickPlayer`, `ServerOP_FlagUpdate`, `ServerOP_ReloadWorld` |
| UCS/Mail | ~10 | `ServerOP_UCSMessage`, `ServerOP_UCSMailMessage` |
| Adventure | ~10 | `ServerOP_AdventureRequest`, `ServerOP_AdventureCreate` |
| Items/Trade | ~10 | `ServerOP_ItemStatus`, `ServerOP_MoveCharToBind` |
| Data Sync | ~15 | `ServerOP_ReloadRules`, `ServerOP_ReloadLogs`, `ServerOP_ReloadAAData` |
| Misc | ~50+ | `ServerOP_Weather`, `ServerOP_Lock`, `ServerOP_Motd`, `ServerOP_Petition` |

---

## 7. Networking Layer

### Source Files

| File | Role |
|------|------|
| `common/net/eqstream.h/cpp` | EQ UDP reliable stream — the core client connection |
| `common/net/reliable_stream_connection.h/cpp` | Generic reliable stream over UDP |
| `common/net/reliable_stream_structs.h` | Wire format for reliable stream headers |
| `common/net/reliable_stream_pooling.h` | Connection pooling |
| `common/net/packet.h/cpp` | Base packet class |
| `common/net/crc32.h/cpp` | CRC32 checksum |
| `common/net/servertalk_server.h/cpp` | Server-side TCP for zone↔world |
| `common/net/servertalk_server_connection.h/cpp` | Individual server TCP connection |
| `common/net/servertalk_client_connection.h/cpp` | Client-side TCP for zone→world |
| `common/net/servertalk_legacy_client_connection.h/cpp` | Legacy TCP connection |
| `common/net/servertalk_common.h` | Shared TCP definitions |
| `common/net/tcp_server.h/cpp` | Generic TCP server |
| `common/net/tcp_connection.h/cpp` | Generic TCP connection |
| `common/net/tcp_connection_pooling.h` | TCP connection pooling |
| `common/net/websocket_server.h/cpp` | WebSocket server (Spire integration) |
| `common/net/websocket_server_connection.h/cpp` | WebSocket connection |
| `common/net/console_server.h/cpp` | Telnet console server |
| `common/net/console_server_connection.h/cpp` | Console connection |
| `common/net/dns.h` | DNS resolution utility |
| `common/net/endian.h` | Byte-order utilities |

### EQ UDP Reliable Stream Protocol

The EQ protocol runs over UDP with a custom reliability layer that provides:

- **Sequencing** — Packets have sequence numbers for ordering
- **Fragmentation** — Large packets split across multiple UDP datagrams
- **ACK/NAK** — Acknowledgment and negative-acknowledgment for reliability
- **Resend** — Automatic retransmission on timeout or NAK
- **4 independent streams** — Separate sequence spaces (like TCP streams multiplexed over one UDP socket)
- **CRC32 validation** — Integrity checking on all packets
- **Compression** — Optional deflate compression for large packets

### Connection Lifecycle

```
1. Client sends SessionRequest (UDP)
2. Server responds with SessionResponse
3. eq_stream_ident.h identifies client version
4. Appropriate patch adapter (Titanium) is attached
5. ConnectingOpcodes handle login/zone-in packets
6. Client reaches "ready" state
7. ConnectedOpcodes handle all gameplay packets
8. SessionDisconnect on logout/linkdead
```

---

## 8. Quick Reference: File Map

| What | File | Lines |
|------|------|-------|
| Internal opcode definitions | `common/emu_oplist.h` | 630 |
| Opcode enum wrapper | `common/emu_opcodes.h` | 49 |
| Titanium opcode numbers | `common/patches/titanium_ops.h` | 137 |
| Titanium translation layer | `common/patches/titanium.cpp` | 3,923 |
| Titanium class declaration | `common/patches/titanium.h` | 52 |
| Packet structure definitions | `common/eq_packet_structs.h` | 6,566 |
| Client packet handlers | `zone/client_packet.cpp` | 17,356 |
| Server-to-server opcodes | `common/servertalk.h` | 1,783 |
| UDP reliable stream | `common/net/eqstream.h/cpp` | — |
| Client version detection | `common/eq_stream_ident.h` | — |
| All patch adapters | `common/patches/` | 7 client versions |
| Networking layer | `common/net/` | 34 files |

---

## 9. Titanium-Specific Constraints

These are critical when designing features that involve client-server communication:

1. **Fixed opcode table** — The Titanium client has a fixed set of opcodes it understands. New opcodes cannot be added without client modification. New features must reuse existing opcodes or piggyback on unused packet fields.

2. **Struct size sensitivity** — The client expects exact byte counts for most packets. Adding fields to existing structs will cause client crashes or data misalignment. The translation layer in `titanium.cpp` handles size differences.

3. **No new UI elements** — The Titanium client's UI is fixed. Server features must work within existing windows (chat, trade, merchant, inspect, etc.) or use creative workarounds.

4. **Bitfield position updates** — Position packets use aggressive bitfield packing. Coordinates are 19-bit signed integers, headings are 12-bit. These limits define the maximum zone dimensions and position precision.

5. **42 buff limit** — The Titanium client displays a maximum of 42 buffs. Server-side there can be more, but the client won't show them.

6. **Group size = 6** — The client's group window supports exactly 6 members (self + 5 others). The companion system must work within this constraint or find creative alternatives.

7. **String length limits** — Character names: 64 bytes. Zone names: 16 bytes. Chat messages: variable but the struct field widths are fixed. Exceeding these causes buffer overflows.
