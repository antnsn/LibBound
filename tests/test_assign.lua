-- Unit tests for Assign.lua: several clients on a simulated group channel (delays, reordering, the
-- client's throttle, our own messages echoed back), plus the exact wire format LibGroupBuffs v1
-- sends and accepts. Run from the repo root:
--   lua5.1 tests/test_assign.lua
local lib = { installing = 37 }
local other -- a stand-in for LibGroupBuffs-1.0, for the bridge test
LibStub = function(name) -- luacheck: ignore
	if name == "LibBound-1.0" then return lib end
	return other
end
dofile("Assign.lua")
local AI = lib.AssignImpl

local pass, fail = 0, 0
local function eq(label, got, want)
	if got == want then pass = pass + 1 else
		fail = fail + 1
		print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

local SLOT = {}
for _, s in ipairs(lib.ASSIGN_SLOTS) do SLOT[s.key] = s end
local FORT, SPIRIT, AMP = SLOT[1243], SLOT[14752], SLOT[1008]
local PRIEST = { [21562] = true, [27681] = true, [27683] = true, [6346] = true }
local MAGE = { [23028] = true, [1008] = true, [604] = true }

-- the simulated group ------------------------------------------------------------------------
local function Sim()
	local sim = { t = 0, server = 1800000000, timers = {}, seq = 0, members = {}, order = {}, seed = 7, sent = {} }
	function sim.rand()
		sim.seed = (sim.seed * 1103515245 + 12345) % 2147483648
		return sim.seed / 2147483648
	end
	function sim:at(delay, fn)
		self.seq = self.seq + 1
		self.timers[#self.timers + 1] = { at = self.t + delay, seq = self.seq, fn = fn }
	end
	function sim:run(seconds)
		local stop = self.t + seconds
		while true do
			table.sort(self.timers, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.seq < b.seq end)
			local nxt = self.timers[1]
			if not nxt or nxt.at > stop then break end
			table.remove(self.timers, 1)
			self.t = math.max(self.t, nxt.at)
			nxt.fn()
		end
		self.t = stop
	end
	function sim:roster()
		local out = {}
		for _, name in ipairs(self.order) do
			local m = self.members[name]
			if m.inGroup then out[name] = { class = m.class, online = m.online } end
		end
		return out
	end
	function sim:broadcast(from, msg, channel)
		local who = self.members[from]
		local now = self.t
		who.tokens = math.min(10, (who.tokens or 10) + (now - (who.refilled or now)))
		who.refilled = now
		if who.tokens < 1 then return 3 end -- the throttle drops it
		who.tokens = who.tokens - 1
		self.sent[#self.sent + 1] = { from = from, msg = msg }
		for _, name in ipairs(self.order) do
			local m = self.members[name]
			if m.inGroup and m.client and not (self.drop and self.drop(from, name, msg)) then
				self:at(0.1 + self.rand() * 0.4, function()
					if m.inGroup and m.client then AI.Receive(m.client, msg, channel, from) end
				end)
			end
		end
		return 0
	end
	return sim
end

local function Member(sim, name, class, spells)
	local m = { name = name, class = class, spells = spells, online = true, inGroup = true, combat = false }
	sim.members[name] = m
	sim.order[#sim.order + 1] = name
	function m:boot()
		local alive = true
		if m.kill then m.kill() end
		m.kill = function() alive = false m.client = nil end
		m.client = AI.NewClient({
			now = function() return sim.t end,
			serverNow = function() return sim.server + math.floor(sim.t) end,
			send = function(msg, channel) if not alive then return 0 end return sim:broadcast(m.name, msg, channel) end,
			lockdown = function() return false end,
			combat = function() return m.combat end,
			after = function(delay, fn) sim:at(delay, function() if alive then fn() end end) end,
			random = sim.rand,
			category = function() return m.inGroup and 2 or nil end,
			channel = function() return "RAID" end,
			roster = function() return sim:roster(), m.name end,
			knows = function(id) return m.spells[id] == true end,
			myClass = function() return m.class end,
		})
		AI.SpellsChanged(m.client)
		AI.RosterChanged(m.client)
	end
	return m
end
local function Roster(sim) for _, n in ipairs(sim.order) do local m = sim.members[n] if m.client then AI.RosterChanged(m.client) end end end

-- 1. a claim reaches the other priest, who then leaves the buff to its owner
do
	local sim = Sim()
	local a, b = Member(sim, "Anna", "PRIEST", PRIEST), Member(sim, "Bea", "PRIEST", PRIEST)
	a:boot() b:boot()
	sim:run(5)
	eq("hello: Bea knows Anna", b.client.peers.Anna ~= nil, true)
	eq("claim accepted", (AI.SetOwner(a.client, FORT, "Anna")), true)
	sim:run(2)
	eq("Bea sees Anna own Fortitude", AI.Owner(b.client, FORT), "Anna")
	eq("Anna sees herself", AI.Owner(a.client, FORT), "Anna")
	eq("Spirit stays unowned", AI.Owner(b.client, SPIRIT), nil)
	eq("same digest", AI.Digest(a.client.records), AI.Digest(b.client.records))

	-- 2. a priest who joins later gets the record through a repair
	local c = Member(sim, "Cid", "PRIEST", PRIEST)
	c:boot() Roster(sim)
	sim:run(15)
	eq("joiner repaired", AI.Owner(c.client, FORT), "Anna")

	-- 3. an owner who goes offline stops counting, the record stays (back when she is)
	a.online = false Roster(sim)
	eq("offline owner not live", AI.Owner(b.client, FORT), nil)
	eq("recorded owner kept", AI.RecordedOwner(b.client, FORT), "Anna")
	a.online = true Roster(sim)
	eq("back online counts again", AI.Owner(b.client, FORT), "Anna")

	-- 4. silent past PEER_TTL: not live (hellos dropped)
	sim.drop = function(from) return from == "Anna" end
	sim:run(200)
	eq("silent owner expires", AI.Owner(b.client, FORT), nil)
	sim.drop = nil
	sim:run(80)
	eq("hello brings her back", AI.Owner(b.client, FORT), "Anna")

	-- 5. clearing and a /reload
	eq("Bea clears it", (AI.SetOwner(b.client, FORT, nil)), true)
	sim:run(2)
	eq("cleared everywhere", AI.Owner(a.client, FORT), nil)
	a:boot()
	sim:run(15)
	eq("reloaded client learns the clear", a.client.records["1243"] ~= nil and a.client.records["1243"].value, "")
end

-- 6. concurrent edits converge on one winner; a mage's slot is kept and relayed by priests
do
	local sim = Sim()
	local a, b = Member(sim, "Anna", "PRIEST", PRIEST), Member(sim, "Bea", "PRIEST", PRIEST)
	local m = Member(sim, "Mo", "MAGE", MAGE)
	a:boot() b:boot() m:boot()
	sim:run(5)
	AI.SetOwner(a.client, FORT, "Anna")
	AI.SetOwner(b.client, FORT, "Bea")
	AI.SetOwner(m.client, AMP, "Mo", 604)
	sim:run(3)
	local winner = AI.Owner(a.client, FORT)
	eq("converged (Anna's view = Bea's)", AI.Owner(b.client, FORT), winner)
	eq("converged (mage's view)", AI.Owner(m.client, FORT), winner)
	eq("same version: the higher writer wins", winner, "Bea")
	eq("priest keeps the mage's record", a.client.records["1008"] and a.client.records["1008"].value, "Mo,604")
	local _, choice = AI.Owner(a.client, AMP)
	eq("Dampen chosen", choice, 604)
	-- the mage leaves: a new priest hears the mage slot from the priests' repair
	m.inGroup = false Roster(sim)
	local c = Member(sim, "Cid", "PRIEST", PRIEST)
	c:boot() Roster(sim)
	sim:run(15)
	eq("relayed mage record", c.client.records["1008"] and c.client.records["1008"].value, "Mo,604")
end

-- 7. an owner who can't cast the group form doesn't count
do
	local sim = Sim()
	local a, b = Member(sim, "Anna", "PRIEST", { [6346] = true }), Member(sim, "Bea", "PRIEST", PRIEST)
	a:boot() b:boot()
	sim:run(5)
	AI.SetOwner(b.client, FORT, "Anna")
	sim:run(2)
	eq("owner without Prayer is not live", AI.Owner(b.client, FORT), nil)
	local told = 0
	table.insert(b.client.subs, { onChanged = function() told = told + 1 end })
	AI.Receive(b.client, "1^A^1243^" .. ((sim.server + 100) * 1000) .. "^Anna^", "RAID", "Anna") -- Anna (not live) cleared
	eq("a change to a not-live owner still tells the watchers", told, 1)
	eq("nor for herself", AI.Owner(a.client, FORT), nil)
end

-- 8. edits refused in combat and out of a group
do
	local sim = Sim()
	local a = Member(sim, "Anna", "PRIEST", PRIEST)
	a:boot()
	a.combat = true
	eq("combat refused", select(2, AI.SetOwner(a.client, FORT, "Anna")), "combat")
	a.inGroup = false Roster(sim)
	a.combat = false
	eq("no group refused", select(2, AI.SetOwner(a.client, FORT, "Anna")), "group")
	eq("leaving forgets your name", a.client.me, nil)
	local told = 0
	table.insert(a.client.subs, { onChanged = function() told = told + 1 end })
	a.inGroup = true Roster(sim)
	eq("joining tells the watchers (Take turns on)", told, 1)
end

-- 9. the wire format (LibGroupBuffs v1)
do
	local sim = Sim()
	local a, b = Member(sim, "Anna", "PRIEST", PRIEST), Member(sim, "Bea", "PRIEST", PRIEST)
	a:boot() b:boot()
	sim:run(5)
	local hello
	for _, s in ipairs(sim.sent) do if s.from == "Anna" and s.msg:find("^1%^H") then hello = s.msg end end
	eq("hello", hello, "1^H^PRIEST^6346,21562,27681,27683^0")
	sim.sent = {}
	AI.SetOwner(a.client, FORT, "Anna")
	sim:run(1)
	eq("record", sim.sent[1] and sim.sent[1].msg, "1^A^1243^" .. ((sim.server + 5) * 1000) .. "^Anna^Anna")
	eq("digest (djb2 over key|ver|writer|value)", AI.Digest({ ["1243"] = { ver = 5, writer = "A", value = "A" } }),
		(function()
			local h = 5381
			for i = 1, #"1243|5|A|A\n" do h = (h * 33 + ("1243|5|A|A\n"):byte(i)) % 4294967296 end
			return string.format("%08x", h)
		end)())
	-- what is refused
	local before = AI.Digest(b.client.records)
	local bad = {
		"1^A^1243^0123^Anna^Anna", -- leading zero
		"1^A^1243^" .. ((sim.server + 2 * 86400) * 1000) .. "^Anna^Anna", -- too far ahead
		"1^A^1243^9^An^na^Anna", -- too many fields
		"1^A^1243^9^Anna^An,na", -- a comma in an owner
		"1^A^6346^9^Anna^Bea", -- Fear Ward without a caster
		"1^A^1008^9^Mo^Mo,605", -- not one of Amplify/Dampen
		"2^A^1243^9^Anna^Anna", -- another protocol version
	}
	for i, msg in ipairs(bad) do AI.Receive(b.client, msg, "RAID", "Anna") eq("refused " .. i, AI.Digest(b.client.records), before) end
	AI.Receive(b.client, "1^A^1243^9^Anna^Anna", "PARTY", "Anna")
	eq("wrong channel ignored", AI.Digest(b.client.records), before)
	AI.Receive(b.client, "1^A^1243^9^Zed^Zed", "RAID", "Zed")
	eq("not in the group ignored", AI.Digest(b.client.records), before)
	AI.Receive(b.client, "1^H^MAGE^23028^0", "RAID", "Anna")
	eq("hello with the wrong class ignored", b.client.peers.Anna.class, "PRIEST")
	AI.Receive(b.client, "1^A^6346:Anna^9^Anna^Bea,Cid", "RAID", "Anna")
	eq("Fear Ward targets accepted", table.concat(AI.Targets(b.client, SLOT[6346], "Anna"), ","), "Bea,Cid")
end

-- 10. the bridge: LibGroupBuffs' client already runs here, so ours reads its state and stays quiet
do
	local G = { assign = { frame = {}, subs = {}, me = "Anna", records = {} }, ASSIGN_SLOTS = lib.ASSIGN_SLOTS }
	G.AssignImpl = {
		Owner = function(c, slot) if slot.key == 1243 then return c.me end end,
		RecordedOwner = function() return nil end,
		SetOwner = function(c, slot, owner) G.set = { slot.key, owner } return true end,
	}
	other = G
	lib.assign.frame = nil
	lib.StartAssign()
	eq("backend", lib.AssignBackend(), "LibGroupBuffs")
	local owner, mine = lib.AssignOwner(1243)
	eq("owner from LibGroupBuffs", owner, "Anna")
	eq("mine", mine, true)
	eq("edit goes to LibGroupBuffs", (lib.AssignSet(14752, "Anna")), true)
	eq("edit slot", G.set and G.set[1], 14752)
	local told = 0
	lib.AssignWatch(function() told = told + 1 end)
	for _, sub in ipairs(G.assign.subs) do sub.onChanged() end
	eq("watchers hear LibGroupBuffs' changes", told >= 1, true)
end

print(("test_assign: %d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
