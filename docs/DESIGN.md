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
| Generator output | 45 E/s | 40 E/s |
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
* Resources: **metal** (commander +3/s, each factory +2/s) and **energy** (commander +25/s, generators).
* Commander builds: **Pylon**, **Generator**, **Weapon Factory**.
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

## Status and caveats
* **Not run in the Spring engine yet.** The scripts, map sources and archives are built and
  structurally checked, but Lua was not executed. Expect to fix small API-version mismatches
  (written against Spring 105.x conventions: `Script.SetWatchAllowTarget`, array-style `movedefs.lua`, `weapons/*.lua` auto-loading).
* Models are generated box placeholders without animation scripts (the engine's null script is used), so units do not animate or aim visibly.
* The map's `.smf/.smt` needs an external compiler (see README). The 4096 px texture, 257 px heightmap and 128 px metalmap are produced for it.
* No AI is included; test as human vs human (`docs/example_startscript.txt`).

## Next steps
Dash/blink command for the commander, per-weapon XP levels (the MMO layer), a pylon "power field" that speeds nearby production, a second map, an AI gadget.
