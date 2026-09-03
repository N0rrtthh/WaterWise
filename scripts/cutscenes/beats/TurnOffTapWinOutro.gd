## TurnOffTap - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TurnOffTapWinOutro.tscn

extends MicrogameOutroBase

## Turn Off Tap — WIN clip.
## res://scenes/ui/cutscenes/beats/TurnOffTapWinOutro.tscn
##
## BEAT 1  The row still blasts; hands hover over every handle.
## BEAT 2  (impact on the synchronized shut-off) All four handles twist
##         shut IN UNISON — the streams die mid-fall and the chrome
##         glints a proud tap-green.
## BEAT 3  The faucets take a little bow, and the mayor frames a
##         comically tiny water bill on the wall.

const Props := preload("res://scripts/cutscenes/beats/TurnOffTapProps.gd")

var taps: Array = []
var bill: Node2D
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
	# The row, still running — for now.
	tap_size = _vp.y * 0.42
	var tap_x := [0.30, 0.44, 0.58, 0.72]
	for i in range(tap_x.size()):
		var tap := Props.make_faucet(tap_size, true)
		tap.position = Vector2(_vp.x * tap_x[i], _vp.y * GROUND_FRACTION)
		tap.z_index = 2
		world.add_child(tap)
		taps.append(tap)
	# The comically tiny framed water bill, waiting to be hung.
	bill = Props.make_bill(_vp.y * 0.075)
	bill.position = Vector2(_vp.x * 0.82, _vp.y * GROUND_FRACTION - _vp.y * 0.32)
	bill.scale = Vector2(0.001, 0.001)
	bill.z_index = 5
	world.add_child(bill)
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.18)
	camera.position = _vp * 0.5

## Impact frame: mid-row, above the handles.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.51, _vp.y * GROUND_FRACTION - tap_size * 0.6)

## BEAT 1 — the row still blasts; hands hover; the room holds its breath.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	for tap: Node2D in taps:
		var stream := tap.get_node("Stream") as Polygon2D
		var pulse := _ct(stream).set_loops(2)
		pulse.tween_property(stream, "scale:x", 1.2, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(stream, "scale:x", 1.0, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var handle := tap.get_node("Handle") as Node2D
		var hover := _ct(handle).set_loops(2)
		hover.tween_property(handle, "rotation", 0.12, 0.13) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hover.tween_property(handle, "rotation", -0.12, 0.13) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — THE SYNCHRONIZED SHUT-OFF.
func _on_impact() -> void:
	super._on_impact()
	for tap: Node2D in taps:
		var handle := tap.get_node("Handle") as Node2D
		var shut := _ct(handle)
		shut.tween_property(handle, "rotation", TAU * 1.5, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var stream := tap.get_node("Stream") as Polygon2D
		var dry := _ct(stream)
		dry.tween_property(stream, "modulate:a", 0.0, 0.10)
		var splash := tap.get_node("Splash") as Polygon2D
		var splash_dry := _ct(splash)
		splash_dry.tween_property(splash, "modulate:a", 0.0, 0.10)
		# The chrome glints a proud tap-green.
		var glint := _ct(tap)
		glint.tween_property(tap, "modulate",
			Color(1.25, 1.4, 1.25).lerp(Props.CLOSED_GREEN, 0.4), 0.08)
		glint.tween_property(tap, "modulate", Color.WHITE, 0.2)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.HAPPY)

## BEAT 3 — the faucets bow; the mayor hangs the tiny bill.
func _beat_payoff() -> void:
	for tap: Node2D in taps:
		var bow := _ct(tap)
		bow.tween_interval(0.10)
		bow.tween_property(tap, "rotation", 0.32, 0.20) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bow.tween_interval(0.28)
		bow.tween_property(tap, "rotation", 0.0, 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor frames the comically small bill on the wall.
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	var hang := _ct(bill)
	hang.tween_interval(0.18)
	hang.tween_property(bill, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	# Dribble takes a bow with the plumbing.
	dribble.set_expression(CartoonActor.Mood.SMUG)
	var d_bow := _ct(dribble)
	d_bow.tween_interval(0.12)
	d_bow.tween_property(dribble, "rotation", 0.45, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	d_bow.tween_interval(0.3)
	d_bow.tween_property(dribble, "rotation", 0.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.set_arm_pose(CartoonActor.ArmPose.UP)
