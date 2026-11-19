function widget:GetInfo()
	return {
		name    = "PW Factory Placement",
		desc    = "While placing a weapon factory: shows metal spots, pylon ranges, power links and whether the spot is valid",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")
local factoryDefs, spots = {}, nil
local lastWhy = ""

local function ScanMetalSpots()
	local sq = cfg.METAL_SQUARE
	local w, h = math.floor(Game.mapSizeX / sq), math.floor(Game.mapSizeZ / sq)
	local seen, result = {}, {}
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for gx = 0, w - 1 do
		for gz = 0, h - 1 do
			local key = gx * h + gz
			if not seen[key] and (Spring.GetMetalAmount(gx, gz) or 0) > 0 then
				seen[key] = true
				local stack, n, sx, sz = { { gx, gz } }, 0, 0, 0
				while #stack > 0 do
					local c = table.remove(stack)
					n, sx, sz = n + 1, sx + c[1] + 0.5, sz + c[2] + 0.5
					for _, d in ipairs(dirs) do
						local nx, nz = c[1] + d[1], c[2] + d[2]
						if nx >= 0 and nz >= 0 and nx < w and nz < h then
							local k = nx * h + nz
							if not seen[k] and (Spring.GetMetalAmount(nx, nz) or 0) > 0 then
								seen[k] = true
								stack[#stack + 1] = { nx, nz }
							end
						end
					end
				end
				result[#result + 1] = { x = sx / n * sq, z = sz / n * sq }
			end
		end
	end
	return result
end

function widget:Initialize()
	for name in pairs(cfg.factories) do
		local ud = UnitDefNames[name]
		if ud then factoryDefs[ud.id] = "factory" end
	end
	for name in pairs(cfg.turrets) do
		local ud = UnitDefNames[name]
		if ud then factoryDefs[ud.id] = "turret" end
	end
	for name in pairs(cfg.siphons) do
		local ud = UnitDefNames[name]
		if ud then factoryDefs[ud.id] = "siphon" end
	end
	spots = ScanMetalSpots()
	local fb = placement.FallbackSpots()
	if #spots == 0 and fb then   -- compiled map has no usable metal layer: show the configured spots
		for _, sp in ipairs(fb) do spots[#spots + 1] = { x = sp[1], z = sp[2] } end
	end
end

local function ActiveFactory()
	local _, cmdID = Spring.GetActiveCommand()
	return cmdID and cmdID < 0 and factoryDefs[-cmdID]
end

function widget:DrawWorldPreUnit()
	if not ActiveFactory() then return end
	local team = Spring.GetMyTeamID()
	local sets = placement.Sets()

	gl.LineWidth(2)
	gl.Color(1, 0.9, 0.2, 0.8)                       -- metal spots
	for _, s in ipairs(spots or {}) do
		gl.DrawGroundCircle(s.x, Spring.GetGroundHeight(s.x, s.z), s.z, 48, 24)
	end
	for _, u in ipairs(Spring.GetTeamUnits(team)) do
		local d = Spring.GetUnitDefID(u)
		if sets.pylons[d] and not Spring.GetUnitIsBeingBuilt(u) then
			local x, y, z = Spring.GetUnitPosition(u)
			gl.Color(0.3, 0.6, 1.0, 0.5); gl.DrawGroundCircle(x, y, z, cfg.PYLON_RANGE, 48)
			gl.Color(1.0, 0.9, 0.3, 0.35); gl.DrawGroundCircle(x, y, z, cfg.POWER_LINK_RANGE, 36)
		end
	end
	local mx, my = Spring.GetMouseState()
	local kind, pos = Spring.TraceScreenRay(mx, my, true)
	if kind == "ground" and pos then
		local kind = ActiveFactory()
		local check = (kind == "siphon") and placement.CanPlaceSiphon
			or (kind == "turret") and placement.CanPlaceTurret or placement.CanPlaceFactory
		local ok, why = check(team, pos[1], pos[3])
		lastWhy = ok and "" or (why or "")
		if ok then gl.Color(0.2, 1, 0.3, 0.9) else gl.Color(1, 0.2, 0.2, 0.9) end
		gl.DrawGroundCircle(pos[1], pos[2], pos[3], (kind == "siphon") and 28 or 40, 32)
	end
	gl.LineWidth(1); gl.Color(1, 1, 1, 1)
end

function widget:DrawScreen()
	if lastWhy ~= "" and ActiveFactory() then
		local mx, my = Spring.GetMouseState()
		gl.Color(1, 0.4, 0.4, 1)
		gl.Text(lastWhy, mx + 24, my - 24, 14, "o")
		gl.Color(1, 1, 1, 1)
	end
end
