## SwipeTheSoap - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/SwipeTheSoapLoseOutro.tscn

extends MicrogameOutroBase

## Swipe The Soap — LOSE clip.
## res://scenes/ui/cutscenes/beats/SwipeTheSoapLoseOutro.tscn
##
## BEAT 1  The fallen soap lies on the floor; Dribble tiptoes over to
##         pick it up.
## BEAT 2  (impact) The floor turns soap-slick and Dribble's feet fly
##         out from under them.
## BEAT 3  ONE uninterrupted slide: out the door, through the market
##         stalls, and off the cliff.

const Props := preload("res://scripts/cutscenes/beats/SwipeTheSoapProps.gd")

const CLIFF_X := 0.94

var soap: Node2D
var slick: Polygon2D
var stalls: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.30, _vp.x * 0.42)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.52, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.16)
	# The door the slide will exit through, right of the stalls.
	var door := Props.make_door(_vp.x * 0.10, _vp.y * 0.34)
	door.position = Vector2(_vp.x * 0.86, _vp.y * GROUND_FRACTION)
	door.z_index = 2
	world.add_child(door)
	# Market stalls between the crowd and the door.
	for x in [0.55, 0.68]:
		var stall := Props.make_stall(_vp.x * 0.13, _vp.y * 0.30)
		stall.position = Vector2(_vp.x * x, _vp.y * GROUND_FRACTION)
		stall.z_index = 3
		world.add_child(stall)
		stalls.append(stall)
	# The soap-slick rink: a glossy sheen strip, hidden until impact.
	slick = Polygon2D.new()
	slick.name = "Slick"
	slick.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.10, _vp.y * GROUND_FRACTION - _vp.y * 0.012),
		Vector2(_vp.x * 0.94, _vp.y * GROUND_FRACTION - _vp.y * 0.012),
		Vector2(_vp.x * 0.94, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x * 0.10, _vp.y * GROUND_FRACTION),
	])
	slick.color = Color(1.0, 1.0, 1.0, 0.35)
	slick.z_index = 1
	world.add_child(slick)
	slick.modulate.a = 0.0
	# The fallen soap on the floor, centre stage.
	soap = Props.make_soap(_vp.x * 0.13)
	soap.position = Vector2(_vp.x * 0.44, _vp.y * GROUND_FRACTION)
	soap.rotation = 0.18
	soap.z_index = 4
	world.add_child(soap)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Dribble tiptoes toward the fallen soap, oblivious.
	var sneak := _ct()
	sneak.tween_property(dribble, "position:x", _vp.x * 0.32, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bobble := _ct(dribble).set_loops(3)
	bobble.tween_property(dribble, "rotation", 0.05, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bobble.tween_property(dribble, "rotation", -0.05, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The town waves warnings that go unheeded.
	for i in range(townsfolk.size()):
		var warn := _ct(townsfolk[i]).set_loops(3)
		warn.tween_interval(0.22 * float(i))
		warn.tween_callback(townsfolk[i].hop.bind(10.0, 0.18))
		warn.tween_interval(0.20)

## Impact frame: the slip point.
func _impact_point() -> Vector2:
	return dribble.position + Vector2(0.0, -_vp.y * 0.06)

## BEAT 2 — the slick rink appears and the feet fly out ON the tick.
func _on_impact() -> void:
	super._on_impact()
	# The floor floods with sheen.
	var flood := _ct(slick)
	flood.tween_property(slick, "modulate:a", 1.0, 0.10)
	# Two glints race along the rink.
	for i in range(2):
		var glint := Polygon2D.new()
		glint.polygon = PackedVector2Array([
			Vector2(-18.0 * _content_scale, 0.0), Vector2(0.0, -5.0 * _content_scale),
			Vector2(18.0 * _content_scale, 0.0), Vector2(0.0, 5.0 * _content_scale),
		])
		glint.position = Vector2(_vp.x * 0.14, _vp.y * GROUND_FRACTION - _vp.y * 0.006)
		glint.color = Color(1, 1, 1, 0.8)
		glint.z_index = 5
		world.add_child(glint)
		var run := _ct(glint)
		run.tween_interval(0.12 * float(i))
		run.tween_property(glint, "position:x", _vp.x * 0.90, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		run.parallel().tween_property(glint, "modulate:a", 0.0, 0.5)
		run.tween_callback(glint.queue_free)
	# THE SLIP: Dribble lands on the slick and the feet give way.
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	var slip := _ct(dribble)
	slip.tween_interval(0.42)
	slip.tween_callback(func() -> void:
		dribble.hop(16.0, 0.12)
		dribble.set_arm_pose(CartoonActor.ArmPose.BRACE))
	slip.tween_property(dribble, "rotation", -0.6, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slip.tween_property(dribble, "position:y",
		_vp.y * GROUND_FRACTION - _vp.y * 0.02, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The soap skitters away from the flailing feet.
	var skitter := _ct(soap)
	skitter.tween_interval(0.44)
	skitter.tween_property(soap, "position:x", _vp.x * 0.52, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)

## BEAT 3 — ONE uninterrupted slide: out the door, through the market
## stalls, off the cliff. A single tween chain, zero gaps.
func _beat_payoff() -> void:
	_slide_of_shame()

func _slide_of_shame() -> void:
	var slide := _ct()
	# Launch onto the rink — accelerating segment times sell the slide.
	slide.tween_property(dribble, "position:x", _vp.x * 0.44, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.parallel().tween_property(dribble, "position:y",
		_vp.y * GROUND_FRACTION, 0.16)
	slide.parallel().tween_property(dribble, "rotation", 0.0, 0.16)
	# Through the first stall.
	slide.tween_callback(func() -> void:
		_wobble_stall(stalls[0]))
	slide.tween_property(dribble, "position:x", _vp.x * 0.58, 0.14) \
		.set_trans(Tween.TRANS_LINEAR)
	# Through the second stall.
	slide.tween_callback(func() -> void:
		_wobble_stall(stalls[1]))
	slide.tween_property(dribble, "position:x", _vp.x * 0.70, 0.12) \
		.set_trans(Tween.TRANS_LINEAR)
	# Out the door — the panel flutters as Dribble blasts past.
	slide.tween_property(dribble, "position:x", _vp.x * 0.82, 0.10) \
		.set_trans(Tween.TRANS_LINEAR)
	# Slinging toward the cliff edge.
	slide.tween_property(dribble, "position:x", _vp.x * 0.92, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Airborne: free-fall off the cliff with a spin.
	slide.tween_property(dribble, "position",
		Vector2(_vp.x * (CLIFF_X + 0.02), _vp.y * GROUND_FRACTION - _vp.y * 0.10), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.parallel().tween_property(dribble, "rotation", 0.9, 0.16)
	slide.tween_property(dribble, "position",
		Vector2(_vp.x * (CLIFF_X + 0.06), _vp.y * 1.1), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide.parallel().tween_property(dribble, "rotation", 3.6, 0.5)
	# The town watches the whole ride, aghast.
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.PANIC)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	# A suds trail follows the slide.
	for i in range(6):
		var suds := Polygon2D.new()
		suds.polygon = Props._ellipse(7.0 * _content_scale, 7.0 * _content_scale, 8)
		suds.position = Vector2(_vp.x * (0.36 + 0.09 * float(i)),
			_vp.y * GROUND_FRACTION - _vp.y * 0.01)
		suds.color = Props.BUBBLE_RIM
		suds.z_index = 5
		world.add_child(suds)
		var fade := _ct(suds)
		fade.tween_interval(0.35 + 0.12 * float(i))
		fade.tween_property(suds, "modulate:a", 0.0, 0.4)
		fade.tween_callback(suds.queue_free)

func _wobble_stall(stall: Node2D) -> void:
	var awning := stall.get_node("Awning") as Polygon2D
	var wobble := _ct(awning)
	wobble.tween_property(awning, "rotation", 0.10, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wobble.tween_property(awning, "rotation", -0.06, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(awning, "rotation", 0.0, 0.10)
	var shudder := _ct(stall)
	shudder.tween_property(stall, "position:x", stall.position.x + 6.0 * _content_scale, 0.06)
	shudder.tween_property(stall, "position:x", stall.position.x, 0.08)

