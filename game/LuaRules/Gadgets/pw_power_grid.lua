function gadget:GetInfo()
	return {
		name    = "PW Power Grid",
		desc    = "Siphons, turrets, beacons, masts, towers and factories only work while a finished pylon of their team is in range; otherwise they are shut down",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 3,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")
local powered   = {}   -- [unitID] = true/false (last known state)

local function HasPower(unitID, teamID, sets)
	local x, _, z = Spring.GetUnitPosition(unitID)
	for _, pid in ipairs(Spring.GetUnitsInCylinder(x, z, cfg.PYLON_RANGE, teamID)) do
		if sets.pylons[Spring.GetUnitDefID(pid)] and not Spring.GetUnitIsBeingBuilt(pid) then return true end
	end
	return false
end

function gadget:UnitDestroyed(unitID) powered[unitID] = nil end

function gadget:GameFrame(frame)
	if frame % 15 ~= 7 then return end
	local sets = placement.Sets()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local defID = Spring.GetUnitDefID(unitID)
		local ud = UnitDefs[defID]
		if ud and sets.consumers[defID] and not Spring.GetUnitIsBeingBuilt(unitID) then
			local teamID = Spring.GetUnitTeam(unitID)
			local on = HasPower(unitID, teamID, sets)
			local _, maxhp = Spring.GetUnitHealth(unitID)
			if not on then
				-- keep the unit paralysed while unpowered (stunned units neither produce nor shoot)
				Spring.SetUnitHealth(unitID, { paralyze = maxhp * 2 })
			elseif powered[unitID] == false then
				Spring.SetUnitHealth(unitID, { paralyze = 0 })
			end
			if powered[unitID] ~= on then
				if powered[unitID] ~= nil or not on then
					Spring.SendMessageToTeam(teamID, on
						and ("[Pylon Wars] " .. (ud.humanName or ud.name) .. " is powered again.")
						or  ("[Pylon Wars] " .. (ud.humanName or ud.name) .. " has no power: build or repair a pylon nearby."))
				end
				powered[unitID] = on
				Spring.SetUnitRulesParam(unitID, "pw_powered", on and 1 or 0, { allied = true })
			end
		end
	end
end
