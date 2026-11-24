---
title: Testing and tools
nav_order: 4
description: wowbench, luacheck, and the scripts in LibBound and in the addons.
---

# Testing and tools
{: .no_toc }

1. TOC
{:toc}

## The checks

Before a commit, in LibBound:

```bash
for f in *.lua; do luac5.1 -p "$f"; done
~/.luarocks/bin/luacheck .
wowbench check .
```

In an addon (Dreambound's `CLAUDE.md`):

```bash
tools/sync-libbound.sh                                                # LibBound into Libs/ (not tracked)
for f in *.lua; do luac5.1 -p "$f" || echo "syntax error: $f"; done
~/.luarocks/bin/luacheck .
wowbench check . && wowbench test .                                   # 0 errors, every scenario ok
```

The rules: Lua 5.1, only API that wowbench knows (its `api/client.txt`), `wowbench check .` with 0 errors, luacheck clean.

## luacheck

luacheck lives at `~/.luarocks/bin/luacheck`. Each repository has a `.luacheckrc`:

- `std = "lua51"`, no line length limit, warnings 212 (unused argument) and 432 (shadowed upvalue argument) ignored.
- `Libs/` is excluded; the addons also exclude `tests/` and `tools/`.
- `read_globals` lists every game global the code reads. Add a new API there when you use it.
- LibBound sets `globals = { "SlashCmdList", "_G" }`, since it writes slash commands.

The real API list is wowbench's; the `.luacheckrc` list is only what the code uses.

## wowbench

wowbench checks, tests and packages WoW: Forever addons.

```text
wowbench check [DIR]   The .toc, Lua 5.1 syntax, and globals nobody defines
wowbench test [DIR]    Run the addon's scenarios in the stand-in client
wowbench pack [DIR]    Build a release zip
wowbench all           check, then test
```

### wowbench check

Reads the `.toc`, checks the Lua syntax and reports globals that nobody defines and that are not in the known API. `--strict` makes warnings fail too; `-v` also lists every global the addon sets. An addon's `wowbench.toml` skips the embedded libraries:

```toml
[check]
skip = ["Libs/**"]
```

LibBound has its own `LibBound.toc` (it loads LibStub and `LibBound.xml`), so `wowbench check .` works in the LibBound folder too.

### wowbench test

Runs every scenario in `tests/` in a stand-in client. Options:

| Option | What it does |
| --- | --- |
| `-s, --scenario` | Scenario files or folders. |
| `--only <text>` | Only runs whose file contains the text, or whose mood is it. |
| `-v, --verbose` | Print each run's log and the stub gaps. |
| `-j, --jobs` | Runs at the same time. |

### Scenarios

A scenario is a file `tests/<name>.scenario.lua`. Its first line lists the moods: the scenario runs once per mood, with `wb.mood` set. Dreambound's `tests/core.scenario.lua`:

```lua
--@moods: druid warlock
local T = dofile(wb.dir .. "/tests/_druid.lua")
if wb.mood == "druid" then
	T.druid({ 1126 })
	wb.login()
	wb.advance(7)
	wb.slash("/dream")
	wb.check(wb.shown("DreamboundOptions"), "/dream opens the options")
	local titles = {}
	for _, p in ipairs(wb.ns.optionsState.pages) do titles[#titles + 1] = p.title end
	wb.expect("pages", table.concat(titles, ", "), "Buffs, Reagents, Travel, Extras, Skin")
else
	wb.state.player.classFile, wb.state.player.class = "WARLOCK", "Warlock"
	wb.login()
	wb.slash("/dream")
	wb.check(wb.printed("only does something on a druid"), "a warlock is told why")
end
```

What the Bound scenarios use from `wb`:

| Call | Used for |
| --- | --- |
| `wb.mood`, `wb.dir` | The current mood; the addon folder (for `dofile` of a shared helper). |
| `wb.state` | The stand-in client's state: `player`, `spells`, `known`, `auras`, `bags`. Set it before `wb.login`. |
| `wb.login({ saved = { DreamboundDB = db } })` | Load the addon and log in, optionally with saved variables. |
| `wb.advance(seconds)` | Let time pass (timers, tickers, `OnUpdate`). |
| `wb.slash(text)` | Type a slash command. |
| `wb.combat(on)` | Enter or leave combat. |
| `wb.join(members)` | Join a group: `{ unit = "party1", name = "Friend", classFile = "WARRIOR" }`, with `far` or `dead` flags. |
| `wb.ns` | The addon's `ns`. |
| `wb.G` | The global table, to stub an API: `wb.G.Screenshot = function() ... end`. |
| `wb.frame(name)`, `wb.frames()`, `wb.shown(name)` | Find frames; is a named frame shown. |
| `wb.printed(text)` | Did chat get a line with this text. |
| `wb.check(cond, message)` | Assert. |
| `wb.expect(what, got, want)` | Assert equal. |

Read the scenarios of an existing addon for more: `tests/buffkey.scenario.lua` and `tests/shots.scenario.lua` in Dreambound show how to stub what the stand-in client lacks.

### How LibBound is tested

LibBound has no scenarios of its own. Its behavior is tested through the addons that embed it: a LibBound change must keep every embedding addon's scenarios green. For each addon:

```bash
cd ../Dreambound
tools/sync-libbound.sh && wowbench test .
```

Do the same in every other Bound addon: Lightbound, Chronobound, Stormbound, Packbound, Spiritbound, Felbound, Ragebound and Shadowbound. A new LibBound feature gets its scenario in at least one addon, usually the one that needs it first.

## tools/sync-libbound.sh

In every addon. Copies `../LibBound` into `Libs/LibBound`, so the addon runs in game and in wowbench while LibBound is developed next to it:

```bash
#!/usr/bin/env bash
# Copies ../LibBound into Libs/LibBound so the addon runs in game and in wowbench while LibBound
# is developed next to it. Libs/LibBound is not tracked: release zips embed LibBound through
# wowbench pack ([[pack.embed]] in wowbench.toml).
```

It copies `LibBound.xml`, `LICENSE`, every `*.lua` file (a new LibBound file needs no change here) and the three minimap libraries. Run it after every LibBound change, then `/reload` in game.

`Libs/LibBound/` is in the addon's `.gitignore`. Release zips embed LibBound through `wowbench.toml`:

```toml
[[pack.embed]]
from = "../LibBound"
to = "Libs/LibBound"
```

## tools/sync_curseforge.py

In every addon. Run from the addon folder:

```text
python3 tools/sync_curseforge.py            (writes CURSEFORGE.md)
python3 tools/sync_curseforge.py --check    (exit 1 if it is out of date)
python3 tools/sync_curseforge.py --summary  (print the summary to paste)
```

- **Changelog sync.** Everything between `<!-- changelog:start -->` and `<!-- changelog:end -->` in `CURSEFORGE.md` is replaced by `CHANGELOG.md`, without its `# ` title. Version headings move one level down (`## 4.5` becomes `### 4.5`), so they sit under the page's own `## Changelog`. An `## Unreleased` section is left out: the page shows what people can download.
- **Summary.** The top of `CURSEFORGE.md` holds the text for CurseForge's "Summary" field in a comment, hidden when the file is pasted as the description:

  ```markdown
  <!-- summary (CurseForge "Summary" field, at most 256 characters):
  One or two sentences.
  -->
  ```

  Every run checks that there is exactly one and that it is at most 256 characters (line breaks count as spaces).

## tools/make_media.py

In every addon, with its own drawings. Draws the addon's textures into `Media/`: TGA files, power-of-two sizes. Card textures (mist, leaves, rim, ...) are white with alpha so the game can tint them; the logo, icon and crest come from the addon's painted art (`<Addon>.png`). Run from the addon folder:

```bash
python3 tools/make_media.py
```

It needs Pillow.

## tools/crop_shots.py

In LibBound. Cuts frames out of the screenshots the hidden `shots` command took:

```bash
python3 LibBound/tools/crop_shots.py Spiritbound   # from Interface/AddOns
```

See [Shots](api/shots.html) for the options and the output layout.

## Releases

- **GitHub:** tag on main, `wowbench pack . --set-version X` (writes `dist/<Addon>-X.zip`; `--list` shows what goes in), `gh release create vX dist/<Addon>-X.zip`.
- **CurseForge:** a tag publishes through `.pkgmeta`, which fetches LibBound as an external.

Before either: the version in `CHANGELOG.md`, then `python3 tools/sync_curseforge.py`.
