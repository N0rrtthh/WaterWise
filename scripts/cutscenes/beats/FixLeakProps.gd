extends RefCounted

## Fix The Leak shared props for the beat tier.
## Flat-fill utility-room dressing: grey pipe runs with flanges and holes,
## water jets, the climbing waste meter, the christening bottle, Dribble's
## hat, and a muted town skyline silhouette for the geyser launch.
##
## The pipe's origin is CENTRE so it can span the frame; holes/jets anchor at
## named children. The meter's origin is the NEEDLE PIVOT so rotation reads
## directly (0 = green, ~2.5 rad = pegged red).

const WALL := Color(0.70, 0.85, 0.95)
const FLOOR := Color(0.80, 0.75, 0.65)
const PIPE := Color(0.50, 0.50, 0.50)
const PIPE_DARK := Color(0.38, 0.38, 0.38)
const PIPE_JOINT := Color(0.42, 0.42, 0.42)
const WATER := Color(0.20, 0.60, 1.00, 0.80)
const WATER_LIGHT := Color(0.55, 0.80, 1.00, 0.90)
const GLEAM := Color(1.00, 0.98, 0.82)
const METER_FACE := Color(0.95, 0.95, 0.92)
const METER_FRAME := Color(0.30, 0.30, 0.32)
const ZONE_GREEN := Color(0.45, 0.80, 0.45)
const ZONE_YELLOW := Color(0.95, 0.80, 0.30)
const ZONE_RED := Color(0.85, 0.25, 0.22)
const BOTTLE_GLASS := Color(0.24, 0.45, 0.30)
const BOTTLE_NECK := Color(0.30, 0.55, 0.38)
const HAT := Color(0.36, 0.76, 1.00)
const HAT_DARK := Color(0.28, 0.60, 0.88)
const SKYLINE := Color(0.55, 0.70, 0.82)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A pipe run. Origin CENTRE. Holes are named "Hole%d" children at fractions
## along the length so jets and patches can anchor to them exactly.
static func make_pipe(length: float, hole_fs: Array) -> Node2D:
	var p := Node2D.new()
	p.name = "Pipe"
	var body := Polygon2D.new()
	body.name = "Body"
	var hy := -11.0
	body.polygon = PackedVector2Array([
		Vector2(-length * 0.5, hy), Vector2(length * 0.5, hy),
		Vector2(length * 0.5, -hy), Vector2(-length * 0.5, -hy),
	])
	body.color = PIPE
	p.add_child(body)
	var sheen := Polygon2D.new()
	sheen.name = "Sheen"
	sheen.polygon = PackedVector2Array([
		Vector2(-length * 0.5, hy + 3.0), Vector2(length * 0.5, hy + 3.0),
		Vector2(length * 0.5, hy + 6.0), Vector2(-length * 0.5, hy + 6.0),
	])
	sheen.color = Color(0.62, 0.62, 0.62)
	p.add_child(sheen)
	for x_f in [-0.5 + 0.035, 0.5 - 0.035]:
		var flange := Polygon2D.new()
		flange.name = "Flange"
		flange.polygon = _ellipse(15.0, 19.0, 12)
		flange.position = Vector2(length * x_f, 0.0)
		flange.color = PIPE_JOINT
		p.add_child(flange)
	for i in range(hole_fs.size()):
		var hole := Polygon2D.new()
		hole.name = "Hole%d" % i
		hole.polygon = _ellipse(7.0, 5.0, 10)
		hole.position = Vector2(length * hole_fs[i], 0.0)
		hole.color = PIPE_DARK
		p.add_child(hole)
	return p

## A water jet. `tex` is the shared dot texture from the clip base. Emission
## is at the node origin, cone pointing +X — rotate the node to aim it.
static func make_jet(tex: Texture2D, power := 1.0) -> GPUParticles2D:
	var j := GPUParticles2D.new()
	j.name = "Jet"
	j.amount = int(26 * power)
	j.lifetime = 0.7
	j.texture = tex
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(1, 0, 0)
	m.spread = 13.0
	m.initial_velocity_min = 340.0 * power
	m.initial_velocity_max = 520.0 * power
	m.gravity = Vector3(0, 900, 0)
	m.color_initial_ramp = _jet_ramp()
	m.scale_min = 0.5
	m.scale_max = 0.9
	j.process_material = m
	return j

static func _jet_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([WATER, WATER_LIGHT, Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

## The waste meter. Origin = NEEDLE PIVOT (bottom-centre of the face), so
## `needle.rotation` 0.0..2.5 sweeps green -> yellow -> pegged red directly.
static func make_waste_meter(size := 1.0) -> Node2D:
	var m := Node2D.new()
	m.name = "WasteMeter"
	var face := Polygon2D.new()
	face.name = "Face"
	face.polygon = PackedVector2Array([
		Vector2(-26.0, -52.0), Vector2(26.0, -52.0), Vector2(26.0, 0.0), Vector2(-26.0, 0.0),
	])
	face.color = METER_FACE
	m.add_child(face)
	# Green -> yellow -> red arc bands across the top of the face.
	var zones := [ZONE_GREEN, ZONE_YELLOW, ZONE_RED]
	for i in range(zones.size()):
		var band := Polygon2D.new()
		band.name = "Zone%d" % i
		var x0 := -24.0 + float(i) * 16.0
		band.polygon = PackedVector2Array([
			Vector2(x0, -48.0), Vector2(x0 + 16.0, -48.0),
			Vector2(x0 + 16.0, -42.0), Vector2(x0, -42.0),
		])
		band.color = zones[i]
		m.add_child(band)
	var frame := Polygon2D.new()
	frame.name = "Frame"
	frame.polygon = PackedVector2Array([
		Vector2(-30.0, -56.0), Vector2(30.0, -56.0), Vector2(30.0, 4.0), Vector2(-30.0, 4.0),
	])
	frame.color = Color(0, 0, 0, 0)
	frame.z_index = -1
	m.add_child(frame)
	var border := Line2D.new()
	border.name = "Border"
	border.points = PackedVector2Array([
		Vector2(-26.0, -52.0), Vector2(26.0, -52.0), Vector2(26.0, 0.0), Vector2(-26.0, 0.0),
		Vector2(-26.0, -52.0),
	])
	border.width = 4.0
	border.default_color = METER_FRAME
	m.add_child(border)
	var needle := Polygon2D.new()
	needle.name = "Needle"
	needle.polygon = PackedVector2Array([
		Vector2(-2.5, 0.0), Vector2(2.5, 0.0), Vector2(0.8, -40.0), Vector2(-0.8, -40.0),
	])
	needle.color = ZONE_RED
	needle.rotation = 0.15
	m.add_child(needle)
	m.scale = Vector2.ONE * size
	return m

## The christening bottle. Origin base-centre.
static func make_bottle(size := 1.0) -> Node2D:
	var b := Node2D.new()
	b.name = "Bottle"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-13.0, 0.0), Vector2(13.0, 0.0), Vector2(13.0, -30.0),
		Vector2(6.0, -40.0), Vector2(6.0, -52.0), Vector2(-6.0, -52.0),
		Vector2(-6.0, -40.0), Vector2(-13.0, -30.0),
	])
	body.color = BOTTLE_GLASS
	b.add_child(body)
	var label := Polygon2D.new()
	label.name = "Label"
	label.polygon = PackedVector2Array([
		Vector2(-11.0, -22.0), Vector2(11.0, -22.0), Vector2(11.0, -12.0), Vector2(-11.0, -12.0),
	])
	label.color = Color(0.92, 0.90, 0.80)
	b.add_child(label)
	var neck_shine := Polygon2D.new()
	neck_shine.name = "Shine"
	neck_shine.polygon = PackedVector2Array([
		Vector2(-9.0, -2.0), Vector2(-5.0, -2.0), Vector2(-5.0, -36.0), Vector2(-9.0, -30.0),
	])
	neck_shine.color = BOTTLE_NECK
	b.add_child(neck_shine)
	var cork := Polygon2D.new()
	cork.name = "Cork"
	cork.polygon = PackedVector2Array([
		Vector2(-6.0, -52.0), Vector2(6.0, -52.0), Vector2(6.0, -58.0), Vector2(-6.0, -58.0),
	])
	cork.color = Color(0.72, 0.55, 0.35)
	b.add_child(cork)
	b.scale = Vector2.ONE * size
	return b

## Dribble's droplet-blue cap. Origin base-centre.
static func make_hat(size := 1.0) -> Node2D:
	var h := Node2D.new()
	h.name = "Hat"
	var dome := Polygon2D.new()
	dome.name = "Dome"
	dome.polygon = _ellipse(15.0, 11.0, 12)
	dome.position = Vector2(0.0, -6.0)
	dome.color = HAT
	h.add_child(dome)
	var brim := Polygon2D.new()
	brim.name = "Brim"
	brim.polygon = PackedVector2Array([
		Vector2(-17.0, -4.0), Vector2(17.0, -4.0), Vector2(13.0, 0.0), Vector2(-13.0, 0.0),
	])
	brim.color = HAT_DARK
	h.add_child(brim)
	h.scale = Vector2.ONE * size
	return h

## Muted town skyline silhouette for the launch clip. Origin base line centre.
static func make_skyline(width := 520.0) -> Node2D:
	var s := Node2D.new()
	s.name = "Skyline"
	var xs := [-0.42, -0.24, -0.04, 0.14, 0.32]
	var ws := [70.0, 55.0, 85.0, 60.0, 75.0]
	var hs := [90.0, 130.0, 105.0, 150.0, 95.0]
	for i in range(xs.size()):
		var bld := Polygon2D.new()
		bld.name = "Building%d" % i
		var x: float = width * xs[i]
		var w: float = ws[i]
		var hh: float = hs[i]
		bld.polygon = PackedVector2Array([
			Vector2(x - w * 0.5, 0.0), Vector2(x - w * 0.5, -hh),
			Vector2(x + w * 0.5, -hh), Vector2(x + w * 0.5, 0.0),
		])
		bld.color = SKYLINE
		bld.z_index = -3
		s.add_child(bld)
		for w_i in range(2):
			var win := Polygon2D.new()
			win.name = "Window"
			win.polygon = PackedVector2Array([
				Vector2(x - 6.0 + 16.0 * float(w_i), -hh + 22.0),
				Vector2(x + 4.0 + 16.0 * float(w_i), -hh + 22.0),
				Vector2(x + 4.0 + 16.0 * float(w_i), -hh + 32.0),
				Vector2(x - 6.0 + 16.0 * float(w_i), -hh + 32.0),
			])
			win.color = Color(0.85, 0.92, 0.98, 0.55)
			s.add_child(win)
	return s

