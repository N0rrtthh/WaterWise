extends RefCounted

## Scrub To Save shared props for the beat tier.
## Flat-fill kitchen-sink set: a dish with a tweenable "Grime" layer and a
## hidden mirror "Shine", a running faucet, the judge's clipboard, soap
## bubbles, the gold scrub-brush trophy, and the grease chute.
##
## Colours taken from the minigame: warm paper bg, steel sink, white plate,
## brown grime.

const BG := Color(0.95, 0.92, 0.88)
const SINK := Color(0.85, 0.85, 0.9)
const SINK_RIM := Color(0.7, 0.7, 0.75)
const PLATE := Color(0.95, 0.95, 0.98)
const GRIME := Color(0.4, 0.3, 0.2, 0.7)
const WATER := Color(0.45, 0.70, 0.95, 0.8)
const WOOD := Color(0.5, 0.35, 0.25)
const WOOD_DARK := Color(0.42, 0.29, 0.20)
const GOLD := Color(1.0, 0.82, 0.24)
const GOLD_DARK := Color(0.85, 0.65, 0.14)
const GREASE := Color(0.35, 0.28, 0.18, 0.85)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## The dish under judgment. Origin BASE-CENTRE. The "Grime" child scales
## down when scrubbed; the "Shine" bar sweeps on the win.
static func make_dish(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Dish"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _ellipse(size * 0.5, size * 0.16, 18)
	body.position = Vector2(0.0, -size * 0.08)
	body.color = PLATE
	root.add_child(body)
	var well := Polygon2D.new()
	well.name = "Well"
	well.polygon = _ellipse(size * 0.32, size * 0.09, 14)
	well.position = Vector2(0.0, -size * 0.12)
	well.color = SINK_RIM
	root.add_child(well)
	# Grime blotches, grouped so the whole layer can be scaled away.
	var grime := Node2D.new()
	grime.name = "Grime"
	for blot in [
		[Vector2(-size * 0.20, -size * 0.14), size * 0.12],
		[Vector2(size * 0.10, -size * 0.06), size * 0.16],
		[Vector2(size * 0.26, -size * 0.16), size * 0.09],
		[Vector2(0.0, -size * 0.20), size * 0.08],
	]:
		var spot := Polygon2D.new()
		spot.name = "Spot"
		spot.polygon = _ellipse(blot[1], blot[1] * 0.75, 10)
		spot.position = blot[0]
		spot.rotation = randf() * PI
		spot.color = GRIME
		grime.add_child(spot)
	root.add_child(grime)
	# Mirror shine bar, hidden until the win payoff.
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.polygon = PackedVector2Array([
		Vector2(-size * 0.045, -size * 0.02), Vector2(size * 0.045, -size * 0.02),
		Vector2(size * 0.16, -size * 0.30), Vector2(size * 0.07, -size * 0.30),
	])
	shine.position = Vector2(-size * 0.7, -size * 0.14)
	shine.color = Color(1.0, 1.0, 1.0, 0.9)
	shine.visible = false
	root.add_child(shine)
	return root

## A sink block with a running faucet. Origin BASE-CENTRE.
static func make_sink(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Sink"
	var basin := Polygon2D.new()
	basin.name = "Basin"
	basin.polygon = PackedVector2Array([
		Vector2(-size * 0.5, 0.0), Vector2(size * 0.5, 0.0),
		Vector2(size * 0.42, -size * 0.34), Vector2(-size * 0.42, -size * 0.34),
	])
	basin.color = SINK
	root.add_child(basin)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-size * 0.52, -size * 0.34), Vector2(size * 0.52, -size * 0.34),
		Vector2(size * 0.52, -size * 0.42), Vector2(-size * 0.52, -size * 0.42),
	])
	rim.color = SINK_RIM
	root.add_child(rim)
	# Faucet: riser + curved spout rendered as two boxes.
	var riser := Polygon2D.new()
	riser.name = "Riser"
	riser.polygon = PackedVector2Array([
		Vector2(-size * 0.03, -size * 0.42), Vector2(size * 0.03, -size * 0.42),
		Vector2(size * 0.03, -size * 0.78), Vector2(-size * 0.03, -size * 0.78),
	])
	riser.color = SINK_RIM
	root.add_child(riser)
	var spout := Polygon2D.new()
	spout.name = "Spout"
	spout.polygon = PackedVector2Array([
		Vector2(-size * 0.03, -size * 0.78), Vector2(size * 0.26, -size * 0.78),
		Vector2(size * 0.26, -size * 0.72), Vector2(-size * 0.03, -size * 0.72),
	])
	spout.color = SINK_RIM
	root.add_child(spout)
	# Running water: a thin wobbling stream from the spout mouth.
	var stream := Polygon2D.new()
	stream.name = "Stream"
	stream.polygon = PackedVector2Array([
		Vector2(-2.0 * size * 0.04, -size * 0.72), Vector2(2.0 * size * 0.04, -size * 0.72),
		Vector2(2.0 * size * 0.04, 0.0), Vector2(-2.0 * size * 0.04, 0.0),
	])
	stream.position = Vector2(size * 0.26, 0.0)
	stream.color = WATER
	root.add_child(stream)
	return root

## The judge's clipboard. Origin CENTRE.
static func make_clipboard(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Clipboard"
	var board := Polygon2D.new()
	board.name = "Board"
	board.polygon = PackedVector2Array([
		Vector2(-size * 0.30, -size * 0.42), Vector2(size * 0.30, -size * 0.42),
		Vector2(size * 0.30, size * 0.42), Vector2(-size * 0.30, size * 0.42),
	])
	board.color = WOOD
	root.add_child(board)
	var paper := Polygon2D.new()
	paper.name = "Paper"
	paper.polygon = PackedVector2Array([
		Vector2(-size * 0.24, -size * 0.34), Vector2(size * 0.24, -size * 0.34),
		Vector2(size * 0.24, size * 0.36), Vector2(-size * 0.24, size * 0.36),
	])
	paper.color = Color(0.97, 0.97, 0.94)
	root.add_child(paper)
	# Checkmark rows, drawn as short strokes.
	for i in range(4):
		var row := Polygon2D.new()
		row.name = "Row"
		var y := -size * 0.24 + size * 0.15 * float(i)
		row.polygon = PackedVector2Array([
			Vector2(-size * 0.16, y), Vector2(size * 0.16, y),
			Vector2(size * 0.16, y + size * 0.045), Vector2(-size * 0.16, y + size * 0.045),
		])
		row.color = Color(0.6, 0.6, 0.65)
		root.add_child(row)
	var clip := Polygon2D.new()
	clip.name = "Clip"
	clip.polygon = PackedVector2Array([
		Vector2(-size * 0.10, -size * 0.48), Vector2(size * 0.10, -size * 0.48),
		Vector2(size * 0.10, -size * 0.36), Vector2(-size * 0.10, -size * 0.36),
	])
	clip.color = SINK_RIM
	root.add_child(clip)
	return root

## The gold scrub-brush trophy. Origin BASE-CENTRE.
static func make_trophy(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Trophy"
	# Bristle block.
	var bristles := Polygon2D.new()
	bristles.name = "Bristles"
	bristles.polygon = PackedVector2Array([
		Vector2(-size * 0.22, 0.0), Vector2(size * 0.22, 0.0),
		Vector2(size * 0.22, -size * 0.26), Vector2(-size * 0.22, -size * 0.26),
	])
	bristles.color = GOLD_DARK
	root.add_child(bristles)
	# Bristle tips.
	for i in range(4):
		var tip := Polygon2D.new()
		tip.name = "Tip"
		var x := -size * 0.16 + size * 0.105 * float(i)
		tip.polygon = PackedVector2Array([
			Vector2(x, 0.0), Vector2(x + size * 0.07, 0.0),
			Vector2(x + size * 0.035, size * 0.09),
		])
		tip.color = GOLD_DARK
		root.add_child(tip)
	# Handle sweeping up to a knob.
	var handle := Polygon2D.new()
	handle.name = "Handle"
	handle.polygon = PackedVector2Array([
		Vector2(-size * 0.07, -size * 0.26), Vector2(size * 0.07, -size * 0.26),
		Vector2(size * 0.10, -size * 0.62), Vector2(-size * 0.10, -size * 0.62),
	])
	handle.color = GOLD
	root.add_child(handle)
	var knob := Polygon2D.new()
	knob.name = "Knob"
	knob.polygon = _ellipse(size * 0.15, size * 0.13, 12)
	knob.position = Vector2(0.0, -size * 0.72)
	knob.color = GOLD
	root.add_child(knob)
	var gleam := Polygon2D.new()
	gleam.name = "Gleam"
	gleam.polygon = PackedVector2Array([
		Vector2(-size * 0.02, -size * 0.30), Vector2(size * 0.02, -size * 0.30),
		Vector2(size * 0.05, -size * 0.58), Vector2(size * 0.01, -size * 0.58),
	])
	gleam.color = Color(1.0, 1.0, 1.0, 0.8)
	root.add_child(gleam)
	return root

## Soap bubbles. Continuous GPUParticles2D drifting up.
static func make_bubbles(tex: Texture2D) -> GPUParticles2D:
	var b := GPUParticles2D.new()
	b.name = "Bubbles"
	b.amount = 18
	b.lifetime = 1.2
	b.local_coords = false
	b.texture = tex
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 14.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 22.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 150.0
	m.gravity = Vector3(0, -60, 0)
	m.scale_min = 0.4
	m.scale_max = 1.1
	m.color = Color(1.0, 1.0, 1.0, 0.8)
	b.process_material = m
	b.emitting = false
	return b

## A one-shot lens-flare star: a bright core with radial spikes.
## Origin CENTRE; scale up + fade it on the flash frame.
static func make_flare(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Flare"
	var core := Polygon2D.new()
	core.name = "Core"
	core.polygon = _ellipse(size * 0.22, size * 0.22, 14)
	core.color = Color(1.0, 1.0, 1.0, 0.95)
	root.add_child(core)
	for i in range(4):
		var spike := Polygon2D.new()
		spike.name = "Spike"
		spike.polygon = PackedVector2Array([
			Vector2(-size * 0.035, 0.0), Vector2(size * 0.035, 0.0),
			Vector2(0.0, -size),
		])
		spike.rotation = PI * 0.25 * float(i)
		spike.color = Color(1.0, 1.0, 1.0, 0.75)
		root.add_child(spike)
	root.visible = false
	return root

## A grease tub. Origin BASE-CENTRE; the "Pool" child's surface sits at
## the top rim for dip-ins.
static func make_grease_tub(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "GreaseTub"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.38, 0.0), Vector2(size * 0.38, 0.0),
		Vector2(size * 0.32, -size * 0.44), Vector2(-size * 0.32, -size * 0.44),
	])
	body.color = WOOD_DARK
	root.add_child(body)
	var pool := Polygon2D.new()
	pool.name = "Pool"
	pool.polygon = _ellipse(size * 0.32, size * 0.07, 14)
	pool.position = Vector2(0.0, -size * 0.40)
	pool.color = GREASE
	root.add_child(pool)
	return root

## A wooden chute plank. Origin at the TOP end; the low end is at
## `length` along `slope` (radians from horizontal).
static func make_chute(length: float, slope: float, width: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Chute"
	var plank := Polygon2D.new()
	plank.name = "Plank"
	var dx := cos(slope) * length
	var dy := sin(slope) * length
	plank.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(dx, dy),
		Vector2(dx - sin(slope) * width, dy - cos(slope) * width),
		Vector2(-sin(slope) * width, -cos(slope) * width),
	])
	plank.color = WOOD
	root.add_child(plank)
	# Rail lip along the top edge.
	var lip := Polygon2D.new()
	lip.name = "Lip"
	lip.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(dx, dy),
		Vector2(dx, dy - width * 0.35), Vector2(0.0, -width * 0.35),
	])
	lip.color = WOOD_DARK
	root.add_child(lip)
	return root

