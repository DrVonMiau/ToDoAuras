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
local function ValidIcon(v)
	return (type(v) == "number" and v > 0) or (type(v) == "string" and v ~= "")
end

-- Remember the icon a buff really shows (procs like Maelstrom Weapon aren't in
-- the spellbook, so looking the icon up by name fails for them).
function ns.RememberIcon(name, icon)
	if not ValidIcon(icon) or ns.Secret(icon) or not ns.cdb then return end
	ns.cdb.icons = ns.cdb.icons or {}
	ns.cdb.icons[name] = icon
end

function ns.SpellIcon(name)
	local saved = ns.cdb and ns.cdb.icons and ns.cdb.icons[name]
	if ValidIcon(saved) then return saved end
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, tex = ns.Safe(C_Spell.GetSpellTexture, name)
		if ok and ValidIcon(tex) then return tex end
	end
	if GetSpellTexture then
		local ok, tex = ns.Safe(GetSpellTexture, name)
		if ok and ValidIcon(tex) then return tex end
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
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(ICON, ICON)
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.text:SetShadowOffset(1, -1)
	r.index = i
	rows[i] = r
	return r
end

-- Alignment: LEFT = [icon] text from the left edge, RIGHT = text [icon] against
-- the right edge, CENTER = [icon] text centred on the list.
local function Layout(r)
	local align = db.align or "LEFT"
	local y = (r.index - 1) * (ROW_H + 2)
	r:ClearAllPoints(); r.icon:ClearAllPoints(); r.text:ClearAllPoints()
	if align == "RIGHT" then
		r:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, y)
		r.icon:SetPoint("RIGHT")
		r.text:SetPoint("RIGHT", r.icon, "LEFT", -6, 0)
		r.text:SetJustifyH("RIGHT")
	elseif align == "CENTER" then
		r:SetPoint("BOTTOM", anchor, "BOTTOM", 0, y)
		local w = ICON + 6 + (r.text:GetStringWidth() or 0)
		r.icon:SetPoint("LEFT", r, "CENTER", -w / 2, 0)
		r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
		r.text:SetJustifyH("LEFT")
	else
		r:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, y)
		r.icon:SetPoint("LEFT")
		r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
		r.text:SetJustifyH("LEFT")
	end
end

-- kind: true = expired (red), "ready" = proc ready (green), nil = expiring (yellow)
local function Show(i, icon, text, kind, alpha)
	local r = Row(i)
	r.icon:SetTexture(icon or QUESTION)
	r.icon:SetDesaturated(kind == true)
	r.text:SetText(text)
	if kind == true then r.text:SetTextColor(1, 0.3, 0.25)
	elseif kind == "ready" then r.text:SetTextColor(0.35, 1, 0.4)
	else r.text:SetTextColor(1, 0.82, 0.2) end
	Layout(r)
	r:SetAlpha(alpha or 1)
	r:Show()
end

-- Fading: an "expired" or "ready" row fades out over one second once it has
-- been on screen for db.fade seconds (0 = never). It comes back when the same
-- item expires or gets ready again.
-- returns alpha (nil = hidden), fading (needs the ticker), wakeAt (when to look again)
local function FadeState(t, kind, now)
	if t.rowKind ~= kind then t.rowKind, t.rowSince = kind, now end
	local fade = db.fade or 0
	if fade <= 0 then return 1 end
	local age = now - t.rowSince
	if age >= fade + 1 then return nil end
	if age > fade then return 1 - (age - fade), true end
	return 1, false, t.rowSince + fade
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

local function Schedule(now, counting, wakeAt)
	if counting and not ticker then
		ticker = C_Timer.NewTicker(0.2, function() Refresh() end)
	elseif not counting and ticker then
		ticker:Cancel(); ticker = nil
	end
	if wake then wake:Cancel(); wake = nil end
	local soonest
	for _, t in ipairs(ns.trackers) do
		if Enabled(t) and (t.status == "active" or t.status == "ready") and t.expires then
			local d = t.expires - db.window - now
			if d > 0 and (not soonest or d < soonest) then soonest = d end
		end
	end
	if wakeAt and wakeAt > now and (not soonest or wakeAt - now < soonest) then soonest = wakeAt - now end
	if soonest then wake = C_Timer.NewTimer(soonest + 0.05, function() wake = nil; Refresh() end) end
end

function Refresh()
	if not cdb then return end
	local now = GetTime()
	for _, t in ipairs(ns.trackers) do
		if Enabled(t) then
			t:Update(now)
			if cdb.logging and (t._st ~= t.status or t._ex ~= t.expires) then
				ns.Log(format("%s: %s -> %s%s", t.key, tostring(t._st), tostring(t.status),
					t.expires and format(" (%ds left)", t.expires - now) or ""))
				t._st, t._ex = t.status, t.expires
			end
		end
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
					if t.threshold then
						Show(n, t.icon or ns.SpellIcon(name), format("%s x%d", name, t.maxStacks or 5), "ready")
					else
						Show(n, t.icon or ns.SpellIcon(name), n == 2 and (name .. " expired")
							or format("%s expires in %ds", name, 5 - n), n == 2)
					end
				end
			end
		end
		if n == 0 then Show(1, QUESTION, "ToDoAuras (nothing ticked)"); n = 1 end
		for i = n + 1, #rows do rows[i]:Hide() end
		anchor:Show()
		return
	end

	local n, counting, wakeAt = 0, false, nil
	local function Wake(at)
		if at and (not wakeAt or at < wakeAt) then wakeAt = at end
	end
	if not Hidden() then
		for _, t in ipairs(ns.trackers) do
			local shown = false
			if Enabled(t) then
				if t.status == "missing" then
					local alpha, fading, at = FadeState(t, "missing", now)
					shown = true
					if alpha then
						n = n + 1
						Show(n, t.icon, t.label .. " expired", true, alpha)
						counting = counting or fading; Wake(at)
					end
				elseif t.status == "ready" then
					local text = format("%s x%d", t.label, t.count or 0)
					local soon = false
					if t.expires then
						local left = t.expires - now
						if left <= db.window then
							soon = true
							text = text .. format(" - fades in %ds", math.max(0, ceil(left)))
						end
					end
					local alpha, fading, at = FadeState(t, "ready", now)
					shown = true
					if soon then alpha = 1 end -- about to drop: always show the countdown
					if alpha then
						n = n + 1
						Show(n, t.icon, text, "ready", alpha)
						counting = counting or soon or fading; Wake(at)
					end
				elseif t.status == "active" and t.expires then
					local left = t.expires - now
					if left <= db.window then
						n = n + 1
						counting = true
						Show(n, t.icon, format("%s expires in %ds", t.label, math.max(0, ceil(left))))
					end
				end
			end
			if not shown then t.rowKind = nil end
		end
	end
	for i = n + 1, #rows do rows[i]:Hide() end
	anchor:SetShown(n > 0)
	Schedule(now, counting, wakeAt)
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

function ns.SetAlign(a)
	a = (a or ""):upper()
	if a ~= "LEFT" and a ~= "CENTER" and a ~= "RIGHT" then return false end
	db.align = a
	Refresh()
	return true
end

function ns.SetFade(sec)
	db.fade = math.min(120, math.max(0, math.floor(sec + 0.5)))
	Refresh()
end

function ns.ResetPosition()
	db.pos = { "CENTER", 0, -150 }
	db.scale = 1
	ApplyPosition()
end

function ns.SetThreshold(key, n)
	cdb.threshold = cdb.threshold or {}
	cdb.threshold[key] = math.min(20, math.max(1, math.floor(n + 0.5)))
	Refresh()
	return cdb.threshold[key]
end

function ns.Threshold(t)
	return (cdb.threshold and cdb.threshold[t.key]) or t.threshold
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

-- /tda log: records events and row changes into the saved file, for bug hunting.
local function Str(v)
	if Secret(v) then return "<secret>" end
	return tostring(v)
end
ns.Str = Str

function ns.Log(msg)
	if not (cdb and cdb.logging) then return end
	cdb.log = cdb.log or {}
	local l = cdb.log
	l[#l + 1] = format("%.1f %s %s", GetTime(), InCombatLockdown() and "C" or "-", msg)
	while #l > 500 do table.remove(l, 1) end
end

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
	elseif cmd == "align" then
		if ns.SetAlign(arg) then Print("rows aligned " .. arg .. ".")
		else Print("/tda align left | center | right") end
	elseif cmd == "fade" and tonumber(arg) then
		ns.SetFade(tonumber(arg))
		Print(db.fade > 0 and ("expired and ready rows fade after " .. db.fade .. " s.") or "rows never fade.")
	elseif cmd == "stacks" and tonumber(arg) then
		local done
		for _, t in ipairs(ns.trackers) do
			if t.threshold then
				ns.SetThreshold(t.key, tonumber(arg)); done = true
				Print(t.label .. " shows at " .. ns.Threshold(t) .. " stacks.")
			end
		end
		if not done then Print("nothing with stacks to track for this class.") end
	elseif cmd == "log" then
		cdb.logging = not cdb.logging
		if cdb.logging then
			cdb.log = {}
			Print("recording. Play as usual (re-apply buffs in combat), then type /tda log again and /reload.")
		else
			Print("recording stopped (" .. #(cdb.log or {}) .. " lines). /reload to save it to disk.")
		end
	elseif cmd == "debug" then
		if ns.DebugAuras then ns.DebugAuras() end
	elseif cmd == "list" then
		if #ns.trackers == 0 then Print("nothing to track for this class.") end
		for _, t in ipairs(ns.trackers) do
			Print(format("%s (%s) — %s", t.title, t.key, Enabled(t) and "|cff55ff55on|r" or "|cffff5555off|r"))
		end
	else
		Print("/tda (settings) | unlock | lock | scale <0.5-2> | warn <seconds> | stacks <n> | align left|center|right | fade <seconds> | reset | list | on|off <item> | debug | log")
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
		db.align = db.align or "LEFT"
		db.fade = db.fade or 0
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
			if e == "UNIT_AURA" or e == "UNIT_INVENTORY_CHANGED" or e == "UNIT_SPELLCAST_SUCCEEDED"
				or e == "UNIT_SPELLCAST_SENT" then
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
	if cdb.logging then
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local _, _, spellID = ...
			local n = "?"
			if not Secret(spellID) and C_Spell and C_Spell.GetSpellName then
				local ok, name = ns.Safe(C_Spell.GetSpellName, spellID)
				if ok then n = tostring(name) end
			end
			ns.Log("event cast id=" .. Str(spellID) .. " " .. n)
		elseif event == "COMBAT_TEXT_UPDATE" then
			local fn = (C_CombatText and C_CombatText.GetCurrentEventInfo) or GetCurrentCombatTextEventInfo
			local info = "?"
			if fn then
				local r = { pcall(fn) }
				if r[1] then
					local parts = {}
					for i = 2, math.max(2, #r) do parts[#parts + 1] = Str(r[i]) end
					info = table.concat(parts, " / ")
				else
					info = "error"
				end
			end
			ns.Log("event COMBAT_TEXT_UPDATE " .. Str(arg1) .. " " .. info)
		elseif event == "UNIT_SPELLCAST_SENT" then
			local _, target, _, spellID = ...
			ns.Log("event sent id=" .. Str(spellID) .. " target=" .. Str(target))
		elseif event == "UNIT_AURA" then
			-- only changes that add or remove buffs, with their instance IDs
			local u = select(2, ...)
			if arg1 == "player" and type(u) == "table" and not Secret(u) then
				local function ids(list, field)
					if list == nil then return nil end
					if Secret(list) then return "<secret>" end
					local out = {}
					for _, v in ipairs(list) do
						local id, n = v, nil
						if field then
							if Secret(v) or type(v) ~= "table" then id = v
							else id, n = v[field], v.name end
						end
						out[#out + 1] = Str(id) .. ((type(n) ~= "nil") and ("=" .. Str(n)) or "")
					end
					return #out > 0 and table.concat(out, ",") or nil
				end
				local add, rem = ids(u.addedAuras, "auraInstanceID"), ids(u.removedAuraInstanceIDs)
				if add or rem or (not Secret(u.isFullUpdate) and u.isFullUpdate) then
					ns.Log("event UNIT_AURA full=" .. Str(u.isFullUpdate) .. " +" .. tostring(add or "")
						.. " -" .. tostring(rem or ""))
				end
			end
		else
			ns.Log("event " .. event .. " " .. Str(arg1))
		end
	end
	for _, t in ipairs(ns.trackers) do
		if t.OnEvent then t:OnEvent(event, ...) end
	end
	Refresh()
end)
