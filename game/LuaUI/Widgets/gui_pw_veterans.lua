function widget:GetInfo()
	return {
		name    = "PW Veteran Studs",
		desc    = "Draws 1-4 golden studs above veteran units (levels come from pw_veterancy's pw_level rules param)",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 6,
		enabled = true,
	}
end

local spGetVisibleUnits   = Spring.GetVisibleUnits
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetUnitHeight     = Spring.GetUnitHeight
local spWorldToScreen     = Spring.WorldToScreenCoords
local spGetCameraPosition = Spring.GetCameraPosition
local glColor, glRect, glBeginEnd, glVertex = gl.Color, gl.Rect, gl.BeginEnd, gl.Vertex

local function Stud(cx, cy, r, level)
	-- a tiny brick stud: dark base ring, gold body, white highlight
	glColor(0.35, 0.25, 0.02, 0.95)
	glRect(cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)
	glColor(1.0, 0.82 - 0.06 * (level - 1), 0.1, 1)
	glRect(cx - r, cy - r, cx + r, cy + r)
	glColor(1, 1, 1, 0.75)
	glRect(cx - r + 1, cy + r - 2, cx - 1, cy + r - 1)
end

function widget:DrawScreen()
	local camX, camY, camZ = spGetCameraPosition()
	for _, u in ipairs(spGetVisibleUnits(-1, nil, true)) do
		local lv = spGetUnitRulesParam(u, "pw_level")
		if lv and lv >= 1 then
			local x, y, z = spGetUnitPosition(u)
			if x then
				local h = (spGetUnitHeight(u) or 20) + 14
				local sx, sy = spWorldToScreen(x, y + h, z)
				if sx then
					local dx, dy, dz = camX - x, camY - y, camZ - z
					local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
					local r = math.max(2, math.min(6, 2600 / math.max(dist, 1)))
					local step = r * 2.8
					local x0 = sx - (lv - 1) * step / 2
					for i = 1, math.min(lv, 4) do
						Stud(x0 + (i - 1) * step, sy, r, i)
					end
				end
			end
		end
	end
	glColor(1, 1, 1, 1)
end
