-- Stack bars: a small segmented bar for a stacking buff (Maelstrom Weapon),
-- separate from the to-do list.
--
-- In combat Forever hides buff stacks from addons, but the game still draws
-- them itself. An "aura container" is a frame the game fills with one of your
-- buffs: it shows our parts only while the buff is on you, sets the fill bar
-- to the stack count, and shows the "full" layer only at max stacks. The
-- addon never reads the count, so it works in combat too.
--
--   ns.StackBar({ key, title, spellIDs = { ... }, max = 5 })

local ADDON, ns = ...

ns.bars = {}

local W, H = 200, 12
local FILL = { 0.25, 0.6, 1 }    -- stacks building up: blue
local FULL = { 1, 0.82, 0.15 }   -- max stacks: gold, with a pulsing glow
local TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local function Enabled(b)
	local v = ns.cdb and ns.cdb.track and ns.cdb.track[b.key]
	if v == nil then return true end
	return v
end
ns.BarEnabled = Enabled

-- Default spot: just above the player's cast bar.
local function DefaultPoint(h)
	local cast = PlayerCastingBarFrame or CastingBarFrame
	h:ClearAllPoints()
	if cast then
		h:SetPoint("BOTTOM", cast, "TOP", 0, 10)
	else
		h:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
	end
end

local function ApplyPosition(b)
	local p = ns.cdb.barPos and ns.cdb.barPos[b.key]
	if p then
		b.holder:ClearAllPoints()
		b.holder:SetPoint("CENTER", UIParent, "CENTER", p[1], p[2])
	else
		DefaultPoint(b.holder)
	end
end

-- Thin dark lines between the segments, on their own layer above the fills.
local function Dividers(parent, max, level)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints(parent)
	f:SetFrameLevel(level)
	for i = 1, max - 1 do
		local t = f:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(0, 0, 0, 0.9)
		t:SetSize(2, H)
		t:SetPoint("CENTER", parent, "LEFT", W * i / max, 0)
	end
	return f
end

local function Backing(parent)
	local bg = parent:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", -1, 1)
	bg:SetPoint("BOTTOMRIGHT", 1, -1)
	bg:SetColorTexture(0, 0, 0, 0.6)
	return bg
end

-- A glow round the bar that breathes while it's shown.
local function Glow(parent)
	local g = CreateFrame("Frame", nil, parent)
	g:SetPoint("TOPLEFT", -4, 4)
	g:SetPoint("BOTTOMRIGHT", 4, -4)
	local t = g:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints(g)
	t:SetColorTexture(FULL[1], FULL[2], FULL[3], 0.45)
	local ag = g:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.2)
	a:SetDuration(0.45)
	ag:Play()
	return g
end

-- The game calls this once for the container's button: hang our parts on it.
local function Dress(b, button)
	local holder = b.holder
	button:ClearAllPoints()
	button:SetAllPoints(holder)
	if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
	if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
	-- hide the button's own icon and count, if it has any
	for _, k in ipairs({ "Icon", "icon", "Count", "count", "Cooldown", "cooldown", "Border", "border" }) do
		local r = button[k]
		if type(r) == "table" and r.SetAlpha then pcall(r.SetAlpha, r, 0) end
	end

	local base = CreateFrame("Frame", nil, button)
	base:SetAllPoints(holder)
	Backing(base)

	-- fill: the game sets its value to the stack count (0 to max)
	local fill = CreateFrame("StatusBar", nil, button)
	fill:SetAllPoints(holder)
	fill:SetStatusBarTexture(TEX)
	fill:SetStatusBarColor(FILL[1], FILL[2], FILL[3])
	fill:SetMinMaxValues(0, b.max)
	fill:SetValue(0)
	fill:EnableMouse(false)
	local ok1 = pcall(button.SetApplicationBar, button, fill, { minApplications = 0, maxApplications = b.max })

	-- full: the game shows this only from max stacks
	local full = CreateFrame("StatusBar", nil, button)
	full:SetAllPoints(holder)
	full:SetStatusBarTexture(TEX)
	full:SetStatusBarColor(FULL[1], FULL[2], FULL[3])
	full:SetMinMaxValues(b.max, b.max)
	full:SetValue(b.max)
	full:EnableMouse(false)
	Glow(full)
	local ok2 = pcall(button.SetApplicationBar, button, full, { minApplications = b.max, maxApplications = b.max })

	Dividers(button, b.max, full:GetFrameLevel() + 2)
	b.dressed = ok1 and ok2
end

local function Build(b)
	if b.built or InCombatLockdown() then return end
	b.built = true
	local holder = CreateFrame("Frame", "ToDoAuras_" .. b.key, UIParent)
	holder:SetSize(W, H)
	holder:SetMovable(true)
	holder:SetClampedToScreen(true)
	b.holder = holder
	ApplyPosition(b)

	local ok, c = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not (ok and c and type(c.AddAuraSlot) == "function") then
		b.failed = true
		ns.Print(b.title .. ": this game version can't draw it.")
		return
	end
	c:ClearAllPoints()
	c:SetSize(1, 1)
	c:SetPoint("CENTER", holder, "CENTER")
	if c.SetEditModePreviewEnabled then pcall(c.SetEditModePreviewEnabled, c, false) end
	local include = {}
	for _, id in ipairs(b.spellIDs) do include[id] = true end
	local okSlot = pcall(c.AddAuraSlot, c, b.key, "HELPFUL|PLAYER", {
		candidateFilters = { includeSpellIDs = include },
		initializeFrame = function(button) Dress(b, button) end,
	})
	if not okSlot then
		b.failed = true
		ns.Print(b.title .. ": this game version can't draw it.")
		return
	end
	b.container = c
end

-- Turn the game's drawing on or off (out of combat only; otherwise after the fight).
local function Apply(b)
	if not b.built then Build(b) end
	if b.failed or not b.container then return end
	if InCombatLockdown() then b.pending = true; return end
	b.pending = nil
	local on = Enabled(b)
	pcall(b.container.SetUnit, b.container, on and "player" or "none")
	pcall(b.container.SetEnabled, b.container, on)
	if on and b.container.UpdateAllAuras then pcall(b.container.UpdateAllAuras, b.container) end
	b.holder:SetShown(on)
end

-- Move mode: a sample bar (3 of 5) on a blue backing, draggable.
local function Sample(b, show)
	if not b.holder then return end
	if show and not b.sample then
		local s = CreateFrame("Frame", nil, b.holder)
		s:SetAllPoints(b.holder)
		s:SetFrameLevel(b.holder:GetFrameLevel() + 20)
		local bg = s:CreateTexture(nil, "BACKGROUND")
		bg:SetPoint("TOPLEFT", -4, 4)
		bg:SetPoint("BOTTOMRIGHT", 4, -4)
		bg:SetColorTexture(0.1, 0.3, 0.8, 0.5)
		local fill = s:CreateTexture(nil, "ARTWORK")
		fill:SetPoint("TOPLEFT")
		fill:SetPoint("BOTTOMLEFT")
		fill:SetWidth(W * 3 / b.max)
		fill:SetTexture(TEX)
		fill:SetVertexColor(FILL[1], FILL[2], FILL[3])
		Dividers(s, b.max, s:GetFrameLevel() + 1)
		local label = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("BOTTOM", s, "TOP", 0, 6)
		label:SetText(b.title)
		b.sample = s
	end
	if b.sample then b.sample:SetShown(show) end
	local h = b.holder
	h:EnableMouse(show)
	if show then
		h:Show()
		h:RegisterForDrag("LeftButton")
		h:SetScript("OnDragStart", h.StartMoving)
		h:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local x, y = self:GetCenter()
			local ux, uy = UIParent:GetCenter()
			ns.cdb.barPos = ns.cdb.barPos or {}
			ns.cdb.barPos[b.key] = { x - ux, y - uy }
			ApplyPosition(b)
		end)
	else
		h:SetScript("OnDragStart", nil)
		h:SetScript("OnDragStop", nil)
		h:SetShown(Enabled(b))
	end
end

function ns.StackBar(opts)
	local b = { key = opts.key, title = opts.title, spellIDs = opts.spellIDs, max = opts.max or 5 }
	ns.bars[#ns.bars + 1] = b
	return b
end

function ns.SetBarEnabled(key, on)
	ns.cdb.track[key] = on and true or false
	for _, b in ipairs(ns.bars) do
		if b.key == key then Apply(b) end
	end
end

function ns.ResetBars()
	if not ns.cdb.barPos then return end
	ns.cdb.barPos = nil
	for _, b in ipairs(ns.bars) do
		if b.holder then ApplyPosition(b) end
	end
end

local ResetPosition = ns.ResetPosition
function ns.ResetPosition()
	ResetPosition()
	ns.ResetBars()
end

-- Move mode for the bars rides along with the list's.
local SetUnlocked = ns.SetUnlocked
function ns.SetUnlocked(on)
	SetUnlocked(on)
	for _, b in ipairs(ns.bars) do
		if not b.built then Build(b) end
		Sample(b, on and true or false)
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_REGEN_ENABLED" then return end
	for _, b in ipairs(ns.bars) do
		if event == "PLAYER_ENTERING_WORLD" or b.pending or not b.built then Apply(b) end
	end
end)
