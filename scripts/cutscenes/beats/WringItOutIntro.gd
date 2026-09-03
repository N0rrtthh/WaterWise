## WringItOut - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WringItOutIntro.tscn

extends MicrogameIntroBase

## Wring It Out — CAUSE clip.
## res://scenes/ui/cutscenes/beats/WringItOutIntro.tscn
##
## BEAT 1  A basin of soaked laundry sits under a clothesline of
##         dripping shirts; the Town glances impatiently at the sky,
##         checking for rain.
## BEAT 2  (flash impact) The sky flickers, the shirts drip harder —
##         everyone shivers.
## BEAT 3  Dribble grabs a shirt and starts wringing it over the basin.

const Props := preload("res://scripts/cutscenes/beats/WringItOutProps.gd")

var shirts: Array = []
var basin: Node2D
var shirt_size: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var gy := _vp.y * GROUND_FRACTION
	# The clothesline: two posts and a sagging rope.
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
	# Three DRENCHED shirts hanging on the line, dripping.
	shirt_size = _vp.y * 0.16
	var shirt_x := [0.3, 0.5, 0.7]
	for i in range(3):
		var shirt := Props.make_shirt(shirt_size, Props.WET)
		shirt.position = Vector2(_vp.x * shirt_x[i], line_y + _vp.y * 0.02)
		shirt.z_index = 2
		shirt.rotation = 0.06 if i == 1 else -0.04
		world.add_child(shirt)
		shirts.append(shirt)
	# The basin of soaked laundry below, catching the drips.
	basin = Props.make_basin(_vp.y * 0.24)
	basin.position = Vector2(_vp.x * 0.5, gy - _vp.y * 0.01)
	basin.z_index = 2
	world.add_child(basin)
	_stage_townsfolk(2, _vp.x * 0.06, _vp.x * 0.16)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.86, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.62)
	camera.position = _vp * 0.5

## BEAT 1 — dripping shirts; the town scans the sky for rain.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	# The shirts sway on the line.
	for i in range(shirts.size()):
		var shirt := shirts[i] as Node2D
		var sway := _ct(shirt).set_loops(3)
		sway.tween_property(shirt, "rotation", shirt.rotation - 0.07, 0.19) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(shirt, "rotation", shirt.rotation + 0.07, 0.19) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_drip_from(shirt.position + Vector2(0.0, shirt_size * 0.55), 0.25 * float(i))
	# The town glances up at the sky, twice, impatient.
	var crowd := [mayor]
	for t in townsfolk:
		crowd.append(t)
	for actor in crowd:
		var a := actor as Node2D
		var glance := _ct(a).set_loops(2)
		glance.tween_property(a, "rotation", -0.12, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glance.tween_property(a, "rotation", 0.0, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## One fat drip falls from a shirt into the basin.
func _drip_from(pos: Vector2, delay: float) -> void:
	var drop := Props.make_drop(_vp.y * 0.018)
	drop.position = pos
	drop.z_index = 4
	world.add_child(drop)
	var fall := _ct(drop)
	fall.tween_interval(delay)
	fall.tween_property(drop, "position:y", basin.position.y, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(drop, "modulate:a", 0.0, 0.08)
	fall.tween_callback(drop.queue_free)

## BEAT 2 — the sky flickers; the shirts drip harder, everyone shivers.
func _on_impact() -> void:
	_impact_flash()
	# A burst of drips from every shirt.
	for i in range(shirts.size()):
		var shirt := shirts[i] as Node2D
		for d in range(2):
			_drip_from(shirt.position +
				Vector2(_vp.x * randf_range(-0.03, 0.03), shirt_size * 0.55),
				0.05 * d)
	# Shiver through the whole cast.
	var crowd := [mayor]
	for t in townsfolk:
		crowd.append(t)
	for actor in crowd:
		var a := actor as Node2D
		var shiver := _ct(a)
		shiver.tween_property(a, "rotation", 0.05, 0.05)
		shiver.tween_property(a, "rotation", -0.05, 0.05)
		shiver.tween_property(a, "rotation", 0.0, 0.06)
	# The laundry lump squishes down as it takes the drips.
	var lump := basin.get_node("Laundry") as Polygon2D
	var squish := _ct(lump)
	squish.tween_property(lump, "scale:y", 0.7, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	squish.tween_property(lump, "scale:y", 1.0, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — Dribble grabs a shirt and starts wringing it.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	var grab := _ct(dribble)
	grab.tween_property(dribble, "position:x", _vp.x * 0.48, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The first shirt comes off the line and lands in his grip.
	var shirt := shirts[0] as Node2D
	var pull := _ct(shirt)
	pull.tween_property(shirt, "position",
		dribble.position + Vector2(0.0, -_vp.y * 0.1), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pull.parallel().tween_property(shirt, "rotation", 0.0, 0.2)
	# The game's signature wring: fast squeeze pulses over the basin.
	for pulse in range(3):
		var wring := _ct(shirt)
		wring.tween_interval(0.26 + pulse * 0.09)
		wring.tween_callback(func():
			_drip_from(shirt.position + Vector2(0.0, shirt_size * 0.4), 0.0))
		wring.tween_property(shirt, "scale", Vector2(0.82, 1.14), 0.055) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wring.tween_property(shirt, "scale", Vector2.ONE, 0.055) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
