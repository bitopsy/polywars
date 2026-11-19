#!/usr/bin/env python3
"""Pylon Wars build script.

    python3 build.py                 # game (.sdz) + map (.sd7)  -> dist/
    python3 build.py --game          # only dist/PylonWars-<version>.sdz
    python3 build.py --map           # only dist/PylonCity.sd7
    python3 build.py --assets        # regenerate placeholder art first
    python3 build.py --install       # also copy results into your Spring data dir
    python3 build.py --clean

Game  : game/ is zipped as-is (root of the archive == contents of game/).
Map   : tools/gen_map.py makes texture/height/metal PNGs, an external map compiler
        (SpringMapConvNG / pymapconv / mapconv) turns them into .smf/.smt, and the
        result plus map/mapinfo.lua is packed as .sd7 (7-Zip) with py7zr or a 7z binary.
        Override the compiler with MAPCONV, e.g.
          MAPCONV="pymapconv -o {smf} -t {tex} -a {height} -m {metal} -n {minh} -x {maxh}"
        Already have a compiled map? Put PylonCity.smf/.smt in map/prebuilt/maps/ and use --no-convert.
"""
import argparse
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GAME_DIR, MAP_DIR, DIST, TOOLS = ROOT / "game", ROOT / "map", ROOT / "dist", ROOT / "tools"
MAP_NAME = "PylonCity"
SKIP_FILES = {".gitkeep", ".DS_Store", "Thumbs.db"}
SKIP_TOP_DIRS = {"tmp"}          # game/tmp is scratch space, never shipped


def log(msg):
    print("[build] " + msg, flush=True)


def modinfo_version():
    text = (GAME_DIR / "modinfo.lua").read_text(encoding="utf-8")
    m = re.search(r'version\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else "dev"


def game_files():
    for path in sorted(GAME_DIR.rglob("*")):
        if not path.is_file() or path.name in SKIP_FILES:
            continue
        rel = path.relative_to(GAME_DIR)
        if rel.parts[0] in SKIP_TOP_DIRS or "__pycache__" in rel.parts:
            continue
        yield path, rel.as_posix()


def build_game():
    out = DIST / f"PylonWars-{modinfo_version()}.sdz"
    DIST.mkdir(exist_ok=True)
    n = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path, arc in game_files():
            zf.write(path, arc)
            n += 1
    log(f"game: {out.name} ({n} files, {out.stat().st_size // 1024} KiB)")
    return out


# ------------------------------------------------------------------ map
def find_converter(files):
    values = dict(smf=files["smf"], tex=files["texture"], height=files["height"], metal=files["metal"],
                  minh=files["minh"], maxh=files["maxh"])
    env = os.environ.get("MAPCONV")
    if env:
        return [a.format(**values) for a in shlex.split(env)]
    for exe in ("springmapconvng", "SpringMapConvNG", "pymapconv", "pymapconv.py", "mapconv"):
        found = shutil.which(exe)
        if found:
            cmd = [found] if not found.endswith(".py") else [sys.executable, found]
            return cmd + ["-o", values["smf"], "-t", values["tex"], "-a", values["height"],
                          "-m", values["metal"], "-n", str(values["minh"]), "-x", str(values["maxh"])]
    return None


def pack_7z(src_dir, out):
    if out.exists():
        out.unlink()
    try:
        import py7zr
        with py7zr.SevenZipFile(out, "w") as z:
            for p in sorted(src_dir.rglob("*")):
                z.write(p, p.relative_to(src_dir).as_posix())
        return True
    except ImportError:
        pass
    for exe in ("7z", "7za", "7zz", "7zr"):
        found = shutil.which(exe)
        if found:
            subprocess.run([found, "a", "-t7z", "-mx=9", str(out), "."], cwd=src_dir, check=True,
                           stdout=subprocess.DEVNULL)
            return True
    return False


def build_map(convert=True):
    sys.path.insert(0, str(TOOLS))
    import gen_map
    work = MAP_DIR / "build"
    stage = work / "stage"
    maps_dir = stage / "maps"
    if stage.exists():
        shutil.rmtree(stage)
    maps_dir.mkdir(parents=True)

    if convert:
        log("map: generating texture / heightmap / metalmap ...")
        images = gen_map.generate(str(work / "src"))
        files = dict(images, smf=str(maps_dir / f"{MAP_NAME}.smf"), minh=gen_map.MIN_H, maxh=gen_map.MAX_H)
        cmd = find_converter(files)
        if not cmd:
            log("map: no map compiler found (SpringMapConvNG / pymapconv / mapconv) and MAPCONV is unset.")
            log(f"     Sources are in {work / 'src'} - compile them yourself, drop {MAP_NAME}.smf/.smt into "
                "map/prebuilt/maps/ and run:  python3 build.py --map --no-convert")
            return None
        log("map: compiling: " + " ".join(cmd))
        subprocess.run(cmd, check=True)
    else:
        pre = MAP_DIR / "prebuilt" / "maps"
        if not pre.is_dir():
            log("map: --no-convert needs map/prebuilt/maps/*.smf|*.smt")
            return None
        for f in pre.iterdir():
            shutil.copy2(f, maps_dir / f.name)

    for need in (f"{MAP_NAME}.smf", f"{MAP_NAME}.smt"):
        if not (maps_dir / need).exists():
            log(f"map: missing {need} after conversion")
            return None
    shutil.copy2(MAP_DIR / "mapinfo.lua", stage / "mapinfo.lua")
    out = DIST / f"{MAP_NAME}.sd7"
    DIST.mkdir(exist_ok=True)
    if not pack_7z(stage, out):
        log("map: no 7-Zip support found. `pip install py7zr` or install 7z/7za, then re-run.")
        return None
    log(f"map: {out.name} ({out.stat().st_size // 1024} KiB)")
    return out


def spring_data_dir():
    if os.environ.get("SPRING_DATADIR"):
        return Path(os.environ["SPRING_DATADIR"])
    home = Path.home()
    if platform.system() == "Windows":
        return home / "Documents" / "My Games" / "Spring"
    return home / ".spring"


def install(results):
    base = spring_data_dir()
    for f in results:
        sub = "maps" if f.suffix == ".sd7" else "games"
        (base / sub).mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, base / sub / f.name)
        log(f"installed {f.name} -> {base / sub}")


def main():
    ap = argparse.ArgumentParser(description="Build Pylon Wars (game .sdz + map .sd7)")
    ap.add_argument("--game", action="store_true", help="build only the game")
    ap.add_argument("--map", action="store_true", help="build only the map")
    ap.add_argument("--no-convert", action="store_true", help="map: reuse map/prebuilt/maps/*.smf|smt")
    ap.add_argument("--assets", action="store_true", help="regenerate placeholder art first")
    ap.add_argument("--install", action="store_true", help="copy results into the Spring data dir")
    ap.add_argument("--clean", action="store_true", help="remove dist/ outputs and map/build")
    a = ap.parse_args()

    if a.clean:
        shutil.rmtree(MAP_DIR / "build", ignore_errors=True)
        for f in DIST.glob("*"):
            if f.name != ".gitkeep":
                f.unlink()
        log("clean")
        return 0
    if a.assets:
        sys.path.insert(0, str(TOOLS))
        import gen_assets
        gen_assets.main()

    both = not (a.game or a.map)
    results, failed = [], False
    if a.game or both:
        results.append(build_game())
    if a.map or both:
        m = build_map(convert=not a.no_convert)
        if m:
            results.append(m)
        else:
            failed = True
    if a.install:
        install(results)
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
