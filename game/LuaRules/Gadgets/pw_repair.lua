function gadget:GetInfo()
	return {
		name    = "PW Repair Beacons",
		desc    = "Powered repair beacons heal friendly units and buildings in range, paying a little energy",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 4,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg = VFS.Include("LuaRules/Headers/pw_config.lua")
local STEP = 15   -- frames between heal ticks

local beaconDefs = {}   -- [unitDefID] = {heal = HP/tick, radius = elmos}

function gadget:Initialize()
	for name in pairs(cfg.beacons or {}) do
		local ud = UnitDefNames[name]
		if ud then beaconDefs[ud.id] = { heal = cfg.BEACON_HEAL, radius = cfg.BEACON_RADIUS or 280 } end
	end
	for name in pairs(cfg.menders or {}) do
		local ud = UnitDefNames[name]
		if ud then beaconDefs[ud.id] = { heal = cfg.MENDER_HEAL or 22, radius = cfg.MENDER_RADIUS or 170 } end
	end
end

function gadget:GameFrame(frame)
	if frame % STEP ~= 3 then return end
	for _, teamID in ipairs(Spring.GetTeamList()) do
		for defID, p in pairs(beaconDefs) do
			local perTick = p.heal * STEP / 30
			local radius  = p.radius
			for _, b in ipairs(Spring.GetTeamUnitsByDefs(teamID, { defID })) do
				-- stunned == unpowered (pw_power_grid paralyses structures without a pylon)
				if not Spring.GetUnitIsBeingBuilt(b) and not Spring.GetUnitIsStunned(b) then
					local allyTeam = Spring.GetUnitAllyTeam(b)
					local bx, _, bz = Spring.GetUnitPosition(b)
					for _, u in ipairs(Spring.GetUnitsInCylinder(bx, bz, radius)) do
						if Spring.GetUnitAllyTeam(u) == allyTeam then
							local hp, maxhp, _, _, build = Spring.GetUnitHealth(u)
							if hp and maxhp and hp > 0 and hp < maxhp and (build or 1) >= 1 then
								local heal = math.min(perTick, maxhp - hp)
								if Spring.UseTeamResource(teamID, "energy", heal * cfg.BEACON_ENERGY) then
									Spring.SetUnitHealth(u, hp + heal)
								end
							end
						end
					end
				end
			end
		end
	end
end
