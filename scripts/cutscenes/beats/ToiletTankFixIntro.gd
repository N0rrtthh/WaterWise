## ToiletTankFix - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ToiletTankFixIntro.tscn

extends MicrogameIntroBase

## Toilet Tank Fix — CAUSE clip.
## res://scenes/ui/cutscenes/beats/ToiletTankFixIntro.tscn
##
## BEAT 1  The tank sits lid-off with the water visibly low; a queue of
##         townsfolk taps its feet outside the stall door.
## BEAT 2  (flash-only impact) The green target line on the tank FLARES —
##         the mark the fill must hit. The queue freezes and stares.
## BEAT 3  Dribble seats the float, the lever gleams, and the water
##         climbs toward the mark. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/ToiletTankProps.gd")

var toilet: Node2D
var tank: Node2D
var tank_water: Polygon2D
var toilet_size: float

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
	# The toilet, tank lid leaning against it, water low.
	toilet = Props.make_toilet(toilet_size, true)
	toilet.position = Vector2(_vp.x * 0.34, _vp.y * GROUND_FRACTION)
	toilet.z_index = 2
	world.add_child(toilet)
	tank = toilet.get_node("Tank") as Node2D
	tank_water = tank.get_node("TankWater") as Polygon2D
	# The float on its arm, parked low in the near-empty tank.
	var float_arm := Props.make_float(toilet_size * 0.3)
	float_arm.position = Vector2(toilet_size * 0.08, 0.0)
	tank.add_child(float_arm)
	# The queue of waiting townsfolk, then the inspecting mayor.
	_stage_townsfolk(3, _vp.x * 0.05, _vp.x * 0.20)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.88, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.47)
	camera.position = _vp * 0.5

func _set_tank_fill(f: float) -> void:
	tank_water.polygon = Props.tank_poly(toilet_size, toilet_size * 0.37 * f)

## BEAT 1 — the queue shuffles and taps; the tank sits sadly low.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	# The queue taps its feet, in order, one after another.
	for i in range(townsfolk.size()):
		var t := townsfolk[i] as CartoonActor
		t.start_idle()
		var tap := _ct(t).set_loops(3)
		tap.tween_interval(0.10 + 0.12 * float(i))
		tap.tween_callback(t.hop.bind(3.0, 0.14))
		tap.tween_interval(0.16)
	# The lid wobbles on its lean against the tank.
	var lid := toilet.get_node("Lid") as Polygon2D
	var rock := _ct(lid).set_loops(2)
	rock.tween_property(lid, "rotation", 0.95, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock.tween_property(lid, "rotation", 0.85, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The float droops in the near-empty tank.
	var ball := tank.get_node("Float/Ball") as Polygon2D
	var droop := _ct(ball).set_loops(2)
	droop.tween_property(ball, "position:y",
		ball.position.y + 4.0 * _content_scale, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	droop.tween_property(ball, "position:y", ball.position.y, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the green mark flares. Flash only; the queue freezes.
func _on_impact() -> void:
	_impact_flash()
	var line := tank.get_node("TargetLine") as Line2D
	var flare := _ct(line)
	flare.tween_property(line, "width", line.width * 2.2, 0.06)
	flare.parallel().tween_property(line, "default_color",
		Color(0.85, 1.0, 0.85), 0.06)
	flare.tween_property(line, "width", line.width * 1.4, 0.16)
	flare.parallel().tween_property(line, "default_color", Props.LINE, 0.16)
	# The whole queue stares at the mark.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — float seated, lever gleams, the fill begins.
func _beat_payoff() -> void:
	var handle := tank.get_node("Handle") as Node2D
	var gleam := _ct(handle)
	gleam.tween_property(handle, "modulate", Color(1.6, 1.6, 1.3), 0.1)
	gleam.tween_property(handle, "modulate", Color.WHITE, 0.2)
	var ball := tank.get_node("Float/Ball") as Polygon2D
	var seat := _ct(ball)
	seat.tween_method(_set_tank_fill, 0.12, 0.6, 0.30)
	# Dribble gives the thumbs up; the queue edges forward.
	dribble.set_expression(CartoonActor.Mood.SMUG)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)