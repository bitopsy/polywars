# polywars - design

An RTS where the **commander is a hero unit**: you spend most of a fight micro-managing
one character (positioning, weapon swaps, energy), like an MMORPG, while a small economy
and a few factories scale the army behind him.

## Pillars
1. **Commander micro** - 6 weapons, each with its own range / burst / energy price. Energy is the limiter, so the right weapon at the right distance beats "everything on".
2. **Wired expansion** - weapon factories exist only on metal spots, and only when a pylon + generator network reaches them.
3. **Small, readable map** - a city grid where streets are lanes and plazas are objectives.

## Factions
| | Aegis (blue) | Vanta (red) |
|---|---|---|
| Identity | precise, long reach, energy-hungry | kinetic, short reach, high burst, tougher |
| Commander HP / speed | 3800 / 2.3 | 4600 / 1.9 |
| Pylon / generator / factory (metal) | 60 / 90 / 400 | 70 / 100 / 420 |
| Generator output | 56 E/s | 50 E/s |
| Units | Skirmisher (fast laser), Prism Tank (long lance) | Gunner (autocannon), Howitzer (artillery) |

## Commander weapons (slot = hotkey Z X C V B N)
| # | Aegis | range | dmg | reload s | energy/shot | Vanta | range | dmg | reload s | energy/shot |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Pulse Pistol | 300 | 40 | 0.5 | 10 | Rivet Gun | 280 | 16 | 0.2 | 4 |
| 2 | Arc Rifle | 450 | 90 | 1.5 | 40 | Breach Slug | 420 | 120 | 1.6 | 45 |
| 3 | Scatter Burst | 220 | 5x25 | 1.2 | 35 | Hail Scatter | 200 | 6x22 | 1.1 | 36 |
| 4 | Rail Lance (sniper) | 700 | 350 | 4.0 | 220 | Gauss Piercer | 650 | 320 | 3.6 | 190 |
| 5 | Plasma Mortar (AoE) | 900 | 140 | 3.0 | 120 | Shell Mortar | 880 | 150 | 3.4 | 125 |
| 6 | Nova Burst (point blank AoE) | 140 | 240 | 5.0 | 150 | Overdrive Slam | 120 | 260 | 5.0 | 150 |

Each weapon is an independent toggle. A disabled weapon never acquires a target, so it never spends energy.
The commander starts with 1500 energy storage and +25 E/s; spamming all six empties it in seconds.

### The micro loop
* **Kite**: stay at the edge of your best affordable weapon, step back when the enemy closes, switch to the next weapon down.
* **Energy budgeting**: pistol/rivet is cheap sustain, snipers and AoE are cash-ins; toggling them off while energy refills is the skill.
* **Burst windows**: slot 6 at point blank + slot 3 shotgun is the all-in; both cost ~185 energy.
* The HUD shows range, damage, energy cost and cooldown per slot, plus rings on the ground for every enabled weapon.

## Economy and building
* Resources: **metal** (commander +3/s, each factory +2/s) and **energy** (commander +25/s, generators +28/s Aegis, +25/s Vanta).
* Commander builds: **Pylon**, **Generator**, **Weapon Factory**, **Siphon**.
* **Factory rule** (enforced in `LuaRules/Gadgets/pw_factory_rules.lua`):
  1. the build position is over a metal spot, **and**
  2. a *finished* pylon is within `PYLON_RANGE` (320 elmos), **and**
  3. a *finished* generator is within `POWER_LINK_RANGE` (220 elmos) of that pylon.
  Constants live in `LuaRules/Headers/pw_config.lua`; the placement widget reads the same file and draws metal spots, pylon rings and a green/red cursor with the reason.
* Factories produce two combat units per faction (see `units/`).
* Win condition: lose your commander and your team is destroyed; last ally team standing wins.

## Map: Pylon City (2048 x 2048 elmos)
8 x 8 city blocks, 80-elmo streets. Buildings are raised walls (units path through streets), 12 plazas are open ground with a metal spot:
2 home plazas per side, 4 flank plazas, a 2 x 2 central square. Aegis spawns west (256, 1024), Vanta east (1792, 1024); the layout is mirror-symmetric.

## Code map
| Path | Role |
|---|---|
| `game/modinfo.lua`, `gamedata/` | archive info, sides, move classes, rules |
| `game/units/*.lua`, `weapons/*.lua` | all unit and weapon defs per faction |
| `LuaRules/Headers/pw_config.lua` | shared constants (commands, ranges, def names) |
| `LuaRules/Headers/pw_placement.lua` | factory rule, used by gadget *and* widget |
| `LuaRules/Gadgets/pw_commander_weapons.lua` | W1..W6 toggle commands + `AllowWeaponTarget` |
| `LuaRules/Gadgets/pw_factory_rules.lua` | blocks illegal factory starts |
| `LuaRules/Gadgets/pw_game_spawn.lua`, `pw_game_end.lua` | fallback commander spawn, win/lose |
| `LuaUI/Widgets/gui_pw_commander_hud.lua` | weapon bar, hotkeys, range rings |
| `LuaUI/Widgets/gui_pw_factory_placement.lua` | placement overlay |
| `tools/gen_map.py` | map texture / heightmap / metalmap generator |
| `tools/gen_assets.py` | placeholder S3O models, textures, pics |
| `build.py` | builds `dist/*.sdz` and `dist/*.sd7` |

## Systems added in v0.2
* **Metal siphons** (`aegis_siphon`, `vanta_siphon`): +4 metal/s, 110-120 metal. Buildable only on a metal spot with a *finished pylon* in range (no generator needed). One factory **or** siphon per spot (`SPOT_CLEARANCE`). Commander metal income is only +3/s, so siphons are the economy: expand, then defend the spots.
* **Blink** (key `F`, or the Blink command button): commander jumps up to 320 elmos toward the cursor, 100 energy, 9 s cooldown, stops at the last standable point on the way. Use it to disengage (kite) or to close on a sniper. Gadget `pw_blink.lua`; constants in `pw_config.lua`.
* **Veterancy** (`pw_veterancy.lua`): every armed mobile unit earns XP = damage dealt + 2 x metal cost of kills; levels at 2000 / 6000 / 14000 / 28000 XP. Per level: +10 % max health, +7 % damage; commanders also +5 energy/s per level. The HUD shows the commander's level; level-ups are announced in chat.
* **Skirmish bot** (`pw_bot.lua`): drives any AI-controlled team (a NullAI slot works as a placeholder). Builds pylon, generators, factory, then expands with pylon + siphon pairs on up to 3 more spots, produces units and attacks. Disable with modoption `pwbot=0`.

## v0.3.0
* **Heavy units**: Aegis *Warden* (3000 HP, 460-range beam, 400 metal) and Vanta *Juggernaut* (4000 HP, 310-range autocannon, 420 metal) from the weapon factories: a slow, expensive third tier that anchors a push.
* **Turrets**: Aegis *Sentry* (laser, 420 range) and Vanta *Bastion* (autocannon, 350 range). They only build inside a finished pylon's range (`CanPlaceTurret`), so defending a siphon means extending the network first.
* **Bot**: builds a turret at its base spot and at every siphon it claims, and blinks its commander back home when it drops below 35 % health with armed enemies nearby.
* Version is now 0.3.0 (`modinfo.lua`): start scripts must say `Pylon Wars 0.6.2`.

## v0.3.2: the wired network
Pylons form a mesh (links up to `WIRE_PYLON_LINK` = 340 elmos). Generators within `POWER_LINK_RANGE` of a pylon feed it; siphons, turrets and factories need a finished pylon within `PYLON_RANGE`. Lose that pylon and they shut down until it is rebuilt, so pylons are the weak point to snipe and to defend. Wires are drawn by `LuaRules/Gadgets/pw_wires.lua`.

## Audio
See README (v0.4.0). Sound names are defined in `gamedata/sounds.lua`; add a new effect by adding a WAV, a `SoundItems` entry, and a `soundstart`/`soundhit`/`GG.PW_Sound` reference.

## v0.6.0 roster
| Role | Aegis | Vanta |
|---|---|---|
| Fast harasser | Scout (300 hp, 250 range) | Raider (380 hp, 220 range, spray) |
| Core line | Skirmisher / Striker (400 range) | Gunner / Bruiser (280 range, scatter) |
| Long range | Prism (lance) | Howitzer |
| Heavy | Warden | Juggernaut |
| Builder | Constructor | Constructor |
| Static D | Sentry, Obelisk (720 range) | Bastion, Mortar Battery (780 range, AoE) |
| Support | Repair Beacon, Sensor Mast, Barrier | Repair Beacon, Sensor Mast, Barrier |
Pylon-powered set: `cfg.turrets` (turrets, artillery, beacons, masts). Beacon tuning: `BEACON_*` in `pw_config.lua`.

## Engine notes (learned the hard way)
* LuaRules needs **both** `LuaRules/main.lua` and `draw.lua`; otherwise no gadget loads.
* Unit `weapons` entries use `name =`, not `def =`.
* Lua unit scripts (`scripts/`) only run with the `unit_script.lua` gadget; builders/factories/weapons need script callins (`scripts/pw_common.lua`). Factories must open the yard in `Activate`.
* Structures need a yardmap (generated in `def()`); factories also need `isfactory = true`.
* Start scripts use full archive names (`Pylon Wars 0.6.2`, `Pylon City 1.0`).
* Models are placeholder boxes without animation.

## Next steps
Pylon power field (speeds production nearby), per-weapon commander perks at veteran levels, a second map, a 2v2 mode with shared pylon networks, bot use of Blink.
