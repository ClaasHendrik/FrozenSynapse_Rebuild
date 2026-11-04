extends RefCounted
## Integer math helpers. All sim positions are integers in "milli-tiles"
## (1 tile = 1000). Angles are integers in decidegrees (0..3599, 0 = +x, 900 = +y).

const TILE := 1000

static var _atan_table: PackedInt32Array = PackedInt32Array()

static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x: int = int(sqrt(float(n)))
	while x * x > n:
		x -= 1
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x

static func _build_table() -> void:
	_atan_table.resize(1025)
	for i in range(1025):
		# decidegrees; table is built once, rounding hides any libm ulp differences
		_atan_table[i] = int(round(atan(float(i) / 1024.0) * 1800.0 / PI))

## Angle of vector (dx, dy) in decidegrees, 0..3599.
static func atan2_dd(dy: int, dx: int) -> int:
	if dx == 0 and dy == 0:
		return 0
	if _atan_table.is_empty():
		_build_table()
	var ax: int = absi(dx)
	var ay: int = absi(dy)
	var mn: int = mini(ax, ay)
	var mx: int = maxi(ax, ay)
	var a: int = _atan_table[mn * 1024 / mx]
	if ay > ax:
		a = 900 - a
	if dx < 0:
		a = 1800 - a
	if dy < 0:
		a = 3600 - a
	return posmod(a, 3600)

## Smallest absolute difference between two angles, 0..1800.
static func angle_diff(a: int, b: int) -> int:
	var d: int = posmod(b - a, 3600)
	if d > 1800:
		d = 3600 - d
	return d

static func dist(ax: int, ay: int, bx: int, by: int) -> int:
	var dx: int = bx - ax
	var dy: int = by - ay
	return isqrt(dx * dx + dy * dy)
