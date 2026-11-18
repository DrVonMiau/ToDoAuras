-- Rogue: poisons on both weapons, Slice and Dice (off by default).
local ADDON, ns = ...

ns.RegisterClass("ROGUE", function()
	ns.WeaponImbue({ "Instant Poison", "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Wound Poison" },
		{ title = "Poison", key = "poison" })
	ns.Aura("Slice and Dice", { default = false })
end)
