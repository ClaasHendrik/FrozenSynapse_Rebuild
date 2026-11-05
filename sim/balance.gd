extends RefCounted
## ALL tunable numbers live here. 20 ticks = 1 second (50 ms per tick); 100 ticks = one 5 s turn.
## Distances are milli-tiles (1000 = 1 tile). Angles in decidegrees. Times in ms unless noted.
##
## kind: direct (auto-fires) | rocket | grenade | none
## base / slope: time-to-kill (ms) = base + slope * distance/range   (adjacent -> max range)
## turn: ms added for a 180 degree turn (scaled by the actual angle)
## fov: half field-of-view in decidegrees (used for sighting / fog of war)
## anim: launch animation in ticks; cooldown: ticks between launches
## shield: half-arc (decidegrees) of bulletproof frontal shield while standing still (0 = none)

const TICKS_PER_TURN := 100
const MS_PER_TICK := 50
const SIGHT_RANGE := 60000

const TYPES := {
	"mg": {
		"name": "Machine Gun", "kind": "direct", "speed": 100, "range": 24000, "fov": 600,
		"base": 320, "slope": 2300, "turn": 128, "anim": 0, "cooldown": 0, "shield": 0,
	},
	"shotgun": {
		"name": "Shotgun", "kind": "direct", "speed": 125, "range": 6500, "fov": 600,
		"base": 320, "slope": 520, "turn": 32, "anim": 0, "cooldown": 0, "shield": 0,
	},
	"sniper": {
		"name": "Sniper", "kind": "direct", "speed": 85, "range": 60000, "fov": 750,
		"base": 1600, "slope": 650, "turn": 352, "anim": 0, "cooldown": 0, "shield": 0,
	},
	"rocket": {
		"name": "Rocket Launcher", "kind": "rocket", "speed": 90, "range": 80000, "fov": 600,
		"base": 0, "slope": 0, "turn": 100, "anim": 13, "cooldown": 100, "shield": 0,
	},
	"grenade": {
		"name": "Grenade Launcher", "kind": "grenade", "speed": 90, "range": 14000, "fov": 600,
		"base": 0, "slope": 0, "turn": 100, "anim": 16, "cooldown": 84, "shield": 0,
	},
	# Expansion unit ("Red"-style pack)
	"riot": {
		"name": "Riot Shield", "kind": "none", "speed": 80, "range": 0, "fov": 600,
		"base": 0, "slope": 0, "turn": 0, "anim": 0, "cooldown": 0, "shield": 600,
	},
	"hacker": {
		"name": "Hacker", "kind": "none", "speed": 100, "range": 0, "fov": 600,
		"base": 0, "slope": 0, "turn": 0, "anim": 0, "cooldown": 0, "shield": 0,
	},
	# Campaign-only units
	"commando": {
		"name": "Commando", "kind": "direct", "speed": 175, "range": 6500, "fov": 600,
		"base": 240, "slope": 480, "turn": 24, "anim": 0, "cooldown": 0, "shield": 0,
	},
	"devastator": {
		"name": "Devastator", "kind": "rocket", "speed": 160, "range": 80000, "fov": 600,
		"base": 0, "slope": 0, "turn": 60, "anim": 8, "cooldown": 14, "shield": 0,
	},
	# Neutral (team 2): unarmed
	"hostage": {
		"name": "Hostage", "kind": "none", "speed": 100, "range": 0, "fov": 450,
		"base": 0, "slope": 0, "turn": 0, "anim": 0, "cooldown": 0, "shield": 0,
	},
	"civilian": {
		"name": "Civilian", "kind": "none", "speed": 100, "range": 0, "fov": 450,
		"base": 0, "slope": 0, "turn": 0, "anim": 0, "cooldown": 0, "shield": 0,
	},
}

## radius: blast radius; wall_radius: terrain destroyed (tile centres within); speed: milli/tick (rocket)
const EXPLOSIVES := {
	"rocket": {"projectile_speed": 400, "radius": 3000, "wall_radius": 2000, "fuse": 0},
	"grenade": {"projectile_speed": 0, "radius": 3000, "wall_radius": 0, "fuse": 60},
}

# time-to-kill multipliers (per mille)
const STILL_PERMILLE := 1000
const AIMING_MOVE_PERMILLE := 1350
const MOVING_PERMILLE := 1800
const UNAWARE_PERMILLE := 2200      # engaged by someone who sighted you first and you're not facing them
const COVER_FAR_PERMILLE := 2000    # shooter at least 2x as far from the cover as the target
const COVER_MID_PERMILLE := 1300
const AIM_CONE := 300               # decidegrees: facing within this of the target = "aiming at it"
const STANCE_LOCK_TICKS := 10       # 0.5 s no-fire after changing stance
const AIM_MOVE_SPEED_PERMILLE := 700
const DUCK_SPEED_PERMILLE := 500
const BURST_EVENT_EVERY := 5        # visual-only shot events while engaged
