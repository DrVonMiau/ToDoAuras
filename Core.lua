-- ToDoAuras core: a to-do list of your own buffs, imbues and totems.
-- A row appears only when something expires within the warning time
-- ("expires in 4s", default 5 seconds) or has expired ("expired"). The list
-- grows from the bottom up, in the order the class module adds its trackers.
--
-- Cost: work happens on events (aura, totem, inventory, combat changes). A
-- one-shot timer wakes the addon when the next item enters the warning
-- window, and a 0.2 s ticker runs only while a countdown row is on screen.
--
-- Forever can hide ("secret") some values in combat. Every game call goes
-- through Safe(): a refused call or a secret value means "unknown", and the
-- tracker keeps what it last knew instead of erroring.

local ADDON, ns = ...

local ROW_H, ICON = 22, 20
local GetTime, ceil, format = GetTime, math.ceil, string.format

---------------------------------------------------------------------------
-- Safe calls
---------------------------------------------------------------------------

local function Secret(v)
	return type(issecretvalue) == "function" and issecretvalue(v) or false
end
ns.Secret = Secret

local function check(ok, ...)
	if not ok then return false end
	for i = 1, select("#", ...) do
		if Secret((select(i, ...))) then return false end
	end
	return true, ...
end

-- ok, results... ; ok is false when the call errors or any result is secret.
function ns.Safe(fn, ...)
	if type(fn) ~= "function" then return false end
	return check(pcall(fn, ...))
end

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
function ns.SpellIcon(name)
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, tex = ns.Safe(C_Spell.GetSpellTexture, name)
		if ok and tex then return tex end
	end
	if GetSpellTexture then
		local ok, tex = ns.Safe(GetSpellTexture, name)
		if ok and tex then return tex end
	end
	return QUESTION
end

-- True when the spell (by name) is in the player's spellbook.
function ns.Knows(name)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = ns.Safe(C_Spell.GetSpellInfo, name)
		if ok then return info ~= nil end
	end
	if GetSpellInfo then
		local ok, n = ns.Safe(GetSpellInfo, name)
		if ok then return n ~= nil end
	end
	return false
end

---------------------------------------------------------------------------
-- Trackers
---------------------------------------------------------------------------
-- A tracker is a table with:
--   key          unique id (settings, /tda on|off <key>)
--   title        text for the settings checkbox
--   default      false = unticked until the player turns it on
--   Update(t)    refreshes t.status ("active" | "missing" | "none"),
--                t.expires (GetTime() based, nil = no end), t.label, t.icon
--   OnEvent      optional, receives every event
--   Events       list of events that should trigger a refresh

ns.trackers = {}
local events = {}

function ns.Add(tracker)
	tracker.status = "none"
	tracker.title = tracker.title or tracker.label or tracker.key
	ns.trackers[#ns.trackers + 1] = tracker
	for _, e in ipairs(tracker.Events or {}) do events[e] = true end
	return tracker
end

local classModules = {}
function ns.RegisterClass(classFile, setup)
	classModules[classFile] = setup
end

local db, cdb

local function Enabled(t)
	local v = cdb.track[t.key]
	if v == nil then return t.default ~= false end
	return v
end
ns.Enabled = Enabled

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

local anchor = CreateFrame("Frame", "ToDoAurasAnchor", UIParent)
anchor:SetSize(240, ROW_H)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:Hide()

local bg = anchor:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.2, 0.6, 1, 0.35)
bg:Hide()

local rows = {}
local function Row(i)
	local r = rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, anchor)
	r:SetSize(240, ROW_H)
	r:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, (i - 1) * (ROW_H + 2))
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(ICON, ICON)
	r.icon:SetPoint("LEFT")
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.text:SetShadowOffset(1, -1)
	rows[i] = r
	return r
end

local function Show(i, icon, text, expired)
	local r = Row(i)
	r.icon:SetTexture(icon or QUESTION)
	r.icon:SetDesaturated(expired and true or false)
	r.text:SetText(text)
	if expired then r.text:SetTextColor(1, 0.3, 0.25) else r.text:SetTextColor(1, 0.82, 0.2) end
	r:Show()
end

local function ApplyPosition()
	anchor:ClearAllPoints()
	local p = db.pos
	anchor:SetPoint(p[1], UIParent, p[1], p[2], p[3])
	anchor:SetScale(db.scale or 1)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local ticker, wake
local Refresh

local function Hidden()
	return UnitIsDeadOrGhost("player") or (UnitOnTaxi and UnitOnTaxi("player"))
end

local function Schedule(now, counting)
	if counting and not ticker then
		ticker = C_Timer.NewTicker(0.2, function() Refresh() end)
	elseif not counting and ticker then
		ticker:Cancel(); ticker = nil
	end
	if wake then wake:Cancel(); wake = nil end
	local soonest
	for _, t in ipairs(ns.trackers) do
		if Enabled(t) and t.status == "active" and t.expires then
			local d = t.expires - db.window - now
			if d > 0 and (not soonest or d < soonest) then soonest = d end
		end
	end
	if soonest then wake = C_Timer.NewTimer(soonest + 0.05, function() wake = nil; Refresh() end) end
end

function Refresh()
	if not cdb then return end
	local now = GetTime()
	for _, t in ipairs(ns.trackers) do
		if Enabled(t) then t:Update(now) end
	end

	if ns.testMode then
		-- Sample rows: items in use first, then the other ticked ones.
		local n = 0
		for pass = 1, 2 do
			for _, t in ipairs(ns.trackers) do
				local inUse = t.status ~= "none"
				if Enabled(t) and n < 3 and ((pass == 1) == inUse) then
					n = n + 1
					local name = t.label or t.title
					Show(n, t.icon or ns.SpellIcon(name), n == 2 and (name .. " expired")
						or format("%s expires in %ds", name, 5 - n), n == 2)
				end
			end
		end
		if n == 0 then Show(1, QUESTION, "ToDoAuras (nothing ticked)"); n = 1 end
		for i = n + 1, #rows do rows[i]:Hide() end
		anchor:Show()
		return
	end

	local n, counting = 0, false
	if not Hidden() then
		for _, t in ipairs(ns.trackers) do
			if Enabled(t) then
				if t.status == "missing" then
					n = n + 1
					Show(n, t.icon, t.label .. " expired", true)
				elseif t.status == "active" and t.expires then
					local left = t.expires - now
					if left <= db.window then
						n = n + 1
						counting = true
						Show(n, t.icon, format("%s expires in %ds", t.label, math.max(0, ceil(left))))
					end
				end
			end
		end
	end
	for i = n + 1, #rows do rows[i]:Hide() end
	anchor:SetShown(n > 0)
	Schedule(now, counting)
end
ns.Refresh = Refresh

---------------------------------------------------------------------------
-- Unlock / test mode
---------------------------------------------------------------------------

function ns.SetUnlocked(on)
	ns.testMode = on and true or false
	anchor:EnableMouse(ns.testMode)
	bg:SetShown(ns.testMode)
	if on then
		anchor:RegisterForDrag("LeftButton")
		anchor:SetScript("OnDragStart", anchor.StartMoving)
		anchor:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local x, y = self:GetCenter()
			local ux, uy = UIParent:GetCenter()
			local s = self:GetScale()
			db.pos = { "CENTER", x * s - ux, y * s - uy }
			ApplyPosition()
		end)
	else
		anchor:SetScript("OnDragStart", nil)
		anchor:SetScript("OnDragStop", nil)
	end
	Refresh()
	if ns.RefreshPanel then ns.RefreshPanel() end
end

function ns.SetScale(v)
	db.scale = math.min(2, math.max(0.5, math.floor(v * 10 + 0.5) / 10))
	ApplyPosition()
end

function ns.SetWindow(v)
	db.window = math.min(30, math.max(1, math.floor(v + 0.5)))
	Refresh()
end

function ns.ResetPosition()
	db.pos = { "CENTER", 0, -150 }
	db.scale = 1
	ApplyPosition()
end

function ns.SetTracked(key, on)
	cdb.track[key] = on and true or false
	for _, t in ipairs(ns.trackers) do
		if t.key == key and not on then t.status = "none"; t.expires = nil end
	end
	Refresh()
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffToDoAuras:|r " .. msg)
end
ns.Print = Print

SLASH_TODOAURAS1 = "/tda"
SLASH_TODOAURAS2 = "/todoauras"
SlashCmdList.TODOAURAS = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "" or cmd == "config" or cmd == "settings" or cmd == "options" then
		if ns.OpenSettings then ns.OpenSettings() end
	elseif cmd == "unlock" or cmd == "move" then
		ns.SetUnlocked(true)
		Print("drag the blue bar to move the list. /tda lock when done.")
	elseif cmd == "lock" then
		ns.SetUnlocked(false)
		Print("locked.")
	elseif cmd == "scale" and tonumber(arg) then
		ns.SetScale(tonumber(arg))
		Print("scale " .. db.scale)
	elseif cmd == "warn" and tonumber(arg) then
		ns.SetWindow(tonumber(arg))
		Print("warning " .. db.window .. " seconds before something expires.")
	elseif cmd == "reset" then
		ns.ResetPosition()
		Print("position and scale reset.")
	elseif cmd == "off" or cmd == "on" then
		local found
		for _, t in ipairs(ns.trackers) do
			if t.key == arg then found = t end
		end
		if not found then
			Print("unknown item '" .. arg .. "'. See /tda list.")
		else
			ns.SetTracked(arg, cmd == "on")
			Print(found.title .. (cmd == "on" and " tracked." or " not tracked."))
		end
	elseif cmd == "debug" then
		if ns.DebugAuras then ns.DebugAuras() end
	elseif cmd == "list" then
		if #ns.trackers == 0 then Print("nothing to track for this class.") end
		for _, t in ipairs(ns.trackers) do
			Print(format("%s (%s) — %s", t.title, t.key, Enabled(t) and "|cff55ff55on|r" or "|cffff5555off|r"))
		end
	else
		Print("/tda (settings) | unlock | lock | scale <0.5-2> | warn <seconds> | reset | list | on|off <item>")
	end
end

---------------------------------------------------------------------------
-- Startup and events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
	local arg1 = ...
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		self:UnregisterEvent("ADDON_LOADED")
		ToDoAurasDB = ToDoAurasDB or {}
		db = ToDoAurasDB
		db.pos = db.pos or { "CENTER", 0, -150 }
		db.window = db.window or 5
		ToDoAurasCharDB = ToDoAurasCharDB or {}
		cdb = ToDoAurasCharDB
		cdb.track = cdb.track or {}
		if cdb.off then -- 1.0 stored hidden items in "off"
			for k in pairs(cdb.off) do cdb.track[k] = false end
			cdb.off = nil
		end
		if type(cdb.imbue) == "string" then cdb.imbue = { imbue = cdb.imbue } end -- 1.0 format
		if cdb.used and cdb.used.offhand then cdb.used.imbueoff, cdb.used.offhand = true, nil end
		ns.db, ns.cdb = db, cdb
		ApplyPosition()

		local _, classFile = UnitClass("player")
		local setup = classModules[classFile]
		if setup then setup(ns) end
		if ns.CreatePanel then ns.CreatePanel() end
		if not setup then return end -- no module for this class: stay idle

		for e in pairs(events) do
			if e == "UNIT_AURA" or e == "UNIT_INVENTORY_CHANGED" or e == "UNIT_SPELLCAST_SUCCEEDED" then
				self:RegisterUnitEvent(e, "player")
			else
				self:RegisterEvent(e)
			end
		end
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
			"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST" }) do
			self:RegisterEvent(e)
		end
		return
	end
	for _, t in ipairs(ns.trackers) do
		if t.OnEvent then t:OnEvent(event, ...) end
	end
	Refresh()
end)
