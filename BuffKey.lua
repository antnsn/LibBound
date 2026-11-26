-- LibBound buff key: one key (set on the Extras page) that casts the next thing needed, out of
-- combat. First a group version (a Prayer, below) when enough of one group need it, then the top card that has something to cast (your own buffs, a pet to call, water to
-- conjure: what each card's click would do), then a group buff (ns.groupBuffs) on the next party
-- or raid member in range who is missing it or about to lose it.
-- The rule for cards: a shown cast overlay means "cast this now" (buff timers offer the cast only
-- when the buff is gone or about to run out). A card that stays clickable while all is well
-- would be cast again and again: don't give the buff key such a card.
-- A secure button named <Addon>BuffKey holds the macro; Lua rewrites it out of combat only (twice
-- a second, and when the group or its buffs change), and the key is an override binding on it.
--   ns.groupBuffs[#ns.groupBuffs + 1] = { list = { spell IDs, lowest rank first },
--     names = function() return { aura names that count, e.g. the Prayer version } end,
--     enabled = function() return true end,  -- optional
--     levels = { 1, 12, 24, 36, 48, 60 },  -- optional: each rank's spell level (as list): a rank
--       goes only on someone at most 10 levels below it, so a low member gets the best rank they can
--       take (cast by spell ID); without levels the best rank always
--     short = "Fortitude", icon = 135987,  -- optional: the group card's label and icon
--     prayer = function() return "Prayer of Fortitude", 48 end }  -- optional: the group version (and
--       its rank's spell level: not on a group with someone more than 10 levels below it), when
--       known and its reagent is in the bags (else nil). Cast first, on a party or raid subgroup
--       where at least ns.db.prayerMin (default 3, 0 = never) need the buff, you included.
-- An addon with its own buff key turns this one off: Bound:NewAddon(name, ns, { buffKey = false, ... }).
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local SOON = 60 -- a buff with less than this many seconds left counts as missing
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>" -- a hidden aura name (as in Core.lua)

function lib.InstallBuffKey(ns)
	ns.groupBuffs = ns.groupBuffs or {}
	local M = {}
	ns.modules[#ns.modules + 1] = M
	local btn, bindLater
	local IsSecret, Clean = ns.IsSecret, ns.Clean

	local function Safe(fn, ...)
		local ok, a, b = pcall(fn, ...)
		if not ok or IsSecret(a) or IsSecret(b) then return nil end
		return a, b
	end

	local function GroupUnits()
		local list, n = {}, Safe(GetNumGroupMembers) or 0
		if Safe(IsInRaid) then
			for i = 1, n do list[#list + 1] = "raid" .. i end
		else
			for i = 1, n - 1 do list[#list + 1] = "party" .. i end
		end
		return list
	end

	-- another group member who is there: online, alive, friendly, near enough to see (buffs readable)
	local function Present(unit)
		if not Safe(UnitExists, unit) or Safe(UnitIsUnit, unit, "player") then return false end
		if not Safe(UnitIsConnected, unit) or Safe(UnitIsDeadOrGhost, unit) then return false end
		return Safe(UnitCanAssist, "player", unit) and Safe(UnitIsVisible, unit) and true or false
	end

	-- can this unit get a buff from you now: present and in range of the spell
	local function Reachable(unit, spell)
		if not Present(unit) then return false end
		local inRange = C_Spell and C_Spell.IsSpellInRange and Safe(C_Spell.IsSpellInRange, spell, unit)
		if inRange ~= nil then return inRange and true or false end
		local near, checked = Safe(UnitInRange, unit)
		return not checked or near and true or false
	end

	-- has the unit one of these buffs with time to spare; when some of its buffs can't be read,
	-- we can't tell it's missing: count it as there (skip the unit) rather than nag
	local function Has(unit, names)
		local unreadable = false
		for i = 1, 40 do
			local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
			if not ok then return true end
			if not a then return unreadable end
			local name = Clean(a.name)
			if not name or name == RESTRICTED then unreadable = true end
			if name and names[name] then
				local expires = Clean(a.expirationTime)
				return not expires or expires == 0 or expires - GetTime() > SOON
			end
		end
		return false
	end

	-- the group's units by subgroup: a raid's 1-8, or a party as 1; you are "player"
	local function Subgroups()
		local groups = {}
		if (Safe(GetNumGroupMembers) or 0) == 0 then return groups end
		if Safe(IsInRaid) then
			for i = 1, Safe(GetNumGroupMembers) or 0 do
				local ok, _, _, sub = pcall(GetRaidRosterInfo, i)
				if ok and type(sub) == "number" and not IsSecret(sub) then
					local unit = Safe(UnitIsUnit, "raid" .. i, "player") and "player" or "raid" .. i
					groups[sub] = groups[sub] or {}
					table.insert(groups[sub], unit)
				end
			end
		else
			groups[1] = { "player" }
			for _, unit in ipairs(GroupUnits()) do table.insert(groups[1], unit) end
		end
		return groups
	end

	-- the buff's aura names that count (the spell and e.g. its Prayer version), or nil when off
	local function Wanted(g)
		local id = (not g.enabled or g.enabled()) and ns.BestRank(g.list)
		local spell = id and ns.SpellName(id)
		if not spell then return nil end
		local names = {}
		for _, n in ipairs(g.names and g.names() or { spell }) do names[n] = true end
		names[spell] = true
		return spell, names
	end

	-- the unit's level, or nil when the client won't say (-1: far above you)
	local function Level(unit)
		local l = Safe(UnitLevel, unit)
		return type(l) == "number" and l > 0 and l or nil
	end
	local function Known(id)
		local ok, k = pcall(IsPlayerSpell, id)
		return ok and not IsSecret(k) and k and true or false
	end

	-- the best rank of a group buff this unit can take (a rank goes on someone at most 10 levels
	-- below its spell level), or nil when even the first is too high for them
	local function RankFor(g, unit)
		local level = g.levels and Level(unit)
		for i = #g.list, 1, -1 do
			if Known(g.list[i]) and (not level or (g.levels[i] or 0) <= level + 10) then return g.list[i] end
		end
	end

	-- a Prayer on the first subgroup where enough need it: on one of them (you, if you do)
	local function Prayer()
		local min = tonumber(ns.db.prayerMin) or 3
		if min <= 0 then return nil end
		local groups
		for _, g in ipairs(ns.groupBuffs) do
			local _, names = Wanted(g)
			local prayer, prayerLevel
			if names and g.prayer then prayer, prayerLevel = g.prayer() end
			if prayer then
				groups = groups or Subgroups()
				for sub = 1, 8 do
					local need, target, tooLow = 0, nil, false
					for _, unit in ipairs(groups[sub] or {}) do
						if (unit == "player" or Reachable(unit, prayer)) and not Has(unit, names) then
							need = need + 1
							target = target or unit
							local l = prayerLevel and Level(unit)
							if l and prayerLevel > l + 10 then tooLow = true end
						end
					end
					-- someone too low for it: single casts for that group, each at their rank
					if need >= min and not tooLow then return ("/cast [nocombat,@%s] %s"):format(target, prayer) end
				end
			end
		end
	end

	local function Next()
		local prayer = Prayer()
		if prayer then return prayer end
		for _, o in ipairs(ns.overlays or {}) do
			if o.spell and o:IsShown() then return o:GetAttribute("macrotext") or "" end
		end
		for _, g in ipairs(ns.groupBuffs) do
			local spell, names = Wanted(g)
			if spell then
				local best = ns.BestRank(g.list)
				for _, unit in ipairs(GroupUnits()) do
					if Reachable(unit, spell) and not Has(unit, names) then
						local rank = RankFor(g, unit)
						if rank == best then return ("/cast [nocombat,@%s] %s"):format(unit, spell) end
						-- a lower rank: by spell ID (a "(Rank 3)" name is not certain to work on Forever)
						if rank then return { spell = rank, unit = unit } end
					end
				end
			end
		end
		return ""
	end

	-- the group card: out of combat in a group, how many lack each group buff (far ones too: the key
	-- skips them until they are in range); its tooltip names them. Only for an addon whose defaults
	-- have groupCard (on or off); the addon puts the toggle on one of its pages.
	local card
	local function Lacking()
		local out = {}
		for _, g in ipairs(ns.groupBuffs) do
			local spell, names = Wanted(g)
			if spell then
				local who = {}
				for _, unit in ipairs(GroupUnits()) do
					if Present(unit) and not Has(unit, names) then who[#who + 1] = Clean((Safe(UnitName, unit))) or "?" end
				end
				if #who > 0 then out[#out + 1] = { label = g.short or spell, who = who } end
			end
		end
		return out
	end

	local function UpdateCard()
		if not card then return end
		if ns.unlocked then
			card:SetStatus((ns.groupBuffs[1].short or "Buffs") .. " 2")
			card:Show()
			return
		end
		local ok, list = pcall(Lacking)
		if not ok or not ns.db.groupCard or ns.InCombat() then list = {} end
		if #list == 0 then card:Hide() return end
		local parts, lines = {}, {}
		for _, l in ipairs(list) do
			parts[#parts + 1] = l.label .. " " .. #l.who
			lines[#lines + 1] = l.label .. ": " .. table.concat(l.who, ", ")
		end
		card:SetStatus(table.concat(parts, " · "))
		card:SetExplain(table.concat(lines, "\n") .. "\nYour buff key gives it to the next one in range.")
		card:Show()
	end

	function M:Update()
		UpdateCard()
		if not btn or InCombatLockdown() then return end
		local ok, what = pcall(Next)
		what = ok and what or ""
		-- a macro, or one spell by ID on a unit; cbtype is what the combat driver restores after a fight
		local kind = type(what) == "table" and "spell" or "macro"
		local function Set(k, v) if btn:GetAttribute(k) ~= v then btn:SetAttribute(k, v) end end
		Set("cbtype", kind)
		Set("type", kind)
		Set("macrotext", kind == "macro" and what or "")
		Set("spell", kind == "spell" and what.spell or nil)
		Set("unit", kind == "spell" and what.unit or nil)
	end

	function ns.BindBuffKey()
		if not btn then return end
		if InCombatLockdown() then bindLater = true return end
		bindLater = nil
		ClearOverrideBindings(btn)
		if ns.db.buffKey then SetOverrideBindingClick(btn, true, ns.db.buffKey, btn:GetName(), "LeftButton") end
	end

	function M:Init()
		btn = CreateFrame("Button", ns.addonName .. "BuffKey", UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
		btn:RegisterForClicks("AnyDown", "AnyUp")
		btn:SetAttribute("type", "macro")
		-- off in combat, secure (a card's macro may have no [nocombat]: pet calls, feeding)
		btn:SetAttribute("_onstate-boundcombat",
			[[ self:SetAttribute("type", (newstate == 1 or newstate == "1") and "none" or (self:GetAttribute("cbtype") or "macro")) ]])
		RegisterStateDriver(btn, "boundcombat", "[combat] 1; 0")
		btn:SetAttribute("macrotext", "")
		btn:SetScript("PostClick", function(self, _, down)
			local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
			if (down and not useDown) or (not down and useDown) then return end -- the phase that didn't act
			if self:GetAttribute("cbtype") ~= "spell" and (self:GetAttribute("macrotext") or "") == ""
				and not InCombatLockdown() then
				ns.Print("nothing to buff right now.")
			end
		end)
		if #ns.groupBuffs > 0 and ns.MakeCard and ns.defaults.groupCard ~= nil then
			card = ns.MakeCard(ns.addonName .. "GroupBuffsFrame", { width = 260 })
			card:SetIcon(ns.groupBuffs[1].icon or 136243)
			card:SetTitle("Group needs buffs")
			ns.MakeMovable(card, "gbPoint")
			ns.ApplyPoint(card, "gbPoint")
		end
		local f = CreateFrame("Frame")
		for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do f:RegisterEvent(e) end
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" and bindLater then ns.BindBuffKey() end
			M:Update()
		end)
		C_Timer.NewTicker(0.5, function() M:Update() end)
		ns.BindBuffKey()
		M:Update()
	end
end
