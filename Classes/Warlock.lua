-- Warlock: Demon Skin / Demon Armor, Unending Breath off by default.
local ADDON, ns = ...

ns.RegisterClass("WARLOCK", function()
	ns.AuraAny("Demon Armor", { "Demon Armor", "Demon Skin" })
	ns.Aura("Unending Breath", { default = false })
end)
