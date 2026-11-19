-- VANTA: kinetic / burst faction (red). Shorter reach, tougher, cheaper energy.
local function def(t, base)
	for k, v in pairs(base) do if t[k] == nil then t[k] = v end end
	-- Structures need a yardmap: without one the engine does not treat them as buildings
	-- (units walk through them and factories are not recognised as factories).
	if t.canmove == false and not t.yardmap then
		t.yardmap = string.rep("o", (t.footprintx or 2) * (t.footprintz or 2))
	end
	return t
end

local STRUCTURE = {
	side = "Vanta", category = "STRUCTURE NOTAIR", canmove = false, upright = true,
	explodeas = "pw_blast_medium", selfdestructas = "pw_blast_medium",
	maxvelocity = 0, sightdistance = 300, activatewhenbuilt = true,
}
local MOBILE = {
	side = "Vanta", category = "LAND NOTAIR", canmove = true, upright = true,
	explodeas = "pw_blast_small", selfdestructas = "pw_blast_small", activatewhenbuilt = true,
}

return {
	vanta_commander = def({
		script = "vanta_commander.lua",
		explodeas = "pw_blast_large", selfdestructas = "pw_blast_large",
		name = "Vanta Commander", description = "Kinetic bruiser",
		objectname = "vanta_commander.s3o", buildpic = "vanta_commander.png",
		maxdamage = 4600, buildcostmetal = 2500, buildcostenergy = 25000, buildtime = 30000,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 1.9, acceleration = 0.18, brakerate = 0.45, turnrate = 950,
		sightdistance = 480,
		builder = true, workertime = 200, buildspeed = 200, builddistance = 170, canreclaim = true, canrepair = true,
		buildoptions = { "vanta_pylon", "vanta_generator", "vanta_factory", "vanta_siphon", "vanta_turret" },
		energymake = 25, metalmake = 3, energystorage = 1500, metalstorage = 500,
		weapons = {
			{ name = "vanta_rivet" }, { name = "vanta_breach" }, { name = "vanta_hail" },
			{ name = "vanta_gauss" }, { name = "vanta_mortar" }, { name = "vanta_slam" },
		},
	}, MOBILE),

	vanta_pylon = def({
		script = "vanta_pylon.lua",
		name = "Vanta Pylon", description = "Power-network node: unlocks weapon factories nearby",
		objectname = "vanta_pylon.s3o", buildpic = "vanta_pylon.png",
		maxdamage = 900, buildcostmetal = 70, buildcostenergy = 160, buildtime = 1200,
		footprintx = 2, footprintz = 2, radardistance = 800, energystorage = 300,
	}, STRUCTURE),

	vanta_generator = def({
		script = "vanta_generator.lua",
		name = "Vanta Generator", description = "Energy generator",
		objectname = "vanta_generator.s3o", buildpic = "vanta_generator.png",
		maxdamage = 1100, buildcostmetal = 100, buildcostenergy = 90, buildtime = 1800,
		footprintx = 3, footprintz = 3, energymake = 40,
	}, STRUCTURE),

	vanta_siphon = def({
		script = "vanta_siphon.lua",
		name = "Vanta Siphon", description = "Metal siphon: +4 metal/s (metal spot, pylon in range)",
		objectname = "vanta_generator.s3o", buildpic = "vanta_generator.png",
		maxdamage = 650, buildcostmetal = 120, buildcostenergy = 170, buildtime = 1500,
		footprintx = 3, footprintz = 3, metalmake = 4,
	}, STRUCTURE),

	vanta_factory = def({
		script = "vanta_factory.lua",
		name = "Vanta Weapon Factory", description = "Builds combat units (metal spots only)",
		objectname = "vanta_factory.s3o", buildpic = "vanta_factory.png",
		maxdamage = 3400, buildcostmetal = 420, buildcostenergy = 650, buildtime = 5000,
		footprintx = 4, footprintz = 4, yardmap = string.rep("o", 16), isfactory = true, builder = true, workertime = 120, buildspeed = 120, metalmake = 2,
		buildoptions = { "vanta_gunner", "vanta_howitzer", "vanta_heavy" },
	}, STRUCTURE),

	vanta_gunner = def({
		script = "vanta_gunner.lua",
		name = "Gunner", description = "Autocannon trooper",
		objectname = "vanta_gunner.s3o", buildpic = "vanta_gunner.png",
		maxdamage = 650, buildcostmetal = 75, buildcostenergy = 110, buildtime = 1500,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 3.0, acceleration = 0.3, brakerate = 0.55, turnrate = 1300, sightdistance = 430,
		weapons = { { name = "vanta_unit_gun" } },
	}, MOBILE),

	vanta_howitzer = def({
		script = "vanta_howitzer.lua",
		name = "Howitzer", description = "Slow artillery tank",
		objectname = "vanta_howitzer.s3o", buildpic = "vanta_howitzer.png",
		maxdamage = 800, buildcostmetal = 200, buildcostenergy = 260, buildtime = 3500,
		footprintx = 3, footprintz = 3, movementclass = "TANK3",
		maxvelocity = 1.5, acceleration = 0.09, brakerate = 0.3, turnrate = 650, sightdistance = 500,
		weapons = { { name = "vanta_unit_howitzer" } },
	}, MOBILE),

	vanta_heavy = def({
		script = "vanta_heavy.lua",
		name = "Juggernaut", description = "Armoured autocannon walker",
		objectname = "vanta_howitzer.s3o", buildpic = "vanta_howitzer.png",
		maxdamage = 4000, buildcostmetal = 420, buildcostenergy = 500, buildtime = 6500,
		footprintx = 3, footprintz = 3, movementclass = "TANK3",
		maxvelocity = 1.2, acceleration = 0.08, brakerate = 0.3, turnrate = 600, sightdistance = 480,
		weapons = { { name = "vanta_unit_juggernaut" } },
	}, MOBILE),

	vanta_turret = def({
		script = "vanta_turret.lua",
		name = "Bastion", description = "Pylon-powered autocannon turret",
		objectname = "vanta_pylon.s3o", buildpic = "vanta_pylon.png",
		maxdamage = 1700, buildcostmetal = 130, buildcostenergy = 170, buildtime = 1800,
		footprintx = 2, footprintz = 2, sightdistance = 480,
		weapons = { { name = "vanta_turret_gun" } },
	}, STRUCTURE),
}
