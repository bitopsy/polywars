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
	sounds = { select = { "pw_select" }, cant = { "pw_cant" } },
}
local MOBILE = {
	side = "Vanta", category = "LAND NOTAIR", canmove = true, upright = true,
	explodeas = "pw_blast_small", selfdestructas = "pw_blast_small", activatewhenbuilt = true,
	sounds = { select = { "pw_select" }, ok = { "pw_ok" }, cant = { "pw_cant" } },
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
		buildoptions = { "vanta_pylon", "vanta_generator", "vanta_factory", "vanta_siphon", "vanta_turret", "vanta_beacon", "vanta_mast", "vanta_barrier", "vanta_mortar" },
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
		footprintx = 2, footprintz = 2, radardistance = 800, sightdistance = 450, energystorage = 300, energyuse = 20,
	}, STRUCTURE),

	vanta_generator = def({
		script = "vanta_generator.lua",
		name = "Vanta Generator", description = "Energy generator",
		objectname = "vanta_generator.s3o", buildpic = "vanta_generator.png",
		maxdamage = 1100, buildcostmetal = 100, buildcostenergy = 90, buildtime = 1800,
		footprintx = 3, footprintz = 3, energymake = 25, energyuse = 20,
	}, STRUCTURE),

	vanta_siphon = def({
		script = "vanta_siphon.lua",
		name = "Vanta Siphon", description = "Metal siphon: +4 metal/s (metal spot, pylon in range)",
		objectname = "vanta_siphon.s3o", buildpic = "vanta_siphon.png",
		maxdamage = 650, buildcostmetal = 120, buildcostenergy = 170, buildtime = 1500,
		footprintx = 3, footprintz = 3, metalmake = 4, energyuse = 12,
	}, STRUCTURE),

	vanta_factory = def({
		script = "vanta_factory.lua",
		name = "Vanta Weapon Factory", description = "Builds combat units (metal spots only)",
		objectname = "vanta_factory.s3o", buildpic = "vanta_factory.png",
		maxdamage = 3400, buildcostmetal = 420, buildcostenergy = 650, buildtime = 5000,
		footprintx = 4, footprintz = 4, yardmap = string.rep("o", 16), isfactory = true, builder = true, workertime = 120, buildspeed = 120, metalmake = 2, energyuse = 40,
		buildoptions = { "vanta_gunner", "vanta_howitzer", "vanta_heavy", "vanta_raider", "vanta_bruiser", "vanta_constructor" },
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
		objectname = "vanta_heavy.s3o", buildpic = "vanta_heavy.png",
		maxdamage = 4000, buildcostmetal = 420, buildcostenergy = 500, buildtime = 6500,
		footprintx = 3, footprintz = 3, movementclass = "TANK3",
		maxvelocity = 1.2, acceleration = 0.08, brakerate = 0.3, turnrate = 600, sightdistance = 480,
		weapons = { { name = "vanta_unit_juggernaut" } },
	}, MOBILE),

	vanta_turret = def({
		script = "vanta_turret.lua",
		name = "Bastion", description = "Pylon-powered autocannon turret",
		objectname = "vanta_turret.s3o", buildpic = "vanta_turret.png",
		maxdamage = 1700, buildcostmetal = 130, buildcostenergy = 170, buildtime = 1800,
		footprintx = 2, footprintz = 2, sightdistance = 480, energyuse = 28,
		weapons = { { name = "vanta_turret_gun" } },
	}, STRUCTURE),

	vanta_beacon = def({
		script = "vanta_beacon.lua", name = "Repair Beacon", description = "Pylon-powered: repairs friendly units and buildings nearby",
		objectname = "vanta_beacon.s3o", buildpic = "vanta_beacon.png",
		maxdamage = 900, buildcostmetal = 90, buildcostenergy = 140, buildtime = 1600,
		footprintx = 2, footprintz = 2, sightdistance = 350, energyuse = 15,
	}, STRUCTURE),

	vanta_mast = def({
		script = "vanta_mast.lua", name = "Sensor Mast", description = "Pylon-powered: long-range vision and radar",
		objectname = "vanta_mast.s3o", buildpic = "vanta_mast.png",
		maxdamage = 600, buildcostmetal = 55, buildcostenergy = 100, buildtime = 1200,
		footprintx = 2, footprintz = 2, sightdistance = 750, radardistance = 1500, energyuse = 18,
	}, STRUCTURE),

	vanta_barrier = def({
		script = "vanta_barrier.lua", name = "Barrier", description = "Cheap armoured wall: shape the battlefield",
		objectname = "vanta_barrier.s3o", buildpic = "vanta_barrier.png",
		maxdamage = 4000, buildcostmetal = 30, buildcostenergy = 15, buildtime = 350,
		footprintx = 3, footprintz = 1, sightdistance = 100, energyuse = 10,
	}, STRUCTURE),

	vanta_mortar = def({
		script = "vanta_mortar.lua", name = "Mortar Battery", description = "Pylon-powered long-range artillery",
		objectname = "vanta_mortar.s3o", buildpic = "vanta_mortar.png",
		maxdamage = 1900, buildcostmetal = 250, buildcostenergy = 330, buildtime = 4200,
		footprintx = 2, footprintz = 2, sightdistance = 450, energyuse = 35,
		weapons = { { name = "vanta_turret_mortar" } },
	}, STRUCTURE),

	vanta_raider = def({
		script = "vanta_raider.lua", name = "Raider", description = "Fast harasser with a spraying SMG",
		objectname = "vanta_raider.s3o", buildpic = "vanta_raider.png",
		maxdamage = 380, buildcostmetal = 45, buildcostenergy = 50, buildtime = 600,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 4.6, acceleration = 0.45, brakerate = 0.8, turnrate = 1600, sightdistance = 600,
		weapons = { { name = "vanta_unit_raider" } },
	}, MOBILE),

	vanta_bruiser = def({
		script = "vanta_bruiser.lua", name = "Bruiser", description = "Tough close-range brawler with a scattergun",
		objectname = "vanta_bruiser.s3o", buildpic = "vanta_bruiser.png",
		maxdamage = 1300, buildcostmetal = 130, buildcostenergy = 140, buildtime = 2600,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 2.0, acceleration = 0.22, brakerate = 0.5, turnrate = 1000, sightdistance = 420,
		weapons = { { name = "vanta_unit_bruiser" } },
	}, MOBILE),

	vanta_constructor = def({
		script = "vanta_constructor.lua", name = "Constructor", description = "Mobile builder: expand without risking the commander",
		objectname = "vanta_constructor.s3o", buildpic = "vanta_constructor.png",
		maxdamage = 900, buildcostmetal = 85, buildcostenergy = 100, buildtime = 2000,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 2.4, acceleration = 0.28, brakerate = 0.6, turnrate = 1100, sightdistance = 380,
		builder = true, workertime = 120, buildspeed = 120, builddistance = 150,
		buildoptions = { "vanta_pylon", "vanta_generator", "vanta_siphon", "vanta_turret", "vanta_beacon", "vanta_mast", "vanta_barrier", "vanta_mortar" },
	}, MOBILE),
}
