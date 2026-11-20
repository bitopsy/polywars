function gadget:GetInfo()
	return {
		name    = "PW Pylon Light & Sensor Range",
		desc    = "Pylons emit light (ground pool + halo) and show their sensor range: sight ring, radar ring when selected",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 4,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then return end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")
local Fx        = VFS.Include("LuaRules/Headers/pw_lightfx.lua")

local sets
local glowOn, rangeOn, failed = true, true, false
local pylons = {}            -- cached list of visible pylons
local lastScan = -100

-- light colour per faction (Aegis = cold blue-white, Vanta = hot orange-red)
local LIGHT = {
	aegis = { 0.40, 0.75, 1.00 },
	vanta = { 1.00, 0.38, 0.18 },
}
local GLOW_RADIUS = 210      -- ground light pool
local HALO_SIZE   = 46       -- billboard halo around the pylon head

local function Visible(u)
	if Spring.GetSpectatingState() then return true end
	return Spring.GetUnitAllyTeam(u) == Spring.GetMyAllyTeamID()
end

local function Scan()
	sets = sets or placement.Sets()
	pylons = {}
	for _, u in ipairs(Spring.GetAllUnits()) do
		local d = Spring.GetUnitDefID(u)
		if d and sets.pylons[d] and Visible(u) then
			local x, y, z = Spring.GetUnitPosition(u)
			local _, top = Spring.GetUnitPosition(u, false, true)   -- aim point (top of model)
			pylons[#pylons + 1] = {
				id = u, team = Spring.GetUnitTeam(u), x = x, y = y, z = z, top = (top or y + 40),
				col = LIGHT[(UnitDefs[d].name or ""):match("^(%a+)_")] or LIGHT.aegis,
				done = not Spring.GetUnitIsBeingBuilt(u),
				sight = UnitDefs[d].losRadius or cfg.PYLON_SIGHT,
				radar = UnitDefs[d].radarRadius or cfg.PYLON_RADAR,
				ground = Spring.GetGroundHeight(x, z),
			}
		end
	end
end

local function Refresh()
	local f = Spring.GetGameFrame()
	if f - lastScan >= 10 or #pylons == 0 then Scan(); lastScan = f end
end

-- additive radial gradient on the ground
local function DrawPool(p, intensity)
	local c = p.col
	local y = p.ground + 3
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Color(c[1], c[2], c[3], 0.42 * intensity)
		gl.Vertex(p.x, y, p.z)
		for i = 0, 24 do
			local a = i / 24 * 2 * math.pi
			gl.Color(c[1], c[2], c[3], 0)
			gl.Vertex(p.x + math.cos(a) * GLOW_RADIUS, y, p.z + math.sin(a) * GLOW_RADIUS)
		end
	end)
end

function gadget:DrawWorldPreUnit()
	if failed then return end
	local ok, err = pcall(function()
		Refresh()
		if #pylons == 0 then return end
		local t = os.clock()
		if glowOn then
			gl.DepthTest(true); gl.DepthMask(false)
			gl.PolygonOffset(-2, -2); gl.Culling(false)
			gl.Blending(GL.SRC_ALPHA, GL.ONE)               -- additive: it adds light
			for _, p in ipairs(pylons) do
				local pulse = 0.85 + 0.15 * math.sin(t * 2.2 + p.id)
				DrawPool(p, (p.done and 1 or 0.35) * pulse * Fx.Brightness(p.team, p.id, t))
			end
			gl.PolygonOffset(false)
			gl.DepthMask(true); gl.DepthTest(false)
		end
		if rangeOn then
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.LineWidth(2)
			for _, p in ipairs(pylons) do
				local c = p.col
				if p.done then
					gl.Color(c[1], c[2], c[3], 0.35 + 0.1 * math.sin(t * 1.5 + p.id))
					gl.DrawGroundCircle(p.x, p.ground, p.z, p.sight, 64)         -- sight range
					if Spring.IsUnitSelected(p.id) then
						gl.Color(c[1], c[2], c[3], 0.28)
						gl.DrawGroundCircle(p.x, p.ground, p.z, p.radar, 96)      -- radar range
					end
				end
			end
			gl.LineWidth(1)
		end
		gl.Color(1, 1, 1, 1)
		gl.Blending(true)
	end)
	if not ok then failed = true; Spring.Echo("[Pylon Wars] pylon light error: " .. tostring(err)) end
end

-- halo around the pylon head, always facing the camera
function gadget:DrawWorld()
	if failed or not glowOn or #pylons == 0 then return end
	local ok, err = pcall(function()
		local t = os.clock()
		gl.DepthTest(false); gl.DepthMask(false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		for _, p in ipairs(pylons) do
			local c = p.col
			local pulse = 0.8 + 0.2 * math.sin(t * 2.2 + p.id)
			local k = (p.done and 1 or 0.3) * pulse * Fx.Brightness(p.team, p.id, t)
			gl.PushMatrix()
			gl.Translate(p.x, p.top + 6, p.z)
			gl.Billboard()
			gl.BeginEnd(GL.TRIANGLE_FAN, function()
				gl.Color(1, 1, 1, 0.75 * k)                      -- hot white core
				gl.Vertex(0, 0, 0)
				for i = 0, 20 do
					local a = i / 20 * 2 * math.pi
					gl.Color(c[1], c[2], c[3], 0)
					gl.Vertex(math.cos(a) * HALO_SIZE, math.sin(a) * HALO_SIZE, 0)
				end
			end)
			gl.PopMatrix()
		end
		gl.Color(1, 1, 1, 1); gl.Blending(true); gl.DepthMask(true)
	end)
	if not ok then failed = true; Spring.Echo("[Pylon Wars] pylon halo error: " .. tostring(err)) end
end

function gadget:Initialize()
	sets = placement.Sets()
	gadgetHandler:AddChatAction("pw_glow", function()
		glowOn = not glowOn
		Spring.Echo("[Pylon Wars] pylon light " .. (glowOn and "on" or "off"))
	end, "toggle pylon light")
	gadgetHandler:AddChatAction("pw_range", function()
		rangeOn = not rangeOn
		Spring.Echo("[Pylon Wars] pylon sensor rings " .. (rangeOn and "on" or "off"))
	end, "toggle pylon sensor range rings")
	Spring.Echo("[Pylon Wars] pylon light loaded (/pw_glow, /pw_range toggle; select a pylon to see its radar range)")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("pw_glow")
	gadgetHandler:RemoveChatAction("pw_range")
end
