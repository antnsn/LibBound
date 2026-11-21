-- LibBound combo point bar: five pips (the addon's painted art), one lit with a glow for each
-- combo point on your target, greyed out for the rest. Shown while you have points or are in
-- combat (or always, if picked), with a few quick flashes when you reach 5. Movable and resizable
-- like the cards, with its own options page. Points the addon can't read (a secret value) hide
-- the bar rather than show a wrong count.
--   Bound.InstallComboBar(ns, {
--     glow = { r, g, b, a },          -- the glow's colour
--     active = function() return true end, -- optional: when the bar may show at all (Cat Form)
--     about = "…",                    -- optional: a line under the page title
--   })
-- Looks: the addon's own skin gets the painted pips; the Blizzard and Flat skins plain squares in
-- the glow's colour (lib.BarLook, below; also used by PowerBar.lua).
-- Media: <addon>/Media/ComboPoint and ComboGlow, made by LibBound/tools/make_combo_media.py.
-- Call it where its options page should go among the addon's own (ns.optionPages order).
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local MAX, SIZE, GAP = 5, 30, 4
local PLAIN, PLAIN_GAP = 16, 3 -- the plain squares
local WHITE = "Interface\\Buttons\\WHITE8x8"
local UNLIT = { 0.16, 0.16, 0.16, 0.9 }
local DIM = { 0.30, 0.30, 0.30, 0.55 }
local IsSecret = lib.IsSecret

-- which look the bars take in this addon's skin: "painted" (its own), "blizzard" or "flat"
function lib.BarLook(ns)
	local key = ns.db and ns.db.skin
	if key == "flat" or key == "blizzard" then return key end
	return "painted"
end

-- combo points on the target, or nil when they can't be read
function lib.ComboPoints()
	local ok, n
	if GetComboPoints then
		ok, n = pcall(GetComboPoints, "player", "target")
	else
		ok, n = pcall(UnitPower, "player", Enum.PowerType.ComboPoints)
	end
	if not ok or IsSecret(n) or type(n) ~= "number" then return nil end
	return n
end

function lib.InstallComboBar(ns, opts)
	opts = opts or {}
	local GLOW = opts.glow or { 1, 1, 1, 0.85 }
	local d = ns.defaults
	if d.comboBar == nil then d.comboBar = true end
	if d.comboPulse == nil then d.comboPulse = true end
	if d.comboAlways == nil then d.comboAlways = false end
	d.cpPoint = d.cpPoint or { "CENTER", "UIParent", "CENTER", 0, -180 }
	ns.ComboPoints = lib.ComboPoints

	local M = {}
	ns.modules[#ns.modules + 1] = M
	local bar, last, pulses = nil, nil, 0
	local look

	local function Light(n)
		for i, p in ipairs(bar.pips) do
			p.lit = i <= n
			if look ~= "painted" then
				local c = p.lit and GLOW or UNLIT
				p:SetVertexColor(c[1], c[2], c[3], 1)
				p.glow:Hide()
			else
				p.glow:SetShown(p.lit)
				if p.lit then p:SetVertexColor(1, 1, 1, 1) else p:SetVertexColor(DIM[1], DIM[2], DIM[3], DIM[4]) end
			end
		end
	end

	local function Active()
		if not opts.active then return true end
		local ok, on = pcall(opts.active)
		return ok and on and true or false
	end

	function M:Update()
		if not bar then return end
		if ns.unlocked then Light(3); bar:Show() return end
		local n = ns.db.comboBar and Active() and lib.ComboPoints()
		if not n then bar.pulse:Stop(); bar:Hide(); last = nil return end
		Light(n)
		if n > 0 or ns.InCombat() or ns.db.comboAlways then bar:Show() else bar:Hide() end
		if n >= MAX and (last or 0) < MAX and ns.db.comboPulse then
			bar.pulse:Play()
			pulses = pulses + 1
			local mine = pulses
			C_Timer.After(1.2, function() if pulses == mine then bar.pulse:Stop() end end) -- three flashes, then still
		end
		if n < MAX then bar.pulse:Stop() end
		last = n
	end

	function M:Init()
		look = lib.BarLook(ns)
		bar = CreateFrame("Frame", ns.addonName .. "ComboFrame", UIParent)
		bar:SetFrameStrata("MEDIUM")
		bar.look = look
		bar.pips = {}
		if look ~= "painted" then
			-- plain squares with a dark 1px edge (the Blizzard skin gets the game's bar texture on them)
			bar:SetSize(MAX * PLAIN + (MAX - 1) * PLAIN_GAP + 2, PLAIN + 2)
			for i = 1, MAX do
				local edge = bar:CreateTexture(nil, "BACKGROUND")
				edge:SetColorTexture(0, 0, 0, 1)
				edge:SetSize(PLAIN + 2, PLAIN + 2)
				edge:SetPoint("LEFT", bar, "LEFT", (i - 1) * (PLAIN + PLAIN_GAP), 0)
				local p = bar:CreateTexture(nil, "ARTWORK")
				p:SetTexture(look == "flat" and WHITE or lib.STOCK_TEX.statusbar)
				p:SetSize(PLAIN, PLAIN)
				p:SetPoint("CENTER", edge, "CENTER")
				p.glow = bar:CreateTexture(nil, "BACKGROUND") -- none in the plain look
				p.glow:Hide()
				bar.pips[i] = p
			end
		end
		if look == "painted" then bar:SetSize(MAX * SIZE + (MAX - 1) * GAP, SIZE) end
		for i = 1, (look == "painted" and MAX or 0) do
			local p = bar:CreateTexture(nil, "ARTWORK")
			p:SetTexture(ns.MEDIA .. "ComboPoint")
			p:SetSize(SIZE, SIZE)
			p:SetPoint("LEFT", bar, "LEFT", (i - 1) * (SIZE + GAP), 0)
			-- the glow: the pip's shape grown and blurred (Media/ComboGlow), added behind it
			local g = bar:CreateTexture(nil, "BACKGROUND")
			g:SetTexture(ns.MEDIA .. "ComboGlow")
			g:SetSize(SIZE / 0.6, SIZE / 0.6) -- the pip fills 3/5 of the glow texture
			g:SetPoint("CENTER", p, "CENTER")
			g:SetBlendMode("ADD")
			g:SetVertexColor(GLOW[1], GLOW[2], GLOW[3], GLOW[4])
			g:Hide()
			p.glow = g
			bar.pips[i] = p
		end
		-- the pulse: the pips flash bright and dim a few times (only animation calls the cards
		-- already use in game; Forever has no AnimationGroup:SetLoopType)
		bar.pulse = bar:CreateAnimationGroup()
		bar.pulse:SetLooping("BOUNCE")
		local a = bar.pulse:CreateAnimation("Alpha")
		a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.2); a:SetSmoothing("IN_OUT")
		ns.MakeMovable(bar, "cpPoint")
		ns.ApplyPoint(bar, "cpPoint")
		bar:EnableMouse(false)
		bar:Hide()
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
		for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
			"PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM" }) do f:RegisterEvent(e) end
		f:SetScript("OnEvent", function() M:Update() end)
		M:Update()
	end

	ns.optionPages[#ns.optionPages + 1] = function(UI)
		local p = UI.NewPage("Combo points", opts.about or "Five pips, one lit for each combo point on your target.")
		local W = UI.CONTENT_W
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "comboBar", "Show the combo point bar", "While you have points or are in combat.")) + 6)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "comboPulse", "Flash at 5 points", "Time for a finisher.")) + 6)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "comboAlways", "Always show the bar", "Also out of combat with no points.")) + 8)
		p:Add(UI.Note(p, p.y, "Unlock frames to move the bar or scroll on it to resize it."))
	end
end
