function gadget:GetInfo()
	return {
		name    = "PW Factory Rules",
		desc    = "Weapon factories may only be started on a metal spot with a finished pylon + linked generator in range",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	local ud = UnitDefs[unitDefID]
	local n = ud and ud.name
	if not n or not x or not (cfg.factories[n] or cfg.siphons[n] or cfg.turrets[n]
	                          or cfg.beacons[n] or cfg.masts[n] or cfg.obelisks[n]) then
		return true   -- not a pylon-powered structure, or built out of a factory (no position given)
	end
	local check = placement.CanPlaceTurret
	if cfg.factories[n] then check = placement.CanPlaceFactory
	elseif cfg.siphons[n] then check = placement.CanPlaceSiphon end
	local ok, why = check(builderTeam, x, z)
	if not ok then
		Spring.SendMessageToTeam(builderTeam, "[Pylon Wars] " .. why)
		return false
	end
	return true
end
