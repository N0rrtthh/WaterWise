## BucketBrigade - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/BucketBrigadeWinOutro.tscn

extends MicrogameOutroBase

## Bucket Brigade — WIN outro.
## res://scenes/ui/cutscenes/beats/BucketBrigadeWinOutro.tscn
##
## BEAT 1  Brigade warm-up hops along the line.
## BEAT 2  The garden ERUPTS into a giant fruit tree: scale-up + leaf/fruit
##         particle burst + camera punch + stinger, all on the impact tick.
## BEAT 3  The brigade breaks into a conga line spraying water arcs, then the
##         town gathers under the tree to feast. SNAP: zoom-snap.

const Props := preload("res://scripts/cutscenes/beats/BucketBrigadeProps.gd")

var _tree: Node2D
var _tree_x: float

func _setup_stage() -> void:
	_tree_x = _vp.x * 0.5
	_make_tree()
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.74, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	_stage_townsfolk(5, _vp.x * 0.08, _vp.x * 0.62)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.32)

## Giant fruit tree, built hidden at 2% scale behind the whole cast (z -2).
func _make_tree() -> void:
	_tree = Node2D.new()
	_tree.name = "FruitTree"
	_tree.position = Vector2(_tree_x, _vp.y * GROUND_FRACTION + 4.0 * _content_scale)
	_tree.scale = Vector2(0.02, 0.02)
	_tree.visible = false
	_tree.z_index = -2

	var trunk := Polygon2D.new()
	trunk.name = "Trunk"
	trunk.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(16, 0), Vector2(10, -78), Vector2(-10, -78),
	])
	trunk.color = Color(0.48, 0.33, 0.2)
	_tree.add_child(trunk)

	var canopy: Array = [
		[Vector2(0, -128), 96.0, 66.0, Color(0.32, 0.66, 0.32)],
		[Vector2(-62, -96), 58.0, 42.0, Color(0.27, 0.6, 0.3)],
		[Vector2(62, -100), 58.0, 42.0, Color(0.38, 0.72, 0.36)],
	]
	for c in canopy:
		var leaf := Polygon2D.new()
		leaf.polygon = _ellipse_poly(c[1], c[2])
		leaf.position = c[0]
		leaf.color = c[3]
		_tree.add_child(leaf)

	var fruit_spots: Array = [
		Vector2(-48, -110), Vector2(-10, -150), Vector2(36, -122),
		Vector2(-30, -92), Vector2(52, -148), Vector2(6, -100),
	]
	for spot in fruit_spots:
		var fruit := Polygon2D.new()
		fruit.polygon = _ellipse_poly(9.0, 9.0)
		fruit.position = spot
		fruit.color = Color(0.95, 0.5, 0.28)
		_tree.add_child(fruit)

	world.add_child(_tree)

func _ellipse_poly(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## BEAT 1 — staggered warm-up hops down the line.
func _beat_setup() -> void:
	var cast: Array = townsfolk.duplicate()
	cast.append(mayor)
	cast.append(dribble)
	for i in range(cast.size()):
		var a: CartoonActor = cast[i]
		a.start_idle()
		a.start_blinking()
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(a.hop.bind(32.0, 0.3))

func _crown_point() -> Vector2:
	return Vector2(_tree_x, _vp.y * GROUND_FRACTION - 150.0 * _content_scale)

## BEAT 2 — the eruption. Everything fires on the SAME tick (base contract),
## but the burst blooms from the tree crown, not above Dribble.
func _on_impact() -> void:
	super._on_impact()
	# No second _camera_punch() or _play_stinger() here: super() already fired both,
	# and repeating them in the same frame doubled the stinger (measured simul=2 in
	# tools/VerifyOutroImpact.tscn) and put two tweens on camera.zoom at once. The
	# crown burst stays -- it lands at a different point than super's, so it reads
	# as a second accent rather than a duplicate.
	_spawn_burst(_crown_point(), false)
	_grow_tree()

func _grow_tree() -> void:
	_tree.visible = true
	var t := _ct()
	t.tween_property(_tree, "scale", Vector2.ONE * _content_scale, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## BEAT 3 — conga line + water arcs + a second fruit pop, then the feast.
func _beat_payoff() -> void:
	for i in range(townsfolk.size()):
		townsfolk[i].set_expression(CartoonActor.Mood.HAPPY)
		townsfolk[i].set_arm_pose(CartoonActor.ArmPose.CHEER)
		var tw := _ct()
		tw.tween_interval(0.09 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(44.0, 0.34))
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	dribble.hop(48.0, 0.36)
	_spray_water()
	# Second leaf/fruit pop as the canopy settles.
	var pop := _ct()
	pop.tween_interval(0.25)
	pop.tween_callback(_spawn_burst.bind(
		_crown_point() + Vector2(0.0, -24.0 * _content_scale), false
	))
	# The town gathers under the tree to feast.
	var gather := _ct().set_parallel(true)
	gather.tween_property(mayor, "position:x", _tree_x + 78.0 * _content_scale, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if townsfolk.size() > 0:
		gather.tween_property(townsfolk[0], "position:x", _tree_x - 84.0 * _content_scale, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if townsfolk.size() > 1:
		gather.tween_property(townsfolk[1], "position:x", _tree_x - 140.0 * _content_scale, 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Cheap celebratory water arcs over the conga line: flat blue dots on
## parabolic tweens, self-freeing.
func _spray_water() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	for i in range(4):
		var drop := Polygon2D.new()
		drop.polygon = _ellipse_poly(6.0, 6.0)
		drop.color = Props.WATER
		drop.z_index = 15
		var from := Vector2(
			_vp.x * (0.14 + 0.17 * float(i)),
			ground_y - 64.0 * _content_scale
		)
		drop.position = from
		world.add_child(drop)
		var arc := Vector2(90.0, -70.0) * _content_scale
		var t := _ct()
		t.tween_property(drop, "position", from + Vector2(arc.x * 0.5, arc.y), 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(drop, "position", from + Vector2(arc.x, 26.0 * _content_scale), 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(drop, "modulate:a", 0.0, 0.16)
		t.tween_callback(drop.queue_free)
