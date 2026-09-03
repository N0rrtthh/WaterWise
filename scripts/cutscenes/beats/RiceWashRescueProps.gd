extends RefCounted

## Rice Wash Rescue shared props for the beat tier.
## Flat-fill kitchen set: rice bowl with a tweenable rice mound, a burlap
## rice bag, the Mayor's plate, feast chairs, and single grains.
##
## Colours taken from the minigame: cream bg, wood counter, basin blue,
## rice white.

const RICE := Color(0.95, 0.95, 0.9)
const RICE_SHADOW := Color(0.86, 0.86, 0.80)
const BOWL := Color(0.3, 0.5, 0.7)
const BOWL_RIM := Color(0.4, 0.6, 0.8)
const BAG := Color(0.75, 0.62, 0.42)
const BAG_DARK := Color(0.62, 0.50, 0.32)
const WOOD := Color(0.5, 0.35, 0.25)
const WOOD_DARK := Color(0.42, 0.29, 0.20)
const PLATE := Color(0.97, 0.97, 0.95)
const SHINE := Color(1.0, 1.0, 1.0, 0.85)
const CHAIR := Color(0.68, 0.50, 0.34)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A rice bowl. Origin BASE-CENTRE. The "Rice" child is a mound that
## scales up from the bowl rim; keep it at ~0.01 until the payoff.
static func make_bowl(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Bowl"
	var body := Polygon2D.new()
	body.name = "Body"
	var pts := PackedVector2Array()
	for i in range(12):
		var a := PI * float(i) / 11.0  # lower half-ellipse
		pts.append(Vector2(cos(a) * size * 0.5, -sin(a) * size * 0.42))
	body.polygon = pts
	body.color = BOWL
	root.add_child(body)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = _ellipse(size * 0.5, size * 0.10, 14)
	rim.position = Vector2(0.0, -size * 0.42)
	rim.color = BOWL_RIM
	root.add_child(rim)
	var rice := Polygon2D.new()
	rice.name = "Rice"
	rice.polygon = PackedVector2Array([
		Vector2(-size * 0.44, 0.0), Vector2(-size * 0.20, -size * 0.30),
		Vector2(0.0, -size * 0.40), Vector2(size * 0.20, -size * 0.30),
		Vector2(size * 0.44, 0.0),
	])
	rice.position = Vector2(0.0, -size * 0.42)
	rice.color = RICE
	rice.scale = Vector2(1.0, 0.01)
	root.add_child(rice)
	# Shine bar, hidden until the win payoff sweeps it across.
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.polygon = PackedVector2Array([
		Vector2(-size * 0.05, 0.0), Vector2(size * 0.05, 0.0),
		Vector2(size * 0.18, -size * 0.5), Vector2(size * 0.08, -size * 0.5),
	])
	shine.position = Vector2(-size * 0.65, -size * 0.42)
	shine.color = SHINE
	shine.visible = false
	root.add_child(shine)
	return root

## A burlap rice bag. Origin BASE-CENTRE; tips over by rotating the root.
static func make_bag(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Bag"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.26, 0.0), Vector2(size * 0.26, 0.0),
		Vector2(size * 0.30, -size * 0.55), Vector2(size * 0.12, -size * 0.72),
		Vector2(-size * 0.12, -size * 0.72), Vector2(-size * 0.30, -size * 0.55),
	])
	body.color = BAG
	root.add_child(body)
	var neck := Polygon2D.new()
	neck.name = "Neck"
	neck.polygon = _ellipse(size * 0.12, size * 0.05, 10)
	neck.position = Vector2(0.0, -size * 0.72)
	neck.color = BAG_DARK
	root.add_child(neck)
	var tie := Polygon2D.new()
	tie.name = "Tie"
	tie.polygon = _ellipse(size * 0.15, size * 0.045, 10)
	tie.position = Vector2(0.0, -size * 0.66)
	tie.color = Color(0.85, 0.80, 0.60)
	root.add_child(tie)
	# Side seam shading.
	var shade := Polygon2D.new()
	shade.name = "Shade"
	shade.polygon = PackedVector2Array([
		Vector2(size * 0.10, -size * 0.04), Vector2(size * 0.26, -size * 0.04),
		Vector2(size * 0.29, -size * 0.54), Vector2(size * 0.13, -size * 0.70),
		Vector2(size * 0.10, -size * 0.70),
	])
	shade.color = BAG_DARK
	root.add_child(shade)
	return root

## A single rice grain. Origin CENTRE.
static func make_grain(size: float, rot: float = 0.0) -> Polygon2D:
	var grain := Polygon2D.new()
	grain.name = "Grain"
	grain.polygon = _ellipse(size * 0.55, size * 0.22, 8)
	grain.rotation = rot
	grain.color = RICE
	return grain

## The Mayor's dinner plate. Origin BASE-CENTRE.
static func make_plate(size: float) -> Polygon2D:
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = _ellipse(size * 0.5, size * 0.16, 16)
	plate.color = PLATE
	return plate

## A kitchen counter table. Origin BASE-CENTRE.
static func make_table(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Table"
	var top := Polygon2D.new()
	top.name = "Top"
	top.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height), Vector2(width * 0.5, -height),
		Vector2(width * 0.5, -height + height * 0.16),
		Vector2(-width * 0.5, -height + height * 0.16),
	])
	top.color = WOOD
	root.add_child(top)
	for x in [-0.38, 0.38]:
		var leg := Polygon2D.new()
		leg.name = "Leg"
		leg.polygon = PackedVector2Array([
			Vector2(width * x - width * 0.025, -height * 0.84),
			Vector2(width * x + width * 0.025, -height * 0.84),
			Vector2(width * x + width * 0.025, 0.0),
			Vector2(width * x - width * 0.025, 0.0),
		])
		leg.color = WOOD_DARK
		root.add_child(leg)
	return root

## A feast chair. Origin BASE-CENTRE, facing right.
static func make_chair(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Chair"
	var seat := Polygon2D.new()
	seat.name = "Seat"
	seat.polygon = PackedVector2Array([
		Vector2(-size * 0.30, -size * 0.34), Vector2(size * 0.30, -size * 0.34),
		Vector2(size * 0.30, -size * 0.24), Vector2(-size * 0.30, -size * 0.24),
	])
	seat.color = CHAIR
	root.add_child(seat)
	var back := Polygon2D.new()
	back.name = "Back"
	back.polygon = PackedVector2Array([
		Vector2(-size * 0.30, -size * 0.34), Vector2(-size * 0.18, -size * 0.34),
		Vector2(-size * 0.18, -size * 0.85), Vector2(-size * 0.30, -size * 0.85),
	])
	back.color = CHAIR
	root.add_child(back)
	for x in [-0.24, 0.24]:
		var leg := Polygon2D.new()
		leg.name = "Leg"
		leg.polygon = PackedVector2Array([
			Vector2(size * x - 2.5 * size * 0.1, -size * 0.24),
			Vector2(size * x + 2.5 * size * 0.1, -size * 0.24),
			Vector2(size * x + 2.5 * size * 0.1, 0.0),
			Vector2(size * x - 2.5 * size * 0.1, 0.0),
		])
		leg.color = CHAIR.darkened(0.15)
		root.add_child(leg)
	return root

## Steam wisps rising from a bowl. Continuous GPUParticles2D.
static func make_steam(tex: Texture2D) -> GPUParticles2D:
	var s := GPUParticles2D.new()
	s.name = "Steam"
	s.amount = 14
	s.lifetime = 1.1
	s.local_coords = false
	s.texture = tex
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 14.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 120.0
	m.gravity = Vector3(0, -40, 0)
	m.scale_min = 0.6
	m.scale_max = 1.3
	m.color = Color(1.0, 1.0, 1.0, 0.5)
	s.process_material = m
	s.emitting = false
	return s

## A scatter burst of rice grains. One-shot; call `restart()`/`emitting`.
static func make_grain_burst(count: int, speed: float, tex: Texture2D) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = "GrainBurst"
	p.amount = count
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.texture = tex
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 70.0
	m.initial_velocity_min = speed * 0.5
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, 900, 0)
	m.scale_min = 0.35
	m.scale_max = 0.7
	m.color = RICE
	p.process_material = m
	p.emitting = false
	return p

