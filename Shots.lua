-- LibBound screenshots for the docs: "/<addon> shots" (not in the help) opens every options page,
-- the unlocked frames and the travel panel in turn and takes a screenshot of each. Where each frame
-- sat goes into the addon's saved variables (db.shots[skin]) as fractions of the screen, so
-- LibBound/tools/crop_shots.py can cut the frames out after a /reload. The skin is fixed for the
-- session: switch skin, reload, run it again. A fight stops the run and puts everything back.
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local SHOT_WAIT = 0.6 -- seconds for a page to draw before the shot
local SHOT_GAP = 1.6  -- between shots: screenshot file names only have whole seconds
local IsSecret = lib.IsSecret

-- a frame's place on screen, top-left origin, as fractions of UIParent (independent of UI scale).
-- Takes in what the frame's own textures and child frames draw outside it (a title plate, a
-- close button), two levels deep, but nothing a scroll frame clips away.
local function Rect(f, depth)
	if not (f and f.IsVisible and f:IsVisible()) then return nil end
	local L, B, R, T
	local function Add(o)
		if not (o.IsVisible and o:IsVisible()) then return end
		local ok, l, b, w, h = pcall(o.GetRect, o)
		-- a text with a hidden (secret) value has a secret size too: no math on it, secret first
		if not ok or IsSecret(l) or IsSecret(b) or IsSecret(w) or IsSecret(h) then return end
		if not l or not w or w <= 0 or h <= 0 then return end
		local es = o.GetEffectiveScale and o:GetEffectiveScale()
		if not es or IsSecret(es) then return end
		local s = es / UIParent:GetEffectiveScale()
		l, b, w, h = l * s, b * s, w * s, h * s
		L, B = math.min(L or l, l), math.min(B or b, b)
		R, T = math.max(R or l + w, l + w), math.max(T or b + h, b + h)
	end
	local function Walk(o, d)
		Add(o)
		if o.GetRegions then for _, r in ipairs({ o:GetRegions() }) do Add(r) end end
		-- a scroll frame (or any clipping frame) draws only its own area: don't look inside
		local clips = (o.IsObjectType and o:IsObjectType("ScrollFrame")) or (o.DoesClipChildren and o:DoesClipChildren())
		if d > 0 and not clips and o.GetChildren then
			for _, c in ipairs({ o:GetChildren() }) do Walk(c, d - 1) end
		end
	end
	Walk(f, depth or 2)
	if not L then return nil end
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	L, B, R, T = math.max(0, L), math.max(0, B), math.min(W, R), math.min(H, T)
	if R <= L or T <= B then return nil end
	return { x = L / W, y = 1 - T / H, w = (R - L) / W, h = (T - B) / H }
end

-- chat windows and the chat input line: other players' names and messages, for the crop script
-- to pixelate
local function ChatRects()
	local list = {}
	for i = 1, (rawget(_G, "NUM_CHAT_WINDOWS") or 10) do
		for _, name in ipairs({ "ChatFrame" .. i, "ChatFrame" .. i .. "EditBox" }) do
			local r = Rect(rawget(_G, name), 0)
			if r then list[#list + 1] = r end
		end
	end
	return list
end

local function Slug(s) return (strlower(s):gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")) end

function lib.Shots(ns)
	if ns.shooting then ns.Print("screenshots are already running.") return end
	if InCombatLockdown() then ns.Print("leave combat first.") return end
	local opt = ns.optionsState
	if not (opt and ns.ToggleOptions) then ns.Print("no options window to shoot.") return end
	local wasUnlocked, page = ns.unlocked, ns.db.optionsPage
	if wasUnlocked then ns.ToggleMove() end -- start from the locked look
	local function Win() return opt.win end
	local function OpenOptions() if not (Win() and Win():IsShown()) then ns.ToggleOptions() end end
	local function CloseOptions() if Win() and Win():IsShown() then Win():Hide() end end

	OpenOptions() -- the pages are built the first time the window opens
	local run = { skin = ns.db.skin or "default", at = date("%Y-%m-%d %H:%M"), list = {} }
	local steps = {}
	for i, pg in ipairs(opt.pages) do
		steps[#steps + 1] = { name = "options-" .. Slug(pg.title or ("page " .. i)),
			prepare = function() OpenOptions() if opt.Select then opt.Select(i) end end,
			rects = function() return { main = Rect(Win()) } end }
	end
	steps[#steps + 1] = { name = "frames-unlocked",
		prepare = function() CloseOptions() if not ns.unlocked then ns.ToggleMove() end end,
		rects = function()
			local r = {}
			for _, m in ipairs(ns.movers or {}) do r[m.key] = Rect(m.frame) end
			return r
		end, full = true } -- the whole screen as well
	if ns.travel then
		steps[#steps + 1] = { name = "travel",
			prepare = function()
				if ns.unlocked then ns.ToggleMove() end
				if GameMenuFrame and not GameMenuFrame:IsShown() then ShowUIPanel(GameMenuFrame) end
			end,
			rects = function() return { main = Rect(rawget(_G, ns.addonName .. "Travel")) } end }
	end

	local cvar = rawget(_G, "C_CVar")
	local format = cvar and cvar.GetCVar and cvar.GetCVar("screenshotFormat")
	if format then cvar.SetCVar("screenshotFormat", "png") end
	ns.shooting = true
	local function Finish(done, why)
		ns.shooting = nil
		if format then cvar.SetCVar("screenshotFormat", format) end
		CloseOptions()
		-- the game menu and the frame lock can't change in a fight: put them back once it's over
		local function Restore()
			if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
			if ns.unlocked ~= wasUnlocked then ns.ToggleMove() end
		end
		if InCombatLockdown() then
			local wait = CreateFrame("Frame")
			wait:RegisterEvent("PLAYER_REGEN_ENABLED")
			wait:SetScript("OnEvent", function(self) self:UnregisterAllEvents() Restore() end)
		else
			Restore()
		end
		ns.db.optionsPage = page
		ns.db.shots = ns.db.shots or {}
		ns.db.shots[run.skin] = run
		local msg = (done and "" or ("stopped (" .. (why or "combat") .. "): ")) .. #run.list .. " screenshots of skin '"
			.. run.skin .. "'. /reload, then: python3 LibBound/tools/crop_shots.py " .. ns.addonName
		ns.Print(msg)
		-- also mid-screen with a sound: the chat line is easy to miss
		local errors = rawget(_G, "UIErrorsFrame")
		if errors then errors:AddMessage(ns.addonName .. ": " .. msg, 1, 0.82, 0) end
		if SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK) end
	end
	local function Next(i)
		local st = steps[i]
		if not st or InCombatLockdown() then Finish(not st) return end
		-- an error must not leave the frames unlocked and the run hanging: report it and clean up
		local ok, err = pcall(st.prepare)
		if not ok then Finish(false, st.name .. ": " .. tostring(err)) return end
		C_Timer.After(SHOT_WAIT, function()
			if InCombatLockdown() then Finish(false) return end
			local got, rects = pcall(st.rects)
			if not got then Finish(false, st.name .. ": " .. tostring(rects)) return end
			run.list[#run.list + 1] = { name = st.name, at = date("%m%d%y_%H%M%S"), rects = rects, full = st.full,
				hide = ChatRects() }
			Screenshot()
			C_Timer.After(SHOT_GAP, function() Next(i + 1) end)
		end)
	end
	ns.Print("taking " .. #steps .. " screenshots: don't touch anything for about "
		.. math.ceil(#steps * (SHOT_WAIT + SHOT_GAP)) .. " s.")
	Next(1)
end
