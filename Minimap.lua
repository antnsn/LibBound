-- LibBound minimap button: left-click options, shift- or middle-click unlocks the frames, an
-- optional right-click action, drag to move around the minimap. Also listed in the addon
-- compartment.
-- lib.InstallMinimap(ns, { rightClick = fn, rightClickText = "Right-click: ..." })
--
-- The button is a LibDataBroker launcher shown by LibDBIcon-1.0 (both embedded in LibBound's
-- Libs/), so minimap addons (EllesmereUI, SexyMap, ElvUI, MinimapButtonBag, broker bars...)
-- collect it like any other. Without those libraries it falls back to a button of its own.
-- Position: ns.db.minimapIcon (LibDBIcon's table: minimapPos in degrees, hide), started from the
-- older ns.db.minimapAngle; ns.db.minimap shows or hides it.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

function lib.InstallMinimap(ns, cfg)
	cfg = cfg or {}
	local M = {}
	ns.modules[#ns.modules + 1] = M
	local btn, dbi
	local title = ns.cfg.title or ns.addonName
	local ICON = ns.MEDIA .. "Icon64"

	local function OnClick(_, button)
		if button == "MiddleButton" or (button ~= "RightButton" and IsShiftKeyDown()) then
			ns.ToggleMove()
		elseif button == "RightButton" and cfg.rightClick then
			cfg.rightClick()
		elseif ns.ToggleOptions then
			ns.ToggleOptions()
		end
	end
	ns.MinimapClick = OnClick

	local function Tooltip(tt)
		tt:AddLine(title)
		tt:AddLine("Left-click: options", 1, 1, 1)
		if cfg.rightClickText then tt:AddLine(cfg.rightClickText, 1, 1, 1) end
		tt:AddLine((ns.unlocked and "Shift-click: lock frames" or "Shift-click: unlock frames"), 1, 1, 1)
		tt:AddLine("Drag: move", 0.6, 0.6, 0.6)
	end

	-- LibDBIcon's settings table, kept in the addon's saved variables
	local function IconDB()
		local d = ns.db.minimapIcon
		if type(d) ~= "table" then
			d = { minimapPos = ns.db.minimapAngle or 220 }
			ns.db.minimapIcon = d
		end
		d.hide = not ns.db.minimap
		return d
	end

	function M:Update()
		if dbi then
			IconDB()
			if ns.db.minimap then dbi:Show(ns.addonName) else dbi:Hide(ns.addonName) end
		elseif btn then
			btn:SetShown(ns.db.minimap)
		end
	end

	-- with LibDBIcon: a broker launcher; the icon follows the emblem variant (ns.SetEmblem)
	local function InitBroker(LDB, DBI)
		local obj = LDB:NewDataObject(ns.addonName, {
			type = "launcher", label = title, icon = ICON,
			OnClick = OnClick, OnTooltipShow = Tooltip,
		})
		if not obj then return false end
		M.iconProxy = { SetTexture = function(_, path) obj.icon = path end }
		ns.SetEmblem(M.iconProxy, "Icon64")
		DBI:Register(ns.addonName, obj, IconDB())
		dbi = DBI
		return true
	end

	-- without: a button of our own, its position an angle around the minimap
	local function Place()
		local angle = math.rad(ns.db.minimapAngle or 220)
		local r = (Minimap:GetWidth() / 2) + 5
		btn:ClearAllPoints()
		btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
	end
	local function OnDragUpdate()
		local mx, my = Minimap:GetCenter()
		local scale = Minimap:GetEffectiveScale()
		local cx, cy = GetCursorPosition()
		cx, cy = cx / scale, cy / scale
		ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
		Place()
	end
	local function InitButton()
		btn = CreateFrame("Button", ns.addonName .. "MinimapButton", Minimap)
		btn:SetSize(31, 31)
		btn:SetFrameStrata("MEDIUM")
		btn:SetFrameLevel(8)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
		btn:RegisterForDrag("LeftButton")
		btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
		bg:SetSize(20, 20)
		bg:SetPoint("TOPLEFT", 7, -5)
		local icon = btn:CreateTexture(nil, "ARTWORK")
		ns.SetEmblem(icon, "Icon64")
		icon:SetSize(18, 18)
		icon:SetPoint("TOPLEFT", 7, -6)
		icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
		btn.icon = icon
		local border = btn:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		border:SetSize(53, 53)
		border:SetPoint("TOPLEFT")
		btn:SetScript("OnClick", OnClick)
		btn:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
		btn:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
		btn:SetScript("OnDragStart", function(self)
			self:LockHighlight()
			self:SetScript("OnUpdate", OnDragUpdate)
		end)
		btn:SetScript("OnDragStop", function(self)
			self:SetScript("OnUpdate", nil)
			self:UnlockHighlight()
			icon:SetPoint("TOPLEFT", 7, -6)
		end)
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			Tooltip(GameTooltip)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		Place()
	end

	function M:Init()
		local LDB = LibStub("LibDataBroker-1.1", true)
		local DBI = LibStub("LibDBIcon-1.0", true)
		local ok, done = false, false
		if LDB and DBI then ok, done = pcall(InitBroker, LDB, DBI) end
		if not (ok and done) then dbi = nil; InitButton() end
		M:Update()
		if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
			pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
				text = title, icon = ICON, notCheckable = true,
				func = function(_, input, _, _, button)
					local b = (type(input) == "table" and input.buttonName) or button
					OnClick(nil, b)
				end,
			})
		end
	end
end
