-- Druid: Mark of the Wild, Thorns, Omen of Clarity.
local ADDON, ns = ...

ns.RegisterClass("DRUID", function()
	ns.AuraAny("Mark of the Wild", { "Mark of the Wild", "Gift of the Wild" })
	ns.Aura("Thorns")
	ns.Aura("Omen of Clarity")
end)
