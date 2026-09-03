## SwipeTheSoap - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/SwipeTheSoapWinOutro.tscn

extends MicrogameOutroBase

## Swipe The Soap — WIN clip.
## res://scenes/ui/cutscenes/beats/SwipeTheSoapWinOutro.tscn
##
## BEAT 1  The swiped soap sits on the pedestal, gleaming.
## BEAT 2  (impact) The soap EXPLODES into bubble fireworks — a particle
##         burst right on the tick.
## BEAT 3  Dribble surfs a giant bubble over the cheering crowd.

const Props := preload("res://scripts/cutscenes/beats/SwipeTheSoapProps.gd")

var soap: Node2D
var dot_tex: Texture2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.66, _vp.x * 0.80)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.92, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.16)
	var pedestal := Props.make_pedestal(_vp.x * 0.20, _vp.y * 0.18)
	pedestal.position = Vector2(_vp.x * 0.38, _vp.y * GROUND_FRACTION)
	pedestal.z_index = 3
	world.add_child(pedestal)
	soap = Props.make_soap(_vp.x * 0.16)
	soap.position = Vector2(_vp.x * 0.38,
		_vp.y * GROUND_FRACTION - _vp.y * 0.18 - _vp.y * 0.005)
	soap.z_index = 4
	world.add_child(soap)
	dot_tex = Props.make_dot_tex(24)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The soap hums on its pedestal; the crowd leans in.
	var hum := _ct(soap).set_loops(2)
	hum.tween_property(soap, "scale", Vector2(1.04, 1.04), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hum.tween_property(soap, "scale", Vector2(1.0, 1.0), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(townsfolk.size()):
		var lean := _ct(townsfolk[i]).set_loops(2)
		lean.tween_interval(0.22 * float(i))
		lean.tween_callback(townsfolk[i].hop.bind(7.0, 0.26))
		lean.tween_interval(0.28)

## Impact frame: the soap's detonation point.
func _impact_point() -> Vector2:
	return soap.position + Vector2(0.0, -_vp.y * 0.035)

## BEAT 2 — the soap explodes into bubble fireworks ON the tick.
func _on_impact() -> void:
	super._on_impact()
	# The soap swells and pops.
	var pop := _ct(soap)
	pop.tween_property(soap, "scale", Vector2(1.45, 1.45), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_callback(func() -> void:
		soap.modulate.a = 0.0)
	# Three staggered bubble-firework bursts at the detonation point.
	for i in range(3):
		var burst := Props.make_bubble_burst(dot_tex, _vp.y * 0.45)
		burst.position = _impact_point() + Vector2(
			(_vp.x * 0.04) * (float(i) - 1.0), -_vp.y * 0.03 * float(i))
		burst.z_index = 8
		world.add_child(burst)
		var fire := _ct(burst)
		fire.tween_interval(0.02 * float(i))
		fire.tween_callback(func() -> void:
			burst.emitting = true)
	# A rising ring of drifting afterbubbles.
	for i in range(8):
		var drift := Polygon2D.new()
		drift.polygon = Props._ellipse(9.0 * _content_scale, 9.0 * _content_scale, 10)
		drift.position = _impact_point() + Vector2(
			(-1.0 + float(i) * 0.28) * _vp.x * 0.05, 0.0)
		drift.color = Props.BUBBLE_RIM
		drift.z_index = 8
		world.add_child(drift)
		var rise := _ct(drift)
		rise.tween_property(drift, "position:y", drift.position.y - _vp.y * 0.22, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rise.parallel().tween_property(drift, "modulate:a", 0.0, 0.8)
		rise.tween_callback(drift.queue_free)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — Dribble surfs a giant bubble over the cheering crowd.
func _beat_payoff() -> void:
	# The giant bubble inflates from the blast point with Dribble on top.
	var bubble := Props.make_bubble(_vp.y * 0.34)
	bubble.position = _impact_point() - Vector2(0.0, _vp.y * 0.10)
	bubble.scale = Vector2(0.15, 0.15)
	bubble.z_index = 7
	world.add_child(bubble)
	var inflate := _ct(bubble)
	inflate.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Dribble drops onto the bubble's crown in surf stance.
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	var land := _ct()
	land.tween_interval(0.18)
	land.tween_property(dribble, "position",
		bubble.position + Vector2(-_vp.y * 0.02, -_vp.y * 0.17), 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The surf: bubble bobs and drifts up-right across the crowd; Dribble
	# rides the sway on top.
	var ride := _ct(bubble)
	ride.tween_interval(0.38)
	ride.tween_property(bubble, "position",
		Vector2(_vp.x * 0.66, _vp.y * 0.44), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ride.tween_property(bubble, "position",
		Vector2(_vp.x * 0.80, _vp.y * 0.38), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bob := _ct(bubble).set_loops(6)
	bob.tween_property(bubble, "scale", Vector2(1.05, 0.96), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(bubble, "scale", Vector2(0.96, 1.05), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Dribble follows the bubble crown each step of the drift.
	var chase := _ct()
	chase.tween_interval(0.38)
	chase.tween_property(dribble, "position",
		Vector2(_vp.x * 0.64, _vp.y * 0.44 - _vp.y * 0.17), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	chase.tween_property(dribble, "position",
		Vector2(_vp.x * 0.78, _vp.y * 0.38 - _vp.y * 0.17), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var sway := _ct(dribble).set_loops(6)
	sway.tween_property(dribble, "rotation", 0.07, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(dribble, "rotation", -0.07, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The crowd goes wild beneath the flight path.
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	for i in range(townsfolk.size()):
		var fan := townsfolk[i] as CartoonActor
		fan.set_expression(CartoonActor.Mood.HAPPY)
		fan.set_arm_pose(CartoonActor.ArmPose.CHEER)
		var cheer := _ct(fan).set_loops(5)
		cheer.tween_interval(0.06 * float(i))
		cheer.tween_callback(fan.hop.bind(18.0, 0.20))
		cheer.tween_interval(0.14)
	mayor.hop(16.0, 0.24)
	# A sparkle trail peels off the bubble.
	for i in range(5):
		var trail := Polygon2D.new()
		trail.polygon = Props._ellipse(5.0 * _content_scale, 5.0 * _content_scale, 8)
		trail.position = Vector2(_vp.x * 0.42 + _vp.x * 0.05 * float(i),
			_vp.y * 0.52 - _vp.y * 0.03 * float(i))
		trail.color = Props.BUBBLE_RIM
		trail.z_index = 6
		world.add_child(trail)
		var fade := _ct(trail)
		fade.tween_interval(0.5 + 0.1 * float(i))
		fade.tween_property(trail, "modulate:a", 0.0, 0.4)
		fade.tween_callback(trail.queue_free)

