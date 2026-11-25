-- LibBound Service: sell what the class can do (mage portals, rogue lockboxes) in Trade.
--  * Announce: one key press, click or `/<slash> announce` posts the player's own message to
--    Trade (the client allows channel posts only from a key press or click), with placeholders
--    like {portals} or {skill} filled in.
--  * Listen: when someone in chat asks for the service ("wtb port org", "anyone open lockbox?"),
--    a sound and one chat line with clickable [Invite] and [Whisper]. Optional auto-whisper reply.
-- An addon declares its service (nothing is on for addons that don't):
--   Bound.InstallService(ns, {
--     label = "Portals",                         -- options page and chat line
--     example = "Portals to {portals}! ...",     -- the message until the player writes their own
--     reply = "Hi {name}! ...",                  -- auto-whisper example ({name}, {target})
--     keywords = { "portal", "portals" },        -- what the service is (multi-word allowed)
--     targets = { org = "Orgrimmar", ... },      -- optional: word -> what {target} becomes
--     weak = { "port" },                         -- optional: count only next to another intent word
--     available = function() return true end,    -- false: can't offer it yet
--     unavailable = "You know no portals yet.",  -- said when announcing while unavailable
--     fill = { portals = function() return "Orgrimmar" end }, -- placeholders ({zone}, {level} are shared)
--     skillField = true,                         -- optional: a number box for {skill} (serviceSkill)
--     page = "Portal service", help = "...",     -- optional: options page title and subtitle
--   })
-- Matching (lib.ServiceMatch): in public chat a keyword or target fires only together with an
-- intent word (wtb, lf, any, port, ? ...); in a whisper either alone is enough. Rival offers
-- (wts, selling, /w, tips ...) never fire in public chat.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local INTENT = {}
for w in ("wtb lf lfm need needs any anyone port plz pls please can someone ?"):gmatch("%S+") do INTENT[w] = true end
local OFFER_WORDS = { wts = true, selling = true, offering = true, tips = true }
local OFFER_PHRASES = { "whisper me", "w me", "lf customers" }

-- lowercase words of a chat message: colour codes and link data removed (a link's [name] stays),
-- letters and digits (UTF-8 kept), and "?" as a word of its own
function lib.ServiceWords(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
	text = text:lower():gsub("%?", " ? ")
	local out = {}
	for w in text:gmatch("[%w\128-\255%?]+") do out[#out + 1] = w end
	return out
end

-- position of a (possibly multi-word) phrase in the word list, or nil
local function Find(words, phrase)
	local parts = {}
	for p in phrase:lower():gmatch("%S+") do parts[#parts + 1] = p end
	if #parts == 0 then return nil end
	for i = 1, #words - #parts + 1 do
		local ok = true
		for j = 1, #parts do
			if words[i + j - 1] ~= parts[j] then ok = false break end
		end
		if ok then return i end
	end
end

local function IsOffer(words, raw)
	for _, w in ipairs(words) do if OFFER_WORDS[w] then return true end end
	for _, p in ipairs(OFFER_PHRASES) do if Find(words, p) then return true end end
	-- "/w me", "/w Name": a slash command in the text
	return raw:lower():find("/w%s") ~= nil or raw:lower():find("/w$") ~= nil
end

-- spec = { keywords = {..}, targets = { word = value }, weak = {..}, extra = {..} } -> nil or { target = value|nil }
function lib.ServiceMatch(text, spec, fromWhisper)
	local words = lib.ServiceWords(text)
	if #words == 0 then return nil end
	if not fromWhisper and IsOffer(words, tostring(text)) then return nil end
	local thing = false
	for _, list in ipairs({ spec.keywords or {}, spec.extra or {} }) do
		for _, k in ipairs(list) do if Find(words, k) then thing = true break end end
		if thing then break end
	end
	local target, at
	for k, v in pairs(spec.targets or {}) do
		local i = Find(words, k)
		if i and (not at or i < at) then target, at = v, i end
	end
	-- weak words ("port"): the thing only with another intent word next to them, or in a whisper
	local weakAt
	if not thing and not target then
		for _, k in ipairs(spec.weak or {}) do
			weakAt = Find(words, k)
			if weakAt then break end
		end
		if not weakAt then return nil end
	end
	if not fromWhisper then
		local intent = false
		for i, w in ipairs(words) do if INTENT[w] and i ~= weakAt then intent = true break end end
		if not intent then return nil end
	end
	return { target = target }
end

-- "{name}" placeholders from fills (a value or a function returning one); unknown or nil ones stay
function lib.ServiceFill(template, fills)
	return (tostring(template or ""):gsub("{(%w+)}", function(name)
		local v = fills and fills[name]
		if type(v) == "function" then v = v() end
		if v == nil then return nil end
		return tostring(v)
	end))
end

-- Links in the alert line: addon:bound:<addonName>:invite|whisper:<sender>. One SetItemRef hook per
-- game session (whichever LibBound copy installs first); it calls the newest lib.ServiceLink.
lib.serviceAddons = lib.serviceAddons or {}
function lib.ServiceLink(link)
	if type(link) ~= "string" then return false end
	local addon, action, name = link:match("^addon:bound:([^:]+):(%a+):(.+)$")
	if not addon or not lib.serviceAddons[addon] then return false end
	if action == "invite" then
		local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or _G.InviteUnit
		if invite then pcall(invite, name) end
	elseif action == "whisper" then
		if ChatFrame_OpenChat then pcall(ChatFrame_OpenChat, "/w " .. name .. " ", DEFAULT_CHAT_FRAME) end
	else
		return false
	end
	return true
end
if not lib.serviceHooked and type(_G.SetItemRef) == "function" then
	lib.serviceHooked = true
	hooksecurefunc("SetItemRef", function(link) lib.ServiceLink(link) end)
end

local LISTEN = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true }
local PUBLIC = { "trade", "general", "lookingforgroup" } -- channels listened to (name starts with)
local DEDUPE, REPLY_AGAIN = 60, 600

function lib.InstallService(ns, service)
	lib.serviceAddons[ns.addonName] = true
	local d = ns.defaults
	d.serviceOn, d.serviceMessage, d.serviceReply = true, service.example, service.reply or ""
	d.serviceChannel, d.serviceInterval, d.serviceSound = "Trade", 60, true
	d.serviceAutoWhisper, d.serviceTriggers = false, {}
	ns.service = service

	local function Available()
		if not service.available then return true end
		local ok, v = pcall(service.available)
		return ok and v and true or false
	end
	local function Spec()
		local t = service.targets
		if type(t) == "function" then t = t() end
		return { keywords = service.keywords, targets = t, weak = service.weak, extra = ns.db.serviceTriggers }
	end
	local function Fills(extra)
		local f = {
			zone = function() return GetZoneText and GetZoneText() or nil end,
			level = function() return UnitLevel and UnitLevel("player") or nil end,
		}
		for k, v in pairs(service.fill or {}) do f[k] = v end
		for k, v in pairs(extra or {}) do f[k] = v end
		return f
	end
	function ns.ServiceMessage() return ns.db.serviceMessage or service.example end
	function ns.ServicePreview() return lib.ServiceFill(ns.ServiceMessage(), Fills()) end
	local function Send(text, kind, target)
		local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G.SendChatMessage
		if not send then return false, "no chat API" end
		return pcall(send, text, kind, nil, target)
	end
	-- the channel number of serviceChannel ("Trade" matches "Trade - City"), or nil
	local function ChannelID()
		if not GetChannelList then return nil end
		local want = strlower(ns.db.serviceChannel or "Trade")
		local list = { GetChannelList() }
		for i = 1, #list, 3 do
			local id, name = list[i], list[i + 1]
			if type(name) == "string" and strlower(name):sub(1, #want) == want then return id end
		end
	end

	-- post the message: from a key press, click or typed slash command only (the client's rule)
	local lastPost
	function ns.ServiceAnnounce()
		if not Available() then ns.Print(service.unavailable or "you can't offer this yet.") return false end
		local text = strtrim(ns.ServicePreview() or "")
		if text == "" then ns.Print("Your message is empty: write one on the Service page.") return false end
		local now, wait = GetTime(), ns.db.serviceInterval or 60
		if lastPost and now - lastPost < wait then
			ns.Print(("Wait %d s before posting again (no spam in Trade)."):format(math.ceil(wait - (now - lastPost))))
			return false
		end
		local id = ChannelID()
		if not id then
			ns.Print(("Not in a city: no %s channel to post in."):format(ns.db.serviceChannel or "Trade"))
			return false
		end
		if #text > 255 then text = text:sub(1, 255) ns.Print("Message cut to 255 characters (the chat limit).") end
		local ok, err = Send(text, "CHANNEL", id)
		if not ok then
			ns.Print("Could not post: " .. tostring(err or "the game refused the message") .. ".")
			return false
		end
		lastPost = now
		return true
	end
	ns.commands.announce = { fn = function() ns.ServiceAnnounce() end,
		help = "post your " .. strlower(service.label or "service") .. " message in Trade" }

	local seen, replied = {}, {}
	local function Short(name) return (name:match("^([^%-]+)")) or name end
	local function Link(action, name, label, color)
		return ("|cff%s|Haddon:bound:%s:%s:%s|h[%s]|h|r"):format(color, ns.addonName, action, name, label)
	end
	function ns.ServiceOnChat(event, text, sender, _, channelName, _, _, _, _, baseName)
		if not LISTEN[event] or not ns.db or not ns.db.serviceOn then return end
		if ns.IsSecret(text) or ns.IsSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
		if event == "CHAT_MSG_CHANNEL" then
			local base = type(baseName) == "string" and baseName ~= "" and baseName
				or (type(channelName) == "string" and channelName:gsub("^%d+%.%s*", "")) or ""
			base = strlower(base)
			local ok = false
			for _, p in ipairs(PUBLIC) do if base:sub(1, #p) == p then ok = true break end end
			if not ok then return end
		end
		local me = UnitName("player")
		if sender == "" or Short(sender) == me then return end
		if not Available() then return end
		local m = lib.ServiceMatch(text, Spec(), event == "CHAT_MSG_WHISPER")
		if not m then return end
		local now = GetTime()
		if seen[sender] and now - seen[sender] < DEDUPE then return end
		seen[sender] = now
		if ns.db.serviceSound then PlaySound((SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081) end
		local title = ns.cfg.title or ns.addonName
		DEFAULT_CHAT_FRAME:AddMessage(("|cff%s[%s]|r %s: %s  %s %s"):format(ns.cfg.prefix or "ffd100", title,
			sender, text, Link("invite", sender, "Invite", "00ff96"), Link("whisper", sender, "Whisper", "ff80ff")))
		if ns.db.serviceAutoWhisper and not ns.InCombat() and not (replied[sender] and now - replied[sender] < REPLY_AGAIN) then
			local reply = lib.ServiceFill(ns.db.serviceReply or service.reply or "",
				Fills({ name = Short(sender), target = m.target or "" }))
			if strtrim(reply) ~= "" then
				replied[sender] = now
				Send(reply:sub(1, 255), "WHISPER", sender)
			end
		end
	end

	-- the announce key: an override binding that clicks a plain button (a key press, so posting is allowed)
	local btn, bindLater
	function ns.BindServiceKey()
		if not btn then return end
		if InCombatLockdown() then bindLater = true return end
		bindLater = nil
		ClearOverrideBindings(btn)
		if ns.db.serviceKey then SetOverrideBindingClick(btn, true, ns.db.serviceKey, btn:GetName(), "LeftButton") end
	end

	local M = {}
	ns.modules[#ns.modules + 1] = M
	function M:Init()
		btn = CreateFrame("Button", ns.addonName .. "ServiceButton", UIParent)
		btn:Hide()
		btn:SetScript("OnClick", function() ns.ServiceAnnounce() end)
		local f = CreateFrame("Frame")
		for e in pairs(LISTEN) do f:RegisterEvent(e) end
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function(_, event, ...)
			if event == "PLAYER_REGEN_ENABLED" then
				if bindLater then ns.BindServiceKey() end
				return
			end
			local ok, err = pcall(ns.ServiceOnChat, event, ...)
			if not ok then pcall(geterrorhandler(), err) end
		end)
		ns.BindServiceKey()
	end

	-- the options page; the addon's Options.lua places it: ns.optionPages[#ns.optionPages + 1] = ns.ServicePage
	function ns.ServicePage(UI)
		local p = UI.NewPage(service.page or ((service.label or "Service") .. " service"),
			service.help or "Post your offer in Trade with a key press; hear it when someone asks.")
		local W = UI.CONTENT_W
		local third = math.floor(W / 3)
		UI.DBToggle(p, 0, p.y, third, "serviceOn", "Alerts")
		UI.DBToggle(p, third, p.y, third, "serviceSound", "Sound")
		UI.DBToggle(p, third * 2, p.y, third, "serviceAutoWhisper", "Auto-whisper")
		p:Add(32)
		p:Add(UI.Section(p, p.y, "Your message") + 2)
		local msgBox, msgH = UI.EditBox(p, p.y, nil, ns.ServiceMessage, function(t)
			t = strtrim(t)
			ns.db.serviceMessage = t ~= "" and t or nil
		end, { lines = 2 })
		p:Add(msgH)
		local names = { "zone", "level" }
		for k in pairs(service.fill or {}) do names[#names + 1] = k end
		table.sort(names)
		local preview = UI.Font(p, 12, UI.C.dim)
		preview:SetPoint("TOPLEFT", 0, p.y); preview:SetWidth(W); preview:SetJustifyH("LEFT")
		UI.Syncer(function()
			preview:SetText("Posts: " .. (ns.ServicePreview() or "") .. "\nPlaceholders: {" .. table.concat(names, "} {") .. "}")
		end)
		p:Add(34)
		local reset = UI.Button(p, "Reset to example", 160, 24)
		reset:SetPoint("TOPLEFT", 0, p.y)
		reset:SetScript("OnClick", function()
			-- the box may still have focus: put the example in it, so losing focus saves the example
			msgBox:SetText(service.example or "")
			msgBox:ClearFocus()
			ns.db.serviceMessage = nil
			local win = ns.optionsState and ns.optionsState.win
			if win and win.Sync then win.Sync() end
		end)
		local now = UI.Button(p, "Announce now", 160, 24)
		now:SetPoint("LEFT", reset, "RIGHT", 10, 0)
		now:SetScript("OnClick", function()
			msgBox.Commit() -- post what is in the box, even when it was not saved yet
			msgBox:ClearFocus()
			ns.ServiceAnnounce()
		end)
		p:Add(32)
		if service.skillField then
			p:Add(select(2, UI.EditBox(p, p.y, "Skill, when the game doesn't tell it", function() return ns.db.serviceSkill end,
				function(t) ns.db.serviceSkill = tonumber(t) end, { numeric = true, width = 80, max = 3 })))
		end
		p:Add(select(2, UI.KeyButton(p, p.y, "Announce key", "serviceKey", function() ns.BindServiceKey() end, "announce key")))
		p:Add(select(2, UI.Slider(p, p.y, "Wait between posts", "serviceInterval", 30, 300, 10, " s")))
		p:Add(select(2, UI.EditBox(p, p.y, "Channel", function() return ns.db.serviceChannel end,
			function(t) t = strtrim(t); ns.db.serviceChannel = t ~= "" and t or "Trade" end, { width = 200 })))
		p:Add(select(2, UI.EditBox(p, p.y, "Extra words (comma between)", function() return table.concat(ns.db.serviceTriggers or {}, ", ") end,
			function(t)
				local list = {}
				for w in t:gmatch("[^,]+") do w = strtrim(strlower(w)); if w ~= "" then list[#list + 1] = w end end
				ns.db.serviceTriggers = list
			end, { width = 300 })))
		p:Add(select(2, UI.EditBox(p, p.y, "Auto-whisper reply", function() return ns.db.serviceReply end,
			function(t) ns.db.serviceReply = t end, { width = 400 })))
	end
end
