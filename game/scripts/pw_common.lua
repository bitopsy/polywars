-- Shared Lua Unit Script for every polywars unit (the models are single-piece placeholders and
-- there are no COB scripts). The engine only lets a unit build or aim when its script says so:
--   * builders must enter "build stance" (INBUILDSTANCE) and expose a nano piece
--   * factories must expose a build-info piece
--   * weapons need Query/Aim callins; without them nothing can fire
local pieces = Spring.GetUnitPieceMap(unitID) or {}
local root = 0
for _, idx in pairs(pieces) do root = idx break end

local SetUnitValue = Spring.UnitScript.SetUnitValue

function script.Create() end
function script.StartBuilding() SetUnitValue(COB.INBUILDSTANCE, 1) end
function script.StopBuilding()  SetUnitValue(COB.INBUILDSTANCE, 0) end
function script.QueryNanoPiece() return root end
function script.QueryBuildInfo() return root end
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

for i = 1, 6 do
	script["QueryWeapon" .. i]    = function() return root end
	script["AimFromWeapon" .. i]  = function() return root end
	script["AimWeapon" .. i]      = function() return true end
end
