-- Shared Lua Unit Script for every Pylon Wars unit (v0.7 brick models).
--
-- There are no COB scripts: the engine only lets a unit build or aim when its script says so
--   * builders must enter "build stance" (INBUILDSTANCE) and expose a nano piece
--   * factories must expose a build-info piece
--   * weapons need Query/Aim callins; without them nothing can fire
--
-- The brick models (tools/brickunits.py) use a piece-naming convention, so ONE script animates all of them:
--   base          root piece
--   turret        yaws toward the target                 gun   pitches (child of turret, or of base)
--   flare/flareN  muzzle (weapon N uses flareN if present, otherwise flare)
--   nano          build-arm tip (builders / factories)
--   legl legr     walk cycle        arml  swings opposite to legl
--   wheel*        spin while the unit moves (wheels, track bogies)
--   spiny*        endless spinners (pylon ring, radar dish, generator fan, drill, medic rotor...)
--   brk*          loose bricks: fly off when the unit dies
-- Any piece that is missing is simply skipped, so a model never has to provide all of them.

local pieces = Spring.GetUnitPieceMap(unitID) or {}
local Turn, Spin, StopSpin, Sleep = Spring.UnitScript.Turn, Spring.UnitScript.Spin, Spring.UnitScript.StopSpin, Spring.UnitScript.Sleep
local WaitForTurn, StartThread = Spring.UnitScript.WaitForTurn, Spring.UnitScript.StartThread
local SetSignalMask, Signal = Spring.UnitScript.SetSignalMask, Spring.UnitScript.Signal
local SetUnitValue, Explode = Spring.UnitScript.SetUnitValue, Spring.UnitScript.Explode
local X, Y, Z = 1, 2, 3

local function anyPiece()
	for _, idx in pairs(pieces) do return idx end
	return 0
end
local base   = pieces.base or anyPiece()
local turret = pieces.turret
local gun    = pieces.gun
local legl, legr, arml = pieces.legl, pieces.legr, pieces.arml
local nano   = pieces.nano

local wheels, spinners, loose = {}, {}, {}
for name, idx in pairs(pieces) do
	if name:sub(1, 5) == "wheel" then wheels[#wheels + 1] = idx
	elseif name:sub(1, 5) == "spiny" then spinners[#spinners + 1] = { idx = idx, name = name }
	elseif name:sub(1, 3) == "brk" then loose[#loose + 1] = idx end
end
table.sort(spinners, function(a, b) return a.name < b.name end)

local udef = UnitDefs[Spring.GetUnitDefID(unitID)]
local uname = udef and udef.name or ""
local isFactory = uname:find("factory", 1, true) ~= nil

-- radians per second of the endless spinners, by unit kind (default 2)
local SPIN_SPEED = { generator = 7, pylon = 1.6, siphon = 5, mast = 1.4, beacon = 4, mender = 16, obelisk = 2.2 }
local function spinSpeed()
	for kind, v in pairs(SPIN_SPEED) do
		if uname:find(kind, 1, true) then return v end
	end
	return 2
end

-- one signal bit per weapon slot, so six commander weapons never kill each other's aim threads
local SIG_WALK, SIG_RESTORE = 128, 256
local moving = false

------------------------------------------------------------------ lifecycle
local function startSpinners()
	local v = spinSpeed()
	for i, s in ipairs(spinners) do
		Spin(s.idx, Y, (i % 2 == 1) and v or -v)
	end
end
local function stopSpinners()
	for _, s in ipairs(spinners) do StopSpin(s.idx, Y, 1) end
end

function script.Create()
	if not isFactory then startSpinners() end   -- factory cranes only turn while building
end

------------------------------------------------------------------ building
function script.StartBuilding()
	SetUnitValue(COB.INBUILDSTANCE, 1)
	if isFactory then startSpinners() end
end
function script.StopBuilding()
	SetUnitValue(COB.INBUILDSTANCE, 0)
	if isFactory then stopSpinners() end
end
function script.QueryNanoPiece() return nano or base end
function script.QueryBuildInfo() return base end
-- Factories only start producing after Activate opens the yard and enters build stance,
-- exactly like the stock COB factory scripts do.
function script.Activate()
	SetUnitValue(COB.ACTIVATION, 1)
	SetUnitValue(COB.YARD_OPEN, 1)
	SetUnitValue(COB.BUGGER_OFF, 0)
	SetUnitValue(COB.INBUILDSTANCE, 1)
end
function script.Deactivate()
	SetUnitValue(COB.ACTIVATION, 0)
	SetUnitValue(COB.YARD_OPEN, 0)
	SetUnitValue(COB.INBUILDSTANCE, 0)
end

------------------------------------------------------------------ walking
local function walkThread()
	SetSignalMask(SIG_WALK)
	local swing, speed, step = 0.75, 6, 170
	while true do
		if legl then Turn(legl, X, swing, speed) end
		if legr then Turn(legr, X, -swing, speed) end
		if arml then Turn(arml, X, -swing * 0.8, speed) end
		Sleep(step)
		if legl then Turn(legl, X, -swing, speed) end
		if legr then Turn(legr, X, swing, speed) end
		if arml then Turn(arml, X, swing * 0.8, speed) end
		Sleep(step)
	end
end

function script.StartMoving()
	moving = true
	Signal(SIG_WALK)
	if legl or legr then StartThread(walkThread) end
	for _, w in ipairs(wheels) do Spin(w, X, 9) end
end
function script.StopMoving()
	moving = false
	Signal(SIG_WALK)
	if legl then Turn(legl, X, 0, 5) end
	if legr then Turn(legr, X, 0, 5) end
	if arml then Turn(arml, X, 0, 5) end
	for _, w in ipairs(wheels) do StopSpin(w, X, 3) end
end

------------------------------------------------------------------ weapons
local function restoreThread()
	SetSignalMask(SIG_RESTORE)
	Sleep(3500)
	if turret then Turn(turret, Y, 0, 2) end
	if gun then Turn(gun, X, 0, 2) end
end

for i = 1, 6 do
	script["QueryWeapon" .. i]   = function() return pieces["flare" .. i] or pieces.flare or gun or turret or base end
	script["AimFromWeapon" .. i] = function() return gun or turret or base end
	local sig = ({ 2, 4, 8, 16, 32, 64 })[i]
	script["AimWeapon" .. i]     = function(heading, pitch)
		Signal(sig)
		Signal(SIG_RESTORE)
		SetSignalMask(sig)
		if turret then Turn(turret, Y, heading, 9) end
		if gun then Turn(gun, X, -pitch, 7) end
		if turret then WaitForTurn(turret, Y) end
		if gun then WaitForTurn(gun, X) end
		StartThread(restoreThread)
		return true
	end
end

------------------------------------------------------------------ death: the bricks fly apart
function script.Killed(recentDamage, maxHealth)
	if SFX and SFX.FALL and Explode then
		local fall = SFX.FALL + (SFX.NO_HEATCLOUD or 0)
		for name, idx in pairs(pieces) do
			if idx ~= base then pcall(Explode, idx, fall) end
		end
	end
	return 1
end
