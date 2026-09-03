## RiceWashRescue - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/RiceWashRescueWinOutro.tscn

extends MicrogameOutroBase

## Rice Wash Rescue — WIN clip.
## res://scenes/ui/cutscenes/beats/RiceWashRescueWinOutro.tscn
##
## BEAT 1  The rescued grains sit waiting in the bowl.
## BEAT 2  (impact) A PERFECT steaming bowl of rice appears — mound rises,
##         steam bursts on, a shine sweeps across the glaze.
## BEAT 3  Chairs slide in instantly. The town feasts.

const Props := preload("res://scripts/cutscenes/beats/RiceWashRescueProps.gd")

var bowl: Node2D
var steam: GPUParticles2D
var rice: Polygon2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Color(0.9, 0.85, 0.8)
	_stage_townsfolk(2, _vp.x * 0.14, _vp.x * 0.90)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.38)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.72, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	var table := Props.make_table(_vp.x * 0.36, _vp.y * 0.16)
	table.position = Vector2(_vp.x * 0.50, _vp.y * GROUND_FRACTION)
	table.z_index = 3
	world.add_child(table)
	bowl = Props.make_bowl(_vp.y * 0.24)
	bowl.position = Vector2(_vp.x * 0.50, _vp.y * GROUND_FRACTION - _vp.y * 0.16)
	bowl.z_index = 4
	world.add_child(bowl)
	rice = bowl.get_node("Rice") as Polygon2D
	# Steam waits, hidden above the bowl.
	steam = Props.make_steam(_dot_texture())
	steam.position = bowl.position + Vector2(0.0, -_vp.y * 0.16)
	steam.z_index = 6
	world.add_child(steam)
	# The rescued bag stands tall again beside the table.
	var bag := Props.make_bag(_vp.y * 0.28)
	bag.position = Vector2(_vp.x * 0.30, _vp.y * GROUND_FRACTION)
	bag.z_index = 2
	world.add_child(bag)
	# The Mayor's plate, dignity restored.
	var side := Props.make_table(_vp.x * 0.12, _vp.y * 0.10)
	side.position = Vector2(_vp.x * 0.72, _vp.y * GROUND_FRACTION)
	side.z_index = 3
	world.add_child(side)
	var plate := Props.make_plate(_vp.y * 0.16)
	plate.position = Vector2(_vp.x * 0.72, _vp.y * GROUND_FRACTION - _vp.y * 0.10)
	plate.z_index = 4
	world.add_child(plate)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Suspense: the empty bowl sits there while everyone leans in.
	var lean := _ct(bowl).set_loops(2)
	lean.tween_property(bowl, "scale", Vector2(1.02, 0.99), 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean.tween_property(bowl, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Impact frame: dead centre of the bowl's glaze.
func _impact_point() -> Vector2:
	return bowl.position + Vector2(0.0, -_vp.y * 0.10)

## BEAT 2 — the reveal. Full impact stack as the perfect bowl appears.
func _on_impact() -> void:
	super._on_impact()
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	# The rice mound rises proud of the rim.
	var rise := _ct(rice)
	rise.tween_property(rice, "scale:y", 1.0, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Steam ON.
	steam.emitting = true
	# Shine sweep across the bowl.
	var shine := bowl.get_node("Shine") as Polygon2D
	shine.visible = true
	var sweep := _ct(shine)
	sweep.tween_property(shine, "position:x", shine.position.x + _vp.y * 0.13, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sweep.tween_callback(func() -> void: shine.visible = false)
	# The bowl does a proud little settle.
	var settle := _ct(bowl)
	settle.tween_property(bowl, "scale", Vector2(1.06, 1.04), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(bowl, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(14.0, 0.24)

## BEAT 3 — chairs slide in INSTANTLY; the whole town takes a seat to feast.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# Two chairs whip in from off-screen, one per townsfolk.
	for i in range(townsfolk.size()):
		var from_left := i == 0
		var chair := Props.make_chair(_vp.y * 0.16)
		chair.position = Vector2(
			-_vp.x * 0.10 if from_left else _vp.x * 1.10,
			_vp.y * GROUND_FRACTION)
		chair.z_index = 2
		world.add_child(chair)
		var target_x := townsfolk[i].position.x
		var slide := _ct(chair)
		slide.tween_property(chair, "position:x", target_x, 0.10) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# The townsperson hops aboard their chair mid-slide.
		var sit := _ct()
		sit.tween_interval(0.06)
		sit.tween_callback(func() -> void:
			townsfolk[i].hop(26.0, 0.18))
		sit.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		# Chair + diner bob as they land.
		var bounce := _ct(chair)
		bounce.tween_interval(0.16)
		bounce.tween_property(chair, "scale", Vector2(1.0, 0.90), 0.06)
		bounce.tween_property(chair, "scale", Vector2(1.0, 1.0), 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The Mayor pulls his own chair from the side table.
	var mayor_chair := Props.make_chair(_vp.y * 0.20)
	mayor_chair.position = Vector2(_vp.x * 1.02, _vp.y * GROUND_FRACTION)
	mayor_chair.z_index = 2
	mayor_chair.scale = CastFactory.MAYOR_SCALE
	world.add_child(mayor_chair)
	var mc := _ct(mayor_chair)
	mc.tween_property(mayor_chair, "position:x", _vp.x * 0.82, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var mhop := _ct()
	mhop.tween_interval(0.10)
	mhop.tween_callback(mayor.hop.bind(20.0, 0.20))
	mhop.tween_callback(mayor.set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
	# Dribble takes a bow at the head of the table.
	var bow := _ct(dribble)
	bow.tween_property(dribble, "rotation", 0.14, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(dribble, "rotation", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

