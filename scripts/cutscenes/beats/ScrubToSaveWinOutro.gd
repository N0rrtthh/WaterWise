## ScrubToSave - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ScrubToSaveWinOutro.tscn

extends MicrogameOutroBase

## Scrub To Save — WIN clip.
## res://scenes/ui/cutscenes/beats/ScrubToSaveWinOutro.tscn
##
## BEAT 1  Suds everywhere; the dish is almost there.
## BEAT 2  (impact) MIRROR SHINE — the lens-flare flash blinds the judge.
## BEAT 3  A gold scrub-brush trophy drops from above. The town feasts
##         its eyes.

const Props := preload("res://scripts/cutscenes/beats/ScrubToSaveProps.gd")

var dish: Node2D
var clipboard: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.14, _vp.x * 0.88)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.36)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.76, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	var sink := Props.make_sink(_vp.y * 0.30)
	sink.position = Vector2(_vp.x * 0.40, _vp.y * GROUND_FRACTION)
	sink.z_index = 3
	world.add_child(sink)
	dish = Props.make_dish(_vp.y * 0.24)
	dish.position = Vector2(_vp.x * 0.52, _vp.y * GROUND_FRACTION)
	dish.z_index = 4
	world.add_child(dish)
	# Half-scrubbed already: grime down to a stubborn half.
	var grime := dish.get_node("Grime") as Node2D
	grime.scale = Vector2(0.55, 0.55)
	clipboard = Props.make_clipboard(_vp.y * 0.14)
	clipboard.rotation = 0.18
	mayor.add_child(clipboard)
	clipboard.position = Vector2(_vp.y * 0.075, -_vp.y * 0.075)
	# Residual suds drifting up.
	var bubbles := Props.make_bubbles(_dot_texture())
	bubbles.position = dish.position + Vector2(0.0, -_vp.y * 0.12)
	bubbles.z_index = 6
	bubbles.emitting = true
	world.add_child(bubbles)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.DROOP)
	for t in townsfolk:
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Two last desperate scrub passes.
	for i in range(2):
		var scrub := _ct()
		scrub.tween_interval(0.2 * float(i))
		scrub.tween_callback(dribble.hop.bind(12.0, 0.16))
	# The judge leans in for the verdict.
	var lean := _ct(mayor)
	lean.tween_property(mayor, "rotation", 0.08, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Impact frame: the dish's polished glaze.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.52, _vp.y * GROUND_FRACTION - _vp.y * 0.10)

## BEAT 2 — the mirror shine. Full impact stack AS the flash blinds him.
func _on_impact() -> void:
	super._on_impact()
	# Grime polished away to nothing.
	var grime := dish.get_node("Grime") as Node2D
	var polish := _ct(grime)
	polish.tween_property(grime, "scale", Vector2(0.04, 0.04), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The shine bar sweeps the glaze.
	var shine := dish.get_node("Shine") as Polygon2D
	shine.visible = true
	var sweep := _ct(shine)
	sweep.tween_property(shine, "position:x", shine.position.x + _vp.y * 0.14, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sweep.tween_callback(func() -> void: shine.visible = false)
	# LENS FLARE: blooms from the glaze and fills the judge's eyes.
	var flare := Props.make_flare(_vp.y * 0.55)
	flare.position = _impact_point()
	flare.z_index = 9
	world.add_child(flare)
	flare.visible = true
	flare.scale = Vector2(0.2, 0.2)
	var bloom := _ct(flare)
	bloom.tween_property(flare, "scale", Vector2(1.3, 1.3), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bloom.tween_property(flare, "modulate:a", 0.0, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bloom.tween_callback(flare.queue_free)
	# The judge is BLINDED: rears back, arms up, seeing stars.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(22.0, 0.26)
	var reel := _ct(mayor)
	reel.tween_property(mayor, "position:x", mayor.position.x + _vp.x * 0.03, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reel.tween_property(mayor, "rotation", -0.10, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reel.tween_property(mayor, "rotation", 0.0, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The clipboard drops in astonishment.
	var drop := _ct(clipboard)
	drop.tween_property(clipboard, "rotation", -0.5, 0.18) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## BEAT 3 — the gold scrub-brush trophy drops from above.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# The trophy descends and lands with a bounce right of the dish.
	var trophy := Props.make_trophy(_vp.y * 0.22)
	trophy.position = Vector2(_vp.x * 0.52, -_vp.y * 0.15)
	trophy.z_index = 5
	world.add_child(trophy)
	var fall := _ct(trophy)
	fall.tween_property(trophy, "position:y", _vp.y * GROUND_FRACTION, 0.34) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# It gleams on landing.
	var gleam := _ct()
	gleam.tween_interval(0.34)
	gleam.tween_property(trophy, "scale", Vector2(1.12, 0.88), 0.07)
	gleam.tween_property(trophy, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Dribble presents it: deep proud bow.
	var bow := _ct(dribble)
	bow.tween_property(dribble, "rotation", 0.16, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(dribble, "rotation", 0.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	# The judge recovers and signs the approval: clipboard flips upright.
	var sign := _ct(clipboard)
	sign.tween_property(clipboard, "rotation", 0.05, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.hop(14.0, 0.24)
	# The town applauds on the same beat.
	var cast: Array = []
	for t in townsfolk:
		cast.append(t)
	for i in range(cast.size()):
		var fan := cast[i] as CartoonActor
		fan.set_arm_pose(CartoonActor.ArmPose.CHEER)
		fan.set_expression(CartoonActor.Mood.HAPPY)
		var clap := _ct(fan).set_loops(3)
		clap.tween_interval(0.02 * float(i))
		clap.tween_callback(fan.hop.bind(14.0, 0.18))
		clap.tween_interval(0.24)
	# The dish itself does a proud little spin.
	var spin := _ct(dish)
	spin.tween_interval(0.30)
	spin.tween_property(dish, "rotation", TAU, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	spin.tween_callback(func() -> void: dish.rotation = 0.0)

