## TimingTap - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TimingTapLoseOutro.tscn

extends MicrogameOutroBase

## Timing Tap — LOSE clip.
## res://scenes/ui/cutscenes/beats/TimingTapLoseOutro.tscn
##
## BEAT 1  The pour blows straight past the line; the glass trembles,
##         bulging over the rim.
## BEAT 2  (impact) THE CREST — the tank overflows and a mini tsunami
##         rises off the counter.
## BEAT 3  Mayor Ripple surfs the flood on a serving tray; a broom
##         sweeps Dribble out on the wave, toward the cliff.

const Props := preload("res://scripts/cutscenes/beats/TimingTapProps.gd")

const CLIFF_X := 0.94

var glass: Node2D
var tap: Node2D
var arc: Node2D
var water_body: Polygon2D
var glass_size: float
var wave: Node2D
var broom: Node2D
var tray: Node2D

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
	tap = Props.make_tap(_vp.y * 0.40)
	tap.position = Vector2(_vp.x * 0.36, _vp.y * 0.40)
	tap.z_index = 3
	world.add_child(tap)
	# The glass, ALREADY bulging over the rim.
	glass = Props.make_glass(glass_size, 1.15)
	glass.position = Vector2(_vp.x * 0.36, _vp.y * 0.665)
	glass.z_index = 3
	world.add_child(glass)
	water_body = glass.get_node("Water") as Polygon2D
	arc = Props.make_water_arc(_vp.y * 0.20)
	arc.position = tap.position
	arc.rotation = PI * 0.5
	arc.z_index = 4
	world.add_child(arc)
	# The broom, leaning in the corner, waiting for its moment.
	broom = Props.make_broom(_vp.y * 0.30)
	broom.position = Vector2(_vp.x * 0.06, _vp.y * GROUND_FRACTION)
	broom.z_index = 5
	world.add_child(broom)
	# The mayor's serving tray, hidden until the surf.
	tray = Props.make_tray(_vp.y * 0.22)
	tray.scale = Vector2(0.0, 0.0)
	tray.z_index = 8
	world.add_child(tray)
	# The floodwave, parked offscreen left.
	wave = Props.make_wave(_vp.x * 0.55)
	wave.position = Vector2(-_vp.x * 0.45, _vp.y * GROUND_FRACTION)
	wave.z_index = 6
	world.add_child(wave)
	_stage_townsfolk(2, _vp.x * 0.60, _vp.x * 0.74)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.88, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.14)
	dribble.z_index = 7
	camera.position = _vp * 0.5

func _set_water_fill(f: float) -> void:
	water_body.polygon = Props.water_poly(glass_size, glass_size * 0.72 * f)

## Impact frame: the overflow crest at the rim.
func _impact_point() -> Vector2:
	return glass.position + Vector2(0.0, -glass_size * 0.72 * 1.15)

## BEAT 1 — the pour blows past the mark; the glass quivers.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The overflow bulge quivers over the rim.
	var quake := _ct(glass).set_loops(3)
	quake.tween_property(glass, "position:x",
		glass.position.x + 2.0 * _content_scale, 0.05)
	quake.tween_property(glass, "position:x",
		glass.position.x - 2.0 * _content_scale, 0.05)
	quake.tween_property(glass, "position:x", glass.position.x, 0.04)
	# Water keeps climbing past the mark.
	var climb := _ct(water_body)
	climb.tween_method(_set_water_fill, 1.15, 1.28, 0.55)
	# The crowd's smiles die.
	for i in range(townsfolk.size()):
		var dread := _ct(townsfolk[i]).set_loops(2)
		dread.tween_interval(0.18 * float(i))
		dread.tween_callback(townsfolk[i].hop.bind(4.0, 0.26))
		dread.tween_interval(0.30)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 2 — THE CREST: the tank overflows ON the tick.
func _on_impact() -> void:
	super._on_impact()
	# The bulge blows up and over the rim.
	var burst := _ct(water_body)
	burst.tween_method(_set_water_fill, 1.28, 1.42, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Foam blows off the rim sideways.
	for i in range(5):
		var dot := Polygon2D.new()
		dot.polygon = Props._ellipse(5.0 * _content_scale, 4.0 * _content_scale, 8)
		dot.color = Props.WAVE_FOAM
		dot.position = _impact_point() \
			+ Vector2(_vp.x * (-0.010 + 0.020 * float(i % 2)), 0.0)
		dot.z_index = 6
		world.add_child(dot)
		var fly := _ct(dot)
		fly.tween_property(dot, "position", dot.position
			+ Vector2(_vp.x * 0.045 * (1.0 if i % 2 == 0 else -1.0),
				-_vp.y * 0.03), 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(dot, "position:y",
			dot.position.y + _vp.y * 0.10, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(dot, "modulate:a", 0.0, 0.30)
		fly.tween_callback(dot.queue_free)
	# Everyone sees it coming.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the tsunami; the mayor surfs, the broom sweeps.
func _beat_payoff() -> void:
	# THE TSUNAMI: a floodwave builds and sweeps across the room.
	var sweep := _ct(wave)
	sweep.tween_property(wave, "position:x", _vp.x * 1.15, 0.95) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# MAYOR RIPPLE SURFS: tray under the mayor, riding the crest out.
	mayor.z_index = 9
	tray.position = mayor.position
	var tray_in := _ct(tray)
	tray_in.tween_property(tray, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var mount := _ct(mayor)
	mount.tween_property(mayor, "position:y", tray.position.y - _vp.y * 0.045, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	# Surf out with the flood, wobbling like a pro.
	var surf := _ct(mayor)
	surf.tween_interval(0.16)
	surf.tween_property(mayor, "position:x", _vp.x * 1.18, 0.80) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var surf_tray := _ct(tray)
	surf_tray.tween_interval(0.16)
	surf_tray.tween_property(tray, "position:x",
		tray.position.x + _vp.x * 0.30, 0.80) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var lean := _ct(mayor).set_loops(4)
	lean.tween_property(mayor, "rotation", 0.10, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean.tween_property(mayor, "rotation", -0.10, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# THE BROOM: swoops in behind Dribble and pushes them onto the wave.
	var swoop := _ct(broom)
	swoop.tween_interval(0.18)
	swoop.tween_property(broom, "position",
		Vector2(dribble.position.x - _vp.x * 0.05, _vp.y * GROUND_FRACTION), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Dribble rides the flood: shove, glide, then off the cliff.
	var ride := _ct(dribble)
	ride.tween_interval(0.30)
	ride.tween_property(dribble, "position:x", _vp.x * 0.42, 0.26) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ride.tween_property(dribble, "position:x", _vp.x * 0.88, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ride.tween_property(dribble, "position:x", _vp.x * CLIFF_X, 0.10)
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	# Off the edge with the floodwater, tumbling.
	var drop := _ct(dribble)
	drop.tween_interval(1.00)
	drop.tween_property(dribble, "rotation", 0.5, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.parallel().tween_property(dribble, "position",
		Vector2(_vp.x * (CLIFF_X + 0.04), _vp.y * 1.15), 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The broom chases the sweep all the way to the cliff edge.
	var chase := _ct(broom)
	chase.tween_interval(0.30)
	chase.tween_property(broom, "position:x", _vp.x * 0.36, 0.26) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	chase.tween_property(broom, "position:x", _vp.x * 0.82, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	chase.tween_property(broom, "position:x", _vp.x * (CLIFF_X - 0.06), 0.10)
	# The sweeping strokes.
	var stroke := _ct(broom).set_loops(4)
	stroke.tween_property(broom, "rotation", 0.18, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stroke.tween_property(broom, "rotation", -0.12, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The crowd watches the flood win.
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)