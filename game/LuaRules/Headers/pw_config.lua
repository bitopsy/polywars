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

	commanders = { aegis_commander = true, vanta_commander = true },
	pylons     = { aegis_pylon = true,     vanta_pylon = true },
	generators = { aegis_generator = true, vanta_generator = true },
	factories  = { aegis_factory = true,   vanta_factory = true },
}
