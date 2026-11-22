---
title: Cooldown Manager skin
parent: API reference
nav_order: 13
description: Bound.InstallCooldownSkin, Blizzard's Cooldown Manager icons in the addon's look, and why it exists (CooldownSkin.lua).
---

# Cooldown Manager skin
{: .no_toc }

`CooldownSkin.lua`: Blizzard's Cooldown Manager (the Essential, Utility and Tracked Buffs icons) in the addon's look, with an options page.

## Why

On Forever, addons can't read buffs in combat: `C_Secrets.ShouldSpellAuraBeSecret` is true for class buffs, lookups return nothing, and `GetAuraApplicationDisplayCount` errors with `ForceTaint_Strong` (tested in game, 2026-11-21). The Cooldown Manager is drawn by the game itself, so its stacks and timers keep working in combat. LibBound doesn't try to read them; it only restyles Blizzard's icons so they match the addon.

## Bound.InstallCooldownSkin(ns, opts)

```lua
Bound.InstallCooldownSkin(ns, {
	suggest = { "Holy Shield", "Righteous Fury", ... }, -- optional: buffs worth tracking, shown on the page
})
```

Call it in `Options.lua`, where its page should go among the addon's own (`ns.optionPages` order).

- **Setting** `cdmSkin` (default on): give the icons the addon's look. Turning it off puts Blizzard's look back without a reload.
- **Looks** (`Bound.BarLook`): the addon's own skin gets a gilt edge (`card.gilt`) with a dark inner line and the count in `card.title`; Flat a black edge and a white count; the Blizzard skin leaves the game's look alone.
- **What changes on each icon**: Blizzard's rounded overlay (`UI-HUD-CoolDownManager-IconOverlay`) hides, the rounded mask comes off, the icon is cropped, our edge goes round it, and the stack count (`Applications`) or charges (`ChargeCount.Current`) take the skin's card font. Bars (Tracked Bars) are left alone.
- **Page**: the toggle, a button that opens Blizzard's settings (`CooldownViewerSettings:TogglePanel()`, out of combat), a note on adding buffs and moving them with Edit Mode, and the `suggest` list.
- **Another addon in charge**: when EllesmereUI's Cooldown Manager (`EllesmereUICooldownManager`) is loaded, it draws its own icons, keeps Blizzard's invisible and locks them in Edit Mode. LibBound then leaves Blizzard's icons alone. When such an addon is installed, the page offers **Who draws the Cooldown Manager**: picking this addon turns the other addon's module off for the character (`C_AddOns.DisableAddOn`, the way EllesmereUI switches its own modules) and picking it back turns it on, both after a reload (`ns.cooldownSkin.Choice()` / `Choose(name)`). More such addons go in the `TAKERS` list in `CooldownSkin.lua`.
- **Test hook**: `ns.cooldownSkin.State(item)` returns LibBound's state for a Blizzard icon (or nil when untouched).

## Taint

LibBound only uses `hooksecurefunc` on the viewers' `RefreshLayout` and `OnAcquireItemFrame`, and calls methods on Blizzard's textures. It writes nothing into Blizzard's frames: its state is in its own weak table. Blizzard's own code, which reads the hidden values in combat, stays untainted. The viewers may load late (`Blizzard_CooldownViewer`), so it hooks on `ADDON_LOADED` and `PLAYER_ENTERING_WORLD` too.
