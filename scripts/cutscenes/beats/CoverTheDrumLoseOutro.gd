## CoverTheDrum - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CoverTheDrumLoseOutro.tscn

extends MicrogameOutroBase

## Cover The Drum — LOSE outro.
## res://scenes/ui/cutscenes/beats/CoverTheDrumLoseOutro.tscn
##
## BEAT 1  Dusk sky; open drums; the swarm has grown — five mosquitoes orbit
##         Dribble specifically; he sweats; the town watches, worried.
## BEAT 2  IMPACT — the swarm dives and lands ON Dribble.
## BEAT 3  They lift him the way ants carry a leaf — flat on their backs — and
##         buzz him up, across, and over the cliff while the town waves bye.

const Props := preload("res://scripts/cutscenes/beats/CoverTheDrumProps.gd")

const CLIFF_EDGE_X := 0.88

var drums: Array[Node2D] = []
var mosqs: Array = []
var carrier: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.DUSK_SKY
	world.get_node("Ground").color = Color(0.30, 0.34, 0.22)
	world.get_node("Dirt").color = Color(0.25, 0.20, 0.15)
	world.add_child(Props.make_stars(_vp, 14))
	_stage_townsfolk(3, _vp.x * 0.10, _vp.x * 0.26)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.78, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.58)
	for i in range(2):
		var d := Props.make_drum(_content_scale)
		d.position = Vector2(_vp.x * (0.32 + 0.14 * float(i)), _vp.y * GROUND_FRACTION)
		d.z_index = -1
		world.add_child(d)
		drums.append(d)
	_make_swarm()

## Five mosquitoes circling Dribble in a tightening double-orbit.
func _make_swarm() -> void:
	for i in range(5):
		var m := Props.make_mosquito(_content_scale * (0.85 + 0.15 * float(i % 2)))
		m.position = dribble.position + Vector2(0.0, -160.0) * _content_scale
		m.z_index = 12
		world.add_child(m)
		mosqs.append(m)
		_flap(m)
		_orbit(m, 0.2 * float(i), 60.0 * _content_scale)

func _flap(m: Node2D) -> void:
	for side in ["WingL", "WingR"]:
		var wing: Polygon2D = m.get_node(side)
		var rest := wing.position.y
		var flap := _ct(wing).set_loops()
		flap.tween_property(wing, "position:y", rest - 4.0, 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flap.tween_property(wing, "position:y", rest, 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _orbit(m: Node2D, phase: float, r: float) -> void:
	var base: Vector2 = m.position
	# Bound to the mosquito so the loop dies with it (never outlives the node).
	var orbit := _ct(m).set_loops()
	orbit.tween_method(func(t: float) -> void:
		var a := (t + phase) * TAU
		m.position = base + Vector2(cos(a) * r, sin(a) * r * 0.35)
	, 0.0, 1.0, 1.5)

## BEAT 1 — Dribble realises he is the target; the town winces.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	dribble.drip_sweat()
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
		t.drip_sweat()

func _impact_point() -> Vector2:
	return dribble.position + Vector2(0.0, -70.0) * _content_scale

## BEAT 2 — the swarm commits: every mosquito dives onto Dribble.
func _on_impact() -> void:
	super._on_impact()
	for i in range(mosqs.size()):
		var m: Node2D = mosqs[i]
		var dive := _ct()
		dive.tween_property(m, "position", _impact_point() \
			+ Vector2(-16.0 + 8.0 * float(i), 6.0 * float(i % 3)) * _content_scale, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## BEAT 3 — the ant-carry: a fresh carrying formation forms UNDER Dribble,
## he tips flat like a carried leaf, and the swarm hauls him up, across and
## over the cliff while the town waves goodbye.
func _beat_payoff() -> void:
	for m in mosqs:
		m.queue_free()
	mosqs.clear()
	dribble.set_expression(CartoonActor.Mood.DIZZY)
	mayor.set_expression(CartoonActor.Mood.SAD)
	_make_carrier()
	_lift()
	_wave_goodbye()

## The carrying swarm: five mosquitoes in the ant-formation under Dribble —
## three along the body line, two on the legs.
func _make_carrier() -> void:
	carrier = Node2D.new()
	carrier.name = "Carrier"
	carrier.position = dribble.position
	carrier.z_index = 12
	var offsets := [
		Vector2(-34.0, 26.0), Vector2(0.0, 32.0), Vector2(34.0, 26.0),
		Vector2(-16.0, 46.0), Vector2(18.0, 44.0),
	]
	for i in range(offsets.size()):
		var m := Props.make_mosquito(_content_scale * 0.9)
		m.position = offsets[i] * _content_scale
		carrier.add_child(m)
		_flap(m)
		m.scale = Vector2.ONE * 0.1
		var pop := _ct()
		pop.tween_property(m, "scale", Vector2.ONE * _content_scale * 0.9, 0.20) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	world.add_child(carrier)

## Dribble tips horizontal, rises into the formation, then the whole unit —
## carrier + Dribble moved by the SAME delta every frame — climbs, crosses
## the frame and slides over the cliff edge.
func _lift() -> void:
	var hover := dribble.position + Vector2(0.0, -50.0) * _content_scale
	var tip := _ct()
	tip.tween_property(dribble, "rig:rotation", -PI * 0.5, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var rise := _ct()
	rise.tween_property(dribble, "position", hover, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ground_y := _vp.y * GROUND_FRACTION
	var cruise := Vector2(_vp.x * 0.68, ground_y - 150.0 * _content_scale)
	var edge := Vector2(_vp.x * (CLIFF_EDGE_X - 0.02), ground_y - 170.0 * _content_scale)
	var over := Vector2(_vp.x * (CLIFF_EDGE_X + 0.10), ground_y + 120.0 * _content_scale)
	var move := _ct()
	move.tween_interval(0.32)
	move.tween_method(_carry_to, dribble.position, cruise, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_method(_carry_to, cruise, edge, 0.40) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_method(_carry_to, edge, over, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Moves Dribble and the carrying swarm by the same delta so the formation
## never detaches from its cargo.
func _carry_to(p: Vector2) -> void:
	var d := p - dribble.position
	dribble.position = p
	carrier.position += d

## The town waves the sad little procession off.
func _wave_goodbye() -> void:
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	var tw := _ct()
	tw.tween_interval(0.55)
	tw.tween_callback(mayor.hop.bind(28.0, 0.36))
	for i in range(townsfolk.size()):
		var wave := _ct()
		wave.tween_interval(0.65 + 0.14 * float(i))
		wave.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.UP))
		wave.tween_callback(townsfolk[i].hop.bind(22.0, 0.30))

