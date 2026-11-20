function widget:GetInfo()
	return {
		name    = "PW Power Wires",
		desc    = "Draws the power network: pylon-to-pylon links and wires from pylons to generators, siphons, turrets and factories",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 5,
		enabled = true,
	}
end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")
local sets
local links = {}          -- { x1,y1,z1, x2,y2,z2, kind, live }
local lastBuild = -100
local LIFT = 20           -- wire height above the building base

local COLORS = {
	pylon     = { 0.35, 0.75, 1.0 },
	generator = { 1.0, 0.9, 0.3 },
	consumer  = { 0.4, 1.0, 0.5 },
	dead      = { 1.0, 0.3, 0.25 },
}

function widget:Initialize() sets = placement.Sets() end

local function Visible(u)
	if Spring.GetSpectatingState() then return true end
	return Spring.GetUnitAllyTeam(u) == Spring.GetMyAllyTeamID()
end

local function Rebuild()
	links = {}
	local pyl, others = {}, {}
	for _, u in ipairs(Spring.GetAllUnits()) do
		if Visible(u) then
			local d = Spring.GetUnitDefID(u)
			local x, y, z = Spring.GetUnitPosition(u)
			if x then
				local rec = { id = u, x = x, y = y + LIFT, z = z, ally = Spring.GetUnitAllyTeam(u),
				              done = not Spring.GetUnitIsBeingBuilt(u) }
				if sets.pylons[d] then pyl[#pyl + 1] = rec
				elseif sets.generators[d] then rec.kind = "generator"; rec.range = cfg.POWER_LINK_RANGE; others[#others + 1] = rec
				elseif sets.consumers[d] then
					rec.kind = "consumer"; rec.range = cfg.PYLON_RANGE; others[#others + 1] = rec
				end
			end
		end
	end
	-- pylon <-> pylon mesh (same ally team, within link range)
	for i = 1, #pyl do
		for j = i + 1, #pyl do
			local a, b = pyl[i], pyl[j]
			if a.ally == b.ally then
				local dx, dz = a.x - b.x, a.z - b.z
				if dx * dx + dz * dz <= cfg.WIRE_PYLON_LINK ^ 2 then
					links[#links + 1] = { a.x, a.y, a.z, b.x, b.y, b.z, "pylon", a.done and b.done }
				end
			end
		end
	end
	-- every other structure is wired to the nearest finished pylon in range
	for _, o in ipairs(others) do
		local best, bd = nil, o.range ^ 2
		for _, p in ipairs(pyl) do
			if p.ally == o.ally and p.done then
				local dx, dz = o.x - p.x, o.z - p.z
				local d2 = dx * dx + dz * dz
				if d2 <= bd then best, bd = p, d2 end
			end
		end
		if best then
			links[#links + 1] = { best.x, best.y, best.z, o.x, o.y, o.z, o.kind, o.done }
		elseif o.kind == "consumer" and o.done then
			-- powerless: draw a short red stub so the player sees the problem
			links[#links + 1] = { o.x, o.y, o.z, o.x, o.y + 40, o.z, "dead", false }
		end
	end
end

function widget:DrawWorld()
	local frame = Spring.GetGameFrame()
	if frame - lastBuild >= 8 then Rebuild(); lastBuild = frame end
	if #links == 0 then return end
	local t = os.clock()
	gl.DepthTest(true)
	gl.LineWidth(2)
	for _, l in ipairs(links) do
		local c = COLORS[l[7]]
		local a = l[8] and 0.85 or 0.35
		gl.Color(c[1], c[2], c[3], a)
		gl.BeginEnd(GL.LINES, function()
			gl.Vertex(l[1], l[2], l[3]); gl.Vertex(l[4], l[5], l[6])
		end)
	end
	-- energy "pulses" travelling along live wires
	gl.PointSize(5)
	gl.BeginEnd(GL.POINTS, function()
		for i, l in ipairs(links) do
			if l[8] and l[7] ~= "dead" then
				local c = COLORS[l[7]]
				local p = (t * 0.6 + i * 0.137) % 1
				gl.Color(c[1], c[2], c[3], 1)
				gl.Vertex(l[1] + (l[4] - l[1]) * p, l[2] + (l[5] - l[2]) * p, l[3] + (l[6] - l[3]) * p)
			end
		end
	end)
	gl.PointSize(1); gl.LineWidth(1); gl.Color(1, 1, 1, 1)
	gl.DepthTest(false)
end
