# Future game: vision notes (captured from the conversation, 2026-11)

These are the project owner's own words and decisions, condensed. They are the source for `NEW_GAME_DESIGN.md`.

## Concept
A completely new game: high-level war strategy (reference points: Command: Modern Operations, Gary Grigsby's games,
Defcon) with simplified mechanics that are quick to learn, but with gameplay in the spirit of the simultaneous-turn
planning of the current project ("Cold Synapse"), at a much larger scale. Inspired by other games, not copying them;
may be released beyond private use, so everything must be original.

## Decisions (answers to the open questions)
1. **Setting:** everything, starting with the Cold War. Story arc: spy missions in Berlin, Vienna, London, Moscow and
   others -> small border skirmishes NATO / Warsaw Pact -> a first invasion (either direction, to be decided by the
   designer) through the Fulda Gap -> Germany as a nuclear wasteland -> global nuclear destruction -> the surviving
   factions cooperate to launch a small colony ship so humanity survives ("we could have done this without the war").
2. **Scale:** follows the story arc, city -> border -> theatre -> wasteland -> world.
3. **Pace:** a long single-player campaign made of many shorter missions of about 30 to 60 minutes. Between missions: a
   high-level layer of logistics, political and strategic-approach decisions that changes the goals, equipment and other
   conditions of the next missions, and is changed by their results. The coupling is much tighter during the invasion
   than during small battles.
4. **Opponents:** single player first (playable from either side, including the decision layers); multiplayer later.
5. **Layers:** different mission types plus supporting between-mission decision layers; not all active at the same time.
6. **Platforms:** installable Linux app first; portable to Windows and macOS. Possibly released beyond private use.
7. **Scoring / KPIs:** nuclear escalation, civilian impact and similar measures appear only where they fit the story.
   Each mission type and each between-mission activity can have its own goals and success measures.

## Tone (added later)
Inject humour into gameplay and story: dark humour and "relaxed situations", whatever else works, always inside the
logic of the storyline.

## Legal / originality notes
* The Cold War, real countries and cities are free to use. Avoid trademarked names (e.g. other games' titles),
  copied units/stat tables, art, text or audio. Real weapon designations should be generic or fictional.
* The current project (Cold Synapse) is a private-use rebuild of a commercial game and stays private. Anything meant to
  be published should be the new game.
* macOS builds need signing/notarisation through an Apple developer account for other people's Macs.

## Answers to the open questions in design draft 1
* Global map from the first mission; everything reachable, so assets (units, caches, scientists, a seed vault) can be
  secured in remote corners early; this pays off in the last act.
* Branches change in varying degrees after each mission and each between-mission decision.
* Tone: realistically dark. Never joke about the results of the war; dealing with them is fine. Humour everywhere else,
  as dark as possible, always respecting life, showing enemies as human beings and resisting propaganda.
* Neutral writing: both sides have equal chances and, absent a decisive imbalance, end in the same situation. The theme is
  the cost of human hubris and inhuman decisions, idealistically, not propaganda for either side.

## Further answers
* Map style by size: FS-like squares for small maps; Grigsby-style hexes for large maps; in between to be worked out
  (suggestion: hexes that can be opened into a few sub-cells).
* Drill-down from the operational map into the close FS-style tactical view: yes, include it in the first version.
* The new game is PARKED until the Frozen Synapse remake (Cold Synapse) is finished.

## REMINDER FOR THE ASSISTANT (owner's explicit request)
**When the Cold Synapse remake is declared done, remind the owner of this project** (docs/NEW_GAME_DESIGN.md,
draft 2, working title "Thin Ice") and offer to start with roadmap step 1 (one Berlin spy mission at the new scale).
Open points to raise then: title, how historical, how remote assets are secured in Act I, hex/square handover.

## Style feedback on units across the scales (owner, after draft 2)
* Human figures: liked. Keep the figure style.
* Going up the scale, abstraction should rise GRADUALLY, not jump to symbol rectangles. On the Act II, III and even IV
  maps the icons should resemble a 3D version of what the unit is: a single vehicle, a squad of five people, a group of
  tanks, even a full armoured/mechanised brigade, shown as small 3D-looking models, not "rectangles with drawings".
* Symbols/echelon marks may remain as a light overlay; the main read is the little 3D model.
* Cold Synapse restyle (later, not now): same figure family but abstract: one colour all over, no faces/uniform detail.

## Decisions on unit granularity (owner, after the 3D-model samples)
* The pad/rectangle around a unit goes. Individual units need no frame; groups get a bracket only when they ARE a group.
* Acts I-II: every soldier/vehicle is its own unit with its own orders. Act III: platoons/companies of 3-6 models move as
  one and can be split into single vehicles when you zoom in. Act IV-V: brigades/convoys/crowds as one group. Act VI: one
  asset per unit (silo, sub, wing). Acts stay separate in their unit dynamics (no mixing of scales in a mission).
* Selecting a platoon/company shows the strength (and fuel/ammo) of each unit in it.
* Overlap missions between acts: designer's decision (to be made when writing missions).
* Temporary groups: box-select several units and move them together, with a choice of pace: slowest unit sets the pace, or
  each as fast as possible. (Not combining from the base unit scale downward.)
* Marker for individual units: samples drawn (ring under each vs. no ring until selected); owner to pick.

## Information and markers (owner decisions after the unit-granularity samples)
* Selection ring: only on the SELECTED unit, never on enemy units. The ring is centred on the unit's BODY (not its gun,
  tail or other protruding parts), and this correction is applied only to unit types whose body is off-centre
  (tank, carrier gun, helicopter, self-propelled gun). People and trucks are already centred.
* Strength bar: every unit always shows a bar above it, an outline of the full bar with the actual strength as the
  filled proportion. Plus the per-unit strength / fuel / ammo details shown when a platoon/company is selected.
* Information asymmetry is a core mechanic: we know our own units better than the enemy's. Enemy units may show only
  what is obvious (outline bar with unknown fill, "?" type if unidentified, destroyed vehicles / dead soldiers crossed
  out). Selecting an enemy shows partial data with unknown fields crossed out. Better intel comes from a successful
  agent / activated source / passed orders from an earlier mission.
* Counter-espionage: an early mission (or one double mission with both operations at once). All four outcomes are
  possible and PLAYED ON (you succeed/they fail, both succeed, both fail, you fail/they succeed). The result counts even
  if your whole team dies: it is not about winning, it is about showing how small things become large.

## Overlaps, QA, partial intel, persistent consequences (owner feedback, then assistant proposals)
* Strength bars sit directly on/above the unit (closer than in the t1 sample). Overlap handling proposals: bar belongs to the
  sprite and is depth-sorted; bar fades to ~40% when covered by another sprite; minimum visual spacing between units
  (display nudge only, rules unaffected); crowd collapse (thin 2 px bars above ~5 overlaps, stack with count past a density
  threshold); hovered/selected unit raised to front; a key (Alt) shows all full bars.
* Mock-up QA rule: every mock-up gets a layout check (text inside boxes, no label overlaps, bars not crossing units) before it
  is shown; unresolved issues are flagged.
* Spy results are partial: per-fact reveal (type, strength, fuel, ammo, crew, position, orders) decided deterministically from
  the mission seed, capped around 70%, quality improves as enemy losses grow (less to track, less guarding, panic), uncertain facts
  shown as ranges, possible disinformation, intel decays over turns unless the source is kept.
* Every mission ends on a graded result and the story continues regardless (decisive win ... disaster). Persistent state:
  forces/veterans/equipment (losses carry over), supply, intel, forward bases; MORALE in three layers (unit morale, home front,
  political support) with consequences (reaction speed, willingness to take risky orders, desertion/refusal/surrender, protests,
  reinforcements, rules of engagement, unlocks incl. nuclear options later). Spiral protection (desperate defenders, allies,
  symmetrical pressure on the enemy). Same system for both sides. Reference: Strike Commander (campaign consequences).
* Open questions asked: visible morale number or only through behaviour; may very-low-morale units refuse orders; minimum force
  floor after a disaster; draw the overlap-solution sample next?
