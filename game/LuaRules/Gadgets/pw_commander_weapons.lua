function gadget:GetInfo()
	return {
		name    = "PW Commander Weapons",
		desc    = "Adds per-weapon ON/OFF toggles (commands W1..W6) to commanders; disabled weapons never acquire targets",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg      = VFS.Include("LuaRules/Headers/pw_config.lua")
local CMD_BASE = cfg.CMD_WEAPON_BASE
local MAX      = cfg.MAX_WEAPONS

local disabled = {}   -- [unitID] = { [weaponNum] = true }  (absent = enabled)

function gadget:Initialize()
	-- Ask the engine to call AllowWeaponTarget for the commander weapons.
	local watch = Script.SetWatchAllowTarget or Script.SetWatchWeapon
	if watch then
		for name in pairs(cfg.commanders) do
			local ud = UnitDefNames[name]
			if ud then
				for _, w in ipairs(ud.weapons) do watch(w.weaponDef, true) end
			end
		end
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not (ud and cfg.commanders[ud.name]) or disabled[unitID] then return end
	disabled[unitID] = {}
	for i, w in ipairs(ud.weapons) do
		if i > MAX then break end
		local wd = WeaponDefs[w.weaponDef]
		local label = (wd.description and wd.description ~= "") and wd.description or wd.name
		Spring.InsertUnitCmdDesc(unitID, {
			id      = CMD_BASE + i - 1,
			type    = CMDTYPE.ICON_MODE,
			name    = "W" .. i,
			action  = "pw_weapon" .. i,
			tooltip = ("Weapon %d: %s\nRange %d | Energy per shot %d"):format(i, label, wd.range or 0, wd.energyCost or 0),
			params  = { "1", "Off", "On" },
		})
	end
end

function gadget:UnitDestroyed(unitID)
	disabled[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if cmdID < CMD_BASE or cmdID >= CMD_BASE + MAX then return true end
	local slots = disabled[unitID]
	if slots then
		local i  = cmdID - CMD_BASE + 1
		local on = (cmdParams[1] or 1) ~= 0
		slots[i] = (not on) or nil
		local idx = Spring.FindUnitCmdDesc(unitID, cmdID)
		if idx then
			Spring.EditUnitCmdDesc(unitID, idx, { params = { on and "1" or "0", "Off", "On" } })
		end
	end
	return false  -- consumed: it is a state toggle, not a queued order
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	local slots = disabled[attackerID]
	if slots and slots[attackerWeaponNum] then
		return false, defPriority or 1
	end
	return true, defPriority or 1
end
