extends RefCounted

## Spot The Speck shared props for the beat tier.
## Flat-fill glassware set: drinking glasses with a dirty/clean water fill,
## speck blotches, the hovering magnifying glass, the wooden table, and
## falling speck dots.
##
## Colours taken from the minigame: cool blue-white bg, wood table,
## translucent glass, murky vs clear water, brown specks.

const BG := Color(0.9, 0.95, 1.0)
const WOOD := Color(0.55, 0.35, 0.2)
const WOOD_DARK := Color(0.46, 0.29, 0.16)
const GLASS := Color(0.8, 0.9, 1.0, 0.3)
const GLASS_RIM := Color(0.7, 0.8, 0.9, 0.5)
const WATER_DIRTY := Color(0.4, 0.55, 0.7, 0.8)
const WATER_CLEAR := Color(0.4, 0.7, 0.95, 0.8)
const SPECK := Color(0.3, 0.2, 0.1, 0.7)
const SHINE := Color(1.0, 1.0, 1.0, 0.55)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A drinking glass. Origin BASE-CENTRE. `dirty` picks the murky water
## and seeds the speck blotches; "Water" scales down for empty glasses.
static func make_glass(size: float, dirty: bool) -> Node2D:
	var root := Node2D.new()
	root.name = "Glass"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.26, 0.0), Vector2(size * 0.26, 0.0),
		Vector2(size * 0.32, -size * 0.8), Vector2(-size * 0.32, -size * 0.8),
	])
	body.color = GLASS
	root.add_child(body)
	var water := Polygon2D.new()
	water.name = "Water"
	water.polygon = PackedVector2Array([
		Vector2(-size * 0.245, 0.0), Vector2(size * 0.245, 0.0),
		Vector2(size * 0.30, -size * 0.62), Vector2(-size * 0.30, -size * 0.62),
	])
	water.color = WATER_DIRTY if dirty else WATER_CLEAR
	water.scale = Vector2(1.0, 1.0)
	root.add_child(water)
	# Speck blotches on the inside wall.
	if dirty:
		var specks := Node2D.new()
		specks.name = "Specks"
		for spot in [
			[Vector2(-size * 0.14, -size * 0.24), 5.0],
			[Vector2(size * 0.10, -size * 0.40), 7.0],
			[Vector2(size * 0.02, -size * 0.12), 4.0],
		]:
			var speck := Polygon2D.new()
			speck.name = "Speck"
			speck.polygon = _ellipse(size * spot[1] * 0.045, size * spot[1] * 0.045, 8)
			speck.position = spot[0]
			speck.color = SPECK
			specks.add_child(speck)
		root.add_child(specks)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = _ellipse(size * 0.32, size * 0.07, 14)
	rim.position = Vector2(0.0, -size * 0.8)
	rim.color = GLASS_RIM
	root.add_child(rim)
	# Vertical highlight stripe.
	var highlight := Polygon2D.new()
	highlight.name = "Highlight"
	highlight.polygon = PackedVector2Array([
		Vector2(-size * 0.20, -size * 0.06), Vector2(-size * 0.13, -size * 0.06),
		Vector2(-size * 0.16, -size * 0.70), Vector2(-size * 0.23, -size * 0.70),
	])
	highlight.color = SHINE
	root.add_child(highlight)
	return root

## A magnifying glass. Origin at the LENS CENTRE; handle hangs down-right.
static func make_magnifier(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Magnifier"
	var lens := Polygon2D.new()
	lens.name = "Lens"
	lens.polygon = _ellipse(size * 0.30, size * 0.30, 18)
	lens.color = Color(0.75, 0.88, 1.0, 0.28)
	root.add_child(lens)
	var ring := Polygon2D.new()
	ring.name = "Ring"
	ring.polygon = _ellipse(size * 0.32, size * 0.32, 18)
	ring.color = Color(0.35, 0.37, 0.42)
	root.add_child(ring)
	var inner := Polygon2D.new()
	inner.name = "Inner"
	inner.polygon = _ellipse(size * 0.28, size * 0.28, 18)
	inner.color = Color(0.8, 0.9, 1.0, 0.35)
	root.add_child(inner)
	# Lens glint.
	var glint := Polygon2D.new()
	glint.name = "Glint"
	glint.polygon = _ellipse(size * 0.07, size * 0.045, 8)
	glint.position = Vector2(-size * 0.10, -size * 0.12)
	glint.rotation = -0.5
	glint.color = Color(1.0, 1.0, 1.0, 0.85)
	root.add_child(glint)
	# Handle.
	var handle := Polygon2D.new()
	handle.name = "Handle"
	handle.polygon = PackedVector2Array([
		Vector2(-size * 0.035, size * 0.30), Vector2(size * 0.035, size * 0.30),
		Vector2(size * 0.06, size * 0.72), Vector2(-size * 0.005, size * 0.76),
	])
	handle.color = Color(0.45, 0.30, 0.18)
	root.add_child(handle)
	return root

## A single falling speck dot. Origin CENTRE.
static func make_speck(size: float) -> Polygon2D:
	var speck := Polygon2D.new()
	speck.name = "Speck"
	speck.polygon = _ellipse(size * 0.5, size * 0.42, 8)
	speck.rotation = randf() * PI
	speck.color = SPECK
	return speck

## The wooden table. Origin BASE-CENTRE.
static func make_table(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Table"
	var top := Polygon2D.new()
	top.name = "Top"
	top.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height), Vector2(width * 0.5, -height),
		Vector2(width * 0.5, -height + height * 0.18),
		Vector2(-width * 0.5, -height + height * 0.18),
	])
	top.color = WOOD
	root.add_child(top)
	for x in [-0.38, 0.38]:
		var leg := Polygon2D.new()
		leg.name = "Leg"
		leg.polygon = PackedVector2Array([
			Vector2(width * x - width * 0.028, -height * 0.82),
			Vector2(width * x + width * 0.028, -height * 0.82),
			Vector2(width * x + width * 0.028, 0.0),
			Vector2(width * x - width * 0.028, 0.0),
		])
		leg.color = WOOD_DARK
		root.add_child(leg)
	return root
