## RiceWashRescue - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/RiceWashRescueLoseOutro.tscn

extends MicrogameOutroBase

## Rice Wash Rescue — LOSE clip.
## res://scenes/ui/cutscenes/beats/RiceWashRescueLoseOutro.tscn
##
## BEAT 1  The bag gives up entirely — rice pours and pours.
## BEAT 2  (impact) The avalanche BURIES Dribble completely.
## BEAT 3  The town eats its way through the pile, then flicks the last
##         grain — and Dribble with it — off the cliff.

const Props := preload("res://scripts/cutscenes/beats/RiceWashRescueProps.gd")

const CLIFF_X := 0.94

var bag: Node2D
var pour: GPUParticles2D
var mound: Polygon2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Color(0.9, 0.85, 0.8)
	_stage_townsfolk(2, _vp.x * 0.14, _vp.x * 0.22)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.46)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.80, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	var table := Props.make_table(_vp.x * 0.20, _vp.y * 0.16)
	table.position = Vector2(_vp.x * 0.60, _vp.y * GROUND_FRACTION)
	table.z_index = 3
	world.add_child(table)
	var bowl := Props.make_bowl(_vp.y * 0.22)
	bowl.position = Vector2(_vp.x * 0.60, _vp.y * GROUND_FRACTION - _vp.y * 0.16)
	bowl.z_index = 4
	world.add_child(bowl)
	# The doomed bag, mid-keel already.
	bag = Props.make_bag(_vp.y * 0.30)
	bag.position = Vector2(_vp.x * 0.36, _vp.y * GROUND_FRACTION)
	bag.rotation = 0.5
	bag.z_index = 4
	world.add_child(bag)
	# The continuous pour, from the bag's mouth.
	pour = Props.make_grain_burst(50, 380.0 * _content_scale, _dot_texture())
	pour.one_shot = false
	pour.explosiveness = 0.0
	pour.lifetime = 0.8
	pour.position = bag.position + Vector2(_vp.x * 0.04, -_vp.y * 0.18)
	pour.z_index = 5
	pour.emitting = false
	world.add_child(pour)
	# The avalanche mound: starts as a trickle at Dribble's feet.
	mound = Polygon2D.new()
	mound.name = "Avalanche"
	mound.polygon = PackedVector2Array([
		Vector2(-_vp.x * 0.10, 0.0), Vector2(-_vp.x * 0.05, -_vp.y * 0.16),
		Vector2(0.0, -_vp.y * 0.22), Vector2(_vp.x * 0.05, -_vp.y * 0.16),
		Vector2(_vp.x * 0.10, 0.0),
	])
	mound.position = Vector2(_vp.x * 0.46, _vp.y * GROUND_FRACTION)
	mound.color = Props.RICE
	mound.scale = Vector2(0.15, 0.01)
	mound.z_index = 6
	world.add_child(mound)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.DROOP)
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	# The bag finishes its keel-over and the pour begins.
	var tip := _ct(bag)
	tip.tween_property(bag, "rotation", 2.0, _setup_sec() * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tip.parallel().tween_property(bag, "position:y", bag.position.y - _vp.y * 0.05, _setup_sec() * 0.7)
	tip.tween_callback(func() -> void: pour.emitting = true)
	# The mound creeps up Dribble's shins.
	var creep := _ct(mound)
	creep.tween_property(mound, "scale", Vector2(0.45, 0.16), _setup_sec()) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Impact frame: the peak of the burial mound.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.46, _vp.y * GROUND_FRACTION - _vp.y * 0.14)

## BEAT 2 — the burial. Full impact stack as the avalanche swallows him.
func _on_impact() -> void:
	super._on_impact()
	dribble.set_expression(CartoonActor.Mood.DIZZY)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.hop(14.0, 0.20)
	# The whole bag empties on his head.
	var burst := _ct(mound)
	burst.tween_property(mound, "scale", Vector2(1.15, 1.15), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Dribble vanishes beneath the white.
	var swallow := _ct()
	swallow.tween_interval(0.16)
	swallow.tween_callback(func() -> void: dribble.visible = false)
	# Mayor peeks over his plate at the carnage.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.22)
	# One last grain bounces off the pile for comic timing.
	var g := Props.make_grain(10.0 * _content_scale, randf() * PI)
	g.position = _impact_point() + Vector2(0.0, -_vp.y * 0.04)
	g.z_index = 7
	world.add_child(g)
	var bounce := _ct(g)
	bounce.tween_property(g, "position:y", g.position.y + _vp.y * 0.03, 0.14) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## BEAT 3 — the town eats the pile down to one grain, then flicks it —
## and Dribble with it — off the cliff.
func _beat_payoff() -> void:
	_eat_and_flick()

func _eat_and_flick() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	var ride_time := _payoff_sec()
	# Everyone hops to the pile and nibbles it away.
	for i in range(townsfolk.size()):
		var diner := townsfolk[i] as CartoonActor
		var approach := _ct()
		approach.tween_interval(0.08 * float(i))
		approach.tween_property(diner, "position:x",
			mound.position.x - _vp.x * 0.12 + _vp.x * 0.08 * float(i), 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var nibble := _ct(diner).set_loops(int(ride_time / 0.24))
		nibble.tween_interval(0.08 * float(i) + 0.18)
		nibble.tween_callback(diner.hop.bind(9.0, 0.12))
		nibble.tween_interval(0.12)
	# The Mayor eats too, with terrible table manners.
	var mayor_go := _ct()
	mayor_go.tween_interval(0.05)
	mayor_go.tween_property(mayor, "position:x", mound.position.x + _vp.x * 0.13, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var munch := _ct(mayor).set_loops(int(ride_time / 0.24))
	munch.tween_interval(0.23)
	munch.tween_callback(mayor.hop.bind(7.0, 0.10))
	# The pile shrinks as it's devoured.
	var devour := _ct(mound)
	devour.tween_interval(0.30)
	devour.tween_property(mound, "scale", Vector2(0.30, 0.12), ride_time * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# THE FLICK: one grain survives — and Dribble pops out with it.
	var flick := _ct()
	flick.tween_interval(ride_time * 0.62)
	flick.tween_callback(func() -> void:
		dribble.visible = true
		dribble.set_expression(CartoonActor.Mood.SHOCKED)
		# The last grain, perched on the pile's peak.
		var last := Props.make_grain(12.0 * _content_scale, 0.4)
		last.position = mound.position + Vector2(0.0, -_vp.y * 0.035)
		last.z_index = 7
		world.add_child(last)
		# Flick! Both spin away on a shared parabola over the cliff.
		var start := last.position
		var apex := Vector2(_vp.x * 0.80, _vp.y * GROUND_FRACTION - _vp.y * 0.26)
		var off := Vector2(_vp.x * (CLIFF_X + 0.12), _vp.y * 1.2)
		dribble.position = start + Vector2(-10.0 * _content_scale, 0.0)
		for rider in [[last, 0.0], [dribble, -14.0 * _content_scale]]:
			var node := rider[0] as Node2D
			var dx := rider[1] as float
			var fly := _ct()
			fly.tween_method(
				func(t: float) -> void:
					var pos := start.lerp(off, t)
					pos.y -= sin(t * PI) * (apex.y - start.y) * 0.9
					pos.x += dx * (1.0 - absf(t - 0.5) * 2.0)
					node.position = pos
					node.rotation = t * 9.0,
				0.0, 1.0, ride_time * 0.38
			)
			fly.tween_callback(func() -> void:
				last.visible = false
				dribble.visible = false))
	# The town, satisfied, dusts off.
	var dust := _ct(mayor)
	dust.tween_interval(ride_time * 0.55)
	dust.tween_property(mayor, "rotation", 0.05, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dust.tween_property(mayor, "rotation", -0.05, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

