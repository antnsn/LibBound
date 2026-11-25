# Service: sell a class service in Trade (portals, lockboxes)

Date: 2026-11-25. Status: draft for Marius's approval (probes done).

## Intent

Marius plays a mage (Chronobound) and a rogue (Shadowbound) on WoW: Forever. He wants to sell what
the class can do for other players: mage portals to the faction's cities, rogue lockbox opening.
Two parts:

1. **Announce**: post his own message in Trade with one key press or click, with placeholders the
   addon fills in (the portals he knows, his lockpicking skill). An example message ships so it
   works out of the box; he can edit it.
2. **Listen**: when someone in chat asks for the service ("wtb port org", "uc port?", "anyone open
   lockbox"), play a sound and print one line in chat with clickable **[Invite]** and **[Whisper]**,
   so he can react before another mage does.

Approved in conversation: the behaviour above, editable message with an example, editable trigger
words matched as whole words, a click on the chat line instead of acting automatically, and an
optional auto-whisper reply (off by default).

## Goals

- One shared module in LibBound (`Service.lua`); Chronobound and Shadowbound only declare their
  service (example message, placeholders, trigger words). Later class addons can reuse it
  (e.g. warlock summons in Felbound) without new library code.
- Few false alerts: bare city words like "org" or "uc" alone in Trade chatter must not fire.
- Works in a city in normal play; never errors on secret chat values.

## Non-goals

- Posting on a timer or posting without a key press/click (the client forbids it: `SendChatMessage`
  is restricted, see Constraints).
- Auto-invite. Inviting stays a click.
- Payment/tip tracking, queues of customers, a customer list window.
- Casting the portal or opening the lockbox for him (protected; the existing travel panel and spell
  book already do that).

## Anti-goals (a failure even if it works)

- Getting Marius muted or reported for spam: no repeated posting faster than a set interval, no
  whisper spam.
- An alert stream from normal chat (every "org" mention) that he learns to ignore.
- Auto-whispers going to people who were not asking for the service, or during combat.

## Constraints (checked 2026-11-25)

- Forever client, Interface 16001, Lua 5.1; only API listed in wowbench `api/client.txt`.
- `C_ChatInfo.SendChatMessage` / `SendChatMessage`: `HasRestrictions`,
  `RestrictedForMacroChatMessages`. Channel posts must come from a hardware event (key binding,
  button click, a slash command typed by hand). Whispers from an event handler are expected to work
  but must be confirmed in game before auto-whisper ships.
- `CHAT_MSG_CHANNEL`, `CHAT_MSG_WHISPER` (and the say/yell events): `SecretInChatMessagingLockdown`.
  `text` and `playerName` can be secret; `channelName`, `zoneChannelID`, `channelIndex` are never
  secret. Check with `lib.IsSecret` and skip the message when text or sender is secret.
- Present in the client: `C_PartyInfo.InviteUnit`, `GetChannelName`, `GetChannelList`,
  `C_ChatInfo.GetChannelInfoFromIdentifier`, `SetItemRef`, `ChatFrame_AddMessageEventFilter`,
  `ChatFrame_OpenChat`, `PlaySound`, `C_SpellBook.IsSpellKnown`/`IsSpellKnown`, `UnitLevel`,
  `C_TradeSkillUI.GetProfessionInfoBySkillLineID`. Missing: `GetSkillLineInfo`,
  `GetNumSkillLines`, `GetSpellInfo`.
- The Trade channel exists only in cities; announcing elsewhere must say so instead of erroring.
- LibBound rules: everything per addon through `ns`; `MINOR` bump (32 → 33); every embedding addon's
  scenarios stay green after `tools/sync-libbound.sh`; docs in `docs/api/` updated with the API.

## Approaches

- **A. Shared module in LibBound (picked by Marius: "uten tvil a").** One implementation of announce,
  templates, matching and the chat line; addons pass data. Costs a LibBound release and a sync into
  both addons.
- **B. Built into each addon.** Faster start, but the matching and chat line would be duplicated and
  drift apart.

## Design

### Addon side: `lib.InstallService(ns, service)`

Called by the addon (not by `NewAddon` for everyone: only addons with a service). `service`:

```lua
lib.InstallService(ns, {
  key = "portals",                       -- settings prefix and link id
  label = "Portals",                     -- options page and chat line
  example = "Portals to {portals}! Whisper \"port {short}\", tips welcome :)", -- {short} = org/uc/tb
  reply = "Hi {name}! Inviting you for a portal, I'm in {zone}.",  -- auto-whisper example
  keywords = { "port", "portal", "portals" },        -- fire on their own
  weak = { "port", "ports" },
  targets  = { org = "Orgrimmar", orgrimmar = "Orgrimmar", uc = "Undercity",
               undercity = "Undercity", tb = "Thunder Bluff", ["thunder bluff"] = "Thunder Bluff" },
               -- Alliance: sw, stormwind, ironforge, darn, darnassus (no "if": an ordinary word)
  available = function() return true end,  -- false: the service can't be offered (no portal known)
  fill = { portals = function() ... end, runes = function() ... end }, -- placeholders
})
```

- Chronobound: `{portals}` = names of the faction's portals the player knows (from its Travel data,
  `IsSpellKnown`), comma-joined; `{runes}` = Rune of Portals count (17032). `available` = knows at
  least one portal.
- Shadowbound: `keywords = lockbox, lockboxes, junkbox, lockpick, lockpicking, "open box"`, no
  targets. `{skill}` = lockpicking skill. `available` = knows Pick Lock (1804).
- Shared placeholders always available: `{name}` (the customer, reply only), `{zone}`,
  `{level}`, `{target}` (matched city, reply only).

**Lockpicking skill:** `C_TradeSkillUI.GetProfessionInfoBySkillLineID(633).skillLevel` (see
In-game probes). When it is 0 or missing while Pick Lock is known, the options page shows a number
field and `{skill}` uses it. No `UnitLevel()*5` guess.

### Matching (pure function, unit-tested)

`Service.Match(text, service, fromWhisper)` → `nil` or `{ target = "Orgrimmar" | nil }`.

- Lowercase, strip item/colour links, split into words (letters/digits). Multi-word triggers
  ("thunder bluff", "open box") match as consecutive words.
- Two word lists per service: **keywords** (the thing: `portal(s)`, `lockbox(es)`, `junkbox`,
  `lockpick(ing)`, `open box`) and **targets** (cities). `port` is an intent word and a **weak**
  keyword: it counts as the thing only next to another intent word ("need a port pls", "lf port"),
  never alone ("lol port"). *(Added after the final review: the most common requests missed.)*
- In public channels it fires only when an **intent word** (`wtb, lf, lfm, need, needs, any,
  anyone, port, plz, pls, please, can, someone`, or a `?` in the text) appears together with a
  keyword or a target. In a whisper to him, a keyword or a target alone is enough. *(Builder's call,
  for the "few false alerts" goal: "lol port" or a bare "portal" in Trade does not fire.)*
- Ignores: his own messages; **competing offers**: text with `wts`, `selling`, `offering`, `/w`,
  `whisper me`, `w me`, `tips` or `lf customers` *(builder's call: a rival "Portals to Org/UC/TB, /w
  me, tips welcome" would otherwise alert every minute)*; the same sender again within 60 s.
- Channels listened to: Trade, General, LookingForGroup, Say, Yell, Whisper. Matching on channel
  number/name uses never-secret fields.

### On a match

- Sound (one short sound, toggle) and one chat line in the default chat frame:
  `[Chronobound] Thrall: wtb port org  [Invite] [Whisper]`. The links are custom hyperlinks
  handled through `SetItemRef` (hook); Invite calls `C_PartyInfo.InviteUnit(name)`, Whisper opens
  the chat box with `/w name `. Custom links work on Forever, also in EllesmereUIChat
  (probe 1).
- Auto-whisper (off by default): sends the reply template once per sender per 10 minutes, never in
  combat, never when `available()` is false. It ships in this release as a toggle (off); the
  client allows whispers from an event handler (probe 3).
- Marius uses **EllesmereUIChat** (enabled on his characters): the chat line goes through `print`
  / the default chat frame, which it shows.

### Announce

- A key binding (via `UI.KeyButton`, setting `<key>AnnounceKey`), a slash sub-command
  (`/cb announce`, `/shadow announce`) and a button on the options page post the filled message to
  the chosen channel (default Trade, found by name via `GetChannelList`).
- Not in Trade's range (no Trade channel): a chat note "Not in a city: no Trade channel", nothing
  sent.
- Minimum interval between posts (default 60 s, setting): a press inside it prints the seconds left
  instead of posting.
- Empty placeholders: an unknown `{x}` is left as is; `available() == false` refuses with a note
  ("You know no portals yet").

### Settings (per addon db, under the service key)

`<key>On` (listen on/off, default on when `available`), `<key>Message`, `<key>Triggers` (extra
words the user added; the built-in lists stay), `<key>Channel` ("Trade"), `<key>Interval` (60),
`<key>Sound` (true), `<key>AutoWhisper` (false), `<key>Reply`. Defaults added through
`lib.SHARED_DEFAULTS`-style merge inside `InstallService`.

### Options page

A "Service" page (`UI.NewPage`): on/off, message box with "Reset to example" and a live preview of
the filled message, extra trigger words, channel, interval, sound, the announce key, auto-whisper
toggle with its reply box. **LibBound has no text input widget yet:** add `UI.EditBox` (single and
multi-line) to `Options.lua` and document it.

## In-game probes (done 2026-11-25)

1. **Custom links work in EllesmereUIChat**: `print("\124Haddon:bound:test\124h[Klikk meg]\124h")`
   rendered as a link, and a click reached a `SetItemRef` hook (`addon:bound:test`). Build the
   [Invite]/[Whisper] links; no popup. (Type `\124` for `|` in `/run`: the edit box escapes pipes.)
2. **Lockpicking**: `C_TradeSkillUI.GetProfessionInfoBySkillLineID(633)` returns
   `professionName = "Lockpicking"`, skill 0/0 on a non-rogue. Not yet seen on a rogue with Pick Lock
   (his rogue is below 16). Use the API; when it gives 0 while Pick Lock (1804) is known, show a
   number field and use that. Marius re-runs the probe once his rogue has Pick Lock.
3. **Whisper from an event handler**: `C_ChatInfo.SendChatMessage(..., "WHISPER", ...)` inside a
   `CHAT_MSG_SAY` handler returned `true` (not blocked by the client); the server answered "No player
   named ... is currently playing" because it was a whisper to himself. Auto-whisper ships as a
   toggle (off).
4. Keep `/run` probe lines under 255 characters (the edit box limit cut one off silently).

## Tests

- Unit (`lua5.1`): `Service.Match` table of cases, including false positives ("going to org later",
  "ucla", "wts portals"), multi-word triggers, links stripped, whisper rule; template fill.
- wowbench scenarios in LibBound and in both addons: announce posts the filled text to Trade;
  outside a city prints the note; interval blocks a second post; a matching `CHAT_MSG_CHANNEL`
  prints the line once (dedupe); secret text is skipped without error; auto-whisper off by default.
- In game (Marius): the announce key posts in Trade; the [Invite]/[Whisper] links work in
  EllesmereUIChat; an alert fires on a real request and not on a rival's ad.

## Rollout

LibBound PR (Service.lua, EditBox, docs `docs/api/service.md`, MINOR 33, this spec; exclude
`docs/superpowers` from the Jekyll site) → sync into Chronobound and Shadowbound with their service
declarations, help texts and CHANGELOG → `tools/sync-libbound.sh && wowbench test .` in every
embedding addon → Codex review before each commit → PRs.

## Left to the builder

Which other Bound addons only get the synced library (all embedders' tests must stay green), whether `<key>On` is stored or follows `available()` live, how the announce key is bound (override binding like BuffKey), where the link hook lives, exact wording of notes and help texts, the alert sound, layout of the options page, how extra trigger words are entered (comma list is fine).
