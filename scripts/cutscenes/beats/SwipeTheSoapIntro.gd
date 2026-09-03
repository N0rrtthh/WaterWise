## SwipeTheSoap - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/SwipeTheSoapIntro.tscn

extends MicrogameIntroBase

## Swipe The Soap — CAUSE clip.
## res://scenes/ui/cutscenes/beats/SwipeTheSoapIntro.tscn
##
## BEAT 1  The giant soap sits on a pedestal; directional arrows flicker
##         around it; the town watches from bleachers like a sporting
##         event.
## BEAT 2  (flash-only impact) Every arrow snaps full-alpha inward as the
##         soap gleams — the crowd gasps.
## BEAT 3  Dribble strides up and REACHes for the soap. SNAP into
##         gameplay.

const Props := preload("res://scripts/cutscenes/beats/SwipeTheSoapProps.gd")

var soap: Node2D
var arrows: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	# Bleachers stand on the right; the town sits on the rows.
	var bleachers := Props.make_bleachers(_vp.x * 0.30, _vp.y * 0.24, 3)
	bleachers.position = Vector2(_vp.x * 0.78, _vp.y * GROUND_FRACTION)
	bleachers.z_index = 2
	world.add_child(bleachers)
	_stage_townsfolk(2, _vp.x * 0.74, _vp.x * 0.84)
	for i in range(townsfolk.size()):
		townsfolk[i].position.y = _vp.y * GROUND_FRACTION \
			- _vp.y * 0.08 * float(i + 1)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.92, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	mayor.position.y = _vp.y * GROUND_FRACTION - _vp.y * 0.24
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.14)
	# The pedestal with the giant soap, centre stage.
	var pedestal := Props.make_pedestal(_vp.x * 0.20, _vp.y * 0.18)
	pedestal.position = Vector2(_vp.x * 0.38, _vp.y * GROUND_FRACTION)
	pedestal.z_index = 3
	world.add_child(pedestal)
	soap = Props.make_soap(_vp.x * 0.16)
	soap.position = Vector2(_vp.x * 0.38,
		_vp.y * GROUND_FRACTION - _vp.y * 0.18 - _vp.y * 0.005)
	soap.z_index = 4
	world.add_child(soap)
	# Four arrows orbit the soap, alternating direction.
	for spec in [
		[Vector2(-0.14, -0.20), PI], [Vector2(0.14, -0.20), 0.0],
		[Vector2(-0.15, 0.02), PI], [Vector2(0.15, 0.02), 0.0],
	]:
		var arrow := Props.make_arrow(48.0 * _content_scale)
		arrow.position = soap.position + Vector2(
			_vp.x * spec[0].x, _vp.y * spec[0].y)
		arrow.rotation = spec[1]
		arrow.z_index = 5
		world.add_child(arrow)
		arrows.append(arrow)
	camera.position = _vp * 0.5

## BEAT 1 — arrows flicker; the crowd murmurs like match-day.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# Alternating arrow flicker: odd and even arrows blink out of phase.
	for i in range(arrows.size()):
		var arrow := arrows[i] as Polygon2D
		var blink := _ct(arrow).set_loops(4)
		blink.tween_interval(0.08 * float(i % 2))
		blink.tween_property(arrow, "modulate:a", 0.15, 0.07)
		blink.tween_property(arrow, "modulate:a", 0.9, 0.07)
	# The crowd does little anticipatory hops in rhythm.
	for i in range(townsfolk.size()):
		var murmur := _ct(townsfolk[i]).set_loops(3)
		murmur.tween_interval(0.26 * float(i))
		murmur.tween_callback(townsfolk[i].hop.bind(6.0, 0.24))
		murmur.tween_interval(0.30)
	mayor.hop(5.0, 0.32)
	# The soap does a slow proud gleam pulse.
	var gleam := _ct(soap).set_loops(2)
	gleam.tween_property(soap, "modulate", Color(1.12, 1.12, 1.12), 0.30)
	gleam.tween_property(soap, "modulate", Color(1.0, 1.0, 1.0), 0.30)

## BEAT 2 — the snap-and-gleam. Intro contract: flash only.
func _on_impact() -> void:
	_impact_flash()
	# Every arrow locks on, fully lit, pointing inward at the soap.
	for arrow in arrows:
		var a := arrow as Polygon2D
		a.modulate.a = 1.0
		var lock := _ct(a)
		lock.tween_property(a, "position",
			a.position - (a.position - soap.position).normalized()
			* 10.0 * _content_scale, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The soap gleams hard.
	var gleam := _ct(soap)
	gleam.tween_property(soap, "modulate", Color(1.3, 1.3, 1.3), 0.10)
	gleam.tween_property(soap, "modulate", Color(1.0, 1.0, 1.0), 0.14)
	# The crowd gasps.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the approach and reach.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	var dash := _ct()
	dash.tween_property(dribble, "position:x", _vp.x * 0.26, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The crowd leans in for the swipe.
	for i in range(townsfolk.size()):
		var crane := _ct()
		crane.tween_interval(0.18 * float(i))
		crane.tween_property(townsfolk[i], "position:y",
			townsfolk[i].position.y + _vp.y * 0.015, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(10.0, 0.20)
