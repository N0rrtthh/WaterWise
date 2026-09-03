extends RefCounted

## Bucket Brigade shared props for the beat tier.
## A flat-fill cartoon bucket in four parts, origin at the bucket's BASE
## (so it sits naturally on ground lines and in actors' prop slots).

const WOOD := Color(0.62, 0.42, 0.25)
const WOOD_DARK := Color(0.48, 0.31, 0.17)
const WATER := Color(0.5, 0.8, 1.0)

static func make_bucket(with_water := true) -> Node2D:
	var b := Node2D.new()
	b.name = "Bucket"

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-30, -46), Vector2(30, -46), Vector2(21, 0), Vector2(-21, 0),
	])
	body.color = WOOD
	b.add_child(body)

	var band := Polygon2D.new()
	band.name = "Band"
	band.polygon = PackedVector2Array([
		Vector2(-27, -34), Vector2(27, -34), Vector2(26, -26), Vector2(-26, -26),
	])
	band.color = WOOD_DARK
	b.add_child(band)

	if with_water:
		var w := Polygon2D.new()
		w.name = "Water"
		w.polygon = PackedVector2Array([
			Vector2(-27, -46), Vector2(27, -46), Vector2(26, -38), Vector2(-26, -38),
		])
		w.color = WATER
		b.add_child(w)

	var handle := Line2D.new()
	handle.name = "Handle"
	handle.width = 5.0
	handle.default_color = WOOD_DARK
	handle.points = PackedVector2Array([
		Vector2(-30, -46), Vector2(-20, -70), Vector2(0, -78),
		Vector2(20, -70), Vector2(30, -46),
	])
	b.add_child(handle)

	return b
