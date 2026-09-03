## TurnOffTap - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TurnOffTapLoseOutro.tscn

extends MicrogameOutroBase

## Turn Off Tap — LOSE clip.
## res://scenes/ui/cutscenes/beats/TurnOffTapLoseOutro.tscn
##
## BEAT 1  The faucets box Dribble in from both sides, blasting.
## BEAT 2  (impact on the peak soak) Every stream swings inward and
##         CONVERGES on Dribble — soaked to the bone amid a droplet
##         burst.
## BEAT 3  Dribble mounts one loose faucet and rides it like a ROCKET
##         PONY off the cliff, exhaust blazing.

const Props := preload("res://scripts/cutscenes/beats/TurnOffTapProps.gd")

var taps: Array = []
var pony: Node2D
var tap_size: float
var puddle: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	# Bathroom tile over the default grass.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	floor_poly.color = Props.TILE
	floor_poly.z_index = 0
	world.add_child(floor_poly)
	for i in range(3):
		var grout := Line2D.new()
		grout.width = 2.0 * _content_scale
		grout.default_color = Props.TILE_LINE
		var y := _vp.y * (GROUND_FRACTION + 0.08 * float(i + 1))
		grout.points = PackedVector2Array([Vector2(0.0, y), Vector2(_vp.x, y)])
		grout.z_index = 0
		world.add_child(grout)
	# The gang: two taps to the left facing in, two to the right facing
	# back — Dribble boxed in at centre. Tap 1 is the future rocket pony.
	tap_size = _vp.y * 0.42
	var tap_x := [0.28, 0.42, 0.60, 0.74]
	for i in range(tap_x.size()):
		var tap := Props.make_faucet(tap_size, true, i == 1)
		tap.position = Vector2(_vp.x * tap_x[i], _vp.y * GROUND_FRACTION)
		if i >= 2:
			tap.scale.x = -1.0
		tap.z_index = 2
		world.add_child(tap)
		taps.append(tap)
	pony = taps[1] as Node2D
	# The puddle spreading under the crossfire.
	puddle = Props.make_puddle()
	puddle.position = Vector2(_vp.x * 0.51, _vp.y * GROUND_FRACTION)
	puddle.z_index = 1
	world.add_child(puddle)
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.51)
	camera.position = _vp * 0.5

func _set_puddle(h: float) -> void:
	var water := puddle.get_node("Water") as Polygon2D
	water.polygon = Props.puddle_poly(_vp.x * 0.30, _vp.y * 0.055 * h)

## BEAT 1 — the gang closes in, blasting from both flanks.
func _beat_setup() -> void:
	_set_puddle(0.3)
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t in townsfolk:
		t.start_idle()
	for tap: Node2D in taps:
		var stream := tap.get_node("Stream") as Polygon2D
		var pulse := _ct(stream).set_loops(2)
		pulse.tween_property(stream, "scale:x", 1.3, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(stream, "scale:x", 1.0, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor points at each guilty tap in turn.
	var point_seq := _ct(mayor)
	for i in range(taps.size()):
		point_seq.tween_interval(0.14)
		point_seq.tween_callback(mayor.hop.bind(9.0, 0.14))
		point_seq.tween_property(mayor, "rotation",
			0.12 if i % 2 == 0 else -0.06, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The puddle creeps higher.
	var rise := _ct(puddle)
	rise.tween_method(_set_puddle, 0.3, 0.8, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## BEAT 2 — PEAK SOAK: every stream converges on Dribble.
func _on_impact() -> void:
	super._on_impact()
	var aim := [0.55, 0.4, -0.4, -0.55]
	for i in range(taps.size()):
		var tap := taps[i] as Node2D
		var turn := _ct(tap)
		turn.tween_property(tap, "rotation", aim[i], 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var stream := tap.get_node("Stream") as Polygon2D
		var blast := _ct(stream)
		blast.tween_property(stream, "scale", Vector2(1.45, 1.2), 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Dribble is soaked to the bone.
	dribble.modulate = Color(0.75, 0.88, 1.0)
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	var shiver := _ct(dribble)
	shiver.tween_property(dribble, "rotation", 0.12, 0.05)
	shiver.tween_property(dribble, "rotation", -0.12, 0.05)
	shiver.tween_property(dribble, "rotation", 0.08, 0.05)
	shiver.tween_property(dribble, "rotation", 0.0, 0.05)
	# A droplet burst scatters off the soaking.
	for d in range(6):
		var drop := Polygon2D.new()
		drop.polygon = Props.ellipse(5.0 * _content_scale, 7.0 * _content_scale, 10)
		drop.color = Color(0.3, 0.6, 1.0, 0.9)
		drop.position = _impact_point()
		drop.z_index = 7
		world.add_child(drop)
		var fly := _ct(drop)
		fly.set_parallel(true)
		fly.tween_property(drop, "position",
			_impact_point() + Vector2(-60.0 + 24.0 * float(d),
				-46.0 + 14.0 * float(d % 3)) * _content_scale, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(drop, "modulate:a", 0.0, 0.35)
		fly.chain().tween_callback(drop.queue_free)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 3 — Dribble rides the loose faucet like a rocket pony,
## blazing off the cliff to the right.
func _beat_payoff() -> void:
	# Mount up: Dribble hops onto the pony's back.
	var mount := _ct(dribble)
	mount.tween_property(dribble, "position",
		pony.position + Vector2(-tap_size * 0.04, -tap_size * 0.56), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mount.parallel().tween_property(dribble, "scale", dribble.scale * 0.8, 0.22)
	# Ignition: the exhaust flares alive.
	for boost_name in ["Boost", "BoostCore"]:
		var flame := pony.get_node(boost_name) as Polygon2D
		var ignite := _ct(flame)
		ignite.tween_property(flame, "modulate:a", 1.0, 0.10)
	# ...and they're OFF.
	var pony_flight := _ct(pony)
	pony_flight.tween_property(pony, "position",
		pony.position + Vector2(_vp.x * 0.40, -_vp.y * 0.46), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pony_flight.tween_property(pony, "position",
		Vector2(_vp.x * 1.45, _vp.y * GROUND_FRACTION + _vp.y * 0.06), 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pony_flight.parallel().tween_property(pony, "rotation", 0.28, 0.62)
	pony_flight.parallel().tween_property(pony, "modulate:a", 0.0, 0.30) \
		.set_delay(0.34)
	var ride := _ct(dribble)
	ride.tween_property(dribble, "position",
		pony.position + Vector2(_vp.x * 0.40, -_vp.y * 0.50), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ride.tween_property(dribble, "position",
		Vector2(_vp.x * 1.45, _vp.y * GROUND_FRACTION - _vp.y * 0.02), 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ride.parallel().tween_property(dribble, "rotation", TAU * 2.0, 0.62)
	ride.parallel().tween_property(dribble, "modulate:a", 0.0, 0.30) \
		.set_delay(0.34)
	# Exhaust puffs trail the launch arc.
	for p in range(4):
		var puff := Polygon2D.new()
		puff.polygon = Props.ellipse(9.0 * _content_scale, 12.0 * _content_scale, 10)
		puff.color = Color(0.85, 0.88, 0.92, 0.8)
		puff.position = pony.position \
			+ Vector2(_vp.x * 0.07 * float(p + 1), -_vp.y * 0.09 * float(p + 1))
		puff.z_index = 3
		world.add_child(puff)
		var bloom := _ct(puff)
		bloom.tween_interval(0.08 + 0.10 * float(p))
		bloom.set_parallel(true)
		bloom.tween_property(puff, "scale", Vector2(2.4, 2.4), 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bloom.tween_property(puff, "modulate:a", 0.0, 0.3)
		bloom.chain().tween_callback(puff.queue_free)
	# The town can only wave goodbye.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.hop(10.0, 0.26)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
