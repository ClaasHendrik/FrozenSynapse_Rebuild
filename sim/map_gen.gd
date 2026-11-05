extends RefCounted
## Procedural map generator: BSP rooms + corridors with door gaps, then low-wall cover.
## Deterministic for a given seed. Returns a "layout" dictionary (see generate()).

const Rng = preload("res://sim/rng.gd")
const MIN_ROOM := 4

static func generate(w: int = 32, h: int = 20, seed_value: int = 1, attacker: int = 0) -> Dictionary:
	for attempt in range(300):
		var rng = Rng.new(seed_value + attempt * 7919)
		var g := PackedByteArray()
		g.resize(w * h)
		for x in range(w):
			g[x] = 1
			g[(h - 1) * w + x] = 1
		for y in range(h):
			g[y * w] = 1
			g[y * w + w - 1] = 1
		_split(g, w, 1, 1, w - 2, h - 2, rng, [], [])
		if not _connected(g, w, h):
			continue
		_decorate(g, w, h, rng)
		var layout := _layout(g, w, h, rng, attacker)
		if not layout.is_empty():
			return layout
	push_error("map generation failed; using open fallback")
	var g2 := PackedByteArray()
	g2.resize(w * h)
	for y in range(h):
		for x in range(w):
			g2[y * w + x] = 1 if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else 0
	return _layout(g2, w, h, Rng.new(seed_value), attacker)

static func _near(arr: Array, v: int) -> bool:
	for a in arr:
		if absi(a - v) <= 1:
			return true
	return false

static func _within(arr: Array, lo: int, hi: int) -> Array:
	var out: Array = []
	for a in arr:
		if a >= lo and a <= hi:
			out.append(a)
	return out

static func _split(g: PackedByteArray, w: int, x0: int, y0: int, x1: int, y1: int, rng, fr: Array, fc: Array) -> void:
	var rw: int = x1 - x0 + 1
	var rh: int = y1 - y0 + 1
	var can_v: bool = rw >= 2 * MIN_ROOM + 1
	var can_h: bool = rh >= 2 * MIN_ROOM + 1
	if not can_v and not can_h:
		return
	if rw * rh < 90 and rng.below(100) < 40:
		return
	var vertical: bool
	if can_v and can_h:
		var ratio: int = rw * 10 / rh
		vertical = ratio > 12 or (ratio >= 8 and rng.below(2) == 0)
	else:
		vertical = can_v
	if vertical:
		var c := -1
		for i in range(8):
			var cand: int = x0 + MIN_ROOM + rng.below(rw - 2 * MIN_ROOM)
			if not _near(fc, cand):
				c = cand
				break
		if c < 0:
			return
		for y in range(y0, y1 + 1):
			g[y * w + c] = 1
		var rows: Array = [y0 + rng.below(rh)]
		if rh >= 8 and rng.below(100) < 60:
			var r2: int = y0 + rng.below(rh)
			if absi(r2 - rows[0]) >= 3:
				rows.append(r2)
		for r in rows:
			g[r * w + c] = 0
		_split(g, w, x0, y0, c - 1, y1, rng, fr + rows, _within(fc, x0, c - 1))
		_split(g, w, c + 1, y0, x1, y1, rng, fr + rows, _within(fc, c + 1, x1))
	else:
		var c2 := -1
		for i in range(8):
			var cand2: int = y0 + MIN_ROOM + rng.below(rh - 2 * MIN_ROOM)
			if not _near(fr, cand2):
				c2 = cand2
				break
		if c2 < 0:
			return
		for x in range(x0, x1 + 1):
			g[c2 * w + x] = 1
		var cols: Array = [x0 + rng.below(rw)]
		if rw >= 8 and rng.below(100) < 60:
			var c3: int = x0 + rng.below(rw)
			if absi(c3 - cols[0]) >= 3:
				cols.append(c3)
		for cc in cols:
			g[c2 * w + cc] = 0
		_split(g, w, x0, y0, x1, c2 - 1, rng, _within(fr, y0, c2 - 1), fc + cols)
		_split(g, w, x0, c2 + 1, x1, y1, rng, _within(fr, c2 + 1, y1), fc + cols)

static func _connected(g: PackedByteArray, w: int, h: int) -> bool:
	var total := 0
	var start := -1
	for i in range(w * h):
		if g[i] == 0:
			total += 1
			if start < 0:
				start = i
	if start < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array = [start]
	seen[start] = 1
	var count := 0
	while not stack.is_empty():
		var i: int = stack.pop_back()
		count += 1
		var x: int = i % w
		var y: int = i / w
		for n in [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]:
			if n[0] < 0 or n[1] < 0 or n[0] >= w or n[1] >= h:
				continue
			var j: int = n[1] * w + n[0]
			if g[j] == 0 and seen[j] == 0:
				seen[j] = 1
				stack.append(j)
	return count == total

static func _decorate(g: PackedByteArray, w: int, h: int, rng) -> void:
	var attempts: int = w * h / 14
	for a in range(attempts):
		var x: int = 4 + rng.below(w - 8)
		var y: int = 1 + rng.below(h - 2)
		if g[y * w + x] != 0:
			continue
		var horiz := false
		var next_to_wall := false
		if g[(y - 1) * w + x] == 1 or g[(y + 1) * w + x] == 1:
			horiz = true
			next_to_wall = true
		elif g[y * w + x - 1] == 1 or g[y * w + x + 1] == 1:
			next_to_wall = true
		if not next_to_wall:
			continue
		var length: int = 1 + rng.below(3)
		var placed: Array = []
		for k in range(length):
			var tx: int = x + (k if horiz else 0)
			var ty: int = y + (0 if horiz else k)
			if tx >= w - 4 or ty >= h - 1 or g[ty * w + tx] != 0:
				break
			g[ty * w + tx] = 2
			placed.append(ty * w + tx)
		if not placed.is_empty():
			# LOW tiles count as non-floor for connectivity
			if not _connected(g, w, h):
				for i in placed:
					g[i] = 0

static func _shuffle(arr: Array, rng) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.below(i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

static func _pick_spaced(cands: Array, count: int, spacing: int, rng) -> Array:
	_shuffle(cands, rng)
	var out: Array = []
	for c in cands:
		var ok := true
		for o in out:
			if absi(o[0] - c[0]) + absi(o[1] - c[1]) < spacing:
				ok = false
				break
		if ok:
			out.append(c)
			if out.size() >= count:
				break
	return out

static func _layout(g: PackedByteArray, w: int, h: int, rng, attacker: int) -> Dictionary:
	var rows: Array = []
	for y in range(h):
		var row := ""
		for x in range(w):
			var v: int = g[y * w + x]
			row += "#" if v == 1 else ("o" if v == 2 else ".")
		rows.append(row)
	var def_right: bool = attacker == 0
	var floor_in := func(xa: int, xb: int) -> Array:
		var out: Array = []
		for y in range(1, h - 1):
			for x in range(xa, xb + 1):
				if g[y * w + x] == 0:
					out.append([x, y])
		return out
	var spawn0: Array = _pick_spaced(floor_in.call(1, 4), 12, 2, rng)
	var spawn1: Array = _pick_spaced(floor_in.call(w - 5, w - 2), 12, 2, rng)
	if spawn0.size() < 8 or spawn1.size() < 8:
		return {}
	# 3x3 all-floor rectangle on the defender side for the Secure zone
	var zone_cands: Array = []
	var zx0: int = w * 11 / 20 if def_right else w * 4 / 20
	var zx1: int = w * 16 / 20 if def_right else w * 9 / 20
	for y in range(1, h - 3):
		for x in range(zx0, zx1 + 1):
			var ok := true
			for dy in range(3):
				for dx in range(3):
					if g[(y + dy) * w + x + dx] != 0:
						ok = false
			if ok:
				zone_cands.append([x, y])
	if zone_cands.is_empty():
		return {}
	var zc: Array = zone_cands[rng.below(zone_cands.size())]
	# 3x3 all-floor square near the middle of the map (hostage start square)
	var cz_cands: Array = []
	for y in range(1, h - 3):
		for x in range(w * 8 / 20, w * 11 / 20 + 1):
			var ok2 := true
			for dy in range(3):
				for dx in range(3):
					if g[(y + dy) * w + x + dx] != 0:
						ok2 = false
			if ok2:
				cz_cands.append([x, y])
	var boxes: Array = _pick_spaced(floor_in.call(w / 3, w * 2 / 3), 3, 4, rng)
	if boxes.size() < 3 or cz_cands.is_empty():
		return {}
	var cz: Array = cz_cands[rng.below(cz_cands.size())]
	var hostages: Array = [[cz[0], cz[1] + 1], [cz[0] + 2, cz[1] + 1]]
	return {
		"w": w, "h": h, "rows": rows, "attacker": attacker,
		"spawn": {0: spawn0, 1: spawn1},
		"zone": [zc[0], zc[1], zc[0] + 2, zc[1] + 2],
		"boxes": boxes, "hostages": hostages,
		"center_zone": [cz[0], cz[1], cz[0] + 2, cz[1] + 2],
		"exits": {0: [1, 1, 2, h - 2], 1: [w - 3, 1, w - 2, h - 2]},
	}
