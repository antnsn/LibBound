-- LibBound skins: every colour, font, border and texture the frames use comes from the active
-- skin, through ns.UI. Each addon brings its own class skin (Lightbound's gold, Chronobound's
-- frost); LibBound derives the neutral "Blizzard" and "Flat" skins from it, so every addon offers
-- the same three kinds. Values are looked up when a frame is built: a skin change needs a reload.
--
-- lib.InstallSkin(ns, { skins = { key = skinTable, ... }, order = { "frost", "blizzard", "flat" },
--   default = "frost", about = { key = "one line for the picker" } })
-- A skin table has the sections font, color, box, dialog, tex, card, widgets (see the class skins
-- for every field). Texture names in `card` are file names in the addon's Media folder.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local FRIZ, ARIALN = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"
lib.FONTS = { friz = FRIZ, arialn = ARIALN, morpheus = "Fonts\\MORPHEUS.TTF" }

-- a skin is another with some values replaced (tables merge, so no token is missing)
local function Derive(base, over)
	local t = {}
	for k, v in pairs(base) do t[k] = v end
	for k, v in pairs(over) do
		if type(v) == "table" and type(base[k]) == "table" and v[1] == nil and next(v) ~= nil then
			t[k] = Derive(base[k], v)
		else
			t[k] = v
		end
	end
	return t
end
lib.DeriveSkin = Derive

-- Classic Blizzard: tooltip and dialog frames in the game's own grey and silver, white text.
local function Blizzard(base)
	return Derive(base, {
		name = "Blizzard",
		font = { card = FRIZ, title = FRIZ, ui = FRIZ },
		color = {
			border = { 0.45, 0.45, 0.45, 0.9 }, hover = { 0.22, 0.22, 0.24, 1 }, selected = { 0.20, 0.20, 0.26, 1 },
			text = { 1, 1, 1 }, dim = { 0.66, 0.66, 0.66 }, accent = { 1, 0.82, 0 }, track = { 0.2, 0.2, 0.2, 1 },
			button = { 0.08, 0.08, 0.09, 1 }, navGlow = { 1, 0.82, 0, 0.55 }, row = { 0.12, 0.12, 0.14, 0.8 },
			rowWarn = { 0.38, 0.30, 0.04, 0.55 }, rowBad = { 0.42, 0.06, 0.06, 0.55 }, cell = { 0.14, 0.14, 0.15, 0.85 },
			cdText = { 1, 1, 1 }, glow = { 1, 0.82, 0 }, gridCentre = { 1, 0.82, 0, 0.45 },
		},
		box = {
			backdrop = {
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
			},
			bg = { 0.04, 0.04, 0.08 }, border = { 0.8, 0.8, 0.8, 1 },
		},
		dialog = {
			backdrop = {
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 11, top = 12, bottom = 11 },
			},
			outset = 10, under = { 0.02, 0.02, 0.03, 1 }, plate = "Interface\\DialogFrame\\UI-DialogBox-Header",
		},
		card = {
			panel = { 0.04, 0.04, 0.07, 0.92 }, gilt = { 0.62, 0.62, 0.62, 1 }, giltFaint = { 0.30, 0.30, 0.32, 0.9 },
			light = { 1, 1, 1, 0.04 }, rays = { 1, 0.9, 0.6 }, raysFaded = { 0.75, 0.71, 0.63 }, title = { 1, 0.82, 0 },
			status = { 1, 1, 1 }, urgent = { 1, 0.35, 0.3 }, glowEdge = { 1, 0.82, 0, 1 },
			burst = false, studs = false, shards = false, frost = false, ring = false, round = false, breathe = false,
		},
		widgets = "blizzard",
	})
end

-- Flat: 1px black edges on dark grey, Arial Narrow throughout, the class accent kept.
local WHITE = "Interface\\Buttons\\WHITE8x8"
local FLAT_BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
local function Flat(base)
	local accent = base.color.accent
	return Derive(base, {
		name = "Flat",
		font = { ui = ARIALN, title = ARIALN, card = ARIALN },
		color = {
			side = { 0, 0, 0, 0.25 }, header = { 0, 0, 0, 0.25 }, border = { 0, 0, 0, 1 }, hover = { 0.22, 0.22, 0.22, 1 },
			selected = { 0.20, 0.20, 0.20, 1 }, text = { 0.92, 0.92, 0.92 }, dim = { 0.58, 0.58, 0.58 },
			track = { 0.16, 0.16, 0.16, 1 }, button = { 0.13, 0.13, 0.13, 1 }, navGlow = { 1, 1, 1, 0.06 },
			row = { 0.12, 0.12, 0.12, 0.9 }, rowWarn = { 0.36, 0.28, 0.04, 0.7 }, rowBad = { 0.40, 0.05, 0.07, 0.7 },
			highlight = { 1, 1, 1, 0.06 }, cell = { 0.12, 0.12, 0.12, 0.9 }, cdText = { 1, 1, 1 },
		},
		box = { backdrop = FLAT_BACKDROP, bg = { 0.06, 0.06, 0.06 }, border = { 0, 0, 0, 1 } },
		dialog = { backdrop = FLAT_BACKDROP, outset = 1, bg = { 0.06, 0.06, 0.06, 0.97 }, border = { 0, 0, 0, 1 },
			under = { 0.06, 0.06, 0.06, 1 }, plate = false },
		tex = { slider = FLAT_BACKDROP, sliderThumb = WHITE, navHighlight = WHITE, statusbar = WHITE },
		card = {
			panel = { 0.06, 0.06, 0.06, 0.92 }, gilt = { 0, 0, 0, 1 }, giltFaint = { 0.16, 0.16, 0.16, 1 },
			light = { 1, 1, 1, 0 }, title = accent, status = { 0.86, 0.86, 0.86 }, urgent = { 1, 0.4, 0.35 },
			glowEdge = { accent[1], accent[2], accent[3], 1 },
			burst = false, studs = false, shards = false, frost = false, ring = false, round = false, breathe = false,
		},
		widgets = "flat",
	})
end

-- Blizzard's own widget textures, shared by every class skin
lib.STOCK_TEX = {
	check = "Interface\\Buttons\\UI-CheckBox-Up",
	checkMark = "Interface\\Buttons\\UI-CheckBox-Check",
	checkHighlight = "Interface\\Buttons\\UI-CheckBox-Highlight",
	slider = {
		bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 },
	},
	sliderThumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
	navHighlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
	statusbar = "Interface\\TargetingFrame\\UI-StatusBar",
}

function lib.InstallSkin(ns, opts)
	local SKINS = {}
	for k, v in pairs(opts.skins) do SKINS[k] = v end
	local base = SKINS[opts.default]
	SKINS.blizzard = SKINS.blizzard or Blizzard(base)
	SKINS.flat = SKINS.flat or Flat(base)
	local ORDER = opts.order or { opts.default, "blizzard", "flat" }
	local MEDIA = ns.MEDIA

	-- the skin is fixed for the session once the saved settings are in: picking another one in the
	-- options takes effect at the next reload, so frames built later never mix two skins
	local current
	local function Active()
		if current then return current end
		if not ns.db then return base end
		current = SKINS[ns.db.skin] or base
		return current
	end

	local function View(section)
		return setmetatable({}, { __index = function(_, k) return Active()[section][k] end })
	end
	local C, F = View("color"), View("font")

	local function Tex(parent, layer, color)
		local t = parent:CreateTexture(nil, layer)
		t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
		return t
	end
	local function Border(frame, color)
		color = color or C.border
		local function edge(p1, p2, w, h)
			local t = Tex(frame, "BORDER", color)
			t:SetPoint(p1); t:SetPoint(p2)
			if w then t:SetWidth(w) end
			if h then t:SetHeight(h) end
		end
		edge("TOPLEFT", "TOPRIGHT", nil, 1)
		edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
		edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
		edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	end
	-- SetFont with a skin font role ("ui", "title", "narrow", "card"); returns what SetFont returned
	local function SetFont(fs, role, size, flags) return fs:SetFont(F[role], size, flags or "") end
	local function Font(parent, size, color, layer)
		local fs = parent:CreateFontString(nil, layer or "OVERLAY")
		SetFont(fs, "ui", size - 1)
		fs:SetTextColor(color[1], color[2], color[3])
		fs:SetJustifyH("LEFT")
		return fs
	end
	local function Hex(c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
	local function Title(parent, size, color)
		local fs = Font(parent, size, color or C.accent)
		SetFont(fs, "title", size)
		fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
		return fs
	end
	local function IsFlat() return Active().widgets == "flat" end

	-- Dialog frame drawn just outside `frame`, plus the title plate (if the skin has one) and a close button.
	local function Skin(frame, titleText, onClose)
		local d = Active().dialog
		local skin = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		skin:SetPoint("TOPLEFT", -d.outset, d.outset); skin:SetPoint("BOTTOMRIGHT", d.outset, -d.outset)
		skin:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
		skin:SetBackdrop(d.backdrop)
		skin:SetBackdropColor(unpack(d.bg or { 1, 1, 1, 1 }))
		if d.border then skin:SetBackdropBorderColor(unpack(d.border)) end
		local ins = d.backdrop.insets
		local under = skin:CreateTexture(nil, "BACKGROUND", nil, -8)
		under:SetPoint("TOPLEFT", ins.left, -ins.top); under:SetPoint("BOTTOMRIGHT", -ins.right, ins.bottom)
		under:SetColorTexture(unpack(d.under))
		local top = CreateFrame("Frame", nil, frame)
		top:SetAllPoints(skin)
		top:SetFrameLevel(frame:GetFrameLevel() + 15)
		if d.plate then
			local plate = top:CreateTexture(nil, "OVERLAY")
			plate:SetTexture(d.plate)
			plate:SetSize(320, 64)
			plate:SetPoint("TOP", 0, 12)
			local t = top:CreateFontString(nil, "OVERLAY")
			SetFont(t, "title", 14)
			t:SetTextColor(unpack(C.accent))
			t:SetPoint("TOP", plate, "TOP", 0, -14)
			t:SetText(titleText)
			skin.title = t
		end
		local close
		if IsFlat() then
			close = CreateFrame("Button", nil, frame)
			close:SetSize(20, 20)
			close:SetPoint("TOPRIGHT", -6, -6)
			local x = close:CreateFontString(nil, "OVERLAY")
			SetFont(x, "narrow", 16)
			x:SetPoint("CENTER", 0, 1); x:SetText("x"); x:SetTextColor(unpack(C.dim))
			close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
			close:SetScript("OnLeave", function() x:SetTextColor(unpack(C.dim)) end)
		else
			close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
			close:SetPoint("TOPRIGHT", 6, 6)
		end
		close:SetFrameLevel(frame:GetFrameLevel() + 20)
		close:SetScript("OnClick", onClose or function() frame:Hide() end)
		return skin
	end

	-- the addon's emblem, faint, behind the content
	local function Watermark(parent, size, alpha)
		local w = parent:CreateTexture(nil, "BORDER")
		w:SetTexture(MEDIA .. "Logo256")
		w:SetSize(size, size)
		w:SetAlpha(alpha)
		return w
	end
	-- box for small frames; needs a frame made with "BackdropTemplate"
	local function Box(frame, alpha)
		if not frame.SetBackdrop then return end
		local b = Active().box
		frame:SetBackdrop(b.backdrop)
		frame:SetBackdropColor(b.bg[1], b.bg[2], b.bg[3], alpha or 0.92)
		frame:SetBackdropBorderColor(unpack(b.border))
	end
	local function FrameTitle(frame)
		local t = frame:CreateFontString(nil, "OVERLAY")
		SetFont(t, "title", 11)
		t:SetTextColor(unpack(C.accent))
		return t
	end
	local function RowBg(row)
		row.bg = Tex(row, "BACKGROUND", C.row); row.bg:SetAllPoints()
		return row.bg
	end
	local function Highlight(frame, alpha)
		local h = C.highlight
		local t = frame:CreateTexture(nil, "HIGHLIGHT"); t:SetAllPoints()
		t:SetColorTexture(h[1], h[2], h[3], alpha or h[4])
		return t
	end
	local function IconBorder(frame)
		if not IsFlat() then return end
		local b = CreateFrame("Frame", nil, frame)
		b:SetPoint("TOPLEFT", -1, 1); b:SetPoint("BOTTOMRIGHT", 1, -1)
		b:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
		Tex(b, "BACKGROUND", { 0, 0, 0, 1 }):SetAllPoints()
		return b
	end

	ns.UI = {
		C = C, F = F, CARD = View("card"), TEX = View("tex"), MEDIA = MEDIA,
		Active = Active, Skins = SKINS, SkinOrder = ORDER, SkinAbout = opts.about or {}, DefaultSkin = opts.default,
		IsFlat = IsFlat, IconBorder = IconBorder,
		Tex = Tex, Border = Border, SetFont = SetFont, Font = Font, Title = Title, Hex = Hex,
		Skin = Skin, Watermark = Watermark, Box = Box, FrameTitle = FrameTitle, RowBg = RowBg, Highlight = Highlight,
	}
	lib.InstallWidgets(ns)
	lib.InstallCards(ns)
end
