# Cold Synapse

A personal-use, native (Godot 4) simultaneous-turn tactics game in the style of Frozen Synapse.
"Cold Synapse" is a placeholder title; the original game's name, art, maps and missions are not used.

## Status
- [x] Step 1: deterministic simulation core + tests (`sim/`, `tests/`)
- [x] Step 2: procedural map generator, five game modes (Light/Dark), match flow (`sim/map_gen.gd`, `sim/modes.gd`, `sim/match.gd`)
- [x] Step 3: planning UI, Test preview, replay, hotseat, look-ahead AI (`ui/`, `sim/ai.gd`, `sim/nav.gd`)
- [x] Step 3.5: rules brought in line with the original (deterministic time-to-kill combat, real mode rules, Upload mode) — see `docs/RULES_REFERENCE.md`
- [x] Step 4: campaign — 55 missions in 19 chapters, Red-style pack (12), Blackout bonus pack (12); mission engine, allies, reinforcements, panels, progress saving (`campaign/`, `sim/mission.gd`)
- [x] Step 5: Linux packaging: `.deb` and portable tarball (`packaging/build_linux.sh`), AppImage script (`packaging/build_appimage.sh`, run on your own machine with appimagetool)
- [ ] Playtest tuning; add-on units/objects for the Blackout pack (proposed, awaiting decisions)

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
Look: procedural neon 3D-style board (extruded glowing walls, cube half-walls, figure silhouettes, bloom). The orders bar is hidden until the mouse touches the top edge of the window; right-click opens a context menu.
Controls: click a unit to select it, click the map to add waypoints (paths route around walls),
Backspace to undo, **A** aim, **D** duck, **W** wait, **F** fire (rocket/grenade),
**I** ignore an enemy, **C** continue on sight, **Tab** next unit, **Space** Test preview, **Enter** commit turn.
Replay: Space pause, +/- speed, drag the timeline, Enter skips.
Orders now also include **K** Check (glance at a point for 1 s while moving), **O** Focus on an enemy, Stand/Duck, Engage on Sight, Clear Focus/Ignore (all in the top-edge bar and the right-click menu).
Hotseat Dark mode shows the whole replay to both players (fog applies only while planning).

Screenshots under a virtual display (used for visual checks):
```bash
xvfb-run -a godot --rendering-driver opengl3 --path . -s tests/ui_smoke.gd -- /output/dir
```

## Campaign data
Missions are plain JSON in `campaign/*.json` (squads as `"mg*2"`, `"rl:launcher"`, `"civ:vip"`; objectives: eliminate,
kill_target, reach, collect, rescue, hold, survive; optional events, panels, dark, turn_seconds). Edit or add missions
there; `sim/mission.gd` documents every field. Maps are generated from each mission's fixed seed.
Progress is saved to `user://campaign_progress.json`; the campaign screen has an "unlock all" switch.

## Packaging (Linux)
```bash
packaging/build_linux.sh /path/to/Godot_v4.3-stable_linux.x86_64     # -> build/*.deb and build/*.tar.gz
sudo apt install ./build/cold-synapse_0.4.0_amd64.deb                  # installs to /opt/cold-synapse, command: cold-synapse
packaging/build_appimage.sh /path/to/Godot_v4.3-stable_linux.x86_64 /path/to/appimagetool   # AppImage (run on your machine)
```
The Godot binary is the runtime for the game's `.pck`. Saves and campaign progress go to `~/.local/share/godot/app_userdata/Cold Synapse/`.
Windows and macOS exports use Godot export templates (macOS also needs signing/notarisation); not done yet.

## Parked: the next game
See `docs/FUTURE_GAME_NOTES.md` and `docs/NEW_GAME_DESIGN.md`. **Remind the owner of this once Cold Synapse is done.**
