extends RefCounted

const FIELDS := [
	"id", "team", "type", "x", "y", "facing", "alive", "ducked", "moving", "extracted",
	"path", "wp_i", "wait_left", "aim_lock", "aim_x", "aim_y", "ignore", "focus", "cos",
	"fires", "fire_i", "anim_left", "anim_order", "fire_cd",
	"pending_duck", "stance_lock", "target", "progress", "unaware", "turn_ms",
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
var extracted: bool = false
var path: Array = []          # [{x,y,wait,duck,aim_x,aim_y}] aim_* optional (-1 = none)
var wp_i: int = 0
var wait_left: int = 0
var aim_lock: bool = false
var aim_x: int = 0
var aim_y: int = 0
var ignore: Array = []        # unit ids this unit will not engage
var focus: Array = []         # if non-empty: engage only these ids
var cos: bool = false         # continue on sight: never engage
var fires: Array = []         # explosive orders [{x,y,tick}]
var fire_i: int = 0
var anim_left: int = 0
var anim_order: Dictionary = {}
var fire_cd: int = 0
var pending_duck: int = -1    # -1 none, 0 stand, 1 duck (applied at tick 1)
var stance_lock: int = 0
var target: int = -1
var progress: int = 0         # kill progress, 1,000,000 = kill shot
var unaware: bool = false
var turn_ms: int = 0

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
