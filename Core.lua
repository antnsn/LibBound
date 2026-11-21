-- LibBound-1.0: the shared core of the Bound class addons (Lightbound, Chronobound, ...).
-- Taken from Lightbound's Core.lua. An addon calls lib:NewAddon(addonName, ns, cfg) from its first
-- file; that fills `ns` with the shared pieces (saved settings, safe aura reading, movable frames
-- with a grid, click-to-cast overlays, the module loader, the slash command), each bound to that
-- addon's own settings and names. The other LibBound files add cards, skins, options, the
-- minimap button and buff timers the same way (lib.Install* below).
--
-- cfg = {
--   class = "MAGE",                 -- loads only on this class (nil: every class)
--   title = "Chronobound",          -- shown in chat, windows, tooltips
--   prefix = "9fdcff",              -- chat prefix colour (hex)
--   db = "ChronoboundDB",           -- SavedVariables name
--   defaults = { ... },             -- merged under the shared defaults below
--   slash = { "/cb", "/chronobound" },
--   commands = { name = { fn = function(arg) end, help = "..." } }, -- extra sub-commands
--   media = "Interface\\AddOns\\Chronobound\\Media\\",
--   migrate = function(db, defaults) end, -- optional, after the defaults are in
-- }
-- Returns true when the addon should load nothing (wrong class): its files then return early.
local MAJOR, MINOR = "LibBound-1.0", 16
local lib = LibStub:NewLibrary(MAJOR, MINOR)
-- the other files of this copy install themselves only when this copy won (a newer or the
-- first one); BuffTimer.lua, the last file, clears the flag
if not lib then
	local current = LibStub(MAJOR, true)
	if current then current.installing = nil end
	return
end
lib.installing = MINOR

-- shared settings every Bound addon has (Lightbound's names, so settings carry over)
lib.SHARED_DEFAULTS = {
	snap = true, gridSize = 20, -- unlocked frames snap to a grid around the screen centre
	minimap = true, minimapAngle = 220,
	explain = true, -- plain-word explanations in tooltips
	travel = true, -- the travel panel beside the Escape menu (every Bound addon has one)
	wellRested = true, wellRestedMinutes = 5, wellRestedSound = true, wellRestedIcon = true, wellRestedKeep = false,
	wrPoint = { "CENTER", "UIParent", "CENTER", 0, 350 },
	wellFed = true, wellFedMinutes = 3, wellFedSound = true, wellFedIcon = true, wellFedKeep = false,
	wfPoint = { "CENTER", "UIParent", "CENTER", 0, 290 },
}

-- Secret values (hidden from addons in combat on Forever). Newer clients expose canaccessvalue,
-- older ones issecretvalue. Support both, assume readable otherwise.
local function IsSecret(v)
	local issecretvalue, canaccessvalue = _G.issecretvalue, _G.canaccessvalue
	if issecretvalue then return issecretvalue(v) end
	if canaccessvalue then return not canaccessvalue(v) end
	return false
end
lib.IsSecret = IsSecret
local RESTRICTED = _G.PP_RESTRICTED or "<restricted>"
local function Clean(v)
	-- secret first: even comparing a secret value with nil is not allowed
	if IsSecret(v) or v == nil then return nil end
	return v
end
lib.Clean = Clean

local function Copy(t)
	local o = {}
	for k, v in pairs(t) do o[k] = type(v) == "table" and Copy(v) or v end
	return o
end
lib.Copy = Copy

function lib:NewAddon(addonName, ns, cfg)
	ns.cfg = cfg
	ns.lib = lib
	ns.addonName = addonName
	local title = cfg.title or addonName
	local function Say(msg) print("|cff" .. (cfg.prefix or "ffd100") .. title .. ":|r " .. msg) end

	local _, class = UnitClass("player")
	ns.class = class
	if cfg.class and class ~= cfg.class then
		-- wrong class: load nothing. The slash command only says why, and the addon is unticked for
		-- this character alone (the AddOns list can tick it again).
		local key = addonName:upper()
		for i, s in ipairs(cfg.slash or {}) do _G["SLASH_" .. key .. i] = s end
		local who = cfg.className or cfg.class:sub(1, 1) .. cfg.class:sub(2):lower()
		SlashCmdList[key] = function() Say("only does something on a " .. who:lower() .. ".") end
		local me = UnitName("player")
		local disable = C_AddOns and C_AddOns.DisableAddOn
		if me and me ~= "" and disable and pcall(disable, addonName, me) then
			-- say so only when the client confirms it, so a call that did nothing can't repeat every login
			local state, ok, now = C_AddOns.GetAddOnEnableState, true, 0
			if state then ok, now = pcall(state, addonName, me) end
			if ok and now == 0 then
				Say(who:lower() .. "s only, so it is turned off for " .. me .. " from the next login.")
			end
		end
		ns.disabled = true
		return true
	end

	ns.defaults = {}
	for k, v in pairs(lib.SHARED_DEFAULTS) do ns.defaults[k] = v end
	for k, v in pairs(cfg.defaults or {}) do ns.defaults[k] = v end
	ns.IsSecret, ns.Clean, ns.Copy = IsSecret, Clean, Copy
	ns.Print = Say
	ns.MEDIA = cfg.media

	-- Emblem textures (logo, watermark, minimap icon, crest) can follow a variant the addon picks,
	-- e.g. a priest's spec: ns.EmblemVariant() returns a file-name suffix ("Shadow") or nil.
	-- ns.SetEmblem(tex, "Logo64") sets MEDIA .. "Logo64" .. suffix, and sets it again whenever the
	-- variant changes (checked on login and SPELLS_CHANGED). Without EmblemVariant: plain names.
	local emblems = setmetatable({}, { __mode = "k" })
	local variant
	local function Variant()
		if not ns.EmblemVariant then return "" end
		local ok, v = pcall(ns.EmblemVariant)
		return (ok and type(v) == "string") and v or ""
	end
	function ns.SetEmblem(tex, base)
		emblems[tex] = base
		variant = variant or Variant()
		tex:SetTexture(ns.MEDIA .. base .. variant)
	end
	local emblemWatch = CreateFrame("Frame")
	emblemWatch:RegisterEvent("PLAYER_LOGIN")
	emblemWatch:RegisterEvent("SPELLS_CHANGED")
	emblemWatch:SetScript("OnEvent", function()
		local v = Variant()
		if v == variant then return end
		variant = v
		for tex, base in pairs(emblems) do tex:SetTexture(ns.MEDIA .. base .. v) end
	end)
	ns.modules = {}
	ns.optionPages = ns.optionPages or {}

	-- True in combat. InCombatLockdown() only turns true after PLAYER_REGEN_DISABLED has fired, so
	-- also ask UnitAffectingCombat (true already then); a secret answer counts as in combat.
	function ns.InCombat()
		if InCombatLockdown() then return true end
		local ok, c = pcall(UnitAffectingCombat, "player")
		if not ok or IsSecret(c) then return true end
		return c and true or false
	end

	-- The player's buffs: name -> { icon, duration, expires, mine, spellId }, and a flag that is
	-- true when some auras were hidden from addons (combat restrictions).
	function ns.ReadPlayerBuffs()
		local buffs, hidden = {}, false
		for i = 1, 40 do
			local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
			if not ok then return buffs, true end
			if not a then break end
			local name = Clean(a.name)
			if not name or name == RESTRICTED then
				hidden = true
			else
				local src = Clean(a.sourceUnit)
				local mine
				if src then mine = (src == "player") end
				if not (buffs[name] and buffs[name].mine) then
					buffs[name] = { icon = Clean(a.icon), duration = Clean(a.duration), expires = Clean(a.expirationTime),
						mine = mine, spellId = Clean(a.spellId) }
				end
			end
		end
		if ns.InCombat() then hidden = true end -- some self buffs are simply left out in combat
		return buffs, hidden
	end

	function ns.SpellName(spellID)
		if not spellID or IsSecret(spellID) then return nil end
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		return ok and Clean(name) or nil
	end

	-- the highest spell of a list (lowest rank first) that the player knows, or nil
	function ns.BestRank(list)
		for i = #list, 1, -1 do
			local ok, known = pcall(IsPlayerSpell, list[i])
			if ok and not IsSecret(known) and known then return list[i], i end
		end
		return nil
	end

	lib.InstallMovers(ns)
	lib.InstallOverlays(ns)
	lib.InstallLoader(ns, addonName, cfg)
	lib.InstallSlash(ns, addonName, cfg)
	return false
end

-- Movable frames and the grid -------------------------------------------------------------
function lib.InstallMovers(ns)
	ns.movers = {}
	ns.unlocked = false

	local function GridSize() return math.max(4, math.floor(tonumber(ns.db.gridSize) or 20)) end
	-- the frame's anchor point (the one its position is saved by), in UIParent units
	local function AnchorXY(frame, point)
		local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
		if not l then return nil end
		local s = frame:GetScale()
		return (point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2) * s,
			(point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2) * s
	end
	local function CursorXY()
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		return x / s, y / s
	end
	local function Snap(ax, ay)
		if not ns.db.snap or IsShiftKeyDown() then return ax, ay end
		local cx, cy = UIParent:GetCenter()
		local g = GridSize()
		return cx + math.floor((ax - cx) / g + 0.5) * g, cy + math.floor((ay - cy) / g + 0.5) * g
	end

	function ns.ApplyPoint(frame, key)
		local p = ns.db[key]
		local scale = ns.db.scales and ns.db.scales[key] or 1
		if frame:GetScale() ~= scale then frame:SetScale(scale) end
		frame:ClearAllPoints()
		frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	end

	-- one drag at a time; a separate driver frame so the dragged frame's own OnUpdate stays intact
	local drag = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local function Place(frame, point, ax, ay)
		local fs = frame:GetScale()
		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, "BOTTOMLEFT", ax / fs, ay / fs)
	end
	-- a fight starting mid-drag: stop, so a frame with secure children is never moved in combat
	-- (it stays where it was dropped last; its saved place is unchanged)
	driver:RegisterEvent("PLAYER_REGEN_DISABLED")
	driver:SetScript("OnEvent", function()
		if drag.frame then drag.frame = nil; driver:Hide() end
	end)
	driver:SetScript("OnUpdate", function()
		local f = drag.frame
		if not f then driver:Hide() return end
		if not IsMouseButtonDown("LeftButton") then ns.EndDrag(f, drag.key) return end
		if InCombatLockdown() then drag.frame = nil; driver:Hide() return end
		local x, y = CursorXY()
		local ax, ay = Snap(x + drag.ox, y + drag.oy)
		drag.ax, drag.ay = ax, ay
		Place(f, drag.point, ax, ay)
	end)

	function ns.BeginDrag(frame, key)
		if not ns.unlocked or InCombatLockdown() then return end
		local point = (ns.db[key] and ns.db[key][1]) or "CENTER"
		local ax, ay = AnchorXY(frame, point)
		if not ax then return end
		local x, y = CursorXY()
		drag.frame, drag.key, drag.point = frame, key, point
		drag.ox, drag.oy, drag.ax, drag.ay = ax - x, ay - y, ax, ay
		driver:Show()
	end

	function ns.EndDrag(frame, key)
		if drag.frame ~= frame then return end
		driver:Hide()
		local fs = frame:GetScale()
		ns.db[key] = { drag.point, "UIParent", "BOTTOMLEFT", drag.ax / fs, drag.ay / fs }
		drag.frame = nil
		if not InCombatLockdown() then ns.ApplyPoint(frame, key) end
	end

	function ns.MakeMovable(frame, key)
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(self) ns.BeginDrag(self, key) end)
		frame:SetScript("OnDragStop", function(self) ns.EndDrag(self, key) end)
		-- while unlocked, the mouse wheel scales the frame (saved per frame in db.scales)
		frame:SetScript("OnMouseWheel", function(self, delta)
			if not ns.unlocked or InCombatLockdown() then return end
			local old = self:GetScale()
			local new = math.floor((old + delta * 0.1) * 10 + 0.5) / 10
			new = math.max(0.5, math.min(2.5, new))
			if new == old then return end
			local point = (ns.db[key] and ns.db[key][1]) or "CENTER"
			local l, r, t, b = self:GetLeft(), self:GetRight(), self:GetTop(), self:GetBottom()
			if not l then return end
			local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
			local y = point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2
			self:SetScale(new)
			ns.db.scales = ns.db.scales or {}
			ns.db.scales[key] = (new ~= 1) and new or nil
			ns.db[key] = { point, "UIParent", "BOTTOMLEFT", x * old / new, y * old / new }
			ns.ApplyPoint(self, key)
			ns.Print(("frame scale %d%%"):format(new * 100 + 0.5))
		end)
		ns.movers[#ns.movers + 1] = { frame = frame, key = key }
	end

	-- the grid itself and the small bar at the top while unlocked
	local grid, panel
	local ShowGrid
	local function GridPanel()
		if panel then return panel end
		local UI = ns.UI
		panel = CreateFrame("Frame", ns.addonName .. "GridPanel", UIParent, "BackdropTemplate")
		panel:SetSize(330, 36)
		panel:SetPoint("TOP", UIParent, "TOP", 0, -12)
		panel:SetFrameStrata("DIALOG")
		panel:EnableMouse(true)
		UI.Box(panel, 0.92)
		local function Resize(delta)
			ns.db.gridSize = math.max(4, math.min(100, GridSize() + delta))
			ns.db.snap = true
			ShowGrid(ns.unlocked)
		end
		local minus = UI.Button(panel, "-", 24, 22); minus:SetPoint("LEFT", 10, 0)
		minus:SetScript("OnClick", function() Resize(IsShiftKeyDown() and -1 or -4) end)
		panel.size = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		panel.size:SetPoint("LEFT", minus, "RIGHT", 6, 0); panel.size:SetWidth(70)
		local plus = UI.Button(panel, "+", 24, 22); plus:SetPoint("LEFT", panel.size, "RIGHT", 6, 0)
		plus:SetScript("OnClick", function() Resize(IsShiftKeyDown() and 1 or 4) end)
		local snap = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		snap:SetSize(24, 24); snap:SetPoint("LEFT", plus, "RIGHT", 10, 0)
		snap:SetScript("OnClick", function(self) ns.db.snap = self:GetChecked() and true or false; ShowGrid(ns.unlocked) end)
		local snapText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		snapText:SetPoint("LEFT", snap, "RIGHT", 2, 0); snapText:SetText("Snap")
		panel.snap = snap
		local lock = UI.Button(panel, "Lock", 60, 22); lock:SetPoint("RIGHT", -10, 0)
		lock:SetScript("OnClick", function() if ns.unlocked then ns.ToggleMove() end end)
		panel:EnableMouseWheel(true)
		panel:SetScript("OnMouseWheel", function(_, d) Resize(d > 0 and 4 or -4) end)
		panel:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Grid")
			GameTooltip:AddLine("- / + or the mouse wheel: grid size (Shift: 1 px steps)", 1, 1, 1)
			GameTooltip:AddLine("Hold Shift while dragging a frame to place it freely", 1, 1, 1)
			GameTooltip:Show()
		end)
		panel:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return panel
	end

	function ShowGrid(show)
		if show then
			local pn = GridPanel()
			pn.size:SetText(GridSize() .. " px")
			pn.snap:SetChecked(ns.db.snap and true or false)
			pn:Show()
		elseif panel then
			panel:Hide()
		end
		if not show or not ns.db.snap then if grid then grid:Hide() end return end
		if not grid then
			grid = CreateFrame("Frame", nil, UIParent)
			grid:SetAllPoints(UIParent)
			grid:SetFrameStrata("BACKGROUND")
			grid.lines = {}
		end
		local g = GridSize()
		local w, h = UIParent:GetWidth(), UIParent:GetHeight()
		local used = 0
		local function Line(vertical, offset, centre)
			used = used + 1
			local t = grid.lines[used]
			if not t then t = grid:CreateTexture(nil, "BACKGROUND"); grid.lines[used] = t end
			t:ClearAllPoints()
			t:SetColorTexture(unpack(centre and ns.UI.C.gridCentre or ns.UI.C.gridLine))
			if vertical then
				t:SetPoint("TOP", grid, "TOP", offset, 0); t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0); t:SetWidth(1)
			else
				t:SetPoint("LEFT", grid, "LEFT", 0, offset); t:SetPoint("RIGHT", grid, "RIGHT", 0, offset); t:SetHeight(1)
			end
			t:Show()
		end
		for i = 0, math.floor(w / 2 / g) do
			Line(true, i * g, i == 0)
			if i > 0 then Line(true, -i * g) end
		end
		for i = 0, math.floor(h / 2 / g) do
			Line(false, i * g, i == 0)
			if i > 0 then Line(false, -i * g) end
		end
		for i = used + 1, #grid.lines do grid.lines[i]:Hide() end
		grid:Show()
	end
	ns.ShowGrid = ShowGrid

	function ns.ToggleMove()
		if InCombatLockdown() then ns.Print("leave combat first.") return end
		ns.unlocked = not ns.unlocked
		for _, m in ipairs(ns.movers) do
			local f = m.frame
			f:EnableMouse(ns.unlocked or f.clickable == true); f:EnableMouseWheel(ns.unlocked)
			-- locked again: cards with an explanation keep their tooltip, still without clicks
			-- (clickable cards keep both)
			if not ns.unlocked and f.explain and f.SetMouseMotionEnabled and not f.clickable then
				f:SetMouseMotionEnabled(true); f:SetMouseClickEnabled(false)
			end
		end
		ShowGrid(ns.unlocked)
		ns.Print(ns.unlocked and ("unlocked: drag the frames, scroll on one to resize it. Lock them again when done."
			.. (ns.db.snap and " They snap to the grid (hold Shift to place freely)." or "")) or "locked.")
		ns.Refresh()
	end

	function ns.ResetPositions()
		if InCombatLockdown() then ns.Print("leave combat first.") return end
		for k, v in pairs(ns.defaults) do
			if k:find("Point$") then ns.db[k] = Copy(v) end
		end
		ns.db.scales = nil
		for _, m in ipairs(ns.movers) do ns.ApplyPoint(m.frame, m.key) end
		ns.Print("positions and sizes reset.")
		ns.Refresh()
	end
end

-- Click-to-cast overlays ---------------------------------------------------------------------
-- A secure button laid over a card: click it to cast the spell. It is a separate frame on UIParent,
-- positioned to match the card, so the card itself stays unprotected and can show and hide in
-- combat. Lua only moves, shows or hides the overlay out of combat. A secure state driver hides it
-- the moment combat starts, and the next out-of-combat Sync brings it back.
-- Create overlays out of combat only. overlay:Sync(spell, unit, explain, macro) shows it over its
-- owner; spell nil hides it.
function lib.InstallOverlays(ns)
	function ns.CastOverlay(owner)
		local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
		b:RegisterForClicks("AnyDown", "AnyUp")
		b:SetAttribute("_onstate-boundcombat", [[ if newstate == 1 or newstate == "1" then self:Hide() end ]])
		RegisterStateDriver(b, "boundcombat", "[combat] 1; 0")
		b:SetAttribute("type", "macro")
		b:Hide()
		b:SetScript("OnEnter", function(self)
			if not self.spell then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.spell)
			if self.explain and ns.db.explain then GameTooltip:AddLine(self.explain, 1, 1, 1, true) end
			GameTooltip:AddLine("Click to cast (out of combat)", 0.6, 0.9, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		-- spell: what it casts (shown in the tooltip); macro: optional full macro text instead of
		-- "/cast [nocombat,@unit] spell" (pet calls, feeding)
		function b:Sync(spell, unit, explain, macro)
			if InCombatLockdown() then return end
			local left, bottom, w, h = owner:GetRect()
			if not spell or ns.unlocked or not owner:IsVisible() or not left then
				self.spell = nil
				self:Hide()
				return
			end
			local s = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
			self:SetFrameStrata(owner:GetFrameStrata())
			self:SetFrameLevel(owner:GetFrameLevel() + 10)
			self:ClearAllPoints()
			self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
			self:SetSize(w * s, h * s)
			macro = macro or ("/cast [nocombat,@%s] %s"):format(unit or "player", spell)
			if self:GetAttribute("macrotext") ~= macro then self:SetAttribute("macrotext", macro) end
			self.spell, self.explain = spell, explain
			self:Show()
		end
		return b
	end
end

-- Modules and events --------------------------------------------------------------------------
-- A module is a table in ns.modules with optional Init(), Update(), Layout(). Init runs once the
-- saved settings are in; Update/Layout when a setting changes (ns.Refresh).
function lib.InstallLoader(ns, addonName, cfg)
	-- Runs one module's method so an error in it can't stop the modules after it. The error goes
	-- to the game's error handler, and the first one per module is printed in chat.
	function ns.Guard(m, what, ...)
		if not m[what] then return true end
		local ok, err = pcall(m[what], m, ...)
		if ok then return true end
		if not m.failed then
			m.failed = true
			ns.Print("a part of the addon hit an error, the rest keeps working: " .. tostring(err))
		end
		pcall(geterrorhandler(), err)
		return false
	end
	function ns.Refresh()
		for _, m in ipairs(ns.modules) do
			if m.Layout then ns.Guard(m, "Layout") end
			ns.Guard(m, "Update")
		end
	end
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self, _, name)
		if name ~= addonName then return end
		self:UnregisterEvent("ADDON_LOADED")
		_G[cfg.db] = _G[cfg.db] or {}
		ns.db = _G[cfg.db]
		for k, v in pairs(ns.defaults) do
			if ns.db[k] == nil then ns.db[k] = type(v) == "table" and Copy(v) or v end
		end
		if cfg.migrate then cfg.migrate(ns.db, ns.defaults) end
		-- modules build secure buttons in Init: after a /reload in combat that would be blocked,
		-- so they start once the fight is over
		-- every Bound addon has the travel panel in the same place: an addon without its own
		-- travel spells still gets it with the Hearthstone
		if not ns.travel and lib.InstallTravel and ns.UI then
			lib.InstallTravel(ns, { rows = function() return {} end, columns = {},
				hearthHelp = "Your Hearthstone takes you back to the inn you set it to. Talk to an innkeeper to change it." })
		end
		local function InitAll() for _, m in ipairs(ns.modules) do ns.Guard(m, "Init") end end
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
			self:SetScript("OnEvent", function(f)
				f:UnregisterEvent("PLAYER_REGEN_ENABLED")
				InitAll()
			end)
		else
			InitAll()
		end
	end)
end

-- Slash command -------------------------------------------------------------------------------
-- /cmd opens the options; /cmd <name> runs a command; every command also gets a space-free alias
-- (/cbunlock) for chat setups that swallow Enter after a space.
function lib.InstallSlash(ns, addonName, cfg)
	local function OnOff(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end
	ns.OnOff = OnOff
	local commands = {
		unlock = { fn = function() if not ns.unlocked then ns.ToggleMove() end end, help = "unlock the frames to move them" },
		lock = { fn = function() if ns.unlocked then ns.ToggleMove() end end, help = "lock the frames" },
		move = { fn = function() ns.ToggleMove() end, help = "unlock or lock the frames" },
		reset = { fn = function() ns.ResetPositions() end, help = "put every frame back where it started" },
		grid = { fn = function(arg)
			local n = tonumber(arg)
			if n then
				ns.db.gridSize = math.max(4, math.min(100, math.floor(n))); ns.db.snap = true
				ns.Print("snap to grid on, " .. ns.db.gridSize .. " px")
			else
				ns.db.snap = not ns.db.snap; ns.Print("snap to grid " .. OnOff(ns.db.snap))
			end
			ns.ShowGrid(ns.unlocked)
		end, help = "grid [size]: snap to grid on/off or its size" },
		minimap = { fn = function() ns.db.minimap = not ns.db.minimap; ns.Print("minimap button " .. OnOff(ns.db.minimap)) end,
			help = "show or hide the minimap button" },
		explain = { fn = function() ns.db.explain = not ns.db.explain; ns.Print("explanations in tooltips " .. OnOff(ns.db.explain)) end,
			help = "turn the plain-word explanations in tooltips on or off" },
		-- screenshots of every options page and frame for the docs (Shots.lua); not in the help
		shots = { fn = function() if lib.Shots then lib.Shots(ns) end end, hidden = true },
	}
	for k, v in pairs(cfg.commands or {}) do commands[k] = v end
	ns.commands = commands

	local function Help()
		local names = {}
		for k, c in pairs(commands) do if not c.hidden then names[#names + 1] = k end end
		table.sort(names)
		ns.Print(cfg.slash[1] .. " opens the options. Commands:")
		for _, k in ipairs(names) do print("  " .. cfg.slash[1] .. " " .. k .. " - " .. commands[k].help) end
	end

	local function Run(msg)
		if not ns.db then return end
		local cmd, arg = strsplit(" ", strtrim(msg or ""), 2)
		cmd = strlower(cmd or "")
		if cmd == "" or cmd == "options" or cmd == "config" then
			if ns.ToggleOptions then ns.ToggleOptions() end
			return
		end
		if cmd == "help" then Help() return end
		local c = commands[cmd]
		if not c then Help() return end
		c.fn(arg and strtrim(arg) or "")
		ns.Refresh()
	end

	local key = addonName:upper()
	for i, s in ipairs(cfg.slash) do _G["SLASH_" .. key .. i] = s end
	SlashCmdList[key] = Run
	-- space-free aliases: /cbunlock, /cbreset ...
	local base = cfg.slash[1]
	for name in pairs(commands) do
		local k = key .. name:upper()
		_G["SLASH_" .. k .. "1"] = base .. name
		SlashCmdList[k] = function(rest) Run(name .. " " .. (rest or "")) end
	end
	_G["SLASH_" .. key .. "HELP1"] = base .. "help"
	SlashCmdList[key .. "HELP"] = Help
end
