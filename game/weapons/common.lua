-- Death / self-destruct explosions referenced by unit defs (explodeas / selfdestructas).
-- Without these the engine logs "Couldn't find WeaponDef NOWEAPON" for every unit.
local function Blast(name, aoe, dmg)
	return { name = name, areaofeffect = aoe, edgeeffectiveness = 0.3, damage = { default = dmg },
	         cratermult = 0, craterboost = 0, impulsefactor = 0.1, soundhit = "" }
end
return {
	pw_blast_small  = Blast("Unit Explosion",      40,   60),
	pw_blast_medium = Blast("Structure Explosion", 80,  120),
	pw_blast_large  = Blast("Commander Blast",    200,  600),
}
