## ScrubToSave - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ScrubToSaveIntro.tscn

extends MicrogameIntroBase

## Scrub To Save — CAUSE clip.
## res://scenes/ui/cutscenes/beats/ScrubToSaveIntro.tscn
##
## BEAT 1  A filthy dish sits beside the running faucet; the judge taps
##         his clipboard, unimpressed.
## BEAT 2  (flash-only impact) The grime CEMENTS — a thick splat; the
##         judge's frown deepens a full grade.
## BEAT 3  Dribble grabs the brush and scrubs like their life depends on
##         it. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/ScrubToSaveProps.gd")

var dish: Node2D
var sink: Node2D
var clipboard: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.14, _vp.x * 0.22)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.28)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.76, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	# The sink with its running faucet.
	sink = Props.make_sink(_vp.y * 0.30)
	sink.position = Vector2(_vp.x * 0.42, _vp.y * GROUND_FRACTION)
	sink.z_index = 3
	world.add_child(sink)
	# The dish under judgment, caked in grime.
	dish = Props.make_dish(_vp.y * 0.24)
	dish.position = Vector2(_vp.x * 0.54, _vp.y * GROUND_FRACTION)
	dish.z_index = 4
	world.add_child(dish)
	# The judge's clipboard, held at chest height.
	clipboard = Props.make_clipboard(_vp.y * 0.14)
	clipboard.position = Vector2(_vp.x * 0.72, _vp.y * GROUND_FRACTION - _vp.y * 0.10)
	clipboard.z_index = 5
	clipboard.rotation = 0.18
	mayor.add_child(clipboard)
	clipboard.position = Vector2(_vp.y * 0.075, -_vp.y * 0.075)
	camera.zoom = Vector2(1.15, 1.15)
	camera.position = _vp * 0.5

## BEAT 1 — the sink runs, the grime sits, the judge judges.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.DROOP)
	for t in townsfolk:
		t.start_idle()
	# The water stream wobbles.
	var stream := sink.get_node("Stream") as Polygon2D
	var flow := _ct(stream).set_loops(3)
	flow.tween_property(stream, "scale:x", 0.8, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flow.tween_property(stream, "scale:x", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The judge taps his clipboard twice — the universal sign of "no".
	for i in range(2):
		var tap := _ct()
		tap.tween_interval(0.35 * float(i))
		tap.tween_property(clipboard, "rotation", 0.02, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tap.tween_property(clipboard, "rotation", 0.18, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## BEAT 2 — the grime cements. Intro contract: flash only.
func _on_impact() -> void:
	_impact_flash()
	# Every blotch swells and darkens.
	var grime := dish.get_node("Grime") as Node2D
	for spot in grime.get_children():
		var blot := spot as Polygon2D
		blot.color = Color(0.30, 0.22, 0.14, 0.85)
		var swell := _ct(blot)
		swell.tween_property(blot, "scale", Vector2(1.35, 1.35), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		swell.tween_property(blot, "scale", Vector2(1.15, 1.15), 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# The judge's frown deepens: slower, sadder head-shake.
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	var shake := _ct(mayor).set_loops(2)
	shake.tween_property(mayor, "rotation", 0.07, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake.tween_property(mayor, "rotation", -0.07, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Dribble gulps.
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.hop(12.0, 0.22)

## BEAT 3 — the frantic scrub.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	# Bubbles erupt over the dish.
	var bubbles := Props.make_bubbles(_dot_texture())
	bubbles.position = dish.position + Vector2(0.0, -_vp.y * 0.12)
	bubbles.z_index = 6
	bubbles.emitting = true
	world.add_child(bubbles)
	# Three furious scrub passes.
	for i in range(3):
		var scrub := _ct()
		scrub.tween_interval(0.16 * float(i))
		scrub.tween_callback(func() -> void:
			dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
			dribble.hop(11.0, 0.15))
	# The dish jolts with each pass.
	var jolt := _ct(dish).set_loops(3)
	jolt.tween_interval(0.16)
	jolt.tween_property(dish, "rotation", 0.05, 0.07)
	jolt.tween_property(dish, "rotation", -0.05, 0.07)
	jolt.tween_property(dish, "rotation", 0.0, 0.05)
	# The judge readies his pen: clipboard upright, brow raised.
	var ready := _ct(clipboard)
	ready.tween_property(clipboard, "rotation", 0.0, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
