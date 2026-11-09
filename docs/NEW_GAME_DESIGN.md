# THIN ICE (working title): design document, draft 4

_A Cold War campaign that escalates from spy games to the end of the world, and then asks whether we could just stop._

**Executive summary.** A single-player strategy campaign, playable from NATO or Warsaw Pact, that grows from a handful of agents in Berlin to a world on fire, and ends with former enemies launching one small colony ship together. The tactical heart is the same idea as the current project: both sides plan the same stretch of time at once, you preview your plan, then watch it resolve deterministically. Between missions, a light strategic layer (supply, resolve, trust, intel) changes what the next mission looks like and is changed by how it went. It is built to be learned in an evening, to be funny in an increasingly dark way, and to be an original game that can be shown to the world.


## Design pillars

* **Plan together, resolve together.** Simultaneous planning, a preview you can trust, a replay you can learn from. At every scale.
* **Few rules, deep consequences.** Small unit and resource sets; depth from positioning, timing and what you choose to give up.
* **Two layers that talk.** The between-mission layer shapes missions, and missions reshape the layer. The closer to the war's centre, the tighter the loop.
* **Escalation is the story.** Scale, tone and goals change act by act. Scores (escalation, civilian cost) appear only where they make sense.
* **A whole world from the first day.** The global map is open from the start: you may send anything anywhere, even where it makes no sense yet.
* **Both sides, equal chances.** Written neutrally. Neither bloc is the hero. The game shows what human hubris and inhuman decisions cost, whoever you play.
* **Realistically dark, with humour.** Humour is part of normal human life even in the worst of times, so it runs through the whole game. The results of the war are never a joke; living with them is.


## At a glance

| Aspect | Plan |
|---|---|
| Mode | Single-player campaign, either side; multiplayer later |
| Mission length | 30 to 60 minutes; about 10 to 20 planning turns |
| Learning curve | One evening: three orders at the start, new tools introduced act by act |
| Platforms | Installable Linux app first; Windows and macOS exports planned |
| Engine | Godot 4, a deterministic simulation core reused from the current project |
| IP | Original game, original names, art and text; real history and places as setting only |


# 1. The escalation ladder

| Act | Setting and scale | What a mission feels like | Strategic layer | Success measures |
|---|---|---|---|---|
| I Spies | Berlin, Vienna, London, Moscow, Geneva. City blocks, 4 to 8 agents | Infiltrate, meet, steal, vanish. Fog of war and timing, not firepower | Light: cover, contacts, budget set equipment and intel | Intel gained, cover intact, plausible deniability |
| II Border | Inner-German border, Baltic, Turkey. Platoons, 20 to 40 units | Patrols, checkpoints, recon in force, incidents that may or may not become wars | Posture, rules of engagement, diplomatic channel | Tension index (keep it down or push it up), territory |
| III Invasion | Fulda Gap and neighbours. Battalions to brigades, a moving front | Battles inside a campaign: breakthrough, hold, encircle. Either side may be the aggressor (a story branch) | Heavy and two-way: fuel, ammo, bridges, air cover, alliance cohesion, public opinion | Front line progress, supply state, allied cohesion |
| IV Threshold | Contested zones. The first nuclear use | Missions under a countdown: deny, seize or survive a launch decision | Escalation ladder and consent, politics dominate | Escalation index, who blinked |
| V Wasteland | Germany contaminated. Convoys, shelters, remnants | Survive, move, protect. Radiation zones act as terrain | Scarcity: fuel, medicine, morale, trust between survivors | People and supplies preserved |
| VI World | A Defcon-like world map. Stockpiles, launches, defences | Short, tense turns of days or hours. Choose targets, or choose not to | Almost all of the game is here | Civilian cost, survivors, time bought |
| VII Second Try | A launch site, a colony ship. Former enemies cooperate | Escort, defend, recruit, repair. Goals reverse: protect, not destroy | Trust becomes a resource that bridges the blocs | People saved, ship readiness, trust |

**Decisions:** the game has a **global map from the very first mission**. Any unit or asset can be sent anywhere, even where it seems pointless, so you can quietly secure things in remote corners (an Antarctic station, a Pacific atoll, a seed vault, fuel caches, a few aircraft, a scientist or two) that nobody else is watching. These long-term investments are the bridge to Act VII. **Branches** bend by degrees after every mission and every between-mission decision, so the Fulda Gap invasion can start from either side, or never in the form you expected. Both campaigns are mirrors in structure with different tools, and the stories are written neutrally: with no side decisively stronger, both end up in the same place, which is what 'equal chances' means here.


# 2. Two layers that talk to each other


## The strategic layer (between missions)

Four tracks, shown as a few glowing bars: **Supply** (fuel, ammo, spares), **Resolve** (morale and domestic politics), **Trust** (allies, and later enemies) and **Intel** (what you know before the mission). Each interlude gives a small number of _order slots_. You fill them with things like stockpile, reposition, negotiate, leak, mobilise, fund a programme, or hold back. Each choice has a clear, previewable effect on the next mission, so the layer is a puzzle and not a spreadsheet.


## How the layers change each other

* **Layer to mission:** low fuel means a unit starts with less movement range; poor intel means a Dark map and no enemy start positions; low trust means an ally unit that won't take orders.
* **Mission to layer:** casualties cut Resolve; ammunition fired comes out of Supply; a bridge kept intact opens a faster route and a better start next time; a civilian incident costs Trust.
* **Goals come from the layer:** a political decision can turn a plain 'destroy' mission into 'seize and hand over', or add a hostage the player must now consider.
* **Coupling grows with scale:** in Act I the layer only sets kit and intel. In Act III the front line on the map is the layer, and a mission is a battle inside it.


## The mission layer

* Both sides plan the same span of game time (minutes in Act I, hours in Act III, days in Act VI), preview with a copy of the game, commit, and watch the replay.
* Orders are few and consistent: route, hold, watch (an arc), engage, withdraw, and a special order per unit class.
* Each act adds one new tool at a time (e.g. smoke in Act I, artillery in Act II, supply convoys in Act III), so there is never a rule dump.
* The computer opponent uses the same planner as the player: it tests candidate plans against a copy of the game and picks the best.


# 3. Humour

Humour is part of the design, not decoration. It has three registers, and the game moves between them as the war escalates.


## Principles

* **Jokes come from institutions and people, never from the dead.** The results of the war are never joked about; dealing with the results is just part of the new world, and that can be funny and human.
* **As dark as it gets.** The darker the stakes, the drier the delivery. Act I is playful, Act IV is gallows humour, Act VI is black, Act VII is warm.
* **Enemies are people.** They have names, letters home and bad canteens. The game resists the official line on both sides, and the jokes are often at propaganda's expense.
* **The ending is sincere.** The last joke is on the idea that we needed a war to figure this out.
* **Humour carries information.** The funniest line in a briefing is usually also the useful one.


## In the gameplay

* **Plausible Deniability** is a spendable resource. Spend it to disown a failed operation, or you lose Trust. Running out is a joke and a problem.
* **Paperwork delay:** some strategic orders arrive late with a stamped note. A request for 40 tanks may return as '40 tents (approved)'. The delay is real, and always visible one turn ahead.
* **Cover identities** are generated, absurd and plausible: 'Herbert Kuchenbäcker, Cheese Inspector, Zurich'. Cover quality affects Act I missions.
* **Unit barks and equipment sheets** in a deadpan catalogue voice: 'Radio, Portable (Bulky)'. 'Binoculars, Allegedly.'
* **Event cards** between missions with small, mean choices: feed the rival's canary, or bribe the janitor with the good coffee.
* **Epitaphs:** named characters who fall get one deadpan line from the loss report.


## In the story: relaxed situations

* **Truce at the Vienna café:** rival agents share a table under a no-business rule and trade gossip; you can play for information or just enjoy the strudel.
* **Chess with the handler** in a London safe house, where each move is a briefing.
* **The ice rink in Moscow:** the dead-drop is a skate rental, and the real mission is to leave without falling over.
* **Mr. Hendricks from Accounting** audits your expenses in every act, even after the bombs, and is eventually the most necessary person alive.


## In the story: dark humour

* **The Contingency Binder:** three inches thick, 'In case of everything, see Appendix Z'. Appendix Z is blank.
* **The radio request line:** a cheerful DJ plays dedications during the Act VI countdown, and reads out the weather in places that no longer have any.
* **The civil-defence film narrator** keeps explaining how to stay calm, long after it stopped helping.
* **The colony-ship naming committee** and the seating chart dispute, settled by a coin toss between two armies who just stopped shooting each other.
* **Communiqués swapped:** the Statement of the Day from each bloc is word for word the same with the names exchanged. The game quietly puts them side by side.
* **Official Version / What the Sensors Say:** every briefing carries both. With enough Intel you see the second. It is rarely flattering and often funny.
* **The Ministry of Optimism** issues a weekly bulletin: 'Supplies are not low, merely ambitious.'
* **Intercepted chatter** from the other side is mundane and human: a sergeant composing a poem, a conscript arguing about the canteen. Capturing them is a decision, not a score.
* **Mandatory-fun officer** in the shelter schedules a talent show. Someone's grandmother wins it.
* **Casualty form 14-B** requires you to first submit form 14-A, which requires a casualty.


# 4. Maps and units change with the scale

The Frozen Synapse style (a close, extruded, glowing grid with individual figures) fits Act I. It cannot carry brigades, supply lines or a world. So the presentation changes with each act toward the conventions of operational wargames, while the **planning loop and the neon look stay the same** (plan together, preview, resolve, replay).

| Act | Map | Units shown as | Time per turn | What changes in the rules |
|---|---|---|---|---|
| I Spies | Close tactical grid of streets and buildings (the current style) | Individual figures with facing and stance | Minutes | Line of sight, cover, timing and noise |
| II Border | Tactical map with terrain: forest, towns, rivers, roads. Zoom between figure and counter view | Squads and platoons as small glowing counters, with figures when zoomed in | Hours | Terrain costs, roads, observation posts, artillery with spotting |
| III Invasion | Operational map (hexes or areas): terrain, rivers, bridges, cities, front line, zones of control | Battalion and brigade counters with original NATO-style symbols and strength steps; unknown contacts as '?' | Half a day to a day | Supply lines and depots, bridge capacity, air missions as a layer, aggregated deterministic combat |
| IV Threshold | Operational map plus contamination and launch-warning overlays | Counters and strategic assets | Hours | Escalation panel, no-go zones, consent of allies |
| V Wasteland | Ruined region map with routes, shelters, hot zones | Convoys, shelters and survivor groups | Days | Scarcity overlays (fuel, medicine, morale), radiation as terrain |
| VI World | Defcon-like vector world map | Silos, submarines, bombers, fighters, missiles with arcs | Hours to days | Stockpiles, launch timing, defence, countdown clock |
| VII Second Try | Launch-site map plus the world logistics map | Mixed | Hours to days | Trust, repair and escort, protect-not-destroy goals |


## Design rules for the larger scales

* **One visual language.** Counters, borders, supply lines and arrows are glowing vector shapes in the same neon style, so the game never looks like three different games.
* **Aggregated, deterministic combat.** A formation has a few strength steps, a supply state and a posture. The result depends on terrain, supply, surprise and posture, with no dice, so the preview is exact. The old ideas of 'stillness' and 'first sight' become dug-in, moving and ambushed.
* **Fog of war by contacts.** You see what your sensors see: confirmed positions, last-known positions and '?' counters. The Official Version / Sensors view from the humour section lives here.
* **Drill-down.** A decisive engagement can be opened as a close tactical view (the current style) and played, or resolved automatically. Results flow back to the operational map.
* **Plan in the same way.** Drawing a route, a front-line order, a supply route or a missile arc, then testing it on a copy of the game, is the same gesture at every scale.
* **Readability first.** A few unit types per act, large clear symbols, and a map that is usable in one evening of learning.


# 5. Campaign state, morale and consequences

**The rule:** every mission ends, and the story continues whatever the result. A mission is not won or lost in the usual sense. It changes the state of the war, and that state shapes the next mission. This is the idea behind games like Strike Commander: the more you lose, the worse your next starting point, and the more you win, the better your equipment, bases and support. The point is to show how brutal war is and how small things become large, not to let the player win.


## Mission results

| Grade | Meaning | Typical effect on the campaign |
|---|---|---|
| Decisive win | Objectives met cheaply | Morale up, better equipment, forward base, political support up |
| Win | Objectives met | Small gains in morale and support |
| Costly win | Objectives met at heavy loss | Gains, but forces, veterans and morale suffer; home front reacts |
| Draw / withdrawal | Objectives not met, force preserved | Little change; the enemy keeps the initiative |
| Defeat | Objectives failed, heavy loss | Forces and morale down, intel and supply lost, political pressure rises |
| Disaster | Force destroyed or surrounded | Reserves must be called up; support and morale collapse; the story goes on from the new situation |


## The persistent state (what carries over)

* **Forces:** surviving units, veterans, equipment and their condition. Losses stay lost until replaced.
* **Supply:** fuel, ammunition and spares, set by logistics decisions and earlier missions.
* **Intel:** what you know about the enemy, in partial and ageing form (see below).
* **Bases and access:** forward bases, safe houses, border crossings, air cover, earned or lost by results.
* **Morale** on three layers: unit morale, the home front and political support.
* **Reserves:** how many have been called up so far, and how weak the next wave is.


## Morale: three layers

| Layer | Moves with | Affects |
|---|---|---|
| Unit morale | Wins and losses, rest, rotation, food, mail, trust in command, orders that cost lives needlessly | How units behave in a mission (levels below) |
| Home front | Casualties, civilian harm, news, the mood in cities, strikes and protests | Reinforcements, rules of engagement, tension, how much the leadership will allow |
| Political support | Results, alliances, what the public learns, what is leaked | Air bases, allies, new equipment and, in later acts, access to nuclear options |


## What the home front reaches

* **Reinforcements:** how many come, and the morale, fitness and training they arrive with. A cheering home front sends confident men, a tired one sends resentful ones.
* **Rules of engagement:** a hostile press or protests restrict targets and tactics.
* **Field morale:** letters, news and rumours reach the front and move morale up or down.
* **Leave and rotation:** how often units can be pulled back to rest.
* **Procurement:** how fast new equipment arrives, and how reliable it is.
* **Intel and recruitment:** informants and volunteers come more easily with public support.
* **Political freedom:** how far leaders may go in later acts, including the nuclear options.
* **Hiding reality:** a calm or censored home front can mask what is happening; the Official Version and What the Sensors Say views show the gap.

Morale is a status detail of every unit, shown beside health, fuel and ammunition. For your own units it is known. For the enemy it is hidden unless your intel is good, though a shaken enemy shows signs (hanging back, slow reactions).


## How low morale changes behaviour

| Level | What happens in a mission |
|---|---|
| Steady | Normal behaviour |
| Shaken | Slightly delayed reaction and slightly less precise aim |
| Wavering | Late and poor execution; units reach 'about here' instead of the exact point; more missed shots |
| Cracking | Orders carried out only in part. Rarely, friendly fire when own units stand close to a target |
| Broken | Desertion and refusal of orders. In the worst cases a unit may switch sides to the enemy |

* **Deterministic:** every morale effect is decided from the mission seed, so the Test preview is still exact and a replay is always the same.
* **Visible:** friendly fire, refusals and desertions are shown plainly in the replay and never hidden.
* **Switching sides** is tied to the story (a political or ideological break), not only to low numbers, and happens to both sides equally.
* **Recovery:** morale can rise again with rest, supplies, a win, a trusted leader's order or good news, so a bad run is not permanent.


## Reserves: always available, always weaker

* There is always a chance to call up reserves, but each wave is weaker than the last: older men, boys, conscripts with little training or fitness.
* Each call-up lowers the ceilings for strength, accuracy and morale of the next wave, and the dossier says so plainly.
* Calling reserves also costs politically and on the home front.
* **The last strategic mission, Act VI, is always playable.** If only a hundred men over sixty remain, they can be given orders, but they cannot get away before the bombs drop. The play is what you choose to do while it happens. It is not scored as a win or a loss. Act VII is always possible by definition.


## Partial intel, shaped by the war

* Each fact about an enemy unit (type, strength, fuel, ammunition, crew, position, orders) has its own chance of being revealed, decided from the mission seed. No spy ever reveals everything: the cap is about 70%.
* Reveal quality improves as the enemy suffers losses, because there is less to hide, less guarding and more confusion.
* Uncertain facts show as ranges, and some intel can be disinformation. Intel ages each turn unless the source is kept alive.
* An early counter-espionage mission can end in four ways (you succeed or fail, they succeed or fail), and all four are played on.


## Veterancy

* A visible rank mark beside the unit and a line in its details.
* Veterans react faster, aim more steadily and break later on the morale scale.
* **They also give nearby units extra morale and fighting prowess.** This aura is visible: a small glow or mark around the veteran and the units it steadies.
* Losing a veteran costs the units beside it some morale. Veterans are hard to replace, because reserves arrive without experience.
* Veterancy is earned by surviving missions and winning fights, not by time served.


## Consequences are felt, not reported

* The effects of a mission outcome appear **only in the missions after it,** and are felt through play: how much you see of the enemy, how your units behave, what reinforcements and equipment arrive.
* The dossier does not show exact numbers for them. At most it uses plain words ('slightly', 'sharply'), and only in the next briefing.
* Example: after a failed spy operation your intel is simply thin in the next mission, and enemy ambushes land on weak points. The game does not announce how thin.


## Guard rails

* **Spiral protection:** a bad run must not make the game unplayable. Desperate defenders fight harder, allies step in when you are collapsing, and the enemy is under the same morale and supply pressure.
* **Symmetry:** both sides use the same system, so neither bloc is favoured.
* **Neutral tone:** the results of the war are never a joke. The Ministry of Optimism bulletins and casualty forms from the humour chapter report the state as spin, while the real numbers drive play.


## Decisions on this chapter

* Six result grades are fine; the player sees them by name.
* The home front reaches many variables (see above), not only supply and reinforcements.
* Veterancy is visible and gives nearby units extra morale and fighting prowess; the aura is shown on the map.
* Outcome effects are felt only in later missions and are not reported as exact numbers.


## Still open

* Exact scoring of the double spy mission's four outcomes (starting values to be tuned in play).
* How strongly the home front limits what the player may do, as opposed to how well things arrive.


# 6. Build, platforms and originality

* **Engine:** Godot 4 with a deterministic, integer-based simulation core reused from the current project: orders, preview on a copy, replay, fog of war, and the same style of automated tests.
* **New modules:** the strategic layer (tracks, order slots, effects as data), campaign state with branches, scale adapters for each act, and a longer-turn planner and AI.
* **Content as data:** missions, events, decisions and jokes in plain JSON, so they can be edited without touching code.
* **Platforms:** Linux first (AppImage and .deb), then Windows and macOS. A macOS build for other people's machines needs signing and notarisation with an Apple developer account, which has to be done on a Mac.
* **Originality:** the Cold War and real places are free to use. All names, art, text and audio are original, no trademarked titles are used, and weapon designations are generic or fictional. The current project (Cold Synapse) stays private; this is the game meant for the world.


## Roadmap (each step playable and tested)

| Step | Deliverable | What it proves |
|---|---|---|
| 0 | This document and the notes file | The idea is written down |
| 1 | One Berlin spy mission with long planning turns and fog of war | The planning loop works at a new scale |
| 2 | The strategic interlude with four tracks driving that mission | The two layers talk in both directions |
| 3 | A short Act I chain across two cities, with humour events and either side | Tone, branching and a mirror campaign |
| 4 | Act II border mission with 20 to 40 units and artillery | The system scales up |
| 5 | Act III prototype: a moving front, supply and an air layer | The tight coupling of the invasion |
| 6 | Acts IV to VII in outline, then in full | The whole arc |


## Decisions made by the project owner

* **Global map from the beginning,** with every location reachable, to allow securing units and assets in remote corners early.
* **Branches** change in varying degrees after each mission and each between-mission decision.
* **Tone:** realistically dark. The results of war are never joked about; dealing with them is fine. Humour everywhere else, as dark as it gets, always respecting life and the humanity of enemies, and resisting propaganda.
* **Map style by size:** FS-like squares for small maps, hexes in the style of operational wargames for large maps, to be worked out in between. **Drill-down** from the operational map to the close view: yes, in the first version.
* **Neutrality:** both sides get equal chances and, absent a decisive imbalance, end in the same situation. The point is the cost of hubris and inhuman decisions, not a message for one side.


## Still open

* Mid-size maps: where exactly FS-style squares hand over to Grigsby-style hexes. My suggestion: hexes that can be opened into a few sub-cells, so one map language covers the in-between scale.
* Visual style of the global map and strategic screens (reference pictures welcome; Frozen Synapse is enough for the tactical look).
* How historical to be: real events and dates, a close alternate history, or a fictional timeline with real places?
* How the player 'secures' remote assets in Act I: a small mini-game, a menu order, or a mission?
* Final title: keep 'Thin Ice'?

