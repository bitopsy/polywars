function widget:GetInfo()
	return {
		name    = "PW Commander HUD",
		desc    = "Weapon bar for the selected commander: hotkeys (Z X C V B N), range, energy cost, cooldown, ON/OFF",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local cfg      = VFS.Include("LuaRules/Headers/pw_config.lua")
local CMD_BASE = cfg.CMD_WEAPON_BASE
local commanderDefs = {}
local vsx, vsy = Spring.GetViewGeometry()

local SLOT_W, SLOT_H, GAP, BASE_Y = 156, 66, 6, 120
local COLORS = {
	{ 0.3, 0.8, 1.0 }, { 0.5, 0.6, 1.0 }, { 0.4, 1.0, 0.8 },
	{ 1.0, 0.9, 0.4 }, { 1.0, 0.6, 0.3 }, { 1.0, 0.4, 0.4 },
}

function widget:Initialize()
	for name in pairs(cfg.commanders) do
		local ud = UnitDefNames[name]
		if ud then commanderDefs[ud.id] = true end
	end
end

function widget:ViewResize(x, y) vsx, vsy = x, y end

local function FindCommander()
	for _, u in ipairs(Spring.GetSelectedUnits()) do
		if commanderDefs[Spring.GetUnitDefID(u)] then return u end
	end
end

local function WeaponOn(unitID, slot)
	local idx = Spring.FindUnitCmdDesc(unitID, CMD_BASE + slot - 1)
	if not idx then return true end
	local descs = Spring.GetUnitCmdDescs(unitID, idx, idx)
	local d = descs and descs[1]
	return not (d and d.params and tostring(d.params[1]) == "0")
end

local function Toggle(unitID, slot)
	Spring.GiveOrderToUnit(unitID, CMD_BASE + slot - 1, { WeaponOn(unitID, slot) and 0 or 1 }, {})
end

local function SlotRect(i, n)
	local total = n * (SLOT_W + GAP) - GAP
	local x0 = (vsx - total) / 2 + (i - 1) * (SLOT_W + GAP)
	return x0, BASE_Y, x0 + SLOT_W, BASE_Y + SLOT_H
end

function widget:KeyPress(key, mods)
	if mods.ctrl or mods.alt or mods.meta then return false end
	local unitID = FindCommander()
	if not unitID then return false end
	local _, name = Spring.GetKeySymbol(key)
	name = name and name:lower()
	for slot, k in ipairs(cfg.WEAPON_KEYS) do
		if k == name then Toggle(unitID, slot); return true end
	end
	if name == "f" then   -- Blink toward the mouse cursor
		local mx, my = Spring.GetMouseState()
		local kind, pos = Spring.TraceScreenRay(mx, my, true)
		if kind == "ground" and pos then
			Spring.GiveOrderToUnit(unitID, cfg.CMD_BLINK, { pos[1], pos[2], pos[3] }, {})
		end
		return true
	end
	return false
end

function widget:MousePress(mx, my, button)
	if button ~= 1 then return false end
	local unitID = FindCommander()
	if not unitID then return false end
	local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
	local n = math.min(#ud.weapons, cfg.MAX_WEAPONS)
	for i = 1, n do
		local x1, y1, x2, y2 = SlotRect(i, n)
		if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
			Toggle(unitID, i)
			return true
		end
	end
	return false
end

function widget:DrawScreen()
	local unitID = FindCommander()
	if not unitID then return end
	local ud    = UnitDefs[Spring.GetUnitDefID(unitID)]
	local n     = math.min(#ud.weapons, cfg.MAX_WEAPONS)
	local frame = Spring.GetGameFrame()
	local energy, storage, _, income, expense = Spring.GetTeamResources(Spring.GetMyTeamID(), "energy")
	energy = energy or 0

	-- energy bar
	local ex1, _, ex2 = SlotRect(1, n)
	local _, _, ex2b = SlotRect(n, n)
	local barY = BASE_Y + SLOT_H + 6
	gl.Color(0, 0, 0, 0.6); gl.Rect(ex1, barY, ex2b, barY + 16)
	gl.Color(1.0, 0.85, 0.2, 0.9); gl.Rect(ex1, barY, ex1 + (ex2b - ex1) * math.min(1, energy / math.max(1, storage or 1)), barY + 16)
	gl.Color(1, 1, 1, 1)
	gl.Text(("Energy %d / %d   (+%d / -%d per s)"):format(energy, storage or 0, income or 0, expense or 0), ex1 + 6, barY + 3, 12, "o")

	-- blink cooldown + veteran level
	do
		local ready = Spring.GetUnitRulesParam(unitID, "pw_blink_ready") or 0
		local lv = Spring.GetUnitRulesParam(unitID, "pw_level") or 0
		local txt = (ready > frame) and ("Blink [F] %.1fs"):format((ready - frame) / 30) or "Blink [F] ready"
		if energy < cfg.BLINK_COST and ready <= frame then gl.Color(1, 0.35, 0.35, 1) else gl.Color(0.7, 0.95, 1, 1) end
		gl.Text(txt .. ("   (%d energy)   Veteran level %d"):format(cfg.BLINK_COST, lv), ex1 + 6, barY + 22, 12, "o")
		gl.Color(1, 1, 1, 1)
	end

	for i = 1, n do
		local wd      = WeaponDefs[ud.weapons[i].weaponDef]
		local on      = WeaponOn(unitID, i)
		local cost    = wd.energyCost or 0
		local x1, y1, x2, y2 = SlotRect(i, n)
		local c = COLORS[i]

		gl.Color(0, 0, 0, 0.65); gl.Rect(x1, y1, x2, y2)
		if on then gl.Color(c[1], c[2], c[3], 0.25) else gl.Color(0.4, 0.1, 0.1, 0.35) end
		gl.Rect(x1, y1, x2, y2)

		-- cooldown bar
		local reloadFrames = math.max(1, (wd.reload or 1) * 30)
		local ready = Spring.GetUnitWeaponState(unitID, i, "reloadState") or frame
		local progress = 1 - math.min(1, math.max(0, (ready - frame) / reloadFrames))
		gl.Color(c[1], c[2], c[3], on and 0.9 or 0.25)
		gl.Rect(x1, y1, x1 + (x2 - x1) * progress, y1 + 5)

		-- text
		local label = (wd.description and wd.description ~= "") and wd.description or wd.name
		if on then gl.Color(1, 1, 1, 1) else gl.Color(0.6, 0.6, 0.6, 1) end
		gl.Text(("[%s] %s"):format(cfg.WEAPON_KEYS[i]:upper(), label), x1 + 6, y2 - 17, 13, "o")
		local dmg = ((wd.damages and wd.damages[0]) or 0) * (wd.projectiles or 1)
		gl.Text(("Range %d   Dmg %d"):format(wd.range or 0, dmg), x1 + 6, y2 - 33, 11, "o")
		if energy < cost then gl.Color(1, 0.35, 0.35, 1) end
		gl.Text(("Energy/shot %d   %s"):format(cost, on and "ON" or "OFF"), x1 + 6, y2 - 49, 11, "o")
	end
	gl.Color(1, 1, 1, 1)
end

-- Range rings on the ground for every enabled weapon of the selected commander.
function widget:DrawWorldPreUnit()
	local unitID = FindCommander()
	if not unitID then return end
	local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
	local x, y, z = Spring.GetUnitPosition(unitID)
	gl.LineWidth(1.5)
	for i = 1, math.min(#ud.weapons, cfg.MAX_WEAPONS) do
		if WeaponOn(unitID, i) then
			local c = COLORS[i]
			gl.Color(c[1], c[2], c[3], 0.35)
			gl.DrawGroundCircle(x, y, z, WeaponDefs[ud.weapons[i].weaponDef].range, 48)
		end
	end
	gl.LineWidth(1); gl.Color(1, 1, 1, 1)
end
