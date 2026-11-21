---
title: Core
parent: API reference
nav_order: 1
description: NewAddon, the ns helpers, modules, movable frames and the slash command (Core.lua).
---

# Core
{: .no_toc }

`Core.lua`: `NewAddon` and everything it puts into `ns`. Click-to-cast overlays live in this file too; they have their own page, [Overlays](overlays.html).

1. TOC
{:toc}

## NewAddon

```lua
local Bound = LibStub("LibBound-1.0")
local disabled = Bound:NewAddon(addonName, ns, cfg)
```

The header comment of `Core.lua`:

```lua
-- cfg = {
--   class = "MAGE",                 -- loads only on this class (nil: every class)
--   title = "Chronobound",          -- shown in chat, windows, tooltips
--   prefix = "9fdcff",              -- chat prefix colour (hex)
--   db = "ChronoboundDB",           -- SavedVariables name
--   defaults = { ... },             -- merged under the shared defaults below
--   slash = { "/cb", "/chronobound" },
--   commands = { name = { fn = function(arg) end, help = "..." } }, -- extra sub-commands
--   media = "Interface\\AddOns\\Chronobound\\Media\\",
--   migrate = function(db, defaults) end, -- optional, after the defaults are in
-- }
-- Returns true when the addon should load nothing (wrong class): its files then return early.
```

Every field it reads:

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `class` | string | `nil` | Class file name, `"DRUID"`. `nil` loads on every class. |
| `className` | string | `class` capitalized | The class name in the wrong-class messages. Not in the header comment. |
| `title` | string | `addonName` | Chat prefix, window titles, tooltips. |
| `prefix` | string | `"ffd100"` | Hex color of the chat prefix. |
| `db` | string | required | The global SavedVariables table name. |
| `defaults` | table | `{}` | Merged over `lib.SHARED_DEFAULTS`: the addon's value wins for a key in both. |
| `slash` | list of strings | required | `slash[1]` is the main command and the base of the aliases. |
| `commands` | table | `{}` | Extra sub-commands, see [The slash command](#the-slash-command). |
| `media` | string | `nil` | Media folder path with a trailing `\\`. Stored as `ns.MEDIA`. |
| `migrate` | function | `nil` | `migrate(db, defaults)`, after missing defaults are copied in. |
| `buffKey` | boolean | `nil` | LibBound 19 and later: `buffKey = false` in the NewAddon config turns the shared buff key off. |

**Returns** `true` when the player's class is not `cfg.class`, else `false`.

### On the wrong class

`NewAddon` then:

- registers the slash commands only to print `only does something on a <class>.`;
- calls `C_AddOns.DisableAddOn(addonName, playerName)`, so the addon is off for this character from the next login, and says so when the client confirms it;
- sets `ns.disabled = true` and returns `true`. Nothing else is installed.

### What it sets up

On the right class, `NewAddon` sets:

| Field | What it is |
| --- | --- |
| `ns.cfg`, `ns.lib`, `ns.addonName`, `ns.class` | The config, the library, the addon name, the player's class file name. |
| `ns.defaults` | `lib.SHARED_DEFAULTS` with `cfg.defaults` over them. |
| `ns.MEDIA` | `cfg.media`. |
| `ns.modules` | An empty module list. |
| `ns.optionPages` | Kept if the addon made it already, else `{}`. |
| `ns.Print`, `ns.IsSecret`, `ns.Clean`, `ns.Copy`, `ns.InCombat`, `ns.ReadPlayerBuffs`, `ns.SpellName`, `ns.BestRank`, `ns.SetEmblem` | The helpers below. |

Then it runs, in this order: `lib.InstallMovers(ns)`, `lib.InstallOverlays(ns)`, `lib.InstallBuffKey(ns)`, `lib.InstallLoader(ns, addonName, cfg)` and `lib.InstallSlash(ns, addonName, cfg)`.

`ns.db` is not there yet when `NewAddon` returns. The loader fills it on `ADDON_LOADED`.

### lib.SHARED_DEFAULTS

Settings every Bound addon has (Lightbound's names, so its settings carry over):

```lua
lib.SHARED_DEFAULTS = {
	snap = true, gridSize = 20, -- unlocked frames snap to a grid around the screen centre
	minimap = true, minimapAngle = 220,
	explain = true, -- plain-word explanations in tooltips
	travel = true, -- the travel panel beside the Escape menu (every Bound addon has one)
	wellRested = true, wellRestedMinutes = 5, wellRestedSound = true, wellRestedIcon = true, wellRestedKeep = false,
	wrPoint = { "CENTER", "UIParent", "CENTER", 0, 350 },
	wellFed = true, wellFedMinutes = 3, wellFedSound = true, wellFedIcon = true, wellFedKeep = false,
	wfPoint = { "CENTER", "UIParent", "CENTER", 0, 290 },
}
```

Other keys LibBound writes into `ns.db` at run time: `scales` (frame scales), `optionsPage` (the last options page), `skin`, `buffKey`, `minimapIcon` (LibDBIcon's table) and `shots`.

## Helpers

### ns.Print

```lua
ns.Print(msg)
```

Prints `<title>: msg` in chat, with the title in `cfg.prefix` color.

### ns.IsSecret, lib.IsSecret

```lua
local secret = ns.IsSecret(v)
```

`true` when `v` is a secret value (hidden from addons in combat on Forever). Uses `issecretvalue` on clients that have it, else `not canaccessvalue(v)`, else `false`. Check this before any comparison: even `v == nil` is not allowed on a secret value.

### ns.Clean, lib.Clean

```lua
local value = ns.Clean(v)
```

`nil` when `v` is secret or `nil`, else `v`. Wrap every value that comes from an aura, unit or spell API.

### ns.Copy, lib.Copy

```lua
local t2 = ns.Copy(t)
```

A deep copy of a table.

### ns.InCombat

```lua
local fighting = ns.InCombat()
```

`true` in combat. `InCombatLockdown()` only turns true after `PLAYER_REGEN_DISABLED` has fired, so it also asks `UnitAffectingCombat("player")`. A secret or failed answer counts as in combat.

### ns.ReadPlayerBuffs

```lua
local buffs, hidden = ns.ReadPlayerBuffs()
```

The player's helpful auras:

- `buffs`: `name -> { icon, duration, expires, mine, spellId }`. `mine` is `true` when the player cast it, `false` when someone else did, `nil` when unknown. For two auras with the same name, the player's own wins.
- `hidden`: `true` when some auras were hidden from addons (a secret or restricted name, an API error) and always in combat, since some self-buffs are left out in combat.

When `hidden` is true, a missing buff may only be unreadable. Don't nag on it.

### ns.SpellName

```lua
local name = ns.SpellName(spellID)
```

The localized spell name, or `nil` for a `nil` or secret ID or an unknown spell.

### ns.BestRank

```lua
local id, index = ns.BestRank(list)
```

`list` is a list of spell IDs, lowest rank first. Returns the highest one the player knows (`IsPlayerSpell`) and its index, or `nil`.

### Emblems: ns.SetEmblem and ns.EmblemVariant

```lua
ns.SetEmblem(texture, base)
```

Sets `texture` to `ns.MEDIA .. base .. suffix` and remembers it. The suffix comes from the addon's optional `ns.EmblemVariant()`, which returns a file-name suffix such as `"Shadow"` or `nil`. LibBound asks again on `PLAYER_LOGIN` and `SPELLS_CHANGED` and sets every remembered texture again when the answer changes. Without `EmblemVariant`: plain names.

LibBound uses it for the options logo (`Logo64`), the watermark (`Logo256`), the minimap icon (`Icon64`) and the skin's crest. Spiritbound's variant:

```lua
local SHADOW_TALENTS = { 15473, 15286, 15407, 15487 }
function ns.EmblemVariant()
	for _, id in ipairs(SHADOW_TALENTS) do
		local ok, known = pcall(IsPlayerSpell, id)
		if ok and not ns.IsSecret(known) and known then return "Shadow" end
	end
	return nil
end
```

Define it before `NewAddon` or at least before login. `texture` only needs a `SetTexture` method; the minimap button passes a proxy table.

### ns.OnOff

```lua
local text = ns.OnOff(value)
```

Green `on` or red `off`, for chat. Set by the slash command install.

## Modules and the error guard

```lua
-- A module is a table in ns.modules with optional Init(), Update(), Layout(). Init runs once the
-- saved settings are in; Update/Layout when a setting changes (ns.Refresh).
```

```lua
local M = {}
ns.modules[#ns.modules + 1] = M
function M:Init() --[[ build frames, register events ]] end
function M:Update() --[[ show, hide, set texts ]] end
function M:Layout() --[[ optional: sizes and places ]] end
```

### When Init runs

On the addon's `ADDON_LOADED`, the loader:

1. sets `_G[cfg.db]` to a table if it is missing, and `ns.db` to it;
2. copies every missing default into `ns.db` (tables are deep-copied);
3. calls `cfg.migrate(ns.db, ns.defaults)` if set;
4. installs a Hearthstone-only travel panel if the addon has none (`ns.travel` unset) and has a skin (`ns.UI` set);
5. runs every module's `Init` through `ns.Guard`. In combat (a `/reload` mid-fight) it waits for `PLAYER_REGEN_ENABLED`, since modules build secure buttons in `Init`.

### ns.Guard

```lua
local ok = ns.Guard(module, methodName, ...)
```

Runs `module[methodName](module, ...)` in `pcall`, so an error in one module can't stop the modules after it. Returns `true` when the method ran fine or doesn't exist. On an error: the first one per module is printed in chat (`a part of the addon hit an error, the rest keeps working: ...`), `module.failed` is set, every error goes to the game's error handler, and it returns `false`.

### ns.Refresh

```lua
ns.Refresh()
```

For every module: `Layout` (if it has one), then `Update`, each through `ns.Guard`. Option widgets, slash commands and `ns.ToggleMove` call it after a change.

## Movable frames and the grid

### ns.MakeMovable

```lua
ns.MakeMovable(frame, key)
```

Makes `frame` draggable while the frames are unlocked, with its position saved in `ns.db[key]` (a `*Point` key). While unlocked, the mouse wheel scales the frame in 10% steps between 50% and 250%, saved in `ns.db.scales[key]`. Dragging snaps the frame's anchor point to the grid around the screen centre when `ns.db.snap` is on; Shift places it freely. A fight that starts mid-drag stops the drag. Adds the frame to `ns.movers`.

### ns.ApplyPoint

```lua
ns.ApplyPoint(frame, key)
```

Sets the frame's scale from `ns.db.scales[key]` (default 1) and its point from `ns.db[key]`, a `{ point, "UIParent", relativePoint, x, y }` table. Call it after `MakeMovable` in `Init`.

### ns.ToggleMove

```lua
ns.ToggleMove()
```

Unlocks or locks every frame in `ns.movers`. Refuses in combat (`leave combat first.`). Unlocked: mouse and wheel on, the grid and a small bar at the top of the screen (grid size, Snap, Lock). Locked: mouse off again, except on cards with `clickable` set; cards with an explanation keep mouse-over without clicks. Calls `ns.Refresh()`. `ns.unlocked` holds the state; modules show sample content while it is true.

### ns.ResetPositions

```lua
ns.ResetPositions()
```

Every `ns.db` key ending in `Point` back to its default, `ns.db.scales` cleared, every mover placed again. Refuses in combat.

### Lower level

- `ns.ShowGrid(show)`: shows or hides the grid and its bar.
- `ns.BeginDrag(frame, key)`, `ns.EndDrag(frame, key)`: the drag handlers `MakeMovable` sets.
- `ns.movers`: list of `{ frame = frame, key = key }`.
- The grid colors come from the skin: `ns.UI.C.gridLine` and `ns.UI.C.gridCentre`.

## The slash command

```lua
-- /cmd opens the options; /cmd <name> runs a command; every command also gets a space-free alias
-- (/cbunlock) for chat setups that swallow Enter after a space.
```

| Input | What it does |
| --- | --- |
| `/cmd`, `/cmd options`, `/cmd config` | `ns.ToggleOptions()` |
| `/cmd help` | The command list. An unknown command shows it too. |
| `/cmd unlock` | Unlock the frames. |
| `/cmd lock` | Lock the frames. |
| `/cmd move` | Unlock or lock. |
| `/cmd reset` | `ns.ResetPositions()` |
| `/cmd grid [size]` | With a number: grid size (4 to 100) and snap on. Without: snap on or off. |
| `/cmd minimap` | Minimap button on or off. |
| `/cmd explain` | Explanations in tooltips on or off. |
| `/cmd shots` | Hidden: not in the help. Screenshots for the docs, see [Shots](shots.html). |

After every command it calls `ns.Refresh()`. Nothing runs before `ns.db` exists.

### Extra commands

```lua
commands = {
	ammo = { fn = function(arg) ns.WaypointToAmmo() end, help = "set a waypoint to the nearest ammo vendor" },
},
```

`fn(arg)` gets the rest of the line, trimmed (`""` when empty). `help` is the line in `/cmd help`. Set `hidden = true` to leave a command out of the help. An addon command with the same name as a shared one replaces it. The full table is `ns.commands`.

### Aliases

Every command gets a space-free alias from `slash[1]` plus the name: `/dreamunlock`, `/dreamreset`, `/dreamshots`, and `/dreamhelp`. Only `slash[1]` gets aliases. The global names are `SLASH_<ADDON><NAME>1`, where `<ADDON>` is the upper-case addon name.
