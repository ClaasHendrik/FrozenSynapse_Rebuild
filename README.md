# Cold Synapse

A personal-use, native (Godot 4) simultaneous-turn tactics game in the style of Frozen Synapse.
"Cold Synapse" is a placeholder title; the original game's name, art, maps and missions are not used.

## Status
- [x] Step 1: deterministic simulation core + tests (`sim/`, `tests/`)
- [x] Step 2: procedural map generator, five game modes (Light/Dark), match flow (`sim/map_gen.gd`, `sim/modes.gd`, `sim/match.gd`)
- [ ] Planning UI, AI, campaign + packs, Linux packaging

## Run the tests
```bash
tests/run_all.sh /path/to/godot
```
All balance numbers live in `sim/balance.gd`. Sim units: positions in milli-tiles (1000 = 1 tile),
angles in decidegrees, 20 ticks/s, 100 ticks per 5 s turn.
