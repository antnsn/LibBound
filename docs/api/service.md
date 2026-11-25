---
title: Service
parent: API reference
nav_order: 15
description: Sell a class service in Trade - announce with a key press, alerts with Invite and Whisper links (Service.lua).
---

# Service
{: .no_toc }

`Service.lua`: lets a player sell what their class can do, like mage portals (Chronobound) or lockbox opening (Shadowbound). Two parts:

- **Announce**: a key, a click or `/<cmd> announce` posts the player's own message to Trade, with placeholders filled in. The client allows channel posts only from a key press or a click, so there is no timer.
- **Listen**: when someone in chat asks for the service, it plays a sound and prints one line with clickable **[Invite]** and **[Whisper]**. An auto-whisper reply can be turned on (off by default).

Only addons that call `Bound.InstallService` get it.

1. TOC
{:toc}

## Declaring a service

From a file loaded before `Options.lua`:

```lua
Bound.InstallService(ns, {
  label = "Portals",                          -- chat and the slash help
  page = "Portal service",                    -- options page title (default: label .. " service")
  example = 'Portals to {portals}! Whisper "port {short}", tips welcome :)',
  reply = "Hi {name}! Inviting you for a portal to {target}, I'm in {zone}.",
  keywords = { "portal", "portals" },         -- what the service is; multi-word allowed ("open box")
  weak = { "port" },                         -- optional: count only next to another intent word
  targets = function() return { org = "Orgrimmar", uc = "Undercity" } end, -- optional: word -> {target}
  available = function() return true end,     -- false: no announcing, no alerts
  unavailable = "You know no portals yet.",   -- said when announcing while unavailable
  fill = { portals = function() return "Orgrimmar, Undercity" end }, -- placeholders
  skillField = true,                          -- optional: a number box for ns.db.serviceSkill
  help = "Post your portal offer ...",        -- optional: the options page subtitle
})
```

`targets` may be a table or a function returning one (read each time, so the faction can be known by then). Then, in `Options.lua`, where the page should go:

```lua
ns.optionPages[#ns.optionPages + 1] = ns.ServicePage
```

Placeholders: the service's `fill` plus `{zone}` and `{level}`. The reply also gets `{name}` (the sender without realm) and `{target}`. An unknown or empty placeholder stays as written.

## Matching

`lib.ServiceMatch(text, spec, fromWhisper)` returns `nil` or `{ target = value or nil }`; `spec = { keywords, targets, extra }` (`extra` = the player's own words, used as keywords).

- Words are lowercased; colour codes and link data are dropped (a link's `[name]` counts), `?` is a word of its own.
- In public chat a keyword or target fires only with an intent word: `wtb lf lfm need needs any anyone port plz pls please can someone ?`. "lol port" or a bare "portal" does not.
- A weak word (`port`) counts only next to another intent word: "need a port pls", "lf port" and "port?" fire, "lol port" does not.
- In a whisper a keyword or target alone fires.
- Rival offers never fire in public chat: `wts selling offering tips`, "whisper me", "w me", "lf customers", or a `/w`.
- Listened to: channels whose name starts with Trade, General or LookingForGroup; say; yell; whispers. Never the player's own messages, never secret text or senders. The same sender again within 60 s is ignored.

`lib.ServiceWords(text)` and `lib.ServiceFill(template, fills)` are the helpers; `tests/test_service.lua` covers all three (`lua5.1 tests/test_service.lua`).

## Links

The line's links are `addon:bound:<addonName>:invite:<name>` and `...:whisper:<name>`. One `SetItemRef` hook (the first LibBound copy installs it) calls `lib.ServiceLink(link)`, which invites with `C_PartyInfo.InviteUnit` or opens `/w name` in the chat box. Links of addons without a service return false. Checked on Forever, also in EllesmereUIChat.

## Settings

Per addon, defaults added by `InstallService`:

| Key | Default | |
|---|---|---|
| `serviceOn` | true | alerts |
| `serviceSound` | true | a sound with each alert |
| `serviceMessage` | the example | nil means the example |
| `serviceChannel` | "Trade" | matched as the start of the channel name |
| `serviceInterval` | 60 | seconds between posts |
| `serviceKey` | nil | the announce key (override binding on `<Addon>ServiceButton`) |
| `serviceTriggers` | {} | extra words |
| `serviceAutoWhisper` | false | reply once per sender per 10 minutes, never in combat |
| `serviceReply` | the reply example | |
| `serviceSkill` | nil | with `skillField` |

## Functions

- `ns.ServiceAnnounce()`: posts, or prints why not (unavailable, empty message, the wait left, no channel). Messages over 255 characters are cut.
- `ns.ServiceOnChat(event, ...)`: the chat listener with the event's arguments.
- `ns.ServiceMessage()`, `ns.ServicePreview()`: the message and its filled text.
- `ns.BindServiceKey()`: rebinds the key (waits for the end of combat).
- `ns.ServicePage(UI)`: the options page builder.
