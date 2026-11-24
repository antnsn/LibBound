---
title: Carrot on a Stick
parent: API reference
nav_order: 14
description: Wear Carrot on a Stick while mounted and put the own trinket back afterwards (Carrot.lua).
---

# Carrot on a Stick
{: .no_toc }

`Carrot.lua`: puts Carrot on a Stick (item 11122) into the trinket slot the player picked when they mount, and their own trinket back when they get off. `NewAddon` installs it (`lib.InstallCarrot(ns)`) in every Bound addon, and the shared Extras page has its setting. Taken from Lightbound, with the same setting names, so a paladin's settings carry over.

1. TOC
{:toc}

## Turning it off

An addon that does not want it:

```lua
ns.disabled = Bound:NewAddon(addonName, ns, { carrot = false, ... })
```

Then there is no module and no Extras section.

An older Lightbound (5.1.1 and before) has its own `Carrot.lua`, which replaces `ns.CarrotSlotItem` after `NewAddon`. The shared module sees that in its `Init` and stays off, so the carrot is never swapped twice and the Extras page shows Lightbound's own section only.

## Settings

All in `lib.SHARED_DEFAULTS`:

| Key | Default | What it is |
| --- | --- | --- |
| `carrotSwap` | `false` | On or off. Off by default. |
| `carrotSlot` | `"Bottom"` | `"Top"` (slot 13) or `"Bottom"` (slot 14). |
| `carrotPrev` | `{}` | Per character (`Name-Realm`): `{ slot = 13 or 14, item = itemID or nil }`, the trinket the carrot replaced. Saved, so a logout while mounted still puts it back. |

## How it behaves

- Not in instances, where you rarely ride and a swap mid-dungeon is unwanted.
- Gear can't change in combat: the swap waits until combat ends (`PLAYER_REGEN_ENABLED`). Also not while dead.
- Needs the carrot in the bags. Nothing happens when it is already in either trinket slot.
- Each ride is handled once: if the player changes that trinket slot by hand while riding, it is left alone until the next ride.
- Getting off, entering an instance or turning it off puts the old trinket back. An empty slot is emptied again: the carrot goes into the first free normal bag. A trinket that is gone from the bags (sold, banked) is forgotten.
- A swap that fails for a moment (item locked) is retried on the next aura, equipment or bag change.

Events: `PLAYER_MOUNT_DISPLAY_CHANGED` (checked 0.2 s later, `IsMounted` can lag), `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED`, `PLAYER_UNGHOST`, `PLAYER_ALIVE`, `UNIT_AURA` on the player.

## Functions

| Function | What it does |
| --- | --- |
| `ns.CarrotSlotID()` | The slot ID the carrot goes into: 13 or 14. |
| `ns.CarrotSlotItem(slotName)` | The name of what is in `"Top"` or `"Bottom"` now, or `"empty"`. The Extras page shows it. |

The module's `Update` runs on every `ns.Refresh()`, so a changed setting applies at once.
