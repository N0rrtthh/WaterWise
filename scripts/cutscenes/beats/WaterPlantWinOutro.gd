## WaterPlant - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WaterPlantWinOutro.tscn

extends MicrogameOutroBase

## Water Plant — WIN clip.
## res://scenes/ui/cutscenes/beats/WaterPlantWinOutro.tscn
##
## BEAT 1  Giant blooms burst open on every plant, crowned by the grand
##         flower THRONE blooming at centre stage.
## BEAT 2  (impact on the lift) The throne lifts Dribble high — the
##         garden's new king.
## BEAT 3  Petals rain down over the town below.

const GProps := preload("res://scripts/cutscenes/beats/ThirstyPlantProps.gd")
const Props := preload("res://scripts/cutscenes/beats/WaterPlantProps.gd")

var plants: Array = []
var blooms: Array = []
var throne: Node2D
var throne_x: float
var throne_y: float

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
	# The row of healthy potted plants, standing tall.
	var plant_size := _vp.y * 0.17
	var plant_x := [0.18, 0.30, 0.44, 0.56]
	for i in range(4):
		var plant := GProps.make_potted_plant(plant_size)
		plant.position = Vector2(_vp.x * plant_x[i], gy)
		plant.z_index = 2
		var head := plant.get_node("Head") as Node2D
		head.rotation = 0.0
		world.add_child(plant)
		plants.append(plant)
		# Each plant hides a giant bloom, ready to burst.
		var bloom := GProps.make_flower(_vp.y * 0.19)
		bloom.position = plant.position + Vector2(0.0, -plant_size * 0.72)
		bloom.scale = Vector2.ZERO
		bloom.z_index = 3
		world.add_child(bloom)
		blooms.append(bloom)
	# The grand flower THRONE, centre-right, also furled for now.
	throne_x = _vp.x * 0.72
	throne_y = gy
	throne = GProps.make_flower(_vp.y * 0.34)
	throne.position = Vector2(throne_x, throne_y - _vp.y * 0.20)
	throne.scale = Vector2.ZERO
	throne.z_index = 2
	world.add_child(throne)
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.72)
	camera.position = _vp * 0.5

## Impact frame: where the lifted champion ends up, above the throne.
func _impact_point() -> Vector2:
	return Vector2(throne_x, throne_y - _vp.y * 0.20 - _vp.y * 0.14)

## BEAT 1 — the blooms burst open, throne last (grandest).
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	for i in range(blooms.size()):
		var bloom := blooms[i] as Node2D
		var burst := _ct(bloom)
		burst.tween_interval(0.12 * float(i))
		burst.tween_property(bloom, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var petals := bloom.get_children()
		for child in petals:
			var petal := child as Polygon2D
			if petal == null:
				continue
			var flutter := _ct(petal).set_loops(2)
			flutter.tween_interval(0.3 + 0.12 * float(i))
			flutter.tween_property(petal, "rotation",
				petal.rotation + 0.12, 0.16) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			flutter.tween_property(petal, "rotation",
				petal.rotation - 0.12, 0.16) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var grand := _ct(throne)
	grand.tween_interval(0.62)
	grand.tween_property(throne, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## BEAT 2 — THE LIFT: the throne hoists Dribble skyward.
func _on_impact() -> void:
	super._on_impact()
	# The throne bows under its champion, then lifts him high.
	var bow := _ct(throne)
	bow.tween_property(throne, "scale", Vector2(1.06, 0.94), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bow.tween_property(throne, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var lift := _ct(dribble)
	lift.set_parallel(true)
	lift.tween_property(dribble, "position",
		Vector2(throne_x, _impact_point().y + _vp.y * 0.02), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(dribble, "rotation", -0.08, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 3 — petals rain down over the town below.
func _beat_payoff() -> void:
	var gy := _vp.y * GROUND_FRACTION
	# The throne drifts gently, champion riding tall.
	var drift := _ct(dribble)
	drift.tween_property(dribble, "position:y",
		_impact_point().y - _vp.y * 0.04, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var petal_colors := [Props.PETAL_PINK, Props.PETAL_LIGHT, Props.PETAL_GOLD]
	for i in range(12):
		var petal := Props.make_petal(_vp.y * 0.028, petal_colors[i % 3])
		petal.position = Vector2(
			_vp.x * (0.06 + 0.075 * float(i % 12)),
			-_vp.y * (0.04 + 0.05 * float(i % 3)))
		petal.rotation = randf() * TAU
		petal.z_index = 7
		world.add_child(petal)
		var fall := _ct(petal)
		fall.tween_interval(0.045 * float(i))
		fall.set_parallel(true)
		fall.tween_property(petal, "position:y", gy - _vp.y * 0.01,
			0.75 + 0.03 * float(i % 4)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fall.tween_property(petal, "position:x",
			petal.position.x + _vp.x * 0.045, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fall.tween_property(petal, "rotation", petal.rotation + 4.0, 0.8)
		fall.chain().tween_property(petal, "modulate:a", 0.0, 0.12)
	# The town below cheers the petal shower.
	var cheer_x := [0.10, 0.20, 0.32]
	for i in range(townsfolk.size()):
		var t := townsfolk[i] as Node2D
		var walk := _ct(t)
		walk.tween_property(t, "position:x", _vp.x * cheer_x[i % cheer_x.size()], 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var gather := _ct(mayor)
	gather.tween_property(mayor, "position:x", _vp.x * 0.44, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for t: CartoonActor in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	# The blooms sway in celebration.
	for bloom: Node2D in blooms:
		var sway := _ct(bloom).set_loops(2)
		sway.tween_property(bloom, "rotation", 0.09, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(bloom, "rotation", -0.09, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
