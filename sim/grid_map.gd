extends RefCounted
## Tile map. Tiles: FLOOR walkable; WALL blocks everything; LOW blocks movement and
## blocks sight only when one of the two parties is ducked.

const Fx = preload("res://sim/fx.gd")

const FLOOR := 0
const WALL := 1
const LOW := 2

var w: int = 0
var h: int = 0
var t: PackedByteArray = PackedByteArray()

static func from_rows(rows: Array) -> RefCounted:
	var m = load("res://sim/grid_map.gd").new()
	m.h = rows.size()
	m.w = 0
	for r in rows:
		m.w = maxi(m.w, String(r).length())
	m.t.resize(m.w * m.h)
	for y in range(m.h):
		var row: String = rows[y]
		for x in range(m.w):
			var c: String = row[x] if x < row.length() else "#"
			m.t[y * m.w + x] = WALL if c == "#" else (LOW if c == "o" else FLOOR)
	return m

func tile(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return WALL
	return t[ty * w + tx]

func at_pos(x: int, y: int) -> int:
	if x < 0 or y < 0:
		return WALL
	return tile(x / Fx.TILE, y / Fx.TILE)

func walkable(x: int, y: int) -> bool:
	return at_pos(x, y) == FLOOR

## Line of sight between two points (milli-tiles).
func los(ax: int, ay: int, bx: int, by: int, low_blocks: bool) -> bool:
	var dx: int = bx - ax
	var dy: int = by - ay
	var d: int = Fx.isqrt(dx * dx + dy * dy)
	if d == 0:
		return true
	var steps: int = d / 250 + 1
	for i in range(1, steps):
		var k: int = at_pos(ax + dx * i / steps, ay + dy * i / steps)
		if k == WALL:
			return false
		if k == LOW and low_blocks:
			return false
	return true

## Turn WALL/LOW tiles whose centre is within r of (cx,cy) into floor. Returns [[tx,ty],...].
func destroy_in_radius(cx: int, cy: int, r: int) -> Array:
	var out: Array = []
	var tx0: int = maxi(0, (cx - r) / Fx.TILE - 1)
	var tx1: int = mini(w - 1, (cx + r) / Fx.TILE + 1)
	var ty0: int = maxi(0, (cy - r) / Fx.TILE - 1)
	var ty1: int = mini(h - 1, (cy + r) / Fx.TILE + 1)
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if t[ty * w + tx] == FLOOR:
				continue
			# keep the outer boundary intact
			if tx == 0 or ty == 0 or tx == w - 1 or ty == h - 1:
				continue
			if Fx.dist(cx, cy, tx * Fx.TILE + 500, ty * Fx.TILE + 500) <= r:
				t[ty * w + tx] = FLOOR
				out.append([tx, ty])
	return out

func duplicate_map() -> RefCounted:
	var m = load("res://sim/grid_map.gd").new()
	m.w = w
	m.h = h
	m.t = t.duplicate()
	return m
