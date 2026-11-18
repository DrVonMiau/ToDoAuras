-- Shaman: weapon imbue, Lightning Shield, totems (bottom to top in this order).
local ADDON, ns = ...

ns.RegisterClass("SHAMAN", function()
	ns.WeaponImbue({ "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon" },
		{ title = "Weapon imbue", key = "imbue" })
	ns.Aura("Lightning Shield", { key = "shield" })
	ns.Totem(1, "Fire")
	ns.Totem(2, "Earth")
	ns.Totem(3, "Water")
	ns.Totem(4, "Air")
end)
