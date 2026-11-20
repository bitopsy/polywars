# Pylon Wars v0.6.2

## Release Notes

## v0.6.2 - repair beacon crash fix

* Fixed `pw_repair.lua:23: attempt to index field 'beacons' (a nil value)` (thrown every 15 frames): `pw_config.lua` had no `beacons` set and no `BEACON_RADIUS`. Both are now defined, and the gadget caches beacon def IDs instead of scanning every unit by name.
* Beacons now heal **allied** units (not just the owner's team) and ignore dead/unpowered ones.
* Repair beacons, sensor masts and heavy towers (Obelisk / Mortar Battery) are now actually pylon-powered like their descriptions say: shut down without a pylon (`pw_power_grid`), only placeable inside the network (`pw_factory_rules`), drawn on the wire overlay, previewed by the placement widget (new `cfg.beacons/masts/obelisks`, `placement.Sets().consumers`).
* Removed the deprecated `Spring.GetUnitCommands(id, 0)` calls in the bot (uses `GetUnitCommandCount`).
* Bot builds a repair beacon at its home base.

[Full changelog on GitHub](https://github.com/bitopsy/polywars/compare/v0.6.1...v0.6.2)

## Download

* [dist/PylonWars-0.6.2.sdz](https://github.com/bitopsy/polywars/releases/tag/v0.6.2)
* [dist/circuit.sd7](https://github.com/bitopsy/polywars/releases/tag/v0.6.2)

## Build

```bash
python3 build.py              # game + map
python3 build.py --game       # dist/PylonWars-0.6.2.sdz (no dependencies)
python3 build.py --map        # dist/polycity.sd7
```

## Play

Use `spring docs/example_startscript.txt` with 2 human slots, one per faction.