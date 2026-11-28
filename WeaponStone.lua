-- LibBound weapon stone / oil card (off by default), taken from Ragebound's Stone.lua (same settings,
-- so a warrior's settings carry over): your main hand has no temporary enchant, and a click uses the
-- best one you carry on it. An addon calls, from one of its files:
--   Bound.InstallWeaponStone(ns, { oils = true })  -- oils: the player may pick Wizard Oil or Mana Oil
-- and puts the settings on one of its pages with ns.WeaponStoneOptions(page, UI).
-- Settings: stone (on/off), stKind ("Stone", "Wizard Oil" or "Mana Oil"; only "Stone" without oils),
-- stPoint. "Stone" follows the weapon: a sharpening stone for blades, a weighted stone for maces and
-- staves. Oils go on any weapon. Without a fitting item in the bags the card says so and takes no
-- click. Quiet in combat. The card frame is <Addon>StoneFrame.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

-- lowest quality first
lib.WEAPON_ITEMS = {
	sharpening = { 2862, 2863, 2871, 7964, 12404 }, -- Rough, Coarse, Heavy, Solid, Dense
	weighted = { 3239, 3240, 3241, 7965, 12643 },
	wizard = { 20744, 20746, 20750, 20749 },         -- Minor, Lesser, Wizard Oil, Brilliant
	mana = { 20745, 20747, 20748 },                  -- Minor, Lesser, Brilliant
}
local NAMES = {
	[2862] = "Rough Sharpening Stone", [2863] = "Coarse Sharpening Stone", [2871] = "Heavy Sharpening Stone",
	[7964] = "Solid Sharpening Stone", [12404] = "Dense Sharpening Stone",
	[3239] = "Rough Weighted Stone", [3240] = "Coarse Weighted Stone", [3241] = "Heavy Weighted Stone",
	[7965] = "Solid Weighted Stone", [12643] = "Dense Weighted Stone",
	[20744] = "Minor Wizard Oil", [20746] = "Lesser Wizard Oil", [20750] = "Wizard Oil",
	[20749] = "Brilliant Wizard Oil",
	[20745] = "Minor Mana Oil", [20747] = "Lesser Mana Oil", [20748] = "Brilliant Mana Oil",
}
local NONE = {
	sharpening = "No sharpening stone in your bags", weighted = "No weighted stone in your bags",
	wizard = "No wizard oil in your bags", mana = "No mana oil in your bags",
}
local HELP = {
	Stone = "A sharpening stone (axes, swords, daggers, polearms, fist weapons) or weighted stone (maces and staves) adds damage to your main-hand weapon for 30 minutes. Blacksmiths make them; the Auction House sells them.",
	["Wizard Oil"] = "Wizard oil adds spell damage and healing to your main-hand weapon for 30 minutes. Enchanters make it; the Auction House sells it.",
	["Mana Oil"] = "Mana oil gives mana every 5 seconds (the better ones also add healing) on your main-hand weapon for 30 minutes. Enchanters make it; the Auction House sells it.",
}
local KINDS = { "Stone", "Wizard Oil", "Mana Oil" }

-- weapon subclasses (item class 2): which stone fits
local SHARP = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [13] = true, [15] = true } -- axes, polearms, swords, fist weapons, daggers
local BLUNT = { [4] = true, [5] = true, [10] = true } -- maces, staves
local NO_OIL = { [14] = true, [20] = true } -- miscellaneous, fishing poles

lib.WEAPON_STONE_DEFAULTS = {
	stone = false, stKind = "Stone",
	stPoint = { "CENTER", "UIParent", "CENTER", 250, 140 },
}

function lib.InstallWeaponStone(ns, cfg)
	cfg = cfg or {}
	for k, v in pairs(lib.WEAPON_STONE_DEFAULTS) do
		if ns.defaults[k] == nil then ns.defaults[k] = v end
	end
	local ITEMS = lib.WEAPON_ITEMS

	local function Count(id)
		local ok, n = pcall(C_Item.GetItemCount, id)
		return (ok and not ns.IsSecret(n) and n) or 0
	end

	local function Kind() -- the chosen kind; "Stone" when oils aren't offered
		local k = ns.db.stKind
		if not cfg.oils or (k ~= "Wizard Oil" and k ~= "Mana Oil") then return "Stone" end
		return k
	end

	-- the item list the main hand takes ("sharpening", "weighted", "wizard", "mana"), or nil when it
	-- takes none (empty, fishing pole, ...)
	function ns.StoneKind()
		local ok, id = pcall(GetInventoryItemID, "player", 16)
		if not ok or ns.IsSecret(id) or not id then return nil end
		local ok2, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
		if not ok2 or ns.IsSecret(classID) or ns.IsSecret(subclassID) or classID ~= 2 then return nil end
		local kind = Kind()
		if kind == "Wizard Oil" then return not NO_OIL[subclassID] and "wizard" or nil end
		if kind == "Mana Oil" then return not NO_OIL[subclassID] and "mana" or nil end
		if SHARP[subclassID] then return "sharpening" end
		if BLUNT[subclassID] then return "weighted" end
		return nil
	end

	-- false when the item needs a higher level than yours (unknown counts as usable)
	local function Usable(id)
		local ok, name, _, _, _, minLevel = pcall(C_Item.GetItemInfo, id)
		if not ok or not name or ns.IsSecret(minLevel) or type(minLevel) ~= "number" then return true end
		local ok2, level = pcall(UnitLevel, "player")
		if not ok2 or ns.IsSecret(level) or type(level) ~= "number" then return true end
		return minLevel <= level
	end

	-- the best item of that list in your bags that you can use: item ID and name, or nil
	function ns.BestStone(kind)
		local list = ITEMS[kind]
		if not list then return nil end
		for i = #list, 1, -1 do
			local id = list[i]
			if Count(id) > 0 and Usable(id) then
				local ok, n = pcall(C_Item.GetItemNameByID, id)
				return id, (ok and not ns.IsSecret(n) and n) or NAMES[id]
			end
		end
	end

	-- true when the main hand has a temporary enchant; nil when it can't be read
	local function Enchanted()
		local ok, has = pcall(GetWeaponEnchantInfo)
		if not ok or ns.IsSecret(has) then return nil end
		return has and true or false
	end

	local M = {}
	ns.modules[#ns.modules + 1] = M
	local card, overlay, shownKind

	local function Dress(kind) -- title, icon and explanation follow the chosen kind
		if kind == shownKind then return end
		shownKind = kind
		local first = kind == "Wizard Oil" and ITEMS.wizard[1] or kind == "Mana Oil" and ITEMS.mana[1] or ITEMS.sharpening[1]
		local ok, tex = pcall(C_Item.GetItemIconByID, first)
		card:SetIcon((ok and not ns.IsSecret(tex) and tex) or 135248)
		card:SetTitle(kind == "Stone" and "Weapon stone" or "Weapon oil")
		card:SetExplain(HELP[kind])
	end

	function M:Update()
		if not card then return end
		local kind = Kind()
		Dress(kind)
		if ns.unlocked then
			card:SetStatus("Missing: click to use"); card:Show(); card:Glow(false)
			if not InCombatLockdown() then overlay:Sync(nil) end
			return
		end
		local list = ns.db.stone and not ns.InCombat() and ns.StoneKind()
		local show, use, macro = false, nil, nil
		if list and Enchanted() == false then
			show = true
			local id, name = ns.BestStone(list)
			if id then
				use = name
				macro = ("/use item:%d\n/use 16"):format(id)
				card:SetStatus("Missing: click for " .. name, true)
			else
				card:SetStatus(NONE[list])
			end
		end
		if show then
			card:Show(); card:Glow(use ~= nil)
		else
			card:Glow(false); card:Hide()
		end
		if not InCombatLockdown() then overlay:Sync(use, "player", HELP[kind], macro) end
	end

	function M:Init()
		card = ns.MakeCard(ns.addonName .. "StoneFrame")
		Dress(Kind())
		ns.MakeMovable(card, "stPoint")
		ns.ApplyPoint(card, "stPoint")
		overlay = ns.CastOverlay(card)
		local f = CreateFrame("Frame")
		for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD",
			"PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED" }) do f:RegisterEvent(e) end
		f:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
		f:SetScript("OnEvent", function() M:Update() end)
		C_Timer.NewTicker(1, function() M:Update() end) -- the enchant wears off without an event
		M:Update()
	end

	-- the settings, as a section on one of the addon's pages
	function ns.WeaponStoneOptions(p, UI)
		local W = UI.CONTENT_W
		p:Add(UI.Section(p, p.y - 4, cfg.oils and "Weapon stone or oil" or "Weapon stone") + 2)
		p:Add(select(2, UI.DBToggle(p, 0, p.y, W, "stone", cfg.oils and "Show when your main hand has no stone or oil"
			or "Show when your main hand has no stone",
			"A click uses the best sharpening stone (blades) or weighted stone (maces, staves) in your bags.",
			function() M:Update() end)) + 6)
		if cfg.oils then
			p:Add(select(2, UI.Cycle(p, p.y, "Put on", KINDS, Kind,
				function(v) ns.db.stKind = v; M:Update() end,
				function()
					local k = Kind()
					if k == "Stone" then return "The stone that fits your weapon." end
					return k == "Wizard Oil" and "Spell damage and healing." or "Mana every 5 seconds."
				end)) + 8)
		end
	end
end
