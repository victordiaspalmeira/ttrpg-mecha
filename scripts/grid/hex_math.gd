class_name HexMath
extends RefCounted

## Shared axial hex helpers (pointy-top, Y-up world).

static func axial_distance(q_a: int, r_a: int, q_b: int, r_b: int) -> int:
	var dq: int = q_a - q_b
	var dr: int = r_a - r_b
	var ds: int = (-q_a - r_a) - (-q_b - r_b)
	return maxi(abs(dq), maxi(abs(dr), abs(ds)))


static func axial_distance_tiles(tile_a: HexTile, tile_b: HexTile) -> int:
	if tile_a == null or tile_b == null:
		return 0
	return axial_distance(tile_a.q, tile_a.r, tile_b.q, tile_b.r)


static func axial_to_world(q: int, r: int, hex_size: float) -> Vector3:
	var x: float = hex_size * sqrt(3.0) * (float(q) + float(r) * 0.5)
	var z: float = hex_size * 1.5 * float(r)
	return Vector3(x, 0.0, z)


static func world_to_axial(world: Vector3, hex_size: float) -> Vector2i:
	if hex_size <= 0.0:
		return Vector2i.ZERO

	var q: float = (sqrt(3.0) / 3.0 * world.x - 1.0 / 3.0 * world.z) / hex_size
	var r: float = (2.0 / 3.0 * world.z) / hex_size
	return axial_round(q, r)


static func axial_round(qf: float, rf: float) -> Vector2i:
	var sf: float = -qf - rf
	var q: int = roundi(qf)
	var r: int = roundi(rf)
	var s: int = roundi(sf)

	var q_diff: float = absf(q - qf)
	var r_diff: float = absf(r - rf)
	var s_diff: float = absf(s - sf)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s

	return Vector2i(q, r)
