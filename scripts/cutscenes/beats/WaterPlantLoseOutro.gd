## WaterPlant - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WaterPlantLoseOutro.tscn

extends MicrogameOutroBase

## Water Plant — LOSE clip.
## res://scenes/ui/cutscenes/beats/WaterPlantLoseOutro.tscn
##
## BEAT 1  The plants droop bone-dry; the old watering can lies empty
##         and tipped on the dirt beside Dribble.
## BEAT 2  (impact on the synchronized point) Every plant snaps upright
##         and POINTS at Dribble. Accusation.
## BEAT 3  The town launches Dribble off the cliff riding the empty can.

const GProps := preload("res://scripts/cutscenes/beats/ThirstyPlantProps.gd")
const Props := preload("res://scripts/cutscenes/beats/WaterPlantProps.gd")

var plants: Array = []
var can: Node2D
var plant_size: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	var gy := _vp.y * GROUND_FRACTION
	# The garden dirt bed over the default grass, with a grass lip.
	var dirt := Polygon2D.new()
	dirt.name = "Dirt"
	dirt.polygon = PackedVector2Array([
		Vector2(0.0, gy), Vector2(_vp.x, gy),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	dirt.color = Props.DIRT
	dirt.z_index = 0
	world.add_child(dirt)
	var lip := Line2D.new()
	lip.name = "GrassLip"
	lip.width = 8.0 * _content_scale
	lip.default_color = Props.GRASS
	lip.points = PackedVector2Array([Vector2(0.0, gy), Vector2(_vp.x, gy)])
	lip.z_index = 0
	world.add_child(lip)
	# The row of potted plants, drooping bone-dry and browned.
	plant_size = _vp.y * 0.17
	var plant_x := [0.20, 0.32, 0.46, 0.58]
	var droop := [0.6, -0.5, 0.55, -0.6]
	for i in range(4):
		var plant := GProps.make_potted_plant(plant_size)
		plant.position = Vector2(_vp.x * plant_x[i], gy)
		plant.z_index = 2
		var head := plant.get_node("Head") as Node2D
		head.rotation = droop[i]
		plant.modulate = Color(0.78, 0.7, 0.55)
		world.add_child(plant)
		plants.append(plant)
	# The OLD, EMPTY watering can, tipped over on the dirt.
	can = Props.make_watering_can(_vp.y * 0.14)
	can.position = Vector2(_vp.x * 0.70, gy - _vp.y * 0.012)
	can.rotation = -1.35
	can.z_index = 3
	world.add_child(can)
	_stage_townsfolk(2, _vp.x * 0.06, _vp.x * 0.14)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.64)
	camera.position = _vp * 0.5

## Impact frame: between the accusing heads and their target.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.52, _vp.y * GROUND_FRACTION - plant_size * 0.7)

## BEAT 1 — the parched rows; Dribble tries to look innocent.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	# The dead heads sway in the hot wind.
	for i in range(plants.size()):
		var plant := plants[i] as Node2D
		var head := plant.get_node("Head") as Node2D
		var sway := _ct(head).set_loops(3)
		sway.tween_property(head, "rotation", head.rotation - 0.08, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(head, "rotation", head.rotation + 0.08, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Dribble sidles toward the can, whistling innocently.
	var sidle := _ct(dribble)
	sidle.tween_property(dribble, "position:x", _vp.x * 0.68, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 2 — THE SYNCHRONIZED POINT: every head snaps toward Dribble.
func _on_impact() -> void:
	super._on_impact()
	# All four heads snap upright at once and lean AT him —
	# plants left of Dribble point right, plants right point left.
	for plant: Node2D in plants:
		var head := plant.get_node("Head") as Node2D
		var toward := -0.75 if plant.position.x > dribble.position.x else 0.75
		var snap := _ct(head)
		snap.tween_property(head, "rotation", toward, 0.09) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var hold := _ct(head)
		hold.tween_interval(0.09)
		hold.tween_property(plant, "scale", Vector2(1.06, 1.06), 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hold.tween_property(plant, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The colour drains back in — they look ALIVE with indignation.
	for plant: Node2D in plants:
		var flush := _ct(plant)
		flush.tween_interval(0.08)
		flush.tween_property(plant, "modulate",
			Color(0.6, 0.9, 0.55), 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — Dribble rides the empty can off the cliff.
func _beat_payoff() -> void:
	var gy := _vp.y * GROUND_FRACTION
	# The town rights the can and loads the "pilot" aboard.
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	var board := _ct(dribble)
	board.tween_property(dribble, "position",
		can.position + Vector2(_vp.x * 0.03, -_vp.y * 0.13), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	# The escorts give the can a firm official shove.
	for t: CartoonActor in townsfolk:
		t.set_expression(CartoonActor.Mood.NEUTRAL)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
	var walk_l := _ct(townsfolk[0] as Node2D)
	walk_l.tween_property(townsfolk[0], "position:x", _vp.x * 0.74, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var walk_r := _ct(townsfolk[1] as Node2D)
	walk_r.tween_property(townsfolk[1], "position:x", _vp.x * 0.80, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	# The launch: can and rider skim right, tip over the cliff edge,
	# and arc away — the can barrel-rolling all the way down.
	var launch := _ct(can)
	launch.tween_interval(0.28)
	launch.tween_property(can, "position:x", _vp.x * 1.08, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	launch.tween_property(can, "position",
		Vector2(_vp.x * 1.5, gy + _vp.y * 0.16), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	launch.parallel().tween_property(can, "rotation", TAU * 1.5, 0.4)
	launch.parallel().tween_property(can, "modulate:a", 0.0, 0.35)
	var ride := _ct(dribble)
	ride.tween_interval(0.28)
	ride.tween_property(dribble, "position:x", _vp.x * 1.11, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	ride.tween_property(dribble, "position",
		Vector2(_vp.x * 1.5, gy + _vp.y * 0.02), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ride.parallel().tween_property(dribble, "modulate:a", 0.0, 0.35)
	# The town waves the can goodbye from the cliff lip.
	var watch := _ct(mayor)
	watch.tween_interval(0.4)
	watch.tween_property(mayor, "position:x", _vp.x * 0.86, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for t: CartoonActor in townsfolk:
		var salute := _ct(t)
		salute.tween_interval(0.6)
		salute.tween_callback(func():
			t.set_arm_pose(CartoonActor.ArmPose.UP))
