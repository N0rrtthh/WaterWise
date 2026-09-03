## FilterBuilder - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/FilterBuilderWinOutro.tscn

extends MicrogameOutroBase

## Filter Builder — WIN outro.
## res://scenes/ui/cutscenes/beats/FilterBuilderWinOutro.tscn
##
## BEAT 1  The filter is assembled on the table; the jug waits; the town
##         stands by with empty glasses.
## BEAT 2  IMPACT — crystal-clear water POURS out: the jug's muddy fill swaps
##         to clean on the impact frame, a shimmering stream fills the glass.
## BEAT 3  The town raises their glasses in a toast; a shimmer burst pops
##         over the table; Dribble toasts the mayor.

const Props := preload("res://scripts/cutscenes/beats/FilterBuilderProps.gd")

const HAND_DY := -42.0

var table: Node2D
var jug: Node2D
var target_glass: Node2D
var glasses: Array = []
var stream: Line2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	_stage_townsfolk(3, _vp.x * 0.08, _vp.x * 0.26)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.17, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.40)
	table = Props.make_table(220.0 * _content_scale)
	table.position = Vector2(_vp.x * 0.64, _vp.y * GROUND_FRACTION - 78.0 * _content_scale)
	table.z_index = -1
	world.add_child(table)
	jug = Props.make_jug(_content_scale * 1.2, true)
	jug.position = Vector2(_vp.x * 0.585, table.position.y + 2.0)
	jug.z_index = 1
	world.add_child(jug)
	var stack := Props.make_filter_stack(_content_scale)
	stack.position = Vector2(_vp.x * 0.66, table.position.y + 2.0)
	stack.z_index = 2
	world.add_child(stack)
	target_glass = Props.make_glass(_content_scale * 1.15)
	target_glass.position = Vector2(_vp.x * 0.715, table.position.y + 2.0)
	target_glass.z_index = 2
	world.add_child(target_glass)
	for member: CartoonActor in townsfolk:
		_give_glass(member, 1.0)
	_give_glass(mayor, CastFactory.MAYOR_SCALE.x)

func _give_glass(who: CartoonActor, scale_f: float) -> void:
	var g := Props.make_glass(_content_scale * scale_f)
	g.position = who.position \
		+ Vector2(24.0 * scale_f, HAND_DY * scale_f) * _content_scale
	g.z_index = 5
	world.add_child(g)
	glasses.append(g)

func _impact_point() -> Vector2:
	return target_glass.position + Vector2(0.0, -30.0) * target_glass.scale.y

## BEAT 1 — quiet before the pour.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()

## BEAT 2 — the pour. super() fires punch + flash + burst + stinger; on the
## frame the stream appears, the jug's muddy fill swaps CLEAN and the glass
## fills with a shimmering ribbon of clear water.
func _on_impact() -> void:
	super._on_impact()
	_clean_swap()
	_start_pour()
	_shimmer()

## The colour-clean swap: jug fill tweens muddy -> clean while a white
## shimmer passes over it — the "shader swap" impact frame.
func _clean_swap() -> void:
	var fill: Polygon2D = jug.get_node("Fill")
	var t := _ct(fill)
	t.tween_property(fill, "color", Props.CLEAN, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## The pour: a clean ribbon from the jug lip into the glass while the glass
## fill rises to full.
func _start_pour() -> void:
	var lip := jug.position + Vector2(-6.0, -60.0) * _content_scale
	var top := target_glass.position + Vector2(0.0, -30.0) * target_glass.scale.y
	stream = Line2D.new()
	stream.name = "PourStream"
	stream.points = PackedVector2Array([lip, top])
	stream.width = 6.0
	stream.default_color = Props.CLEAN
	stream.z_index = 8
	world.add_child(stream)
	# Stream wavers gently while pouring; bound to the stream.
	var flow := _ct(stream).set_loops()
	flow.tween_property(stream, "width", 7.5, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flow.tween_property(stream, "width", 6.0, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var fill: Polygon2D = target_glass.get_node("Fill")
	var rise := _ct(fill)
	rise.tween_property(fill, "scale:y", 1.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Sparkle shimmer drifting down the pour ribbon — the "crystal-clear" read.
func _shimmer() -> void:
	var p := GPUParticles2D.new()
	p.name = "Shimmer"
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.amount = 30
	p.lifetime = 0.8
	p.position = _impact_point() + Vector2(0.0, -60.0 * _content_scale)
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 18.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 160.0
	m.gravity = Vector3(0, 240, 0)
	m.color_initial_ramp = _ramp([
		Props.SHIMMER, Color(1, 1, 1), Props.CLEAN,
	])
	m.scale_min = 0.3
	m.scale_max = 0.7
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.0)
	safety.tween_callback(p.queue_free)

## BEAT 3 — the toast: every glass rises, the town cheers, Dribble and the
## mayor clink in the middle.
func _beat_payoff() -> void:
	_stop_stream()
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	for i in range(glasses.size()):
		var g: Node2D = glasses[i]
		var raise := _ct(g)
		raise.tween_interval(0.07 * float(i))
		raise.tween_property(g, "position:y", g.position.y - 40.0 * _content_scale, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.12 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(28.0, 0.32))
	mayor.hop(30.0, 0.36)
	dribble.hop(34.0, 0.34)

## The pour is done: fade the ribbon out and kill its loop.
func _stop_stream() -> void:
	if stream == null or not is_instance_valid(stream):
		return
	var out := _ct(stream)
	out.tween_property(stream, "modulate:a", 0.0, 0.20)
	out.tween_callback(stream.queue_free)

