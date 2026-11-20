-- polywars: game archive description (read by the Spring engine / lobbies).
return {
	name        = "polywars",
	shortName   = "PW",
	game        = "polywars",
	shortGame   = "PW",
	version     = "0.6.1",
	description = "Commander-centric RTS/MMO hybrid: micro your commander, wire pylons to power, claim metal spots.",
	modtype     = 1,
	author      = "goddot",
	-- No external dependencies: everything the game needs ships in this archive
	-- (plus the always-loaded springcontent).
	depend      = {},
}
