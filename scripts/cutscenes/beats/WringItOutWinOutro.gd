## WringItOut - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WringItOutWinOutro.tscn

extends MicrogameOutroBase

## Wring It Out — WIN clip.
## res://scenes/ui/cutscenes/beats/WringItOutWinOutro.tscn
##
## BEAT 1  The last shirt gets its final squeeze — so dry it sparkles.
## BEAT 2  (impact on the lift-off) The clothes float upward on their
##         own, drifting above the clothesline.
## BEAT 3  The Town borrows the floating shirts as makeshift parachutes.

const Props := preload("res://scripts/cutscenes/beats/WringItOutProps.gd")

var shirts: Array = []
var basin: Node2D
var shirt_size: float
var canopies: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var gy := _vp.y * GROUND_FRACTION
	# The same clothesline, now under a sunny pale sky.
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
	# Three shirts on the line — nearly dry already.
	shirt_size = _vp.y * 0.16
	var shirt_x := [0.3, 0.5, 0.7]
	for i in range(3):
		var shirt := Props.make_shirt(shirt_size, Props.DRY)
		shirt.position = Vector2(_vp.x * shirt_x[i], line_y + _vp.y * 0.02)
		shirt.z_index = 2
		world.add_child(shirt)
		shirts.append(shirt)
	# The wrung-out basin, water surface drained to almost nothing.
	basin = Props.make_basin(_vp.y * 0.24)
	basin.position = Vector2(_vp.x * 0.5, gy - _vp.y * 0.01)
	basin.z_index = 2
	world.add_child(basin)
	(basin.get_node("Water") as Polygon2D).color = Color(Props.WATER, 0.25)
	_stage_townsfolk(2, _vp.x * 0.06, _vp.x * 0.16)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.86, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	camera.position = _vp * 0.5

## Impact frame: above the line, where the shirts come to hover.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.5, _vp.y * 0.24)

## BEAT 1 — final squeezes; the shirts brighten to sparkly dry.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	for i in range(shirts.size()):
		var shirt := shirts[i] as Node2D
		# The game's wring pulse, once each, staggered left to right.
		var wring := _ct(shirt)
		wring.tween_interval(0.12 * i)
		wring.tween_property(shirt, "scale", Vector2(0.85, 1.12), 0.055) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wring.tween_property(shirt, "scale", Vector2.ONE, 0.055) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Then the wet blue drains out into sparkling dry.
		var dry := _ct(shirt)
		dry.tween_interval(0.12 * i)
		dry.tween_property(shirt, "modulate",
			Color(1.25, 1.25, 1.35), 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var sway := _ct(shirt).set_loops(3)
		sway.tween_property(shirt, "rotation", 0.06, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(shirt, "rotation", -0.06, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — THE LIFT-OFF: so dry the clothes float upward on their own.
func _on_impact() -> void:
	super._on_impact()
	# The shirts rise off the line, each to a hover height, and bob.
	var lift_x := [0.26, 0.5, 0.74]
	var lift_y := [0.3, 0.22, 0.3]
	for i in range(shirts.size()):
		var shirt := shirts[i] as Node2D
		var rise := _ct(shirt)
		rise.tween_property(shirt, "position",
			Vector2(_vp.x * lift_x[i], _vp.y * lift_y[i]), 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rise.parallel().tween_property(shirt, "rotation", 0.0, 0.3)
		var bob := _ct(shirt)
		bob.tween_interval(0.3)
		bob.tween_property(shirt, "position:y",
			_vp.y * lift_y[i] - _vp.y * 0.012, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(shirt, "position:y", _vp.y * lift_y[i], 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.hop(10.0, 0.2)

## BEAT 3 — the Town borrows the shirts as makeshift parachutes.
func _beat_payoff() -> void:
	# Shirt: owner. Dribble takes the big middle one.
	var owners: Array = []
	owners.append([shirts[0], townsfolk[0]])
	owners.append([shirts[2], townsfolk[1]])
	owners.append([shirts[1], dribble])
	for pair: Array in owners:
		var shirt := pair[0] as Node2D
		var owner := pair[1] as Node2D
		# The shirt glides down to canopy over its new pilot.
		var perch := _ct(shirt)
		perch.tween_property(shirt, "position",
			owner.position + Vector2(0.0, -_vp.y * 0.16), 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		perch.parallel().tween_property(shirt, "rotation", 0.0, 0.26)
		canopies.append([shirt, owner])
	# Everyone gets a gentle airborne drift: hover up and bob while
	# the canopies sway above them like canopies do.
	for pair: Array in canopies:
		var shirt := pair[0] as Node2D
		var owner := pair[1] as Node2D
		var actor := owner as CartoonActor
		actor.set_expression(CartoonActor.Mood.HAPPY)
		actor.set_arm_pose(CartoonActor.ArmPose.UP)
		var float_up := _ct(owner)
		float_up.tween_interval(0.28)
		float_up.tween_property(owner, "position:y",
			owner.position.y - _vp.y * 0.14, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var sway := _ct(shirt).set_loops(2)
		sway.tween_property(shirt, "rotation", 0.12, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(shirt, "rotation", -0.12, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The grounded spectators wave the new air force up.
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(16.0, 0.3)
