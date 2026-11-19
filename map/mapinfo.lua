-- Pylon City: compact city-grid duel map (2048 x 2048 elmos).
-- Streets are walkable lowlands, building blocks are raised walls, 12 plazas carry metal spots.
-- Numbers marked (gen_map.py) must match tools/gen_map.py.
local mapinfo = {
	name        = "Pylon City",
	shortname   = "PylonCity",
	description = "City-grid duel. 12 metal spots in open plazas; Aegis starts west, Vanta east.",
	author      = "Pylon Wars",
	version     = "1.0",
	modtype     = 3,
	mapfile     = "maps/PylonCity.smf",

	maphardness    = 100,
	notDeformable  = true,
	gravity        = 130,
	tidalStrength  = 0,
	maxMetal       = 2.0,
	extractorRadius = 60,
	voidWater      = false,

	smf = {
		minheight    = 0,      -- MIN_H (gen_map.py)
		maxheight    = 130,    -- MAX_H (gen_map.py)
		smtFileName0 = "PylonCity.smt",
	},

	atmosphere = {
		minWind = 0, maxWind = 0,
		fogStart = 0.9, fogEnd = 1.0, fogColor = { 0.50, 0.55, 0.62 },
		skyColor = { 0.45, 0.55, 0.72 }, sunColor = { 1.0, 1.0, 0.95 },
		cloudColor = { 0.9, 0.9, 0.9 }, cloudDensity = 0.5,
	},

	lighting = {
		sunDir = { 0.5, 1.0, 0.3 },
		groundAmbientColor  = { 0.55, 0.55, 0.58 }, groundDiffuseColor  = { 0.80, 0.80, 0.78 },
		groundSpecularColor = { 0.10, 0.10, 0.10 },
		unitAmbientColor    = { 0.50, 0.50, 0.52 }, unitDiffuseColor    = { 0.90, 0.90, 0.88 },
		unitSpecularColor   = { 0.50, 0.50, 0.50 }, specularExponent = 100,
	},

	teams = {
		[0] = { startPos = { x = 256,  z = 1024 } },   -- Aegis (west)
		[1] = { startPos = { x = 1792, z = 1024 } },   -- Vanta (east)
	},

	terrainTypes = {
		[0] = { name = "Asphalt", hardness = 1, receiveTracks = false,
		        moveSpeeds = { tank = 1, kbot = 1, hover = 1, ship = 1 } },
	},
}

return mapinfo
