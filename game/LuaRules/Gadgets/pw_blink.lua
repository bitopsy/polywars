function gadget:GetInfo()
	return {
		name    = "PW Commander Blink",
		desc    = "Adds a Blink (dash) command to commanders: short ground-targeted jump for energy, with a cooldown",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local CMD_BLINK = cfg.CMD_BLINK
local readyAt   = {}   -- [unitID] = frame when blink is available again

function gadget:UnitCreated(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not (ud and cfg.commanders[ud.name]) then return end
	Spring.InsertUnitCmdDesc(unitID, {
		id      = CMD_BLINK,
		type    = CMDTYPE.ICON_MAP,
		name    = "Blink",
		action  = "pw_blink",
		cursor  = "Attack",
		tooltip = ("Blink [F]: jump up to %d elmos.\nCosts %d energy, %d s cooldown."):format(
			cfg.BLINK_RANGE, cfg.BLINK_COST, cfg.BLINK_COOLDOWN / 30),
	})
end

function gadget:UnitDestroyed(unitID) readyAt[unitID] = nil end

local function Blink(unitID, unitDefID, teamID, params)
	local tx, tz = params[1], params[3]
	if not (tx and tz) then return end
	local frame = Spring.GetGameFrame()
	if (readyAt[unitID] or 0) > frame then
		Spring.SendMessageToTeam(teamID, ("[Pylon Wars] Blink ready in %.1f s"):format((readyAt[unitID] - frame) / 30))
		return
	end
	local energy = Spring.GetTeamResources(teamID, "energy") or 0
	if energy < cfg.BLINK_COST then
		Spring.SendMessageToTeam(teamID, "[Pylon Wars] Not enough energy to blink.")
		return
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	local dx, dz = tx - x, tz - z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 24 then return end
	if dist > cfg.BLINK_RANGE then
		dx, dz, dist = dx * cfg.BLINK_RANGE / dist, dz * cfg.BLINK_RANGE / dist, cfg.BLINK_RANGE
	end
	-- walk back from the target along the jump line until we find ground the commander can stand on
	local steps = 16
	for i = steps, 1, -1 do
		local px, pz = x + dx * i / steps, z + dz * i / steps
		local py = Spring.GetGroundHeight(px, pz)
		if Spring.TestMoveOrder(unitDefID, px, py, pz) then
			if not Spring.UseTeamResource(teamID, "energy", cfg.BLINK_COST) then return end
			Spring.SetUnitPosition(unitID, px, pz)
			Spring.SetUnitVelocity(unitID, 0, 0, 0)
			readyAt[unitID] = frame + cfg.BLINK_COOLDOWN
			Spring.SetUnitRulesParam(unitID, "pw_blink_ready", readyAt[unitID], { allied = true })
			return
		end
	end
	Spring.SendMessageToTeam(teamID, "[Pylon Wars] Nowhere to blink to.")
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if cmdID ~= CMD_BLINK then return true end
	Blink(unitID, unitDefID, teamID, cmdParams)
	return false    -- instant action: never queued
end
