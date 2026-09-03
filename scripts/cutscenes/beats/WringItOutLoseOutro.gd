## WringItOut - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WringItOutLoseOutro.tscn

extends MicrogameOutroBase

## Wring It Out — LOSE clip.
## res://scenes/ui/cutscenes/beats/WringItOutLoseOutro.tscn
##
## BEAT 1  Dribble wrings far too hard; the basin water starts to swirl.
## BEAT 2  (impact at the cyclone's peak spin) The basin becomes a small
##         cyclone and droplets burst outward.
## BEAT 3  The cyclone flings Dribble skyward; his splash rains down
##         over the Town and sails past the cliff.

const Props := preload("res://scripts/cutscenes/beats/WringItOutProps.gd")

var shirts: Array = []
var basin: Node2D
var cyclone: Node2D
var shirt_size: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var gy := _vp.y * GROUND_FRACTION
	# Clothesline with two still-soaked shirts; the third is already in
	# Dribble's iron grip.
	var line_y := _vp.y * 0.36
	for side in range(2):
		var post := Polygon2D.new()
		post.name = "Post%d" % side
		post.polygon = PackedVector2Array([
			Vector2(-_vp.y * 0.012, 0.0), Vector2(_vp.y * 0.012, 0.0),
			Vector2(_vp.y * 0.012, line_y - gy), Vector2(-_vp.y * 0.012, line_y - gy),
		])
		post.position = Vector2(_vp.x * (0.08 if side == 0 else 0.92), gy)
		post.color = Props.BASIN_DARK
		post.z_index = 1
		world.add_child(post)
	var rope := Line2D.new()
	rope.name = "Rope"
	rope.width = 4.0 * _content_scale
	rope.default_color = Props.ROPE
	rope.points = PackedVector2Array([
		Vector2(_vp.x * 0.08, line_y),
		Vector2(_vp.x * 0.5, line_y + _vp.y * 0.015),
		Vector2(_vp.x * 0.92, line_y),
	])
	rope.z_index = 1
	world.add_child(rope)
	shirt_size = _vp.y * 0.16
	var shirt_x := [0.32, 0.56]
	for i in range(2):
		var shirt := Props.make_shirt(shirt_size, Props.WET)
		shirt.position = Vector2(_vp.x * shirt_x[i], line_y + _vp.y * 0.02)
		shirt.z_index = 2
		world.add_child(shirt)
		shirts.append(shirt)
	# The basin — full to the brim with soak water.
	basin = Props.make_basin(_vp.y * 0.26)
	basin.position = Vector2(_vp.x * 0.68, gy - _vp.y * 0.01)
	basin.z_index = 2
	world.add_child(basin)
	_stage_townsfolk(2, _vp.x * 0.06, _vp.x * 0.16)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.86, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.68)
	# The young cyclone, coiled in the basin water, not yet awake.
	cyclone = Node2D.new()
	cyclone.name = "Cyclone"
	cyclone.position = basin.position
	cyclone.z_index = 3
	world.add_child(cyclone)

## Impact frame: the crown of the water column.
func _impact_point() -> Vector2:
	return basin.position + Vector2(0.0, -_vp.y * 0.1)

## BEAT 1 — Dribble wrings far too hard; the water starts to swirl.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	# The two line shirts sway, oblivious.
	for shirt: Node2D in shirts:
		var sway := _ct(shirt).set_loops(3)
		sway.tween_property(shirt, "rotation", 0.07, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(shirt, "rotation", -0.07, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The water surface starts turning — first wobble, then spin.
	var water := basin.get_node("Water") as Polygon2D
	# set_loops(3) only delivers three revolutions with as_relative(); see the note on
	# the cyclone bands below.
	var spin := _ct(water).set_loops(3)
	spin.tween_property(water, "rotation", TAU, 0.55) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN).as_relative()
	# The cyclone column grows from the basin: a twisting water funnel.
	for layer in range(3):
		var band := Polygon2D.new()
		band.polygon = Props._ellipse(
			_vp.y * (0.05 + layer * 0.045), _vp.y * 0.028)
		band.position = Vector2(0.0, -_vp.y * (0.035 + layer * 0.038))
		band.color = Color(Props.WATER, 0.5)
		band.scale = Vector2(0.2, 0.2)
		cyclone.add_child(band)
		var grow := _ct(band)
		grow.tween_interval(0.2 + layer * 0.12)
		grow.tween_property(band, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# as_relative() is what keeps it turning. A PropertyTweener with no from()
		# captures the property when it STARTS and a looping Tween restarts its
		# tweeners every loop, so a fixed TAU target animated TAU -> TAU from loop 2
		# on: the funnel froze after one turn, at the exact moment the eruption is
		# meant to peak. Measured in tools/VerifyLoopingTweenAdvance.tscn.
		var whirl := _ct(band).set_loops(4)
		whirl.tween_property(band, "rotation", TAU, 0.4) \
			.set_trans(Tween.TRANS_LINEAR).as_relative()

## BEAT 2 — PEAK SPIN: droplets burst from the cyclone's crown.
func _on_impact() -> void:
	super._on_impact()
	# Eight droplets flung outward from the crown, spinning off wide.
	for d in range(8):
		var angle := d * TAU / 8.0
		var drop := Props.make_drop(_vp.y * 0.02)
		drop.position = _impact_point()
		drop.z_index = 4
		drop.rotation = angle
		world.add_child(drop)
		var fly := _ct(drop)
		fly.tween_property(drop, "position",
			_impact_point() + Vector2(cos(angle) * _vp.x * 0.12,
			sin(angle) * _vp.y * 0.1 - _vp.y * 0.03), 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(drop, "modulate:a", 0.0, 0.3)
		fly.tween_callback(drop.queue_free)
	# The whole cyclone hunches down, coiling for the fling.
	cyclone.scale = Vector2(1.15, 0.85)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the fling: Dribble goes skyward, his splash rains down
## over the Town and drifts off past the cliff.
func _beat_payoff() -> void:
	# The cyclone releases: Dribble is launched straight up, spinning.
	var fling := _ct(dribble)
	fling.tween_property(dribble, "position",
		Vector2(_vp.x * 0.68, -_vp.y * 0.12), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fling.parallel().tween_property(dribble, "rotation", TAU * 1.75, 0.4)
	fling.parallel().tween_property(dribble, "modulate:a", 0.0, 0.35)
	# The cyclone collapses back into the basin and fizzles.
	var fizzle := _ct(cyclone)
	fizzle.tween_interval(0.15)
	fizzle.tween_property(cyclone, "scale", Vector2(0.2, 0.2), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fizzle.tween_property(cyclone, "modulate:a", 0.0, 0.2)
	# His splash rains down over the town — then sails right, past
	# the cliff edge.
	var gy := _vp.y * GROUND_FRACTION
	for d in range(7):
		var drop := Props.make_drop(_vp.y * 0.024)
		drop.position = Vector2(_vp.x * (0.62 + 0.02 * d), -_vp.y * 0.05)
		drop.z_index = 4
		world.add_child(drop)
		var rain := _ct(drop)
		rain.tween_interval(0.45 + 0.06 * d)
		rain.tween_property(drop, "position",
			Vector2(_vp.x * (0.14 + 0.06 * d), gy - _vp.y * 0.04), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rain.tween_property(drop, "position",
			Vector2(_vp.x * (1.25 + 0.06 * d), gy + _vp.y * 0.14), 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rain.parallel().tween_property(drop, "modulate:a", 0.0, 0.35)
	# The town watches the human weather system leave the premises.
	var watch := _ct(mayor)
	watch.tween_interval(0.4)
	watch.tween_property(mayor, "position:x", _vp.x * 0.82, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t: CartoonActor in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
