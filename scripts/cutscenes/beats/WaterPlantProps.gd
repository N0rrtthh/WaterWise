extends RefCounted

## Water Plant shared props for the beat tier (#24).
## Colours lifted from res://scenes/minigames/WaterPlant.gd: sky blue,
## dirt ground, grass strip. Potted plants and blooms come from
## ThirstyPlantProps.gd; this file adds the watering can and petals.

const SKY := Color(0.55, 0.82, 1.0)
const DIRT := Color(0.45, 0.32, 0.18)
const GRASS := Color(0.35, 0.65, 0.25)
const CAN := Color(0.42, 0.6, 0.62)
const WATER := Color(0.3, 0.6, 1.0, 0.7)
const PETAL_PINK := Color(0.95, 0.45, 0.6)
const PETAL_LIGHT := Color(0.95, 0.75, 0.85)
const PETAL_GOLD := Color(0.95, 0.85, 0.3)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## The watering can. Origin BASE-CENTRE (can bottom). "Fill" is the
## blue disc at the spout mouth — shown only while there is water.
static func make_watering_can(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "WateringCan"
	# The spout angles up-left from the body; the rose caps its mouth.
	var spout := Polygon2D.new()
	spout.name = "Spout"
	spout.polygon = PackedVector2Array([
		Vector2(-size * 0.28, -size * 0.44), Vector2(-size * 0.60, -size * 0.72),
		Vector2(-size * 0.52, -size * 0.82), Vector2(-size * 0.20, -size * 0.54),
	])
	spout.color = CAN
	root.add_child(spout)
	var rose := Polygon2D.new()
	rose.name = "Rose"
	rose.polygon = _ellipse(size * 0.10, size * 0.10)
	rose.position = Vector2(-size * 0.57, -size * 0.78)
	rose.color = CAN.darkened(0.2)
	root.add_child(rose)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = _ellipse(size * 0.07, size * 0.07)
	fill.position = rose.position
	fill.color = WATER
	fill.visible = false
	root.add_child(fill)
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.30, 0.0), Vector2(size * 0.30, 0.0),
		Vector2(size * 0.36, -size * 0.62), Vector2(-size * 0.36, -size * 0.62),
	])
	body.color = CAN
	root.add_child(body)
	# The top carry-handle, an arc over the lid.
	var handle := Line2D.new()
	handle.name = "Handle"
	handle.width = size * 0.05
	handle.default_color = CAN.darkened(0.25)
	var arc := PackedVector2Array()
	for i in range(9):
		var a := PI - PI * float(i) / 8.0
		arc.append(Vector2(cos(a) * size * 0.30, -size * 0.62 + sin(a) * size * 0.22))
	handle.points = arc
	root.add_child(handle)
	# The side grip handle.
	var grip := Polygon2D.new()
	grip.name = "Grip"
	grip.polygon = PackedVector2Array([
		Vector2(size * 0.32, -size * 0.52), Vector2(size * 0.46, -size * 0.46),
		Vector2(size * 0.44, -size * 0.38), Vector2(size * 0.30, -size * 0.42),
	])
	grip.color = CAN.darkened(0.15)
	root.add_child(grip)
	return root

## A single loose petal for the rain. Origin CENTRE.
static func make_petal(size: float, color: Color) -> Polygon2D:
	var petal := Polygon2D.new()
	petal.name = "Petal"
	petal.polygon = _ellipse(size * 0.5, size * 0.28, 10)
	petal.color = color
	return petal
