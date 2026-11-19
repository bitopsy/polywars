-- Factory placement rule, shared by the synced gadget (enforcement) and the
-- LuaUI widget (preview). Uses only functions that exist in both environments.
local cfg   = VFS.Include("LuaRules/Headers/pw_config.lua")
local floor = math.floor
local M = {}

local defSets
function M.Sets()
	if not defSets then
		defSets = {}
		for _, key in ipairs({ "commanders", "pylons", "generators", "factories", "siphons", "turrets" }) do
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

-- ---------------------------------------------------------------- metal spots
local hasMetal
local function MapHasMetal()
	if hasMetal == nil then
		hasMetal = false
		local sq = cfg.METAL_SQUARE
		for cz = 0, floor(Game.mapSizeZ / sq) - 1 do
			for cx = 0, floor(Game.mapSizeX / sq) - 1 do
				if (Spring.GetMetalAmount(cx, cz) or 0) > 0 then hasMetal = true return true end
			end
		end
	end
	return hasMetal
end

local function IsPylonCity()
	return (Game.mapName or ""):lower():find("pylon city", 1, true) ~= nil
end

-- Spot centres from the configured list (Pylon City only); nil on other maps.
function M.FallbackSpots()
	if IsPylonCity() then return cfg.PYLON_CITY_SPOTS end
end

-- True when ANY part of the footprint (a square of half-size `half` elmos centred on x,z)
-- overlaps a metal spot: a metal-map cell, or (Pylon City) a configured spot square.
-- The cursor therefore never has to be on the spot centre. On a map with no metal layer at
-- all and no configured spots, the metal restriction is lifted instead of blocking every build.
M.FACTORY_HALF = 40   -- 4x4 footprint is 64 elmos; +8 slack
M.SIPHON_HALF  = 28   -- 3x3 footprint is 48 elmos; +4 slack
function M.OnMetal(x, z, half)
	half = half or M.FACTORY_HALF
	local sq = cfg.METAL_SQUARE
	for cz = floor((z - half) / sq), floor((z + half) / sq) do
		for cx = floor((x - half) / sq), floor((x + half) / sq) do
			if (Spring.GetMetalAmount(cx, cz) or 0) > 0 then return true end
		end
	end
	local fb = M.FallbackSpots()
	if fb then
		local r = half + cfg.SPOT_HALF
		for _, sp in ipairs(fb) do
			if math.abs(x - sp[1]) <= r and math.abs(z - sp[2]) <= r then return true end
		end
		return false
	end
	return not MapHasMetal()
end

-- All spot centres known to the game (configured list, else the metal map's clusters)
function M.SpotList()
	local fb = M.FallbackSpots()
	if fb then return fb end
	return nil
end

-- true when a factory or siphon already stands on this spot (finished or not)
function M.SpotTaken(x, z)
	local sets = M.Sets()
	for _, u in ipairs(Spring.GetUnitsInCylinder(x, z, cfg.SPOT_CLEARANCE)) do
		local d = Spring.GetUnitDefID(u)
		if sets.factories[d] or sets.siphons[d] then return true end
	end
	return false
end

-- Metal siphon: metal spot + a finished pylon in range (no generator needed)
function M.CanPlaceSiphon(teamID, x, z)
	if not M.OnMetal(x, z, M.SIPHON_HALF) then
		return false, "Metal siphons can only be built on a metal spot."
	end
	if M.SpotTaken(x, z) then
		return false, "This metal spot is already in use."
	end
	local sets = M.Sets()
	for _, pid in ipairs(Spring.GetUnitsInCylinder(x, z, cfg.PYLON_RANGE, teamID)) do
		if sets.pylons[Spring.GetUnitDefID(pid)] and Finished(pid) then return true end
	end
	return false, "Build a pylon next to this metal spot first."
end

-- Turrets only work inside the pylon network
function M.CanPlaceTurret(teamID, x, z)
	local sets = M.Sets()
	for _, pid in ipairs(Spring.GetUnitsInCylinder(x, z, cfg.PYLON_RANGE, teamID)) do
		if sets.pylons[Spring.GetUnitDefID(pid)] and Finished(pid) then return true end
	end
	return false, "Turrets must be built within range of a finished pylon."
end

-- returns ok(boolean), reason(string|nil)
function M.CanPlaceFactory(teamID, x, z)
	if not M.OnMetal(x, z) then
		return false, "Weapon factories can only be built on a metal spot."
	end
	if M.SpotTaken(x, z) then
		return false, "This metal spot is already in use."
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
