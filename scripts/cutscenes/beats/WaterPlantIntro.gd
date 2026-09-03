## WaterPlant - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WaterPlantIntro.tscn

extends MicrogameIntroBase

## Water Plant — CAUSE clip.
## res://scenes/ui/cutscenes/beats/WaterPlantIntro.tscn
##
## BEAT 1  Rows of thirsty plants droop in their pots on the garden dirt
##         while a watering can HOVERS overhead. Mayor Ripple bites his
##         nails watching.
## BEAT 2  (flash impact) The plants shiver, the can tilts and leaks a
##         single drop — everyone's nerves fray.
## BEAT 3  The can tips and pours one arc; the first plant perks up.

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
	# The row of thirsty potted plants, drooping hard.
	plant_size = _vp.y * 0.17
	var plant_x := [0.24, 0.36, 0.48, 0.60]
	var droop := [0.55, -0.45, 0.5, -0.55]
	for i in range(4):
		var plant := GProps.make_potted_plant(plant_size)
		plant.position = Vector2(_vp.x * plant_x[i], gy)
		plant.z_index = 2
		var head := plant.get_node("Head") as Node2D
		head.rotation = droop[i]
		world.add_child(plant)
		plants.append(plant)
	# The watering can, hovering mysteriously overhead.
	can = Props.make_watering_can(_vp.y * 0.14)
	can.position = Vector2(_vp.x * 0.42, gy - _vp.y * 0.42)
	can.z_index = 3
	world.add_child(can)
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.88, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.72)
	camera.position = _vp * 0.5

## BEAT 1 — drooping rows; hovering can; the mayor bites his nails.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	for t in townsfolk:
		t.start_idle()
	# The droop heads sway nervously.
	for i in range(plants.size()):
		var plant := plants[i] as Node2D
		var head := plant.get_node("Head") as Node2D
		var sway := _ct(head).set_loops(3)
		sway.tween_property(head, "rotation", head.rotation - 0.1, 0.17) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(head, "rotation", head.rotation + 0.1, 0.17) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The can bobs in mid-air, defying gravity.
	var hover := _ct(can).set_loops(3)
	hover.tween_property(can, "position:y", can.position.y - _vp.y * 0.02, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover.tween_property(can, "position:y", can.position.y, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor's nail-bite: a tight anxious shiver.
	var bite := _ct(mayor).set_loops(3)
	bite.tween_property(mayor, "position:y",
		mayor.position.y - 2.0 * _content_scale, 0.07)
	bite.tween_property(mayor, "position:y", mayor.position.y, 0.07)

## BEAT 2 — the plants shiver; the can leaks a single ominous drop.
func _on_impact() -> void:
	_impact_flash()
	for plant: Node2D in plants:
		var head := plant.get_node("Head") as Node2D
		var shiver := _ct(head)
		shiver.tween_property(head, "rotation",
			head.rotation + 0.12 * (1.0 if head.rotation >= 0.0 else -1.0), 0.05)
		shiver.tween_property(head, "rotation", head.rotation, 0.08)
	# The can tips, and one fat drop falls.
	var tip := _ct(can)
	tip.tween_property(can, "rotation", 0.22, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fill := can.get_node("Fill") as Polygon2D
	fill.visible = true
	var drop := Polygon2D.new()
	drop.polygon = Props._ellipse(_vp.y * 0.012, _vp.y * 0.016)
	drop.color = Props.WATER
	drop.position = can.position + Vector2(-_vp.y * 0.06, _vp.y * 0.05)
	drop.z_index = 4
	world.add_child(drop)
	var fall := _ct(drop)
	fall.tween_property(drop, "position:y",
		_vp.y * GROUND_FRACTION - _vp.y * 0.02, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(drop, "modulate:a", 0.0, 0.28)
	fall.tween_callback(drop.queue_free)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(10.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.WORRIED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.WORRIED)

## BEAT 3 — the can pours one arc and the first plant perks up.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	# The can swings over the first plant and pours.
	var move := _ct(can)
	move.tween_property(can, "position",
		Vector2(_vp.x * 0.24, _vp.y * GROUND_FRACTION - _vp.y * 0.38), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pour := GProps.make_water_arc(_vp.y * 0.2)
	pour.position = can.position + Vector2(-_vp.y * 0.07, _vp.y * 0.02)
	pour.rotation = 1.2
	pour.z_index = 4
	world.add_child(pour)
	var stream := _ct(pour)
	stream.tween_interval(0.22)
	stream.tween_property(pour, "scale:x", 1.0, 0.16)
	# The first plant straightens up, grateful.
	var plant := plants[0] as Node2D
	var head := plant.get_node("Head") as Node2D
	var perk := _ct(head)
	perk.tween_interval(0.3)
	perk.tween_property(head, "rotation", 0.0, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Dribble reaches for the can; the mayor leans in hopeful.
	var reach := _ct(dribble)
	reach.tween_property(dribble, "position:x", _vp.x * 0.66, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
