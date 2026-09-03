## TimingTap - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TimingTapIntro.tscn

extends MicrogameIntroBase

## Timing Tap — CAUSE clip.
## res://scenes/ui/cutscenes/beats/TimingTapIntro.tscn
##
## BEAT 1  A glass sits under the tap, a red target line marked on the
##         side. The town files in with folding chairs — this pour is a
##         competition.
## BEAT 2  (flash-only impact) The target line FLARES. The room freezes
##         and the crowd gasps at the mark.
## BEAT 3  Dribble turns the handle and the pour whips out. SNAP into
##         gameplay.

const Props := preload("res://scripts/cutscenes/beats/TimingTapProps.gd")

var glass: Node2D
var tap: Node2D
var arc: Node2D
var water_body: Polygon2D
var glass_size: float
var chairs: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	glass_size = _vp.y * 0.30
	# Kitchen floor over the default grass.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	floor_poly.color = Props.FLOOR
	floor_poly.z_index = 0
	world.add_child(floor_poly)
	# The counter with its work top.
	var counter := Polygon2D.new()
	counter.name = "Counter"
	counter.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.10, _vp.y * GROUND_FRACTION), Vector2(_vp.x * 0.56, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x * 0.56, _vp.y), Vector2(_vp.x * 0.10, _vp.y),
	])
	counter.color = Props.COUNTER
	counter.z_index = 1
	world.add_child(counter)
	var top := Polygon2D.new()
	top.name = "CounterTop"
	top.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.09, _vp.y * 0.665), Vector2(_vp.x * 0.57, _vp.y * 0.665),
		Vector2(_vp.x * 0.57, _vp.y * GROUND_FRACTION), Vector2(_vp.x * 0.09, _vp.y * GROUND_FRACTION),
	])
	top.color = Props.COUNTER_TOP
	top.z_index = 2
	world.add_child(top)
	# The tap, spout tip at origin, mounted above the glass.
	tap = Props.make_tap(_vp.y * 0.40)
	tap.position = Vector2(_vp.x * 0.36, _vp.y * 0.40)
	tap.z_index = 3
	world.add_child(tap)
	# The glass, quarter-filled, target line marked on the side.
	glass = Props.make_glass(glass_size, 0.15)
	glass.position = Vector2(_vp.x * 0.36, _vp.y * 0.665)
	glass.z_index = 3
	world.add_child(glass)
	water_body = glass.get_node("Water") as Polygon2D
	# The pour, coiled at the spout until beat 3.
	arc = Props.make_water_arc(_vp.y * 0.20)
	arc.position = tap.position
	arc.rotation = PI * 0.5
	arc.scale = Vector2(0.0, 1.0)
	arc.z_index = 4
	world.add_child(arc)
	# The competition crowd: folding chairs set out.
	for i in range(3):
		var chair := Props.make_chair(_vp.y * 0.30)
		chair.position = Vector2(_vp.x * (0.66 + 0.10 * float(i)),
			_vp.y * GROUND_FRACTION)
		chair.z_index = 1
		world.add_child(chair)
		chairs.append(chair)
	_stage_townsfolk(3, _vp.x * 0.68, _vp.x * 0.88)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.94, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.24)
	camera.position = _vp * 0.5

func _set_water_fill(f: float) -> void:
	water_body.polygon = Props.water_poly(glass_size, glass_size * 0.72 * f)

## BEAT 1 — the town takes their seats; Dribble bounces at the tap.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	# The folding chairs pop open, one after another.
	for i in range(chairs.size()):
		var c := chairs[i] as Node2D
		c.scale = Vector2(0.0, 0.0)
		var pop := _ct(c)
		pop.tween_interval(0.05 * float(i))
		pop.tween_property(c, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The crowd settles, chattering.
	for i in range(townsfolk.size()):
		var t := townsfolk[i] as CartoonActor
		t.start_idle()
		var chat := _ct(t).set_loops(2)
		chat.tween_interval(0.14 * float(i))
		chat.tween_callback(t.hop.bind(5.0, 0.24))
		chat.tween_interval(0.30)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Dribble bounces on the spot, finger hovering over the handle.
	var ready_hop := _ct(dribble).set_loops(2)
	ready_hop.tween_callback(dribble.hop.bind(7.0, 0.20))
	ready_hop.tween_interval(0.28)
	# The water in the glass wobbles, eager.
	var wobble := _ct(water_body).set_loops(2)
	wobble.tween_property(water_body, "offset:y", -2.0 * _content_scale, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(water_body, "offset:y", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the mark flares. Flash only; the room freezes.
func _on_impact() -> void:
	_impact_flash()
	# The target line flares red-hot: THE mark everyone must hit.
	var line := glass.get_node("TargetLine") as Line2D
	var flare := _ct(line)
	flare.tween_property(line, "width", line.width * 2.2, 0.06)
	flare.parallel().tween_property(line, "default_color",
		Color(1.0, 0.95, 0.9), 0.06)
	flare.tween_property(line, "width", line.width * 1.4, 0.16)
	flare.parallel().tween_property(line, "default_color", Props.TARGET, 0.16)
	# The crowd gasps at the mark.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the handle turns; the pour whips out toward the mark.
func _beat_payoff() -> void:
	var handle := tap.get_node("Handle") as Node2D
	var turn := _ct(handle)
	turn.tween_property(handle, "rotation", 1.3, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var pour := _ct(arc)
	pour.tween_interval(0.10)
	pour.tween_property(arc, "scale:x", 1.0, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var climb := _ct(water_body)
	climb.tween_interval(0.16)
	climb.tween_method(_set_water_fill, 0.15, 0.55, 0.30)
	# The crowd cranes in; the mayor raises a judging hand.
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.SMUG)