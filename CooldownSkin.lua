-- LibBound Cooldown Manager skin: Blizzard's Cooldown Manager (Essential, Utility and Tracked
-- Buffs icons) in the addon's look. On Forever addons can't read buffs in combat, but the game
-- draws the Cooldown Manager itself, so its stacks and timers keep working there; this only
-- changes how its icons look: our edge instead of Blizzard's rounded frame and mask, the count in
-- the skin's font. Positions and what is tracked stay Blizzard's (Edit Mode, its settings).
--   Bound.InstallCooldownSkin(ns, {
--     suggest = { "Holy Shield", ... }, -- optional: buffs worth tracking for this class (shown on the page)
--   })
-- Looks: the addon's own skin gets a gilt edge and a gold count, Flat a black edge and a white
-- count; the Blizzard skin leaves the game's own look alone (lib.BarLook).
-- Taint: only secure hooks (hooksecurefunc) and calls on Blizzard's textures; nothing is written
-- into Blizzard's frames or their data (our state lives in our own table), so the game's own
-- code that reads hidden values in combat stays untainted.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
local OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local CROP = { 0.07, 0.93, 0.07, 0.93 }
-- addons that replace the Cooldown Manager's icons with their own; where to set them up instead
-- (needs: addons it requires, turned on with it, since they may be off for this character)
local TAKERS = { { addon = "EllesmereUICooldownManager", name = "EllesmereUI", where = "/eui, Cooldown Manager",
	needs = { "EllesmereUI" } } }

function lib.InstallCooldownSkin(ns, opts)
	opts = opts or {}
	if ns.defaults.cdmSkin == nil then ns.defaults.cdmSkin = true end

	local M = {}
	ns.modules[#ns.modules + 1] = M
	local states = setmetatable({}, { __mode = "k" }) -- Blizzard icon -> our state for it
	local hooked = {}
	local look

	-- another addon that draws its own Cooldown Manager icons (and hides Blizzard's): we step aside
	local function TakenBy()
		local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
		if not loaded then return nil end
		for _, a in ipairs(TAKERS) do
			local ok, on = pcall(loaded, a.addon)
			if ok and on then return a end
		end
	end
	local function Wanted() return look ~= "blizzard" and ns.db.cdmSkin and not TakenBy() and true or false end

	local function Edge(parent, color, inset)
		local f = CreateFrame("Frame", nil, parent)
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", -inset, inset)
		f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset, -inset)
		local function side(p1, p2, w, h)
			local t = f:CreateTexture(nil, "OVERLAY")
			t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
			t:SetPoint(p1); t:SetPoint(p2)
			if w then t:SetWidth(w) end
			if h then t:SetHeight(h) end
		end
		side("TOPLEFT", "TOPRIGHT", nil, 1); side("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
		side("TOPLEFT", "BOTTOMLEFT", 1, nil); side("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
		return f
	end

	-- turn our look on or off for one icon (off puts Blizzard's back exactly)
	local function Apply(st, on)
		st.on = on
		if st.overlay then st.overlay:SetShown(not on) end
		if st.mask then
			if on and st.masked then st.icon:RemoveMaskTexture(st.mask); st.masked = false
			elseif not on and not st.masked then st.icon:AddMaskTexture(st.mask); st.masked = true end
		end
		if on then st.icon:SetTexCoord(CROP[1], CROP[2], CROP[3], CROP[4]) else st.icon:SetTexCoord(0, 1, 0, 1) end
		st.border:SetShown(on)
		for _, c in ipairs(st.counts) do
			if on then
				c.fs:SetFont(ns.UI.F.card, c.size, "OUTLINE")
				local col = look == "flat" and { 1, 1, 1 } or ns.UI.CARD.title
				c.fs:SetTextColor(col[1], col[2], col[3])
			else
				c.fs:SetFont(c.font, c.size, c.flags)
				c.fs:SetTextColor(c.r, c.g, c.b)
			end
		end
	end

	local function Skin(item)
		if not item or states[item] then return end
		local icon = item.Icon
		if not (icon and icon.IsObjectType and icon:IsObjectType("Texture")) then return end -- not an icon (a bar)
		local st = { icon = icon, counts = {}, masked = false }
		for _, r in ipairs({ item:GetRegions() }) do
			if r ~= icon and r.GetAtlas and r:GetAtlas() == OVERLAY then st.overlay = r end
		end
		if icon.GetMaskTexture then
			st.mask = icon:GetMaskTexture(1)
			st.masked = st.mask ~= nil
		end
		local holder = CreateFrame("Frame", nil, item)
		holder:SetAllPoints(icon)
		holder:SetFrameLevel((item:GetFrameLevel() or 0) + 5)
		if look == "flat" then
			st.border = Edge(holder, { 0, 0, 0, 1 }, 1)
		else
			st.border = Edge(holder, ns.UI.CARD.gilt, 1)
			Edge(st.border, { 0, 0, 0, 0.9 }, -1) -- a dark line inside the gilt, as on the cards
		end
		-- the stack count (Tracked Buffs) and charges (Essential, Utility)
		for _, pair in ipairs({ { "Applications", "Applications" }, { "ChargeCount", "Current" } }) do
			local box = item[pair[1]]
			local fs = box and box[pair[2]]
			if fs and fs.SetFont then
				local font, size, flags = fs:GetFont()
				local r, g, b = fs:GetTextColor()
				st.counts[#st.counts + 1] = { fs = fs, font = font, size = size or 14, flags = flags or "", r = r, g = g, b = b }
			end
		end
		states[item] = st
		Apply(st, true)
	end

	-- one icon or a whole viewer; never lets an error out into Blizzard's own call
	local function SkinItem(item) if Wanted() then pcall(Skin, item) end end
	local function Each(v)
		local pool = v.itemFramePool
		if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
		for item in pool:EnumerateActive() do SkinItem(item) end
	end
	local function SkinViewer(v) if v and Wanted() then pcall(Each, v) end end

	local function Hook()
		for _, name in ipairs(VIEWERS) do
			local v = _G[name]
			if type(v) == "table" and not hooked[v] then
				hooked[v] = true
				if type(v.RefreshLayout) == "function" then
					hooksecurefunc(v, "RefreshLayout", function(self) SkinViewer(self) end)
				end
				if type(v.OnAcquireItemFrame) == "function" then
					hooksecurefunc(v, "OnAcquireItemFrame", function(_, item) SkinItem(item) end)
				end
			end
			if v then SkinViewer(v) end
		end
	end

	function M:Init()
		look = lib.BarLook(ns)
		local f = CreateFrame("Frame")
		f:RegisterEvent("ADDON_LOADED"); f:RegisterEvent("PLAYER_ENTERING_WORLD")
		f:SetScript("OnEvent", function(_, event, name)
			if event == "ADDON_LOADED" and name ~= "Blizzard_CooldownViewer" then return end
			Hook()
		end)
		Hook()
	end

	-- the setting changed: skin what is there, or put Blizzard's look back
	function M:Update()
		if not look then return end
		local want = Wanted()
		for _, st in pairs(states) do if st.on ~= want then Apply(st, want) end end
		if want then Hook() end
	end

	-- The player picks who draws the Cooldown Manager: the other addon, or us (its module turned off
	-- for this character, the way EllesmereUI switches its own modules). Takes effect at a reload.
	local function Installed()
		local exists = C_AddOns and (C_AddOns.DoesAddOnExist or C_AddOns.IsAddOnLoaded)
		if not exists then return nil end
		for _, a in ipairs(TAKERS) do
			local ok, on = pcall(exists, a.addon)
			if ok and on then return a end
		end
	end
	local pending
	local function Choice()
		if pending then return pending end
		local t = TakenBy()
		return t and t.name or ns.addonName
	end
	local function Choose(v)
		local t = Installed()
		if not t or v == Choice() then return end
		local who = UnitName("player")
		if v == t.name then
			for _, need in ipairs(t.needs or {}) do pcall(C_AddOns.EnableAddOn, need, who) end
			pcall(C_AddOns.EnableAddOn, t.addon, who)
		else
			pcall(C_AddOns.DisableAddOn, t.addon, who)
		end
		pending = v
		ns.Print(("The Cooldown Manager: %s draws it after a reload (/reload)."):format(v))
	end

	ns.cooldownSkin = { State = function(item) return states[item] end, Choice = Choice, Choose = Choose }

	ns.optionPages[#ns.optionPages + 1] = function(UI)
		local p = UI.NewPage("Cooldown Manager", "Blizzard's Cooldown Manager shows buffs with stacks and time left, also in combat.")
		local W = UI.CONTENT_W
		local other = Installed()
		if other then
			p:Add(select(2, UI.Cycle(p, p.y, "Who draws the Cooldown Manager", { other.name, ns.addonName }, Choice, Choose,
				function()
					if Choice() == other.name then
						return ("%s draws its own icons and locks them in Edit Mode: set them up in %s."):format(other.name, other.where)
					end
					return ("%s's Cooldown Manager is off for this character: Blizzard's icons in this addon's look."):format(other.name)
				end)) + 4)
			local r = UI.Button(p, "Reload now", 120, 22)
			r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, p.y)
			r:SetScript("OnClick", function() if not InCombatLockdown() then ReloadUI() end end)
			p:Add(30)
			if TakenBy() then
				p:Add(UI.Note(p, p.y, ("While %s's Cooldown Manager is loaded, the settings below do nothing."):format(other.name)) + 8)
			end
		end
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "cdmSkin", "Give its icons this addon's look",
			"Our edge and count font. In the Blizzard skin they keep the game's own look.")) + 8)
		local b = UI.Button(p, "Open the Cooldown Manager", 220, 24)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, p.y)
		b:SetScript("OnClick", function()
			if InCombatLockdown() then return end
			if CooldownViewerSettings and CooldownViewerSettings.TogglePanel then
				CooldownViewerSettings:TogglePanel()
			else
				ns.Print("Turn the Cooldown Manager on first: Options, Gameplay Enhancements.")
			end
		end)
		p:Add(32)
		p:Add(UI.Note(p, p.y, "Add buffs under Tracked Buffs there, and move the icons with Edit Mode. Addons can't read buffs in combat on Forever, but these icons keep counting.") + 6)
		if opts.suggest and #opts.suggest > 0 then
			p:Add(UI.Section(p, p.y - 4, "Worth tracking") + 2)
			p:Add(UI.Note(p, p.y, table.concat(opts.suggest, ", ") .. "."))
		end
	end
end
