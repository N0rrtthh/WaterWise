## VegetableBath - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/VegetableBathLoseOutro.tscn

extends MicrogameOutroBase

## Vegetable Bath — LOSE clip.
## res://scenes/ui/cutscenes/beats/VegetableBathLoseOutro.tscn
##
## BEAT 1  The wash basin is bone dry; the veggies bob in a MUD POOL
##         instead, filthier than ever.
## BEAT 2  (impact on the mud-splash) The pool ERUPTS — the veggies get
##         coated, the town recoils.
## BEAT 3  A protest tomato splats Dribble, and the town pelts him with
##         produce all the way off the cliff.

const Props := preload("res://scripts/cutscenes/beats/VegetableProps.gd")

const VEG_COLORS := [
	Color(1.0, 0.4, 0.2), Color(0.2, 0.7, 0.2), Color(0.8, 0.2, 0.2),
	Color(0.5, 0.3, 0.6), Color(0.9, 0.8, 0.2),
]

var veggies: Array = []
var mud: Node2D
var stall: Node2D
var veg_size: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.CREAM
	# The wooden counter over the default grass.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Counter"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	floor_poly.color = Props.COUNTER
	floor_poly.z_index = 0
	world.add_child(floor_poly)
	var edge := Line2D.new()
	edge.width = 4.0 * _content_scale
	edge.default_color = Props.COUNTER_EDGE
	var gy := _vp.y * GROUND_FRACTION
	edge.points = PackedVector2Array([Vector2(0.0, gy), Vector2(_vp.x, gy)])
	edge.z_index = 0
	world.add_child(edge)
	veg_size = _vp.y * 0.05
	# The dry basin where the water should have been.
	var basin := Props.make_basin(_vp.y * 0.24)
	basin.position = Vector2(_vp.x * 0.47, gy)
	basin.z_index = 2
	world.add_child(basin)
	var dry := basin.get_node("Water") as Polygon2D
	dry.modulate.a = 0.15
	# The mud pool the veggies actually ended up in.
	mud = Node2D.new()
	mud.name = "MudPool"
	mud.position = Vector2(_vp.x * 0.31, gy)
	mud.z_index = 2
	world.add_child(mud)
	var pool := Polygon2D.new()
	pool.name = "Pool"
	pool.polygon = Props.pool_poly(_vp.x * 0.17, _vp.y * 0.055)
	pool.color = Props.MUD
	pool.position = Vector2(0.0, _vp.y * 0.012)
	mud.add_child(pool)
	# Five veggies bobbing in the mud, dirt spots showing.
	var soak := [Vector2(-0.5, -0.5), Vector2(0.0, -0.7), Vector2(0.5, -0.5),
		Vector2(-0.25, -0.85), Vector2(0.3, -0.9)]
	for i in range(5):
		var veg := Props.make_veggie(veg_size, VEG_COLORS[i], true)
		veg.position = mud.position + soak[i] * _vp.y * 0.06
		veg.z_index = 3
		world.add_child(veg)
		veggies.append(veg)
	stall = Props.make_stall(_vp.y * 0.55)
	stall.position = Vector2(_vp.x * 0.86, gy)
	stall.z_index = 1
	world.add_child(stall)
	_stage_townsfolk(2, _vp.x * 0.06, _vp.x * 0.14)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.94, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.51)
	camera.position = _vp * 0.5

## Impact frame: the crown of the mud pool.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.31, _vp.y * GROUND_FRACTION - _vp.y * 0.06)

## BEAT 1 — dry basin, muddy veggies, one worried town.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	# The veggies bob helplessly in the sludge.
	for i in range(veggies.size()):
		var veg := veggies[i] as Node2D
		var bob := _ct(veg).set_loops(3)
		bob.tween_property(veg, "position:y",
			veg.position.y - 5.0 * _content_scale, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(veg, "position:y", veg.position.y, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor stares into the dry basin.
	var peer := _ct(mayor)
	peer.tween_property(mayor, "rotation", 0.16, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	peer.tween_interval(0.2)
	peer.tween_property(mayor, "rotation", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — THE MUD SPLASH: the pool erupts and coats everything.
func _on_impact() -> void:
	super._on_impact()
	var pool := mud.get_node("Pool") as Polygon2D
	var erupt := _ct(pool)
	erupt.tween_property(pool, "scale", Vector2(1.25, 1.7), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	erupt.tween_property(pool, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The veggies get coated: darker, filthier, doomed.
	for veg: Node2D in veggies:
		var coat := _ct(veg)
		coat.tween_property(veg, "modulate", Color(0.72, 0.66, 0.58), 0.12)
		var dirt := veg.get_node("Dirt") as Node2D
		var flare := _ct(dirt)
		flare.tween_property(dirt, "modulate", Color(1.7, 1.4, 0.9), 0.07)
		flare.tween_property(dirt, "modulate", Color.WHITE, 0.16)
	# Brown droplets burst out of the crown.
	for d in range(6):
		var drop := Polygon2D.new()
		drop.polygon = Props.ellipse(6.0 * _content_scale, 8.0 * _content_scale, 10)
		drop.color = Props.MUD
		drop.position = _impact_point()
		drop.z_index = 7
		world.add_child(drop)
		var fly := _ct(drop)
		fly.set_parallel(true)
		fly.tween_property(drop, "position",
			_impact_point() + Vector2(-66.0 + 26.0 * float(d),
				-52.0 + 15.0 * float(d % 3)) * _content_scale, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(drop, "modulate:a", 0.0, 0.35)
		fly.chain().tween_callback(drop.queue_free)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — protest tomato splat, then a full produce pelting as
## Dribble flees off the cliff.
func _beat_payoff() -> void:
	var gy := _vp.y * GROUND_FRACTION
	# THE PROTEST TOMATO arcs in from the stall side and SPLATS.
	var tomato := Props.make_veggie(veg_size, Props.TOMATO, false)
	var t_start := Vector2(_vp.x * 0.62, gy - _vp.y * 0.06)
	var t_end := dribble.position
	tomato.position = t_start
	tomato.z_index = 6
	world.add_child(tomato)
	var toss := _ct(tomato)
	toss.tween_method(func(v: float):
		tomato.position = t_start.lerp(t_end, v)
		tomato.position.y -= _vp.y * 0.22 * sin(v * PI),
		0.0, 1.0, 0.32)
	toss.tween_callback(func():
		tomato.visible = false
		var splat := Props.make_splat(veg_size * 1.2, Props.TOMATO)
		splat.position = t_end + Vector2(0.0, -_vp.y * 0.05)
		splat.z_index = 9
		world.add_child(splat)
		dribble.modulate = Color(1.0, 0.72, 0.66)
		dribble.set_expression(CartoonActor.Mood.SHOCKED)
		var fade := _ct(splat)
		fade.tween_interval(0.5)
		fade.tween_property(splat, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property(splat, "scale",
			Vector2(1.3, 1.3), 0.3))
	# The town pelts Dribble with produce along the retreat path.
	var pelts := [Props.LETTUCE, Props.CARROT, Props.EGGPLANT, Props.CORN]
	for p in range(4):
		var veg := Props.make_veggie(veg_size, pelts[p], false)
		var start := Vector2(_vp.x * (0.30 + 0.06 * float(p)), gy - _vp.y * 0.07)
		var end := Vector2(_vp.x * (0.74 + 0.2 * float(p)), gy - _vp.y * 0.055)
		veg.position = start
		veg.z_index = 6
		world.add_child(veg)
		var throw := _ct(veg)
		throw.tween_interval(0.45 + 0.22 * float(p))
		throw.tween_method(func(v: float):
			veg.position = start.lerp(end, v)
			veg.position.y -= _vp.y * 0.2 * sin(v * PI)
			veg.rotation = v * TAU,
			0.0, 1.0, 0.3)
		throw.tween_callback(func():
			veg.visible = false
			var splat := Props.make_splat(veg_size * 1.1, pelts[p])
			splat.position = end
			splat.z_index = 5
			world.add_child(splat)
			var fade := _ct(splat)
			fade.tween_interval(0.4)
			fade.tween_property(splat, "modulate:a", 0.0, 0.25))
	# ...and Dribble runs for the cliff, slipping off the edge.
	var run := _ct(dribble)
	run.tween_interval(0.42)
	run.tween_property(dribble, "position:x", _vp.x * 0.78, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	run.tween_property(dribble, "position:x", _vp.x * 1.02, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	run.tween_property(dribble, "position:x", _vp.x * 1.3, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run.tween_property(dribble, "position",
		Vector2(_vp.x * 1.45, gy + _vp.y * 0.14), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run.parallel().tween_property(dribble, "modulate:a", 0.0, 0.25)
	# The crowd flings, arms wide.
	for t: CartoonActor in townsfolk:
		t.set_expression(CartoonActor.Mood.SMUG)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.hop(10.0, 0.26)
