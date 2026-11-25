---
title: Home
nav_order: 1
description: What LibBound is, what it gives a Bound addon, and how it is embedded.
permalink: /
---

# LibBound-1.0
{: .fs-9 }

The shared core of the Bound addons for World of Warcraft: Forever.
{: .fs-6 .fw-300 }

[Build a Bound addon](guide.html){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[API reference](api/){: .btn .fs-5 .mb-4 .mb-md-0 }

---

This site is for developers: people who want to work on LibBound or on one of the Bound addons, or who want to build a new one (a Ragebound for warriors, a Shadowbound for rogues). Players want the docs of the addon they use.

## What LibBound is

The Bound addons are small class helpers, one per class. Each one shows cards when a buff is missing, warns before reagents run out and puts the class's travel spells beside the Escape menu. They look like their class but work the same way.

LibBound-1.0 is the part they share. It started as Lightbound's own core. An addon calls one function from its first file:

```lua
local addonName, ns = ...
local Bound = LibStub("LibBound-1.0")
ns.disabled = Bound:NewAddon(addonName, ns, cfg)
```

That fills the addon's namespace table `ns` with everything below, bound to that addon's own settings, names and slash command. Nothing is shared between two addons except the library code itself.

## What it gives an addon

| Piece | What it does | Reference |
| --- | --- | --- |
| Saved settings | Defaults merged into the addon's SavedVariables, plus the shared ones (grid, minimap, explanations, travel, Well-Rested, Well Fed). | [Core](api/core.html) |
| Safe aura reading | `ns.ReadPlayerBuffs`, `ns.IsSecret`, `ns.Clean`: reading buffs on Forever, where some values are secret in combat. | [Core](api/core.html) |
| Module loader with an error guard | Modules with `Init`, `Update`, `Layout`. An error in one module can't stop the others. | [Core](api/core.html#modules-and-the-error-guard) |
| Movable frames with a grid | Unlock, drag, snap to a grid, scale with the mouse wheel, reset. | [Core](api/core.html#movable-frames-and-the-grid) |
| Slash command | `/cmd` opens the options, `/cmd <name>` runs a command, every command gets a space-free alias. | [Core](api/core.html#the-slash-command) |
| Cards | The one look for reminders: icon, title, status, glow, dressed by the skin. | [Cards](api/cards.html) |
| Buff timers | A card that warns before a long buff runs out, with a countdown and a "has run out" state. Well-Rested and Well Fed are built in. | [Buff timers](api/buff-timers.html) |
| Click-to-cast overlays | A secure button over a card: click the card to cast. | [Overlays](api/overlays.html) |
| Options window and widgets | A sidebar window in the addon's skin, the shared Extras and Skin pages, toggles, sliders, cycles, key binders. | [Options](api/options.html) |
| Skins | The addon's class skin plus Blizzard and Flat, derived from it. | [Skins](api/skins.html) |
| Travel panel | The class's travel spells and the Hearthstone beside the Escape menu, plus an optional action row. | [Travel panel](api/travel.html) |
| Minimap button | A LibDataBroker launcher shown by LibDBIcon-1.0, so minimap addons collect it. Also in the addon compartment. | [Minimap button](api/minimap.html) |
| Buff key | One key that casts what a card asks for, then a group buff on the next party or raid member who needs it. | [Buff key](api/buff-key.html) |
| Shots | A hidden command that screenshots every options page and frame for the docs, and a script that crops them. | [Shots](api/shots.html) |
| Explanations in tooltips | Plain-word help on cards, overlays and travel rows while the player keeps the "Explain things" setting on. | [Cards](api/cards.html#setexplaintext) |

## Who uses it

All nine Bound addons embed it:

| Addon | Class | Slash command |
| --- | --- | --- |
| Lightbound | Paladin | `/lb` |
| Chronobound | Mage | `/cb` |
| Stormbound | Shaman | `/storm` |
| Packbound | Hunter | `/pack` |
| Spiritbound | Priest | `/spirit` |
| Felbound | Warlock | `/fel` |
| Dreambound | Druid | `/dream` |
| Ragebound | Warrior | `/rage` |
| Shadowbound | Rogue | `/shadow` |

Dreambound is the smallest and the cleanest example. The [guide](guide.html) walks through it file by file.

## License

LibBound is MIT licensed (`LICENSE` in the repository). The addons that embed it have their own licenses; Dreambound, for example, is GPL-3.0-or-later.

## How it is embedded

Each addon carries its own copy of LibBound in `Libs/LibBound` and loads it from its `.toc`, after LibStub:

```text
Libs\LibStub\LibStub.lua
Libs\LibBound\LibBound.xml

Core.lua
...
```

Where that copy comes from depends on the build:

- **Development.** `tools/sync-libbound.sh` in the addon copies `../LibBound` (the folder next to it in `Interface/AddOns`) into `Libs/LibBound`. That folder is not tracked by git. Run the script again after every LibBound change.
- **CurseForge releases.** The addon's `.pkgmeta` fetches LibBound as an external:

  ```yaml
  externals:
    Libs/LibBound:
      url: https://github.com/antnsn/LibBound
  ```

  LibBound's own `.pkgmeta` leaves out `README.md`, `CLAUDE.md`, `AGENTS.md`, `.beads`, `.luacheckrc` and `tools`, so only the library goes in.
- **GitHub release zips.** `wowbench pack` embeds `../LibBound` through `[[pack.embed]]` in the addon's `wowbench.toml`.

See [Testing and tools](testing.html) for the scripts.

## LibStub and the MINOR rule

Several Bound addons can be installed at once, each with its own copy of LibBound. LibStub keeps one: the copy with the highest `MINOR` number. `Core.lua` starts with:

```lua
local MAJOR, MINOR = "LibBound-1.0", 33   -- the current number is in Core.lua
local lib = LibStub:NewLibrary(MAJOR, MINOR)
```

{: .warning }
Bump `MINOR` in `Core.lua` with every behavior change. If two copies have the same number, the first one loaded wins, and an addon may run with old code.

### `lib.installing` and the load order

`LibBound.xml` loads the files in a fixed order:

```xml
<Script file="Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua"/>
<Script file="Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua"/>
<Script file="Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua"/>
<Script file="Core.lua"/>
<Script file="Skin.lua"/>
<Script file="Card.lua"/>
<Script file="Options.lua"/>
<Script file="Minimap.lua"/>
<Script file="Travel.lua"/>
<Script file="Shots.lua"/>
<Script file="BuffKey.lua"/>
<Script file="BuffTimer.lua"/> <!-- last: it ends the install (lib.installing) -->
```

How a copy decides whether to install:

1. `Core.lua` calls `LibStub:NewLibrary`. When this copy is newer than the one already loaded (or the first), it gets the library table and sets `lib.installing = MINOR`. When it is older or equal, it gets `nil`, clears `installing` on the current copy and returns.
2. Every other file starts with:

   ```lua
   local lib = LibStub("LibBound-1.0")
   if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)
   ```

   So a losing copy defines nothing.
3. `BuffTimer.lua`, the last file, ends with `lib.installing = nil`.

A new LibBound file goes before `BuffTimer.lua` in `LibBound.xml`. `tools/sync-libbound.sh` copies every `*.lua` file, so it needs no change.

{: .note }
The `ns` functions are closures made when an addon calls `NewAddon` and the `Install*` functions. An addon that runs those before a newer copy of LibBound has loaded keeps the functions of the older copy for that session. The `MINOR` rule makes sure the newest copy is the one later calls get.

The three minimap libraries are LibStub libraries too, so the newest copy of each wins the same way.
