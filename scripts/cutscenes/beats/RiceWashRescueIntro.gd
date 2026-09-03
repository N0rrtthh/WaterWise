## RiceWashRescue - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/RiceWashRescueIntro.tscn

extends MicrogameIntroBase

## Rice Wash Rescue — CAUSE clip.
## res://scenes/ui/cutscenes/beats/RiceWashRescueIntro.tscn
##
## BEAT 1  Kitchen counter: an empty bowl waits, the rice bag stands tall.
## BEAT 2  (flash-only impact) The bag TIPS — grains scatter everywhere;
##         Mayor Ripple flings himself over his plate.
## BEAT 3  Dribble scrambles to scoop the grains back. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/RiceWashRescueProps.gd")

var bag: Node2D
var bowl: Node2D
var scatter: GPUParticles2D
var floor_grains: Array = []
var plate: Polygon2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Color(0.9, 0.85, 0.8)
	_stage_townsfolk(2, _vp.x * 0.16, _vp.x * 0.24)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.30)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.80, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	# The counter table with the empty rice bowl.
	var table := Props.make_table(_vp.x * 0.34, _vp.y * 0.16)
	table.position = Vector2(_vp.x * 0.55, _vp.y * GROUND_FRACTION)
	table.z_index = 3
	world.add_child(table)
	bowl = Props.make_bowl(_vp.y * 0.22)
	bowl.position = Vector2(_vp.x * 0.53, _vp.y * GROUND_FRACTION - _vp.y * 0.16)
	bowl.z_index = 4
	world.add_child(bowl)
	# The proud upright rice bag, still full.
	bag = Props.make_bag(_vp.y * 0.30)
	bag.position = Vector2(_vp.x * 0.38, _vp.y * GROUND_FRACTION)
	bag.z_index = 4
	world.add_child(bag)
	# The Mayor's plate, in front of him on a small side table.
	var side := Props.make_table(_vp.x * 0.12, _vp.y * 0.10)
	side.position = Vector2(_vp.x * 0.80, _vp.y * GROUND_FRACTION)
	side.z_index = 3
	world.add_child(side)
	plate = Props.make_plate(_vp.y * 0.16)
	plate.position = Vector2(_vp.x * 0.80, _vp.y * GROUND_FRACTION - _vp.y * 0.10)
	plate.z_index = 4
	world.add_child(plate)
	# The coming disaster, armed and waiting.
	scatter = Props.make_grain_burst(40, 520.0 * _content_scale, _dot_texture())
	scatter.position = bag.position + Vector2(0.0, -_vp.y * 0.20)
	scatter.z_index = 5
	world.add_child(scatter)
	camera.zoom = Vector2(1.15, 1.15)
	camera.position = _vp * 0.5

## BEAT 1 — the kitchen hums; the bag wobbles menacingly.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# Bag wobble: the top-heavy sack sways.
	var wobble := _ct(bag).set_loops(3)
	wobble.tween_property(bag, "rotation", 0.07, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(bag, "rotation", -0.07, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Mayor inspects his plate, proud.
	var inspect := _ct(mayor).set_loops(2)
	inspect.tween_property(mayor, "rotation", -0.05, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	inspect.tween_property(mayor, "rotation", 0.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the tip. Intro contract: flash only. Grains go EVERYWHERE and
## the Mayor covers his plate with his whole body.
func _on_impact() -> void:
	_impact_flash()
	# The bag keels over.
	var tip := _ct(bag)
	tip.tween_property(bag, "rotation", 1.9, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tip.parallel().tween_property(bag, "position:y", bag.position.y - _vp.y * 0.05, 0.16)
	tip.tween_callback(func() -> void: scatter.emitting = true)
	# Grains pepper the floor as static props.
	for i in range(8):
		var g := Props.make_grain(9.0 * _content_scale, randf() * PI)
		g.position = Vector2(
			_vp.x * (0.30 + 0.45 * randf()),
			_vp.y * GROUND_FRACTION - randf() * 6.0 * _content_scale)
		g.z_index = 2
		world.add_child(g)
		floor_grains.append(g)
	# Mayor Ripple: full defensive crouch OVER the plate.
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(16.0, 0.22)
	var shield := _ct(mayor)
	shield.tween_property(mayor, "scale", Vector2(1.05, 0.94), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shield.tween_property(mayor, "scale", CastFactory.MAYOR_SCALE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Dribble reels from the spill.
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.hop(20.0, 0.24)

## BEAT 3 — the scramble. Dribble scoops grains back toward the bowl;
## the Mayor guards his plate for dear life.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	# Scoop-scoop-scoop: three quick reaches at the floor grains.
	for i in range(3):
		var scoop := _ct()
		scoop.tween_interval(0.14 * float(i))
		scoop.tween_callback(func() -> void:
			dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
			dribble.hop(10.0, 0.14))
		if not floor_grains.is_empty() and i < floor_grains.size():
			var g := floor_grains[i] as Polygon2D
			var gather := _ct(g)
			gather.tween_interval(0.14 * float(i) + 0.10)
			gather.tween_property(g, "position", bowl.position, 0.12) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			gather.tween_callback(g.queue_free)
	# The Mayor stays glued to his plate, eyes darting.
	var guard := _ct(mayor).set_loops(2)
	guard.tween_property(mayor, "rotation", 0.05, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	guard.tween_property(mayor, "rotation", -0.05, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	# A couple of townsfolk hurry over to help.
	for i in range(townsfolk.size()):
		var helper := _ct()
		helper.tween_interval(0.10 * float(i))
		helper.tween_property(townsfolk[i], "position:x",
			townsfolk[i].position.x + _vp.x * 0.04, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		townsfolk[i].set_arm_pose(CartoonActor.ArmPose.REACH)

