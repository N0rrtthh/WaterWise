extends RefCounted

## Rainwater Harvesting shared props for the beat tier.
## Flat-fill rain set: storm cloud with dot-texture rain jets, harvest
## barrels with a tweenable "Fill" water level, and the single shared rope.
##
## Colours: storm grey cloud, wood-stave barrels, the project water blue.

const CLOUD := Color(0.62, 0.66, 0.72)
const CLOUD_DARK := Color(0.52, 0.56, 0.63)
const RAIN := Color(0.45, 0.70, 0.95, 0.85)
const WOOD := Color(0.62, 0.45, 0.28)
const WOOD_DARK := Color(0.50, 0.35, 0.20)
const HOOP := Color(0.40, 0.42, 0.46)
const WATER := Color(0.30, 0.60, 1.00, 0.85)
const WATER_SOFT := Color(0.55, 0.78, 1.00, 0.6)
const ROPE := Color(0.78, 0.68, 0.48)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A puffy rain cloud. Origin CENTRE.
static func make_cloud(width: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Cloud"
	var puffs := [
		[Vector2(-width * 0.30, 0.0), width * 0.22, CLOUD_DARK],
		[Vector2(width * 0.28, 0.02), width * 0.24, CLOUD_DARK],
		[Vector2(0.0, -width * 0.10), width * 0.30, CLOUD],
	]
	for i in range(puffs.size()):
		var puff := Polygon2D.new()
		puff.name = "Puff%d" % i
		puff.polygon = _ellipse(puffs[i][1], puffs[i][1] * 0.78, 14)
		puff.position = puffs[i][0]
		puff.color = puffs[i][2]
		root.add_child(puff)
	return root

## A rain jet: continuous GPUParticles2D aimed straight down, using the
## stage's dot texture. Scale the node to intensify the downpour.
static func make_rain(size: float, tex: Texture2D) -> GPUParticles2D:
	var r := GPUParticles2D.new()
	r.name = "Rain"
	r.amount = 30
	r.lifetime = 0.6
	r.local_coords = false
	r.texture = tex
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = size * 0.9
	m.direction = Vector3(0, 1, 0)
	m.spread = 6.0
	m.initial_velocity_min = 420.0 * size
	m.initial_velocity_max = 620.0 * size
	m.gravity = Vector3(0, 500, 0)
	m.scale_min = 0.3
	m.scale_max = 0.7
	m.color = RAIN
	r.process_material = m
	r.emitting = true
	return r

## A harvest barrel with a water level. Origin BASE-CENTRE. The "Fill"
## child scales up from the base to show the barrel filling.
static func make_barrel(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Barrel"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.34, 0.0), Vector2(size * 0.34, 0.0),
		Vector2(size * 0.40, -size * 0.72), Vector2(-size * 0.40, -size * 0.72),
	])
	body.color = WOOD
	root.add_child(body)
	# Vertical stave seams.
	for x in [-0.16, 0.0, 0.16]:
		var stave := Polygon2D.new()
		stave.name = "Stave"
		stave.polygon = PackedVector2Array([
			Vector2(size * x - 2.0, -size * 0.04), Vector2(size * x + 2.0, -size * 0.04),
			Vector2(size * x * 1.18 + 2.0, -size * 0.68), Vector2(size * x * 1.18 - 2.0, -size * 0.68),
		])
		stave.color = WOOD_DARK
		root.add_child(stave)
	# Metal hoops.
	for y in [0.08, 0.36, 0.64]:
		var hoop := Polygon2D.new()
		hoop.name = "Hoop"
		var half_w: float = size * (0.34 + 0.06 * (y as float))
		hoop.polygon = PackedVector2Array([
			Vector2(-half_w, -size * y - 3.0), Vector2(half_w, -size * y - 3.0),
			Vector2(half_w, -size * y + 3.0), Vector2(-half_w, -size * y + 3.0),
		])
		hoop.color = HOOP
		root.add_child(hoop)
	# Water fill: rises from the barrel base.
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(-size * 0.32, 0.0), Vector2(size * 0.32, 0.0),
		Vector2(size * 0.32, -1.0), Vector2(-size * 0.32, -1.0),
	])
	fill.position = Vector2(0.0, -size * 0.05)
	fill.color = WATER
	fill.scale = Vector2(1.0, 0.01)
	root.add_child(fill)
	# Rim ellipse on top.
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = _ellipse(size * 0.40, size * 0.09, 12)
	rim.position = Vector2(0.0, -size * 0.72)
	rim.color = WOOD_DARK
	root.add_child(rim)
	return root

## A single shared rope. Origin at the ANCHOR (top end); the bottom end is
## at `length` below. Reweave `polygon` each frame to track a hanging pair.
static func make_rope(length: float, thickness: float) -> Polygon2D:
	var rope := Polygon2D.new()
	rope.name = "Rope"
	rope.polygon = PackedVector2Array([
		Vector2(-thickness * 0.5, 0.0), Vector2(thickness * 0.5, 0.0),
		Vector2(thickness * 0.5, length), Vector2(-thickness * 0.5, length),
	])
	rope.color = ROPE
	return rope

## A rope loop / harness band wrapped around a hanging character's middle.
## Origin CENTRE; parent it to follow the character.
static func make_harness(width: float) -> Polygon2D:
	var band := Polygon2D.new()
	band.name = "Harness"
	band.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -4.0), Vector2(width * 0.5, -4.0),
		Vector2(width * 0.5, 4.0), Vector2(-width * 0.5, 4.0),
	])
	band.color = ROPE.darkened(0.1)
	return band
