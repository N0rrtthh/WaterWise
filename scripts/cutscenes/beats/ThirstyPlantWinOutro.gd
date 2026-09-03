## ThirstyPlant - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ThirstyPlantWinOutro.tscn

extends MicrogameOutroBase

## Thirsty Plant — WIN clip.
## res://scenes/ui/cutscenes/beats/ThirstyPlantWinOutro.tscn
##
## BEAT 1  The freshly watered plant straightens up, bud swelling.
## BEAT 2  (impact) An ENORMOUS flower blooms with a pop.
## BEAT 3  The flower leans down and kisses Dribble; the crowd goes
##         "awww".

const Props := preload("res://scripts/cutscenes/beats/ThirstyPlantProps.gd")

var plant: Node2D
var plant_head: Node2D
var flower: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	ground.color = Props.GROUND
	ground.z_index = 0
	world.add_child(ground)
	_stage_townsfolk(2, _vp.x * 0.72, _vp.x * 0.84)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.94, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.20)
	# The watered plant, perked, with its green bucket resting beside it.
	plant = Props.make_potted_plant(_vp.y * 0.44)
	plant.position = Vector2(_vp.x * 0.38, _vp.y * GROUND_FRACTION)
	plant.z_index = 3
	plant_head = plant.get_node("Head") as Node2D
	plant_head.rotation = 0.12
	world.add_child(plant)
	var bucket := Props.make_bucket(_vp.y * 0.15, Props.BUCKET_GREEN)
	bucket.position = Vector2(_vp.x * 0.45, _vp.y * GROUND_FRACTION)
	bucket.rotation = 2.4
	bucket.z_index = 4
	world.add_child(bucket)
	# The bloom, hidden at zero until the pop.
	flower = Props.make_flower(_vp.y * 0.34)
	flower.position = bud_point()
	flower.scale = Vector2(0.0, 0.0)
	flower.z_index = 6
	world.add_child(flower)
	camera.position = _vp * 0.5

func bud_point() -> Vector2:
	return plant.position + plant_head.position \
		+ Vector2(0.0, -_vp.y * 0.15)

## Impact frame: the bloom's centre.
func _impact_point() -> Vector2:
	return flower.position

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The plant drinks: head straightens, leaves lift, bud swells.
	var straighten := _ct(plant_head)
	straighten.tween_property(plant_head, "rotation", 0.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bud := plant_head.get_node("Bud") as Polygon2D
	var swell := _ct(bud).set_loops(2)
	swell.tween_property(bud, "scale", Vector2(1.25, 1.25), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swell.tween_property(bud, "scale", Vector2(1.05, 1.05), 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The town hushes, leaning in.
	for i in range(townsfolk.size()):
		var hush := _ct(townsfolk[i]).set_loops(2)
		hush.tween_interval(0.24 * float(i))
		hush.tween_callback(townsfolk[i].hop.bind(4.0, 0.30))
		hush.tween_interval(0.34)

## BEAT 2 — the bloom-pop ON the tick.
func _on_impact() -> void:
	super._on_impact()
	# The bud vanishes into the flower as it pops huge, then settles.
	var bud := plant_head.get_node("Bud") as Polygon2D
	bud.modulate.a = 0.0
	var pop := _ct(flower)
	pop.tween_property(flower, "scale", Vector2(1.30, 1.30), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(flower, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# A ring of petal sparks flings outward.
	for i in range(8):
		var spark := Polygon2D.new()
		spark.polygon = Props._ellipse(7.0 * _content_scale, 4.0 * _content_scale, 8)
		spark.position = _impact_point()
		spark.rotation = float(i) * TAU / 8.0
		spark.color = Props.BLOOM.lightened(0.1)
		spark.z_index = 7
		world.add_child(spark)
		var dir := Vector2(sin(float(i) * TAU / 8.0), -cos(float(i) * TAU / 8.0))
		var fly := _ct(spark)
		fly.tween_property(spark, "position", _impact_point() + dir * 80.0 * _content_scale, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(spark, "modulate:a", 0.0, 0.30)
		fly.tween_callback(spark.queue_free)
	# The flower sways with fresh life.
	var sway := _ct(flower)
	sway.tween_property(flower, "rotation", 0.05, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(flower, "rotation", -0.05, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The crowd is stunned.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the flower leans down and kisses Dribble; the crowd
## "awww"s in unison.
func _beat_payoff() -> void:
	# The whole bloom (flower + stem follow) leans toward Dribble.
	var lean := _ct(flower)
	lean.tween_property(flower, "position",
		dribble.position + Vector2(_vp.x * 0.015, -_vp.y * 0.17), 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean.parallel().tween_property(flower, "rotation", -0.9, 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# THE KISS: a boop-and-bounce on Dribble's head.
	var kiss := _ct(dribble)
	kiss.tween_interval(0.30)
	kiss.tween_callback(func() -> void:
		dribble.set_expression(CartoonActor.Mood.HAPPY)
		dribble.hop(10.0, 0.14))
	kiss.tween_property(dribble, "scale", Vector2(0.94, 1.06), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kiss.tween_property(dribble, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# A cluster of hearts floats up from the kiss.
	for i in range(4):
		var heart := Props.make_heart(26.0 * _content_scale)
		heart.position = dribble.position + Vector2(
			(-8.0 + 12.0 * float(i % 2)) * _content_scale, -_vp.y * 0.13)
		heart.scale = Vector2(0.6, 0.6)
		heart.z_index = 8
		world.add_child(heart)
		var float_heart := _ct(heart)
		float_heart.tween_interval(0.32 + 0.10 * float(i))
		float_heart.tween_property(heart, "position:y",
			heart.position.y - _vp.y * 0.10, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		float_heart.parallel().tween_property(heart, "modulate:a", 0.0, 0.6)
		float_heart.parallel().tween_property(heart, "scale", Vector2(1.1, 1.1), 0.6)
		float_heart.tween_callback(heart.queue_free)
	# The flower leans back up, beaming.
	var rise := _ct(flower)
	rise.tween_interval(0.52)
	rise.tween_property(flower, "position", bud_point(), 0.36) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.parallel().tween_property(flower, "rotation", 0.0, 0.36)
	# The collective "awww": synchronized soft hops + hands to cheeks.
	for i in range(townsfolk.size()):
		var fan := townsfolk[i] as CartoonActor
		fan.set_expression(CartoonActor.Mood.HAPPY)
		fan.set_arm_pose(CartoonActor.ArmPose.UP)
		var awww := _ct(fan)
		awww.tween_interval(0.44 + 0.03 * float(i))
		awww.tween_callback(fan.hop.bind(6.0, 0.26))
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(6.0, 0.30)
	# Dribble takes a bashful little bow.
	var bow := _ct(dribble)
	bow.tween_interval(0.7)
	bow.tween_property(dribble, "rotation", 0.12, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(dribble, "rotation", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

