---
title: Options
parent: API reference
nav_order: 5
description: Bound.InstallOptions, option pages and the UI widgets (Options.lua).
---

# Options
{: .no_toc }

`Options.lua`: the options window, a sidebar with one page per feature, in the active skin. Taken from Lightbound's `Options.lua`.

1. TOC
{:toc}

The header comment:

```lua
-- Addons add pages with
--   ns.optionPages[#ns.optionPages + 1] = function(UI) local p = UI.NewPage("Title", "sub") ... end
-- Widgets return (widget, height); add the height with p:Add(h). UI.CONTENT_W is the usable width.
-- LibBound adds the shared pages itself: "Extras" (buff key, Well Rested, Well Fed,
-- Carrot on a Stick, then the addon's own extras) and "Skin" (the skin, explanations, the minimap button). lib.InstallOptions(ns, { header = "Mage helper", launcher = "one line for Settings",
--   extras = function(UI, page, width) end -- more sections on the Extras page })
```

The widgets (`ns.UI.NewPage`, `DBToggle` and the rest) are installed by `Bound.InstallSkin` (it calls `lib.InstallWidgets(ns)`). The window itself by `Bound.InstallOptions`.

## Bound.InstallOptions

```lua
Bound.InstallOptions(ns, cfg)
```

| Field | What it is |
| --- | --- |
| `cfg.header` | Text in the window header, next to the logo. Default: the addon's title. |
| `cfg.launcher` | One line for the launcher in the game's Settings > AddOns list. `Type /cmd in chat to open the options.` is added. |
| `cfg.extras` | `function(UI, page, width)`: more sections at the bottom of the shared Extras page. The page is 494 px high and the shared sections use most of it: keep an extra to a row or two. |

Call it last, after every file has added its pages. It defines `ns.ToggleOptions()` and registers the Settings launcher. The window is built the first time it opens.

### The window

- 760 x 620, named `<Addon>Options`, strata `DIALOG`, movable by its header, closed by Escape.
- Header: the logo (`Logo64`, through `ns.SetEmblem`), `cfg.header`, the version from the `.toc`.
- Sidebar: one button per page, in this order: the addon's pages (`ns.optionPages`), then **Extras**, then **Skin**.
- Footer: **Unlock frames** / **Lock frames**, **Reset positions** and a hint. Frames unlocked from the window lock again when it closes.
- The skin's crest in the corner, or the faint emblem when the skin has no crest.
- The last page shown is saved in `ns.db.optionsPage`.
- On every open, every control's `Sync` runs, so widgets show the current settings.

### The shared pages

**Extras** ("Levelling helpers."):

- **Buff key**: a `KeyButton` for `ns.db.buffKey` (calls `ns.BindBuffKey()`), and a note.
- **Well-Rested** and **Well Fed**: a short note and a Test button on the section line; Warn, Sound, Countdown card and Rebuff warning (the `Keep` setting) in one row; Warn with time left (1 to 30 min).
- **Carrot on a Stick** (when `NewAddon` installed it): a cycle Off / Top trinket / Bottom trinket for `carrotSwap` and `carrotSlot`. See [Carrot on a Stick](carrot.html).
- Then `cfg.extras(UI, page, width)`.

**Skin** ("How <title>'s frames look. A new skin applies after a reload."):

- A `Cycle` over the skins in `UI.SkinOrder`, with each skin's one-line description, and **Reload now** once the choice differs from the running skin.
- **General**: "Explain things in tooltips" (`explain`) and "Minimap button" (`minimap`).

### ns.ToggleOptions

```lua
ns.ToggleOptions()
```

Opens or closes the window. Does nothing before `ns.db` exists. `/cmd` with no argument and a left click on the minimap button call it.

### ns.optionsState

The internal state, used by Shots and tests: `controls` (everything with a `Sync`), `pages` (`{ title, frame }` in sidebar order), `capturers` (key buttons), `win` (the window, once built) and `Select(i)` (show page `i`).

## Pages

```lua
ns.optionPages[#ns.optionPages + 1] = function(UI)
	local p = UI.NewPage("Buffs", "A card when a buff is missing or running out.")
	-- widgets
end
```

### UI.NewPage

```lua
local p = UI.NewPage(title, subtitle)
```

A page frame, `UI.CONTENT_W` wide, with the title and the subtitle at the top. `title` is also the sidebar label.

- `p.y`: the next free line, a negative offset from the top. Starts at `-58`, under the subtitle.
- `p:Add(h)`: moves `p.y` down by `h`.

### Layout

Each widget takes a `y` (pass `p.y`) and returns its height, or the widget and its height. Add the height, plus some space:

```lua
p:Add(UI.Section(p, p.y, "Reagents") + 2)                       -- returns a height only
p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "seeds", "Warn when seeds run low")) + 6)
p:Add(select(2, UI.Slider(p, p.y, "Seeds: warn at", "seedLow", 0, 10, 1, " left")) + 8)
```

Several toggles on one line: place them at `x = 0`, `third`, `third * 2` with the same `p.y`, then `p:Add(34)` once.

### UI.CONTENT_W

The usable page width: 538 pixels.

## Widgets

### UI.DBToggle

```lua
local row, h = UI.DBToggle(page, x, y, w, key, label, desc, onSet)
```

A checkbox bound to `ns.db[key]`. `desc` is an optional second line in dim text; `onSet(value)` runs after the setting changes. Height 40 with `desc`, else 26. A click plays the checkbox sound and calls `ns.Refresh()`.

### UI.Toggle

```lua
local row, h = UI.Toggle(page, x, y, w, label, desc, get, set)
```

The same with your own `get()` and `set(value)`, for a value that isn't a plain setting.

### UI.Slider

```lua
local slider, h = UI.Slider(page, y, label, key, minV, maxV, step, suffix)
```

A full-width slider bound to `ns.db[key]`, the label on the left and the value plus `suffix` on the right. The mouse wheel steps it. A change calls `ns.Refresh()`. Height 46.

### UI.Cycle

```lua
local button, h = UI.Cycle(page, y, label, values, get, set, note, labelColor)
```

A `Label   < Value >` selector: left-click picks the next value in `values`, right-click the previous. `get()` returns the current value (shown as `None` when `nil`), `set(value)` stores it. `note` is an optional function returning a dim line under the label. `labelColor` is an optional color table. Height 34.

### UI.Section

```lua
local h = UI.Section(page, y, text)
```

A section heading: `text` in upper case in the accent color, with a line under it. Returns only the height, 26.

### UI.Note

```lua
local h = UI.Note(page, y, text)
```

Dim text across the page, wrapped. Returns its height (at least 18).

### UI.KeyButton

```lua
local keyButton, h = UI.KeyButton(page, y, label, dbKey, onSet, what)
```

```lua
-- Key binder: label, the key button and a Clear button. Click, then press a key (Esc cancels);
-- the combo goes to ns.db[dbKey] and onSet(combo or nil) runs. `what` names it in chat. Height 40.
```

The combo is written as `ALT-CTRL-SHIFT-KEY`. A capture refuses to start in combat, and ends when the page or the window hides.

### UI.Button

```lua
local button = UI.Button(parent, text, w, h)
```

A button in the skin (the game's panel button, or a flat one in a flat skin). `h` defaults to 24. `button:SetLabel(text)` changes the text.

### UI.Syncer

```lua
local row = UI.Syncer(fn)
```

A control with only a `Sync`: `fn` runs whenever the window opens. For page parts with their own state.

## Extras example

An addon adds its own section to the Extras page:

```lua
local function Extra(UI, p, W)
	p:Add(UI.Section(p, p.y - 4, "Something") + 2)
	-- ...
end

Bound.InstallOptions(ns, {
	header = "Paladin buffs",
	launcher = "Paladin buffing and self-buff helper.",
	extras = Extra,
})
```

Lightbound also puts its own pages before any that other files added, with `table.insert(ns.optionPages, i, build)`.
