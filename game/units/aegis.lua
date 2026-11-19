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
}
local MOBILE = {
	side = "Aegis", category = "LAND NOTAIR", canmove = true, upright = true,
	explodeas = "pw_blast_small", selfdestructas = "pw_blast_small", activatewhenbuilt = true,
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
		buildoptions = { "aegis_pylon", "aegis_generator", "aegis_factory" },
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
		footprintx = 2, footprintz = 2, radardistance = 900, energystorage = 300,
	}, STRUCTURE),

	aegis_generator = def({
		script = "aegis_generator.lua",
		name = "Aegis Generator", description = "Energy generator",
		objectname = "aegis_generator.s3o", buildpic = "aegis_generator.png",
		maxdamage = 900, buildcostmetal = 90, buildcostenergy = 100, buildtime = 1800,
		footprintx = 3, footprintz = 3, energymake = 45,
	}, STRUCTURE),

	aegis_factory = def({
		script = "aegis_factory.lua",
		name = "Aegis Weapon Factory", description = "Builds combat units (metal spots only)",
		objectname = "aegis_factory.s3o", buildpic = "aegis_factory.png",
		maxdamage = 2800, buildcostmetal = 400, buildcostenergy = 700, buildtime = 5000,
		footprintx = 5, footprintz = 5, yardmap = string.rep("o", 25), isfactory = true, builder = true, workertime = 120, buildspeed = 120, metalmake = 2,
		buildoptions = { "aegis_skirmisher", "aegis_prism" },
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
}
