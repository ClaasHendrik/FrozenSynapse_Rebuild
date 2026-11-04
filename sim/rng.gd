extends RefCounted
## Tiny xorshift32 RNG: identical on every machine, state is one integer.

var s: int = 2463534242

func _init(seed_value: int = 1) -> void:
	s = (seed_value * 2654435761 + 1) & 0xFFFFFFFF
	if s == 0:
		s = 2463534242

func next_u32() -> int:
	s ^= (s << 13) & 0xFFFFFFFF
	s ^= (s >> 17)
	s ^= (s << 5) & 0xFFFFFFFF
	s &= 0xFFFFFFFF
	return s

func below(n: int) -> int:
	return next_u32() % n
