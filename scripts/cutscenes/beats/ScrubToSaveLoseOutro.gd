## ScrubToSave - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ScrubToSaveLoseOutro.tscn

extends MicrogameOutroBase

## Scrub To Save — LOSE clip.
## res://scenes/ui/cutscenes/beats/ScrubToSaveLoseOutro.tscn
##
## BEAT 1  The scrub goes WRONG — the brush drags filth INTO the water.
## BEAT 2  (impact) The dish ends up DIRTIER than before — a giant grime
##         splat with droplets flung wide.
## BEAT 3  The town dips Dribble in grease and rolls them off the cliff
##         down a chute, like a dirty plate.

const Props := preload("res://scripts/cutscenes/beats/ScrubToSaveProps.gd")

const CLIFF_X := 0.94

var dish: Node2D
var chute: Node2D
var tub: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.14, _vp.x * 0.22)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.46)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.78, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	var sink := Props.make_sink(_vp.y * 0.30)
	sink.position = Vector2(_vp.x * 0.36, _vp.y * GROUND_FRACTION)
	sink.z_index = 3
	world.add_child(sink)
	dish = Props.make_dish(_vp.y * 0.24)
	dish.position = Vector2(_vp.x * 0.48, _vp.y * GROUND_FRACTION)
	dish.z_index = 4
	world.add_child(dish)
	# The grease tub waits at the counter's right end.
	tub = Props.make_grease_tub(_vp.y * 0.26)
	tub.position = Vector2(_vp.x * 0.62, _vp.y * GROUND_FRACTION)
	tub.z_index = 3
	world.add_child(tub)
	# The chute: from beside the tub, down over the cliff edge.
	var top := Vector2(_vp.x * 0.66, _vp.y * GROUND_FRACTION - _vp.y * 0.12)
	chute = Props.make_chute(_vp.x * 0.34, 0.36, _vp.y * 0.05)
	chute.position = top
	chute.rotation = 0.0  # geometry already built along the slope
	chute.z_index = 2
	world.add_child(chute)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.PANIC)
	# The doomed scrub: the dish wobbles harder and harder.
	var dread := _ct(dish).set_loops(3)
	dread.tween_property(dish, "rotation", 0.06, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dread.tween_property(dish, "rotation", -0.06, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dread.tween_property(dish, "rotation", 0.0, 0.10)
	# The judge's clipboard hovers, pen ready.
	mayor.set_arm_pose(CartoonActor.ArmPose.DROOP)

## Impact frame: the centre of the fresh splat.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.48, _vp.y * GROUND_FRACTION - _vp.y * 0.10)

## BEAT 2 — dirtier than before. Full impact stack ON the grime splat.
func _on_impact() -> void:
	super._on_impact()
	# The grime layer EXPLODES back, bigger and browner than ever.
	var grime := dish.get_node("Grime") as Node2D
	grime.scale = Vector2(0.55, 0.55)
	for spot in grime.get_children():
		var blot := spot as Polygon2D
		blot.color = Color(0.28, 0.20, 0.12, 0.92)
	var splat := _ct(grime)
	splat.tween_property(grime, "scale", Vector2(1.5, 1.5), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	splat.tween_property(grime, "scale", Vector2(1.2, 1.2), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Splat droplets fling off the dish.
	for i in range(7):
		var drop := Polygon2D.new()
		drop.polygon = Props._ellipse(9.0 * _content_scale, 7.0 * _content_scale, 8)
		drop.position = _impact_point()
		drop.color = Props.GRIME
		drop.z_index = 7
		world.add_child(drop)
		var dir := Vector2(cos(float(i) * TAU / 7.0), sin(float(i) * TAU / 7.0) * 0.6 - 0.4)
		var far := _impact_point() + dir * 90.0 * _content_scale \
			+ Vector2(0.0, 60.0 * _content_scale)
		var fly := _ct(drop)
		fly.tween_property(drop, "position", far, 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(drop, "modulate:a", 0.0, 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_callback(drop.queue_free)
	# The judge writes the F with relish: clipboard jab.
	mayor.set_expression(CartoonActor.Mood.SMUG)
	var jab := _ct(mayor)
	jab.tween_property(mayor, "rotation", -0.06, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jab.tween_property(mayor, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The dish shudders, defeated.
	var shudder := _ct(dish).set_loops(3)
	shudder.tween_property(dish, "rotation", 0.08, 0.06)
	shudder.tween_property(dish, "rotation", -0.08, 0.06)
	shudder.tween_property(dish, "rotation", 0.0, 0.05)

## BEAT 3 — the town dips Dribble in grease and rolls them off the cliff
## down the chute, like a dirty plate.
func _beat_payoff() -> void:
	_dip_and_roll()

func _dip_and_roll() -> void:
	var ride_time := _payoff_sec()
	# Two townsfolk seize Dribble and haul him to the grease tub.
	var grabbers: Array = [townsfolk[0], townsfolk[1]]
	for i in range(grabbers.size()):
		var grabber := grabbers[i] as CartoonActor
		grabber.set_arm_pose(CartoonActor.ArmPose.REACH)
		var haul := _ct()
		haul.tween_property(grabber, "position:x",
			tub.position.x - _vp.x * 0.08 + _vp.x * 0.05 * float(i), 0.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var dip := _ct()
	dip.tween_interval(0.18)
	# DOWN into the grease...
	dip.tween_property(dribble, "position",
		tub.position + Vector2(0.0, -_vp.y * 0.10), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dip.tween_callback(func() -> void:
		dribble.set_expression(CartoonActor.Mood.DIZZY)
		dribble.modulate = Color(0.75, 0.65, 0.5))
	# ...and back UP, glistening.
	dip.tween_property(dribble, "position",
		tub.position + Vector2(0.0, -_vp.y * 0.30), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A greasy drip lands in the tub.
	var ripple := tub.get_node("Pool") as Polygon2D
	var plop := _ct(ripple)
	plop.tween_interval(0.34)
	plop.tween_property(ripple, "scale", Vector2(1.15, 1.4), 0.10)
	plop.tween_property(ripple, "scale", Vector2(1.0, 1.0), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# THE ROLL: down the chute and off the cliff, spinning like a plate.
	var roll := _ct()
	roll.tween_interval(0.40)
	roll.tween_callback(func() -> void:
		var top: Vector2 = chute.position
		var slope := 0.36
		var length := _vp.x * 0.34
		var dir := Vector2(cos(slope), sin(slope))
		var total := length * 1.3  # carry on past the cliff edge
		var flight := _ct()
		flight.tween_method(
			func(t: float) -> void:
				var along := t * total
				var pos := top + dir * along
				# Sit on the chute surface while on it, then free-fall.
				if along <= length:
					pos.y -= _vp.y * 0.045
				else:
					pos.y += (along - length) * 0.9
				(dribble as Node2D).position = pos
				(dribble as Node2D).rotation = t * 10.0,
			0.0, 1.0, ride_time * 0.60
		)
		flight.tween_callback(func() -> void: dribble.visible = false))
	# The judge stamps the fail: a decisive clipboard slam.
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.hop(16.0, 0.22)
	# Town watches, unimpressed; the Mayor wipes his hands of it.
	mayor.set_expression(CartoonActor.Mood.SMUG)
	var wipe := _ct(mayor).set_loops(2)
	wipe.tween_property(mayor, "rotation", 0.08, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wipe.tween_property(mayor, "rotation", -0.08, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(townsfolk.size()):
		var watcher := _ct()
		watcher.tween_interval(0.5 + 0.2 * float(i))
		watcher.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.DROOP))

