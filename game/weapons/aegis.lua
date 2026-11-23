-- AEGIS weapons: precise, energy-hungry, long reach.
-- Commander slots (aegis_commander.weapons order = hotkey order):
--   1 Pulse Pistol  2 Arc Rifle  3 Scatter Burst  4 Rail Lance  5 Mortar  6 Nova Burst
local function W(t)
	t.turret = true
	t.cratermult, t.craterboost = 0, 0      -- the city map is not deformable
	t.impulsefactor = 0.2
	return t
end

return {
	-- ===== commander weapons =====
	aegis_pistol = W{ name = "Pulse Pistol", description = "Pulse Pistol", weapontype = "LaserCannon",
		range = 300, reloadtime = 0.5, energypershot = 10, damage = { default = 40 },
		weaponvelocity = 900, rgbcolor = "0.3 0.7 1.0", thickness = 2.5, corethickness = 0.3, laserflaresize = 4 },

	aegis_arc = W{ name = "Arc Rifle", description = "Arc Rifle", weapontype = "LightningCannon",
		range = 450, reloadtime = 1.5, energypershot = 40, damage = { default = 90 },
		rgbcolor = "0.5 0.6 1.0", thickness = 2 },

	aegis_scatter = W{ name = "Scatter Burst", description = "Scatter Burst", weapontype = "LaserCannon",
		range = 220, reloadtime = 1.2, energypershot = 35, damage = { default = 25 },
		projectiles = 5, sprayangle = 1100, weaponvelocity = 900,
		rgbcolor = "0.4 0.9 1.0", thickness = 1.8, corethickness = 0.3, laserflaresize = 3 },

	aegis_rail = W{ name = "Rail Lance", description = "Rail Lance (sniper)", weapontype = "LaserCannon",
		range = 700, reloadtime = 4.0, energypershot = 220, damage = { default = 350 },
		weaponvelocity = 2600, rgbcolor = "0.9 0.95 1.0", thickness = 5, corethickness = 0.8, laserflaresize = 8 },

	aegis_mortar = W{ name = "Plasma Mortar", description = "Plasma Mortar (artillery)", weapontype = "Cannon",
		range = 900, reloadtime = 3.0, energypershot = 120, damage = { default = 140 },
		areaofeffect = 100, edgeeffectiveness = 0.4, weaponvelocity = 450, size = 5,
		rgbcolor = "0.4 0.7 1.0" },

	aegis_nova = W{ name = "Nova Burst", description = "Nova Burst (point blank)", weapontype = "Cannon",
		range = 140, reloadtime = 5.0, energypershot = 150, damage = { default = 240 },
		areaofeffect = 180, edgeeffectiveness = 0.2, weaponvelocity = 700, size = 6, noselfdamage = true,
		rgbcolor = "0.6 0.8 1.0" },

	-- ===== unit weapons =====
	aegis_unit_laser = W{ name = "Skirmisher Laser", weapontype = "LaserCannon",
		range = 330, reloadtime = 0.5, damage = { default = 25 }, weaponvelocity = 900,
		rgbcolor = "0.3 0.7 1.0", thickness = 2, corethickness = 0.3 },

	aegis_unit_beam = W{ name = "Prism Lance", weapontype = "LaserCannon",
		range = 520, reloadtime = 2.5, damage = { default = 120 }, weaponvelocity = 1800,
		rgbcolor = "0.8 0.9 1.0", thickness = 3.5, corethickness = 0.5, laserflaresize = 6 },

	-- ===== v0.3 =====
	aegis_unit_warden = W{ name = "Warden Beam", weapontype = "LaserCannon",
		range = 460, reloadtime = 1.2, damage = { default = 85 }, weaponvelocity = 1500,
		rgbcolor = "0.5 0.8 1.0", thickness = 3, corethickness = 0.45 },

	-- ===== v0.7 (these three were referenced by unit defs but missing, leaving the units unarmed) =====
	aegis_unit_scout = W{ name = "Scout Laser", weapontype = "LaserCannon",
		range = 280, reloadtime = 0.4, damage = { default = 11 }, weaponvelocity = 1000,
		rgbcolor = "0.4 0.8 1.0", thickness = 1.6, corethickness = 0.3 },

	aegis_unit_striker = W{ name = "Striker Twin Laser", weapontype = "LaserCannon",
		range = 400, reloadtime = 0.7, damage = { default = 42 }, weaponvelocity = 1300,
		rgbcolor = "0.3 0.7 1.0", thickness = 2.4, corethickness = 0.4 },

	aegis_turret_obelisk = W{ name = "Obelisk Beam", weapontype = "LaserCannon",
		range = 780, reloadtime = 3.2, damage = { default = 230 }, weaponvelocity = 2400, areaofeffect = 20,
		rgbcolor = "0.7 0.9 1.0", thickness = 4.5, corethickness = 0.6, laserflaresize = 8 },

	aegis_turret_laser = W{ name = "Sentry Laser", weapontype = "LaserCannon",
		range = 420, reloadtime = 0.6, damage = { default = 40 }, weaponvelocity = 1400,
		rgbcolor = "0.3 0.7 1.0", thickness = 2.5, corethickness = 0.4 },
}
