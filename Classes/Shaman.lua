-- Shaman: weapon imbue, Lightning Shield, totems (bottom to top).
local ADDON, ns = ...

ns.RegisterClass("SHAMAN", function()
	ns.WeaponImbue({ "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon" },
		{ title = "Weapon imbue", key = "imbue" })
	ns.Aura("Lightning Shield", { key = "shield", charges = 3 })
	-- drawn by the game itself, so it keeps working in combat
	ns.StackBar({ key = "msbar", title = "Maelstrom Weapon bar", spellIDs = { 408505 }, max = 5 })
	ns.Totem(1, "Fire")
	ns.Totem(2, "Earth")
	ns.Totem(3, "Water")
	ns.Totem(4, "Air")
end)
