#!/usr/bin/env python3
"""Offline sanity test for the Lua unit scripts + unit defs (needs `pip install lupa`).

Loads every unit's S3O to get its real piece list, mocks the Spring.UnitScript API, runs the unit's script and
exercises Create / StartMoving / StopMoving / Query* / Aim* (all six weapon slots) / Killed. Any call that
passes a nil or unknown piece, or any Lua error, fails the test. Also syntax-checks every Lua file in game/.
"""
import os
import sys
import glob

try:
    import lupa
except ImportError:
    sys.exit("pip install lupa")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GAME = os.path.join(ROOT, "game")
sys.path.insert(0, HERE)
import bricklib as bl  # noqa: E402

LUA_MOCK = r'''
local pieceMap, uname = ...
local log = {errors = {}, calls = {}}
local valid = {}
for n, i in pairs(pieceMap) do valid[i] = n end
local function chk(fn, p)
  if type(p) ~= "number" or not valid[p] then log.errors[#log.errors+1] = fn .. ": bad piece " .. tostring(p) end
end
local threads = {}
local US = {}
US.Turn = function(p, a, ang, sp) chk("Turn", p); assert(a>=1 and a<=3, "axis"); assert(type(ang)=="number"); log.calls.Turn=(log.calls.Turn or 0)+1 end
US.Spin = function(p, a, sp) chk("Spin", p); log.calls.Spin=(log.calls.Spin or 0)+1 end
US.StopSpin = function(p, a, d) chk("StopSpin", p) end
US.Move = function(p, a, d, sp) chk("Move", p) end
US.WaitForTurn = function(p, a) chk("WaitForTurn", p) end
US.Sleep = function(ms) coroutine.yield() end
US.StartThread = function(f, ...) local co = coroutine.create(f); threads[#threads+1] = {co=co, args={...}}; end
US.SetSignalMask = function(m) assert(type(m)=="number") end
US.Signal = function(m) assert(type(m)=="number") end
US.SetUnitValue = function(k, v) assert(k ~= nil, "COB constant missing") end
US.Explode = function(p, f) chk("Explode", p); log.calls.Explode=(log.calls.Explode or 0)+1 end
Spring = { UnitScript = US, GetUnitPieceMap = function() return pieceMap end, GetUnitDefID = function() return 1 end }
UnitDefs = { [1] = { name = uname } }
COB = { INBUILDSTANCE = 1, ACTIVATION = 2, YARD_OPEN = 3, BUGGER_OFF = 4 }
SFX = { FALL = 1, SHATTER = 2, NO_HEATCLOUD = 4 }
unitID = 1
script = {}
function include(f) dofile(SCRIPTDIR .. "/" .. f) end
function log.pump(n)
  for round = 1, n or 6 do
    local alive = {}
    for _, t in ipairs(threads) do
      if coroutine.status(t.co) ~= "dead" then
        local ok, err = coroutine.resume(t.co, table.unpack(t.args))
        t.args = {}
        if not ok then log.errors[#log.errors+1] = "thread: " .. tostring(err) end
        if coroutine.status(t.co) ~= "dead" then alive[#alive+1] = t end
      end
    end
    threads = alive
  end
end
return log
'''


def check_script(lua, name, pieces):
    pm = lua.table_from({p: i + 1 for i, p in enumerate(pieces)})
    chunk = lua.eval("function(src, pm, name, dir) SCRIPTDIR = dir; local f = assert(loadstring or load)(src); return f(pm, name) end")
    log = chunk(LUA_MOCK, pm, name, os.path.join(GAME, "scripts"))
    lua.execute("function run_unit(f) local ok, err = pcall(dofile, f); return ok, err end")
    ok, err = lua.globals().run_unit(os.path.join(GAME, "scripts", name + ".lua"))
    errs = []
    if not ok:
        return ["script load: %s" % err]
    s = lua.globals().script
    def call(fn, *a):
        f = s[fn]
        if f is None:
            return None
        try:
            return f(*a)
        except Exception as e:  # noqa
            errs.append("%s: %s" % (fn, e))
    call("Create"); call("StartBuilding"); call("StopBuilding"); call("Activate"); call("Deactivate")
    call("StartMoving"); log.pump(8); call("StopMoving")
    call("QueryNanoPiece"); call("QueryBuildInfo")
    for i in range(1, 7):
        for q in ("QueryWeapon", "AimFromWeapon"):
            r = call(q + str(i))
            if r is None or r not in range(1, len(pieces) + 1):
                errs.append("%s%d returned %r" % (q, i, r))
        call("AimWeapon%d" % i, 0.5, 0.2)
    log.pump(8)
    call("Killed", 100, 1000)
    for e in log.errors.values():
        errs.append(e)
    return errs


def main():
    bad = 0
    # 1. syntax check of every lua file
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    load = lua.eval("function(src, name) local f, err = (loadstring or load)(src, name); return f ~= nil, err end")
    n = 0
    for path in glob.glob(os.path.join(GAME, "**", "*.lua"), recursive=True):
        ok, err = load(open(path, encoding="utf8").read(), path)
        n += 1
        if not ok:
            print("SYNTAX", path, err)
            bad += 1
    print("syntax-checked %d lua files" % n)
    # 2. unit scripts against the real models
    for path in sorted(glob.glob(os.path.join(GAME, "objects3d", "*.s3o"))):
        name = os.path.basename(path)[:-4]
        model = bl.read_s3o(open(path, "rb").read())
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        errs = check_script(lua, name, list(model["pieces"].keys()))
        status = "ok" if not errs else "FAIL"
        if errs:
            bad += 1
            print(status, name, errs[:4])
    print("unit scripts checked; failures: %d" % bad)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
