function gadget:GetInfo()
	return {
		name    = "PW Commander Death = Defeat",
		desc    = "A team without a commander is wiped out; the last ally team standing wins",
		author  = "goddot",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg = VFS.Include("LuaRules/Headers/pw_config.lua")
local commanderDefs = {}
local pending, over = false, false

function gadget:Initialize()
	for name in pairs(cfg.commanders) do
		local ud = UnitDefNames[name]
		if ud then commanderDefs[#commanderDefs + 1] = ud.id end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if ud and cfg.commanders[ud.name] then pending = true end
end

function gadget:GameFrame(frame)
	if not pending or over then return end
	pending = false
	local gaia = Spring.GetGaiaTeamID()
	local alive = {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia then
			local _, _, dead, _, _, allyTeam = Spring.GetTeamInfo(teamID)
			if not dead then
				if #Spring.GetTeamUnitsByDefs(teamID, commanderDefs) > 0 then
					alive[allyTeam] = true
				else
					for _, u in ipairs(Spring.GetTeamUnits(teamID)) do
						Spring.DestroyUnit(u, true, false)
					end
				end
			end
		end
	end
	local winners = {}
	for allyTeam in pairs(alive) do winners[#winners + 1] = allyTeam end
	if #winners <= 1 then
		over = true
		Spring.GameOver(winners)
	end
end
