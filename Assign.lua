-- LibBound assignments: who in the group casts each raid-wide buff (the Prayers, Gift of the Wild,
-- Arcane Brilliance, Amplify/Dampen Magic) and who a caster keeps Thorns or Fear Ward on. It speaks
-- the addon-message protocol of LibGroupBuffs-1.0 (v1, prefix "LibGroupBuffs"), so a Bound priest
-- and a priest on Buffy, Priestly, Wildly or Magely share the same assignments. The protocol and
-- the rules below are ported from LibGroupBuffs (MIT, Copyright (c) 2026 Spotnick2,
-- github.com/Spotnick2/LibGroupBuffs, Assign section). Keep both in step: the slot table, the
-- message format and the record order are protocol, and the same in every copy.
--
-- For the addons (via the buff key: give a group buff entry `slot = <its slot key>`, the first
-- rank's spell ID, e.g. 1243 for Power Word: Fortitude):
--   lib.AssignOwner(key)       -> owner name or nil, true when it is you (a live owner only: in the
--                                 group, online, heard from within 180 s and able to cast the
--                                 slot's group spell; otherwise the slot counts as nobody's)
--   lib.AssignRecorded(key)    -> the recorded owner, live or not (for "away")
--   lib.AssignSet(key, name)   -> ok, why: claim (your name), hand over (theirs) or clear (nil);
--                                 why = "group", "combat", "invalid", "version", "size"
--   lib.AssignSlots(class)     -> the owner slots of that class, in protocol order
--   lib.AssignWatch(fn)        -> fn() whenever who owns what may have changed
--   lib.AssignBackend()        -> "own", "LibGroupBuffs" (another addon on this client already
--                                 runs the protocol: we read and edit its state and send nothing
--                                 ourselves) or nil (not started)
-- The buff key (BuffKey.lua) leaves out a group buff someone else owns and gives you the ones you
-- own even when their toggle is off. The "Group" options page has the claim/release rows.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local PREFIX, PROTO, SEP = "LibGroupBuffs", "1", "^"
local MAX_BYTES = 255
local HELLO_PERIOD, HELLO_JITTER, PEER_TTL = 60, 10, 180
local VER_SCALE, VER_AHEAD, VER_DIGITS = 1000, 86400, 16
local BUCKET, REFILL, BACKOFF = 10, 1, 2
local PRIO_EDIT, PRIO_HELLO, PRIO_REPAIR = 1, 2, 3
local HOME = LE_PARTY_CATEGORY_HOME or 1
local INSTANCE = LE_PARTY_CATEGORY_INSTANCE or 2

-- protocol v1's slots: `needs` is the spell an owner must know (the group form for the raid-wide
-- buffs); a slot with `choices` is owned with one of them; `label` names it
local SLOTS = {
	{ key = 1243, class = "PRIEST", kind = "owner", needs = 21562, label = 21562 }, -- Prayer of Fortitude
	{ key = 14752, class = "PRIEST", kind = "owner", needs = 27681, label = 27681 }, -- Prayer of Spirit
	{ key = 976, class = "PRIEST", kind = "owner", needs = 27683, label = 27683 }, -- Prayer of Shadow Protection
	{ key = 6346, class = "PRIEST", kind = "targets", needs = 6346, label = 6346 }, -- Fear Ward
	{ key = 1126, class = "DRUID", kind = "owner", needs = 21849, label = 21849 }, -- Gift of the Wild
	{ key = 467, class = "DRUID", kind = "targets", needs = 467, label = 467 }, -- Thorns
	{ key = 1459, class = "MAGE", kind = "owner", needs = 23028, label = 23028 }, -- Arcane Brilliance
	{ key = 1008, class = "MAGE", kind = "owner", choices = { 1008, 604 }, label = 1008 }, -- Amplify / Dampen
}
local SLOT_BY_KEY = {}
for _, s in ipairs(SLOTS) do SLOT_BY_KEY[s.key] = s end
lib.ASSIGN_SLOTS = SLOTS

-- the implementation: every function takes the client first and reaches the game only through
-- its env, so the tests run several clients on one simulated channel. Frame scripts and timers
-- call lib.AssignImpl.<name>, so a newer LibBound copy's code is what runs.
lib.AssignImpl = lib.AssignImpl or {}
local AI = lib.AssignImpl

local function Split(s, sep)
	local out, start = {}, 1
	while true do
		local i = s:find(sep, start, true)
		if not i then out[#out + 1] = s:sub(start) return out end
		out[#out + 1] = s:sub(start, i - 1)
		start = i + 1
	end
end
local function Names(value) if value == "" then return {} end return Split(value, ",") end

-- the game, behind one table (names are read protected: a secret value throws when compared).
-- GetUnitName(unit, false) is what CHAT_MSG_ADDON's sender matches (measured by LibGroupBuffs);
-- UnitName only when it gives nothing
local function NameOf(unit)
	local ok, n = pcall(function()
		for _, name in ipairs({ GetUnitName and GetUnitName(unit, false) or false, (UnitName(unit)) or false }) do
			if type(name) == "string" and name ~= "" and name ~= UNKNOWNOBJECT then return name end
		end
	end)
	return ok and n or nil
end
local ENV = {}
function ENV.now() return GetTime() end
function ENV.serverNow()
	local ok, t = pcall(GetServerTime)
	return math.floor(ok and type(t) == "number" and t or GetTime())
end
function ENV.send(msg, channel) return C_ChatInfo.SendAddonMessage(PREFIX, msg, channel) end
function ENV.lockdown()
	local f = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	if not f then return false end
	local ok, v = pcall(f)
	return ok and v == true
end
function ENV.combat() return InCombatLockdown() and true or false end
function ENV.after(delay, fn) C_Timer.After(delay, fn) end
function ENV.random() return math.random() end
function ENV.category()
	if IsInGroup(HOME) then return HOME end
	if IsInGroup(INSTANCE) then return INSTANCE end
end
function ENV.channel(category)
	if category == INSTANCE then return "INSTANCE_CHAT" end
	return IsInRaid(category) and "RAID" or "PARTY"
end
function ENV.roster() -- name -> { class, online }, and your own name
	local out, units = {}, { "player", "party1", "party2", "party3", "party4" }
	if IsInRaid() then
		units = {}
		for i = 1, GetNumGroupMembers() do units[i] = "raid" .. i end
	end
	for _, unit in ipairs(units) do
		if UnitExists(unit) then
			local name = NameOf(unit)
			if name then
				local _, class = UnitClass(unit)
				out[name] = { class = class, online = UnitIsConnected(unit) and true or false }
			end
		end
	end
	return out, NameOf("player")
end
function ENV.knows(id)
	local ok, k = pcall(IsPlayerSpell, id)
	return ok and k == true
end
function ENV.myClass() local _, c = UnitClass("player") return c end
local function Env(c) return c.env or ENV end

-- records -----------------------------------------------------------------------------------

-- a total order, so every client keeps the same winner whatever order messages come in
local function Newer(a, b)
	if not b then return true end
	if not a then return false end
	if a.ver ~= b.ver then return a.ver > b.ver end
	if a.writer ~= b.writer then return a.writer > b.writer end
	return a.value > b.value
end
AI.Newer = Newer

-- one checksum over every record (other classes and clears too), as LibGroupBuffs computes it
local function Digest(records)
	local keys = {}
	for k in pairs(records) do keys[#keys + 1] = k end
	if #keys == 0 then return "0" end
	table.sort(keys)
	local h = 5381
	for _, k in ipairs(keys) do
		local r = records[k]
		local s = k .. "|" .. r.ver .. "|" .. r.writer .. "|" .. r.value .. "\n"
		for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
	end
	return string.format("%08x", h)
end
AI.Digest = Digest

local function EncodeRecord(key, r) return table.concat({ PROTO, "A", key, tostring(r.ver), r.writer, r.value }, SEP) end
AI.EncodeRecord = EncodeRecord

-- a key names an owner slot ("1243") or a caster's list on a targets slot ("467:Name")
local function ParseKey(key)
	local id, caster = key:match("^(%d+):(.+)$")
	if id then
		local slot = SLOT_BY_KEY[tonumber(id)]
		if slot and slot.kind == "targets" then return slot, caster end
		return nil
	end
	local slot = SLOT_BY_KEY[tonumber(key) or -1]
	if slot and slot.kind == "owner" and tostring(slot.key) == key then return slot end
end
local function ValidName(name) return name ~= "" and not name:find("[%^,:|]") end
local function ValidValue(slot, value)
	if value == "" then return true end
	if slot.kind == "targets" then
		for _, n in ipairs(Names(value)) do if not ValidName(n) then return false end end
		return true
	end
	local owner, choice = value:match("^([^,]+),(%d+)$")
	if slot.choices then
		if not owner then return false end
		for _, id in ipairs(slot.choices) do
			if id == tonumber(choice) then return ValidName(owner) end
		end
		return false
	end
	return ValidName(value)
end
local function ParseOwner(slot, value)
	if value == "" then return nil end
	if slot.choices then
		local owner, choice = value:match("^([^,]+),(%d+)$")
		return owner, tonumber(choice)
	end
	return value
end

-- the client ----------------------------------------------------------------------------------

function AI.Fill(c)
	c.records = c.records or {}
	c.peers = c.peers or {}
	c.queue = c.queue or {}
	c.seq = c.seq or 0
	c.subs = c.subs or {}
	c.roster = c.roster or {}
	c.mySpells = c.mySpells or {}
	c.spellList = c.spellList or ""
	c.gen = c.gen or 0
	c.effective = c.effective or ""
	return c
end
function AI.NewClient(env) return AI.Fill({ env = env }) end

function AI.Wipe(c)
	c.records, c.peers, c.queue = {}, {}, {}
	c.repair, c.blockedUntil = nil, nil
	c.gen = c.gen + 1
end

-- a peer's age stands still while chat is locked down (nobody can say hello then)
function AI.LockClock(c)
	local env = Env(c)
	local now = env.now()
	if c.chatRestricted or env.lockdown() then
		c.lockedAt = c.lockedAt or now
	elseif c.lockedAt then
		local from = c.lockedAt
		c.lockedAt = nil
		for _, peer in pairs(c.peers) do
			if peer.seen < from then peer.seen = peer.seen + (now - from) else peer.seen = now end
		end
	end
end

-- is `name` in the group now and able to cast `spell`
local function Capable(c, name, spell)
	if not name or not spell then return false end
	if name == c.me then return c.mySpells[spell] == true end
	local member, peer = c.roster[name], c.peers[name]
	if not member or not member.online or not peer or not peer.spells[spell] then return false end
	AI.LockClock(c)
	return c.lockedAt ~= nil or Env(c).now() - peer.seen <= PEER_TTL
end
AI.Capable = Capable

function AI.Owner(c, slot)
	local rec = c.records[tostring(slot.key)]
	if not rec then return nil end
	local owner, choice = ParseOwner(slot, rec.value)
	if owner and Capable(c, owner, choice or slot.needs) then return owner, choice end
end
function AI.RecordedOwner(c, slot)
	local rec = c.records[tostring(slot.key)]
	if rec then return ParseOwner(slot, rec.value) end
end
function AI.Targets(c, slot, caster)
	local rec = caster and c.records[slot.key .. ":" .. caster]
	return rec and Names(rec.value) or {}
end

-- who owns what, and whether we're in a group at all (joining enables the Take buttons)
local function Effective(c)
	local parts = { tostring(c.group) .. "," .. tostring(c.me) }
	for _, slot in ipairs(SLOTS) do
		if slot.kind == "owner" then
			local owner, choice = AI.Owner(c, slot)
			-- the recorded owner too: the rows show an away owner
			parts[#parts + 1] = tostring(owner) .. "," .. tostring(choice) .. "," .. tostring((AI.RecordedOwner(c, slot)))
		else
			parts[#parts + 1] = table.concat(AI.Targets(c, slot, c.me), ",")
		end
	end
	return table.concat(parts, ";")
end

function AI.Changed(c)
	local now = Effective(c)
	if now == c.effective then return end
	c.effective = now
	for _, sub in ipairs(c.subs) do
		if sub.onChanged then pcall(sub.onChanged) end
	end
end

function AI.Apply(c, key, rec)
	if c.repair and Newer(rec, c.repair.seen[key]) then c.repair.seen[key] = rec end
	if not Newer(rec, c.records[key]) then return false end
	c.records[key] = rec
	return true
end

-- sending: one queue entry per key, a token bucket as the client's throttle (about 10, then 1 a
-- second; it DROPS what it refuses, so an entry leaves the queue only once the client took it)
local function Enqueue(c, qkey, prio, msg, rec)
	local old = c.queue[qkey]
	if old and rec and old.rec and Newer(old.rec, rec) then return end
	c.seq = c.seq + 1
	c.queue[qkey] = { qkey = qkey, prio = old and math.min(old.prio, prio) or prio, seq = c.seq, msg = msg, rec = rec }
end
local function NextEntry(c)
	local best
	for _, e in pairs(c.queue) do
		if not best or e.prio < best.prio or (e.prio == best.prio and e.seq < best.seq) then best = e end
	end
	return best
end

function AI.HelloMessage(c)
	return table.concat({ PROTO, "H", c.myClass or "", c.spellList, Digest(c.records) }, SEP)
end

function AI.SchedulePump(c, delay)
	local env = Env(c)
	local at = env.now() + delay
	if c.pumpAt and c.pumpAt <= at then return end
	c.pumpAt = at
	env.after(delay, function() return lib.AssignImpl.Pump(c) end)
end

function AI.Pump(c)
	c.pumpAt = nil
	if c.stopped or not c.group or not c.channel then c.queue = {} return end
	local env = Env(c)
	local now = env.now()
	c.tokens = math.min(BUCKET, (c.tokens or BUCKET) + (now - (c.refilled or now)) * REFILL)
	c.refilled = now
	if c.blockedUntil and now < c.blockedUntil then return AI.SchedulePump(c, c.blockedUntil - now) end
	if env.lockdown() then return AI.SchedulePump(c, BACKOFF) end
	while c.tokens >= 1 do
		local e = NextEntry(c)
		if not e then return end
		local ok, res = pcall(env.send, e.msg or AI.HelloMessage(c), c.channel)
		if ok and (res == 0 or res == nil or res == true) then
			c.queue[e.qkey] = nil
			c.tokens = c.tokens - 1
			if e.rec and c.repair then
				local key = e.qkey:sub(3)
				if Newer(e.rec, c.repair.seen[key]) then c.repair.seen[key] = e.rec end
			end
		elseif ok and (res == 3 or res == 8 or res == 11) then -- throttled or locked down: try again
			c.blockedUntil = now + BACKOFF
			return AI.SchedulePump(c, BACKOFF)
		else
			c.queue[e.qkey] = nil -- not in a group (5) or refused: drop it
		end
	end
	if next(c.queue) then AI.SchedulePump(c, 1 / REFILL) end
end

function AI.SendHello(c)
	if not c.group or not c.me then return end
	Enqueue(c, "H", PRIO_HELLO)
	AI.SchedulePump(c, 0)
end
-- soon, not now: a burst of roster events or new peers sends one hello
function AI.HelloSoon(c)
	if c.helloSoon or not c.group then return end
	c.helloSoon = true
	local env = Env(c)
	env.after(1 + env.random() * 2, function() return lib.AssignImpl.HelloSoonFire(c) end)
end
function AI.HelloSoonFire(c) c.helloSoon = nil AI.SendHello(c) end
function AI.StartHelloLoop(c)
	c.helloGen = (c.helloGen or 0) + 1
	local gen, env = c.helloGen, Env(c)
	env.after(HELLO_PERIOD + (env.random() * 2 - 1) * HELLO_JITTER, function() return lib.AssignImpl.HelloTick(c, gen) end)
end
function AI.HelloTick(c, gen)
	if gen ~= c.helloGen or not c.group or c.stopped then return end
	AI.Expire(c)
	AI.SendHello(c)
	AI.StartHelloLoop(c)
	AI.Changed(c)
end

-- repair: a peer whose digest differs from ours gets, once and a few seconds later, every record
-- the channel has not carried in the meantime (so a joiner in a full raid is answered about once)
function AI.ScheduleRepair(c)
	if c.repair then return end
	c.repair = { seen = {}, gen = c.gen }
	local env = Env(c)
	env.after(1 + env.random() * 4, function() return lib.AssignImpl.RepairFire(c) end)
end
function AI.RepairFire(c)
	local rep = c.repair
	c.repair = nil
	if not rep or rep.gen ~= c.gen or not c.group or c.stopped then return end
	local mine, differs = Digest(c.records), false
	for name, peer in pairs(c.peers) do
		if peer.digest ~= mine and c.roster[name] then differs = true break end
	end
	if not differs then return end
	for key, rec in pairs(c.records) do
		if Newer(rec, rep.seen[key]) then Enqueue(c, "A:" .. key, PRIO_REPAIR, EncodeRecord(key, rec), rec) end
	end
	AI.SchedulePump(c, 0)
end

-- receiving
local function Plain(text, channel, sender)
	return type(text) == "string" and type(channel) == "string" and type(sender) == "string"
		and #text <= MAX_BYTES and channel ~= "" and sender ~= ""
end

-- a version as sent: digits, no sign or leading zero, at most a day past the server's clock
function AI.ParseVersion(c, text)
	if type(text) ~= "string" or #text > VER_DIGITS or not text:match("^[1-9]%d*$") then return nil end
	local ver = tonumber(text)
	if not ver or ver > (Env(c).serverNow() + VER_AHEAD) * VER_SCALE then return nil end
	return ver
end

function AI.Receive(c, text, channel, sender)
	local ok, plain = pcall(Plain, text, channel, sender)
	if not ok or not plain or c.stopped then return end
	if not c.group or channel ~= c.channel or sender == c.me then return end
	local member = c.roster[sender]
	if not member then return end
	local f = Split(text, SEP)
	if f[1] ~= PROTO then return end
	if f[2] == "H" and #f == 5 then
		if f[3] ~= member.class then return end
		local spells = {}
		for id in f[4]:gmatch("%d+") do spells[tonumber(id)] = true end
		local isNew = c.peers[sender] == nil
		c.peers[sender] = { class = f[3], spells = spells, digest = f[5], seen = Env(c).now() }
		if isNew then AI.HelloSoon(c) end
		if f[5] ~= Digest(c.records) then AI.ScheduleRepair(c) end
		AI.Changed(c)
	elseif f[2] == "A" and #f == 6 then
		local key, ver, writer, value = f[3], AI.ParseVersion(c, f[4]), f[5], f[6]
		local slot = ParseKey(key)
		if not slot or not ver or not ValidName(writer) or not ValidValue(slot, value) then return end
		if AI.Apply(c, key, { ver = ver, writer = writer, value = value }) then AI.Changed(c) end
	end
end

-- the group
function AI.Expire(c)
	AI.LockClock(c)
	if c.lockedAt then return end
	local now = Env(c).now()
	for name, peer in pairs(c.peers) do
		if not c.roster[name] or now - peer.seen > PEER_TTL then c.peers[name] = nil end
	end
end

-- records, peers, timers and the queue belong to the selected group: a new one starts them again
function AI.RosterChanged(c)
	local env = Env(c)
	local category = env.category()
	if category ~= c.group then
		AI.Wipe(c)
		c.group = category
		c.helloGen = (c.helloGen or 0) + 1
		if category then
			c.channel = env.channel(category)
			c.roster, c.me = env.roster()
			AI.StartHelloLoop(c)
			AI.HelloSoon(c)
		else
			c.channel, c.roster, c.me = nil, {}, nil
		end
	elseif category then
		c.channel = env.channel(category)
		c.roster, c.me = env.roster()
	end
	AI.Expire(c)
	AI.Changed(c)
end

-- what you can cast, from your own spellbook; a change goes out in a hello
function AI.SpellsChanged(c)
	local env = Env(c)
	c.myClass = env.myClass()
	local known, list = {}, {}
	for _, slot in ipairs(SLOTS) do
		if slot.class == c.myClass then
			for _, id in ipairs(slot.choices or { slot.needs }) do
				if not known[id] and env.knows(id) then known[id] = true list[#list + 1] = id end
			end
		end
	end
	table.sort(list)
	local text = table.concat(list, ",")
	c.mySpells = known
	if text ~= c.spellList then
		c.spellList = text
		AI.HelloSoon(c)
	end
	AI.Changed(c)
end

-- one edit: refused out of a group, in combat, and when the message would not arrive whole
function AI.Edit(c, key, value)
	local env = Env(c)
	if not c.group or not c.me then return false, "group" end
	if env.combat() then return false, "combat" end
	local slot = ParseKey(key)
	if not slot or not ValidValue(slot, value) then return false, "invalid" end
	local cur = c.records[key]
	local ver = env.serverNow() * VER_SCALE
	if cur and cur.ver >= ver then ver = cur.ver + 1 end
	if ver > (env.serverNow() + VER_AHEAD) * VER_SCALE then return false, "version" end
	local rec = { ver = ver, writer = c.me, value = value }
	local msg = EncodeRecord(key, rec)
	if #msg > MAX_BYTES then return false, "size" end
	c.records[key] = rec
	Enqueue(c, "A:" .. key, PRIO_EDIT, msg, rec)
	AI.SchedulePump(c, 0)
	AI.Changed(c)
	return true
end
function AI.SetOwner(c, slot, owner, choice)
	local value = ""
	if owner then value = slot.choices and (owner .. "," .. tostring(choice or slot.choices[1])) or owner end
	return AI.Edit(c, tostring(slot.key), value)
end

-- the live client ---------------------------------------------------------------------------

lib.assign = AI.Fill(lib.assign or {})

-- LibGroupBuffs running its own client on this game client (Buffy and the like): then it is the
-- one that talks, and ours stays quiet (two clients would send every hello twice)
local function Other()
	local G = LibStub("LibGroupBuffs-1.0", true)
	if G and type(G.assign) == "table" and G.assign.frame and type(G.AssignImpl) == "table"
		and G.AssignImpl.Owner and G.AssignImpl.SetOwner and G.ASSIGN_SLOTS then
		return G
	end
end

local EVENTS = { "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "GROUP_JOINED", "GROUP_LEFT", "PLAYER_ENTERING_WORLD",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_CONNECTION", "SPELLS_CHANGED", "ADDON_RESTRICTION_STATE_CHANGED" }

function AI.OnEvent(c, event, ...)
	if c.stopped then return end
	if Other() then return AI.Stop(c) end
	if event == "CHAT_MSG_ADDON" then
		local prefix, text, channel, sender = ...
		if prefix == PREFIX then return AI.Receive(c, text, channel, sender) end
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		AI.LockClock(c)
	elseif event == "SPELLS_CHANGED" then
		AI.SpellsChanged(c)
	elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
		local kind, state = ...
		local E = rawget(_G, "Enum")
		local CHAT = E and E.AddOnRestrictionType and E.AddOnRestrictionType.Chat or 5
		local INACTIVE = E and E.AddOnRestrictionState and E.AddOnRestrictionState.Inactive or 0
		if kind == CHAT and type(state) == "number" then
			c.chatRestricted = state ~= INACTIVE or nil
			AI.LockClock(c)
			AI.Changed(c)
		end
	else
		local wasGroup = c.group
		AI.RosterChanged(c)
		if event == "PLAYER_ENTERING_WORLD" and wasGroup and c.group == wasGroup then AI.HelloSoon(c) end
	end
end

function AI.Start(c)
	if c.frame or c.stopped then return end
	local frame = CreateFrame("Frame")
	c.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) return lib.AssignImpl.OnEvent(lib.assign, event, ...) end)
	for _, e in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, e) end
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	AI.SpellsChanged(c)
	AI.RosterChanged(c)
end

-- the other client took over: ours stops for good (until a /reload)
function AI.Stop(c)
	c.stopped = true
	if type(c.frame) == "table" then c.frame:UnregisterAllEvents() end
	AI.Wipe(c)
	c.group = nil
	local G = Other()
	if G and not c.bridged then
		c.bridged = true
		table.insert(G.assign.subs, { onChanged = function() for _, fn in ipairs(c.watchers or {}) do pcall(fn) end end })
	end
	for _, fn in ipairs(c.watchers or {}) do pcall(fn) end
end

-- the addons' side -----------------------------------------------------------------------------

-- the client and implementation that answer now: LibGroupBuffs' when it runs, else ours
local function Backend()
	local c = lib.assign
	if not c.frame and not c.stopped then return nil end
	if not c.stopped and Other() then AI.Stop(c) end
	local G = c.stopped and Other()
	if G then
		local slots = {}
		for _, s in ipairs(G.ASSIGN_SLOTS) do slots[s.key] = s end
		return G.assign, G.AssignImpl, slots, "LibGroupBuffs"
	end
	if c.stopped then return nil end
	return c, AI, SLOT_BY_KEY, "own"
end

function lib.AssignBackend() return select(4, Backend()) end

function lib.AssignOwner(key)
	local c, impl, slots = Backend()
	local slot = c and slots[key]
	if not slot or slot.kind ~= "owner" then return nil end
	local ok, owner = pcall(impl.Owner, c, slot)
	if not ok or not owner then return nil end
	return owner, owner == c.me
end

function lib.AssignRecorded(key)
	local c, impl, slots = Backend()
	local slot = c and slots[key]
	if not slot or slot.kind ~= "owner" or not impl.RecordedOwner then return nil end
	local ok, owner = pcall(impl.RecordedOwner, c, slot)
	return ok and owner or nil
end

function lib.AssignMe()
	local c = Backend()
	return c and c.group and c.me or nil
end

function lib.AssignSet(key, name)
	local c, impl, slots = Backend()
	local slot = c and slots[key]
	if not slot or slot.kind ~= "owner" then return false, "invalid" end
	local ok, done, why = pcall(impl.SetOwner, c, slot, name)
	if not ok then return false, "invalid" end
	return done, why
end

function lib.AssignSlots(class)
	local out = {}
	for _, s in ipairs(SLOTS) do
		if s.class == class and s.kind == "owner" then out[#out + 1] = s end
	end
	return out
end

function lib.AssignWatch(fn)
	local c = lib.assign
	c.watchers = c.watchers or {}
	c.watchers[#c.watchers + 1] = fn
	if not c.watchSub then
		c.watchSub = true
		table.insert(c.subs, { onChanged = function() for _, f in ipairs(c.watchers) do pcall(f) end end })
	end
end

-- a slot's name in the player's language (its group spell), e.g. "Prayer of Fortitude"
function lib.AssignLabel(key)
	local slot = SLOT_BY_KEY[key]
	if not slot then return tostring(key) end
	local names = {}
	for _, id in ipairs(slot.choices or { slot.label }) do
		local ok, n = pcall(function() return C_Spell.GetSpellName(id) end)
		names[#names + 1] = ok and type(n) == "string" and n or ("spell " .. id)
	end
	return table.concat(names, " / ")
end

-- why an edit was refused, in plain words
local WHY = { group = "join a group first.", combat = "leave combat first.", invalid = "that can't be assigned.",
	version = "the server clock looks wrong, try again.", size = "the name is too long to send." }

-- the claim/release text for one slot: what the row says and what the button does
function lib.AssignState(key)
	local backend = lib.AssignBackend()
	if not backend then return "Not started", nil end
	local me = lib.AssignMe()
	if not me then return "Not in a group", nil end
	local owner, mine = lib.AssignOwner(key)
	if mine then return "You", "Release" end
	local away = lib.AssignRecorded(key)
	if away == me then return "You (can't cast it)", "Release" end
	-- Take only with the group spell: an owner who can't cast it never counts
	local slot = SLOT_BY_KEY[key]
	local can = false
	for _, id in ipairs(slot and (slot.choices or { slot.needs }) or {}) do
		local ok, k = pcall(IsPlayerSpell, id)
		if ok and k == true then can = true end
	end
	local take = can and "Take" or nil
	if owner then return owner, take end
	if away then return away .. " (away)", take end
	return can and "Nobody" or "Nobody (you can't cast it yet)", take
end

-- claim the slot for yourself, or release it (the button and /<slash> assign)
function lib.AssignToggle(ns, key)
	local _, action = lib.AssignState(key)
	if not action then
		ns.Print(lib.AssignMe() and (lib.AssignLabel(key) .. ": you can't cast it yet, so you can't have it.") or WHY.group)
		return
	end
	ns.assignEditAt = GetTime()
	local ok, why = lib.AssignSet(key, action == "Take" and lib.AssignMe() or nil)
	if not ok then ns.Print(WHY[why] or tostring(why)) return end
	ns.Print(lib.AssignLabel(key) .. (action == "Take" and ": yours now." or ": released, nobody is assigned."))
end

-- the "Group" page (Options.lua builds it after Extras): one row per slotted buff. Its own page:
-- the Extras page has no room left (pages don't scroll)
function lib.AssignPage(ns, UI, W)
	local slotted = {}
	for _, g in ipairs(ns.groupBuffs or {}) do if g.slot and SLOT_BY_KEY[g.slot] then slotted[#slotted + 1] = g end end
	if #slotted == 0 then return end
	local p = UI.NewPage("Group", "Who buffs the group.")
	p:Add(UI.Note(p, p.y, "Shared with the others in your group who run a Bound addon, Buffy or Priestly. "
		.. "While someone else has a buff, your buff key and the group card leave it to them. "
		.. "Only someone who can cast a buff's group version can have it.") + 8)
	p:Add(UI.Section(p, p.y, "Who buffs the group") + 2)
	local rows = {}
	for _, g in ipairs(slotted) do
		local label = UI.Font(p, 14, UI.C.text)
		label:SetPoint("TOPLEFT", 0, p.y - 5)
		local status = UI.Font(p, 12, UI.C.dim)
		status:SetPoint("TOPLEFT", math.floor(W * 0.5), p.y - 6)
		local b = UI.Button(p, "Take", 90, 22)
		b:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, p.y - 2)
		b:SetScript("OnClick", function() lib.AssignToggle(ns, g.slot) ns.assignRows.Sync() end)
		rows[#rows + 1] = { slot = g.slot, label = label, status = status, button = b }
		p:Add(30)
	end
	p:Add(UI.Note(p, p.y - 6, "Not saved: after a /reload the group is asked again. "
		.. ns.cfg.slash[1] .. " assign lists them in chat.") + 6)
	ns.assignRows = UI.Syncer(function()
		for _, r in ipairs(rows) do
			local text, action = lib.AssignState(r.slot)
			r.label:SetText(lib.AssignLabel(r.slot))
			r.status:SetText(text)
			r.button:SetLabel(action or "Take")
			r.button:SetEnabled(action ~= nil)
		end
	end)
	ns.assignRows.Sync()
end

-- /<slash> assign: who has each slotted buff; "assign 2" takes or releases the second
function lib.AssignCommand(ns, arg)
	local slotted = {}
	for _, g in ipairs(ns.groupBuffs or {}) do if g.slot and SLOT_BY_KEY[g.slot] then slotted[#slotted + 1] = g end end
	if #slotted == 0 then ns.Print("no group buffs to assign.") return end
	local n = tonumber(arg)
	if n and slotted[n] then return lib.AssignToggle(ns, slotted[n].slot) end
	ns.Print("who buffs the group (" .. ns.cfg.slash[1] .. " assign <number> takes or releases one):")
	for i, g in ipairs(slotted) do
		local text = lib.AssignState(g.slot)
		print(("  %d. %s: %s"):format(i, lib.AssignLabel(g.slot), text))
	end
end

-- started by the first addon whose group buffs carry slots (BuffKey.lua's Init)
function lib.StartAssign()
	local c = lib.assign
	if c.frame or c.stopped then return end
	if Other() then
		c.frame = true -- marks it started; the other client does the talking
		return AI.Stop(c)
	end
	AI.Start(c)
end
