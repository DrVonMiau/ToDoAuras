-- Mage: Intellect, armor; Dampen/Amplify Magic off by default.
local ADDON, ns = ...

ns.RegisterClass("MAGE", function()
	ns.AuraAny("Arcane Intellect", { "Arcane Intellect", "Arcane Brilliance" })
	ns.AuraAny("Mage armor", { "Frost Armor", "Ice Armor", "Mage Armor" })
	ns.AuraAny("Dampen / Amplify Magic", { "Dampen Magic", "Amplify Magic" }, { default = false })
end)
