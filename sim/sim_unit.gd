extends RefCounted

const FIELDS := [
	"id", "team", "type", "x", "y", "facing", "alive", "ducked", "moving",
	"path", "wp_i", "wait_left", "aim_lock", "aim_x", "aim_y", "ignore",
	"fire_order", "fired", "fire_timer", "target", "aim_timer", "cooldown",
]

var id: int = 0
var team: int = 0
var type: String = "mg"
var x: int = 0
var y: int = 0
var facing: int = 0
var alive: bool = true
var ducked: bool = false
var moving: bool = false
var path: Array = []          # [{x,y,wait,duck,aim_x,aim_y}] aim_* optional (-1 = none)
var wp_i: int = 0
var wait_left: int = 0
var aim_lock: bool = false
var aim_x: int = 0
var aim_y: int = 0
var ignore: Array = []        # unit ids this unit will not shoot at
var fire_order: Dictionary = {}  # {x,y,tick}
var fired: bool = false
var fire_timer: int = -1
var target: int = -1
var aim_timer: int = 0
var cooldown: int = 0

func to_dict() -> Dictionary:
	var d := {}
	for f in FIELDS:
		var v = get(f)
		d[f] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return d

static func from_dict(d: Dictionary) -> RefCounted:
	var u = load("res://sim/sim_unit.gd").new()
	for f in FIELDS:
		var v = d[f]
		u.set(f, v.duplicate(true) if (v is Array or v is Dictionary) else v)
	return u
