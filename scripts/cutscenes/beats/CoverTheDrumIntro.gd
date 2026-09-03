## CoverTheDrum - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CoverTheDrumIntro.tscn

extends MicrogameIntroBase

## Cover The Drum — CAUSE clip.
## res://scenes/ui/cutscenes/beats/CoverTheDrumIntro.tscn
##
## BEAT 1  Dusk sky. Camera starts high on three OPEN water drums with
##         mosquitoes already circling; pans down. The town is itching.
## BEAT 2  (flash-only impact) The lead mosquito dives at an open drum's
##         water; Dribble clocks it — that's the round: TAP to cover.
## BEAT 3  The mayor points UP at the swarm; mosquitoes tighten their orbit;
##         Dribble grabs for the lid. SNAP: whip-pan into gameplay.

const Props := preload("res://scripts/cutscenes/beats/CoverTheDrumProps.gd")

const DRUM_XS := [0.30, 0.50, 0.70]

var drums: Array = []
var mosqs: Array = []
var _diver_bob: Tween

func _setup_stage() -> void:
	# Dusk dressing to match the game frame.
	get_node("Backdrop").color = Props.DUSK_SKY
	world.get_node("Ground").color = Color(0.30, 0.34, 0.22)
	world.get_node("Dirt").color = Color(0.25, 0.20, 0.15)
	world.add_child(Props.make_stars(_vp, 16))
	_stage_townsfolk(3, _vp.x * 0.08, _vp.x * 0.24)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.84, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.50)
	for i in range(DRUM_XS.size()):
		var d := Props.make_drum(_content_scale)
		d.position = Vector2(_vp.x * float(DRUM_XS[i]), _vp.y * GROUND_FRACTION)
		d.z_index = -1
		world.add_child(d)
		drums.append(d)
	_make_mosqs()
	# Beat 1 starts high and tight on the circling swarm, then pans down.
	camera.zoom = Vector2(1.24, 1.24)
	camera.position = _vp * 0.5 + Vector2(0.0, -170.0) * _content_scale

## Two orbiters circle their drums; the lead diver hovers with a bob and
## waits for the impact tick to strike.
func _make_mosqs() -> void:
	for i in range(3):
		var m := Props.make_mosquito(_content_scale)
		m.position = drums[i].position \
			+ Vector2(randf_range(-30.0, 30.0), -150.0) * _content_scale
		m.z_index = 4
		world.add_child(m)
		mosqs.append(m)
		_flap(m)
		if i == 0:
			_diver_bob = _ct().set_loops()
			_diver_bob.tween_property(m, "position:y", m.position.y + 14.0, 0.30) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_diver_bob.tween_property(m, "position:y", m.position.y, 0.30) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			_orbit(m, 0.33 * float(i))

func _flap(m: Node2D) -> void:
	for side in ["WingL", "WingR"]:
		var wing: Polygon2D = m.get_node(side)
		var rest := wing.position.y
		var flap := _ct(wing).set_loops()
		flap.tween_property(wing, "position:y", rest - 4.0, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flap.tween_property(wing, "position:y", rest, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _orbit(m: Node2D, phase: float) -> void:
	var base := m.position
	var r := 36.0 * _content_scale
	# Bound to the mosquito so the loop dies with it (never outlives the node).
	var orbit := _ct(m).set_loops()
	orbit.tween_method(func(t: float) -> void:
		var a := (t + phase) * TAU
		m.position = base + Vector2(cos(a) * r, sin(a) * r * 0.35)
	, 0.0, 1.0, 1.7)

## BEAT 1 — dusk settles; the town itches; pan down onto the open drums.
func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	_scratch(townsfolk[0], 0.05)
	_scratch(townsfolk[2], 0.20)
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. The lead mosquito dives for the open water.
func _on_impact() -> void:
	_impact_flash()
	if _diver_bob:
		_diver_bob.kill()
	var diver: Node2D = mosqs[0]
	var target: Vector2 = drums[0].position + Vector2(0.0, -64.0) * _content_scale
	var dive := _ct()
	dive.tween_property(diver, "position", target, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dive.tween_property(diver, "position", diver.position + Vector2(40.0, -50.0) \
		* _content_scale, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.drip_sweat()
	_scratch(townsfolk[1], 0.0)

## BEAT 3 — the mayor hammers the point home; the swarm tightens; Dribble
## grabs for a lid just as the whip-pan snaps in.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for i in range(1, mosqs.size()):
		_orbit(mosqs[i], 0.11 * float(i))
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	dribble.hop(30.0, 0.30)
	for i in range(townsfolk.size()):
		_scratch(townsfolk[i], 0.12 * float(i))

## The nervous bite-scratch: little shudder.
func _scratch(who: CartoonActor, delay: float) -> void:
	var t := _ct()
	t.tween_interval(delay)
	t.tween_callback(who.shake.bind(4.0, 0.28))
