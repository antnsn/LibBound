---
title: Buff timers
parent: API reference
nav_order: 3
description: Bound.InstallBuffTimers and ns.MakeBuffTimer (BuffTimer.lua).
---

# Buff timers
{: .no_toc }

`BuffTimer.lua`: a card that warns before a long self-buff runs out, counts down, and can follow the buff after it is gone. Taken from Lightbound's `WellRested.lua`.

1. TOC
{:toc}

## Bound.InstallBuffTimers

```lua
Bound.InstallBuffTimers(ns)
```

Call it once, after `NewAddon` and `InstallSkin` (Dreambound calls it in `Skin.lua`). It defines `ns.MakeBuffTimer`, `ns.UpdateBuffTimers`, `ns.TestBuffTimer` and `ns.buffTimers`, and makes the two timers every Bound addon has:

| Key | Buff | Position | Frame name |
| --- | --- | --- | --- |
| `wellRested` | Well-Rested (spell 429959) | `wrPoint` | `<Addon>WellRestedFrame` |
| `wellFed` | Well Fed, with `sayGone` | `wfPoint` | `<Addon>WellFedFrame` |

Their settings are in `lib.SHARED_DEFAULTS` and on the shared Extras page.

## ns.MakeBuffTimer

```lua
local M = ns.MakeBuffTimer(cfg)
```

The header comment:

```lua
--   key       settings prefix: <key>, <key>Minutes, <key>Sound, <key>Icon, <key>Keep
--   point     settings key of the card's position
--   frameName the card's global name
--   label     shown on the card and in chat
--   names     list of buff names, or a function returning one (several ranks, a choice of spell)
--   spellID   optional: its localized name is looked for too
--   icon      card icon until the buff's own icon is known
--   sayGone   say "<label> is gone" when it drops (when not following it)
--   cast      optional function -> spell name to cast when the card is clicked (out of combat)
--   explain   optional plain-word tooltip text
--   goneText  status text when it is missing (default "Buff has run out"), or a function returning it
--   active    optional function -> false to hide the timer entirely (spell not known yet)
--   castIDs   optional spell IDs: casting one restarts the timer
--   duration  seconds a cast lasts until the buff has been seen once
--   ready     optional function -> false to keep the card from glowing
```

`castIDs` exists because Forever hides buffs from addons in combat: a buff cast mid-fight is only seen through `UNIT_SPELLCAST_SUCCEEDED`. The timer then runs for the buff's real duration from the last time it was read, or `duration` until then. A spell ID the addon can't read is ignored. `ready` errors and unreadable answers count as ready, so the glow shows rather than hides.

The code also reads `cfg.title`: a string or a function returning one, set as the card's title on every update. Without it the title is `label`.

**Returns** the module table `M`, already added to `ns.modules`. It is also stored as `ns.buffTimers[key]`.

### The settings

`key = "thorns"` reads these `ns.db` keys. Give each a default:

| Setting | Type | What it does |
| --- | --- | --- |
| `thorns` | boolean | Warn at all. |
| `thornsMinutes` | number | Warn with this many minutes left. |
| `thornsSound` | boolean | Play the raid warning sound with the warning. |
| `thornsIcon` | boolean | Show the countdown card. |
| `thornsKeep` | boolean | Keep following the buff after it is gone: the "has run out" card and one reminder. |
| `thornsCombat` | boolean | Optional. Only in combat: the card and warnings show only during a fight, and the out-of-combat reminder is off. For a buff cast in the fight (Battle Shout). Unset counts as off. |
| `thornsPoint` (the `point` key) | point table | The card's position. |

### What the player sees

- **Countdown.** With `<key>Minutes` or less left, once: a raid warning and a chat line (`<label>: N min left`), with a sound when `<key>Sound` is on. Then, with `<key>Icon` on, the card glows and counts down (`4:59 left`).
- **Gone.** With `<key>Keep` on and the buff missing: the card faded, with `goneText` in the urgent color. Once per loss, out of combat and alive: `<label> is gone, rebuff`.
- **sayGone.** With `<key>Keep` off and `sayGone` set: `<label> is gone` when the buff drops.
- **Unlocked.** The card shows with `5:00 left` so the player can place it.
- **Not active.** When `active()` returns false the card stays hidden and the timer silent.
- **Only in combat.** With `<key>Combat` on, out of combat the card stays hidden and the warning waits: entering combat with little time left shows the card and gives the warning then. The card can't be clicked in combat (the cast overlay hides), so `goneText` should not say "click" there: pass a function.
- **Ready.** With `ready` given, the countdown and gone cards glow only while it returns true (rechecked on `UNIT_POWER_FREQUENT`).

For 5 seconds after login or a zone change it stays quiet, since the aura list may not be filled in yet. A buff that is unreadable (combat restrictions) does not count as gone.

### Click to cast

With `cast` set, the timer lays a [cast overlay](overlays.html) over its card. The overlay is shown only in the countdown and gone states, with the spell name `cast()` returns, on `"player"`, and `explain` in its tooltip. That keeps the buff key rule: a shown overlay means "cast this now".

### Module fields

| Field | What it is |
| --- | --- |
| `M:Init()`, `M:Update()` | Run by the loader and by `ns.Refresh`. |
| `M.Test()` | Fires the countdown warning as if it were due. |
| `M.Card()` | The card frame (after `Init`). |
| `M.Overlay()` | The overlay, or `nil` without `cast`. |
| `M.Mode()` | `"countdown"`, `"gone"`, `"unlocked"` or `nil`. |

## Other functions

```lua
ns.UpdateBuffTimers() -- Update every timer (after a "Keep" toggle, for example)
ns.TestBuffTimer(key) -- the Test button on the Extras page
lib.FormatTime(seconds) -- "m:ss"
```

## Example

From Packbound's `Aspect.lua`:

```lua
ns.MakeBuffTimer({
	key = "trueshot", point = "taPoint", frameName = "PackboundTrueshotFrame",
	label = "Trueshot Aura", icon = 132329,
	names = function() return { ns.SpellName(D.trueshot) or "Trueshot Aura" } end,
	active = function() return Known(D.trueshot) end,
	cast = function() return Known(D.trueshot) and ns.SpellName(D.trueshot) or nil end,
	explain = ns.Help.trueshot,
	goneText = "Missing: click to cast",
})
```

With these defaults:

```lua
trueshot = true, trueshotMinutes = 1, trueshotSound = false, trueshotIcon = true, trueshotKeep = true,
taPoint = { "CENTER", "UIParent", "CENTER", 250, 140 },
```
