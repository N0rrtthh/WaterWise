## TimingTap - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TimingTapWinOutro.tscn

extends MicrogameOutroBase

## Timing Tap — WIN clip.
## res://scenes/ui/cutscenes/beats/TimingTapWinOutro.tscn
##
## BEAT 1  The water creeps toward the red line; the room goes dead
##         silent, barista-championship style.
## BEAT 2  (impact) The pour stops EXACTLY on the line and a latte-art
##         water swirl blooms on the surface, foam ring and all.
## BEAT 3  Dribble hoists the glass like a trophy; the crowd applauds
##         like it's a barista championship.

const Props := preload("res://scripts/cutscenes/beats/TimingTapProps.gd")

var glass: Node2D
var tap: Node2D
var arc: Node2D
var water_body: Polygon2D
var glass_size: float
var swirl: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	glass_size = _vp.y * 0.30
	# Kitchen floor over the default grass.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	floor_poly.color = Props.FLOOR
	floor_poly.z_index = 0
	world.add_child(floor_poly)
	# The counter with its work top.
	var counter := Polygon2D.new()
	counter.name = "Counter"
	counter.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.10, _vp.y * GROUND_FRACTION), Vector2(_vp.x * 0.56, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x * 0.56, _vp.y), Vector2(_vp.x * 0.10, _vp.y),
	])
	counter.color = Props.COUNTER
	counter.z_index = 1
	world.add_child(counter)
	var top := Polygon2D.new()
	top.name = "CounterTop"
	top.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.09, _vp.y * 0.665), Vector2(_vp.x * 0.57, _vp.y * 0.665),
		Vector2(_vp.x * 0.57, _vp.y * GROUND_FRACTION), Vector2(_vp.x * 0.09, _vp.y * GROUND_FRACTION),
	])
	top.color = Props.COUNTER_TOP
	top.z_index = 2
	world.add_child(top)
	# The tap, caught mid-pour.
	tap = Props.make_tap(_vp.y * 0.40)
	tap.position = Vector2(_vp.x * 0.36, _vp.y * 0.40)
	tap.z_index = 3
	world.add_child(tap)
	# The glass, nearly at the mark.
	glass = Props.make_glass(glass_size, 0.78)
	glass.position = Vector2(_vp.x * 0.36, _vp.y * 0.665)
	glass.z_index = 3
	world.add_child(glass)
	water_body = glass.get_node("Water") as Polygon2D
	arc = Props.make_water_arc(_vp.y * 0.20)
	arc.position = tap.position
	arc.rotation = PI * 0.5
	arc.z_index = 4
	world.add_child(arc)
	# The water-art swirl, hidden until the perfect stop.
	swirl = Props.make_swirl(glass_size * 0.55)
	swirl.position = surface_point()
	swirl.scale = Vector2(0.0, 0.0)
	swirl.z_index = 5
	world.add_child(swirl)
	_stage_townsfolk(2, _vp.x * 0.68, _vp.x * 0.82)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.94, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.22)
	camera.position = _vp * 0.5

func surface_point() -> Vector2:
	return Vector2(_vp.x * 0.36, _vp.y * 0.665 - glass_size * 0.72 * 0.78)

func _set_water_fill(f: float) -> void:
	water_body.polygon = Props.water_poly(glass_size, glass_size * 0.72 * f)

## Impact frame: the water surface, where the swirl blooms.
func _impact_point() -> Vector2:
	return swirl.position

## BEAT 1 — the slow creep toward the mark; nobody breathes.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The water creeps toward the mark. Too slow. Agonising.
	var creep := _ct(water_body)
	creep.tween_method(_set_water_fill, 0.78, 0.795, 0.55)
	# The handle-hand trembles.
	var handle := tap.get_node("Handle") as Node2D
	var tremble := _ct(handle).set_loops(3)
	tremble.tween_property(handle, "rotation", 0.05, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tremble.tween_property(handle, "rotation", -0.05, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The hush: the crowd leans in.
	for i in range(townsfolk.size()):
		var hush := _ct(townsfolk[i]).set_loops(2)
		hush.tween_interval(0.20 * float(i))
		hush.tween_callback(townsfolk[i].hop.bind(4.0, 0.30))
		hush.tween_interval(0.36)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)

## BEAT 2 — the perfect stop ON the tick, and the swirl bloom.
func _on_impact() -> void:
	super._on_impact()
	# Release: the handle snaps back and the pour cuts off.
	var handle := tap.get_node("Handle") as Node2D
	var release := _ct(handle)
	release.tween_property(handle, "rotation", 0.0, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var cut := _ct(arc)
	cut.tween_property(arc, "scale:x", 0.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The line flashes approval-green.
	var line := glass.get_node("TargetLine") as Line2D
	var pass_mark := _ct(line)
	pass_mark.tween_property(line, "default_color", Color(0.30, 0.9, 0.45), 0.10)
	pass_mark.parallel().tween_property(line, "width", line.width * 1.6, 0.10)
	pass_mark.tween_property(line, "width", line.width * 1.1, 0.14)
	# THE SWIRL: water-art blooms on the surface with a foam ring.
	var bloom := _ct(swirl)
	bloom.tween_property(swirl, "scale", Vector2(1.3, 1.3), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bloom.tween_property(swirl, "scale", Vector2.ONE, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var dot := Polygon2D.new()
		dot.polygon = Props._ellipse(4.0 * _content_scale, 4.0 * _content_scale, 8)
		dot.color = Props.SWIRL
		dot.position = swirl.position
		dot.z_index = 6
		world.add_child(dot)
		var fly := _ct(dot)
		fly.tween_property(dot, "position",
			swirl.position + Vector2(cos(a), sin(a) * 0.6) * glass_size * 0.45, 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(dot, "modulate:a", 0.0, 0.34)
		fly.tween_callback(dot.queue_free)
	# The crowd is stunned.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the trophy lift and the barista-championship applause.
func _beat_payoff() -> void:
	glass.z_index = 7
	# THE TROPHY LIFT: Dribble hoists the glass overhead.
	var lift := _ct(glass)
	lift.tween_property(glass, "position",
		dribble.position + Vector2(0.0, -_vp.y * 0.26), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.parallel().tween_property(glass, "rotation", -0.12, 0.30)
	# The swirl rides on the surface all the way up (parallel-follow).
	var follow := _ct(swirl)
	follow.tween_property(swirl, "position",
		dribble.position + Vector2(0.0, -_vp.y * 0.26 - glass_size * 0.72 * 0.78), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The swirl keeps spiralling, showing off.
	var spin := _ct(swirl).set_loops(3)
	spin.tween_property(swirl, "rotation", 0.5, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(swirl, "rotation", -0.5, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# BARISTA-CHAMPIONSHIP APPLAUSE.
	for i in range(townsfolk.size()):
		var fan := townsfolk[i] as CartoonActor
		fan.set_expression(CartoonActor.Mood.HAPPY)
		fan.set_arm_pose(CartoonActor.ArmPose.CHEER)
		var clap := _ct(fan).set_loops(3)
		clap.tween_interval(0.30 + 0.05 * float(i))
		clap.tween_callback(fan.hop.bind(9.0, 0.22))
		clap.tween_interval(0.10)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.hop(9.0, 0.26)
	# Dribble takes a proud barista bow.
	dribble.set_expression(CartoonActor.Mood.SMUG)
	var bow := _ct(dribble)
	bow.tween_interval(0.32)
	bow.tween_property(dribble, "rotation", 0.14, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(dribble, "rotation", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Trophy hearts over the lifted glass.
	for i in range(3):
		var heart := Props.make_heart(22.0 * _content_scale)
		heart.position = dribble.position \
			+ Vector2((-14.0 + 14.0 * float(i)) * _content_scale, -_vp.y * 0.38)
		heart.scale = Vector2(0.5, 0.5)
		heart.z_index = 8
		world.add_child(heart)
		var float_heart := _ct(heart)
		float_heart.tween_interval(0.32 + 0.10 * float(i))
		float_heart.tween_property(heart, "position:y",
			heart.position.y - _vp.y * 0.08, 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		float_heart.parallel().tween_property(heart, "modulate:a", 0.0, 0.55)
		float_heart.parallel().tween_property(heart, "scale", Vector2(1.1, 1.1), 0.55)
		float_heart.tween_callback(heart.queue_free)