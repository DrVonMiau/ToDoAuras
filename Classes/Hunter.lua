-- Hunter: an aspect, Trueshot Aura (off by default).
local ADDON, ns = ...

ns.RegisterClass("HUNTER", function()
	ns.AuraAny("Aspect", {
		"Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah",
		"Aspect of the Pack", "Aspect of the Beast", "Aspect of the Wild",
	})
	ns.Aura("Trueshot Aura", { default = false })
end)
