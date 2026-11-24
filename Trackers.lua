-- Reusable tracker types for class modules:
--   ns.Aura(name, opts)              one buff on yourself, by spell name
--   ns.AuraAny(title, names, opts)   any one of several buffs (blessings, armors...)
--   ns.WeaponImbue(names, opts)      temporary weapon enchants (imbues, poisons)
--   ns.Totem(slot, element)          one totem slot (1 fire, 2 earth, 3 water, 4 air)
-- opts: key = settings id, default = false to start unticked.

local ADDON, ns = ...
local Safe = ns.Safe

local function Key(s) return (s:lower():gsub("[^%a]", "")) end

---------------------------------------------------------------------------
-- Auras on the player
---------------------------------------------------------------------------

-- Forever may hide your own buffs from some lookups during combat, so a buff
-- is looked up three ways (by spell ID, by name, by scanning) and any "found"
-- wins. Each lookup answers true (found), false (not there) or nil (the game
-- won't say).

-- Spell IDs for a buff: the ones seen in your casts, plus your spellbook's rank.
local function SpellIDs(name)
	local ids, seen = {}, {}
	local learned = ns.cdb and ns.cdb.ids and ns.cdb.ids[name]
	if type(learned) == "table" then
		for id in pairs(learned) do
			if type(id) == "number" then ids[#ids + 1] = id; seen[id] = true end
		end
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = Safe(C_Spell.GetSpellInfo, name)
		local id = ok and type(info) == "table" and info.spellID
		if type(id) == "number" and not ns.Secret(id) and not seen[id] then ids[#ids + 1] = id end
	end
	return ids
end

-- true, expirationTime (nil if hidden), stack count (nil if hidden)
local function Result(aura)
	local exp, count = aura.expirationTime, aura.applications
	if ns.Secret(exp) then exp = nil end
	if ns.Secret(count) then count = nil end
	return true, exp, count
end

local methods = {}

methods.byID = function(name)
	local U = C_UnitAuras
	if not (U and U.GetPlayerAuraBySpellID) then return nil end
	local ids = SpellIDs(name)
	if #ids == 0 then return nil end
	local unknown
	for _, id in ipairs(ids) do
		local ok, aura = Safe(U.GetPlayerAuraBySpellID, id)
		if not ok then unknown = true
		elseif type(aura) == "table" then return Result(aura) end
	end
	if unknown then return nil end
	return false
end

methods.byName = function(name)
	local U = C_UnitAuras
	if not (U and U.GetAuraDataBySpellName) then return nil end
	local ok, aura = Safe(U.GetAuraDataBySpellName, "player", name, "HELPFUL")
	if not ok then return nil end
	if type(aura) == "table" then return Result(aura) end
	return false
end

methods.scan = function(name)
	local U = C_UnitAuras
	for i = 1, 40 do
		local an, exp, count
		if U and U.GetAuraDataByIndex then
			local ok, aura = Safe(U.GetAuraDataByIndex, "player", i, "HELPFUL")
			if not ok then return nil end
			if type(aura) ~= "table" then return false end
			an, exp, count = aura.name, aura.expirationTime, aura.applications
		elseif UnitAura then
			local ok, n, _, c, _, _, e = Safe(UnitAura, "player", i, "HELPFUL")
			if not ok then return nil end
			if not n then return false end
			an, exp, count = n, e, c
		else
			return nil
		end
		if ns.Secret(an) then return nil end
		if an == name then
			if ns.Secret(exp) then exp = nil end
			if ns.Secret(count) then count = nil end
			return true, exp, count
		end
	end
	return false
end

local ORDER = { "byID", "byName", "scan" }

local function FindAura(name)
	local saidNo
	for _, m in ipairs(ORDER) do
		local found, exp, count = methods[m](name)
		if found then return true, exp, count end
		if found == false then saidNo = true end
	end
	if saidNo then return false end
	return nil
end

-- /tda debug: what each lookup says about every tracked buff right now.
function ns.DebugAuras()
	ns.Print("combat: " .. tostring(InCombatLockdown() and true or false)
		.. ", lookups worked this fight: " .. tostring(ns.combatSeen and true or false))
	for _, t in ipairs(ns.trackers) do
		if t.names then
			for _, n in ipairs(t.names) do
				if ns.Knows(n) then
					local parts = {}
					for _, m in ipairs(ORDER) do
						local f, e, c = methods[m](n)
						parts[#parts + 1] = m .. "=" .. (f == nil and "?" or tostring(f))
							.. ((f and e and e > 0) and string.format("(%ds)", e - GetTime()) or "")
							.. ((f and c) and ("x" .. c) or "")
					end
					local ids = SpellIDs(n)
					ns.Print(string.format("%s [ids %s]: %s -> %s", n, table.concat(ids, ","),
						table.concat(parts, " "), t.status or "?"))
				end
			end
		end
	end
end

-- opts.targeted: the spell can be cast on others (Fortitude, Mark of the
-- Wild...), so your own cast doesn't prove you have the buff.
function ns.AuraAny(title, names, opts)
	opts = opts or {}
	local isName = {}
	for _, n in ipairs(names) do isName[n] = true end
	return ns.Add({
		key = opts.key or Key(title),
		title = title,
		label = title,
		names = names,
		default = opts.default,
		Events = { "UNIT_AURA", "SPELLS_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" },
		OnEvent = function(t, event, unit, _, spellID)
			if event == "PLAYER_REGEN_DISABLED" then ns.combatSeen = false; return end
			if event ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" or ns.Secret(spellID) then return end
			local ok, n = Safe(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spellID)
			if not ok or type(n) ~= "string" or not isName[n] then return end
			local cdb = ns.cdb
			cdb.ids = cdb.ids or {}
			cdb.ids[n] = cdb.ids[n] or {}
			cdb.ids[n][spellID] = true
			ns.Log("cast " .. n .. (opts.targeted and " (targeted, ignored)" or " -> active"))
			if opts.targeted then return end
			t.castAt = GetTime()
			t.status, t.label, t.icon = "active", n, ns.SpellIcon(n)
			t.expires = nil -- unknown until the game reports it
		end,
		Update = function(t, now)
			local known
			for _, n in ipairs(names) do
				if ns.Knows(n) then known = true; break end
			end
			if not known then t.status = "none"; return end
			local unknown
			for _, n in ipairs(names) do
				local found, exp = FindAura(n)
				if found then
					if InCombatLockdown() then ns.combatSeen = true end
					t.label, t.icon = n, ns.SpellIcon(n)
					t.status = "active"
					t.castAt = nil
					if exp and exp > 0 then t.expires = exp
					elseif exp == 0 then t.expires = nil end
					-- exp nil (secret): keep the last known expiry
					return
				elseif found == nil then
					unknown = true
				end
			end
			if unknown then
				ns.Log(title .. ": lookups won't say")
				return -- the game won't say: keep the last state
			end
			-- Every lookup says "not there".
			if t.status == "active" then
				-- Just cast: give the game a moment to list it.
				if t.castAt and now - t.castAt < 3 then return end
				-- In combat the game may hide buffs. Unless lookups have found
				-- something this fight, only trust a known expiry time.
				if InCombatLockdown() and not ns.combatSeen and not (t.expires and t.expires <= now) then
					return
				end
			end
			t.status = "missing"
			t.expires = nil
			if not t.icon then
				for _, n in ipairs(names) do
					if ns.Knows(n) then t.label, t.icon = n, ns.SpellIcon(n); break end
				end
			end
		end,
	})
end

function ns.Aura(name, opts)
	opts = opts or {}
	opts.key = opts.key or Key(name)
	return ns.AuraAny(name, { name }, opts)
end

---------------------------------------------------------------------------
-- Stacking procs (Maelstrom Weapon...)
---------------------------------------------------------------------------
-- A green "ready" row while the buff has at least `threshold` stacks
-- (changeable per character). Casting one of `consumers` spends the stacks,
-- which clears the row at once even if the game hides auras in combat.

function ns.Stacks(name, opts)
	opts = opts or {}
	local spends = {}
	for _, n in ipairs(opts.consumers or {}) do spends[n] = true end
	return ns.Add({
		key = opts.key or Key(name),
		title = opts.title or (name .. " (stacks)"),
		label = name,
		names = { name },
		threshold = opts.threshold or 5,
		maxStacks = opts.maxStacks or 5,
		default = opts.default,
		Events = { "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED" },
		OnEvent = function(t, event, unit, _, spellID)
			if event ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" or ns.Secret(spellID) then return end
			local ok, n = Safe(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spellID)
			if ok and type(n) == "string" and spends[n] then
				t.status, t.count, t.expires = "none", 0, nil
				t.spentAt = GetTime()
			end
		end,
		Update = function(t, now)
			t.icon = t.icon or ns.SpellIcon(name)
			local found, exp, count = FindAura(name)
			if found == nil then return end -- the game won't say: keep the last state
			if not found then
				-- Just spent, or simply no stacks: nothing to do either way.
				t.status, t.count, t.expires = "none", nil, nil
				return
			end
			if t.spentAt and now - t.spentAt < 0.5 then return end -- aura list not updated yet
			if count == nil then return end -- stacks hidden: keep the last state
			t.count = count
			t.expires = (exp and exp > 0) and exp or nil
			local need = (ns.cdb.threshold and ns.cdb.threshold[t.key]) or t.threshold
			t.status = (count >= need) and "ready" or "none"
		end,
	})
end

---------------------------------------------------------------------------
-- Weapon imbues and poisons
---------------------------------------------------------------------------
-- The game reports that a weapon is enchanted and for how long, but not which
-- enchant it is, so the name comes from your last matching cast (remembered
-- per character). An "expired" row only appears once this character has used
-- one, so characters that never imbue are left alone.

function ns.WeaponImbue(names, opts)
	opts = opts or {}
	local title = opts.title or "Weapon imbue"
	local function Matches(n)
		for _, prefix in ipairs(names) do
			if n:sub(1, #prefix) == prefix then return true end
		end
	end
	local slots = {}

	-- A matching cast goes to the main hand, or to the off-hand when only the
	-- off-hand is missing its imbue. The slot counts as imbued at once, even if
	-- the game hides weapon enchants during combat.
	local function OnCast(n, icon)
		local main, off = slots[1], slots[2]
		local target = main
		if off and off.status == "missing" and main.status ~= "missing" then target = off end
		ns.cdb.imbue = ns.cdb.imbue or {}
		ns.cdb.imbue[target.key] = n
		target.castIcon = icon
		target.castAt = GetTime()
		target.status, target.expires = "active", nil
		ns.Log("cast " .. n .. " -> " .. target.key)
	end

	local function Make(slotKey, invSlot, suffix, slotTitle)
		local tr = ns.Add({
			key = slotKey,
			title = slotTitle,
			default = opts.default,
			Events = { "UNIT_INVENTORY_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" },
			OnEvent = function(t, event, unit, _, spellID)
				if t ~= slots[1] then return end -- the main-hand tracker handles casts for both
				if event ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" then return end
				if ns.Secret(spellID) then return end
				local ok, n = Safe(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spellID)
				if ok and type(n) == "string" and Matches(n) then
					local _, icon = Safe(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, spellID)
					OnCast(n, icon)
				end
			end,
			Update = function(t, now)
				local name = type(ns.cdb.imbue) == "table" and ns.cdb.imbue[slotKey] or nil
				t.label = (name or title) .. suffix
				t.icon = t.castIcon or (name and ns.SpellIcon(name))
					or (GetInventoryItemTexture and GetInventoryItemTexture("player", invSlot))
				local ok, hasMain, mainMs, _, _, hasOff, offMs = Safe(GetWeaponEnchantInfo)
				if not ok then return end -- hidden: keep the last state
				local has, ms
				if invSlot == 16 then has, ms = hasMain, mainMs else has, ms = hasOff, offMs end
				if has then
					ns.cdb.used = ns.cdb.used or {}
					ns.cdb.used[slotKey] = true
					t.status = "active"
					t.castAt = nil
					t.expires = (ms and ms > 0) and (now + ms / 1000) or nil
				elseif ns.cdb.used and ns.cdb.used[slotKey] then
					if t.status == "active" then
						if t.castAt and now - t.castAt < 3 then return end
						-- In combat, only trust "no enchant" once a known expiry has passed,
						-- or for a cast we saw (the game may hide it until combat ends).
						if InCombatLockdown() and (t.castAt or not (t.expires and t.expires <= now + 1)) then return end
					end
					t.status = "missing"
					t.expires = nil
				else
					t.status = "none"
				end
			end,
		})
		slots[#slots + 1] = tr
		return tr
	end
	local base = opts.key or "imbue"
	Make(base, 16, "", title .. " (main hand)")
	Make(base .. "off", 17, " (off-hand)", title .. " (off-hand)")
end

---------------------------------------------------------------------------
-- Totems
---------------------------------------------------------------------------
-- "Expired" shows only in combat, after a totem of that element ran out or
-- was destroyed; it clears when combat ends or a new totem goes down.

function ns.Totem(slot, element)
	return ns.Add({
		key = element:lower() .. "totem",
		title = element .. " totem",
		label = element .. " totem",
		Events = { "PLAYER_TOTEM_UPDATE" },
		OnEvent = function(t, event)
			if event == "PLAYER_REGEN_ENABLED" then t.gone = nil end
		end,
		Update = function(t, now)
			if not GetTotemInfo then t.status = "none"; return end
			local ok, have, name, start, dur, icon = Safe(GetTotemInfo, slot)
			if not ok then return end
			if have and name and name ~= "" and dur and dur > 0 then
				t.label, t.icon = name, icon
				t.expires = start + dur
				t.status = "active"
				t.gone = nil
				t.wasUp = true
			else
				if t.wasUp and InCombatLockdown() then t.gone = true end
				t.wasUp = nil
				t.expires = nil
				t.status = t.gone and "missing" or "none"
			end
		end,
	})
end
