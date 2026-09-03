## PlugTheLeak - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/PlugTheLeakLoseOutro.tscn

extends MicrogameOutroBase

## Plug The Leak — LOSE clip.
## res://scenes/ui/cutscenes/beats/PlugTheLeakLoseOutro.tscn
##
## BEAT 1  The town marches Dribble toward the last hole.
## BEAT 2  (impact) STUFFED: Dribble is wedged into the hole like a cork —
##         impact frame lands exactly on the stuffed pose.
## BEAT 3  The pipe fires him out like a champagne cork — pop, cork-bit
##         confetti, and off the cliff he goes.

const Props := preload("res://scripts/cutscenes/beats/PlugTheLeakProps.gd")

const CLIFF_X := 0.94

var pipe: Node2D
var hole: Polygon2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG_PALE
	_stage_townsfolk(3, _vp.x * 0.24, _vp.x * 0.42)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.34, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.50)
	pipe = Props.make_pipe(_vp.x * 0.22, [0.0])
	pipe.position = Vector2(_vp.x * 0.72, _vp.y * 0.44)
	pipe.z_index = 4
	world.add_child(pipe)
	hole = pipe.get_node("Hole0") as Polygon2D
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()
	_march_to_hole()

## BEAT 1 — the march. The town hustles Dribble to the hole; he arrives
## right as the impact tick lands.
func _march_to_hole() -> void:
	var hole_pos := pipe.position + hole.position.rotated(pipe.rotation)
	var start := dribble.position
	var end := hole_pos + Vector2(-30.0 * _content_scale, 10.0 * _content_scale)
	var march := _ct()
	march.tween_method(
		func(t: float) -> void:
			var pos := start.lerp(end, t)
			pos.y -= sin(t * PI) * 20.0 * _content_scale
			(dribble as Node2D).position = pos,
		0.0, 1.0, _setup_sec()
	)
	march.parallel().tween_property(dribble, "rotation", 0.3, _setup_sec())
	# Pushers lean in behind him.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_property(townsfolk[i], "position:x", start.x - 40.0 * _content_scale - 30.0 * float(i) * _content_scale, _setup_sec()) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## BEAT 2 — the stuffed pose. Impact frame lands exactly as Dribble is
## wedged into the hole, feet-first.
func _on_impact() -> void:
	super()
	# Wedge him in: sideways, half-inside, squashed like a good cork.
	dribble.rotation = PI * 0.5
	dribble.position = hole.position.rotated(pipe.rotation) + pipe.position \
		+ Vector2(-14.0 * _content_scale, 0.0)
	var wedge := _ct(dribble)
	wedge.tween_property(dribble, "scale", Vector2(1.15, 0.85) * _content_scale, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wedge.tween_property(dribble, "scale", Vector2.ONE * _content_scale, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dribble.set_expression(CartoonActor.Mood.DIZZY)
	# The hole goes red — straining.
	hole.color = Props.BAD_RED
	# Pushers brace and shove.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(12.0, 0.22))
	# Pressure builds: the pipe trembles.
	var tremble := _ct(pipe).set_loops(3)
	tremble.tween_property(pipe, "position:x", pipe.position.x + 2.0, 0.05)
	tremble.tween_property(pipe, "position:x", pipe.position.x - 2.0, 0.05)
	tremble.tween_property(pipe, "position:x", pipe.position.x, 0.05)

## BEAT 3 — POP. The pipe fires Dribble out like a champagne cork: cork-bit
## confetti at the mouth, then a spinning arc off the cliff.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	_pop_launch()

func _pop_launch() -> void:
	# Deferred impact stack at the pop (non-tick frame). super._on_impact()
	# delivers all of it -- flash, camera punch, stinger, burst -- so the explicit punch and
	# stinger that used to bracket this line were duplicates: two pool players on
	# the identical stinger stream in one frame (measured simul=2 in
	# tools/VerifyOutroImpact.tscn) and two tweens fighting over camera.zoom.
	super._on_impact()
	# Cork-bit confetti: tan chunks burst radially at the pipe mouth.
	var mouth := pipe.position + hole.position.rotated(pipe.rotation) \
		+ Vector2(20.0 * _content_scale, 0.0)
	for i in range(12):
		var bit := Polygon2D.new()
		bit.polygon = PackedVector2Array([
			Vector2(-3.0, -2.0), Vector2(3.0, -2.0), Vector2(4.0, 2.0), Vector2(-4.0, 2.0),
		])
		bit.position = mouth
		bit.color = Props.CORK if i % 2 == 0 else Props.CORK_DARK
		bit.rotation = TAU * float(i) / 12.0
		bit.z_index = 9
		world.add_child(bit)
		var a := TAU * float(i) / 12.0 - PI * 0.5
		var far := mouth + Vector2(cos(a), sin(a)) * (60.0 + 18.0 * float(i % 3)) * _content_scale
		var fly := _ct(bit)
		fly.tween_property(bit, "position", far, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(bit, "rotation", bit.rotation + 4.0, 0.30)
		fly.parallel().tween_property(bit, "modulate:a", 0.0, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_callback(bit.queue_free)
	# The launch: Dribble shoots right, spinning, arcs off the cliff.
	var start := dribble.position
	var out := Vector2(_vp.x * (CLIFF_X + 0.08), _vp.y * 1.15)
	var launch := _ct()
	launch.tween_method(
		func(t: float) -> void:
			var pos := start.lerp(out, t)
			pos.y -= sin(t * PI) * _vp.y * 0.22
			(dribble as Node2D).position = pos,
		0.0, 1.0, 0.55
	)
	launch.parallel().tween_property(dribble, "rotation", TAU * 2.5, 0.55)
	launch.tween_callback(func() -> void: dribble.visible = false)
	# Recoil: the pipe kicks back, then settles.
	var kick := _ct(pipe)
	kick.tween_property(pipe, "position:x", pipe.position.x - 14.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kick.tween_property(pipe, "position:x", pipe.position.x, 0.16) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Town + mayor watch him sail, then deadpan-wave.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.45 + 0.07 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(12.0, 0.24))
	var mayor_tw := _ct()
	mayor_tw.tween_interval(0.55)
	mayor_tw.tween_callback(mayor.hop.bind(12.0, 0.26))

