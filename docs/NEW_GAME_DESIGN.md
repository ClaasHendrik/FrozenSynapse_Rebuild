# THIN ICE (working title): design document, draft 1

_A Cold War campaign that escalates from spy games to the end of the world, and then asks whether we could just stop._

**Executive summary.** A single-player strategy campaign, playable from NATO or Warsaw Pact, that grows from a handful of agents in Berlin to a world on fire, and ends with former enemies launching one small colony ship together. The tactical heart is the same idea as the current project: both sides plan the same stretch of time at once, you preview your plan, then watch it resolve deterministically. Between missions, a light strategic layer (supply, resolve, trust, intel) changes what the next mission looks like and is changed by how it went. It is built to be learned in an evening, to be funny in an increasingly dark way, and to be an original game that can be shown to the world.


## Design pillars

* **Plan together, resolve together.** Simultaneous planning, a preview you can trust, a replay you can learn from. At every scale.
* **Few rules, deep consequences.** Small unit and resource sets; depth from positioning, timing and what you choose to give up.
* **Two layers that talk.** The between-mission layer shapes missions, and missions reshape the layer. The closer to the war's centre, the tighter the loop.
* **Escalation is the story.** Scale, tone and goals change act by act. Scores (escalation, civilian cost) appear only where they make sense.
* **Dark humour with a heart.** The jokes come from bureaucracy and human foibles, grow darker with the stakes, and the ending is sincere.


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

Which side starts the Fulda Gap invasion is decided by the story, not fixed: earlier choices in Acts I and II (and which side you play) tip it either way, so it can surprise you. Each side's campaign is a mirror in structure but not in tools: NATO leans on alliance cohesion and air power, the Pact on discipline and mass, and each has its own jokes.


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

* **Jokes come from institutions and people, never from victims.** Bureaucracy, committees, paperwork, politicians' vanity, gadgets that were over-promised.
* **The darker the stakes, the drier the delivery.** Act I is playful, Act IV is gallows humour, Act VII is warm.
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


# 4. Build, platforms and originality

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


## Open questions

* How much of the strategic layer should be a map and how much cards and menus?
* How fixed is the story, and how much can the player bend it? (My proposal: fixed set pieces with branches.)
* How dark should Act VI go, and how should the civilian cost be shown? (My proposal: shown plainly, never as a joke.)
* Which side should the very first campaign be written for?
* Should the humour also be added to the current project's own-missions pack (Blackout)?

