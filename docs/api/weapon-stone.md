---
title: Weapon stone
parent: API reference
nav_order: 18
description: A card when the main hand has no stone or oil; a click uses the best one in the bags (WeaponStone.lua).
---

# Weapon stone
{: .no_toc }

`WeaponStone.lua`: a card when the main-hand weapon has no temporary enchant. A click (out of combat) uses the best fitting item in the bags on it. Moved here from Ragebound with the same settings, so a warrior's settings carry over. Ragebound (stones) and Lightbound (stones and oils) use it. Since MINOR 40.

## Install

```lua
-- from one of the addon's files
LibStub("LibBound-1.0").InstallWeaponStone(ns, { oils = true }) -- oils: optional

-- on one of its option pages
ns.WeaponStoneOptions(page, UI)
```

| cfg | What it does |
| --- | --- |
| `oils` | The player may pick Wizard Oil or Mana Oil instead of a stone (a "Put on" choice on the page). Without it the card only uses stones. |

## What it uses

| `stKind` | Item | Weapons |
| --- | --- | --- |
| `Stone` | Sharpening stone: axes, swords, daggers, polearms, fist weapons. Weighted stone: maces, staves. | those listed |
| `Wizard Oil` | Minor, Lesser, Wizard Oil, Brilliant | any weapon but fishing poles and miscellaneous |
| `Mana Oil` | Minor, Lesser, Brilliant | the same |

The best item the player's level allows is picked (the item lists are in `lib.WEAPON_ITEMS`, lowest first). Without one in the bags the card says so and takes no click. It hides in combat.

## Settings

`lib.WEAPON_STONE_DEFAULTS`, added to `ns.defaults` unless the addon set them:

| Key | Default | |
| --- | --- | --- |
| `stone` | `false` | the card on or off |
| `stKind` | `"Stone"` | `"Stone"`, `"Wizard Oil"` or `"Mana Oil"` (only `"Stone"` counts without `oils`) |
| `stPoint` | right of the screen centre | the card's place |

## Functions

| | |
| --- | --- |
| `ns.StoneKind()` | the item list the main hand takes now (`"sharpening"`, `"weighted"`, `"wizard"`, `"mana"`), or nil |
| `ns.BestStone(list)` | item ID and name of the best usable item of that list in the bags, or nil |
| `ns.WeaponStoneOptions(page, UI)` | adds the section (toggle, and the kind choice with `oils`) to a page |

The card frame is named `<Addon>StoneFrame`.
