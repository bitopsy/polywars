function gadget:GetInfo()
	return {
		name    = "PW Skirmish Bot",
		desc    = "Simple built-in opponent: pylon -> generator -> factory on a metal spot, then mass units and attack",
		author  = "Pylon Wars",
		date    = "2026",
		license = "GPL v2 or later",
		layer   = 5,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

-- Controls every team whose controller is an AI (e.g. a NullAI slot in the lobby / start script).
-- Disable with the mod option  pwbot = 0.
if tonumber((Spring.GetModOptions() or {}).pwbot or 1) == 0 then return end

local cfg       = VFS.Include("LuaRules/Headers/pw_config.lua")
local placement = VFS.Include("LuaRules/Headers/pw_placement.lua")
local CMD_FIGHT = CMD.FIGHT
local sq        = cfg.METAL_SQUARE
local bots      = {}

local function Def(prefix, kind) return UnitDefNames[prefix .. "_" .. kind] end

local function Dist2(ax, az, bx, bz) return (ax - bx) ^ 2 + (az - bz) ^ 2 end

-- nearest metal spot (centroid of the metal cells around the nearest metal cell)
local function FindSpot(cx, cz, taken)
	local fb = placement.FallbackSpots()
	if fb then   -- configured plaza spots (works even if the compiled metal map is empty)
		local bestD, bx, bz = math.huge
		for _, sp in ipairs(fb) do
			local free = true
			for _, t in ipairs(taken) do if Dist2(sp[1], sp[2], t[1], t[2]) < 150 ^ 2 then free = false end end
			local d = Dist2(sp[1], sp[2], cx, cz)
			if free and d < bestD then bestD, bx, bz = d, sp[1], sp[2] end
		end
		if bx then return bx, bz end
	end
	local bestD, bx, bz = math.huge
	for z = 0, Game.mapSizeZ - sq, sq do
		for x = 0, Game.mapSizeX - sq, sq do
			if (Spring.GetMetalAmount(x / sq, z / sq) or 0) > 0 then
				local d = Dist2(x, z, cx, cz)
				local free = true
				for _, t in ipairs(taken) do if Dist2(x, z, t[1], t[2]) < 150 ^ 2 then free = false end end
				if free and d < bestD then bestD, bx, bz = d, x, z end
			end
		end
	end
	if not bx then return end
	local sx, sz, n = 0, 0, 0
	for z = bz - 96, bz + 96, sq do
		for x = bx - 96, bx + 96, sq do
			if (Spring.GetMetalAmount(x / sq, z / sq) or 0) > 0 and Dist2(x, z, bx, bz) < 96 ^ 2 then
				sx, sz, n = sx + x, sz + z, n + 1
			end
		end
	end
	return sx / n + sq / 2, sz / n + sq / 2
end

-- spiral search for a free build position around (x,z), keeping clear of the metal spot centre
local function FindPos(defID, x, z, minR, maxR, avoidX, avoidZ)
	for r = minR, maxR, 24 do
		for a = 0, 7 do
			local ang = a * math.pi / 4
			local px, pz = x + r * math.cos(ang), z + r * math.sin(ang)
			px, pz = 16 * math.floor(px / 16 + 0.5), 16 * math.floor(pz / 16 + 0.5)
			if Dist2(px, pz, avoidX, avoidZ) > 110 ^ 2
			   and (Spring.TestBuildOrder(defID, px, 0, pz, 0) or 0) >= 2 then
				return px, pz
			end
		end
	end
end

local function CountNear(teamID, defID, x, z, r, finishedOnly)
	local n = 0
	for _, u in ipairs(Spring.GetUnitsInCylinder(x, z, r, teamID)) do
		if Spring.GetUnitDefID(u) == defID and (not finishedOnly or not Spring.GetUnitIsBeingBuilt(u)) then
			n = n + 1
		end
	end
	return n
end

local function Build(cmdr, defID, x, z)
	Spring.GiveOrderToUnit(cmdr, -defID, { x, Spring.GetGroundHeight(x, z), z, 0 }, {})
end

local function Think(teamID, b)
	local prefix = b.prefix
	local cmdrDef, pylon, gen, fac = Def(prefix, "commander"), Def(prefix, "pylon"), Def(prefix, "generator"), Def(prefix, "factory")
	local cmdrs = Spring.GetTeamUnitsByDefs(teamID, { cmdrDef.id })
	local cmdr = cmdrs[1]
	if not cmdr then return end
	local cx, _, cz = Spring.GetUnitPosition(cmdr)

	b.home = b.home or { cx, cz }
	local hp, maxhp = Spring.GetUnitHealth(cmdr)
	if hp and maxhp and hp < 0.35 * maxhp then
		local myAlly = Spring.GetUnitAllyTeam(cmdr)
		for _, u in ipairs(Spring.GetUnitsInCylinder(cx, cz, 450)) do
			if Spring.GetUnitAllyTeam(u) ~= myAlly and #UnitDefs[Spring.GetUnitDefID(u)].weapons > 0 then
				Spring.GiveOrderToUnit(cmdr, cfg.CMD_BLINK, { b.home[1], Spring.GetGroundHeight(b.home[1], b.home[2]), b.home[2] }, {})
				break
			end
		end
	end

	if not b.spot then
		local sx, sz = FindSpot(cx, cz, {})
		if not sx then return end
		b.spot = { sx, sz }
	end
	local sx, sz = b.spot[1], b.spot[2]

	-- 1) economy / base building, only when the commander has nothing queued
	if (Spring.GetUnitCommands(cmdr, 0) or 0) == 0 then
		local nGen = CountNear(teamID, gen.id, sx, sz, 450)
		if CountNear(teamID, pylon.id, sx, sz, cfg.PYLON_RANGE - 20) == 0 then
			local x, z = FindPos(pylon.id, sx, sz, 150, 280, sx, sz)
			if x then Build(cmdr, pylon.id, x, z) end
		elseif nGen < 1 then
			local px, pz = sx, sz
			local ps = Spring.GetUnitsInCylinder(sx, sz, cfg.PYLON_RANGE, teamID)
			for _, u in ipairs(ps) do
				if Spring.GetUnitDefID(u) == pylon.id then px, _, pz = Spring.GetUnitPosition(u) break end
			end
			local x, z = FindPos(gen.id, px, pz, 70, 170, sx, sz)
			if x then Build(cmdr, gen.id, x, z) end
		elseif CountNear(teamID, fac.id, sx, sz, 100) == 0 then
			if placement.CanPlaceFactory(teamID, sx, sz) then Build(cmdr, fac.id, sx, sz) end
		elseif nGen < 3 then
			local x, z = FindPos(gen.id, sx, sz, 150, 300, sx, sz)
			if x then Build(cmdr, gen.id, x, z) end
		else
			-- expansion: pylon + metal siphon on further metal spots (max 3)
			local sip = Def(prefix, "siphon")
			local tur = Def(prefix, "turret")
			b.taken = b.taken or { { sx, sz } }
			-- one defensive turret per claimed spot
			for _, sp in ipairs(b.taken) do
				if CountNear(teamID, tur.id, sp[1], sp[2], 220) == 0
				   and (sp == b.taken[1] or CountNear(teamID, sip.id, sp[1], sp[2], 100, true) > 0) then
					local x, z = FindPos(tur.id, sp[1], sp[2], 90, 200, sp[1], sp[2])
					if x and placement.CanPlaceTurret(teamID, x, z) then Build(cmdr, tur.id, x, z); return end
				end
			end
			if not b.cur and #b.taken < 4 then
				local ex, ez = FindSpot(sx, sz, b.taken)
				if ex then b.cur = { ex, ez } end
			end
			if b.cur then
				local ex, ez = b.cur[1], b.cur[2]
				if CountNear(teamID, sip.id, ex, ez, 100) > 0 or b.tries and b.tries > 4 then
					b.taken[#b.taken + 1] = b.cur; b.cur, b.tries = nil, nil
				elseif CountNear(teamID, pylon.id, ex, ez, cfg.PYLON_RANGE - 20, true) == 0 then
					local x, z = FindPos(pylon.id, ex, ez, 150, 280, ex, ez)
					b.tries = (b.tries or 0) + 1
					if x then Build(cmdr, pylon.id, x, z) end
				elseif placement.CanPlaceSiphon(teamID, ex, ez) then
					Build(cmdr, sip.id, ex, ez)
				else
					b.tries = (b.tries or 0) + 1
				end
			end
		end
	end

	-- 2) keep the factory producing
	for _, f in ipairs(Spring.GetTeamUnitsByDefs(teamID, { fac.id })) do
		if not Spring.GetUnitIsBeingBuilt(f) and (Spring.GetUnitCommands(f, 0) or 0) < 2 then
			local opts = UnitDefs[fac.id].buildOptions
			b.n = ((b.n or 0) % #opts) + 1
			local pick = UnitDefs[opts[b.n]]
			if pick then Spring.GiveOrderToUnit(f, -pick.id, {}, {}) end
		end
	end
end

local function Attack(teamID, b)
	local myAlly = select(6, Spring.GetTeamInfo(teamID))
	local army, idle = 0, {}
	for _, u in ipairs(Spring.GetTeamUnits(teamID)) do
		local ud = UnitDefs[Spring.GetUnitDefID(u)]
		if ud.canMove and not ud.isBuilder and not Spring.GetUnitIsBeingBuilt(u) then
			army = army + 1
			if (Spring.GetUnitCommands(u, 0) or 0) == 0 then idle[#idle + 1] = u end
		end
	end
	if army < 5 or #idle == 0 then return end
	local tx, tz
	for _, t in ipairs(Spring.GetTeamList()) do
		local ally = select(6, Spring.GetTeamInfo(t))
		if ally ~= myAlly and t ~= Spring.GetGaiaTeamID() then
			local found = Spring.GetTeamUnitsByDefs(t, { UnitDefNames.aegis_commander.id, UnitDefNames.vanta_commander.id })
			local target = found[1] or Spring.GetTeamUnits(t)[1]
			if target then local x, _, z = Spring.GetUnitPosition(target); tx, tz = x, z break end
		end
	end
	if not tx then return end
	for _, u in ipairs(idle) do
		Spring.GiveOrderToUnit(u, CMD_FIGHT, { tx, Spring.GetGroundHeight(tx, tz), tz }, {})
	end
end

function gadget:GameStart()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= Spring.GetGaiaTeamID() and select(4, Spring.GetTeamInfo(teamID)) then
			local side = select(5, Spring.GetTeamInfo(teamID))
			local prefix = ((type(side) == "string" and side or ""):lower())
			if not UnitDefNames[prefix .. "_commander"] then prefix = (teamID % 2 == 0) and "aegis" or "vanta" end
			bots[teamID] = { prefix = prefix }
		end
	end
end

function gadget:GameFrame(frame)
	if frame % 30 == 10 then
		for teamID, b in pairs(bots) do Think(teamID, b) end
	end
	if frame % 120 == 50 then
		for teamID, b in pairs(bots) do Attack(teamID, b) end
	end
end
