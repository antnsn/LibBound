-- luacheck config: run "luacheck ." from this folder (Lua 5.1, like the WoW client).
std = "lua51"
max_line_length = false
ignore = { "212", "432" }
exclude_files = { "Libs/" }
read_globals = {
	"AddonCompartmentFrame", "C_AddOns", "C_Spell", "C_Timer", "C_UnitAuras", "ChatTypeInfo", "CreateColor",
	"CreateFrame", "GameTooltip", "geterrorhandler", "GetCursorPosition", "GetTime", "HideUIPanel", "InCombatLockdown",
	"IsMouseButtonDown", "IsPlayerSpell", "IsShiftKeyDown", "LibStub", "Minimap", "PlaySound", "RaidNotice_AddMessage",
	"RaidWarningFrame", "RegisterStateDriver", "ReloadUI", "Settings", "SettingsPanel", "SOUNDKIT", "strlower",
	"strsplit", "strtrim", "tinsert", "UIParent", "UISpecialFrames", "UnitAffectingCombat", "UnitClass",
	"UnitIsDeadOrGhost", "UnitName", "issecretvalue", "canaccessvalue",
}
globals = { "SlashCmdList", "_G" }
