## TurnOffTap - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TurnOffTapIntro.tscn

extends MicrogameIntroBase

## Turn Off Tap — CAUSE clip.
## res://scenes/ui/cutscenes/beats/TurnOffTapIntro.tscn
##
## BEAT 1  A row of faucets blasts at full force; the puddle creeps up
##         the tiles; Mayor Ripple points at each tap in urgent turn.
## BEAT 2  (flash-only impact) The puddle SURGES — a wave crest flares
##         across the floor and the whole queue freezes.
## BEAT 3  Dribble squares up to the row, ready to shut every tap.

const Props := preload("res://scripts/cutscenes/beats/TurnOffTapProps.gd")

var taps: Array = []
var puddle: Node2D
var tap_size: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	# Bathroom tile over the default grass.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	floor_poly.color = Props.TILE
	floor_poly.z_index = 0
	world.add_child(floor_poly)
	for i in range(3):
		var grout := Line2D.new()
		grout.width = 2.0 * _content_scale
		grout.default_color = Props.TILE_LINE
		var y := _vp.y * (GROUND_FRACTION + 0.08 * float(i + 1))
		grout.points = PackedVector2Array([Vector2(0.0, y), Vector2(_vp.x, y)])
		grout.z_index = 0
		world.add_child(grout)
	# The row of faucets, all blasting at full force.
	tap_size = _vp.y * 0.42
	var tap_x := [0.30, 0.44, 0.58, 0.72]
	for i in range(tap_x.size()):
		var tap := Props.make_faucet(tap_size, true)
		tap.position = Vector2(_vp.x * tap_x[i], _vp.y * GROUND_FRACTION)
		tap.z_index = 2
		world.add_child(tap)
		taps.append(tap)
	# The rising puddle creeping out from under the row.
	puddle = Props.make_puddle()
	puddle.position = Vector2(_vp.x * 0.51, _vp.y * GROUND_FRACTION)
	puddle.z_index = 1
	world.add_child(puddle)
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.16)
	camera.position = _vp * 0.5

func _set_puddle(h: float) -> void:
	var water := puddle.get_node("Water") as Polygon2D
	water.polygon = Props.puddle_poly(_vp.x * 0.34, _vp.y * 0.06 * h)

## BEAT 1 — full blast; the puddle creeps; the mayor points in sequence.
func _beat_setup() -> void:
	_set_puddle(0.15)
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t in townsfolk:
		t.start_idle()
	# The streams throb at full pressure.
	for tap: Node2D in taps:
		var stream := tap.get_node("Stream") as Polygon2D
		var pulse := _ct(stream).set_loops(3)
		pulse.tween_property(stream, "scale:x", 1.25, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(stream, "scale:x", 1.0, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor points at each tap, urgently, one after another.
	var point_seq := _ct(mayor)
	for i in range(taps.size()):
		point_seq.tween_interval(0.16)
		point_seq.tween_callback(mayor.hop.bind(9.0, 0.15))
		point_seq.tween_property(mayor, "rotation",
			0.12 if i % 2 == 0 else -0.06, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The puddle creeps up the tiles.
	var rise := _ct(puddle)
	rise.tween_method(_set_puddle, 0.15, 0.55, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## BEAT 2 — the puddle surges. Flash only; the queue freezes.
func _on_impact() -> void:
	_impact_flash()
	var surge := _ct(puddle)
	surge.tween_method(_set_puddle, 0.55, 1.35, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	surge.tween_method(_set_puddle, 1.35, 0.9, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for tap: Node2D in taps:
		var splash := tap.get_node("Splash") as Polygon2D
		var flare := _ct(splash)
		flare.tween_property(splash, "scale", Vector2(1.8, 1.8), 0.07)
		flare.tween_property(splash, "scale", Vector2.ONE, 0.15)
		var jump := _ct(tap)
		jump.tween_property(tap, "position:y",
			tap.position.y - 6.0 * _content_scale, 0.07)
		jump.tween_property(tap, "position:y", tap.position.y, 0.15)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — Dribble squares up to the row; the taps keep blasting.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	var march := _ct(dribble)
	march.tween_property(dribble, "position:x", _vp.x * 0.22, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for tap: Node2D in taps:
		var stream := tap.get_node("Stream") as Polygon2D
		var keep := _ct(stream).set_loops(3)
		keep.tween_property(stream, "scale:x", 1.2, 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		keep.tween_property(stream, "scale:x", 1.0, 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
