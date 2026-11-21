---
title: Buff key
parent: API reference
nav_order: 9
description: One key that casts what a card asks for, then group buffs; ns.groupBuffs (BuffKey.lua).
---

# Buff key
{: .no_toc }

`BuffKey.lua`: one key, set on the Extras page, that casts the next thing needed, out of combat. `NewAddon` installs it (`lib.InstallBuffKey(ns)`).

1. TOC
{:toc}

{: .note }
LibBound 19 and later: `buffKey = false` in the NewAddon config turns the shared buff key off. For an addon with its own buff key, like Lightbound.

The header comment:

```lua
-- LibBound buff key: one key (set on the Extras page) that casts the next thing needed, out of
-- combat. First the top card that has something to cast (your own buffs, a pet to call, water to
-- conjure: what each card's click would do), then a group buff (ns.groupBuffs) on the next party
-- or raid member in range who is missing it or about to lose it.
-- The rule for cards: a shown cast overlay means "cast this now" (buff timers offer the cast only
-- when the buff is gone or about to run out). A card that stays clickable while all is well
-- would be cast again and again: don't give the buff key such a card.
-- A secure button named <Addon>BuffKey holds the macro; Lua rewrites it out of combat only (twice
-- a second, and when the group or its buffs change), and the key is an override binding on it.
--   ns.groupBuffs[#ns.groupBuffs + 1] = { list = { spell IDs, lowest rank first },
--     names = function() return { aura names that count, e.g. the Prayer version } end,
--     enabled = function() return true end }  -- optional
```

## What a press casts

Each press casts one spell, the first that applies:

1. **A card.** The first shown [cast overlay](overlays.html) in `ns.overlays` (creation order): the key runs that overlay's `macrotext`, the same as clicking the card.
2. **A group buff.** For each entry of `ns.groupBuffs` in order: the highest known rank of `list`, on the first group member who can get it and is missing it.

When nothing applies, a press prints `nothing to buff right now.`

### The rule for cards

{: .warning }
A shown overlay means "cast now". Only sync a spell into an overlay while the cast is needed. A card that stays clickable while all is well would be cast again on every press: don't give the buff key such a card.

Buff timers keep the rule on their own: their overlay shows only when the buff is gone or about to run out.

### Group members

- In a raid: `raid1` to `raidN`. In a party: `party1` to `party(N-1)`. The player is skipped (the cards cover them).
- A member counts as reachable when they exist, are connected, alive, friendly, visible and in range of the spell (`C_Spell.IsSpellInRange`, else `UnitInRange`).
- A member has the buff when one of the `names` is on them with more than 60 seconds left (or no expiry). Less than a minute left counts as missing.
- When some of a member's buffs can't be read (hidden from addons), the member counts as buffed and is skipped, rather than nag.
- The cast is `/cast [nocombat,@<unit>] <spell>`.

## ns.groupBuffs

```lua
ns.groupBuffs[#ns.groupBuffs + 1] = {
	list = { --[[ spell IDs, lowest rank first ]] },
	names = function() return { --[[ aura names that count ]] } end, -- optional
	enabled = function() return true end,                          -- optional
}
```

| Field | What it is |
| --- | --- |
| `list` | Rank list. The key casts `ns.BestRank(list)`; an entry with no known rank is skipped. |
| `names` | Optional. Aura names that count as having the buff, e.g. the group version. The spell's own name always counts. |
| `enabled` | Optional. Return false to skip the entry, e.g. while the player turned that buff's card off. |

`ns.groupBuffs` exists after `NewAddon`. Dreambound:

```lua
ns.groupBuffs[#ns.groupBuffs + 1] = { list = b.list,
	names = function() return Names(b) end, -- Mark of the Wild and Gift of the Wild
	enabled = function() return ns.db[b.key] ~= false end }
```

## The key and the button

- The key is `ns.db.buffKey`, a combo like `SHIFT-F` from the [KeyButton](options.html#uikeybutton) on the Extras page. `nil`: no key.
- The secure button is `<Addon>BuffKey` (`SecureActionButtonTemplate, SecureHandlerStateTemplate`, `type = "macro"`).
- The key is an override binding on the button (`SetOverrideBindingClick`), on top of the player's normal bindings. Clearing the key gives the old binding back.
- The macro is rewritten out of combat only: every 0.5 seconds and on `GROUP_ROSTER_UPDATE`, `PLAYER_REGEN_ENABLED` and `PLAYER_ENTERING_WORLD`.
- In combat a state driver sets the button's `type` to `none`, so the key casts nothing (a card's macro may have no `[nocombat]`). It goes back to `macro` after the fight.

### ns.BindBuffKey

```lua
ns.BindBuffKey()
```

Binds `ns.db.buffKey` to the button again, or clears the binding. In combat it waits until the fight ends. The Extras page calls it when the key changes.
