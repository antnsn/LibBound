---
title: API reference
nav_order: 3
has_children: true
description: Every LibBound function and config table, one page per area.
permalink: /api/
---

# API reference

One page per area. Signatures, parameters and config tables are taken from the code; where a file's header comment defines the contract, it is quoted.

Two kinds of names:

- `lib.*` (or `Bound.*`): functions on the library table, `local Bound = LibStub("LibBound-1.0")`. Mostly the `Install*` functions an addon calls once.
- `ns.*`: functions LibBound puts into the addon's own namespace table. Each addon gets its own set, bound to its own settings.

| Page | File | What an addon calls |
| --- | --- | --- |
| [Core](core.html) | `Core.lua` | `Bound:NewAddon`, `ns.Print`, `ns.ReadPlayerBuffs`, `ns.MakeMovable`, `ns.Guard`, `ns.Refresh`, slash commands |
| [Cards](cards.html) | `Card.lua` | `ns.MakeCard` and the card methods |
| [Buff timers](buff-timers.html) | `BuffTimer.lua` | `Bound.InstallBuffTimers`, `ns.MakeBuffTimer` |
| [Overlays](overlays.html) | `Core.lua` | `ns.CastOverlay`, `overlay:Sync` |
| [Options](options.html) | `Options.lua` | `Bound.InstallOptions`, `ns.optionPages`, the `UI` widgets |
| [Skins](skins.html) | `Skin.lua` | `Bound.InstallSkin`, `ns.UI` |
| [Travel panel](travel.html) | `Travel.lua` | `Bound.InstallTravel` |
| [Minimap button](minimap.html) | `Minimap.lua` | `Bound.InstallMinimap` |
| [Buff key](buff-key.html) | `BuffKey.lua` | `ns.groupBuffs` |
| [Shots](shots.html) | `Shots.lua`, `tools/crop_shots.py` | `/<cmd> shots` |
| [Combo bar](combo-bar.html) | `ComboBar.lua`, `tools/make_combo_media.py` | `Bound.InstallComboBar` |
| [Power bar](power-bar.html) | `PowerBar.lua`, `tools/make_bar_media.py` | `Bound.InstallPowerBar` |
| [Cooldown Manager skin](cooldown-skin.html) | `CooldownSkin.lua` | `Bound.InstallCooldownSkin` |

## The order of calls

What Dreambound calls, in `.toc` order:

```lua
-- Core.lua
ns.disabled = Bound:NewAddon(addonName, ns, cfg) -- movers, overlays, buff key, loader, slash
-- Skin.lua
Bound.InstallSkin(ns, { skins, order, default, about }) -- ns.UI, widgets, ns.MakeCard
Bound.InstallBuffTimers(ns)                             -- ns.MakeBuffTimer, Well-Rested, Well Fed
Bound.InstallMinimap(ns)
-- Buffs.lua, Reagents.lua: ns.MakeBuffTimer, ns.MakeCard, ns.groupBuffs, modules
-- Travel.lua
Bound.InstallTravel(ns, cfg)
-- Options.lua
Bound.InstallComboBar(ns, { glow, active, about }) -- optional: a combo point bar and its page
Bound.InstallPowerBar(ns, { power, title, active, ... }) -- optional: a rage or energy bar and its page
Bound.InstallCooldownSkin(ns, { suggest })             -- optional: Blizzard's Cooldown Manager in the addon's look
Bound.InstallOptions(ns, cfg)
```

All of this runs while the addon's files load. The loader then waits for the addon's `ADDON_LOADED`, fills `ns.db` and runs every module's `Init`.
