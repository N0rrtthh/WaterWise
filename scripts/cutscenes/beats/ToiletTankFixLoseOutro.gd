## ToiletTankFix - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ToiletTankFixLoseOutro.tscn

extends MicrogameOutroBase

## Toilet Tank Fix — LOSE clip.
## res://scenes/ui/cutscenes/beats/ToiletTankFixLoseOutro.tscn
##
## BEAT 1  The fill blows past the green mark; a hairline crack creeps
##         across the tank.
## BEAT 2  (impact on the crack/burst) THE TANK BURSTS — shards fly, the
##         lid launches like a frisbee, a geyser erupts.
## BEAT 3  Dribble spirals down the bowl in an exaggerated cartoon flush
##         and shoots out toward the cliff-side sewer outlet.

const Props := preload("res://scripts/cutscenes/beats/ToiletTankProps.gd")

var toilet: Node2D
var tank: Node2D
var tank_water: Polygon2D
var toilet_size: float
var crack: Line2D
var geyser: Node2D
var sewer: Node2D
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
	# The toilet, overfilled past the mark.
	toilet = Props.make_toilet(toilet_size, false)
	toilet.position = Vector2(_vp.x * 0.26, _vp.y * GROUND_FRACTION)
	toilet.z_index = 2
	world.add_child(toilet)
	tank = toilet.get_node("Tank") as Node2D
	tank_water = tank.get_node("TankWater") as Polygon2D
	var float_arm := Props.make_float(toilet_size * 0.3)
	float_arm.position = Vector2(toilet_size * 0.08, 0.0)
	tank.add_child(float_arm)
	mouth_point = toilet.position + Vector2(0.0, -toilet_size * 0.52)
	# The hairline crack, zigzagging down the tank face, invisible.
	crack = Line2D.new()
	crack.name = "Crack"
	crack.width = 1.2 * _content_scale
	crack.default_color = Props.OUTLINE
	var cy := -toilet_size * 0.14
	crack.points = PackedVector2Array([
		Vector2(-toilet_size * 0.2, cy), Vector2(-toilet_size * 0.1, cy - toilet_size * 0.09),
		Vector2(-toilet_size * 0.18, cy - toilet_size * 0.18),
		Vector2(-toilet_size * 0.06, cy - toilet_size * 0.26),
	])
	crack.modulate.a = 0.0
	tank.add_child(crack)
	# The burst geyser, coiled above the tank until the burst.
	geyser = Props.make_geyser(toilet_size * 0.7)
	geyser.position = Vector2(toilet.position.x, toilet.position.y - toilet_size * 1.02)
	geyser.scale = Vector2(0.0, 0.0)
	geyser.z_index = 6
	world.add_child(geyser)
	# The cliff-side sewer outlet, waiting at the right edge.
	sewer = Props.make_sewer(_vp.y * 0.26)
	sewer.position = Vector2(_vp.x * 0.97, _vp.y * GROUND_FRACTION)
	sewer.z_index = 1
	world.add_child(sewer)
	_stage_townsfolk(2, _vp.x * 0.46, _vp.x * 0.58)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.68, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.39)
	camera.position = _vp * 0.5

func _set_tank_fill(f: float) -> void:
	tank_water.polygon = Props.tank_poly(toilet_size, toilet_size * 0.37 * f)

## Impact frame: the crack mid-tank, where the burst tears open.
func _impact_point() -> Vector2:
	return toilet.position + Vector2(-toilet_size * 0.12, -toilet_size * 0.28)

## BEAT 1 — the fill blows past the mark; the crack creeps.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The fill climbs past the mark and keeps going.
	var climb := _ct(tank_water)
	climb.tween_method(_set_tank_fill, 0.95, 1.3, 0.55)
	# The hairline crack creeps across the tank face.
	var spread := _ct(crack)
	spread.tween_property(crack, "modulate:a", 1.0, 0.2)
	spread.parallel().tween_property(crack, "width", 2.4 * _content_scale, 0.5)
	# The tank quivers under the pressure.
	var quake := _ct(tank).set_loops(3)
	quake.tween_property(tank, "position:x",
		tank.position.x + 2.0 * _content_scale, 0.05)
	quake.tween_property(tank, "position:x",
		tank.position.x - 2.0 * _content_scale, 0.05)
	quake.tween_property(tank, "position:x", tank.position.x, 0.04)
	# The crowd's smiles die.
	for i in range(townsfolk.size()):
		var dread := _ct(townsfolk[i]).set_loops(2)
		dread.tween_interval(0.18 * float(i))
		dread.tween_callback(townsfolk[i].hop.bind(4.0, 0.26))
		dread.tween_interval(0.30)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 2 — impact ON the crack: THE TANK BURSTS.
func _on_impact() -> void:
	super._on_impact()
	# The crack flashes white and tears open.
	var tear := _ct(crack)
	tear.tween_property(crack, "default_color", Color(1.0, 1.0, 1.0), 0.05)
	tear.tween_property(crack, "default_color", Props.OUTLINE, 0.2)
	# THE GEYSER erupts from the open tank.
	var erupt := _ct(geyser)
	erupt.tween_property(geyser, "scale", Vector2.ONE, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Porcelain shards fly.
	for i in range(6):
		var shard := Props.make_shard(
			(9.0 + 3.0 * float(i % 3)) * _content_scale)
		shard.position = _impact_point()
		shard.z_index = 7
		world.add_child(shard)
		var dir := -1.0 if i % 2 == 0 else 1.0
		var fly := _ct(shard)
		fly.tween_property(shard, "position",
			shard.position + Vector2(dir * _vp.x * (0.03 + 0.012 * float(i)),
				-_vp.y * (0.06 + 0.02 * float(i % 3))), 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(shard, "rotation", dir * (2.0 + float(i)), 0.32)
		fly.tween_property(shard, "position:y",
			shard.position.y + _vp.y * 0.14, 0.36) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(shard, "modulate:a", 0.0, 0.36)
		fly.tween_callback(shard.queue_free)
	# THE LID launches off the tank like a frisbee.
	var lid := toilet.get_node("Lid") as Polygon2D
	lid.z_index = 8
	var frisbee := _ct(lid).set_parallel(true)
	frisbee.tween_property(lid, "position",
		toilet.position + Vector2(_vp.x * 0.22, -_vp.y * 0.34), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	frisbee.tween_property(lid, "rotation", TAU * 3.0, 0.55)
	# The tank drains through the burst.
	var drain := _ct(tank_water)
	drain.tween_method(_set_tank_fill, 1.3, 0.3, 0.5)
	# Everyone watches it come apart.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the cartoon flush: Dribble spirals down the bowl and out
## through the cliff-side sewer outlet.
func _beat_payoff() -> void:
	# The geyser keeps pulsing through the flush.
	var pulse := _ct(geyser).set_loops(3)
	pulse.tween_property(geyser, "scale:y", 1.15, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(geyser, "scale:y", 1.0, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The bowl whirlpool spins up.
	var bowl := toilet.get_node("BowlWater") as Polygon2D
	var whirl := _ct(bowl)
	whirl.tween_property(bowl, "scale", Vector2(2.0, 1.6), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	whirl.parallel().tween_property(bowl, "rotation", TAU * 2.0, 1.0)
	# THE SPIRAL: Dribble whirls down into the bowl, cartoon-style.
	var d0 := dribble.scale
	var spin := _ct(dribble)
	spin.tween_property(dribble, "position",
		mouth_point + Vector2(0.0, -_vp.y * 0.06), 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spin.parallel().tween_property(dribble, "scale", d0 * 0.6, 0.24)
	spin.parallel().tween_property(dribble, "rotation", TAU * 1.5, 0.24)
	spin.tween_property(dribble, "position",
		mouth_point + Vector2(0.0, _vp.y * 0.01), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spin.parallel().tween_property(dribble, "scale", d0 * 0.28, 0.2)
	spin.parallel().tween_property(dribble, "rotation", TAU * 2.5, 0.2)
	# ...and the flush shoots them along the ground toward the sewer.
	spin.tween_property(dribble, "position:x", sewer.position.x, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spin.parallel().tween_property(dribble, "rotation", TAU * 4.0, 0.4)
	spin.parallel().tween_property(dribble, "scale", d0 * 0.16, 0.4)
	# Down into the sewer arch, gone.
	spin.tween_property(dribble, "position:y",
		dribble.position.y + _vp.y * 0.05, 0.15)
	spin.parallel().tween_property(dribble, "scale", d0 * 0.08, 0.15)
	spin.parallel().tween_property(dribble, "modulate:a", 0.0, 0.15)
	# A swirl rings out of the sewer mouth as they vanish.
	var ring := Polygon2D.new()
	ring.polygon = Props._ellipse(16.0 * _content_scale, 9.0 * _content_scale, 16)
	ring.color = Color(0.5, 0.8, 1.0, 0.6)
	ring.position = sewer.position + Vector2(0.0, -_vp.y * 0.10)
	ring.z_index = 7
	world.add_child(ring)
	var puff := _ct(ring)
	puff.tween_interval(0.62)
	puff.tween_property(ring, "scale", Vector2(3.0, 2.5), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	puff.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
	puff.tween_callback(ring.queue_free)
	# The crowd braces; the mayor is appalled.
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(10.0, 0.26)