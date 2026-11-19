-- Shared constants. Included by synced gadgets AND unsynced widgets so that both
-- sides always agree on the rules (single source of truth).
return {
	-- Commander weapon toggles: slot i uses command id CMD_WEAPON_BASE + i - 1
	CMD_WEAPON_BASE  = 36000,
	MAX_WEAPONS      = 6,
	WEAPON_KEYS      = { "z", "x", "c", "v", "b", "n" },   -- HUD hotkeys for slots 1..6

	-- Weapon factory placement rules
	PYLON_RANGE      = 320,  -- a FINISHED pylon must be within this distance of the factory spot
	POWER_LINK_RANGE = 220,  -- ...and a FINISHED generator must be within this distance of that pylon
	METAL_SQUARE     = 16,   -- metal map resolution in elmos

	-- Commander blink (dash): custom command, ground target
	CMD_BLINK        = 36100,
	BLINK_RANGE      = 320,   -- max jump distance (elmos)
	BLINK_COST       = 100,   -- energy
	BLINK_COOLDOWN   = 270,   -- sim frames (9 s)

	-- Veterancy: xp = damage dealt + 2 x metal cost of kills; thresholds for levels 1..4
	XP_LEVELS        = { 2000, 6000, 14000, 28000 },
	XP_HEALTH_PER_LV = 0.10,  -- +10 % max health per level
	XP_DAMAGE_PER_LV = 0.07,  -- +7 % damage per level
	XP_ENERGY_PER_LV = 5,     -- commanders: +5 energy/s per level

	-- Metal spot centres of the Pylon City map. Used as a fallback whenever the compiled map's
	-- metal layer is missing/shifted/empty (compilers often drop or rescale it), so placement
	-- and the bot still work. Real metal cells are always honoured as well.
	PYLON_CITY_SPOTS = {
		{ 384, 896 }, { 384, 1152 }, { 896, 384 }, { 896, 896 }, { 896, 1152 }, { 896, 1664 },
		{ 1152, 384 }, { 1152, 896 }, { 1152, 1152 }, { 1152, 1664 }, { 1664, 896 }, { 1664, 1152 },
	},
	SPOT_HALF        = 56,    -- half-size of a fallback spot (112 elmos plaza spot)

	-- Power wires (drawn by the wire widget, enforced by pw_power_grid)
	WIRE_PYLON_LINK  = 340,   -- pylons closer than this are wired together

	-- Metal siphons need a metal spot + a finished pylon in range; one structure per spot
	SPOT_CLEARANCE   = 72,

	commanders = { aegis_commander = true, vanta_commander = true },
	pylons     = { aegis_pylon = true,     vanta_pylon = true },
	generators = { aegis_generator = true, vanta_generator = true },
	siphons    = { aegis_siphon = true,    vanta_siphon = true },
	turrets    = { aegis_turret = true,    vanta_turret = true },
	factories  = { aegis_factory = true,   vanta_factory = true },
}
