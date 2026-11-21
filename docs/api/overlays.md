---
title: Overlays
parent: API reference
nav_order: 4
description: ns.CastOverlay and overlay:Sync, click-to-cast over a card (Core.lua).
---

# Overlays
{: .no_toc }

Click-to-cast overlays, in `Core.lua`. `NewAddon` installs them (`lib.InstallOverlays(ns)`).

1. TOC
{:toc}

The header comment:

```lua
-- A secure button laid over a card: click it to cast the spell. It is a separate frame on UIParent,
-- positioned to match the card, so the card itself stays unprotected and can show and hide in
-- combat. Lua only moves, shows or hides the overlay out of combat. A secure state driver hides it
-- the moment combat starts, and the next out-of-combat Sync brings it back.
-- Create overlays out of combat only. overlay:Sync(spell, unit, explain, macro) shows it over its
-- owner; spell nil hides it.
```

## ns.CastOverlay

```lua
local overlay = ns.CastOverlay(owner)
```

| Parameter | What it is |
| --- | --- |
| `owner` | The frame to cover, usually a card. |

**Returns** a hidden `Button` on `UIParent` with the templates `SecureActionButtonTemplate, SecureHandlerStateTemplate`, `type = "macro"`. It takes both mouse phases (`AnyDown`, `AnyUp`). A state driver (`[combat] 1; 0`) hides it when combat starts.

Every overlay is added to `ns.overlays`, in creation order. The [buff key](buff-key.html) casts what the first shown one would.

Create it in a module's `Init` (which runs out of combat).

## overlay:Sync

```lua
overlay:Sync(spell, unit, explain, macro)
```

| Parameter | What it is |
| --- | --- |
| `spell` | The spell name to cast, shown as the tooltip title. `nil` hides the overlay. |
| `unit` | The target unit. Default `"player"`. |
| `explain` | Optional plain-word text for the tooltip (while `ns.db.explain` is on). |
| `macro` | Optional full macro text instead of `/cast [nocombat,@<unit>] <spell>`. |

What it does:

- In combat: nothing. Call it again after combat (on `PLAYER_REGEN_ENABLED`, or from `Update`).
- Hides the overlay when `spell` is `nil`, the frames are unlocked, the owner is not visible or has no position yet.
- Else places it exactly over the owner (same strata, 10 levels above, scale taken into account), sets `macrotext` only when it changed, and shows it.

The tooltip shows the spell, the explanation and `Click to cast (out of combat)`.

### The macro parameter

The default macro has `[nocombat]`. Pass `macro` for anything a plain `/cast` can't do. Packbound's pet card:

```lua
if need == "revive" then
	macro = ("/cast %s"):format(revive)
else
	macro = ("/cast [@pet,dead] %s; [nopet] %s"):format(revive, call)
end
-- feeding: a spell and an item
macro = ("/cast %s\n/use item:%d"):format(spell or "Feed Pet", ns.PetFood())
overlay:Sync(spell, "player", ns.Help[...], macro)
```

## Fields

| Field | What it is |
| --- | --- |
| `overlay.spell` | The spell it casts now, `nil` while hidden. |
| `overlay.explain` | The tooltip text. |

## The rule

{: .warning }
A shown overlay means "cast this now". Sync a spell only while the cast is needed (a missing buff, water to conjure, a pet to call), and `Sync(nil)` once it isn't. The buff key presses the first shown overlay, so an overlay that stays up while all is well would be cast again on every press.

Buff timers follow this rule on their own: their overlay shows only in the countdown and gone states.

## Pattern

```lua
function M:Update()
	if not card then return end
	local need = -- what to cast now, or nil
	-- ... card texts, Show/Hide, Glow
	if not InCombatLockdown() then overlay:Sync(need, "player", ns.Help.something) end
end

function M:Init()
	card = ns.MakeCard("MyAddonThingFrame")
	ns.MakeMovable(card, "thPoint")
	ns.ApplyPoint(card, "thPoint")
	overlay = ns.CastOverlay(card)
	-- register PLAYER_REGEN_ENABLED among the events, so the overlay comes back after a fight
end
```
