# Cold Synapse

A personal-use, native (Godot 4) simultaneous-turn tactics game in the style of Frozen Synapse.
"Cold Synapse" is a placeholder title; the original game's name, art, maps and missions are not used.

## Status
- [x] Step 1: deterministic simulation core + tests (`sim/`, `tests/`)
- [x] Step 2: procedural map generator, five game modes (Light/Dark), match flow (`sim/map_gen.gd`, `sim/modes.gd`, `sim/match.gd`)
- [x] Step 3: planning UI, Test preview, replay, hotseat, look-ahead AI (`ui/`, `sim/ai.gd`, `sim/nav.gd`)
- [x] Step 3.5: rules brought in line with the original (deterministic time-to-kill combat, real mode rules, Upload mode) — see `docs/RULES_REFERENCE.md`
- [ ] Campaign (55 missions, 19 chapters) + Red-style pack + bonus pack, Linux packaging

## Run the tests
```bash
tests/run_all.sh /path/to/godot
```
All balance numbers live in `sim/balance.gd`. Sim units: positions in milli-tiles (1000 = 1 tile),
angles in decidegrees, 20 ticks/s, 100 ticks per 5 s turn.

## Play (development)
```bash
godot --path .          # opens the menu: mode, Light/Dark, vs computer or hotseat
```
Controls: click a unit to select it, click the map to add waypoints (paths route around walls),
right-click or Backspace to undo, **A** aim, **D** duck, **W** wait, **F** fire (rocket/grenade),
**I** ignore an enemy, **C** continue on sight, **Tab** next unit, **Space** Test preview, **Enter** commit turn.
Replay: Space pause, +/- speed, drag the timeline, Enter skips.
Hotseat Dark mode shows the whole replay to both players (fog applies only while planning).

Screenshots under a virtual display (used for visual checks):
```bash
xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_smoke.gd -- /output/dir
```
