---
title: Shots
parent: API reference
nav_order: 10
description: The hidden shots command, the db.shots format and crop_shots.py (Shots.lua, tools/crop_shots.py).
---

# Shots
{: .no_toc }

Screenshots for the docs: a hidden command takes them in game, a script crops them.

1. TOC
{:toc}

The header comment of `Shots.lua`:

```lua
-- LibBound screenshots for the docs: "/<addon> shots" (not in the help) opens every options page,
-- the unlocked frames and the travel panel in turn and takes a screenshot of each. Where each frame
-- sat goes into the addon's saved variables (db.shots[skin]) as fractions of the screen, so
-- LibBound/tools/crop_shots.py can cut the frames out after a /reload. The skin is fixed for the
-- session: switch skin, reload, run it again. A fight stops the run and puts everything back.
```

## The command

```text
/dream shots
/dreamshots
```

Every Bound addon has it (`/pack shots`, `/spirit shots`, ...). It is hidden: `/cmd help` does not list it. The command calls `lib.Shots(ns)`.

The run:

1. Refuses in combat, while a run is going, or when the addon has no options window.
2. Locks the frames if they were unlocked, and opens the options window.
3. Sets the `screenshotFormat` CVar to `png` for the run.
4. Takes one screenshot per step, 0.6 s after preparing it and 1.6 s apart (screenshot file names only have whole seconds):
   - `options-<page>` for every options page (the page title as a slug: `options-buffs`, `options-extras`, `options-skin`);
   - `frames-unlocked`: the options closed, every frame unlocked; the whole screen is kept too;
   - `travel`: the game menu with the travel panel, when the addon has one.
5. Puts everything back: the CVar, the options page, the frame lock, the game menu.
6. Saves the run in `ns.db.shots[skin]` and prints what to do next, also in the middle of the screen with a sound.

A fight stops the run: it says `stopped (combat)`, saves what it has and puts the frame lock and the game menu back once the fight is over. An error in a step stops it the same way, with the step's name.

{: .warning }
Don't touch anything while it runs. The chat line tells how long it takes.

To shoot another skin: pick it on the Skin page, reload, run the command again. Each skin is saved under its own key.

## db.shots

```lua
ns.db.shots[skin] = {
	skin = "dream",            -- ns.db.skin, or "default" when unset
	at = "2026-11-21 14:05",   -- when the run started
	list = {
		{
			name = "options-buffs",  -- the file name of the crop
			at = "112126_140501",    -- %m%d%y_%H%M%S, matched against WoWScrnShot_<stamp>.png
			rects = { main = { x = 0.31, y = 0.18, w = 0.40, h = 0.57 } },
			full = nil,              -- true for frames-unlocked: keep the whole screen too
			hide = { { x = ..., y = ..., w = ..., h = ... } }, -- chat windows to pixelate
		},
		-- frames-unlocked: rects = { markOfTheWildPoint = {...}, rgPoint = {...}, ... } (one per mover key)
	},
}
```

Rects are fractions of the screen with the origin at the top left, so they don't depend on the UI scale. A frame's rect takes in what its textures and child frames draw outside it (a title plate, a close button), two levels deep, but nothing a scroll frame clips away. `hide` holds every shown chat window and chat input line.

## crop_shots.py

`LibBound/tools/crop_shots.py` cuts the frames out of the screenshots. It needs Pillow (`pip install pillow`).

```text
Usage: crop_shots.py ADDON [--out DIR] [--sv FILE] [--screens DIR] [--skin NAME] [--dry-run]
  (from Interface/AddOns: python3 LibBound/tools/crop_shots.py Spiritbound)
```

| Option | Default | What it is |
| --- | --- | --- |
| `ADDON` | | The addon's folder name. |
| `--out DIR` | `<addon>/docs/screenshots` | Where to write. |
| `--sv FILE` | the newest saved variables file with screenshots | The addon's saved variables, from `WTF/Account/*/SavedVariables` or a character folder. |
| `--screens DIR` | `_forever_/Screenshots` | The game's screenshot folder. |
| `--skin NAME` | every skin | Only this skin. |
| `--dry-run` | | Print what would be written. |

### Steps

After the shots command ran, `/reload` (so the saved variables are written), then from `Interface/AddOns`:

```bash
python3 LibBound/tools/crop_shots.py Spiritbound
```

The script:

1. Reads the SavedVariables name from the `.toc` (`## SavedVariables:`) and the addon's own skin from `Core.lua` (the first `skin = "..."`).
2. Finds each shot's screenshot by its time stamp: from 1 second before to 3 seconds after the noted time.
3. Pixelates the chat windows (other players' names and messages), 14 px blocks.
4. Writes the crops, 4 px of margin around each:

| What | Where |
| --- | --- |
| The addon's own skin | `<out>/<name>.png` |
| Other skins | `<out>/skins/<skin>/<name>.png` |
| Frames in the unlocked shot | `.../frames/<key>.png` next to them, the key in lower case |

Whole-screen shots are scaled down to at most 1920 px wide. The script exits with an error when a screenshot is missing.

{: .note }
The SavedVariables name in the `.toc` and a `skin = "<key>"` default in `Core.lua` are what the script relies on. Keep both in a new addon.
