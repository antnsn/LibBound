-- LibBound resource bar: Marius' layered bar art, filled to your rage (or another power), the
-- number on it, a glowing line at the fill's end and a glow round the bar when full. Horizontal or
-- vertical (the same art turned a quarter: the ornament ends up at the bottom, the fill grows
-- upward). Shown in combat or while there is any, or always if picked; movable and resizable
-- like the cards, with its own options page.
-- Looks: the addon's own skin gets the painted art; the Blizzard skin a plain bar with the game's
-- bar texture, the Flat skin a plain bar in flat colours (lib.BarLook in ComboBar.lua; the skin is fixed until a reload).
-- Rage the addon can't read (a secret value) still fills the bar and shows its number: the game
-- draws a secret value it is handed. Only what needs comparing (the full glow) is left out then.
--   Bound.InstallPowerBar(ns, {
--     power = 1,                       -- Enum.PowerType (1 rage, 3 energy)
--     title = "Rage bar",              -- the options page; also "Show the rage bar"
--     noun = "rage",                   -- for the texts
--     active = function() return true end, -- optional: when the bar may show at all (Bear Form)
--     overlay = true,                  -- optional: <prefix>Overlay on top (Dreambound's claws)
--     prefix = "RageBar",              -- media names: <prefix>Back, Fill, Frame, Full, Spark
--     fill = { 112, 44, 990, 84 }, canvas = { 1024, 128 }, -- the fill's box on the art's canvas
--     color = { r, g, b },             -- the fill in the Blizzard and Flat skins
--   })
-- Media: LibBound/tools/make_bar_media.py makes them from the art and prints the fill box.
-- Call it from Options.lua, where its page should go among the addon's own (ns.optionPages order).
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local SCALE = 0.3 -- art pixels to screen units: the 1024x128 canvas draws 307x38
local IsSecret = lib.IsSecret
-- a quarter turn to the left: the art's left end at the bottom, its top edge on the left
local ROTATED = { 1, 0, 0, 0, 1, 1, 0, 1 }
local WHITE = "Interface\\Buttons\\WHITE8x8"
local PLAIN_W, PLAIN_H = 220, 14 -- the plain bar, horizontal

function lib.InstallPowerBar(ns, opts)
	opts = opts or {}
	local POWER = opts.power or 1
	local PREFIX = opts.prefix or "RageBar"
	local NOUN = opts.noun or "rage"
	local FILL = opts.fill or { 112, 44, 990, 84 }
	local CW, CH = (opts.canvas or { 1024, 128 })[1], (opts.canvas or { 1024, 128 })[2]
	local d = ns.defaults
	for k, v in pairs({ powerBar = true, powerVertical = false, powerNumber = true, powerAlways = false }) do
		if d[k] == nil then d[k] = v end
	end
	d.pbPoint = d.pbPoint or { "CENTER", "UIParent", "CENTER", 0, -230 }

	local M = {}
	ns.modules[#ns.modules + 1] = M
	local bar, sb, top, look
	local COLOR = opts.color or { 0.80, 0.12, 0.08 }
	local art = {} -- the canvas-sized textures, turned with the bar

	local function Active()
		if not opts.active then return true end
		local ok, on = pcall(opts.active)
		return ok and on and true or false
	end

	-- size, fill box, turn and the spark's anchor for one orientation
	local function Place(vertical)
		sb:ClearAllPoints()
		bar.spark:ClearAllPoints()
		if look ~= "painted" then
			if vertical then bar:SetSize(PLAIN_H, PLAIN_W) else bar:SetSize(PLAIN_W, PLAIN_H) end
			sb:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
			sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
			if vertical then
				bar.spark:SetTexCoord(unpack(ROTATED)) -- the upright spark lies across the fill's top
				bar.spark:SetSize(PLAIN_H * 2, 12)
				bar.spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "TOP")
			else
				bar.spark:SetTexCoord(0, 1, 0, 1)
				bar.spark:SetSize(12, PLAIN_H * 2)
				bar.spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "RIGHT")
			end
			sb:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
			sb:SetRotatesTexture(vertical)
			bar.vertical = vertical
			return
		end
		local s = SCALE
		local l, t, r, b = FILL[1] * s, FILL[2] * s, (CW - FILL[3]) * s, (CH - FILL[4]) * s
		if vertical then
			bar:SetSize(CH * s, CW * s)
			-- turned left: the art's left end (where the fill starts) is the bottom
			sb:SetPoint("TOPLEFT", bar, "TOPLEFT", t, -r)
			sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -b, l)
			for _, tex in ipairs(art) do tex:SetTexCoord(unpack(ROTATED)) end
			bar.spark:SetTexCoord(unpack(ROTATED))
			bar.spark:SetSize(128 * s, 64 * s)
			bar.spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "TOP")
		else
			bar:SetSize(CW * s, CH * s)
			sb:SetPoint("TOPLEFT", bar, "TOPLEFT", l, -t)
			sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -r, b)
			for _, tex in ipairs(art) do tex:SetTexCoord(0, 1, 0, 1) end
			bar.spark:SetTexCoord(0, 1, 0, 1)
			bar.spark:SetSize(64 * s, 128 * s)
			bar.spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "RIGHT")
		end
		sb:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
		sb:SetRotatesTexture(vertical)
		bar.vertical = vertical
	end

	function M:Layout()
		if not bar then return end
		local vertical = ns.db.powerVertical and true or false
		if bar.vertical ~= vertical then Place(vertical); ns.ApplyPoint(bar, "pbPoint") end
	end

	local function Read()
		local ok, cur = pcall(UnitPower, "player", POWER)
		local ok2, mx = pcall(UnitPowerMax, "player", POWER)
		if not ok then cur = 0 end
		if not ok2 or IsSecret(mx) or type(mx) ~= "number" or mx <= 0 then mx = 100 end
		return cur, mx
	end

	local function Show(cur, mx)
		local secret = IsSecret(cur)
		if not secret and type(cur) ~= "number" then cur = 0 end
		sb:SetMinMaxValues(0, mx)
		pcall(sb.SetValue, sb, cur)
		if ns.db.powerNumber then
			-- a secret number goes to SetText as it is; never into and/or, which would test it
			if secret then bar.text:SetText(cur) else bar.text:SetText(tostring(cur)) end
			bar.text:Show()
		else
			bar.text:Hide()
		end
		bar.spark:SetShown(secret or (cur > 0 and cur < mx))
		bar.full:SetShown(not secret and cur >= mx)
		return secret, cur
	end

	function M:Update()
		if not bar then return end
		M:Layout()
		if ns.unlocked then Show(60, 100); bar:Show() return end
		if not (ns.db.powerBar and Active()) then bar:Hide() return end
		local secret, cur = Show(Read())
		local some = not secret and cur > 0
		if some or ns.InCombat() or ns.db.powerAlways then bar:Show() else bar:Hide() end
	end

	-- the painted bar: Marius' layers, the frame over the fill
	local function BuildPainted()
		local media = ns.MEDIA .. PREFIX
		local back = bar:CreateTexture(nil, "BACKGROUND")
		back:SetTexture(media .. "Back"); back:SetAllPoints()
		art[#art + 1] = back
		sb:SetStatusBarTexture(media .. "Fill")
		bar.spark:SetTexture(media .. "Spark")
		local frame = top:CreateTexture(nil, "ARTWORK")
		frame:SetTexture(media .. "Frame"); frame:SetAllPoints()
		art[#art + 1] = frame
		if opts.overlay then
			local o = top:CreateTexture(nil, "OVERLAY")
			o:SetTexture(media .. "Overlay"); o:SetAllPoints()
			art[#art + 1] = o
			bar.overlay = o
		end
		bar.full:SetTexture(media .. "Full"); bar.full:SetAllPoints()
		art[#art + 1] = bar.full
		bar.text:SetFont(lib.FONTS.friz, 11, "OUTLINE")
	end

	-- the plain bar (Blizzard and Flat skins): a dark track, a 1px edge, the fill in the power's
	-- colour; full is a bright edge
	local function BuildPlain()
		local back = bar:CreateTexture(nil, "BACKGROUND")
		back:SetAllPoints(); back:SetColorTexture(0, 0, 0, look == "flat" and 0.75 or 0.55)
		sb:SetStatusBarTexture(look == "flat" and WHITE or lib.STOCK_TEX.statusbar)
		sb:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3], 1)
		if look == "flat" then
			bar.spark:SetTexture(WHITE); bar.spark:SetVertexColor(1, 1, 1, 0.5)
		else
			bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		end
		local edge = look == "flat" and { 0, 0, 0, 1 } or { 0.55, 0.55, 0.55, 1 }
		for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
			{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
			local e = top:CreateTexture(nil, "ARTWORK")
			e:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
			e:SetPoint(side[1]); e:SetPoint(side[2])
			if side[3] then e:SetHeight(1) else e:SetWidth(1) end
		end
		-- full: the edge lights up in the fill's colour
		bar.full:SetPoint("TOPLEFT", -2, 2); bar.full:SetPoint("BOTTOMRIGHT", 2, -2)
		bar.full:SetColorTexture(COLOR[1], COLOR[2], COLOR[3], 0.45)
		bar.full:SetDrawLayer("BACKGROUND", -1)
		bar.full:SetParent(bar)
		bar.text:SetFont(look == "flat" and lib.FONTS.arialn or lib.FONTS.friz, 11, "OUTLINE")
	end

	function M:Init()
		look = lib.BarLook(ns)
		bar = CreateFrame("Frame", ns.addonName .. "PowerBar", UIParent)
		bar:SetFrameStrata("MEDIUM")
		bar.look = look
		sb = CreateFrame("StatusBar", nil, bar)
		sb:SetFrameLevel(bar:GetFrameLevel() + 1)
		bar.status = sb
		bar.spark = sb:CreateTexture(nil, "OVERLAY")
		bar.spark:SetBlendMode("ADD")
		-- the frame (and claws, the full glow, the number) over the fill
		top = CreateFrame("Frame", nil, bar)
		top:SetAllPoints(); top:SetFrameLevel(bar:GetFrameLevel() + 3)
		bar.full = top:CreateTexture(nil, "OVERLAY")
		bar.full:SetBlendMode("ADD")
		bar.text = top:CreateFontString(nil, "OVERLAY")
		bar.text:SetPoint("CENTER", sb, "CENTER")
		bar.text:SetTextColor(1, 0.93, 0.80)
		if look == "painted" then BuildPainted() else BuildPlain() end
		Place(ns.db.powerVertical and true or false)
		ns.MakeMovable(bar, "pbPoint")
		ns.ApplyPoint(bar, "pbPoint")
		bar:EnableMouse(false)
		bar:Hide()
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
		f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
		f:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
		for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD",
			"UPDATE_SHAPESHIFT_FORM" }) do f:RegisterEvent(e) end
		f:SetScript("OnEvent", function() M:Update() end)
		M:Update()
	end

	ns.optionPages[#ns.optionPages + 1] = function(UI)
		local title = opts.title or "Rage bar"
		local p = UI.NewPage(title, opts.about or ("Your " .. NOUN .. " in a bar of its own."))
		local W = UI.CONTENT_W
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "powerBar", "Show the " .. title:lower(), "While you have " .. NOUN .. " or are in combat.")) + 6)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "powerVertical", "Vertical", "Upright, filling from the bottom.")) + 6)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "powerNumber", "Show the number")) + 6)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "powerAlways", "Always show the bar", "Also out of combat with no " .. NOUN .. ".")) + 8)
		p:Add(UI.Note(p, p.y, "Unlock frames to move the bar or scroll on it to resize it."))
	end
end
