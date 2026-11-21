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

	-- can this unit get a buff from you now: there, alive, friendly, in range of the spell
	local function Reachable(unit, spell)
		if not Safe(UnitExists, unit) or Safe(UnitIsUnit, unit, "player") then return false end
		if not Safe(UnitIsConnected, unit) or Safe(UnitIsDeadOrGhost, unit) then return false end
		if not Safe(UnitCanAssist, "player", unit) or not Safe(UnitIsVisible, unit) then return false end
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

	local function Next()
		for _, o in ipairs(ns.overlays or {}) do
			if o.spell and o:IsShown() then return o:GetAttribute("macrotext") or "" end
		end
		for _, g in ipairs(ns.groupBuffs) do
			local id = (not g.enabled or g.enabled()) and ns.BestRank(g.list)
			local spell = id and ns.SpellName(id)
			if spell then
				local names = {}
				for _, n in ipairs(g.names and g.names() or { spell }) do names[n] = true end
				names[spell] = true
				for _, unit in ipairs(GroupUnits()) do
					if Reachable(unit, spell) and not Has(unit, names) then
						return ("/cast [nocombat,@%s] %s"):format(unit, spell)
					end
				end
			end
		end
		return ""
	end

	function M:Update()
		if not btn or InCombatLockdown() then return end
		local ok, macro = pcall(Next)
		macro = ok and macro or ""
		if btn:GetAttribute("macrotext") ~= macro then btn:SetAttribute("macrotext", macro) end
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
			[[ self:SetAttribute("type", (newstate == 1 or newstate == "1") and "none" or "macro") ]])
		RegisterStateDriver(btn, "boundcombat", "[combat] 1; 0")
		btn:SetAttribute("macrotext", "")
		btn:SetScript("PostClick", function(self, _, down)
			local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
			if (down and not useDown) or (not down and useDown) then return end -- the phase that didn't act
			if (self:GetAttribute("macrotext") or "") == "" and not InCombatLockdown() then
				ns.Print("nothing to buff right now.")
			end
		end)
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
