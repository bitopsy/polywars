function gadget:GetInfo()
	return {
		name    = "PW Game Spawn",
		desc    = "Spawns each team's commander at its start position and sets start resources",
		author  = "goddot",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = -1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local modOptions = Spring.GetModOptions() or {}

-- Start position priority: 1) what the engine/lobby reports  2) mapinfo.lua `teams`
-- 3) a symmetric west/east default. The engine reports no position (x < 0) when the start
-- script uses "choose in game" and nobody clicked; spawning there puts the commander off-map,
-- which looks exactly like "the commander is not on the map".
local mapTeams
do
	local ok, mi = pcall(VFS.Include, "mapinfo.lua", nil, VFS.MAP)
	if ok and type(mi) == "table" then mapTeams = mi.teams end
end

local function StartPos(teamID, order)
	local x, _, z = Spring.GetTeamStartPosition(teamID)
	if x and z and x > 0 and z > 0 then return x, z end
	local t = mapTeams and mapTeams[teamID]
	if t and t.startPos then return t.startPos.x, t.startPos.z end
	local sx, sz = Game.mapSizeX, Game.mapSizeZ
	return (order % 2 == 0) and sx * 0.125 or sx * 0.875, sz * 0.5
end

local function StartUnitName(teamID)
	local _, _, _, _, side = Spring.GetTeamInfo(teamID)
	local name = ((type(side) == "string" and side or ""):lower()) .. "_commander"
	if not UnitDefNames[name] then
		name = (teamID % 2 == 0) and "aegis_commander" or "vanta_commander"
	end
	return name
end

local function SpawnTeam(teamID, order)
	local x, z = StartPos(teamID, order)
	x, z = 16 * math.floor((x + 8) / 16), 16 * math.floor((z + 8) / 16)   -- snap to the 16 grid
	x = math.max(64, math.min(Game.mapSizeX - 64, x))
	z = math.max(64, math.min(Game.mapSizeZ - 64, z))
	local facing = (x < Game.mapSizeX / 2) and "east" or "west"            -- face the map centre
	local unitID = Spring.CreateUnit(StartUnitName(teamID), x, Spring.GetGroundHeight(x, z), z, facing, teamID)
	if not unitID then
		Spring.Echo("[polywars] FAILED to spawn commander for team " .. teamID)
		return
	end
	-- start resources (same behaviour as the stock spawn gadget: storage == start amount)
	local opts = select(8, Spring.GetTeamInfo(teamID)) or {}
	local m = tonumber(opts.startmetal  or modOptions.startmetal  or 1000)
	local e = tonumber(opts.startenergy or modOptions.startenergy or 1500)
	Spring.SetTeamResource(teamID, "ms", math.max(m, 500))
	Spring.SetTeamResource(teamID, "es", math.max(e, 1500))
	Spring.SetTeamResource(teamID, "m", m)
	Spring.SetTeamResource(teamID, "e", e)
end

local spawned = false
local function SpawnAll()
	if spawned then return end
	spawned = true
	local gaia = Spring.GetGaiaTeamID()
	local order = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia then
			if Spring.GetTeamUnitCount(teamID) == 0 then SpawnTeam(teamID, order) end
			order = order + 1
		end
	end
end

function gadget:GameStart() SpawnAll() end
function gadget:GameFrame(frame)       -- safety net if GameStart was missed
	if frame >= 1 and frame <= 5 then SpawnAll() end
end
