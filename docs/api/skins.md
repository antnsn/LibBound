---
title: Skins
parent: API reference
nav_order: 6
description: Bound.InstallSkin, the skin table and the ns.UI helpers (Skin.lua).
---

# Skins
{: .no_toc }

`Skin.lua`: every color, font, border and texture the frames use comes from the active skin, through `ns.UI`.

1. TOC
{:toc}

The header comment:

```lua
-- Each addon brings its own class skin (Lightbound's gold, Chronobound's
-- frost); LibBound derives the neutral "Blizzard" and "Flat" skins from it, so every addon offers
-- the same three kinds. Values are looked up when a frame is built: a skin change needs a reload.
--
-- lib.InstallSkin(ns, { skins = { key = skinTable, ... }, order = { "frost", "blizzard", "flat" },
--   default = "frost", about = { key = "one line for the picker" } })
-- A skin table has the sections font, color, box, dialog, tex, card, widgets (see the class skins
-- for every field). Texture names in `card` are file names in the addon's Media folder.
```

## Bound.InstallSkin

```lua
Bound.InstallSkin(ns, opts)
```

| Field | What it is |
| --- | --- |
| `opts.skins` | `key -> skin table`. Usually only the class skin. |
| `opts.default` | The key of the class skin. Blizzard and Flat are derived from it. |
| `opts.order` | The order in the Skin page's picker. Default `{ default, "blizzard", "flat" }`. |
| `opts.about` | `key -> one line` shown under the picker. Blizzard and Flat have their own. |

It sets `ns.UI`, then calls `lib.InstallWidgets(ns)` (the option widgets) and `lib.InstallCards(ns)` (`ns.MakeCard`). Call it right after `NewAddon`, before anything that builds frames or option pages.

A skin under the key `blizzard` or `flat` in `opts.skins` replaces the derived one.

### The active skin

The skin is `ns.db.skin` if that key exists, else the default. It is fixed for the session the first time it is read after the saved settings are in, so frames built later never mix two skins. Picking another skin on the Skin page takes effect at the next reload. Before `ns.db` exists, `Active()` returns the default skin.

## The skin table

A skin has these sections. Dreambound's `Skin.lua` is a complete example.

### name

The name in the picker: `"Dream"`.

### font

Font paths per role: `ui`, `title`, `narrow`, `card`. `lib.FONTS` has three:

```lua
lib.FONTS = { friz = "Fonts\\FRIZQT__.TTF", arialn = "Fonts\\ARIALN.TTF", morpheus = "Fonts\\MORPHEUS.TTF" }
```

### color

Color tables `{ r, g, b[, a] }`. The keys the class skins set:

| Key | Used for |
| --- | --- |
| `bg` | Background. |
| `side`, `header` | The options sidebar and the header and footer bars. |
| `border` | Borders and section lines. |
| `hover`, `selected` | Button hover; a selected row. |
| `text`, `dim`, `accent` | Normal text, quiet text, headings and values. |
| `track`, `button` | Slider track in a flat skin; button background. |
| `navGlow` | The selected page in the sidebar. |
| `row`, `rowWarn`, `rowBad`, `cell` | Rows and cells in addon windows. |
| `highlight` | Mouse-over highlight. |
| `cdText`, `glow` | Cooldown text; glow color. |
| `gridLine`, `gridCentre` | The grid lines and its center lines while frames are unlocked. |

### box

The backdrop for small frames (the grid bar, the travel panel): `backdrop` (a backdrop table), `bg` (color), `border` (color).

### dialog

The frame around the options window: `backdrop`, `outset` (pixels outside the window), `bg` (optional), `border` (optional), `under` (color under the backdrop), `plate` (a title plate texture, or `false`).

### tex

Widget textures. Class skins use the game's own:

```lua
tex = Bound.STOCK_TEX,
-- check, checkMark, checkHighlight, slider (a backdrop), sliderThumb, navHighlight, statusbar
```

### card

The card look. Every field is on the [Cards](cards.html#the-skins-card-section) page.

### widgets

`"blizzard"` (the game's checkboxes and buttons) or `"flat"` (drawn boxes, 1 px borders). `UI.IsFlat()` reads it.

## The derived skins

- **Blizzard**: the game's gray and silver tooltip and dialog frames, Friz Quadrata, white text, gold accent, no card ornaments.
- **Flat**: 1 px black edges on dark gray, Arial Narrow, the class skin's accent kept, no card ornaments, flat widgets.

Both start from the class skin through `lib.DeriveSkin(base, over)`: a copy of `base` with `over`'s values replacing its own, merging nested tables (but not lists), so no key is missing. Use it for your own variants.

{: .note }
Colors that carry meaning stay the same in every skin: red for missing or running low.

## ns.UI

| Field | What it is |
| --- | --- |
| `C`, `F`, `CARD`, `TEX` | Views of the active skin's `color`, `font`, `card` and `tex`: `UI.C.accent` reads the active skin's value. |
| `MEDIA` | `ns.MEDIA`. |
| `Active()` | The active skin table. |
| `Skins`, `SkinOrder`, `SkinAbout`, `DefaultSkin` | Every skin, the picker order, the descriptions, the default key. |
| `IsFlat()` | `true` for a flat skin. |
| `Tex(parent, layer, color)` | A solid color texture. |
| `Border(frame, color)` | A 1 px border (default `C.border`). |
| `SetFont(fontString, role, size, flags)` | Sets a role's font; returns what `SetFont` returned. |
| `Font(parent, size, color, layer)` | A left-aligned font string in the `ui` font, one point smaller than `size`. |
| `Title(parent, size, color)` | A font string in the `title` font with a shadow, default accent color. |
| `Hex(color)` | The color as a chat color escape, for chat lines and font strings. |
| `Skin(frame, titleText, onClose)` | The dialog frame around `frame`, the title plate and a close button. |
| `Watermark(parent, size, alpha)` | The faint emblem (`Logo256`). |
| `Crest(parent, size, alphaScale)` | The skin's crest in the bottom-right corner, or `nil` when the skin has none. |
| `Box(frame, alpha)` | The `box` backdrop on a `BackdropTemplate` frame. |
| `FrameTitle(frame)` | A small title font string. |
| `RowBg(row)` | A `C.row` background. |
| `Highlight(frame, alpha)` | A mouse-over highlight texture. |
| `IconBorder(frame)` | A black 1 px frame around an icon, in flat skins only. |

The option widgets (`NewPage`, `DBToggle`, ...) are added to `ns.UI` too. See [Options](options.html).
