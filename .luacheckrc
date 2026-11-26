-- luacheck config: run "luacheck ." from this folder (Lua 5.1, like the WoW client).
std = "lua51"
max_line_length = false
ignore = { "212", "432" }
exclude_files = { "Libs/" }
read_globals = {
	"AddonCompartmentFrame", "Enum", "GetComboPoints", "UnitPower", "UnitPowerMax", "C_AddOns", "ClearOverrideBindings", "GetNumGroupMembers", "GetRaidRosterInfo", "IsInRaid", "SetOverrideBindingClick", "UnitCanAssist", "UnitExists", "UnitInRange", "UnitIsConnected", "UnitIsUnit", "UnitIsVisible", "C_Item", "GameMenuFrame", "GetBindLocation", "GetCVarBool", "C_Spell", "C_Timer", "C_UnitAuras", "ChatTypeInfo", "CreateColor",
	"CreateFrame", "date", "GameTooltip", "geterrorhandler", "GetCursorPosition", "GetTime", "HideUIPanel", "InCombatLockdown",
	"IsAltKeyDown", "IsControlKeyDown", "IsMouseButtonDown", "IsPlayerSpell", "IsShiftKeyDown", "LibStub", "Minimap", "PlaySound", "RaidNotice_AddMessage",
	"RaidWarningFrame", "RegisterStateDriver", "ReloadUI", "Screenshot", "ShowUIPanel", "Settings", "SettingsPanel", "SOUNDKIT", "strlower",
	"strsplit", "strtrim", "tinsert", "UIParent", "UISpecialFrames", "UnitAffectingCombat", "UnitClass",
	"UnitIsDeadOrGhost", "UnitName", "issecretvalue", "canaccessvalue", "hooksecurefunc", "CooldownViewerSettings", "UnitGUID", "GetCVar", "SetCVar",
	"IsMounted", "IsInInstance", "GetInventoryItemID", "EquipItemByName", "C_Container", "PickupInventoryItem", "PutItemInBackpack",
	"PutItemInBag", "ContainerIDToInventoryID", "CursorHasItem", "NUM_BAG_SLOTS", "GetRealmName", "GetItemCount",
	"GetZoneText", "UnitLevel", "C_ChatInfo", "C_PartyInfo", "GetChannelList", "DEFAULT_CHAT_FRAME", "ChatFrame_OpenChat",
}
globals = { "SlashCmdList", "_G" }
