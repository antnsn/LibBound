---
title: Assignments
parent: API reference
nav_order: 16
description: Who in the group casts each raid-wide buff, shared with Buffy, Priestly, Wildly and Magely over LibGroupBuffs' addon messages (Assign.lua).
---

# Assignments
{: .no_toc }

`Assign.lua`: who in the group casts each raid-wide buff. It speaks protocol v1 of [LibGroupBuffs-1.0](https://github.com/Spotnick2/LibGroupBuffs) (MIT; the addon-message prefix `LibGroupBuffs`). A Bound caster therefore shares assignments with casters on Buffy, Priestly, Wildly or Magely. The code is ported from LibGroupBuffs' Assign section. The slot table, the message format and the record order are protocol, so keep them the same as there.

1. TOC
{:toc}

## Turning it on

Give a [group buff](buff-key.html#nsgroupbuffs) its slot, which is the first rank's spell ID:

```lua
ns.groupBuffs[#ns.groupBuffs + 1] = { list = D.fortitude, slot = D.fortitude[1], ... } -- 1243
```

The buff key's `Init` starts the shared client the first time an entry has a slot. Then:

- **The buff key** leaves out a buff that another live caster owns: no single casts, no Prayer, and no line on the group card. A buff you own is on even when its `enabled` says no.
- **A "Group" options page** (after Extras) lists one row per slotted buff: who has it, and **Take** / **Release**. **Take** is grey until you can cast the slot's group spell. It has a page of its own because the Extras page has no room left, and pages don't scroll.
- **`/<slash> assign`** lists them, and `/<slash> assign <n>` takes or releases the n-th one.
- **Chat** gets one line when someone else gives you a buff, takes one over, or goes away.

## Slots (protocol v1)

| Key | Class | Kind | Owner must know |
| --- | --- | --- | --- |
| 1243 | Priest | owner | 21562 Prayer of Fortitude |
| 14752 | Priest | owner | 27681 Prayer of Spirit |
| 976 | Priest | owner | 27683 Prayer of Shadow Protection |
| 6346 | Priest | targets (Fear Ward) | 6346 |
| 1126 | Druid | owner | 21849 Gift of the Wild |
| 467 | Druid | targets (Thorns) | 467 |
| 1459 | Mage | owner | 23028 Arcane Brilliance |
| 1008 | Mage | owner, one of 1008 / 604 | Amplify or Dampen Magic |

Every client keeps and relays every slot's record, including other classes', because the checksum covers them all. The targets slots are stored and relayed but not used yet.

## Rules

- **Live owner:** an owner counts only while they are in the group, online, heard from within 180 seconds, and able to cast the slot's group spell. Their age stops counting while chat is locked down. When the owner is not live, the slot counts as nobody's, but the record stays, so the claim comes back when the owner does.
- **Last write wins:** records are ordered by version, then writer, then value. A version is the server time × 1000, or one more than the current version. A version more than a day ahead is refused.
- **Edits** are refused out of a group, in combat, and when the message would not fit in 255 bytes.
- **Nothing is saved.** After a `/reload` the client asks the group: a hello with a different checksum makes a peer resend, once and a few seconds later, every record the channel has not carried in the meantime.
- **Throttle:** about 10 messages at once, then 1 a second. A refused message is kept and sent again.

## Messages

On `RAID`, `PARTY` or `INSTANCE_CHAT`, with the home group first:

```
1^H^<class>^<known spell ids, sorted, csv>^<checksum>   hello: on joining, on login, when your spells change, to a new peer, every 60 ± 10 s
1^A^<slot key>^<version>^<writer>^<value>               one record: owner name, "name,choice" for 1008, a csv of names for targets ("6346:<caster>")
```

The checksum is `%08x` of djb2 (`h = h * 33 + byte`, mod 2^32) over the sorted `key|ver|writer|value\n` lines, or `0` when there are no records. Names are `GetUnitName(unit, false)`, and `^ , : |` are not allowed in them.

## Next to LibGroupBuffs

When another addon on this client already runs LibGroupBuffs' client (Buffy, for example), LibBound does not run its own. It reads and edits LibGroupBuffs' state and sends nothing, so every hello still goes out only once. `lib.AssignBackend()` says which client is used.

## Functions

| Function | Returns |
| --- | --- |
| `lib.AssignOwner(key)` | The live owner's name, or nil. True as the second value when the owner is you. |
| `lib.AssignRecorded(key)` | The recorded owner, live or not. |
| `lib.AssignSet(key, name)` | `ok, why`. Pass your name to claim, another name to hand it over, or nil to clear. `why` is `group`, `combat`, `invalid`, `version` or `size`. |
| `lib.AssignMe()` | Your name as the protocol writes it (nil out of a group). |
| `lib.AssignSlots(class)` | That class's owner slots. |
| `lib.AssignLabel(key)` | The slot's group spell name, e.g. "Prayer of Fortitude". |
| `lib.AssignState(key)` | The row text and the button action (`"Take"`, `"Release"` or nil). |
| `lib.AssignWatch(fn)` | Calls `fn()` whenever who owns what may have changed. |
| `lib.AssignBackend()` | `"own"`, `"LibGroupBuffs"`, or nil before it starts. |

## Tests

`lua5.1 tests/test_assign.lua` runs several clients on a simulated channel and covers:

- claims, repair for a joiner, offline and silent owners, clears after a `/reload`, and concurrent edits
- the exact v1 messages, and the malformed ones that are refused
- the bridge to LibGroupBuffs

Spiritbound's `tests/assign.scenario.lua` drives it through the buff key.
