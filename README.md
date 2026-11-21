<p align="center"><a href="https://github.com/antnsn/Lightbound"><img src="https://raw.githubusercontent.com/antnsn/Lightbound/main/Lightbound.png" width="96" alt="Lightbound" title="Lightbound"></a> <a href="https://github.com/antnsn/Chronobound"><img src="https://raw.githubusercontent.com/antnsn/Chronobound/main/Chronobound.png" width="96" alt="Chronobound" title="Chronobound"></a> <a href="https://github.com/antnsn/Stormbound"><img src="https://raw.githubusercontent.com/antnsn/Stormbound/main/Stormbound.png" width="96" alt="Stormbound" title="Stormbound"></a> <a href="https://github.com/antnsn/Packbound"><img src="https://raw.githubusercontent.com/antnsn/Packbound/main/Packbound.png" width="96" alt="Packbound" title="Packbound"></a> <a href="https://github.com/antnsn/Spiritbound"><img src="https://raw.githubusercontent.com/antnsn/Spiritbound/main/Spiritbound.png" width="96" alt="Spiritbound" title="Spiritbound"></a> <a href="https://github.com/antnsn/Felbound"><img src="https://raw.githubusercontent.com/antnsn/Felbound/main/Felbound.png" width="96" alt="Felbound" title="Felbound"></a> <a href="https://github.com/antnsn/Dreambound"><img src="https://raw.githubusercontent.com/antnsn/Dreambound/main/Dreambound.png" width="96" alt="Dreambound" title="Dreambound"></a> <a href="https://github.com/antnsn/Ragebound"><img src="https://raw.githubusercontent.com/antnsn/Ragebound/main/Ragebound.png" width="96" alt="Ragebound" title="Ragebound"></a> <a href="https://github.com/antnsn/Shadowbound"><img src="https://raw.githubusercontent.com/antnsn/Shadowbound/main/Shadowbound.png" width="96" alt="Shadowbound" title="Shadowbound"></a></p>

# LibBound-1.0

The shared core of the **Bound** class addons for WoW: Forever: Lightbound (paladin), Chronobound
(mage), Stormbound (shaman), Packbound (hunter), Spiritbound (priest), Felbound (warlock), Dreambound
(druid), Ragebound (warrior) and Shadowbound (rogue). Taken from Lightbound's own core.

**Guide and API reference for addon authors: https://antnsn.github.io/LibBound/**

An addon calls `LibStub("LibBound-1.0"):NewAddon(addonName, ns, cfg)` from its first file. That
fills `ns` with: saved settings with defaults, safe aura reading on Forever (secret values in
combat), the module loader with error isolation, movable frames with grid snapping and mouse-wheel
scaling, click-to-cast overlays, the slash command with space-free aliases. Then:

- `lib.InstallSkin(ns, { skins, default, order, about })`: the addon's class skin, plus Blizzard
  and Flat derived from it; `ns.UI` helpers and option widgets; `ns.MakeCard` (cards dressed by
  the skin: sunburst, ring, studs for Lightbound; frosted glass, crystal shards, breathing rim
  for Chronobound).
- `lib.InstallBuffTimers(ns)`: `ns.MakeBuffTimer(cfg)`, with Well-Rested and Well Fed built in.
- `lib.InstallTravel(ns, cfg)`: the travel panel beside the Escape menu (the class's travel
  spells in one or two columns, a footer line, the Hearthstone).
- `lib.InstallMinimap(ns, cfg)`, `lib.InstallOptions(ns, cfg)`: the minimap button and the options
  window (addon pages plus the shared Extras and Skin pages). The button is a LibDataBroker
  launcher shown by LibDBIcon-1.0 (embedded in `Libs/`), so minimap addons collect it.
- `ns.EmblemVariant()` (the addon's, optional) returns a file-name suffix such as `"Shadow"`; the
  logo, watermark, minimap icon and crest use `ns.SetEmblem(tex, base)` and follow it (Spiritbound:
  holy or shadow hood).

See the comments at the top of each file for the details. Embed it with `LibBound.xml` after
LibStub; one copy runs no matter how many Bound addons embed it.

## Development

```bash
for f in *.lua; do luac5.1 -p "$f"; done
~/.luarocks/bin/luacheck .
wowbench check .
```

Its behaviour is tested through the addons that use it (`wowbench test` in Chronobound).

## Screenshots for the docs

Every Bound addon has a hidden `shots` command (`/pack shots`, `/spirit shots`, ...; `Shots.lua`):
it opens each options page, the unlocked frames and the travel panel in turn, takes a screenshot
of each and saves where every frame sat in the addon's saved variables. Don't touch anything while
it runs; a fight stops it. Then `/reload` and, from `Interface/AddOns`:

```bash
python3 LibBound/tools/crop_shots.py Spiritbound   # crops into Spiritbound/docs/screenshots
```

Chat windows are pixelated. The addon's own skin goes to `docs/screenshots/`, other skins (switch
skin, reload, run it again) to `docs/screenshots/skins/<skin>/`. Needs Pillow (`pip install pillow`).

## Buff key

`BuffKey.lua`: one key (Extras page, saved as `db.buffKey`) that, out of combat, casts what the
first shown card's click would, else a group buff from `ns.groupBuffs` on the next party or raid
member in range who is missing it (less than a minute left counts). See the file's header for
the `ns.groupBuffs` entry shape.

## Combo bar

`ComboBar.lua`: `Bound.InstallComboBar(ns, { glow, active, about })` adds five pips, one lit with a
glow for each combo point on the target, with its own **Combo points** options page (call it from
`Options.lua` where the page should go). `active` limits it, e.g. to Cat Form. Make the pip
textures from a painted pip with `python3 tools/make_combo_media.py ART.png ADDON/Media`. See
[the API page](https://antnsn.github.io/LibBound/api/combo-bar.html).

## Power bar

`PowerBar.lua`: `Bound.InstallPowerBar(ns, { power, title, active, overlay, ... })` adds a rage
(or energy) bar from layered painted art, horizontal or vertical, with the number, a spark at the
fill's end and a glow when full, and its own options page. The Blizzard and Flat skins get a plain
bar (`Bound.BarLook`, shared with the combo bar). Make the textures with
`python3 tools/make_bar_media.py SRC_DIR ADDON/Media`. See
[the API page](https://antnsn.github.io/LibBound/api/power-bar.html).

## Cooldown Manager skin

`CooldownSkin.lua`: `Bound.InstallCooldownSkin(ns, { suggest })` gives Blizzard's Cooldown Manager
icons the addon's look (edge, count font) and adds a page with a button to Blizzard's settings.
Forever hides buffs from addons in combat, but the Cooldown Manager is drawn by the game, so its
stacks and timers keep working there. Secure hooks only, nothing written into Blizzard's frames. See
[the API page](https://antnsn.github.io/LibBound/api/cooldown-skin.html).
