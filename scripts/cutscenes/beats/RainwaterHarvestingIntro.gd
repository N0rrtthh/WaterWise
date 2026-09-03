## RainwaterHarvesting - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/RainwaterHarvestingIntro.tscn

extends MicrogameIntroBase

## Rainwater Harvesting — CAUSE clip.
## res://scenes/ui/cutscenes/beats/RainwaterHarvestingIntro.tscn
##
## BEAT 1  Rain falls over two empty barrels; the co-op duo stands ready.
## BEAT 2  (flash-only impact) The cloud darkens and dumps harder — the
##         duo exchanges a determined nod.
## BEAT 3  High-five! Both jump, palms meet mid-air. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/RainwaterHarvestingProps.gd")

var cloud: Node2D
var rain: GPUParticles2D
var barrels: Array = []
var partner: CartoonActor  # Player 2 — a distinct teal-skin townsfolk

func _setup_stage() -> void:
	get_node("Backdrop").color = Color(0.82, 0.88, 0.86)
	_stage_townsfolk(2, _vp.x * 0.18, _vp.x * 0.28)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.78, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.36)
	# Player 2: second collector with a distinct skin from the town palette.
	var skins: Array[Color] = CastFactory.TOWNSFOLK_SKINS
	partner = _stage_actor(CastFactory.make_townsfolk(1)[0], _vp.x * 0.68)
	partner.set_skin(skins[0])
	# The harvest barrels, empty.
	for x in [0.47, 0.59]:
		var barrel := Props.make_barrel(_vp.y * 0.24)
		barrel.position = Vector2(_vp.x * x, _vp.y * GROUND_FRACTION)
		barrel.z_index = 4
		world.add_child(barrel)
		barrels.append(barrel)
	# Storm cloud parked over the barrels, raining.
	cloud = Props.make_cloud(_vp.x * 0.22)
	cloud.position = Vector2(_vp.x * 0.53, _vp.y * 0.14)
	cloud.z_index = 6
	world.add_child(cloud)
	rain = Props.make_rain(_content_scale, _dot_texture())
	rain.position = cloud.position + Vector2(0.0, _vp.y * 0.05)
	rain.z_index = 5
	world.add_child(rain)
	camera.zoom = Vector2(1.2, 1.2)
	camera.position = _vp * 0.5

## BEAT 1 — rain on empty barrels; the duo sizes up the job.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	partner.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	# Drizzle: the rain sways gently.
	var sway := _ct(rain).set_loops(3)
	sway.tween_property(rain, "position:x", rain.position.x + 10.0 * _content_scale, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(rain, "position:x", rain.position.x - 10.0 * _content_scale, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The cloud bobs.
	var bob := _ct(cloud).set_loops(3)
	bob.tween_property(cloud, "position:y", cloud.position.y - 6.0 * _content_scale, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(cloud, "position:y", cloud.position.y, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# A few drops already trickle into the barrels.
	for b in range(barrels.size()):
		var barrel := barrels[b] as Node2D
		var fill := barrel.get_node("Fill") as Polygon2D
		var trickle := _ct(fill)
		trickle.tween_property(fill, "scale:y", 0.06 + 0.03 * float(b), _setup_sec())

## BEAT 2 — the sky opens up. Intro contract: flash only. The cloud darkens
## and dumps harder; the duo exchanges a determined nod.
func _on_impact() -> void:
	_impact_flash()
	# Cloud swells and darkens; rain surges.
	cloud.modulate = Color(0.82, 0.84, 0.88)
	var swell := _ct(cloud)
	swell.tween_property(cloud, "scale", Vector2(1.15, 1.15), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swell.tween_property(cloud, "scale", Vector2(1.05, 1.05), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var surge := _ct(rain)
	surge.tween_property(rain, "scale", Vector2(1.6, 1.3), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Barrels drum under the downpour.
	for b in range(barrels.size()):
		var barrel := barrels[b] as Node2D
		var drum := _ct(barrel).set_loops(2)
		drum.tween_property(barrel, "scale:y", 0.96, 0.06)
		drum.tween_property(barrel, "scale:y", 1.02, 0.06)
		drum.tween_property(barrel, "scale:y", 1.0, 0.06)
	# The nod: both lean toward each other and back.
	var lean_l := _ct(dribble)
	lean_l.tween_property(dribble, "rotation", 0.14, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean_l.tween_property(dribble, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var lean_r := _ct(partner)
	lean_r.tween_property(partner, "rotation", -0.14, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean_r.tween_property(partner, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	partner.set_expression(CartoonActor.Mood.WORRIED)

## BEAT 3 — the high-five. Both REACH, jump together, palms meet.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	partner.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	partner.set_arm_pose(CartoonActor.ArmPose.REACH)
	# They dash toward the middle and leap in sync.
	var meet_x := _vp.x * 0.52
	var dash_l := _ct()
	dash_l.tween_property(dribble, "position:x", meet_x - 26.0 * _content_scale, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var dash_r := _ct()
	dash_r.tween_property(partner, "position:x", meet_x + 26.0 * _content_scale, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dash_l.tween_callback(dribble.hop.bind(30.0, 0.26))
	dash_r.tween_callback(partner.hop.bind(30.0, 0.26))
	# Palms meet: both flash a CHEER on landing.
	var settle := _ct()
	settle.tween_interval(0.30)
	settle.tween_callback(func() -> void:
		dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
		partner.set_arm_pose(CartoonActor.ArmPose.CHEER))
	# Mayor approves the teamwork.
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.hop(14.0, 0.28)

