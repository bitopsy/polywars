-- VANTA weapons: kinetic, shorter reach, higher burst.
-- Commander slots (vanta_commander.weapons order = hotkey order):
--   1 Rivet Gun  2 Breach Slug  3 Hail Scatter  4 Gauss Piercer  5 Shell Mortar  6 Overdrive Slam
local function W(t)
	t.turret = true
	t.weapontype = t.weapontype or "Cannon"
	t.cratermult, t.craterboost = 0, 0
	t.impulsefactor = 0.3
	return t
end

return {
	-- ===== commander weapons =====
	vanta_rivet = W{ name = "Rivet Gun", description = "Rivet Gun",
		range = 280, reloadtime = 0.2, energypershot = 4, damage = { default = 16 },
		weaponvelocity = 1500, sprayangle = 400, size = 1.5 },

	vanta_breach = W{ name = "Breach Slug", description = "Breach Slug",
		range = 420, reloadtime = 1.6, energypershot = 45, damage = { default = 120 },
		weaponvelocity = 1200, areaofeffect = 24, size = 3 },

	vanta_hail = W{ name = "Hail Scatter", description = "Hail Scatter",
		range = 200, reloadtime = 1.1, energypershot = 36, damage = { default = 22 },
		projectiles = 6, sprayangle = 1500, weaponvelocity = 1000, size = 1.8 },

	vanta_gauss = W{ name = "Gauss Piercer", description = "Gauss Piercer (sniper)",
		range = 650, reloadtime = 3.6, energypershot = 190, damage = { default = 320 },
		weaponvelocity = 2800, areaofeffect = 16, size = 3.5 },

	vanta_mortar = W{ name = "Shell Mortar", description = "Shell Mortar (artillery)",
		range = 880, reloadtime = 3.4, energypershot = 125, damage = { default = 150 },
		areaofeffect = 110, edgeeffectiveness = 0.4, weaponvelocity = 440, size = 5 },

	vanta_slam = W{ name = "Overdrive Slam", description = "Overdrive Slam (point blank)",
		range = 120, reloadtime = 5.0, energypershot = 150, damage = { default = 260 },
		areaofeffect = 160, edgeeffectiveness = 0.2, weaponvelocity = 700, size = 6, noselfdamage = true },

	-- ===== unit weapons =====
	vanta_unit_gun = W{ name = "Gunner Autocannon",
		range = 280, reloadtime = 0.25, damage = { default = 14 }, weaponvelocity = 1500, sprayangle = 500, size = 1.5 },

	vanta_unit_howitzer = W{ name = "Howitzer",
		range = 800, reloadtime = 3.0, damage = { default = 110 }, areaofeffect = 90,
		edgeeffectiveness = 0.4, weaponvelocity = 430, size = 4.5 },

	-- ===== v0.3 =====
	vanta_unit_juggernaut = W{ name = "Juggernaut Cannon",
		range = 310, reloadtime = 0.4, damage = { default = 48 }, weaponvelocity = 1300, sprayangle = 300, size = 2.2 },

	vanta_turret_gun = W{ name = "Bastion Autocannon",
		range = 350, reloadtime = 0.3, damage = { default = 22 }, weaponvelocity = 1500, sprayangle = 350, size = 1.8 },
}
