-- LibBound travel panel: beside the game menu (Escape), the class's own ways to travel (a mage's
-- teleports and portals, a shaman's Astral Recall...) and the Hearthstone. Click one to cast it;
-- the menu closes after the cast. Spells not learned yet are greyed with the level.
-- The panel holds secure buttons, so it lives on UIParent (a secure child would make the game
-- menu itself protected and break Escape in combat); it follows the menu out of combat only,
-- which is also when travel spells can be cast, and a secure driver hides it when a fight starts.
--
-- lib.InstallTravel(ns, {
--   key = "travel",                         -- the on/off setting
--   columns = { "TELEPORT", "PORTAL" },     -- one or two column headers ({} for none)
--   rows = function() return { { spell = id, label = "Orgrimmar", column = 1, known = bool,
--            level = 20, tip = "Teleport: Orgrimmar", help = "...", learn = "from a mage trainer" } } end,
--   footer = function() return "Runes: ..." end, -- optional text line (may change in combat)
--   hearthHelp = "...",                      -- tooltip help for the Hearthstone row
-- })
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local HEARTHSTONE = 6948
local ROW_H, W = 30, 250

function lib.InstallTravel(ns, cfg)
	local M = {}
	ns.modules[#ns.modules + 1] = M
	local name = ns.addonName .. "Travel"
	local key = cfg.key or "travel"
	local cols = cfg.columns or { "TRAVEL" }
	local colW = (W - 24) / math.max(1, #cols)
	local panel, buttons, dirty = nil, {}, true
	local UI

	local function Count(id)
		local ok, n = pcall(C_Item.GetItemCount, id)
		return (ok and not ns.IsSecret(n) and n) or 0
	end
	local function SpellIcon(id)
		local ok, t = pcall(C_Spell.GetSpellTexture, id)
		return ok and ns.Clean(t) or 134400
	end

	-- buttons take both mouse phases (the secure action fires on the one ActionButtonUseKeyDown
	-- picks); the menu closes only after that phase, so it can't hide the button before the cast
	local function ActingPhase(down)
		local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
		return (down and useDown) or (not down and not useDown)
	end
	local function CloseAfter(self, _, down)
		if not ActingPhase(down) then return end
		if self.castable == false then return end
		C_Timer.After(0, function() if not InCombatLockdown() then HideUIPanel(GameMenuFrame) end end)
	end
	local function Tooltip(self)
		if not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tip)
		if self.help and ns.db.explain then GameTooltip:AddLine(self.help, 1, 1, 1, true) end
		if self.note then GameTooltip:AddLine(self.note, 0.6, 0.9, 1, true) end
		GameTooltip:Show()
	end

	local function Destination(i)
		local b = buttons[i]
		if b then return b end
		b = CreateFrame("Button", name .. "Button" .. i, panel, "SecureActionButtonTemplate")
		b:SetSize(colW - 4, ROW_H - 4)
		b:RegisterForClicks("AnyDown", "AnyUp")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(ROW_H - 6, ROW_H - 6); b.icon:SetPoint("LEFT")
		b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		b.text = UI.Font(b, 12, UI.C.text)
		b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 4)
		b.text:SetPoint("RIGHT")
		b.text:SetWordWrap(false)
		b.sub = UI.Font(b, 10, UI.C.dim)
		b.sub:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -1)
		UI.Highlight(b)
		b:SetScript("OnEnter", Tooltip)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetScript("PostClick", CloseAfter)
		buttons[i] = b
		return b
	end

	local function Build()
		if InCombatLockdown() then dirty = true return end
		dirty = false
		if not panel then
			UI = ns.UI
			panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate, SecureHandlerStateTemplate")
			panel:SetWidth(W)
			panel:SetFrameStrata("DIALOG")
			panel:Hide()
			panel:SetAttribute("_onstate-boundcombat", [[ if newstate == 1 or newstate == "1" then self:Hide() end ]])
			RegisterStateDriver(panel, "boundcombat", "[combat] 1; 0")
			UI.Box(panel, 0.95)
			panel.title = UI.FrameTitle(panel)
			panel.title:SetPoint("TOPLEFT", 12, -10)
			panel.title:SetText("Travel")
			panel.heads = {}
			for i, h in ipairs(cols) do
				local fs = UI.Font(panel, 10, UI.C.accent)
				fs:SetPoint("TOPLEFT", 12 + (i - 1) * colW, -30)
				fs:SetText(h)
				panel.heads[i] = fs
			end
			panel.footer = UI.Font(panel, 11, UI.C.text)
			local h = CreateFrame("Button", name .. "Hearth", panel, "SecureActionButtonTemplate")
			h:SetSize(W - 24, ROW_H - 4)
			h:RegisterForClicks("AnyDown", "AnyUp")
			h.icon = h:CreateTexture(nil, "ARTWORK")
			h.icon:SetSize(ROW_H - 6, ROW_H - 6); h.icon:SetPoint("LEFT")
			h.icon:SetTexture(134414)
			h.text = UI.Font(h, 12, UI.C.text)
			h.text:SetPoint("LEFT", h.icon, "RIGHT", 6, 0)
			h:SetAttribute("type", "item")
			h:SetAttribute("item", "item:" .. HEARTHSTONE)
			h.tip, h.help = "Hearthstone", cfg.hearthHelp
			UI.Highlight(h)
			h:SetScript("OnEnter", Tooltip)
			h:SetScript("OnLeave", function() GameTooltip:Hide() end)
			h:SetScript("PostClick", CloseAfter)
			panel.hearth = h
		end
		local rows = cfg.rows()
		local perCol, lines = {}, 0
		local rowTop = #cols > 0 and 46 or 28 -- under the column headers, or right under the title
		for i, r in ipairs(rows) do
			local c = r.column or 1
			perCol[c] = (perCol[c] or 0) + 1
			lines = math.max(lines, perCol[c])
			local b = Destination(i)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", panel, "TOPLEFT", 12 + (c - 1) * colW, -rowTop - (perCol[c] - 1) * ROW_H)
			b.icon:SetTexture(SpellIcon(r.spell))
			b.text:SetText(r.label)
			b.tip, b.help = r.tip or r.label, r.help
			b.castable = r.known
			if r.known then
				b:SetAttribute("type", "spell")
				b:SetAttribute("spell", r.spell)
				b.icon:SetDesaturated(false); b.icon:SetAlpha(1)
				b.text:SetTextColor(unpack(UI.C.text))
				b.sub:SetText("")
				b.note = "Click to cast."
			else
				b:SetAttribute("type", nil)
				b:SetAttribute("spell", nil)
				b.icon:SetDesaturated(true); b.icon:SetAlpha(0.6)
				b.text:SetTextColor(unpack(UI.C.dim))
				b.sub:SetText(r.level and ("level " .. r.level) or "")
				b.note = r.level and ("Learn it at level %d %s."):format(r.level, r.learn or "from your class trainer") or nil
			end
			b:Show()
		end
		for i = #rows + 1, #buttons do buttons[i]:Hide() end
		M:UpdateCounts()
		local footerH = cfg.footer and 20 or 0
		local top = rowTop + 4
		panel.footer:ClearAllPoints()
		panel.footer:SetPoint("TOPLEFT", 12, -top - lines * ROW_H)
		panel.hearth:ClearAllPoints()
		panel.hearth:SetPoint("TOPLEFT", 12, -top - lines * ROW_H - footerH)
		panel:SetHeight(top + 6 + lines * ROW_H + footerH + ROW_H)
	end

	-- the text-only parts (footer, hearthstone place): safe to change in combat
	function M:UpdateCounts()
		if not panel then return end
		panel.footer:SetText(cfg.footer and cfg.footer() or "")
		local bind = GetBindLocation and ns.Clean(GetBindLocation()) or nil
		panel.hearth.text:SetText("Hearthstone" .. (bind and (" → " .. bind) or ""))
		if not InCombatLockdown() then panel.hearth:SetShown(Count(HEARTHSTONE) > 0) end
	end

	-- beside the menu, in UIParent coordinates (no anchor to the menu: it isn't ours to protect)
	local function Place()
		local l, b, w, h = GameMenuFrame:GetRect()
		if not l then return end
		local s = GameMenuFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		panel:ClearAllPoints()
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (l + w) * s + 12, (b + h) * s)
	end

	function M:Update()
		if InCombatLockdown() then return end
		if not ns.db[key] or not GameMenuFrame:IsShown() then
			if panel then panel:Hide() end
			return
		end
		if dirty or not panel then Build() end
		if not panel then return end
		Place()
		M:UpdateCounts()
		panel:Show()
	end

	function M:Init()
		if not GameMenuFrame then return end
		local f = CreateFrame("Frame")
		for _, e in ipairs({ "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
			f:RegisterEvent(e)
		end
		f:SetScript("OnEvent", function(_, event)
			if event == "BAG_UPDATE_DELAYED" then M:UpdateCounts() return end
			if event ~= "PLAYER_REGEN_ENABLED" then dirty = true end -- spells or zone changed: rebuild
			M:Update() -- also catches up on what combat held back
		end)
		GameMenuFrame:HookScript("OnShow", function() M:Update() end)
		GameMenuFrame:HookScript("OnHide", function() if panel and not InCombatLockdown() then panel:Hide() end end)
		M:Update()
	end
	ns.travel = M
	return M
end
