extends RefCounted

## Wring It Out shared props for the beat tier (#25).
## Colours lifted from res://scenes/minigames/WringItOut.gd: pale sky,
## rope brown, wet-vs-dry shirt blues, translucent water, wood basin.

const BG := Color(0.9, 0.95, 1.0)
const ROPE := Color(0.4, 0.3, 0.2)
const WET := Color(0.3, 0.5, 0.9)
const DRY := Color(0.5, 0.7, 1.0)
const WATER := Color(0.3, 0.6, 1.0, 0.8)
const BASIN := Color(0.6, 0.4, 0.2)
const BASIN_DARK := Color(0.48, 0.31, 0.14)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A T-shirt, matching the minigame's polygon. Origin TOP-CENTRE (the
## shoulder line, where it hangs from the line).
static func make_shirt(size: float, color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "Shirt"
	var body := Polygon2D.new()
	body.name = "Body"
	var k := size / 160.0
	body.polygon = PackedVector2Array([
		Vector2(-80, -100) * k, Vector2(-40, -100) * k,
		Vector2(-40, -60) * k, Vector2(40, -60) * k,
		Vector2(40, -100) * k, Vector2(80, -100) * k,
		Vector2(80, -40) * k, Vector2(50, -40) * k,
		Vector2(50, 100) * k, Vector2(-50, 100) * k,
		Vector2(-50, -40) * k, Vector2(-80, -40) * k,
	])
	body.color = color
	root.add_child(body)
	return root

## The laundry basin: trapezoid tub from the minigame plus a water
## surface and a heaped laundry lump. Origin TOP-CENTRE.
static func make_basin(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Basin"
	var tub := Polygon2D.new()
	tub.name = "Tub"
	tub.polygon = PackedVector2Array([
		Vector2(-size * 0.5, 0.0), Vector2(size * 0.5, 0.0),
		Vector2(size * 0.4, size * 0.3), Vector2(-size * 0.4, size * 0.3),
	])
	tub.color = BASIN
	root.add_child(tub)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-size * 0.54, -size * 0.02), Vector2(size * 0.54, -size * 0.02),
		Vector2(size * 0.5, size * 0.06), Vector2(-size * 0.5, size * 0.06),
	])
	rim.color = BASIN_DARK
	root.add_child(rim)
	var water := Polygon2D.new()
	water.name = "Water"
	water.polygon = _ellipse(size * 0.44, size * 0.05)
	water.position = Vector2(0.0, size * 0.02)
	water.color = WATER
	root.add_child(water)
	var lump := Polygon2D.new()
	lump.name = "Laundry"
	lump.polygon = _ellipse(size * 0.3, size * 0.09)
	lump.position = Vector2(0.0, -size * 0.04)
	lump.color = WET
	root.add_child(lump)
	return root

## A diamond water drop. Origin CENTRE.
static func make_drop(size: float) -> Polygon2D:
	var drop := Polygon2D.new()
	drop.name = "Drop"
	drop.polygon = PackedVector2Array([
		Vector2(0.0, -size * 0.5), Vector2(size * 0.38, 0.0),
		Vector2(0.0, size * 0.5), Vector2(-size * 0.38, 0.0),
	])
	drop.color = WATER
	return drop
