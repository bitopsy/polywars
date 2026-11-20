-- AEGIS: precision / energy faction (blue).
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
	side = "Aegis", category = "STRUCTURE NOTAIR", canmove = false, upright = true,
	explodeas = "pw_blast_medium", selfdestructas = "pw_blast_medium",
	maxvelocity = 0, sightdistance = 300, activatewhenbuilt = true,
	sounds = { select = { "pw_select" }, cant = { "pw_cant" } },
}
local MOBILE = {
	side = "Aegis", category = "LAND NOTAIR", canmove = true, upright = true,
	explodeas = "pw_blast_small", selfdestructas = "pw_blast_small", activatewhenbuilt = true,
	sounds = { select = { "pw_select" }, ok = { "pw_ok" }, cant = { "pw_cant" } },
}

return {
	aegis_commander = def({
		script = "aegis_commander.lua",
		explodeas = "pw_blast_large", selfdestructas = "pw_blast_large",
		name = "Aegis Commander", description = "Precision energy duelist",
		objectname = "aegis_commander.s3o", buildpic = "aegis_commander.png",
		maxdamage = 3800, buildcostmetal = 2500, buildcostenergy = 25000, buildtime = 30000,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 2.3, acceleration = 0.22, brakerate = 0.5, turnrate = 1100,
		sightdistance = 520,
		builder = true, workertime = 200, buildspeed = 200, builddistance = 170, canreclaim = true, canrepair = true,
		buildoptions = { "aegis_pylon", "aegis_generator", "aegis_factory", "aegis_siphon", "aegis_turret", "aegis_beacon", "aegis_mast", "aegis_barrier", "aegis_obelisk" },
		energymake = 25, metalmake = 3, energystorage = 1500, metalstorage = 500,
		-- slot order == hotkey order (Z X C V B N)
		weapons = {
			{ name = "aegis_pistol" }, { name = "aegis_arc" }, { name = "aegis_scatter" },
			{ name = "aegis_rail" },   { name = "aegis_mortar" }, { name = "aegis_nova" },
		},
	}, MOBILE),

	aegis_pylon = def({
		script = "aegis_pylon.lua",
		name = "Aegis Pylon", description = "Power-network node: unlocks weapon factories nearby",
		objectname = "aegis_pylon.s3o", buildpic = "aegis_pylon.png",
		maxdamage = 700, buildcostmetal = 60, buildcostenergy = 180, buildtime = 1200,
		footprintx = 2, footprintz = 2, radardistance = 900, sightdistance = 450, energystorage = 300, energyuse = 20,
	}, STRUCTURE),

	aegis_generator = def({
		script = "aegis_generator.lua",
		name = "Aegis Generator", description = "Energy generator",
		objectname = "aegis_generator.s3o", buildpic = "aegis_generator.png",
		maxdamage = 900, buildcostmetal = 90, buildcostenergy = 100, buildtime = 1800,
		footprintx = 3, footprintz = 3, energymake = 56,
	}, STRUCTURE),

	aegis_siphon = def({
		script = "aegis_siphon.lua",
		name = "Aegis Siphon", description = "Metal siphon: +4 metal/s (metal spot, pylon in range)",
		objectname = "aegis_siphon.s3o", buildpic = "aegis_siphon.png",
		maxdamage = 650, buildcostmetal = 110, buildcostenergy = 160, buildtime = 1500,
		footprintx = 3, footprintz = 3, metalmake = 4, energyuse = 12,
	}, STRUCTURE),

	aegis_factory = def({
		script = "aegis_factory.lua",
		name = "Aegis Weapon Factory", description = "Builds combat units (metal spots only)",
		objectname = "aegis_factory.s3o", buildpic = "aegis_factory.png",
		maxdamage = 2800, buildcostmetal = 400, buildcostenergy = 700, buildtime = 5000,
		footprintx = 4, footprintz = 4, yardmap = string.rep("o", 16), isfactory = true, builder = true, workertime = 120, buildspeed = 120, metalmake = 2, energyuse = 40,
		buildoptions = { "aegis_skirmisher", "aegis_prism", "aegis_heavy", "aegis_scout", "aegis_striker", "aegis_constructor" },
	}, STRUCTURE),

	aegis_skirmisher = def({
		script = "aegis_skirmisher.lua",
		name = "Skirmisher", description = "Fast laser raider",
		objectname = "aegis_skirmisher.s3o", buildpic = "aegis_skirmisher.png",
		maxdamage = 520, buildcostmetal = 70, buildcostenergy = 140, buildtime = 1500,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 3.4, acceleration = 0.35, brakerate = 0.6, turnrate = 1400, sightdistance = 450,
		weapons = { { name = "aegis_unit_laser" } },
	}, MOBILE),

	aegis_prism = def({
		script = "aegis_prism.lua",
		name = "Prism Tank", description = "Slow tank with a long-range lance",
		objectname = "aegis_prism.s3o", buildpic = "aegis_prism.png",
		maxdamage = 1400, buildcostmetal = 220, buildcostenergy = 300, buildtime = 3500,
		footprintx = 3, footprintz = 3, movementclass = "TANK3",
		maxvelocity = 1.7, acceleration = 0.1, brakerate = 0.3, turnrate = 700, sightdistance = 520,
		weapons = { { name = "aegis_unit_beam" } },
	}, MOBILE),

	aegis_heavy = def({
		script = "aegis_heavy.lua",
		name = "Warden", description = "Heavy beam walker",
		objectname = "aegis_heavy.s3o", buildpic = "aegis_heavy.png",
		maxdamage = 3000, buildcostmetal = 400, buildcostenergy = 540, buildtime = 6000,
		footprintx = 3, footprintz = 3, movementclass = "TANK3",
		maxvelocity = 1.3, acceleration = 0.08, brakerate = 0.3, turnrate = 600, sightdistance = 480,
		weapons = { { name = "aegis_unit_warden" } },
	}, MOBILE),

	aegis_turret = def({
		script = "aegis_turret.lua",
		name = "Sentry", description = "Pylon-powered laser turret",
		objectname = "aegis_turret.s3o", buildpic = "aegis_turret.png",
		maxdamage = 1200, buildcostmetal = 120, buildcostenergy = 200, buildtime = 1800,
		footprintx = 2, footprintz = 2, sightdistance = 480, energyuse = 25,
		weapons = { { name = "aegis_turret_laser" } },
	}, STRUCTURE),

	aegis_beacon = def({
		script = "aegis_beacon.lua", name = "Repair Beacon", description = "Pylon-powered: repairs friendly units and buildings nearby",
		objectname = "aegis_beacon.s3o", buildpic = "aegis_beacon.png",
		maxdamage = 700, buildcostmetal = 80, buildcostenergy = 160, buildtime = 1600,
		footprintx = 2, footprintz = 2, sightdistance = 350, energyuse = 15,
	}, STRUCTURE),

	aegis_mast = def({
		script = "aegis_mast.lua", name = "Sensor Mast", description = "Pylon-powered: long-range vision and radar",
		objectname = "aegis_mast.s3o", buildpic = "aegis_mast.png",
		maxdamage = 450, buildcostmetal = 50, buildcostenergy = 120, buildtime = 1200,
		footprintx = 2, footprintz = 2, sightdistance = 800, radardistance = 1700, energyuse = 18,
	}, STRUCTURE),

	aegis_barrier = def({
		script = "aegis_barrier.lua", name = "Barrier", description = "Cheap armoured wall: shape the battlefield",
		objectname = "aegis_barrier.s3o", buildpic = "aegis_barrier.png",
		maxdamage = 3000, buildcostmetal = 25, buildcostenergy = 20, buildtime = 350,
		footprintx = 3, footprintz = 1, sightdistance = 100, energyuse = 10,
	}, STRUCTURE),

	aegis_obelisk = def({
		script = "aegis_obelisk.lua", name = "Obelisk", description = "Pylon-powered long-range beam tower",
		objectname = "aegis_obelisk.s3o", buildpic = "aegis_obelisk.png",
		maxdamage = 1500, buildcostmetal = 260, buildcostenergy = 420, buildtime = 4200,
		footprintx = 2, footprintz = 2, sightdistance = 500, energyuse = 30,
		weapons = { { name = "aegis_turret_obelisk" } },
	}, STRUCTURE),

	aegis_scout = def({
		script = "aegis_scout.lua", name = "Scout", description = "Very fast, fragile spotter with a light laser",
		objectname = "aegis_scout.s3o", buildpic = "aegis_scout.png",
		maxdamage = 300, buildcostmetal = 45, buildcostenergy = 60, buildtime = 600,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 5.0, acceleration = 0.5, brakerate = 0.8, turnrate = 1800, sightdistance = 700,
		weapons = { { name = "aegis_unit_scout" } },
	}, MOBILE),

	aegis_striker = def({
		script = "aegis_striker.lua", name = "Striker", description = "Mid-weight laser walker, the backbone of an army",
		objectname = "aegis_striker.s3o", buildpic = "aegis_striker.png",
		maxdamage = 900, buildcostmetal = 120, buildcostenergy = 180, buildtime = 2600,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 2.4, acceleration = 0.25, brakerate = 0.5, turnrate = 1100, sightdistance = 470,
		weapons = { { name = "aegis_unit_striker" } },
	}, MOBILE),

	aegis_constructor = def({
		script = "aegis_constructor.lua", name = "Constructor", description = "Mobile builder: expand without risking the commander",
		objectname = "aegis_constructor.s3o", buildpic = "aegis_constructor.png",
		maxdamage = 700, buildcostmetal = 80, buildcostenergy = 120, buildtime = 2000,
		footprintx = 2, footprintz = 2, movementclass = "KBOT2",
		maxvelocity = 2.6, acceleration = 0.3, brakerate = 0.6, turnrate = 1200, sightdistance = 400,
		builder = true, workertime = 120, buildspeed = 120, builddistance = 150,
		buildoptions = { "aegis_pylon", "aegis_generator", "aegis_siphon", "aegis_turret", "aegis_beacon", "aegis_mast", "aegis_barrier", "aegis_obelisk" },
	}, MOBILE),
}
