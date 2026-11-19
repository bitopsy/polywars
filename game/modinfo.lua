-- Pylon Wars: game archive description (read by the Spring engine / lobbies).
return {
	name        = "Pylon Wars",
	shortName   = "PW",
	game        = "Pylon Wars",
	shortGame   = "PW",
	version     = "0.3.2",
	description = "Commander-centric RTS/MMO hybrid: micro your commander, wire pylons to power, claim metal spots.",
	modtype     = 1,
	-- No external dependencies: everything the game needs ships in this archive
	-- (plus the always-loaded springcontent).
	depend      = {},
}
