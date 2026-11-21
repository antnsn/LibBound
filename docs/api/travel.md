---
title: Travel panel
parent: API reference
nav_order: 7
description: Bound.InstallTravel, the panel beside the Escape menu (Travel.lua).
---

# Travel panel
{: .no_toc }

`Travel.lua`: beside the game menu (Escape), the class's own ways to travel and the Hearthstone.

1. TOC
{:toc}

The header comment:

```lua
-- LibBound travel panel: beside the game menu (Escape), the class's own ways to travel (a mage's
-- teleports and portals, a shaman's Astral Recall...) and the Hearthstone. Click one to cast it;
-- the menu closes after the cast. Spells not learned yet are greyed with the level.
-- The panel holds secure buttons, so it lives on UIParent (a secure child would make the game
-- menu itself protected and break Escape in combat); it follows the menu out of combat only,
-- which is also when travel spells can be cast, and a secure driver hides it when a fight starts.
--
-- lib.InstallTravel(ns, {
--   key = "travel",                         -- the on/off setting
--   columns = { "TELEPORT", "PORTAL" },     -- one or two column headers ({} for none)
--   rows = function() return { { spell = id, label = "Orgrimmar", column = 1, known = bool,
--            level = 20, tip = "Teleport: Orgrimmar", help = "...", learn = "from a mage trainer" } } end,
--   footer = function() return "Runes: ..." end, -- optional text line (may change in combat)
--   hearthHelp = "...",                      -- tooltip help for the Hearthstone row
--   action = function() return { icon = fileID, label = "...", sub = "...", tip = "...", help = "...",
--            note = "...", click = function() end } end, -- optional: one plain (not secure) row
--            under the spells, refreshed on every menu open; nil hides it. A click calls click()
--            and closes the menu. Not a spell, so it can't cast; it can set a waypoint, open a page.
-- })
```

## Bound.InstallTravel

```lua
local M = Bound.InstallTravel(ns, cfg)
```

| Field | Default | What it is |
| --- | --- | --- |
| `key` | `"travel"` | The on/off setting in `ns.db`. |
| `columns` | `{ "TRAVEL" }` | Column headers. One or two; `{}` for no headers. |
| `rows` | required | A function returning the rows (below). Called on every rebuild. |
| `footer` | `nil` | A function returning a text line under the spells. Updated on every open and after bag changes, also in combat. |
| `hearthHelp` | `nil` | Tooltip help for the Hearthstone row. |
| `action` | `nil` | A function returning one action row, or `nil` to hide it. |

**Returns** the module `M` (added to `ns.modules`), also stored as `ns.travel`.

### Without a call

The loader installs a panel with no spells and only the Hearthstone when the addon calls neither `InstallTravel` nor sets `ns.travel` by `ADDON_LOADED`, as long as the addon has a skin (`ns.UI`). So every Bound addon has the panel.

### Rows

```lua
{ spell = id, label = "Orgrimmar", column = 1, known = bool,
  level = 20, tip = "Teleport: Orgrimmar", help = "...", learn = "from a mage trainer" }
```

| Field | What it is |
| --- | --- |
| `spell` | Spell ID: the icon, and what a click casts. |
| `label` | The row's text. |
| `column` | 1 or 2. Default 1. |
| `known` | `true`: the row casts the spell. `false`: grayed, with `level <n>` under the label. |
| `level` | The level it is learned at. |
| `tip` | Tooltip title. Default `label`. |
| `help` | Tooltip help, shown while `ns.db.explain` is on. |
| `learn` | Where to learn it, for a row not known yet: `Learn it at level <level> <learn>.` Default `from your class trainer`. |

### The action row

```lua
action = function()
	return { icon = fileID, label = "...", sub = "...", tip = "...", help = "...", note = "...",
		click = function() end }
end
```

| Field | What it is |
| --- | --- |
| `icon` | Icon file ID. Default the question mark (134400). |
| `label`, `sub` | The two text lines. |
| `tip`, `help`, `note` | Tooltip title (default `label`), help (with explanations on) and a blue note. |
| `click` | Called on a left click, then the menu closes. Without `click` the row is grayed and does nothing. |

The row is a plain button, not a secure one: it can't cast. It sits between the spells and the footer and is refreshed on every menu open. Packbound's nearest ammo vendor:

```lua
return { icon = icon, label = "Ammo: " .. v.name, sub = ("%s, %d yards"):format(v.zone, v.yards),
	tip = "Nearest ammo vendor", help = ns.Help.ammoVendor, note = "Click for a waypoint.", click = ns.WaypointToAmmo }
```

## Behavior

- The panel opens with the game menu when `ns.db[key]` is on, placed to the right of the menu, out of combat only.
- A click casts on the mouse phase `ActionButtonUseKeyDown` picks; the menu closes after that phase.
- The Hearthstone row (item 6948) shows `Hearthstone: <bind location>` and hides when the player has none.
- The panel rebuilds after `SPELLS_CHANGED` and `PLAYER_ENTERING_WORLD`, and catches up after combat. Texts (footer, action row, Hearthstone) update on every open and on `BAG_UPDATE_DELAYED`.
- A state driver hides the panel when combat starts.
- Frame names: `<Addon>Travel`, `<Addon>TravelButton<i>`, `<Addon>TravelHearth`, `<Addon>TravelAction`.
- The skin's crest sits in the corner.

## Module fields

| Field | What it is |
| --- | --- |
| `M:Init()`, `M:Update()` | Run by the loader and `ns.Refresh`. |
| `M:UpdateCounts()` | Refreshes only the texts: footer, action row, Hearthstone. Safe in combat. |

## Examples

Chronobound, two columns and a footer:

```lua
Bound.InstallTravel(ns, {
	columns = { "TELEPORT", "PORTAL" },
	rows = ns.TravelRows,
	footer = function()
		local t, p = Count(RUNE_TELEPORT), Count(RUNE_PORTAL)
		local function N(n) return (n < 3 and ns.UI.Hex({ 1, 0.62, 0.42 }) or "") .. n .. "|r" end
		return "Runes: Teleportation " .. N(t) .. " · Portals " .. N(p)
	end,
	hearthHelp = ns.Help.hearthstone,
})
```

Packbound, one column and an action row:

```lua
Bound.InstallTravel(ns, { columns = { "HUNTER" }, rows = ns.TravelRows, hearthHelp = ns.Help.hearthstone,
	action = function() return ns.AmmoTravelRow() end })
```
