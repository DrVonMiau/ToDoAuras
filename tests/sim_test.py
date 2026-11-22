"""Simulated-WoW tests for ToDoAuras (not shipped in the addon zip).

Run:  python -m venv .venv && .venv/bin/pip install lupa && .venv/bin/python tests/sim_test.py
"""
import os
import sys

import lupa

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = [l.strip().replace("\\", "/") for l in open(os.path.join(BASE, "ToDoAuras.toc"))
         if l.strip().endswith(".lua")]

STUB = r'''
now = 1000
secret = {}
issecretvalue = function(v) return secret[v] == true end
SECRET = setmetatable({}, {}); secret[SECRET] = true
local Obj = {}
local function new() return setmetatable({_shown=true}, Obj) end
Obj.__index = function(t, k)
  if k=="SetText" then return function(self,s) rawset(self,"_text",s) end end
  if k=="Show" then return function(self) rawset(self,"_shown",true) end end
  if k=="Hide" then return function(self) rawset(self,"_shown",false) end end
  if k=="SetShown" then return function(self,v) rawset(self,"_shown",v and true or false) end end
  if k=="CreateTexture" or k=="CreateFontString" then return function() return new() end end
  if k=="SetScript" then return function(self,n,fn) rawset(self,"s_"..n,fn) end end
  if k=="GetScale" then return function() return 1 end end
  if k=="GetCenter" then return function() return 0,0 end end
  if k=="RegisterEvent" or k=="RegisterUnitEvent" then
    return function(self,e) local r=rawget(self,"_ev") or {}; r[e]=true; rawset(self,"_ev",r) end end
  return function() end
end
frames = {}
CreateFrame = function() local f = new(); frames[#frames+1] = f; return f end
UIParent = new()
GetTime = function() return now end
timers = {}
local function mk(d, fn, rep) local t={at=now+d, fn=fn, rep=rep, d=d}; t.Cancel=function() t.dead=true end; timers[#timers+1]=t; return t end
C_Timer = { NewTicker=function(d,f) return mk(d,f,true) end, NewTimer=function(d,f) return mk(d,f,false) end, After=function(d,f) mk(d,f,false) end }
function advance(sec)
  local target = now + sec
  while true do
    local nxt
    for _,t in ipairs(timers) do if not t.dead and t.at <= target and (not nxt or t.at < nxt.at) then nxt = t end end
    if not nxt then break end
    now = nxt.at
    if nxt.rep then nxt.at = now + nxt.d else nxt.dead = true end
    nxt.fn()
  end
  now = target
end
class = "SHAMAN"
UnitClass = function() return "Shaman", class end
UnitIsDeadOrGhost = function() return false end
UnitOnTaxi = function() return false end
combat = false
InCombatLockdown = function() return combat end
spellIDs = { ["Lightning Shield"]=10432, ["Rockbiter Weapon"]=10399, ["Maelstrom Weapon"]=53817, ["Lightning Bolt"]=403 }
known = { ["Lightning Shield"]=true, ["Rockbiter Weapon"]=true }
C_Spell = {
  GetSpellInfo=function(n) if known[n] then return {name=n, spellID=spellIDs[n]} end end,
  GetSpellTexture=function(n) return "icon:"..tostring(n) end,
  GetSpellName=function(id) for n,i in pairs(spellIDs) do if i==id then return n end end end,
}
auras = {}    -- name -> {exp=, count=}
hideInCombat = false
local function hidden() return hideInCombat and combat end
local function data(n) local a=auras[n]; if a then return {name=n, expirationTime=a.exp, applications=a.count or 0} end end
C_UnitAuras = {
  GetAuraDataBySpellName=function(u,n) if hidden() then return nil end return data(n) end,
  GetPlayerAuraBySpellID=function(id) if hidden() then return nil end
    for n,i in pairs(spellIDs) do if i==id then return data(n) end end end,
}
weaponExp = nil
GetWeaponEnchantInfo = function() if weaponExp and weaponExp > now then return true, (weaponExp-now)*1000, 0, 0, false, 0, 0, 0 end return false, 0, 0, 0, false, 0, 0, 0 end
GetInventoryItemTexture = function() return "weaponicon" end
totems = {}
GetTotemInfo = function(s) local t=totems[s]; if t then return true, t.name, t.start, t.dur, "icon:"..t.name end return false, "", 0, 0, "" end
DEFAULT_CHAT_FRAME = {AddMessage=function(_,m) chatlog = (chatlog or "") .. m .. "\n" end}
SlashCmdList = {}
function fire(ev, ...) for _,f in ipairs(frames) do local h=rawget(f,"s_OnEvent"); if h then h(f, ev, ...) end end end
function rows()
  local out = {}
  for _,f in ipairs(frames) do local t = rawget(f,"text"); if type(t)=="table" and rawget(f,"_shown") then out[#out+1] = rawget(t,"_text") end end
  return out
end
'''


def load(setup=""):
    L = lupa.LuaRuntime()
    L.execute(STUB)
    if setup:
        L.execute(setup)
    ns = L.table()
    loader = L.eval("function(src, name) local f, e = load(src, name); if not f then error(e) end return f end")
    for fn in FILES:
        loader(open(os.path.join(BASE, fn)).read(), fn)("ToDoAuras", ns)
    G = L.globals()
    G.fire("ADDON_LOADED", "ToDoAuras")
    G.fire("PLAYER_ENTERING_WORLD")
    return L, G, ns


def rows(G):
    r = G.rows()
    return [r[i] for i in range(1, len(r) + 1)]


passed = 0


def check(name, got, want):
    global passed
    if got != want:
        print(f"FAIL {name}: got {got!r}, want {want!r}")
        sys.exit(1)
    passed += 1
    print(f"ok   {name}: {got}")


# --- core behaviour -------------------------------------------------------
L, G, ns = load()
L.execute('auras["Lightning Shield"] = {exp = 1100}; weaponExp = 1600')
G.fire("UNIT_AURA", "player"); G.fire("UNIT_INVENTORY_CHANGED", "player")
check("nothing due", rows(G), [])
G.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 10399)
G.advance(96.1)
check("shield expiring", rows(G), ["Lightning Shield expires in 4s"])
G.advance(4.1); L.execute('auras["Lightning Shield"] = nil'); G.fire("UNIT_AURA", "player")
check("shield expired", rows(G), ["Lightning Shield expired"])
G.advance(500); G.fire("UNIT_INVENTORY_CHANGED", "player")
check("imbue + shield expired (bottom-up)", rows(G), ["Rockbiter Weapon expired", "Lightning Shield expired"])
L.execute('weaponExp = now + 1800; auras["Lightning Shield"] = {exp = now + 600}')
G.fire("UNIT_AURA", "player"); G.fire("UNIT_INVENTORY_CHANGED", "player")
check("all reapplied", rows(G), [])
G.combat = True; G.fire("PLAYER_REGEN_DISABLED")
L.execute("totems[1] = {name='Searing Totem', start=now, dur=8}"); G.fire("PLAYER_TOTEM_UPDATE", 1)
G.advance(4.1)
check("totem expiring", rows(G), ["Searing Totem expires in 4s"])
G.advance(3.95); L.execute("totems[1] = nil"); G.fire("PLAYER_TOTEM_UPDATE", 1)
check("totem gone in combat", rows(G), ["Searing Totem expired"])
G.combat = False; G.fire("PLAYER_REGEN_ENABLED")
check("combat over clears totem", rows(G), [])

# --- 1.1.1: recast during combat while the game hides buffs ------------------
L, G, ns = load("hideInCombat = true")
check("no shield", rows(G), ["Lightning Shield expired"])
G.combat = True; G.fire("PLAYER_REGEN_DISABLED")
L.execute('auras["Lightning Shield"] = {exp = now + 600}')
G.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 10432); G.fire("UNIT_AURA", "player")
check("recast in combat, hidden", rows(G), [])
G.advance(10); G.fire("UNIT_AURA", "player")
check("still hidden 10s later", rows(G), [])

# --- 1.2.0: Maelstrom Weapon --------------------------------------------------
L, G, ns = load('auras["Lightning Shield"] = {exp = 5000}')
L.execute('auras["Maelstrom Weapon"] = {exp = now + 30, count = 3}'); G.fire("UNIT_AURA", "player")
check("3 stacks: nothing", rows(G), [])
L.execute('auras["Maelstrom Weapon"] = {exp = now + 30, count = 5}'); G.fire("UNIT_AURA", "player")
check("5 stacks: ready", rows(G), ["Maelstrom Weapon x5"])
G.advance(26.1)
check("ready, about to fade", rows(G), ["Maelstrom Weapon x5 - fades in 4s"])
G.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 403)   # Lightning Bolt spends it
check("spent on Lightning Bolt", rows(G), [])
L.execute('auras["Maelstrom Weapon"] = nil'); G.fire("UNIT_AURA", "player")
check("aura gone", rows(G), [])
G.SlashCmdList.TODOAURAS("stacks 3")
G.advance(1)
L.execute('auras["Maelstrom Weapon"] = {exp = now + 30, count = 3}'); G.fire("UNIT_AURA", "player")
check("threshold 3", rows(G), ["Maelstrom Weapon x3"])
G.combat = True
L.execute('C_UnitAuras.GetAuraDataBySpellName = function(u,n) return {name=n, expirationTime=SECRET, applications=SECRET} end')
L.execute('C_UnitAuras.GetPlayerAuraBySpellID = function(id) return {expirationTime=SECRET, applications=SECRET} end')
G.fire("UNIT_AURA", "player")
check("stacks hidden in combat: keep last", rows(G), ["Maelstrom Weapon x3"])
G.SlashCmdList.TODOAURAS("debug")

# --- every class loads --------------------------------------------------------
for cls in ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT"):
    L, G, ns = load(f'class = "{cls}"')
    n = len(ns["trackers"])
    check(f"{cls} loads", n >= 0, True)

print(f"\nALL {passed} CHECKS PASSED")
