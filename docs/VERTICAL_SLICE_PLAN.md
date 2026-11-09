# Thin Ice (working title): vertical slice plan, draft 1

# Vertical slice plan: one Berlin mission, end to end

**Summary.** The smallest thing that proves Thin Ice is one playable Act I mission in Berlin, with the painted close-view look, long planning turns, partial intel, one strategic interlude and one humour event, both before and after the mission. It reuses most of Cold Synapse's engine (the deterministic simulation, planning, Test preview, replay and AI), and adds an isometric renderer with height levels, sight cones and noise, a small campaign state, and an interlude screen. It is built in six steps, each of them playable and tested, with a screenshot at the end of each. Nothing is built until you say go.


## What the slice must prove

* **The planning loop works at the new scale:** long turns, sight cones, noise, doors and height, with a Test preview you can trust.
* **The two layers talk:** a decision in the interlude changes the mission, and the result changes the next interlude.
* **The tone works:** dry humour in the briefing and a human, never cruel, handling of the people in it.
* **The look works in the engine,** not only in mock-ups: painted world, neon information layer, green highlight, ring only on the selected unit, strength bars, and partial enemy intel.
* **Consequences carry over,** felt only in the following mission, as decided.


## Scope (and what is deliberately left out)

| In the slice | Left out for now |
|---|---|
| One mission, 'The Café Handover', Berlin, night; 4 agents, about 8 guards and 6 civilians, one two-level building (roof and street) | Other cities, other acts, the hex and world maps |
| Sight cones with height, noise, doors, a body that can be found; Light and Dark play | Combat beyond a few shots and one fight; vehicles |
| Partial intel on the guards (type, route, alertness), shown as unknown or crossed out | Spy networks, counter-espionage mission |
| Interlude with the four tracks (supply, resolve, trust, intel), three decisions and one humour event card | The full strategic layer and branching |
| Morale of the four agents as a status detail, with the first two levels of its effects | Reserves, home front, veterancy |
| Play as the Western side; a mirrored Eastern version of the same mission as a switch | A second, different campaign for the other bloc |
| Save, load and replay; automated tests like Cold Synapse | Sound, music, voice, final fonts |


## What is reused and what is new

| Reused from Cold Synapse | New work |
|---|---|
| Deterministic simulation core, seeded rules, Test preview on a copy, replay frames and events | Isometric renderer with depth sorting, lighting, shadows and height levels |
| Waypoints, aim, stance, wait, check, ignore and focus orders; pathfinding | Sight cones that respect height and doors; noise; found bodies; alertness levels |
| Computer opponent that tests plans on a copy of the game | Guard routines (patrols that turn into hunting) as the opponent's plans |
| Mission data as JSON, objectives and events | Campaign state, interlude screen, event cards, partial-intel rules |
| Test and screenshot tooling | Painted-style assets generated in code and a procedural figure set |


## Milestones

| # | Deliverable | Done when |
|---|---|---|
| M1 | Isometric board with the Berlin block, agents and guards as figures, the ring on the selected unit, strength bars | A screenshot matches the Vienna mock-up closely; the engine runs it at a steady frame rate |
| M2 | Planning in the new view: waypoints, aim, stance, wait, check, with the hidden orders bar and the right-click menu | A scripted test plans and previews a full turn |
| M3 | Sight cones with height and doors, noise and found bodies; guards with patrol routines | Tests show a guard noticing an agent in sight and ignoring one behind a door |
| M4 | Partial intel and morale levels on guards and agents, deterministic | A replay is identical every time; unknown fields are crossed out as designed |
| M5 | Interlude: the four tracks, three decisions, one humour card, and the effect on the mission start | A different decision gives a visibly different mission start |
| M6 | Full loop: interlude, mission, result grade, next interlude, with save and load and the double view (Western and Eastern side) | A complete playthrough, with a PDF of screenshots for your review |


## Risks and honest unknowns

* **Art:** a painted look in code is an approximation. If it does not feel close enough once it runs, an artist or art pipeline may be needed, and that is a decision I would raise at M1.
* **Isometric rules:** hit-testing, occlusion and height levels are harder than top-down. M1 and M3 are where I would expect surprises.
* **Fun is unproven:** the planning loop is proven in Cold Synapse, but stealth with long turns is new. A first playable at M2 or M3 is the earliest honest test.
* **Effort:** I can't give days. In terms of working sessions I would expect each milestone to take one to three, so the whole slice is roughly ten to fifteen sessions.
* **Cold Synapse comes first:** it still waits on your Blackout list, polish items and feedback on the restyle.


## Decisions I need from you before M1

* Is 'The Café Handover' in Berlin the right first mission, or do you prefer Vienna or London?
* Western side first, with the mirrored Eastern version as a switch, or the other way round?
* May I start Thin Ice in the same repository (a separate folder), or do you want a new repository?
* Do you want Cold Synapse finished first, or should Thin Ice start in parallel?

