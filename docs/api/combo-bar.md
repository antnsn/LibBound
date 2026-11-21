---
title: Combo bar
parent: API reference
nav_order: 11
description: Bound.InstallComboBar, the combo point bar with its options page, and make_combo_media.py (ComboBar.lua).
---

# Combo bar
{: .no_toc }

`ComboBar.lua`: five pips, one lit with a glow for each combo point on the target, greyed out for the rest. Shadowbound shows it always, Dreambound in Cat Form only.

1. TOC
{:toc}

## Bound.InstallComboBar

```lua
Bound.InstallComboBar(ns, {
	glow = { r, g, b, a },                 -- the glow's colour (default white)
	active = function() return true end,   -- optional: when the bar may show at all
	about = "…",                           -- optional: the line under the page title
})
```

Call it from `Options.lua`, where its page should go among the addon's own pages: it appends a **Combo points** page to `ns.optionPages`. It also adds a module (the bar) and fills in its settings in `ns.defaults` unless the addon set them:

| Setting | Default | What it does |
| --- | --- | --- |
| `comboBar` | `true` | Show the bar. |
| `comboPulse` | `true` | Flash a few times on reaching 5 points. |
| `comboAlways` | `false` | Also show it out of combat with no points (still only while `active`). |
| `cpPoint` | `CENTER`, 0, -180 | Its place (movable, resizable: `ns.MakeMovable`). |

Dreambound's `active`, Cat Form only:

```lua
active = function() -- Cat Form runs on energy; caster form on mana, Bear Form on rage
	local t = UnitPowerType("player")
	return not ns.IsSecret(t) and t == 3
end,
```

## What the player sees

- Shown while there are points, or in combat, or always if `comboAlways`; never while `active` is false.
- Points the addon can't read (a secret value), or an `active` that errors, hide the bar.
- On reaching 5 the pips flash for about a second, once each time.
- While the frames are unlocked, the bar shows with three pips lit, to be placed.

The frame is `<Addon>ComboFrame`; `bar.pips[i]` are its textures (`pip.lit`, `pip.glow`), `bar.pulse` the flash. `Bound.ComboPoints()` (also `ns.ComboPoints`) returns the points on the target, or nil when unreadable.

## Media

The bar uses `Media/ComboPoint` and `Media/ComboGlow` from the addon's folder. Make both from a painted pip on a transparent background:

```sh
python3 ../LibBound/tools/make_combo_media.py ComboPoint.png Media
```

`ComboPoint.tga` is the art trimmed and centred on a 64×64 square. `ComboGlow.tga` is its outline grown and blurred, white on alpha; the game tints it with `glow` and adds it behind a lit pip, at 1/0.6 of the pip's size.
