-- LibBound options window: a sidebar with one page per feature, in the active skin. Taken from
-- Lightbound's Options.lua. Addons add pages with
--   ns.optionPages[#ns.optionPages + 1] = function(UI) local p = UI.NewPage("Title", "sub") ... end
-- Widgets return (widget, height); add the height with p:Add(h). UI.CONTENT_W is the usable width.
-- LibBound adds the shared pages itself: "Extras" (buff key, Well Rested, Well Fed,
-- Carrot on a Stick, then the addon's own extras), "Group" (who buffs the group, only for an addon
-- whose group buffs have assignment slots) and "Skin" (the skin, explanations, the minimap button). lib.InstallOptions(ns, { header = "Mage helper", launcher = "one line for Settings",
--   extras = function(UI, page, width) end -- more sections on the Extras page })
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local WIDTH, HEIGHT, SIDE_W, HEADER_H, FOOTER_H = 760, 620, 170, 44, 52
local PAD = 26
local CONTENT_W = WIDTH - SIDE_W - PAD * 2

function lib.InstallWidgets(ns)
	local UI = ns.UI
	local C, TEX = UI.C, UI.TEX
	local Tex, Font, Title, Hex = UI.Tex, UI.Font, UI.Title, UI.Hex
	local opt = { controls = {}, pages = {}, capturers = {} }
	ns.optionsState = opt

	local function FlatButton(parent)
		local b = CreateFrame("Button", nil, parent)
		b.bg = Tex(b, "BACKGROUND", C.button); b.bg:SetAllPoints()
		UI.Border(b)
		local fs = b:CreateFontString(nil, "OVERLAY")
		UI.SetFont(fs, "ui", 12)
		b:SetFontString(fs)
		return b
	end

	local function Button(parent, text, w, h)
		local b = UI.IsFlat() and FlatButton(parent) or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		b:SetSize(w, h or 24)
		b:SetText(text ~= "" and text or " ")
		b.label = b:GetFontString()
		UI.SetFont(b.label, "ui", 12)
		b.label:SetTextColor(unpack(C.accent))
		b.label:SetPoint("LEFT", 6, 0); b.label:SetPoint("RIGHT", -6, 0)
		b.label:SetJustifyH("CENTER")
		b.label:SetWordWrap(false)
		b.SetLabel = function(self, t) self:SetText(t ~= "" and t or " ") end
		b:SetScript("OnEnter", function(self)
			self.label:SetTextColor(1, 1, 1)
			if self.bg then self.bg:SetColorTexture(unpack(C.hover)) end
		end)
		b:SetScript("OnLeave", function(self)
			self.label:SetTextColor(unpack(C.accent))
			if self.bg then self.bg:SetColorTexture(unpack(C.button)) end
		end)
		return b
	end
	UI.Button = Button

	-- Toggle with label and optional description. Returns the row and its height.
	local function Toggle(page, x, y, w, label, desc, get, set)
		local h = desc and 40 or 26
		local row = CreateFrame("Button", nil, page)
		row:SetPoint("TOPLEFT", x, y)
		row:SetSize(w, h)
		local track, knob
		if UI.IsFlat() then
			local box = CreateFrame("Frame", nil, row)
			box:SetSize(14, 14); box:SetPoint("TOPLEFT", 2, -5)
			Tex(box, "BACKGROUND", C.button):SetAllPoints()
			UI.Border(box)
			knob = Tex(box, "ARTWORK", C.accent)
			knob:SetPoint("TOPLEFT", 3, -3); knob:SetPoint("BOTTOMRIGHT", -3, 3)
			local glow = Tex(box, "HIGHLIGHT", C.highlight); glow:SetAllPoints()
			track = CreateFrame("Frame", nil, row)
			track:SetSize(26, 26); track:SetPoint("TOPLEFT", -4, 1)
		else
			track = row:CreateTexture(nil, "ARTWORK")
			track:SetTexture(TEX.check)
			track:SetSize(26, 26)
			track:SetPoint("TOPLEFT", -4, 1)
			knob = row:CreateTexture(nil, "OVERLAY")
			knob:SetTexture(TEX.checkMark)
			knob:SetAllPoints(track)
			local glow = row:CreateTexture(nil, "HIGHLIGHT")
			glow:SetTexture(TEX.checkHighlight)
			glow:SetBlendMode("ADD")
			glow:SetAllPoints(track)
		end
		local text = Font(row, 14, C.text)
		text:SetPoint("TOPLEFT", track, "TOPRIGHT", 4, -6)
		text:SetPoint("RIGHT", row, "RIGHT")
		text:SetText(label)
		if desc then
			local d = Font(row, 12, C.dim)
			d:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
			d:SetPoint("RIGHT", row, "RIGHT")
			d:SetText(desc)
		end
		row.Sync = function() knob:SetShown(get() and true or false) end
		row:SetScript("OnClick", function()
			local v = not get()
			set(v)
			PlaySound(v and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			row.Sync(); ns.Refresh()
		end)
		row:SetScript("OnEnter", function() text:SetTextColor(1, 1, 1) end)
		row:SetScript("OnLeave", function() text:SetTextColor(unpack(C.text)) end)
		opt.controls[#opt.controls + 1] = row
		return row, h
	end

	local function DBToggle(page, x, y, w, key, label, desc, onSet)
		return Toggle(page, x, y, w, label, desc,
			function() return ns.db[key] end,
			function(v) ns.db[key] = v; if onSet then onSet(v) end end)
	end

	-- Thin slider with the value on the right. Height 46.
	local function Slider(page, y, label, key, minV, maxV, step, suffix)
		local title = Font(page, 14, C.text)
		title:SetPoint("TOPLEFT", 0, y)
		title:SetText(label)
		local value = Font(page, 14, C.accent)
		value:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
		value:SetJustifyH("RIGHT")
		local s = CreateFrame("Slider", nil, page, "BackdropTemplate")
		s:SetOrientation("HORIZONTAL")
		s:SetPoint("TOPLEFT", 0, y - 21)
		s:SetSize(CONTENT_W, 17)
		s:SetHitRectInsets(0, 0, -4, -4)
		s:SetBackdrop(TEX.slider)
		s:SetThumbTexture(TEX.sliderThumb)
		if UI.IsFlat() then
			s:SetBackdropColor(unpack(C.track)); s:SetBackdropBorderColor(unpack(C.border))
			local thumb = s:GetThumbTexture()
			thumb:SetSize(8, 17); thumb:SetVertexColor(unpack(C.accent))
		end
		s:SetMinMaxValues(minV, maxV)
		s:SetValueStep(step)
		s:SetObeyStepOnDrag(true)
		s:EnableMouseWheel(true)
		s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
		local syncing = false
		s:SetScript("OnValueChanged", function(_, v)
			v = math.floor(v / step + 0.5) * step
			value:SetText(v .. (suffix or ""))
			if syncing then return end
			ns.db[key] = v
			ns.Refresh()
		end)
		s.Sync = function(self)
			syncing = true
			self:SetValue(ns.db[key])
			value:SetText(ns.db[key] .. (suffix or ""))
			syncing = false
		end
		opt.controls[#opt.controls + 1] = s
		return s, 46
	end

	-- "Label        < Value >" selector. Left-click next, right-click previous.
	local function Cycle(page, y, label, values, get, set, note, labelColor)
		local text = Font(page, 14, labelColor or C.text)
		text:SetPoint("TOPLEFT", 0, note and y or (y - 5))
		text:SetText(label)
		local b = Button(page, "", 190, 26)
		b:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local noteText
		if note then
			noteText = Font(page, 12, C.dim)
			noteText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
			noteText:SetWidth(CONTENT_W - 200)
			noteText:SetJustifyH("LEFT")
			noteText:SetWordWrap(false)
		end
		b.Sync = function(self)
			self:SetLabel(Hex(C.dim) .. "<|r   " .. (get() or "None") .. "   " .. Hex(C.dim) .. ">|r")
			if noteText then noteText:SetText(note() or "") end
		end
		b:SetScript("OnClick", function(self, mouse)
			local cur, idx = get(), 1
			for i, v in ipairs(values) do if v == cur then idx = i end end
			idx = (mouse == "RightButton") and (idx - 2) % #values + 1 or idx % #values + 1
			set(values[idx])
			self:Sync(); ns.Refresh()
		end)
		opt.controls[#opt.controls + 1] = b
		return b, 34
	end

	local function Section(page, y, text)
		local fs = Title(page, 11, C.accent)
		fs:SetPoint("TOPLEFT", 0, y)
		fs:SetText(text:upper())
		local line = Tex(page, "ARTWORK", C.border)
		line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -5)
		line:SetSize(CONTENT_W, 1)
		return 26
	end

	-- a line of dim text across the page; returns its height
	local function Note(page, y, text)
		local n = Font(page, 12, C.dim)
		n:SetPoint("TOPLEFT", 0, y); n:SetWidth(CONTENT_W); n:SetJustifyH("LEFT")
		n:SetText(text)
		return math.max(18, (n:GetStringHeight() or 14) + 6)
	end

	local function NewPage(title, subtitle)
		local p = CreateFrame("Frame", nil, opt.win)
		p:SetPoint("TOPLEFT", SIDE_W + PAD, -HEADER_H - 20)
		p:SetSize(CONTENT_W, HEIGHT - HEADER_H - FOOTER_H - 30)
		p:Hide()
		local t = Title(p, 19)
		t:SetPoint("TOPLEFT")
		t:SetText(title)
		local s = Font(p, 13, C.dim)
		s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
		s:SetPoint("RIGHT", p, "RIGHT")
		s:SetText(subtitle)
		p.y = -58
		p.Add = function(self, h) self.y = self.y - h end
		opt.pages[#opt.pages + 1] = { title = title, frame = p }
		return p
	end

	-- Key binder: label, the key button and a Clear button. Click, then press a key (Esc cancels);
	-- the combo goes to ns.db[dbKey] and onSet(combo or nil) runs. `what` names it in chat. Height 40.
	local KEY_MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, LMETA = 1, RMETA = 1 }
	local function KeyButton(page, y, label, dbKey, onSet, what)
		local kl = Font(page, 14, C.text)
		kl:SetPoint("TOPLEFT", 0, y - 5)
		kl:SetText(label)
		local clear = Button(page, "Clear", 70, 26)
		clear:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
		local keyBtn = Button(page, "", 190, 26)
		keyBtn:SetPoint("RIGHT", clear, "LEFT", -8, 0)
		keyBtn.Sync = function(self)
			if self.capturing then return end
			self:SetLabel(ns.db[dbKey] or "Click to set")
		end
		local function Stop()
			keyBtn.capturing = false
			keyBtn:EnableKeyboard(false)
			keyBtn:SetScript("OnKeyDown", nil)
			keyBtn:Sync()
		end
		keyBtn.Stop = Stop
		keyBtn:SetScript("OnClick", function(self)
			if InCombatLockdown() then ns.Print("leave combat first.") return end
			self.capturing = true
			self:SetLabel("Press a key  (Esc cancels)")
			self:EnableKeyboard(true)
			self:SetPropagateKeyboardInput(false)
			self:SetScript("OnKeyDown", function(_, key)
				if KEY_MODS[key] then return end
				if key ~= "ESCAPE" then
					local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
						.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
					ns.db[dbKey] = combo
					if onSet then onSet(combo) end
					ns.Print((what or label:lower()) .. " set to " .. combo .. ".")
				end
				Stop()
			end)
		end)
		clear:SetScript("OnClick", function()
			if keyBtn.capturing then Stop() end -- Clear also ends a capture in progress
			ns.db[dbKey] = nil; if onSet then onSet(nil) end; keyBtn:Sync()
		end)
		-- leaving the page (or the window) ends a capture, so a later keypress can't rebind
		keyBtn:SetScript("OnHide", function() if keyBtn.capturing then Stop() end end)
		opt.controls[#opt.controls + 1] = keyBtn
		opt.capturers[#opt.capturers + 1] = keyBtn
		return keyBtn, 40
	end
	UI.KeyButton = KeyButton

	-- Text box. With a label: "Label      [box]" on one row (height 30). Without: a box across the
	-- page, opts.lines tall. Saves on Enter and when it loses focus (set(text)); Esc puts the saved
	-- text back. opts = { lines = 1, numeric = false, width = 360, max = 255 }. Returns box, height.
	local function EditBox(page, y, label, get, set, opts)
		opts = opts or {}
		local lines = opts.lines or 1
		local box = CreateFrame("EditBox", nil, page)
		box:SetAutoFocus(false)
		box:SetMultiLine(lines > 1)
		box:SetMaxLetters(opts.max or 255)
		if opts.numeric then box:SetNumeric(true) end
		box:SetTextInsets(6, 6, 4, 4)
		UI.SetFont(box, "ui", 12)
		box:SetTextColor(unpack(C.text))
		local bg = Tex(box, "BACKGROUND", C.button); bg:SetAllPoints()
		UI.Border(box)
		local h
		if label then
			local l = Font(page, 14, C.text)
			l:SetPoint("TOPLEFT", 0, y - 5)
			l:SetText(label)
			box:SetSize(opts.width or 360, 24)
			box:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y)
			h = 30
		else
			box:SetSize(CONTENT_W, lines * 15 + 10)
			box:SetPoint("TOPLEFT", 0, y)
			h = lines * 15 + 16
		end
		local function Save()
			set(box:GetText() or "")
			if opt.win and opt.win.Sync then opt.win.Sync() else box.Sync() end -- a preview may follow it
			ns.Refresh()
		end
		box.Commit = Save -- save the typed text now (a button next to the box reads the setting)
		box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) -- focus lost saves
		box:SetScript("OnEditFocusLost", Save)
		box:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring(get() or "")); self:ClearFocus()
		end)
		box.Sync = function()
			if box:HasFocus() then return end
			box:SetText(tostring(get() or ""))
		end
		opt.controls[#opt.controls + 1] = box
		return box, h
	end
	UI.EditBox = EditBox

	-- a row that only syncs (for pages with their own state)
	local function Syncer(fn) local row = { Sync = fn }; opt.controls[#opt.controls + 1] = row; return row end

	UI.NewPage, UI.DBToggle, UI.Toggle, UI.Slider, UI.Cycle, UI.Section, UI.Note, UI.Syncer =
		NewPage, DBToggle, Toggle, Slider, Cycle, Section, Note, Syncer
	UI.CONTENT_W = CONTENT_W
end

function lib.InstallOptions(ns, cfg)
	cfg = cfg or {}
	local UI = ns.UI
	local opt = ns.optionsState
	local C, TEX = UI.C, UI.TEX
	local Tex, Font, Title = UI.Tex, UI.Font, UI.Title
	local navButtons = {}
	local title = ns.cfg.title or ns.addonName

	local function BuildExtras()
		local p = UI.NewPage("Extras", "Levelling helpers.")
		local W = CONTENT_W
		if ns.BindBuffKey then -- not when the addon turned the shared buff key off (NewAddon buffKey = false)
			p:Add(UI.Section(p, p.y, "Buff key") + 2)
			p:Add(select(2, UI.KeyButton(p, p.y, "Key", "buffKey", function() ns.BindBuffKey() end, "buff key")))
			local groupBuff = ns.groupBuffs and #ns.groupBuffs > 0
			p:Add(UI.Note(p, p.y, groupBuff
				and "Out of combat, each press casts the next thing a card asks for, then a group buff on the next group member in range who needs it."
				or "Out of combat, each press casts the next thing a card asks for.") + 6)
		end
		local function Timer(label, key, test, note)
			local y = p.y - 4
			p:Add(UI.Section(p, y, label) + 2)
			local tb = UI.Button(p, "Test", 70, 20)
			tb:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, y + 4)
			tb:SetScript("OnClick", test)
			-- the note on the section line, beside Test
			if note then
				local n = UI.Font(p, 12, UI.C.dim)
				n:SetPoint("RIGHT", tb, "LEFT", -10, 0); n:SetJustifyH("RIGHT")
				n:SetText(note)
			end
			-- one row of four (room for Carrot on a Stick below); the short labels get narrow
			-- columns so "Countdown card" and "Rebuff warning" stay on one line
			local short = math.floor(W * 0.18)
			local long = math.floor((W - 2 * short) / 2)
			UI.DBToggle(p, 0, p.y, short, key, "Warn")
			UI.DBToggle(p, short, p.y, short, key .. "Sound", "Sound")
			UI.DBToggle(p, short * 2, p.y, long, key .. "Icon", "Countdown card")
			UI.DBToggle(p, short * 2 + long, p.y, W - short * 2 - long, key .. "Keep", "Rebuff warning",
				nil, function() ns.UpdateBuffTimers() end)
			p:Add(32)
			p:Add(select(2, UI.Slider(p, p.y, "Warn with time left", key .. "Minutes", 1, 30, 1, " min")) + 8)
		end
		Timer("Well-Rested", "wellRested", function() ns.TestBuffTimer("wellRested") end, "Cozy Sleeping Bag buff.")
		Timer("Well Fed", "wellFed", function() ns.TestBuffTimer("wellFed") end,
			"Food buff: more experience on Forever. Says when it's gone.")
		if ns.carrotShared then -- not when the addon turned it off (NewAddon carrot = false)
			p:Add(UI.Section(p, p.y - 4, "Carrot on a Stick") + 2)
			-- one row: Off, or the trinket slot the carrot goes into
			p:Add(select(2, UI.Cycle(p, p.y, "Wear it while mounted", { "Off", "Top trinket", "Bottom trinket" },
				function() return ns.db.carrotSwap and (ns.db.carrotSlot .. " trinket") or "Off" end,
				function(v)
					ns.db.carrotSwap = v ~= "Off"
					if v ~= "Off" then ns.db.carrotSlot = v:match("^(%a+)") end
				end,
				function()
					if not ns.db.carrotSwap then return "Your own trinket goes back on when you get off." end
					return "Swaps out: " .. ns.CarrotSlotItem(ns.db.carrotSlot)
				end)))
		end
		-- the addon's own extras below the shared ones
		if cfg.extras then cfg.extras(UI, p, W) end
	end

	local function BuildSkin()
		local p = UI.NewPage("Skin", "How " .. title .. "'s frames look. A new skin applies after a reload.")
		local names, keyOf = {}, {}
		for _, key in ipairs(UI.SkinOrder) do
			local n = UI.Skins[key].name
			names[#names + 1] = n; keyOf[n] = key
		end
		local about = {
			blizzard = "The game's own grey and silver tooltips, dialogs and buttons.",
			flat = "Thin black edges on dark grey, plain text. Fits EllesmereUI and ElvUI.",
		}
		for k, v in pairs(UI.SkinAbout) do about[k] = v end
		local function Current() return ns.db.skin or UI.DefaultSkin end
		local pending = Font(p, 12, C.accent)
		local reload = UI.Button(p, "Reload now", 120, 24)
		p:Add(select(2, UI.Cycle(p, p.y, "Skin", names,
			function() return UI.Skins[Current()].name end,
			function(n) ns.db.skin = keyOf[n]; p.skinRow.Sync() end,
			function() return about[Current()] end)) + 12)
		reload:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, p.y)
		pending:SetPoint("TOPLEFT", 0, p.y - 5); pending:SetPoint("RIGHT", reload, "LEFT", -10, 0)
		reload:SetScript("OnClick", function() ReloadUI() end)
		local built = UI.Active().name
		p.skinRow = UI.Syncer(function()
			local changed = UI.Skins[Current()].name ~= built
			pending:SetText(changed and "Reload to switch to " .. UI.Skins[Current()].name .. "." or "")
			reload:SetShown(changed)
		end)
		p:Add(30)
		p:Add(UI.Note(p, p.y, "Colours that carry meaning stay the same in every skin: red for missing or running low.") + 10)
		-- the general switches live here, where there is room (Extras fills up with addon extras)
		p:Add(UI.Section(p, p.y, "General") + 2)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, CONTENT_W, "explain", "Explain things in tooltips",
			"Plain-word help when you hover over a card or button. Turn it off once you know it all.")) + 6)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, CONTENT_W, "minimap", "Minimap button  (left-click options, shift-click unlock)")) + 6)
	end

	local function Select(i)
		for j, pg in ipairs(opt.pages) do
			pg.frame:SetShown(j == i)
			local nb = navButtons[j]
			nb.bar:SetShown(j == i)
			nb.bg:SetShown(j == i)
			nb.text:SetTextColor(unpack(j == i and C.accent or C.dim))
		end
		ns.db.optionsPage = i
	end
	opt.Select = function(i) if opt.win then Select(i) end end -- for the screenshots (Shots.lua)

	local win
	local function Build()
		win = CreateFrame("Frame", ns.addonName .. "Options", UIParent)
		opt.win = win
		win:SetSize(WIDTH, HEIGHT)
		win:SetPoint("CENTER")
		win:SetFrameStrata("DIALOG")
		win:SetToplevel(true)
		win:SetClampedToScreen(true)
		win:SetMovable(true)
		win:EnableMouse(true)
		win:Hide()
		tinsert(UISpecialFrames, win:GetName()) -- Escape closes it
		UI.Skin(win, title)
		-- the class crest in the corner where the skin has one, else the emblem, faint, in the middle
		if not UI.Crest(win, 300) then
			local wm = UI.Watermark(win, 300, 0.06)
			wm:SetPoint("CENTER", win, "CENTER", SIDE_W / 2, -10)
		end

		local header = CreateFrame("Frame", nil, win)
		header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(HEADER_H)
		Tex(header, "BACKGROUND", C.header):SetAllPoints()
		local hl = Tex(header, "ARTWORK", C.border); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)
		header:EnableMouse(true)
		header:RegisterForDrag("LeftButton")
		header:SetScript("OnDragStart", function() win:StartMoving() end)
		header:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
		local logo = header:CreateTexture(nil, "ARTWORK"); logo:SetSize(34, 34); logo:SetPoint("LEFT", 8, -2)
		ns.SetEmblem(logo, "Logo64")
		local t = Title(header, 15); t:SetPoint("LEFT", logo, "RIGHT", 6, 0); t:SetText(cfg.header or title)
		local ver = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.addonName, "Version") or ""
		-- run from git, the version is still the packager's "@project-version@": show none then
		local sub = Font(header, 12, C.dim); sub:SetPoint("RIGHT", -16, -2)
		-- a tag already starts with "v" (CurseForge fills the version from it): show one v either way
		ver = ver:gsub("^[vV]", "")
		sub:SetText((ver ~= "" and not ver:find("@", 1, true)) and ("v" .. ver) or "")
		opt.version = sub

		local side = CreateFrame("Frame", nil, win)
		side:SetPoint("TOPLEFT", 0, -HEADER_H); side:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
		side:SetWidth(SIDE_W)
		Tex(side, "BACKGROUND", C.side):SetAllPoints()
		local sl = Tex(side, "ARTWORK", C.border); sl:SetPoint("TOPRIGHT"); sl:SetPoint("BOTTOMRIGHT"); sl:SetWidth(1)

		for _, build in ipairs(ns.optionPages) do build(UI) end
		BuildExtras()
		if lib.AssignPage then lib.AssignPage(ns, UI, CONTENT_W) end -- "Group": who buffs the group (Assign.lua)
		BuildSkin()

		local pages = opt.pages
		local step = math.min(36, math.floor((HEIGHT - HEADER_H - FOOTER_H - 20) / #pages))
		for i, pg in ipairs(pages) do
			local nb = CreateFrame("Button", nil, side)
			nb:SetSize(SIDE_W - 1, step - 2)
			nb:SetPoint("TOPLEFT", 0, -10 - (i - 1) * step)
			nb.bg = nb:CreateTexture(nil, "BACKGROUND")
			nb.bg:SetTexture(TEX.navHighlight)
			nb.bg:SetBlendMode("ADD"); nb.bg:SetVertexColor(unpack(C.navGlow))
			if UI.IsFlat() then nb.bg:SetBlendMode("BLEND") end
			nb.bg:SetAllPoints(); nb.bg:Hide()
			nb.bar = Tex(nb, "ARTWORK", C.accent); nb.bar:SetPoint("TOPLEFT"); nb.bar:SetPoint("BOTTOMLEFT"); nb.bar:SetWidth(3); nb.bar:Hide()
			nb.text = Font(nb, step < 30 and 13 or 14, C.dim); nb.text:SetPoint("LEFT", 18, 0); nb.text:SetText(pg.title)
			nb:SetScript("OnClick", function() Select(i) end)
			nb:SetScript("OnEnter", function(self) if not pg.frame:IsShown() then self.text:SetTextColor(unpack(C.text)) end end)
			nb:SetScript("OnLeave", function(self) if not pg.frame:IsShown() then self.text:SetTextColor(unpack(C.dim)) end end)
			navButtons[i] = nb
		end

		local footer = CreateFrame("Frame", nil, win)
		footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(FOOTER_H)
		Tex(footer, "BACKGROUND", C.header):SetAllPoints()
		local fl = Tex(footer, "ARTWORK", C.border); fl:SetPoint("TOPLEFT"); fl:SetPoint("TOPRIGHT"); fl:SetHeight(1)
		local move = UI.Button(footer, "Unlock frames", 150, 28)
		move:SetPoint("LEFT", 16, 0)
		local reset = UI.Button(footer, "Reset positions", 150, 28)
		reset:SetPoint("LEFT", move, "RIGHT", 8, 0)
		reset:SetScript("OnClick", function() ns.ResetPositions() end)
		local hint = Font(footer, 12, C.dim)
		hint:SetPoint("LEFT", reset, "RIGHT", 14, 0)
		hint:SetText("Unlock shows every frame so you can drag it into place.")
		move:SetScript("OnClick", function() ns.ToggleMove(); win.unlockedHere = ns.unlocked; win.Sync() end)

		win.Sync = function()
			for _, c in ipairs(opt.controls) do c:Sync() end
			move:SetLabel(ns.unlocked and "Lock frames" or "Unlock frames")
		end
		win:SetScript("OnShow", function()
			win.Sync()
			Select(math.min(ns.db.optionsPage or 1, #pages))
		end)
		win:SetScript("OnHide", function()
			for _, b in ipairs(opt.capturers) do if b.capturing then b.Stop() end end
			if win.unlockedHere and ns.unlocked and not InCombatLockdown() then ns.ToggleMove() end
			win.unlockedHere = nil
		end)
	end

	function ns.ToggleOptions()
		if not ns.db then return end
		if not win then Build() end
		if win:IsShown() then win:Hide() else win:Show() end
	end

	-- launcher in the game's Settings > AddOns list
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local panel = CreateFrame("Frame")
		local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		t:SetPoint("TOPLEFT", 16, -16)
		t:SetText(title)
		local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
		d:SetText((cfg.launcher or title) .. " Type " .. ns.cfg.slash[1] .. " in chat to open the options.")
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		b:SetSize(180, 26)
		b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
		b:SetText("Open options")
		b:SetScript("OnClick", function()
			if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
			ns.ToggleOptions()
		end)
		pcall(function()
			local category = Settings.RegisterCanvasLayoutCategory(panel, title)
			Settings.RegisterAddOnCategory(category)
		end)
	end
end
