-- Stack bars: a small segmented bar for a stacking buff (Maelstrom Weapon),
-- separate from the to-do list.
--
-- In combat Forever hides buff stacks from addons, but the game still draws
-- them itself. An "aura container" is a frame the game fills with one of your
-- buffs. Each slot drives one bar, which the game shows only from a set stack
-- count. So the bar is built from one container per segment: segment n shows
-- from n stacks, and the last one also turns the whole bar gold. The addon
-- never reads the count, so it works in combat too.
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

local function Quiet(button, holder)
	button:ClearAllPoints()
	button:SetAllPoints(holder)
	if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
	if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
	-- hide the button's own icon and count, if it has any
	for _, k in ipairs({ "Icon", "icon", "Count", "count", "Cooldown", "cooldown", "Border", "border" }) do
		local r = button[k]
		if type(r) == "table" and r.SetAlpha then pcall(r.SetAlpha, r, 0) end
	end
end

-- The game calls this once for segment n's button: hang our parts on it.
-- Its bar is shown by the game only from n stacks.
local function Dress(b, n, button)
	local holder = b.holder
	Quiet(button, holder)
	local level = holder:GetFrameLevel()
	if n == 1 then
		-- shown with any stacks: the empty backing and the dividers
		local base = CreateFrame("Frame", nil, button)
		base:SetAllPoints(holder)
		base:SetFrameLevel(level + 1)
		Backing(base)
		Dividers(button, b.max, level + 10)
	end
	local seg = CreateFrame("StatusBar", nil, button)
	seg:SetPoint("TOPLEFT", holder, "TOPLEFT", W * (n - 1) / b.max, 0)
	seg:SetSize(W / b.max, H)
	seg:SetFrameLevel(level + 2)
	seg:SetStatusBarTexture(TEX)
	seg:SetStatusBarColor(FILL[1], FILL[2], FILL[3])
	seg:SetMinMaxValues(n, n)
	seg:SetValue(n)
	seg:EnableMouse(false)
	if n == b.max then
		-- full: the whole bar gold, with a pulsing glow (a child, so it shows with this segment)
		local full = CreateFrame("Frame", nil, seg)
		full:SetAllPoints(holder)
		full:SetFrameLevel(level + 5)
		local t = full:CreateTexture(nil, "ARTWORK")
		t:SetAllPoints(full)
		t:SetTexture(TEX)
		t:SetVertexColor(FULL[1], FULL[2], FULL[3])
		Glow(full)
	end
	local ok = pcall(button.SetApplicationBar, button, seg, { minApplications = n, maxApplications = n })
	b.dressed = (b.dressed ~= false) and ok
end

local function NewContainer(b, n, include)
	local ok, c = pcall(CreateFrame, "AuraContainer", nil, b.holder, "CustomAuraContainerTemplate")
	if not (ok and c and type(c.AddAuraSlot) == "function") then return nil end
	c:ClearAllPoints()
	c:SetSize(1, 1)
	c:SetPoint("CENTER", b.holder, "CENTER")
	if c.SetEditModePreviewEnabled then pcall(c.SetEditModePreviewEnabled, c, false) end
	local okSlot = pcall(c.AddAuraSlot, c, b.key .. n, "HELPFUL|PLAYER", {
		candidateFilters = { includeSpellIDs = include },
		initializeFrame = function(button) Dress(b, n, button) end,
	})
	if not okSlot then return nil end
	return c
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

	local include = {}
	for _, id in ipairs(b.spellIDs) do include[id] = true end
	b.containers = {}
	for n = 1, b.max do
		local c = NewContainer(b, n, include)
		if not c then
			b.failed = true
			for _, old in ipairs(b.containers) do pcall(old.SetEnabled, old, false); old:Hide() end
			b.containers = nil
			ns.Print(b.title .. ": this game version can't draw it.")
			return
		end
		b.containers[n] = c
	end
end

-- Turn the game's drawing on or off (out of combat only; otherwise after the fight).
local function Apply(b)
	if not b.built then Build(b) end
	if b.failed or not b.containers then return end
	if InCombatLockdown() then b.pending = true; return end
	b.pending = nil
	local on = Enabled(b)
	for _, c in ipairs(b.containers) do
		pcall(c.SetUnit, c, on and "player" or "none")
		pcall(c.SetEnabled, c, on)
		if on and c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
	end
	b.holder:SetShown(on or b.moving or false)
end

-- Move mode (its own, apart from the list's): a sample bar, 3 of 5, on blue, draggable.
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
		label:SetText(b.title .. ": drag, then click Lock bar")
		b.sample = s
	end
	if b.sample then b.sample:SetShown(show) end
	b.moving = show or nil
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

function ns.SetBarUnlocked(key, on)
	for _, b in ipairs(ns.bars) do
		if b.key == key or key == nil then
			if not b.built then Build(b) end
			Sample(b, on and true or false)
		end
	end
	if ns.RefreshPanel then ns.RefreshPanel() end
end

function ns.BarUnlocked(key)
	for _, b in ipairs(ns.bars) do
		if b.key == key then return b.moving and true or false end
	end
	return false
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
