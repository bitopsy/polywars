function gadget:GetInfo()
	return {
		name    = "PW Factory Rules",
		desc    = "Weapon factories may only be started on a metal spot with a finished pylon + linked generator in range",
		author  = "goddot",
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
	if not (ud and cfg.factories[ud.name]) or not x then
		return true   -- not a factory, or built out of a factory (no position given)
	end
	local ok, why = placement.CanPlaceFactory(builderTeam, x, z)
	if not ok then
		Spring.SendMessageToTeam(builderTeam, "[polywars] " .. why)
		return false
	end
	return true
end
