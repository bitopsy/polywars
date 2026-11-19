-- Factory placement rule, shared by the synced gadget (enforcement) and the
-- LuaUI widget (preview). Uses only functions that exist in both environments.
local cfg   = VFS.Include("LuaRules/Headers/pw_config.lua")
local floor = math.floor
local M = {}

local defSets
function M.Sets()
	if not defSets then
		defSets = {}
		for _, key in ipairs({ "commanders", "pylons", "generators", "factories" }) do
			local set = {}
			for name in pairs(cfg[key]) do
				local ud = UnitDefNames[name]
				if ud then set[ud.id] = true end
			end
			defSets[key] = set
		end
	end
	return defSets
end

local function Finished(unitID)
	return not (Spring.GetUnitIsBeingBuilt(unitID))
end

function M.OnMetal(x, z)
	local sq = cfg.METAL_SQUARE
	return (Spring.GetMetalAmount(floor(x / sq), floor(z / sq)) or 0) > 0
end

-- returns ok(boolean), reason(string|nil)
function M.CanPlaceFactory(teamID, x, z)
	if not M.OnMetal(x, z) then
		return false, "Weapon factories can only be built on a metal spot."
	end
	local sets = M.Sets()
	local sawPylon = false
	for _, pid in ipairs(Spring.GetUnitsInCylinder(x, z, cfg.PYLON_RANGE, teamID)) do
		if sets.pylons[Spring.GetUnitDefID(pid)] and Finished(pid) then
			sawPylon = true
			local px, _, pz = Spring.GetUnitPosition(pid)
			for _, gid in ipairs(Spring.GetUnitsInCylinder(px, pz, cfg.POWER_LINK_RANGE, teamID)) do
				if sets.generators[Spring.GetUnitDefID(gid)] and Finished(gid) then
					return true
				end
			end
		end
	end
	if sawPylon then
		return false, "The pylon in range has no energy generator next to it."
	end
	return false, "Build a pylon and a generator next to this metal spot first."
end

return M
