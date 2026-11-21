---
title: Build a Bound addon
nav_order: 2
description: A new Bound addon step by step, with Dreambound as the worked example.
---

# Build a Bound addon
{: .no_toc }

This guide builds a class addon on LibBound, step by step. The worked example is Dreambound, the druid addon: it is the smallest of the seven and uses every part of LibBound that a new addon needs. Read its source next to this page.

1. TOC
{:toc}

## 1. The folder

A Bound addon is a folder in `Interface/AddOns`, next to `LibBound`. Dreambound's:

```text
Dreambound/
  Dreambound.toc      the addon's table of contents
  Core.lua            ns.DATA, defaults, Bound:NewAddon
  Skin.lua            the class skin; installs skins, buff timers, the minimap button
  Help.lua            every plain-word explanation (ns.Help)
  Buffs.lua           buff cards (ns.MakeBuffTimer) and group buffs (ns.groupBuffs)
  Reagents.lua        a custom card (ns.MakeCard)
  Travel.lua          the travel panel (Bound.InstallTravel)
  Options.lua         option pages, then Bound.InstallOptions
  Media/              textures (TGA): Logo64, Logo256, Icon64, Icon128, Crest, card textures
  Libs/LibStub/       LibStub (tracked)
  Libs/LibBound/      LibBound (not tracked: tools/sync-libbound.sh, .pkgmeta, wowbench pack)
  tests/              wowbench scenarios
  tools/              sync-libbound.sh, sync_curseforge.py, make_media.py
  docs/               the player docs site
  CHANGELOG.md        release notes
  CURSEFORGE.md       the CurseForge project page
  .pkgmeta            CurseForge packaging
  wowbench.toml       wowbench settings
  .luacheckrc
```

Anything every Bound addon needs belongs in LibBound, not in the addon.

## 2. The .toc

```text
## Interface: 16001
## Title: Dreambound
## Notes: Druid helper: Mark of the Wild, Thorns and Omen of Clarity reminders (click to cast), ...
## X-License: GPL-3.0-or-later
## Author: Rheolux
## Version: @project-version@
## IconTexture: Interface\AddOns\Dreambound\Media\Icon64
## SavedVariables: DreamboundDB

Libs\LibStub\LibStub.lua
Libs\LibBound\LibBound.xml

Core.lua
Skin.lua
Help.lua
Buffs.lua
Reagents.lua
Travel.lua
Options.lua
```

Rules for the order:

- LibStub, then `LibBound.xml`, then the addon's files.
- `Core.lua` first: it calls `NewAddon`, which every other file needs.
- `Skin.lua` next: `InstallSkin` creates `ns.UI`, the widgets and `ns.MakeCard`; it also installs the buff timers and the minimap button.
- `Help.lua` before the files that read `ns.Help` when they load.
- `Options.lua` last: `InstallOptions` reads `ns.UI` and collects the pages the other files added.

The `## SavedVariables:` line must name the same table as `cfg.db`. `tools/crop_shots.py` reads it from the `.toc` too.

## 3. Core.lua and NewAddon

`Core.lua` holds the addon's data and defaults and calls `NewAddon`. Dreambound's, shortened:

```lua
local addonName, ns = ...
local Bound = LibStub("LibBound-1.0")

-- Spells and items, lowest rank first. Classic IDs; Forever follows Classic content.
ns.DATA = {
	markOfTheWild = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 },
	giftOfTheWild = { 21849, 21850 },
	thorns = { 467, 782, 1075, 8914, 9756, 9910 },
	omenOfClarity = { 16864 },
	moonglade = 18960, travelForm = 783, aquaticForm = 1066,
	-- ...
}

local defaults = {
	skin = "dream",
	giftReagent = true, giftLow = 5, seeds = true, seedLow = 1,
	rgPoint = { "CENTER", "UIParent", "CENTER", 250, 200 },
	wrPoint = { "CENTER", "UIParent", "CENTER", 0, 320 },
	wfPoint = { "CENTER", "UIParent", "CENTER", 0, 260 },
	-- plus one block per buff card, see below
}

ns.disabled = Bound:NewAddon(addonName, ns, {
	class = "DRUID",
	title = "Dreambound",
	prefix = "9fe8c0",
	db = "DreamboundDB",
	slash = { "/dream", "/dreambound" },
	media = "Interface\\AddOns\\Dreambound\\Media\\",
	defaults = defaults,
})
```

### `ns.DATA`

`ns.DATA` is a convention, not something LibBound reads. Keep every spell and item ID in it, rank lists lowest rank first, so `ns.BestRank(list)` can pick the highest known rank. The Bound addons use Classic IDs and check them in game before each release.

### The cfg fields

Every field `NewAddon` reads:

| Field | Required | What it is |
| --- | --- | --- |
| `class` | no | Class file name (`"DRUID"`). On another class the addon loads nothing. `nil`: every class. |
| `className` | no | The class name in the wrong-class messages. Default: `class` with only the first letter upper case (`"Druid"`). |
| `title` | no | Shown in chat, windows and tooltips. Default: `addonName`. |
| `prefix` | no | Hex color of the chat prefix. Default `"ffd100"`. |
| `db` | yes | The SavedVariables name, the same as the `.toc` line. |
| `defaults` | no | The addon's defaults, merged over `lib.SHARED_DEFAULTS`. |
| `slash` | yes | Slash commands; the first one is the main one and the base of the space-free aliases. |
| `commands` | no | Extra sub-commands: `name = { fn = function(arg) end, help = "..." }`. |
| `media` | yes in practice | Path of the Media folder, ending in `\\`. Emblems, the minimap icon and card textures are read from it. |
| `migrate` | no | `function(db, defaults)`, run after the defaults are in. |
| `buffKey` | no | LibBound 19 and later: `buffKey = false` in the NewAddon config turns the shared buff key off. For an addon with its own, like Lightbound. |

`NewAddon` returns `true` on the wrong class. Store that in `ns.disabled` and start every other file with:

```lua
local _, ns = ...
if ns.disabled then return end
```

On the wrong class, the slash command only says why, and the addon is turned off for that character from the next login. See [Core](api/core.html#newaddon) for the details.

### Defaults

Each setting needs a default; the loader copies missing ones into the saved table on `ADDON_LOADED`. Frame positions are keys ending in `Point`, with a `{ point, "UIParent", relativePoint, x, y }` value: `ns.ResetPositions()` puts every `*Point` key back to its default.

Put `skin = "<your skin key>"` in the defaults. The Skin page and `crop_shots.py` both use it.

A buff timer needs five settings and a position. Dreambound builds them in a loop:

```lua
local function Timer(key, x, y, keep)
	return key, true, key .. "Minutes", 2, key .. "Sound", false, key .. "Icon", true, key .. "Keep", keep,
		key .. "Point", { "CENTER", "UIParent", "CENTER", x, y }
end
for _, t in ipairs({ { "markOfTheWild", -250, 200, true }, { "thorns", -250, 140, true },
	{ "omenOfClarity", -250, 80, true } }) do
	local kv = { Timer(t[1], t[2], t[3], t[4]) }
	for i = 1, #kv, 2 do defaults[kv[i]] = kv[i + 1] end
end
```

### Optional: an emblem variant

Spiritbound defines `ns.EmblemVariant()` before `NewAddon`. It returns a file-name suffix (`"Shadow"`) or `nil`, and the logo, watermark, minimap icon and crest switch to the `...Shadow` files when it changes. See [Core](api/core.html#emblems-nssetemblem-and-nsemblemvariant).

## 4. Skin.lua

The skin is a table with the sections `name`, `font`, `color`, `box`, `dialog`, `tex`, `card` and `widgets`. Copy Dreambound's `Skin.lua` and change the values. Then install it, and with it the buff timers and the minimap button:

```lua
local _, ns = ...
if ns.disabled then return end
local Bound = LibStub("LibBound-1.0")
local F = Bound.FONTS

local dream = {
	name = "Dream",
	font = { ui = F.friz, title = F.friz, narrow = F.arialn, card = F.morpheus },
	color = { --[[ border, text, dim, accent, ... ]] },
	box = { --[[ backdrop, bg, border ]] },
	dialog = { --[[ backdrop, outset, border, under, plate ]] },
	tex = Bound.STOCK_TEX,
	card = {
		-- colours, then the textures that dress the card (files in Media/)
		frost = "Mist", frostTint = { 0.60, 1, 0.80, 0.12 },
		crest = "Crest", crestTint = { 0.66, 1, 0.74, 0.15 },
		shards = "Leaf", shardTint = { 0.66, 0.96, 0.62, 0.9 },
		rim = "Rim", breathe = true, breatheTime = 3.2,
		burst = false, studs = false, ring = false, round = false,
	},
	widgets = "blizzard",
}

Bound.InstallSkin(ns, {
	skins = { dream = dream },
	order = { "dream", "blizzard", "flat" },
	default = "dream",
	about = { dream = "Emerald Dream green with a soft edge, mist and leaves." },
})
Bound.InstallBuffTimers(ns)
Bound.InstallMinimap(ns)
```

LibBound derives the Blizzard and Flat skins from yours. Every field is on the [Skins](api/skins.html) page.

`tools/make_media.py` draws the textures into `Media/`: TGA files, power-of-two sizes, card textures white with alpha so the game can tint them. LibBound needs at least `Logo64`, `Logo256` and `Icon64`, plus every texture your `card` section names (and `RoundMask` for a skin with `round = true`).

## 5. Help.lua

Every plain-word explanation in one table:

```lua
local _, ns = ...
if ns.disabled then return end

ns.Help = {
	markOfTheWild = "Mark of the Wild gives armor, all stats and resistances. Keep it on yourself and your group. Gift of the Wild counts.",
	thorns = "Thorns hurts anything that hits you in melee. Keep it up while you level or tank.",
	hearthstone = "Your Hearthstone takes you back to the inn you set it to. Talk to an innkeeper to change it.",
	-- ...
}
```

`ns.Help` is a convention too. Cards, overlays and travel rows take these texts as `explain`, `help` or `SetExplain(text)`, and show them while the player keeps "Explain things in tooltips" on (`ns.db.explain`).

## 6. Buff cards with ns.MakeBuffTimer

A buff timer is a card that warns before a long self-buff runs out, counts down, and, with "keep following" on, shows a "has run out" card and reminds once. With `cast` set, a click on the card casts the buff. From Dreambound's `Buffs.lua`:

```lua
local D = ns.DATA
local function Name(list) local id = ns.BestRank(list) return id and ns.SpellName(id) end
local function BuffName(list, english) return ns.SpellName(list[1]) or english end

local BUFFS = {
	{ key = "markOfTheWild", frame = "DreamboundMarkOfTheWildFrame", label = "Mark of the Wild", icon = 136078,
		list = D.markOfTheWild, group = D.giftOfTheWild, groupName = "Gift of the Wild", party = true },
	{ key = "thorns", frame = "DreamboundThornsFrame", label = "Thorns", icon = 136104, list = D.thorns },
	-- ...
}
ns.BUFFS = BUFFS

local function Names(b)
	local n = { BuffName(b.list, b.label) }
	if b.group then n[#n + 1] = BuffName(b.group, b.groupName) end
	return n
end

for _, b in ipairs(BUFFS) do
	ns.MakeBuffTimer({
		key = b.key, point = b.key .. "Point", frameName = b.frame,
		label = b.label, icon = b.icon,
		names = function() return Names(b) end,         -- Gift of the Wild counts as Mark of the Wild
		active = function() return ns.BestRank(b.list) ~= nil end, -- hidden until learned
		cast = function() return Name(b.list) end,      -- the highest known rank
		explain = ns.Help[b.key],
		goneText = "Missing: click to cast",
	})
end
```

`key` must match the settings from step 3: `<key>`, `<key>Minutes`, `<key>Sound`, `<key>Icon`, `<key>Keep`, and `point` the position key. Every field is on the [Buff timers](api/buff-timers.html) page.

## 7. A custom card with ns.MakeCard and ns.CastOverlay

For anything that isn't a buff timer, build the card yourself as a module. Dreambound's reagent card (`Reagents.lua`) has no click:

```lua
local M = {}
ns.modules[#ns.modules + 1] = M
local card

function M:Update()
	if not card then return end
	if ns.unlocked then card:SetStatus("Wild Berries: 3"); card:Show(); card:Glow(false) return end
	local low = (not ns.InCombat()) and ns.LowReagents() or {}
	if #low > 0 then
		-- ... build the text
		card:SetStatus(table.concat(parts, " · "), urgent)
		card:Show(); card:Glow(true)
	else
		card:Glow(false); card:Hide()
	end
end

function M:Init()
	card = ns.MakeCard("DreamboundReagentsFrame", { width = 300 })
	card:SetIcon(136038)
	card:SetTitle("Reagents running low")
	card:SetExplain(ns.Help.giftReagent .. " " .. ns.Help.seeds)
	ns.MakeMovable(card, "rgPoint")
	ns.ApplyPoint(card, "rgPoint")
	local f = CreateFrame("Frame")
	for _, e in ipairs({ "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
		"PLAYER_ENTERING_WORLD" }) do f:RegisterEvent(e) end
	f:SetScript("OnEvent", function() M:Update() end)
	M:Update()
end
```

Things to copy from it:

- Create frames in `Init`, not when the file loads. `Init` runs once the saved settings are in, and after combat when the UI was reloaded in a fight.
- While `ns.unlocked`, show the card with sample text so the player can place it.
- `ns.MakeMovable(card, key)` and `ns.ApplyPoint(card, key)` with the card's `*Point` key.

To make a card cast, lay an overlay over it. Packbound's aspect card (`Aspect.lua`):

```lua
function M:Update()
	if not card then return end
	if ns.unlocked then
		card:SetStatus("Click to cast"); card:Show(); card:Glow(false)
		if not InCombatLockdown() then overlay:Sync(nil) end
		return
	end
	local spell = ns.AspectSpell()
	local show = -- no aspect up, out of combat, not mounted
	-- ...
	if not InCombatLockdown() then overlay:Sync(show and spell or nil, "player", ns.Help.aspect) end
end

function M:Init()
	card = ns.MakeCard("PackboundAspectFrame")
	-- ...
	overlay = ns.CastOverlay(card)
end
```

{: .warning }
Show an overlay only when the cast is needed now. The buff key casts what the first shown overlay would, so a card that stays clickable while all is well would be cast again and again. See [Buff key](api/buff-key.html).

## 8. Group buffs with ns.groupBuffs

The buff key, after the cards, casts group buffs on the next party or raid member in range who is missing them. Add one entry per buff. Dreambound gives Mark of the Wild to the group while its card is on:

```lua
for _, b in ipairs(BUFFS) do
	if b.party then
		ns.groupBuffs[#ns.groupBuffs + 1] = { list = b.list,
			names = function() return Names(b) end,
			enabled = function() return ns.db[b.key] ~= false end }
	end
end
```

`list` is the rank list (the key casts the highest known rank), `names` the aura names that count (here Gift of the Wild too), `enabled` optional. See [Buff key](api/buff-key.html#nsgroupbuffs).

## 9. Options pages and Bound.InstallOptions

Each page is a function that gets `UI` and builds the page when the window opens the first time. Add them to `ns.optionPages`, then call `InstallOptions`. Dreambound's `Options.lua`:

```lua
local Bound = LibStub("LibBound-1.0")

local function BuffPage(UI)
	local p = UI.NewPage("Buffs", "A card when a buff is missing or running out. Click it to cast (out of combat).")
	local W = UI.CONTENT_W
	local third = math.floor(W / 3)
	for _, b in ipairs(ns.BUFFS) do
		p:Add(UI.Section(p, p.y - 2, b.label) + 2)
		UI.DBToggle(p, 0, p.y, third, b.key, "Show")
		UI.DBToggle(p, third, p.y, third, b.key .. "Sound", "Sound")
		UI.DBToggle(p, third * 2, p.y, third, b.key .. "Keep", "When missing", nil, function() ns.UpdateBuffTimers() end)
		p:Add(34)
	end
	p:Add(UI.Note(p, p.y, "Omen of Clarity is a Restoration talent. Gift of the Wild counts as Mark of the Wild."))
end

local function ReagentPage(UI)
	local p = UI.NewPage("Reagents", "Wild Berries or Wild Thornroot for Gift of the Wild, and the seed for Rebirth.")
	local W = UI.CONTENT_W
	p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "giftReagent", "Warn when Gift of the Wild reagents run low", "Once you know Gift of the Wild.")) + 6)
	p:Add(select(2, UI.Slider(p, p.y, "Berries or Thornroot: warn at", "giftLow", 0, 40, 1, " left")) + 8)
end

local function TravelPage(UI)
	local p = UI.NewPage("Travel", "Teleport: Moonglade, Travel Form, Aquatic Form and your Hearthstone beside the game menu (Escape).")
	p:Add(select(2, UI.DBToggle(p, 0, p.y, UI.CONTENT_W, "travel", "Show the travel panel when the game menu opens")) + 8)
end

ns.optionPages[#ns.optionPages + 1] = BuffPage
ns.optionPages[#ns.optionPages + 1] = ReagentPage
ns.optionPages[#ns.optionPages + 1] = TravelPage
Bound.InstallOptions(ns, { header = "Druid helper", launcher = "Druid helper: buffs, reagents, travel." })
```

The layout pattern: `p.y` is the next free line (negative, from the top), widgets return their height, and `p:Add(h)` moves `p.y` down. LibBound adds the Extras and Skin pages after yours. Every widget is on the [Options](api/options.html) page.

## 10. The travel panel

Every Bound addon has the travel panel. Without a call, the loader installs one with only the Hearthstone. With the class's travel spells, Dreambound's `Travel.lua`:

```lua
local ROWS = {
	{ key = "moonglade", label = "Teleport: Moonglade", level = 10, learn = "from a druid trainer" },
	{ key = "travelForm", label = "Travel Form", level = 30, learn = "from a druid trainer" },
	{ key = "aquaticForm", label = "Aquatic Form", level = 16, learn = "from the druid quest for it" },
}
function ns.TravelRows()
	local out = {}
	for _, r in ipairs(ROWS) do
		local id = ns.DATA[r.key]
		out[#out + 1] = { spell = id, label = r.label, column = 1, known = Known(id), level = r.level,
			tip = r.label, help = ns.Help[r.key], learn = r.learn }
	end
	return out
end

Bound.InstallTravel(ns, { columns = { "DRUID" }, rows = ns.TravelRows, hearthHelp = ns.Help.hearthstone })
```

The optional `action` row is a plain button under the spells: not a spell, so it can't cast, but it can set a waypoint or open a page. Packbound uses it for the nearest ammo vendor:

```lua
Bound.InstallTravel(ns, { columns = { "HUNTER" }, rows = ns.TravelRows, hearthHelp = ns.Help.hearthstone,
	action = function() return ns.AmmoTravelRow() end })
```

`ns.AmmoTravelRow()` returns `{ icon, label, sub, tip, help, note, click }`; without `click` the row is grayed. Chronobound adds a `footer` with its rune counts and two columns. All fields are on the [Travel panel](api/travel.html) page.

## 11. Tests

Write wowbench scenarios in `tests/*.scenario.lua`, one file per feature, with shared setup in a helper (Dreambound: `tests/_druid.lua`, loaded with `dofile`). Dreambound has scenarios for core, buffs, the buff key, reagents, shots, skins and travel. Copy them and change the class. See [Testing and tools](testing.html).

## 12. CURSEFORGE.md and releases

- `CHANGELOG.md`: newest version on top, `## <version>` headings. CurseForge shows it as each release's changelog (`manual-changelog` in `.pkgmeta`).
- `CURSEFORGE.md`: the CurseForge project page, pasted by hand. It starts with a comment that holds the text for CurseForge's "Summary" field, at most 256 characters:

  ```markdown
  <!-- summary (CurseForge "Summary" field, at most 256 characters):
  Druid helper for WoW: Forever: one-click cards when Mark of the Wild, ...
  -->
  ```

  Between `<!-- changelog:start -->` and `<!-- changelog:end -->` it holds a copy of the changelog.
- Before a release: write the version in `CHANGELOG.md`, then run `python3 tools/sync_curseforge.py`.
- `.pkgmeta`: `package-as`, the LibBound external, `manual-changelog`, and an `ignore` list for everything that isn't the addon (docs, tests, tools, `.luacheckrc`, `wowbench.toml`, `CLAUDE.md`, `AGENTS.md`, `.beads`, `.claude`, `CURSEFORGE.md`, the art, `README.md`, `.gitignore`). A tag publishes: `v0.2.0` is a release, `v0.2.0-beta.1` a beta, `v0.2.0-alpha.1` an alpha.
- GitHub release zip: tag on main, `wowbench pack . --set-version X`, then `gh release create vX dist/<Addon>-X.zip`.

The tools are described on [Testing and tools](testing.html).

## Checklist for a new addon

1. Copy Dreambound, rename every `Dreambound` and `DreamboundDB`, and pick a slash command and a chat prefix color.
2. Set `class` and fill `ns.DATA` with the class's spells (Classic IDs, lowest rank first).
3. Write the skin and draw the media.
4. Replace the buffs, reagents and travel rows with the class's.
5. Add the group buffs the class can give.
6. Run `tools/sync-libbound.sh`, `luacheck .`, `wowbench check .` and `wowbench test .`.
7. Run `/<cmd> shots` in game, then `crop_shots.py`, for the docs' screenshots.
