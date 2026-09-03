## CloudCatcher - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CloudCatcherIntro.tscn

extends MicrogameIntroBase

## Cloud Catcher — CAUSE clip.
## res://scenes/ui/cutscenes/beats/CloudCatcherIntro.tscn
##
## BEAT 1  Camera pans down from a lone white cloud onto a row of SAGGING
##         thirsty plants; Dribble and the town survey the dry spell.
## BEAT 2  (flash-only impact) The cloud drifts AWAY — teasingly out of reach.
##         Dribble clocks the problem: no rain without tapping clouds.
## BEAT 3  Dribble leaps and grabs at empty sky while the plants droop further.
##         SNAP: whip-pan into gameplay.

const Props := preload("res://scripts/cutscenes/beats/CloudCatcherProps.gd")

var plants: Array[Node2D] = []
var teasing_cloud: Node2D

func _setup_stage() -> void:
	(get_node("Backdrop") as ColorRect).color = Color(0.53, 0.81, 0.92)
	_stage_townsfolk(3, _vp.x * 0.08, _vp.x * 0.24)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.82, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	_make_plants()
	teasing_cloud = Props.make_puff_cloud(1.15)
	teasing_cloud.name = "TeasingCloud"
	teasing_cloud.position = Vector2(_vp.x * 0.60, _vp.y * 0.15)
	teasing_cloud.z_index = -4
	world.add_child(teasing_cloud)
	# Beat 1 starts high and tight on the lone cloud, then pans down.
	camera.zoom = Vector2(1.2, 1.2)
	camera.position = _vp * 0.5 + Vector2(teasing_cloud.position.x - _vp.x * 0.5, -160.0) * _content_scale

## The thirsty plant row — the whole reason this round exists.
func _make_plants() -> void:
	for i in range(5):
		var plant := Props.make_plant("thirsty", (0.95 + 0.12 * float(i % 3)) * _content_scale)
		plant.name = "Plant%d" % (i + 1)
		plant.position = Vector2(_vp.x * (0.14 + 0.18 * float(i)), _vp.y * GROUND_FRACTION + 2.0)
		plant.z_index = -2
		world.add_child(plant)
		plants.append(plant)

## BEAT 1 — pan down off the cloud onto the drooping row; survey the drought.
func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SAD)
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	_sag_plants(0.10)
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _sag_plants(extra: float) -> void:
	for i in range(plants.size()):
		var t := _ct()
		t.tween_property(plants[i], "rotation", 0.12 * (1.0 if i % 2 == 0 else -1.0) + extra * (1.0 if i % 2 == 0 else -1.0), 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. The cloud drifts off, just out of reach.
func _on_impact() -> void:
	_impact_flash()
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.drip_sweat()
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	var drift := _ct()
	drift.tween_property(teasing_cloud, "position:x", _vp.x * 0.80, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 3 — Dribble lunges at empty sky; the plants sag even further.
func _beat_payoff() -> void:
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	dribble.hop(52.0, 0.42)
	var lunge := _ct()
	lunge.tween_property(dribble, "position:x", _vp.x * 0.52, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor.set_expression(CartoonActor.Mood.SAD)
	_sag_plants(0.16)
	for t in townsfolk:
		t.shake(4.0, 0.3)
