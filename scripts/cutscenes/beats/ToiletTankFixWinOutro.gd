## ToiletTankFix - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ToiletTankFixWinOutro.tscn

extends MicrogameOutroBase

## Toilet Tank Fix — WIN clip.
## res://scenes/ui/cutscenes/beats/ToiletTankFixWinOutro.tscn
##
## BEAT 1  The fill creeps toward the green mark; the room hushes.
## BEAT 2  (impact on the flush handle push) The flush works and rings
##         out like a CATHEDRAL-ORGAN CHORD — visible chord rings bloom
##         from the bowl.
## BEAT 3  A choir of singing toilets harmonizes in celebration, music
##         notes floating up; the town bows to the porcelain.

const Props := preload("res://scripts/cutscenes/beats/ToiletTankProps.gd")

var toilet: Node2D
var tank: Node2D
var tank_water: Polygon2D
var toilet_size: float
var choir: Array = []
var mouth_point: Vector2

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	toilet_size = _vp.y * 0.52
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
	# The hero toilet, repaired: lid seated, filled to the mark.
	toilet = Props.make_toilet(toilet_size, false)
	toilet.position = Vector2(_vp.x * 0.28, _vp.y * GROUND_FRACTION)
	toilet.z_index = 2
	world.add_child(toilet)
	tank = toilet.get_node("Tank") as Node2D
	tank_water = tank.get_node("TankWater") as Polygon2D
	var float_arm := Props.make_float(toilet_size * 0.3)
	float_arm.position = Vector2(toilet_size * 0.08, 0.0)
	tank.add_child(float_arm)
	mouth_point = toilet.position + Vector2(0.0, -toilet_size * 0.52)
	# The choir: three singing toilets, mouths open, ready to harmonize.
	# Spread wide and small so the trio reads as distinct pipes, not a
	# garbled overlapping stack.
	var choir_x := [0.70, 0.83, 0.95]
	var choir_size := [0.22, 0.26, 0.22]
	for i in range(3):
		var t := Props.make_toilet(_vp.y * choir_size[i], false, true)
		t.position = Vector2(_vp.x * choir_x[i], _vp.y * GROUND_FRACTION)
		t.z_index = 2
		world.add_child(t)
		choir.append(t)
	_stage_townsfolk(2, _vp.x * 0.44, _vp.x * 0.55)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.64, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.41)
	camera.position = _vp * 0.5

func _set_tank_fill(f: float) -> void:
	tank_water.polygon = Props.tank_poly(toilet_size, toilet_size * 0.37 * f)

## Impact frame: the bowl mouth, where the organ chord blooms from.
func _impact_point() -> Vector2:
	return mouth_point

## BEAT 1 — the fill creeps toward the mark; the room hushes.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The fill creeps that last bit toward the mark. Too slow.
	var creep := _ct(tank_water)
	creep.tween_method(_set_tank_fill, 0.75, 0.78, 0.55)
	# The float quivers at the mark.
	var ball := tank.get_node("Float/Ball") as Polygon2D
	var quiver := _ct(ball).set_loops(3)
	quiver.tween_property(ball, "position:x",
		ball.position.x + 2.0 * _content_scale, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	quiver.tween_property(ball, "position:x",
		ball.position.x - 2.0 * _content_scale, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The choir breathes, mouths closed, warming up.
	for i in range(choir.size()):
		var m := (choir[i] as Node2D).get_node("Mouth") as Polygon2D
		var breathe := _ct(m).set_loops(2)
		breathe.tween_interval(0.15 * float(i))
		breathe.tween_property(m, "scale:y", 0.8, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathe.tween_property(m, "scale:y", 1.0, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The hush: everyone leans in.
	for i in range(townsfolk.size()):
		var hush := _ct(townsfolk[i]).set_loops(2)
		hush.tween_interval(0.20 * float(i))
		hush.tween_callback(townsfolk[i].hop.bind(4.0, 0.30))
		hush.tween_interval(0.36)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)

## BEAT 2 — impact ON the flush handle push: the organ chord.
func _on_impact() -> void:
	super._on_impact()
	# The handle pushes down; the flush pulls the tank water through.
	var handle := tank.get_node("Handle") as Node2D
	var push := _ct(handle)
	push.tween_property(handle, "rotation", 0.55, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var drain := _ct(tank_water)
	drain.tween_method(_set_tank_fill, 0.78, 0.2, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The flush swirl in the bowl.
	var bowl := toilet.get_node("BowlWater") as Polygon2D
	var swirl := _ct(bowl)
	swirl.tween_property(bowl, "scale", Vector2(1.7, 1.7), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swirl.parallel().tween_property(bowl, "rotation", TAU * 1.5, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# THE CATHEDRAL-ORGAN CHORD: three chord rings bloom from the bowl.
	for i in range(3):
		var ring := Polygon2D.new()
		ring.polygon = Props._ellipse(30.0 * _content_scale, 14.0 * _content_scale, 20)
		ring.color = Color(0.6, 0.85, 1.0, 0.55)
		ring.position = mouth_point
		ring.z_index = 7
		world.add_child(ring)
		var bloom := _ct(ring)
		bloom.tween_interval(0.05 * float(i))
		bloom.tween_property(ring, "scale", Vector2(7.0, 6.0), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bloom.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
		bloom.tween_callback(ring.queue_free)
	# The choir's mouths pop open — the chord hits them too.
	for i in range(choir.size()):
		var m := (choir[i] as Node2D).get_node("Mouth") as Polygon2D
		var open := _ct(m)
		open.tween_interval(0.06 * float(i))
		open.tween_property(m, "scale:y", 1.7, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Everyone is stunned by the acoustics.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the choir harmonizes; the town bows to the porcelain.
func _beat_payoff() -> void:
	# THE CHOIR: the toilets sing, mouths pulsing out of phase.
	for i in range(choir.size()):
		var c := choir[i] as Node2D
		var m := c.get_node("Mouth") as Polygon2D
		var sing := _ct(m).set_loops(3)
		sing.tween_property(m, "scale:y", 1.7, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sing.tween_property(m, "scale:y", 0.85, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sing.tween_interval(0.04 * float(i % 2))
		# ...and each voice floats music notes up.
		for n in range(2):
			var note := Props.make_note(
				(16.0 + 4.0 * float((i + n) % 3)) * _content_scale)
			note.position = c.position \
				+ Vector2((-10.0 + 20.0 * float(n)) * _content_scale,
					-_vp.y * (0.40 + 0.04 * float(i)))
			note.scale = Vector2(0.4, 0.4)
			note.z_index = 6
			world.add_child(note)
			var rise := _ct(note)
			rise.tween_interval(0.10 + 0.18 * float(i) + 0.08 * float(n))
			rise.set_parallel(true)
			rise.tween_property(note, "position:y",
				note.position.y - _vp.y * 0.10, 0.7) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rise.tween_property(note, "scale", Vector2.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			rise.tween_property(note, "rotation", 0.4, 0.7)
			rise.tween_property(note, "modulate:a", 0.0, 0.7)
			rise.chain().tween_callback(note.queue_free)
	# THE TOWN BOWS TO THE PORCELAIN.
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		var bow := _ct(t)
		bow.tween_interval(0.12)
		bow.tween_property(t, "rotation", 0.45, 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bow.tween_interval(0.3)
		bow.tween_property(t, "rotation", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	var mayor_bow := _ct(mayor)
	mayor_bow.tween_interval(0.12)
	mayor_bow.tween_property(mayor, "rotation", 0.45, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor_bow.tween_interval(0.3)
	mayor_bow.tween_property(mayor, "rotation", 0.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Dribble takes a proud bow beside the instrument.
	dribble.set_expression(CartoonActor.Mood.SMUG)
	var d_bow := _ct(dribble)
	d_bow.tween_interval(0.12)
	d_bow.tween_property(dribble, "rotation", 0.45, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	d_bow.tween_interval(0.3)
	d_bow.tween_property(dribble, "rotation", 0.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)