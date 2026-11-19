# Pylon Wars (Spring engine)

Two factions, one hero commander with six weapons, factories that only run on metal spots wired to pylons + generators.
Full design: [docs/DESIGN.md](docs/DESIGN.md).

```
dist/   build output (.sdz game, .sd7 map)        docs/   design + example start script
game/   the game archive root (becomes the .sdz)   map/    mapinfo.lua + generated map sources
tools/  gen_map.py, gen_assets.py, pngutil.py      build.py
```

## Build
```
python3 build.py              # game + map
python3 build.py --game       # dist/PylonWars-0.3.2.sdz  (no dependencies)
python3 build.py --map        # dist/PylonCity.sd7
python3 build.py --install    # copy into ~/.spring (or %USERPROFILE%/Documents/My Games/Spring, or $SPRING_DATADIR)
python3 build.py --assets     # regenerate placeholder models/textures/pics
```
The `.sdz` needs only Python 3. The `.sd7` additionally needs:
1. a **map compiler** on PATH (`springmapconvng`, `pymapconv` or `mapconv`), or set
   `MAPCONV="<cmd> -o {smf} -t {tex} -a {height} -m {metal} -n {minh} -x {maxh}"` to match your tool's flags
   (the default flags are my best recollection of the common ones; check your tool's `--help`);
2. 7-Zip: `pip install py7zr` or a `7z`/`7za` binary.

Without a compiler, `build.py --map` still writes the PNG sources to `map/build/src/`; compile them, put
`PylonCity.smf` + `PylonCity.smt` in `map/prebuilt/maps/` and run `python3 build.py --map --no-convert`.

## Play
`spring docs/example_startscript.txt` (edit names/ports first). Select the commander, then
* **Z X C V B N** or click the bar: toggle weapon slots 1-6 (rings on the ground show enabled ranges)
* build Pylon + Generator near a metal spot, then the Weapon Factory (the overlay shows why a spot is invalid).

## Changelog (engine-tested fixes)
- Added `LuaRules/main.lua` + `draw.lua` (without them no gadget loads, so no commander spawned).
- Start scripts must use full archive names: `Pylon Wars 0.3.2`, `Pylon City 1.0`.
- Unit `weapons` entries use `name =` (this engine ignores `def =`).
- Lua unit scripts (`scripts/`) + shipped `unit_script.lua` gadget: required for building/aiming.
- Factories need `isfactory`, a yardmap and a yard-opening `Activate`; all structures get a yardmap.
- Added death explosions (`weapons/common.lua`) and a built-in skirmish bot (`pw_bot.lua`, disable with modoption `pwbot=0`).
- Factory footprint reduced from 5x5 (80 elmos, the whole metal spot) to 4x4 (64 elmos); the metal check now
  accepts a factory whose footprint touches any metal cell; generated map metal spots are 7x7 px (112 elmos).
  Re-run `python3 build.py` to regenerate/recompile the map if you use the generator.

## v0.2 gameplay additions
Metal siphons, commander Blink (F), veterancy levels, and bot expansion. See `docs/DESIGN.md`.
Controls: Z X C V B N toggle commander weapons, **F** blinks toward the cursor.

## v0.3.0
Heavy units (Warden / Juggernaut), pylon-powered turrets (Sentry / Bastion), smarter bot (turrets, blink retreat).

## v0.3.1
Placement fix: a factory (or siphon) is accepted as soon as ANY part of its footprint overlaps the metal spot
(`placement.OnMetal(x, z, half)`), so the cursor no longer needs to be centred on the spot.

## v0.3.2
* "Can only be built on a metal spot" fix: if the compiled map's metal layer is empty/shifted, placement (and the bot,
  and the overlay) fall back to the configured Pylon City spots in `pw_config.lua` (`PYLON_CITY_SPOTS`). Real metal cells still count.
  On a map with no metal at all and no configured spots the restriction is lifted instead of blocking every build.
* **Power wires**: `gui_pw_wires.lua` draws pylon-to-pylon links and wires from pylons to generators (yellow),
  siphons/turrets/factories (green); a red stub marks a powerless building. Pulses travel along live wires.
* **Power grid** (`pw_power_grid.lua`): siphons, turrets and factories are shut down (stunned) while no finished pylon of
  their team is within `PYLON_RANGE`, and restart when a pylon is rebuilt. Messages tell the team what happened.
* Removed the deprecated `autoShowMetal` from `map/mapinfo.lua` (recompile the map to drop the warning).
