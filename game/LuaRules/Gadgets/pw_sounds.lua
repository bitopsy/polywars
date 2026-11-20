function gadget:GetInfo()
	return {
		name    = "PW Sounds",
		desc    = "Event sounds: build complete, blink, veteran level-up, power loss/restore (other gadgets call GG.PW_Sound)",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = -5,
		enabled = true,
	}
end

local FILES = {
	complete = "sounds/complete.wav", blink = "sounds/blink.wav", levelup = "sounds/levelup.wav",
	power_off = "sounds/power_off.wav", power_on = "sounds/power_on.wav",
}

if gadgetHandler:IsSyncedCode() then
	local cfg = VFS.Include("LuaRules/Headers/pw_config.lua")

	-- name, position, and optionally the team that should hear it (nil = everyone who can see the spot)
	GG.PW_Sound = function(name, x, y, z, team)
		SendToUnsynced("pw_sound", name, x, y, z, team or -1)
	end

	function gadget:UnitFinished(unitID, unitDefID, teamID)
		local ud = UnitDefs[unitDefID]
		if ud and (cfg.pylons[ud.name] or cfg.generators[ud.name] or cfg.siphons[ud.name]
		    or cfg.turrets[ud.name] or cfg.factories[ud.name]) then
			local x, y, z = Spring.GetUnitPosition(unitID)
			GG.PW_Sound("complete", x, y, z, teamID)
		end
	end
	return
end

-- ---------------------------------------------------------------- unsynced
local function Audible(x, y, z, team)
	if Spring.GetSpectatingState() then return true end
	if team and team >= 0 then return team == Spring.GetMyTeamID() end
	return Spring.IsPosInLos(x, y, z, Spring.GetMyAllyTeamID())
end

function gadget:RecvFromSynced(cmd, name, x, y, z, team)
	if cmd ~= "pw_sound" then return end
	local file = FILES[name]
	if file and Audible(x, y, z, team) then
		if team and team >= 0 then
			Spring.PlaySoundFile(file, 0.7)               -- team feedback: not positional
		else
			Spring.PlaySoundFile(file, 0.9, x, y, z)      -- world sound
		end
	end
end
