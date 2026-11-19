# polywars

RTS game where the commander is a hero unit - micro your commander with six weapons, wire pylons to power, and claim metal spots.

**Author:** goddot

Full design: [docs/DESIGN.md](docs/DESIGN.md).

```
dist/   build output (.sdz game, .sd7 map)        docs/   design + example start script
game/   the game archive root (becomes the .sdz)   map/    mapinfo.lua + generated map sources
tools/  gen_map.py, gen_assets.py, pngutil.py      build.py
```

## Build
```
python3 build.py              # game + map
python3 build.py --game       # dist/polywars-0.1.0.sdz  (no dependencies)
python3 build.py --map        # dist/polycity.sd7
python3 build.py --install    # copy into ~/.spring (or %USERPROFILE%/Documents/My Games/Spring, or $SPRING_DATADIR)
python3 build.py --assets     # regenerate placeholder models/textures/pics
```
The `.sdz` needs only Python 3. The `.sd7` additionally needs:
1. a **map compiler** on PATH (`springmapconvng`, `pymapconv` or `mapconv`), or set
   `MAPCONV="<cmd> -o {smf} -t {tex} -a {height} -m {metal} -n {minh} -x {maxh}"` to match your tool's flags
   (the default flags are my best recollection of the common ones; check your tool's `--help`);
2. 7-Zip: `pip install py7zr` or a `7z`/`7za` binary.

Without a compiler, `build.py --map` still writes the PNG sources to `map/build/src/`; compile them, put
`polycity.smf` + `polycity.smt` in `map/prebuilt/maps/` and run `python3 build.py --map --no-convert`.

## Play
`spring docs/example_startscript.txt` (edit names/ports first). Select the commander, then
* **Z X C V B N** or click the bar: toggle weapon slots 1-6 (rings on the ground show enabled ranges)
* build Pylon + Generator near a metal spot, then the Weapon Factory (the overlay shows why a spot is invalid).

## Changelog (engine-tested fixes)
- Added `LuaRules/main.lua` + `draw.lua` (without them no gadget loads, so no commander spawned).
- Start scripts must use full archive names: `polywars 0.1.0`, `polycity 1.0`.
- Unit `weapons` entries use `name =` (this engine ignores `def =`).
- Lua unit scripts (`scripts/`) + shipped `unit_script.lua` gadget: required for building/aiming.
- Factories need `isfactory`, a yardmap and a yard-opening `Activate`; all structures get a yardmap.
- Added death explosions (`weapons/common.lua`) and a built-in skirmish bot (`pw_bot.lua`, disable with modoption `pwbot=0`).
