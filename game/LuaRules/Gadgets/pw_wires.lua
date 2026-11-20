function gadget:GetInfo()
	return {
		name    = "PW Power Wires",
		desc    = "Draws the power network: pylon-to-pylon links and wires from pylons to generators, siphons, turrets and factories (/pw_wires toggles)",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 5,
		enabled = true,
	}
end

-- Unsynced gadget (not a widget) so it always loads together with the rest of the game rules.
if gadgetHandler:IsSyncedCode() then return end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")
local Fx        = VFS.Include("LuaRules/Headers/pw_lightfx.lua")
local sets
local links = {}          -- { x1,y1,z1, x2,y2,z2, kind, live }
local lastBuild = -100
local enabled = true
local failed = false
local LIFT = 12           -- extra height above the building's centre

local COLORS = {
	pylon     = { 0.35, 0.85, 1.0 },
	generator = { 1.0, 0.9, 0.2 },
	consumer  = { 0.3, 1.0, 0.45 },
	dead      = { 1.0, 0.25, 0.2 },
}

local function Visible(u)
	if Spring.GetSpectatingState() then return true end
	return Spring.GetUnitAllyTeam(u) == Spring.GetMyAllyTeamID()
end

local function Rebuild()
	sets = sets or placement.Sets()
	links = {}
	local pyl, others = {}, {}
	for _, u in ipairs(Spring.GetAllUnits()) do
		if Visible(u) then
			local d = Spring.GetUnitDefID(u)
			local x, y, z = Spring.GetUnitPosition(u, true)   -- true = centre of the model
			if x and d then
				local rec = { x = x, y = y + LIFT, z = z, ally = Spring.GetUnitAllyTeam(u), team = Spring.GetUnitTeam(u),
				              done = not Spring.GetUnitIsBeingBuilt(u) }
				if sets.pylons[d] then
					pyl[#pyl + 1] = rec
				elseif sets.generators[d] then
					rec.kind = "generator"; rec.range = cfg.POWER_LINK_RANGE; others[#others + 1] = rec
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
					links[#links + 1] = { a.x, a.y, a.z, b.x, b.y, b.z, "pylon", a.done and b.done, a.team }
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
			links[#links + 1] = { best.x, best.y, best.z, o.x, o.y, o.z, o.kind, o.done, o.team }
		elseif o.kind == "consumer" and o.done then
			links[#links + 1] = { o.x, o.y, o.z, o.x, o.y + 60, o.z, "dead", false, o.team }   -- red stub: no power
		end
	end
end

local function Draw()
	local frame = Spring.GetGameFrame()
	if frame - lastBuild >= 8 or #links == 0 then Rebuild(); lastBuild = frame end
	if #links == 0 then return end
	local t = os.clock()
	gl.DepthTest(false)                -- always visible, even through city blocks and models
	gl.Blending(true)
	for pass = 1, 2 do
		gl.LineWidth(pass == 1 and 6 or 2)
		for i, l in ipairs(links) do
			local c = COLORS[l[7]]
			local a = (l[8] and 0.9 or 0.45) * Fx.Brightness(l[9], i, t)   -- flickers when energy is low
			if pass == 1 then a = a * 0.25 end          -- soft glow underneath
			gl.Color(c[1], c[2], c[3], a)
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(l[1], l[2], l[3]); gl.Vertex(l[4], l[5], l[6])
			end)
		end
	end
	-- energy pulses travelling along live wires
	gl.PointSize(8)
	gl.BeginEnd(GL.POINTS, function()
		for i, l in ipairs(links) do
			if l[8] and l[7] ~= "dead" then
				local c = COLORS[l[7]]
				for k = 0, 1 do
					local p = (t * 0.5 + i * 0.137 + k * 0.5) % 1
					gl.Color(c[1], c[2], c[3], Fx.Brightness(l[9], i, t))
					gl.Vertex(l[1] + (l[4] - l[1]) * p, l[2] + (l[5] - l[2]) * p, l[3] + (l[6] - l[3]) * p)
				end
			end
		end
	end)
	gl.PointSize(1); gl.LineWidth(1); gl.Color(1, 1, 1, 1)
end

function gadget:Initialize()
	sets = placement.Sets()
	gadgetHandler:AddChatAction("pw_wires", function()
		enabled = not enabled
		Spring.Echo("[Pylon Wars] power wires " .. (enabled and "on" or "off"))
	end, "toggle the power wire overlay")
	Spring.Echo("[Pylon Wars] power wires loaded (type /pw_wires to toggle)")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("pw_wires")
end

-- DrawWorld runs after units; errors are caught so a bug can never remove the gadget silently
function gadget:DrawWorld()
	if not enabled or failed then return end
	local ok, err = pcall(Draw)
	if not ok then
		failed = true
		Spring.Echo("[Pylon Wars] wire overlay error: " .. tostring(err))
	end
end
