---
title: Cards
parent: API reference
nav_order: 2
description: ns.MakeCard and the card methods (Card.lua).
---

# Cards
{: .no_toc }

`Card.lua`: the one look for reminders. `ns.MakeCard` exists after `Bound.InstallSkin(ns, ...)`, which calls `lib.InstallCards(ns)`.

1. TOC
{:toc}

The header comment:

```lua
-- LibBound cards: the one look for reminders (a buff that is missing or running out, water to
-- conjure...). The spell icon on a dark panel with a double rule, dressed by the skin:
--   burst   = "Sunburst"  a light behind the icon that turns slowly and breathes (Lightbound)
--   ring    = "Ring"      a ring around a round icon;  round = true masks the icon round
--   studs   = "Stud"      ornaments in the corners
--   frost   = "Frost"     a frosted-glass layer over the panel (Chronobound)
--   shards  = "Shard"     crystal shards cut into the corners
--   crest   = "Crest"     a large faint class motif behind the right side, cut off by the edge
--                         (crestTint = { r, g, b, a }); also in the options window and travel panel
--   breathe = true        the edge itself breathes while the card glows
-- Texture names are files in the addon's Media folder. Quiet on purpose: no flicker, no swelling.
-- card:SetIcon(tex), SetTitle(text), SetStatus(text, urgent), SetFaded(on), Glow(on), SetExplain(text)
-- ns.MakeCard(name, { width = 230, clickable = false }): clickable cards take clicks while locked
-- (the addon sets OnMouseUp); other cards only take mouse-over, so the world under them stays clickable
```

## ns.MakeCard

```lua
local card = ns.MakeCard(name, opts)
```

| Parameter | What it is |
| --- | --- |
| `name` | The frame's global name, e.g. `"DreamboundReagentsFrame"`. |
| `opts.width` | Width in pixels. Default 230. The height is always 56, the icon 34. |
| `opts.clickable` | `true`: the card takes mouse clicks even while locked. The addon sets its own `OnMouseUp`. Default `false`. |

**Returns** a `Frame` on `UIParent`, strata `LOW`, hidden. It is not secure, so it can show and hide in combat. To cast on click, lay an [overlay](overlays.html) over it.

Make cards in a module's `Init`, then `ns.MakeMovable(card, key)` and `ns.ApplyPoint(card, key)`.

## Card methods

### SetIcon(tex)

```lua
card:SetIcon(tex)
```

The icon texture: a file ID or path.

### SetTitle(text)

```lua
card:SetTitle(text)
```

The title line, in the skin's `card` font and `card.title` color. `nil` clears it.

### SetStatus(text, urgent)

```lua
card:SetStatus(text, urgent)
```

The line under the title. `urgent = true` uses the skin's `card.urgent` color (red in every skin), else `card.status`.

### SetFaded(on)

```lua
card:SetFaded(on)
```

Desaturates the icon and dims the light behind it. Buff timers use it for the "has run out" state.

### Glow(on)

```lua
card:Glow(on)
```

Turns the card's "needs you" look on or off. With a `burst` skin the light behind the icon turns and breathes; with `breathe` the rim breathes; with neither, the outer edge takes the skin's `card.glowEdge` color. A faded card does not animate.

### SetExplain(text)

```lua
card:SetExplain(text)
```

A plain-word explanation in the card's tooltip, shown while `ns.db.explain` is on and the frames are locked. The card then takes mouse-over but not clicks (unless it is `clickable`), so the world under it stays clickable. `nil` turns mouse-over off again. The tooltip shows the title, then the text.

## Fields

| Field | What it is |
| --- | --- |
| `card.icon`, `card.titleText`, `card.statusText` | The icon texture and the two font strings. |
| `card.clickable` | From `opts.clickable`. |
| `card.explain` | The text from `SetExplain`. |
| `card.IsGlowing()`, `card.IsFaded()` | The current state. Plain functions: call with `.`, not `:`. |

## The skin's card section

Every color and texture comes from the active skin's `card` table. The fields `Card.lua` reads:

| Field | What it does |
| --- | --- |
| `panel` | The panel color. |
| `gilt` | The outer edge color. |
| `giltFaint` | The inner rule color. |
| `light` | Light from above (a gradient over the top 60%). |
| `rays`, `raysFaded` | Color of the burst and the rim, normal and faded. |
| `title`, `status`, `urgent` | Text colors. |
| `glowEdge` | The edge color while glowing, for a skin without `burst` or `breathe`. |
| `iconEdge` | The 1 px frame around a square icon. Default black. |
| `burst`, `spin` | Texture of the light behind the icon, and its turn time in seconds (default 90). |
| `ring`, `round` | A ring texture around the icon; `round = true` masks the icon round with `Media/RoundMask`. |
| `studs` | Corner ornament texture (9 px). |
| `frost`, `frostTint` | A tiled texture over the panel and its tint. |
| `shards`, `shardTint` | Corner texture (12 px) pointing into the top-left corner, mirrored for the others. |
| `crest`, `crestTint` | A large faint motif behind the right side, set with `ns.SetEmblem`. |
| `breathe`, `rim`, `breatheTime` | A breathing rim while glowing, its texture (else a plain color) and its period (default 2.5 s). |

Set a texture field to `false` to leave the part out. See [Skins](skins.html).
