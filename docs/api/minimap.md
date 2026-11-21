---
title: Minimap button
parent: API reference
nav_order: 8
description: Bound.InstallMinimap, a LibDataBroker launcher shown by LibDBIcon (Minimap.lua).
---

# Minimap button
{: .no_toc }

`Minimap.lua`: the minimap button, also listed in the addon compartment.

1. TOC
{:toc}

The header comment:

```lua
-- LibBound minimap button: left-click options, shift- or middle-click unlocks the frames, an
-- optional right-click action, drag to move around the minimap. Also listed in the addon
-- compartment.
-- lib.InstallMinimap(ns, { rightClick = fn, rightClickText = "Right-click: ..." })
--
-- The button is a LibDataBroker launcher shown by LibDBIcon-1.0 (both embedded in LibBound's
-- Libs/), so minimap addons (EllesmereUI, SexyMap, ElvUI, MinimapButtonBag, broker bars...)
-- collect it like any other. Without those libraries it falls back to a button of its own.
-- Position: ns.db.minimapIcon (LibDBIcon's table: minimapPos in degrees, hide), started from the
-- older ns.db.minimapAngle; ns.db.minimap shows or hides it.
```

## Bound.InstallMinimap

```lua
Bound.InstallMinimap(ns, cfg)
```

| Field | What it is |
| --- | --- |
| `cfg.rightClick` | Optional function for a right click. |
| `cfg.rightClickText` | Optional tooltip line for it. |

`cfg` may be left out. Lightbound opens its Blessings window on right-click:

```lua
Bound.InstallMinimap(ns, {
	rightClick = function() if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end end,
	rightClickText = "Right-click: blessings",
})
```

## Clicks

| Click | What it does |
| --- | --- |
| Left | `ns.ToggleOptions()` |
| Shift + left, or middle | `ns.ToggleMove()` |
| Right | `cfg.rightClick()` if set, else the options |
| Drag | Moves the button around the minimap |

The click handler is also `ns.MinimapClick(_, button)`.

## How it is shown

On `Init`:

1. With LibDataBroker-1.1 and LibDBIcon-1.0 (both loaded by `LibBound.xml`), it creates a `launcher` data object named after the addon, with the title, the icon, the click handler and the tooltip, and registers it with LibDBIcon. The icon follows the emblem variant through `ns.SetEmblem` (`Icon64`).
2. Without them, or if that fails, it builds its own button, `<Addon>MinimapButton`, placed by angle (`ns.db.minimapAngle`) around the minimap.
3. It registers the addon in the addon compartment (`AddonCompartmentFrame`), when the client has one.

## Settings

| Key | What it is |
| --- | --- |
| `minimap` | Show the button. Shared default `true`. Toggled by `/cmd minimap` and the Skin page. |
| `minimapIcon` | LibDBIcon's table (`minimapPos` in degrees, `hide`). Created from `minimapAngle` the first time. |
| `minimapAngle` | The angle for the fallback button, and the start of `minimapIcon`. Shared default 220. |

The addon needs `Media/Icon64` for the icon.
