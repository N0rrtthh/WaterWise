## ThirstyPlant - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ThirstyPlantIntro.tscn

extends MicrogameIntroBase

## Thirsty Plant — CAUSE clip.
## res://scenes/ui/cutscenes/beats/ThirstyPlantIntro.tscn
##
## BEAT 1  A row of identical buckets shuffles back and forth in front
##         of a wilting plant; one is secretly glowing green. The town
##         watches.
## BEAT 2  (flash-only impact) The green glow FLARES — the shuffle
##         freezes and the town gasps at the tell.
## BEAT 3  The buckets part and the green bucket rolls up to pour. SNAP
##         into gameplay.

const Props := preload("res://scripts/cutscenes/beats/ThirstyPlantProps.gd")

const SECRET_INDEX := 1

var buckets: Array = []
var glow: Polygon2D
var plant_head: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	# Ground strip in the minigame's brown.
	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	ground.color = Props.GROUND
	ground.z_index = 0
	world.add_child(ground)
	_stage_townsfolk(2, _vp.x * 0.70, _vp.x * 0.82)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.93, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.12)
	# The wilting plant, already drooping.
	var plant := Props.make_potted_plant(_vp.y * 0.40)
	plant.position = Vector2(_vp.x * 0.36, _vp.y * GROUND_FRACTION)
	plant.z_index = 3
	plant_head = plant.get_node("Head") as Node2D
	plant_head.rotation = 0.35
	world.add_child(plant)
	# The shuffling bucket row.
	for i in range(4):
		var bucket := Props.make_bucket(_vp.y * 0.17, Props.BUCKET_BLUE)
		bucket.position = Vector2(_vp.x * (0.30 + 0.08 * float(i)),
			_vp.y * GROUND_FRACTION)
		bucket.z_index = 5
		world.add_child(bucket)
		buckets.append(bucket)
	# The secret tell: a green glow tucked behind one bucket.
	glow = Props.make_glow(_vp.y * 0.17)
	glow.position = Vector2(0.0, -_vp.y * 0.085)
	glow.z_index = -1
	glow.modulate.a = 0.25
	(buckets[SECRET_INDEX] as Node2D).add_child(glow)
	camera.position = _vp * 0.5

## BEAT 1 — the shuffle and the flicker of the tell.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The buckets shuffle back and forth, out of phase.
	for i in range(buckets.size()):
		var bucket := buckets[i] as Node2D
		var base_x := bucket.position.x
		var shuffle := _ct(bucket).set_loops(3)
		shuffle.tween_interval(0.10 * float(i % 3))
		shuffle.tween_property(bucket, "position:x",
			base_x + 26.0 * _content_scale, 0.20) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shuffle.tween_property(bucket, "position:x",
			base_x - 22.0 * _content_scale, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shuffle.tween_property(bucket, "position:x", base_x, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The secret glow pulses, almost invisible.
	var pulse := _ct(glow).set_loops(3)
	pulse.tween_property(glow, "modulate:a", 0.45, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "modulate:a", 0.15, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The plant wilts a little more with each pass.
	var sag := _ct(plant_head).set_loops(2)
	sag.tween_property(plant_head, "rotation", 0.42, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sag.tween_property(plant_head, "rotation", 0.35, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the tell flares and the shuffle freezes. Flash only.
func _on_impact() -> void:
	_impact_flash()
	# The glow blows out bright — everyone sees it.
	var flare := _ct(glow)
	flare.tween_property(glow, "modulate:a", 1.0, 0.06)
	flare.tween_property(glow, "modulate:a", 0.55, 0.18)
	var secret := buckets[SECRET_INDEX] as Node2D
	reveal_secret(secret)
	# The shuffle dies mid-step: every bucket halts and straightens.
	for bucket in buckets:
		var halt := _ct(bucket as Node2D)
		halt.tween_property(bucket, "rotation", 0.0, 0.10)
	# The town gasps at the tell.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## Swap a bucket's body to its true colour.
func reveal_secret(bucket: Node2D) -> void:
	var paint := _ct(bucket)
	paint.tween_callback(func() -> void:
		(bucket.get_node("Body") as Polygon2D).color = Props.BUCKET_GREEN)

## BEAT 3 — the buckets part; the green one rolls up to pour.
func _beat_payoff() -> void:
	# The decoys slide aside.
	for i in range(buckets.size()):
		if i == SECRET_INDEX:
			continue
		var dir := -1.0 if float(i) < float(SECRET_INDEX) else 1.0
		var decoy := buckets[i] as Node2D
		var slide := _ct(decoy)
		slide.tween_property(decoy, "position:x",
			decoy.position.x + dir * _vp.x * 0.06, 0.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The green bucket rolls forward to the plant.
	var secret := buckets[SECRET_INDEX] as Node2D
	var roll := _ct(secret)
	roll.tween_property(secret, "position",
		Vector2(_vp.x * 0.28, _vp.y * GROUND_FRACTION), 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	roll.parallel().tween_property(secret, "rotation", -2.2, 0.26)
	# It tips and pours: the water arc whips out into the pot.
	var arc := Props.make_water_arc(_vp.y * 0.14)
	arc.position = secret.position + Vector2(-_vp.y * 0.02, -_vp.y * 0.16)
	arc.rotation = -1.9
	arc.scale = Vector2(0.0, 1.0)
	arc.z_index = 6
	world.add_child(arc)
	var pour := _ct(arc)
	pour.tween_interval(0.26)
	pour.tween_property(arc, "scale:x", 1.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The plant perks up at the first drops.
	var perk := _ct(plant_head)
	perk.tween_interval(0.30)
	perk.tween_property(plant_head, "rotation", 0.12, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The crowd cranes in.
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.REACH)

