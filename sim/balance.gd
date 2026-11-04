extends RefCounted
## ALL tunable numbers live here. 20 ticks = 1 second; 100 ticks = one 5 s turn.
## Distances are milli-tiles (1000 = 1 tile). Angles in decidegrees.

const TICKS_PER_TURN := 100

## kind: direct (hitscan gun) | rocket | grenade
## react: ticks before the first shot once a target is acquired
## turn: decidegrees the unit can rotate per tick
## interval: ticks between shots
## chance_near / chance_far: hit chance per mille at distance 0 / at max range
## shield: half-arc (decidegrees) in which frontal direct fire is blocked (0 = none)
const TYPES := {
	"mg": {
		"name": "Machine Gun", "kind": "direct", "speed": 100, "range": 16000, "vision": 22000,
		"react": 8, "turn": 120, "interval": 6, "chance_near": 880, "chance_far": 420, "shield": 0,
	},
	"shotgun": {
		"name": "Shotgun", "kind": "direct", "speed": 120, "range": 6000, "vision": 22000,
		"react": 5, "turn": 150, "interval": 10, "chance_near": 980, "chance_far": 450, "shield": 0,
	},
	"sniper": {
		"name": "Sniper", "kind": "direct", "speed": 85, "range": 28000, "vision": 28000,
		"react": 22, "turn": 60, "interval": 40, "chance_near": 950, "chance_far": 800, "shield": 0,
	},
	"rocket": {
		"name": "Rocket Launcher", "kind": "rocket", "speed": 90, "range": 24000, "vision": 20000,
		"react": 14, "turn": 90, "interval": 0, "chance_near": 0, "chance_far": 0, "shield": 0,
	},
	"grenade": {
		"name": "Grenade Launcher", "kind": "grenade", "speed": 90, "range": 14000, "vision": 20000,
		"react": 12, "turn": 90, "interval": 0, "chance_near": 0, "chance_far": 0, "shield": 0,
	},
	# Expansion unit ("Red"-style pack)
	"riot": {
		"name": "Riot Shield", "kind": "direct", "speed": 80, "range": 5000, "vision": 20000,
		"react": 9, "turn": 100, "interval": 10, "chance_near": 700, "chance_far": 200, "shield": 700,
	},
}

const EXPLOSIVES := {
	"rocket": {"projectile_speed": 400, "radius": 2500, "wall_radius": 1800, "fuse": 0},
	"grenade": {"projectile_speed": 300, "radius": 3000, "wall_radius": 0, "fuse": 40},
}

const MOVING_AIM_NUM := 3         # aim time multiplier while moving = 3/2
const MOVING_AIM_DEN := 2
const MOVING_HIT_PERMILLE := 650  # hit chance multiplier while moving
const DUCKED_TARGET_PERMILLE := 850
const PREAIM_TOLERANCE := 200     # decidegrees: already aimed => react halved, no turn time
const DUCK_SPEED_PERMILLE := 500
