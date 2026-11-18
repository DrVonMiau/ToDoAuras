-- Paladin: blessing on yourself, aura, Righteous Fury (off by default).
local ADDON, ns = ...

ns.RegisterClass("PALADIN", function()
	ns.AuraAny("Blessing", {
		"Blessing of Might", "Blessing of Wisdom", "Blessing of Kings",
		"Blessing of Salvation", "Blessing of Light", "Blessing of Sanctuary",
		"Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
		"Greater Blessing of Salvation", "Greater Blessing of Light", "Greater Blessing of Sanctuary",
	}, { targeted = true })
	ns.AuraAny("Paladin aura", {
		"Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura",
		"Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura",
	})
	ns.Aura("Righteous Fury", { default = false })
end)
