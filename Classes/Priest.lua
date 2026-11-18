-- Priest: Fortitude, Inner Fire; Spirit, Shadow Protection and Shadowform off by default.
local ADDON, ns = ...

ns.RegisterClass("PRIEST", function()
	ns.AuraAny("Fortitude", { "Power Word: Fortitude", "Prayer of Fortitude" }, { targeted = true })
	ns.Aura("Inner Fire")
	ns.AuraAny("Divine Spirit", { "Divine Spirit", "Prayer of Spirit" }, { default = false, targeted = true })
	ns.AuraAny("Shadow Protection", { "Shadow Protection", "Prayer of Shadow Protection" }, { default = false, targeted = true })
	ns.Aura("Shadowform", { default = false })
end)
