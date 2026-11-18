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

-- found (true/false), expirationTime; found is nil when the game won't tell.
local function FindAura(name)
	local U = C_UnitAuras
	if U and U.GetAuraDataBySpellName then
		local ok, aura = Safe(U.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if not ok then return nil end
		if not aura then return false end
		local exp = aura.expirationTime
		if ns.Secret(exp) then return true, nil end
		return true, exp
	end
	for i = 1, 40 do
		local an, exp
		if U and U.GetAuraDataByIndex then
			local ok, aura = Safe(U.GetAuraDataByIndex, "player", i, "HELPFUL")
			if not ok then return nil end
			if not aura then return false end
			an, exp = aura.name, aura.expirationTime
		elseif UnitAura then
			local ok, n, _, _, _, _, e = Safe(UnitAura, "player", i, "HELPFUL")
			if not ok then return nil end
			if not n then return false end
			an, exp = n, e
		else
			return nil
		end
		if ns.Secret(an) then return nil end
		if an == name then
			if ns.Secret(exp) then return true, nil end
			return true, exp
		end
	end
	return false
end

function ns.AuraAny(title, names, opts)
	opts = opts or {}
	return ns.Add({
		key = opts.key or Key(title),
		title = title,
		label = title,
		default = opts.default,
		Events = { "UNIT_AURA", "SPELLS_CHANGED" },
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
					t.label, t.icon = n, ns.SpellIcon(n)
					t.status = "active"
					if exp and exp > 0 then t.expires = exp
					elseif exp == 0 then t.expires = nil end
					-- exp nil (secret): keep the last known expiry
					return
				elseif found == nil then
					unknown = true
				end
			end
			if unknown then return end -- the game won't say: keep the last state
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

	local function Make(slotKey, invSlot, suffix, slotTitle)
		return ns.Add({
			key = slotKey,
			title = slotTitle,
			default = opts.default,
			Events = { "UNIT_INVENTORY_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" },
			OnEvent = function(t, event, unit, _, spellID)
				if event ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" then return end
				if ns.Secret(spellID) then return end
				local ok, n = Safe(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spellID)
				if ok and type(n) == "string" and Matches(n) then
					ns.cdb.imbue = ns.cdb.imbue or {}
					ns.cdb.imbue[slotKey] = n
					t.castIcon = select(2, Safe(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture, spellID))
				end
			end,
			Update = function(t, now)
				local ok, hasMain, mainMs, _, _, hasOff, offMs = Safe(GetWeaponEnchantInfo)
				if not ok then return end
				local has, ms
				if invSlot == 16 then has, ms = hasMain, mainMs else has, ms = hasOff, offMs end
				local name = type(ns.cdb.imbue) == "table" and ns.cdb.imbue[slotKey] or nil
				t.label = (name or title) .. suffix
				t.icon = t.castIcon or (name and ns.SpellIcon(name))
					or (GetInventoryItemTexture and GetInventoryItemTexture("player", invSlot))
				if has then
					ns.cdb.used = ns.cdb.used or {}
					ns.cdb.used[slotKey] = true
					t.status = "active"
					t.expires = (ms and ms > 0) and (now + ms / 1000) or nil
				elseif ns.cdb.used and ns.cdb.used[slotKey] then
					t.status = "missing"
					t.expires = nil
				else
					t.status = "none"
				end
			end,
		})
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
