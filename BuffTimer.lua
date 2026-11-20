-- LibBound buff timers: a card that warns before a long buff runs out, with a countdown, and (when
-- "keep following" is on) a "has run out" card with one rebuff reminder, out of combat and alive.
-- Taken from Lightbound's WellRested.lua. Every Bound addon gets Well-Rested and Well Fed; class
-- addons add their own self-buffs with ns.MakeBuffTimer(cfg):
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
--   goneText  status text when it is missing (default "Buff has run out")
--   active    optional function -> false to hide the timer entirely (spell not known yet)
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local function FormatTime(s)
	s = math.max(0, math.floor(s))
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end
lib.FormatTime = FormatTime

function lib.InstallBuffTimers(ns)
	local timers = {}

	function ns.MakeBuffTimer(cfg)
		local M = {}
		ns.modules[#ns.modules + 1] = M
		timers[cfg.key] = M
		local key = cfg.key
		local card, overlay
		local expires, warned, buffIcon, had = nil, false, nil, false
		local missing, reminded = false, false
		local quietUntil = 0 -- right after login or zoning the aura list may not be filled in yet
		local mode

		local function Names()
			local n = cfg.names
			if type(n) == "function" then n = n() end
			n = n or {}
			if cfg.spellID then
				local s = ns.SpellName(cfg.spellID)
				if s then n = { s, unpack(n) } end
			end
			return n
		end
		local function Active() return not cfg.active or cfg.active() end

		local function Notify(text)
			local msg = ("|T%d:24|t %s"):format(buffIcon or cfg.icon, text)
			if RaidNotice_AddMessage and RaidWarningFrame then
				RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.5, b = 0 })
			end
			ns.Print(msg)
			if ns.db[key .. "Sound"] then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
		end
		local function NotifyLeft(secondsLeft)
			local mins = math.max(1, math.floor(secondsLeft / 60 + 0.5))
			Notify(("%s: %d min left"):format(cfg.label, mins))
		end

		local function SyncOverlay()
			if not overlay or InCombatLockdown() then return end
			local spell = (mode == "countdown" or mode == "gone") and cfg.cast and cfg.cast() or nil
			overlay:Sync(spell, "player", cfg.explain)
		end

		local function SetMode(m)
			-- the overlay follows even when the look stays (combat hid it; the armor choice changed)
			if m == mode then SyncOverlay() return end
			mode = m
			if m then card:Show(); card:Glow(m ~= "unlocked") else card:Glow(false); card:Hide() end
			SyncOverlay()
		end

		local function Following() return ns.db[key] and ns.db[key .. "Keep"] and Active() end

		local function Remind()
			if reminded or not missing or not Following() or GetTime() < quietUntil then return end
			if ns.InCombat() or UnitIsDeadOrGhost("player") then return end
			reminded = true
			Notify(cfg.label .. " is gone, rebuff")
		end

		local function UpdateCard()
			if not card then return end
			local db = ns.db
			card:SetIcon(buffIcon or cfg.icon)
			if ns.unlocked then
				SetMode("unlocked"); card:SetFaded(false); card:SetStatus("5:00 left")
				return
			end
			local left = expires and (expires - GetTime())
			if not Active() then
				SetMode(nil)
			elseif db[key] and db[key .. "Icon"] and warned and left and left > 0 then
				SetMode("countdown"); card:SetFaded(false); card:SetStatus(FormatTime(left) .. " left")
			elseif Following() and missing and not expires and GetTime() >= quietUntil then
				SetMode("gone"); card:SetFaded(true); card:SetStatus(cfg.goneText or "Buff has run out", true)
			else
				SetMode(nil)
			end
		end

		local function Check()
			local db = ns.db
			if not db[key] or not expires then Remind(); UpdateCard() return end
			local left = expires - GetTime()
			local limit = db[key .. "Minutes"] * 60
			if left <= 0 then
				expires, warned, missing = nil, false, true
			elseif left > limit + 5 then
				warned = false -- refreshed (or the limit was raised): arm again
			elseif not warned and Active() then -- a timer not in use stays silent too
				warned = true
				NotifyLeft(left)
			end
			Remind()
			UpdateCard()
		end

		function M:Update()
			if not card then return end
			if cfg.title then card:SetTitle(type(cfg.title) == "function" and cfg.title() or cfg.title) end
			local buffs, hidden = ns.ReadPlayerBuffs()
			local b
			for _, n in ipairs(Names()) do b = b or buffs[n] end
			if b then
				had, missing, reminded = true, false, false
				if b.expires and b.expires > 0 then expires = b.expires end
				if b.icon then buffIcon = b.icon end
			elseif not hidden and GetTime() >= quietUntil then
				if had and cfg.sayGone and ns.db[key] and not ns.db[key .. "Keep"] and not UnitIsDeadOrGhost("player") then
					Notify(cfg.label .. " is gone")
				end
				had, expires, warned, missing = false, nil, false, true
			end
			Check()
		end

		function M:Init()
			local f = CreateFrame("Frame")
			for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do f:RegisterEvent(e) end
			f:RegisterUnitEvent("UNIT_AURA", "player")
			f:RegisterEvent("PLAYER_UNGHOST"); f:RegisterEvent("PLAYER_ALIVE")
			f:SetScript("OnEvent", function(_, event)
				if event == "PLAYER_ENTERING_WORLD" then
					quietUntil = GetTime() + 5
					C_Timer.After(5.5, function() M:Update() end)
				end
				M:Update()
			end)
			card = ns.MakeCard(cfg.frameName)
			card:SetIcon(cfg.icon)
			card:SetTitle(cfg.label)
			if cfg.explain then card:SetExplain(cfg.explain) end
			ns.MakeMovable(card, cfg.point)
			ns.ApplyPoint(card, cfg.point)
			if cfg.cast then overlay = ns.CastOverlay(card) end
			local acc = 0
			card:SetScript("OnUpdate", function(_, elapsed)
				acc = acc + elapsed
				if acc >= 1 then acc = 0; Check() end
			end)
			C_Timer.NewTicker(5, Check)
			quietUntil = GetTime() + 5
			C_Timer.After(5.5, function() M:Update() end)
			M:Update()
		end

		M.Test = function() NotifyLeft(ns.db[key .. "Minutes"] * 60) end
		M.Card = function() return card end
		M.Overlay = function() return overlay end
		M.Mode = function() return mode end
		return M
	end

	function ns.UpdateBuffTimers() for _, t in pairs(timers) do t:Update() end end
	function ns.TestBuffTimer(key) if timers[key] then timers[key].Test() end end
	ns.buffTimers = timers

	local name = ns.addonName
	ns.MakeBuffTimer({ key = "wellRested", names = { "Well-Rested" }, spellID = 429959, icon = 132802, label = "Well-Rested",
		point = "wrPoint", frameName = name .. "WellRestedFrame",
		explain = "Sleeping in a Cozy Sleeping Bag gives Well-Rested: more experience for a while." })
	ns.MakeBuffTimer({ key = "wellFed", names = { "Well Fed" }, icon = 136000, sayGone = true, label = "Well Fed",
		point = "wfPoint", frameName = name .. "WellFedFrame",
		explain = "Eating buff food gives Well Fed: better stats, and on Forever more experience too." })
end

lib.installing = nil -- the last file of the embed: this copy is in
