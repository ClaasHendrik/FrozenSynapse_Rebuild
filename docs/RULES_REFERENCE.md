# Rules reference (from the community wiki at fs.error420.com, read 2026-11-05)

Our own paraphrase, used as the design target for `sim/`. Mission names/story are lightly renamed in `campaign/`.

## Combat (deterministic, no hit chances)
- Direct-fire units auto-engage enemies in line of sight + engagement range. Kill happens when the
  *time-to-kill* (TTK) elapses; losing LOS resets it. Bilateral fights: only one side can land the kill.
- TTK factors: unit type, distance, cover, stillness (still < aiming while moving < full-speed moving),
  first sight (the unit that sighted first wins ties), turn delay, 0.5 s no-fire delay after a stance change.
- Base kill time ms (adjacent): MG 320, Shotgun 320, Sniper 1600. Turn delay (180°) ms: MG 128, SG 32, SN 352.
- Ranges: MG long (slightly shorter than a Charge map), Shotgun short (16 vs MG 75), Sniper unlimited,
  Grenade 35, Rocket unlimited. Field of view about 120° (snipers wider). LOS blocked by full walls; ducked units
  cannot see/be seen over half walls. Standing units can see over half walls but a target behind one gets a TTK bonus
  (only if the shooter is >= 2x as far from the cover as the target).
- Ignore / Focus / Continue-on-Sight orders. Aiming while moving reduces speed.
- Indirect fire only on command. Grenade: 0.8 s launch, detonates 3 s after launch, bounces off walls, cooldown 4.2 s,
  does not destroy terrain. Rocket: 0.65 s launch, cooldown 5 s, flies in a straight line and explodes on the first full
  wall (flies on over half walls unless the launcher was ducked; flies away harmlessly off the map edge), destroys terrain.
  Same blast radius for both. Half walls block blasts partly (standing) or fully (ducked, from the far side).
- Riot Shield (Red): no weapon; bulletproof shield in its facing direction while standing still; bounces grenades;
  rockets explode on it; no protection from explosions.
- Campaign-only: Commando (very fast shotgun), Devastator (very fast rocket launcher, several shots per turn),
  civilians (unarmed).

## Modes (default turn limits in brackets)
- Extermination [8]: 10/kill, -10/loss, +-20 wipeout, -1 x initial unit difference.
- Secure [6 Light / 12 Dark]: bid on a zone size; bid winner defends (deploys in the zone). Attacker wins by surviving
  3 s in the zone after the first 2 turns, or by wiping out the defender. Score 50 + up to 150 + up to 50 by bid size.
- Disputed [16]: fixed deployment; boxes appear at the end of turn 4 and edge extraction zones activate (any unit entering
  is extracted). Box counts only when its carrier is extracted; carrier dies = box lost. 30 points per box; a side wiped out
  or extracted ends the game and remaining boxes go to the other. Wipe-out before turn 4 end = 140 points.
- Hostage [8]: hostages start in a small square mid-map and cannot be killed inside it; rescuer deploys at an edge and can
  order hostages from turn 2; once a hostage leaves the square its escape path is fixed. Rescuer wins if a hostage reaches
  an exit or all enemies die; taker wins by killing the hostages. Score 50 (2 escape) / 25 (1) / -40 (0).
- Charge [6]: both bid a line; the further bid attacks. Attacker needs a unit on or past the line for the last 3 s of turn 6
  (or wipes out the defender earlier). Score = 200 x bid fraction.
- Upload (Red expansion) [8]: each side has a hacker; kill the enemy hacker. (Not documented on the wiki: our own design.)
- Dark mode: enemies only seen with LOS; initial enemy positions shown in Extermination/Disputed; projectiles and corpses
  always shown.

## Campaign
55 missions in 19 chapters (Nashar, Power Plant, The Studio, Blue Sunlight, Cairn Habitat, Novena, Ninstar, Dillinger,
Base 77, Devastator, Brightling, Brightling Core, Brightling Conclusion, Terman Bank, Open Warfare, Finding Nix,
Glass Tower, Endgame, Mandala). Hints exist for about half of the missions; the rest are designed from chapter context.
