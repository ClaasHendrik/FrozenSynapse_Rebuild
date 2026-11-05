extends RefCounted
## Grid pathfinding (BFS, 8-way, no corner cutting) with line-of-walk path smoothing.

const Fx = preload("res://sim/fx.gd")
const FLOOR := 0

## True if a unit can walk the straight segment (0.25-tile clearance on both sides).
static func walk_clear(map, ax: int, ay: int, bx: int, by: int) -> bool:
	var dx: int = bx - ax
	var dy: int = by - ay
	var d: int = Fx.isqrt(dx * dx + dy * dy)
	if d == 0:
		return map.walkable(ax, ay)
	var px: int = -dy * 250 / d
	var py: int = dx * 250 / d
	var steps: int = d / 200 + 1
	for i in range(steps + 1):
		var x: int = ax + dx * i / steps
		var y: int = ay + dy * i / steps
		if not (map.walkable(x, y) and map.walkable(x + px, y + py) and map.walkable(x - px, y - py)):
			return false
	return true

## Returns waypoints [{x,y}] (milli-tiles) from start to end, or [] if unreachable.
static func find_path(map, sx: int, sy: int, ex: int, ey: int) -> Array:
	var stx: int = sx / Fx.TILE
	var sty: int = sy / Fx.TILE
	var etx: int = ex / Fx.TILE
	var ety: int = ey / Fx.TILE
	if map.tile(stx, sty) != FLOOR or map.tile(etx, ety) != FLOOR:
		return []
	if walk_clear(map, sx, sy, ex, ey):
		return [{"x": ex, "y": ey}]
	var w: int = map.w
	var prev := PackedInt32Array()
	prev.resize(w * map.h)
	prev.fill(-2)
	var start: int = sty * w + stx
	var goal: int = ety * w + etx
	var queue: Array = [start]
	prev[start] = -1
	var head := 0
	var dirs := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
	while head < queue.size() and prev[goal] == -2:
		var cur: int = queue[head]
		head += 1
		var cx: int = cur % w
		var cy: int = cur / w
		for d in dirs:
			var nx: int = cx + d[0]
			var ny: int = cy + d[1]
			if map.tile(nx, ny) != FLOOR:
				continue
			if d[0] != 0 and d[1] != 0 and (map.tile(cx + d[0], cy) != FLOOR or map.tile(cx, cy + d[1]) != FLOOR):
				continue
			var ni: int = ny * w + nx
			if prev[ni] == -2:
				prev[ni] = cur
				queue.append(ni)
	if prev[goal] == -2:
		return []
	var tiles: Array = []
	var c: int = goal
	while c != -1:
		tiles.append(c)
		c = prev[c]
	tiles.reverse()
	var pts: Array = [[sx, sy]]
	for i in range(1, tiles.size()):
		pts.append([(tiles[i] % w) * Fx.TILE + 500, (tiles[i] / w) * Fx.TILE + 500])
	pts[pts.size() - 1] = [ex, ey]
	var out: Array = []
	var i2 := 0
	var last: int = pts.size() - 1
	while i2 < last:
		var j: int = last
		while j > i2 + 1 and not walk_clear(map, pts[i2][0], pts[i2][1], pts[j][0], pts[j][1]):
			j -= 1
		out.append({"x": pts[j][0], "y": pts[j][1]})
		i2 = j
	return out
