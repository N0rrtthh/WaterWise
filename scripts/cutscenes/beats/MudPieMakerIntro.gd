## MudPieMaker - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/MudPieMakerIntro.tscn

extends MicrogameIntroBase

## Mud Pie Maker — CAUSE clip.
## res://scenes/ui/cutscenes/beats/MudPieMakerIntro.tscn
##
## BEAT 1  The bake-sale stand with three EMPTY tins; the fill gauge rests at
##         zero; the camera settles on the sad, unsold setup.
## BEAT 2  (flash-only impact) Mayor Ripple pops up his wrist-watch and taps
##         it impatiently — the gauge still reads zero.
## BEAT 3  Dribble panic-reaches for the mud; the mayor points at the gauge.
##         SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/MudPieMakerProps.gd")

var stand: Node2D
var tins: Array = []
var gauge: Node2D
var watch: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.MEADOW
	_stage_townsfolk(3, _vp.x * 0.68, _vp.x * 0.88)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.48, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.58)
	stand = Props.make_stand(_vp.x * 0.16)
	stand.position = Vector2(_vp.x * 0.30, _vp.y * GROUND_FRACTION)
	stand.z_index = 3
	world.add_child(stand)
	var table_y := _vp.y * GROUND_FRACTION + Props.TABLE_TOP_Y() * _content_scale
	for i in range(3):
		var tin := Props.make_tin(_content_scale * 1.5)
		tin.position = Vector2(_vp.x * 0.30 + (float(i) - 1.0) * 40.0 * _content_scale, table_y)
		tin.z_index = 4
		world.add_child(tin)
		tins.append(tin)
	gauge = Props.make_gauge(_content_scale * 1.3)
	gauge.position = Vector2(_vp.x * 0.41, _vp.y * GROUND_FRACTION)
	gauge.z_index = 3
	world.add_child(gauge)
	camera.zoom = Vector2(1.3, 1.3)
	camera.position = stand.position + Vector2(0.0, -90.0 * _content_scale)

## BEAT 1 — open on the stand, settle wide. The empty tins glint hopefully.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Hopeful glint sweep across the tins.
	for i in range(tins.size()):
		var shine := (tins[i] as Node2D).get_node("Shine") as Polygon2D
		var glint := _ct(shine)
		glint.tween_interval(0.05 * float(i))
		glint.tween_property(shine, "scale", Vector2(1.6, 1.6), 0.09) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		glint.tween_property(shine, "scale", Vector2.ONE, 0.09) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# The gauge fill jitter-jitters at zero.
	var fill := gauge.get_node("Fill") as Polygon2D
	var zero := _ct(fill).set_loops(2)
	zero.tween_property(fill, "position:x", 1.5 * _content_scale, 0.05)
	zero.tween_property(fill, "position:x", -1.5 * _content_scale, 0.05)
	zero.tween_property(fill, "position:x", 0.0, 0.05)

## BEAT 2 — the situation becomes clear. Intro contract: flash only. Mayor
## Ripple pops up his wrist-watch and taps it impatiently; gauge: still zero.
func _on_impact() -> void:
	_impact_flash()
	watch = Props.make_watch(_content_scale * 1.6)
	watch.position = mayor.position + Vector2(28.0 * _content_scale, -80.0 * _content_scale)
	watch.z_index = 6
	watch.scale *= 0.01
	world.add_child(watch)
	var pop := _ct(watch)
	pop.tween_property(watch, "scale", Vector2.ONE * _content_scale * 1.6, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Impatient ticking: hands spin fast, watch waggles.
	var hand_a := watch.get_node("Hand0") as Polygon2D
	var hand_b := watch.get_node("Hand1") as Polygon2D
	var tick := _ct().set_loops(3)
	tick.tween_callback(func() -> void:
		hand_a.rotation += TAU * 0.5
		hand_b.rotation += TAU * 0.25)
	tick.tween_interval(0.12)
	tick.tween_callback(func() -> void:
		watch.rotation = 0.14)
	tick.tween_interval(0.10)
	tick.tween_callback(func() -> void:
		watch.rotation = -0.10)
	tick.tween_interval(0.10)
	tick.tween_callback(func() -> void:
		watch.rotation = 0.0)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.WORRIED)

## BEAT 3 — Dribble panic-reaches for the mud; the mayor points at the gauge.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Dribble shuffles toward the gauge, then panics back.
	var shuf := _ct()
	shuf.tween_property(dribble, "position:x", gauge.position.x + 30.0 * _content_scale, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shuf.tween_property(dribble, "position:x", _vp.x * 0.56, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.hop(18.0, 0.30)
	# Mayor hops, pointing at the zero gauge.
	var lean := _ct()
	lean.tween_property(mayor, "rotation", -0.16, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean.tween_property(mayor, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.hop(16.0, 0.30)
	# Tins hurry-wobble — the crowd is waiting.
	for i in range(tins.size()):
		var tin := tins[i] as Node2D
		var wob := _ct(tin)
		wob.tween_interval(0.04 * float(i))
		wob.tween_property(tin, "rotation", 0.08, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(tin, "rotation", -0.08, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(tin, "rotation", 0.0, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Town leans in nervously.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.06 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(12.0, 0.24))

