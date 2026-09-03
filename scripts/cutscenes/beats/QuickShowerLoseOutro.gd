## QuickShower - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/QuickShowerLoseOutro.tscn

extends MicrogameOutroBase

## Quick Shower — LOSE clip.
## res://scenes/ui/cutscenes/beats/QuickShowerLoseOutro.tscn
##
## BEAT 1  Water rises under the bathroom door — the bathroom is flooding.
## BEAT 2  (impact) The bathtub BURSTS through the doorway with Dribble in
##         it; the door flings off its hinge.
## BEAT 3  The tub sails down the main street and over the cliff, rocking.

const Props := preload("res://scripts/cutscenes/beats/QuickShowerProps.gd")

const CLIFF_X := 0.94

var doorway: Node2D
var door_panel: Node2D
var flood: Polygon2D
var tub: Node2D
var door_base: Vector2

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG_BATH
	_stage_townsfolk(3, _vp.x * 0.28, _vp.x * 0.42)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.50, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.60)
	dribble.visible = false  # inside the bathroom until the burst
	var door_w := _vp.x * 0.14
	var door_h := _vp.y * 0.30
	doorway = Props.make_door(door_w, door_h)
	door_base = Vector2(_vp.x * 0.66, _vp.y * GROUND_FRACTION)
	doorway.position = door_base
	doorway.z_index = 5
	world.add_child(doorway)
	door_panel = doorway.get_node("Door") as Node2D
	# Flood water: a flat translucent sheet seeping out from under the door.
	# Origin at the door base; tween "scale:y" to raise it.
	flood = Polygon2D.new()
	flood.name = "Flood"
	flood.polygon = PackedVector2Array([
		Vector2(-door_w * 0.5, 0.0), Vector2(door_w * 1.5, 0.0),
		Vector2(door_w * 1.5, -1.0), Vector2(-door_w * 0.5, -1.0),
	])
	flood.position = door_base
	flood.color = Props.WATER
	flood.z_index = 4
	flood.scale = Vector2(1.0, 0.01)
	world.add_child(flood)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.WORRIED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()
	# The flood rises through the whole setup beat, cresting at the tick.
	var rise := _ct(flood)
	rise.tween_property(flood, "scale:y", _vp.y * 0.16, _setup_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# The queue backs away from the rising water.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_property(townsfolk[i], "position:x", townsfolk[i].position.x - _vp.x * 0.03, _setup_sec()) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Impact frame is the burst: tub + Dribble punch through the doorway.
func _impact_point() -> Vector2:
	return door_base + Vector2(0.0, -_vp.y * 0.12)

## BEAT 2 — the burst. Full impact stack as the tub blows the door open.
func _on_impact() -> void:
	super._on_impact()
	# The door flings wide on its hinge.
	var fling := _ct(door_panel)
	fling.tween_property(door_panel, "rotation", -1.9, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Dribble + tub pop out, riding the flood wave.
	tub = Props.make_tub(_vp.y * 0.20)
	tub.position = door_base + Vector2(_vp.x * 0.02, -_vp.y * 0.08)
	tub.z_index = 8
	world.add_child(tub)
	dribble.visible = true
	dribble.set_expression(CartoonActor.Mood.DIZZY)
	dribble.position = tub.position + Vector2(0.0, -_vp.y * 0.085)
	# Pop: both squash-stretch on emergence.
	for target in [tub, dribble]:
		var node := target as Node2D
		var pop := _ct(node)
		pop.tween_property(node, "scale", Vector2(1.15, 0.85) * _content_scale, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(node, "scale", Vector2.ONE * _content_scale, 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Spill: spray-droplet burst at the doorway (flat circles, rise+fade).
	for i in range(10):
		_spill_droplet(door_base + Vector2(0.0, -_vp.y * 0.06), i)
	# The queue reels back.
	var queue: Array = [mayor]
	for t in townsfolk:
		queue.append(t)
	for i in range(queue.size()):
		var member := queue[i] as CartoonActor
		member.set_expression(CartoonActor.Mood.SHOCKED)
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(member.hop.bind(16.0, 0.26))

func _spill_droplet(from: Vector2, i: int) -> void:
	var drop := Polygon2D.new()
	drop.polygon = Props._ellipse(7.0 * _content_scale, 5.0 * _content_scale, 10)
	drop.position = from
	drop.color = Props.WATER_SOFT if i % 2 == 0 else Props.WATER
	drop.z_index = 9
	world.add_child(drop)
	var a := -PI * 0.25 - PI * 0.5 * float(i) / 9.0
	var far := from + Vector2(cos(a), sin(a)) * (50.0 + 14.0 * float(i % 4)) * _content_scale
	far.y += 30.0 * _content_scale
	var fly := _ct(drop)
	fly.tween_property(drop, "position", far, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.parallel().tween_property(drop, "modulate:a", 0.0, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_callback(drop.queue_free)

## BEAT 3 — the tub sails down the street and off the cliff, rocking.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	_sail_off()

func _sail_off() -> void:
	var start_tub := tub.position
	var edge := Vector2(_vp.x * CLIFF_X, _vp.y * GROUND_FRACTION - _vp.y * 0.06)
	var out := Vector2(_vp.x * (CLIFF_X + 0.10), _vp.y * 1.2)
	var flight := 0.7
	# Tub and rider share one parabola; Dribble stays seated in the tub.
	var tub_go := _ct()
	tub_go.tween_method(
		func(t: float) -> void:
			var pos := start_tub.lerp(out, t)
			pos.y -= sin(t * PI) * _vp.y * 0.20
			(tub as Node2D).position = pos,
		0.0, 1.0, flight
	)
	var drop_in := Vector2(0.0, -_vp.y * 0.085)
	var drip_go := _ct()
	drip_go.tween_method(
		func(t: float) -> void:
			var pos := (start_tub + drop_in).lerp(out + drop_in, t)
			pos.y -= sin(t * PI) * _vp.y * 0.20
			(dribble as Node2D).position = pos,
		0.0, 1.0, flight
	)
	# The tub rocks as it rolls down the street.
	var rock := _ct(tub).set_loops(6)
	rock.tween_property(tub, "rotation", 0.14, 0.06) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock.tween_property(tub, "rotation", -0.14, 0.06) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Gone over the edge: hide both.
	var gone := _ct()
	gone.tween_interval(flight)
	gone.tween_callback(func() -> void:
		tub.visible = false
		dribble.visible = false)
	# Wake: small puddle puffs left behind along the street.
	for i in range(4):
		var wake_at := Vector2(
			start_tub.x + (edge.x - start_tub.x) * (0.2 + 0.2 * float(i)),
			_vp.y * GROUND_FRACTION - 8.0 * _content_scale
		)
		var wake := Polygon2D.new()
		wake.polygon = Props._ellipse(16.0 * _content_scale, 6.0 * _content_scale, 10)
		wake.position = wake_at
		wake.color = Props.WATER_SOFT
		wake.z_index = 3
		world.add_child(wake)
		var fade := _ct(wake)
		fade.tween_interval(0.12 * float(i))
		fade.tween_property(wake, "modulate:a", 0.0, 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.tween_callback(wake.queue_free)
	# Flood sheet drains back as the tub leaves.
	var drain := _ct(flood)
	drain.tween_property(flood, "scale:y", _vp.y * 0.03, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Town watches him go, then waves.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.40 + 0.07 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(12.0, 0.24))
	var mayor_tw := _ct()
	mayor_tw.tween_interval(0.50)
	mayor_tw.tween_callback(mayor.hop.bind(12.0, 0.26))

