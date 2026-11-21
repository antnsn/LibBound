---
title: Power bar
parent: API reference
nav_order: 12
description: Bound.InstallPowerBar, the rage (or energy) bar with its options page, its looks, and make_bar_media.py (PowerBar.lua).
---

# Power bar
{: .no_toc }

`PowerBar.lua`: a resource bar from layered painted art, filled to the player's rage (or another power), with the number on it, a glowing line at the fill's end and a glow round the bar when full. Ragebound shows it always, Dreambound in Bear Form.

1. TOC
{:toc}

## Bound.InstallPowerBar

```lua
Bound.InstallPowerBar(ns, {
	power = 1,                              -- Enum.PowerType: 1 rage, 3 energy
	title = "Rage bar",                     -- the options page (and "Show the rage bar")
	noun = "rage",                          -- for the page's texts
	active = function() return true end,    -- optional: when the bar may show at all
	overlay = true,                         -- optional: <prefix>Overlay on top (Dreambound's claws)
	prefix = "RageBar",                     -- media names
	fill = { 112, 44, 990, 84 }, canvas = { 1024, 128 }, -- the fill's box on the art's canvas
	color = { r, g, b },                    -- the fill in the Blizzard and Flat skins
	about = "…",                            -- optional: the line under the page title
})
```

Call it from `Options.lua`, where its page should go among the addon's own pages: it appends the page to `ns.optionPages`, adds a module and fills in its settings in `ns.defaults` unless the addon set them:

| Setting | Default | What it does |
| --- | --- | --- |
| `powerBar` | `true` | Show the bar. |
| `powerVertical` | `false` | Stand it up: the art turned a quarter left (its left end at the bottom), the fill growing upward. Takes effect at once. |
| `powerNumber` | `true` | The number on the bar. |
| `powerAlways` | `false` | Also show it out of combat with nothing in it (still only while `active`). |
| `pbPoint` | `CENTER`, 0, -230 | Its place (movable, resizable). |

## What the player sees

- Shown while there is any of the power, or in combat, or always if `powerAlways`; never while `active` is false.
- The line at the fill's end shows between empty and full; the full glow at the maximum.
- A secret value (Forever hides some combat values) still fills the bar and shows its number: `StatusBar:SetValue` and `FontString:SetText` take it as it is. Only the full glow, which needs a comparison, stays off then.
- While the frames are unlocked the bar shows at 60, to be placed.

The frame is `<Addon>PowerBar`; `bar.status` is its `StatusBar`, `bar.spark`, `bar.full`, `bar.text` and `bar.overlay` its parts, `bar.vertical` and `bar.look` its state.

## Looks

``Bound.BarLook(ns)` (`lib.BarLook`, in `ComboBar.lua`, shared with the combo bar) reads the skin, which is fixed until a reload:

| Skin | Look |
| --- | --- |
| The addon's own | `painted`: the layered art. |
| Blizzard | `blizzard`: a plain bar, the game's bar texture (`UI-StatusBar`) in `color`, a grey 1px edge, the casting bar's spark. |
| Flat | `flat`: a plain bar in flat `color`, a black 1px edge. |

The combo bar follows the same rule: painted pips in the addon's skin, plain squares in its `glow` colour otherwise.

## Media

Marius' layers, all on one canvas (1024×128; the spark 64×128): `rage-bar-empty.png` (frame and dark inside), `rage-bar-fill.png` (the fill at 100%, alone), `rage-bar-frame.png` (the frame, open inside, drawn over the fill), `rage-bar-full.png` (the glow at full), `rage-bar-spark.png`. Make the textures with:

```sh
python3 ../LibBound/tools/make_bar_media.py art/rage-bar Media [--prefix RageBar] [--overlay art/rage-bar/bear-claws.png]
```

It writes `<prefix>Back`, `Frame`, `Full`, `Spark` (and `Overlay`) at the canvas size, and `<prefix>Fill` cut to the fill's own box, and prints that box: pass it as `fill` if it differs from the default.
