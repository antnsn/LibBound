-- Unit tests for Service.lua's pure part (matching and templates). Run from the repo root:
--   lua5.1 tests/test_service.lua
local lib = { installing = 33 }
LibStub = function() return lib end -- luacheck: ignore
dofile("Service.lua")

local pass, fail = 0, 0
local function eq(label, got, want)
	if got == want then pass = pass + 1 else
		fail = fail + 1
		print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
	end
end

local PORTALS = {
	keywords = { "portal", "portals" },
	targets = { org = "Orgrimmar", orgrimmar = "Orgrimmar", uc = "Undercity", undercity = "Undercity",
		tb = "Thunder Bluff", ["thunder bluff"] = "Thunder Bluff" },
}
local LOCKBOX = { keywords = { "lockbox", "lockboxes", "junkbox", "lockpick", "lockpicking", "open box" } }

-- { text, fromWhisper, expected target (string), true (fires, no target) or false (no fire) }
local cases = {
	{ "wtb port org", false, "Orgrimmar" },
	{ "WTB PORT ORG!!", false, "Orgrimmar" },
	{ "port->uc?", false, "Undercity" },
	{ "any portal to thunder bluff?", false, "Thunder Bluff" },
	{ "lf mage port tb", false, "Thunder Bluff" },
	{ "org", true, "Orgrimmar" },
	{ "portal pls", true, true },
	{ "tips?", true, false }, -- no keyword or target, even in a whisper
	{ "going to org later", false, false },
	{ "ucla", false, false },
	{ "lol port", false, false },
	{ "portal", false, false },
	{ "WTS portals to Org/UC/TB, tips welcome", false, false },
	{ "Portals to Org /w me", false, false },
	{ "thunder", false, false },
	{ "anyone selling port to org?", false, false },
}
for i, c in ipairs(cases) do
	local m = lib.ServiceMatch(c[1], PORTALS, c[2])
	local got = m and (m.target or true) or false
	eq("portal case " .. i .. " '" .. c[1] .. "'", got, c[3])
end

local boxCases = {
	{ "anyone open lockbox?", false, true },
	{ "need lockpicking", false, true },
	{ "can someone open box", false, true },
	{ "lockbox", false, false },
	{ "WTS lockbox opening, tips", false, false },
	{ "lockbox", true, true },
	{ "wtb open |cff1eff00|Hitem:4632::::::::20:::::::|h[Ornate Bronze Lockbox]|h|r", false, true },
}
for i, c in ipairs(boxCases) do
	local m = lib.ServiceMatch(c[1], LOCKBOX, c[2])
	eq("lockbox case " .. i .. " '" .. c[1] .. "'", m and true or false, c[3])
end

-- weak words ("port"): a request only with another intent word, or in a whisper
local WEAK = { keywords = { "portal" }, targets = { org = "Orgrimmar" }, weak = { "port", "ports" } }
for i, c in ipairs({
	{ "need a port pls", false, true }, { "lf port", false, true }, { "wtb port", false, true },
	{ "port?", false, true }, { "lol port", false, false }, { "port", false, false },
	{ "port", true, true }, { "wts port", false, false }, { "wtb port org", false, "Orgrimmar" },
}) do
	local mm = lib.ServiceMatch(c[1], WEAK, c[2])
	eq("weak case " .. i .. " '" .. c[1] .. "'", mm and (mm.target or true) or false, c[3])
end

-- user trigger words count as keywords
local withExtra = { keywords = { "portal" }, targets = {}, extra = { "dala" } }
eq("extra word fires with intent", lib.ServiceMatch("wtb dala", withExtra, false) and true or false, true)

-- words
local w = lib.ServiceWords("WTB Port->UC?")
eq("words lowercased", table.concat(w, ","), "wtb,port,uc,?")

-- templates
eq("fill", lib.ServiceFill("Portals to {portals}! 50% off {x}", { portals = "Orgrimmar, Undercity" }),
	"Portals to Orgrimmar, Undercity! 50% off {x}")
eq("fill function", lib.ServiceFill("Lockpicking {skill}", { skill = function() return 75 end }), "Lockpicking 75")
eq("fill nil keeps", lib.ServiceFill("Lockpicking {skill}", { skill = function() return nil end }), "Lockpicking {skill}")
eq("fill %", lib.ServiceFill("{a}", { a = "100%" }), "100%")

print(("ok %d/%d"):format(pass, pass + fail))
os.exit(fail == 0 and 0 or 1)
