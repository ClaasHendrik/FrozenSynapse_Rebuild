# Cold Synapse

A personal-use, native (Godot 4) simultaneous-turn tactics game in the style of Frozen Synapse.
"Cold Synapse" is a placeholder title; the original game's name, art, maps and missions are not used.

## Status
- [x] Step 1: deterministic simulation core + tests (`sim/`, `tests/`)
- [ ] Map generator, planning UI, AI, game modes, campaign + packs, Linux packaging

## Run the tests
```bash
godot --headless --path . -s tests/run_tests.gd
```
All balance numbers live in `sim/balance.gd`. Sim units: positions in milli-tiles (1000 = 1 tile),
angles in decidegrees, 20 ticks/s, 100 ticks per 5 s turn.
