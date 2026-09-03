extends RefCounted

## Droplet Dash shared props for the beat tier.
## Flat-fill race-course dressing: start line, race flag, cartoon obstacles,
## the champion's glass on its gold podium, and the cliff-edge waterfall.
##
## All standing props use BASE-CENTRE origins. The flag's pennant is a child
## (Pennant) so the intro can drop it down the pole with one tween.

const COURSE_SKY := Color(0.20, 0.40, 0.60)
const TRACK := Color(0.55, 0.50, 0.40)
const TRACK_DARK := Color(0.45, 0.40, 0.32)
const LINE_WHITE := Color(0.95, 0.95, 0.92)
const POLE := Color(0.35, 0.30, 0.26)
const PENNANT := Color(0.85, 0.25, 0.30)
const CRATE := Color(0.62, 0.44, 0.26)
const CRATE_DARK := Color(0.48, 0.33, 0.18)
const BARREL := Color(0.50, 0.36, 0.22)
const BARREL_DARK := Color(0.36, 0.25, 0.14)
const BRICK := Color(0.65, 0.36, 0.26)
const BRICK_DARK := Color(0.52, 0.28, 0.20)
const GOLD := Color(0.85, 0.68, 0.25)
const GOLD_DARK := Color(0.65, 0.50, 0.16)
const GLASS := Color(1, 1, 1, 0.40)
const GLASS_RIM := Color(1, 1, 1, 0.75)
const WATER_FILL := Color(0.30, 0.80, 1.00, 0.65)
const FALL := Color(0.55, 0.82, 0.95, 0.85)
const FALL_FOAM := Color(0.92, 0.97, 1.00, 0.9)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## Checkered starting strip lying flat on the track. Origin strip-centre.
static func make_start_line(width: float) -> Node2D:
	var line := Node2D.new()
	line.name = "StartLine"
	var cell := width / 6.0
	for i in range(6):
		for j in range(2):
			var sq := Polygon2D.new()
			sq.name = "Cell%d%d" % [i, j]
			var x0 := -width * 0.5 + cell * float(i)
			var y0 := -10.0 + 10.0 * float(j)
			sq.polygon = PackedVector2Array([
				Vector2(x0, y0), Vector2(x0 + cell, y0),
				Vector2(x0 + cell, y0 + 10.0), Vector2(x0, y0 + 10.0),
			])
			sq.color = LINE_WHITE if (i + j) % 2 == 0 else TRACK_DARK
			line.add_child(sq)
	return line

## Race flag: pole with a red pennant that starts raised; the intro drops it.
static func make_flag(height := 96.0) -> Node2D:
	var f := Node2D.new()
	f.name = "RaceFlag"
	var pole := Polygon2D.new()
	pole.name = "Pole"
	pole.polygon = PackedVector2Array([
		Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(2.5, -height), Vector2(-2.5, -height),
	])
	pole.color = POLE
	f.add_child(pole)
	var knob := Polygon2D.new()
	knob.name = "Knob"
	knob.polygon = _ellipse(5.0, 5.0, 10)
	knob.position = Vector2(0.0, -height)
	knob.color = GOLD
	f.add_child(knob)
	var pennant := Polygon2D.new()
	pennant.name = "Pennant"
	pennant.polygon = PackedVector2Array([
		Vector2(2.5, -height + 4.0), Vector2(34.0, -height + 14.0), Vector2(2.5, -height + 26.0),
	])
	pennant.color = PENNANT
	f.add_child(pennant)
	return f

## Cartoon course obstacle. kind: "crate" | "barrel" | "wall".
## Origin base-centre, roughly 60 px tall at scale 1.
static func make_obstacle(kind := "crate") -> Node2D:
	var o := Node2D.new()
	o.name = "Obstacle"
	match kind:
		"barrel":
			var body := Polygon2D.new()
			body.name = "Body"
			body.polygon = _ellipse(22.0, 30.0, 14)
			body.position = Vector2(0.0, -30.0)
			body.color = BARREL
			o.add_child(body)
			for y_off in [-16.0, -44.0]:
				var band := Polygon2D.new()
				band.name = "Band"
				band.polygon = _ellipse(22.0, 5.0, 14)
				band.position = Vector2(0.0, y_off + 30.0)
				band.color = BARREL_DARK
				o.add_child(band)
		"wall":
			for row in range(3):
				var n := 3 - (row % 2)
				for i in range(n + (1 if row % 2 == 1 else 0)):
					var b := Polygon2D.new()
					b.name = "Brick"
					var w := 20.0
					var x := -float(n) * w * 0.5 + w * 0.5 + float(i) * w \
						+ (w * 0.5 if row % 2 == 1 else 0.0)
					b.polygon = PackedVector2Array([
						Vector2(x - w * 0.45, -float(row) * 18.0),
						Vector2(x + w * 0.45, -float(row) * 18.0),
						Vector2(x + w * 0.45, -float(row) * 18.0 - 16.0),
						Vector2(x - w * 0.45, -float(row) * 18.0 - 16.0),
					])
					b.color = BRICK if (row + i) % 2 == 0 else BRICK_DARK
					o.add_child(b)
		_:
			var box := Polygon2D.new()
			box.name = "Box"
			box.polygon = PackedVector2Array([
				Vector2(-26, 0), Vector2(26, 0), Vector2(26, -52), Vector2(-26, -52),
			])
			box.color = CRATE
			o.add_child(box)
			var brace1 := Line2D.new()
			brace1.name = "Brace1"
			brace1.points = PackedVector2Array([Vector2(-24, -2), Vector2(24, -50)])
			brace1.width = 5.0
			brace1.default_color = CRATE_DARK
			o.add_child(brace1)
			var brace2 := Line2D.new()
			brace2.name = "Brace2"
			brace2.points = PackedVector2Array([Vector2(24, -2), Vector2(-24, -50)])
			brace2.width = 5.0
			brace2.default_color = CRATE_DARK
			o.add_child(brace2)
	return o

## Champion's glass on a gold #1 podium. Origin podium base-centre.
## The glass water surface sits at GLASS_Y (local) — the win clip uses it as
## the splash-landing target.
static func make_trophy_podium(size := 1.0) -> Node2D:
	var p := Node2D.new()
	p.name = "TrophyPodium"

	var block := Polygon2D.new()
	block.name = "Block"
	block.polygon = PackedVector2Array([
		Vector2(-34, 0), Vector2(34, 0), Vector2(30, -70), Vector2(-30, -70),
	])
	block.color = GOLD
	p.add_child(block)
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = PackedVector2Array([
		Vector2(-22, -58), Vector2(22, -58), Vector2(20, -14), Vector2(-20, -14),
	])
	plate.color = GOLD_DARK
	p.add_child(plate)

	var glass := Node2D.new()
	glass.name = "Glass"
	glass.position = Vector2(0.0, -70.0)
	var bowl := Polygon2D.new()
	bowl.name = "Bowl"
	bowl.polygon = PackedVector2Array([
		Vector2(-26, -44), Vector2(26, -44), Vector2(16, 0), Vector2(-16, 0),
	])
	bowl.color = GLASS
	glass.add_child(bowl)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(-24, -30), Vector2(24, -30), Vector2(17, -2), Vector2(-17, -2),
	])
	fill.color = WATER_FILL
	glass.add_child(fill)
	var stem := Polygon2D.new()
	stem.name = "Stem"
	stem.polygon = PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0), Vector2(7, 16), Vector2(-7, 16),
	])
	stem.color = GLASS
	glass.add_child(stem)
	var foot := Polygon2D.new()
	foot.name = "Foot"
	foot.polygon = _ellipse(14.0, 4.0, 12)
	foot.position = Vector2(0.0, 17.0)
	foot.color = GLASS
	glass.add_child(foot)
	p.add_child(glass)

	p.scale = Vector2.ONE * size
	return p

## Cliff-edge waterfall for the lose outro: white-blue streaks pouring over
## the right edge of the frame with a foam pool. `frame` sizes it; the fall
## spans the last `span_frac` of frame width from the ground line downward.
static func make_waterfall(frame: Vector2, edge_x_frac := 0.88) -> Node2D:
	var w := Node2D.new()
	w.name = "Waterfall"
	w.z_index = -3
	var top := frame.y * 0.52
	var x0 := frame.x * edge_x_frac
	var width := frame.x * (1.0 - edge_x_frac)
	var sheet := Polygon2D.new()
	sheet.name = "Sheet"
	sheet.polygon = PackedVector2Array([
		Vector2(x0 + width * 0.15, top), Vector2(frame.x, top),
		Vector2(frame.x, frame.y), Vector2(x0 + width * 0.15, frame.y),
	])
	sheet.color = FALL
	w.add_child(sheet)
	for i in range(4):
		var streak := Line2D.new()
		streak.name = "Streak%d" % (i + 1)
		var sx := x0 + width * (0.3 + 0.16 * float(i))
		streak.points = PackedVector2Array([
			Vector2(sx, top + 8.0), Vector2(sx, frame.y - 10.0),
		])
		streak.width = 3.0 + 2.0 * float(i % 2)
		streak.default_color = Color(1, 1, 1, 0.55)
		w.add_child(streak)
	var foam := Polygon2D.new()
	foam.name = "Foam"
	foam.polygon = _ellipse(width * 0.55, 12.0, 14)
	foam.position = Vector2(x0 + width * 0.55, frame.y * 0.78)
	foam.color = FALL_FOAM
	w.add_child(foam)
	return w

