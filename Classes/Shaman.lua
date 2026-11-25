-- Shaman: weapon imbue, Lightning Shield, Maelstrom Weapon stacks, totems (bottom to top).
local ADDON, ns = ...

ns.RegisterClass("SHAMAN", function()
	ns.WeaponImbue({ "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon" },
		{ title = "Weapon imbue", key = "imbue" })
	ns.Aura("Lightning Shield", { key = "shield", charges = true })
	ns.Stacks("Maelstrom Weapon", {
		key = "maelstrom", title = "Maelstrom Weapon (ready at stacks)", threshold = 5, maxStacks = 5,
		consumers = { "Lightning Bolt", "Chain Lightning", "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Hex" },
	})
	ns.Totem(1, "Fire")
	ns.Totem(2, "Earth")
	ns.Totem(3, "Water")
	ns.Totem(4, "Air")
end)
