---
title: Cleanse
parent: API reference
nav_order: 17
description: A grid (or list) of the group showing who has a debuff the class can remove, a click per spell and a mouseover key each (Cleanse.lua).
---

# Cleanse
{: .no_toc }

`Cleanse.lua`: the group as a grid of small cells, like Decursive, or as a list. A cell lights up when its player has a debuff the class can remove. Click a cell to cast, or use a mouseover key per spell. It was moved here from Lightbound, with the same settings (`cl*`), so a paladin's settings carry over. Lightbound (Cleanse) and Spiritbound (Dispel) use it.

1. TOC
{:toc}

## Turning it on

Call it from one of the addon's files:

```lua
Bound.InstallCleanse(ns, {
	title = "Dispel",
	buttons = {
		{ list = { 527, 988 }, types = { Magic = true } },   -- left click, key clKey
		{ list = { 528, 552 }, types = { Disease = true } }, -- right click, key clKey2
	},
	page = false, -- optional: put ns.CleansePage into ns.optionPages yourself
})
```

| Field | What it is |
| --- | --- |
| `title` | The frame title and the options page title. Default `Cleanse`. |
| `buttons` | Up to three spells: left click, right click, middle click, each with a key (`clKey`, `clKey2`, `clKey3`). |
| `buttons[i].list` | Spell IDs, lowest first. The best one known (`ns.BestRank`) is cast, by name, so a later spell in the list (Abolish Disease after Cure Disease) replaces an earlier one. |
| `buttons[i].types` | The dispel types it removes: `Magic`, `Curse`, `Disease`, `Poison`. Or one set per entry of `list`, e.g. Purify then Cleanse. |
| `page` | Without it, the page goes into `ns.optionPages` when this is called, so the file's place in the `.toc` is the page's place. With `false` it is `ns.CleansePage`. |

The frame appears once one of the spells is known. `/<slash> ignore <debuff>` (and `/<slash>ignore`) toggles a debuff the frame leaves alone.

## Per class

| Class | Left | Right |
| --- | --- | --- |
| Paladin (Lightbound) | Purify 1152 (Poison, Disease), then Cleanse 4987 (and Magic) | |
| Priest (Spiritbound) | Dispel Magic 527, 988 (Magic) | Cure Disease 528, then Abolish Disease 552 (Disease) |
| Druid | Remove Curse 2782 (Curse) | Cure Poison 8946, then Abolish Poison 2893 (Poison) |
| Mage | Remove Lesser Curse 475 (Curse) | |
| Shaman | Cure Poison 526 (Poison) | Cure Disease 2870 (Disease) |

The druid, mage and shaman rows are not wired in yet. Check the IDs on Forever when they are.

## How it works

- **Grid:** two SecureGroupHeaders (players and pets) create the cells and give them their unit, in combat too, so joins, leaves and raid moves never leave a cell on the wrong person. Every cell gets `type1`/`spell1`, `type2`/`spell2`, and so on. A click casts on the cell's unit whether or not it is lit, because in combat the addon may not see what the game hides.
- **Debuff look:** each cell carries a native AuraContainer filtered to the class's dispel types. Blizzard draws the colour, icon and stacks, so it keeps working while aura data is secret. Lua paints only what stays readable: names, range and dead alpha, and the "most debuffs" border. If AuraContainer is missing, the cells fall back to the Lua scan.
- **List:** rows are mapped out of combat, afflicted players first. The mapping is frozen in combat.
- **Keys:** `/cast [@mouseover,help,nodead][help,nodead] <spell>` on hidden secure buttons named `<Addon>CleanseKeyButton`, `<Addon>CleanseKeyButton2` and so on, as override bindings.
- **Layout** changes wait for the end of combat.
- **The page** has no room to spare: pages don't scroll, and two keys plus the ignore list just fit. The scenarios check `page.cleanseBottom` against the page height.

## Settings

`lib.CLEANSE_DEFAULTS`, added to the addon's defaults where it has none: `clEnabled`, `clSolo`, `clSound`, `clRows`, `clPets`, `clIgnore`, `clMode` (`Grid`/`List`), `clPerRow`, `clCell`, `clNames`, `clRange`, `clPoint`. The keys `clKey`, `clKey2` and `clKey3` default to none. `clIgnoreIDs` is learned: it holds the spell IDs of ignored debuffs, for the native cells' filter.
