# LibBound-1.0

The shared core of the **Bound** class addons for WoW: Forever: Lightbound (paladin),
Chronobound (mage), and the ones to come. Taken from Lightbound's own core.

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
  window (addon pages plus the shared Extras and Skin pages).

See the comments at the top of each file for the details. Embed it with `LibBound.xml` after
LibStub; one copy runs no matter how many Bound addons embed it.

## Development

```bash
for f in *.lua; do luac5.1 -p "$f"; done
~/.luarocks/bin/luacheck .
wowbench check .
```

Its behaviour is tested through the addons that use it (`wowbench test` in Chronobound).
