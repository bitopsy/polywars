function gadget:GetInfo()
	return {
		name    = "PW Veterancy",
		desc    = "Units and commanders earn XP from damage and kills and level up (health, damage, commander energy)",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 2,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg    = VFS.Include("LuaRules/Headers/pw_config.lua")
local LEVELS = cfg.XP_LEVELS
local xp, level, baseHP = {}, {}, {}

local function Eligible(unitDefID)
	local ud = UnitDefs[unitDefID]
	return ud and #ud.weapons > 0 and ud.canMove
end

function gadget:UnitCreated(unitID, unitDefID)
	if not Eligible(unitDefID) then return end
	xp[unitID], level[unitID] = 0, 0
	baseHP[unitID] = select(2, Spring.GetUnitHealth(unitID))
end

local function AddXP(unitID, amount)
	if not xp[unitID] or amount <= 0 then return end
	xp[unitID] = xp[unitID] + amount
	local lv = 0
	for i, need in ipairs(LEVELS) do if xp[unitID] >= need then lv = i end end
	if lv > level[unitID] then
		local hp, maxhp = Spring.GetUnitHealth(unitID)
		local newMax = baseHP[unitID] * (1 + cfg.XP_HEALTH_PER_LV * lv)
		Spring.SetUnitMaxHealth(unitID, newMax)
		Spring.SetUnitHealth(unitID, hp + (newMax - maxhp))
		level[unitID] = lv
		Spring.SetUnitRulesParam(unitID, "pw_level", lv, { allied = true })
		local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
		Spring.SendMessageToTeam(Spring.GetUnitTeam(unitID),
			("[Pylon Wars] %s reached veteran level %d!"):format(ud.humanName or ud.name, lv))
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	local lv = attackerID and level[attackerID]
	if lv and lv > 0 and attackerTeam ~= unitTeam then
		return damage * (1 + cfg.XP_DAMAGE_PER_LV * lv), 1
	end
	return damage, 1
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if attackerID and attackerTeam ~= unitTeam and not paralyzer then
		local hp = select(1, Spring.GetUnitHealth(unitID)) or 0
		AddXP(attackerID, math.min(damage, hp + damage))
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if attackerID and attackerTeam and attackerTeam ~= unitTeam then
		local cost = (UnitDefs[unitDefID] or {}).metalCost or 0
		AddXP(attackerID, 2 * cost)
	end
	xp[unitID], level[unitID], baseHP[unitID] = nil, nil, nil
end

-- commander veteran perk: bonus energy income
function gadget:GameFrame(frame)
	if frame % 30 ~= 0 then return end
	for unitID, lv in pairs(level) do
		if lv > 0 and cfg.commanders[UnitDefs[Spring.GetUnitDefID(unitID)].name] then
			Spring.AddTeamResource(Spring.GetUnitTeam(unitID), "energy", cfg.XP_ENERGY_PER_LV * lv)
		end
	end
end
