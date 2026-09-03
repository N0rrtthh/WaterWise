## TracePipePath - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TracePipePathWinOutro.tscn

extends MicrogameOutroBase

## Trace Pipe Path — WIN clip.
## res://scenes/ui/cutscenes/beats/TracePipePathWinOutro.tscn
##
## BEAT 1  The connected pipe runs full; the fountain idles at a
##         trickle; the town settles into deck chairs with drinks.
## BEAT 2  (impact at the jet crown) THE FOUNTAIN SHOW — the water jets
##         triumphantly skyward, spray fans wide, droplets arc out.
## BEAT 3  The show settles into rhythm; the crowd leans back and
##         raises the drinks; the mayor toasts.

const Props := preload("res://scripts/cutscenes/beats/TracePipeProps.gd")

var pipes: Array = []
var fountain: Node2D
var drinks: Array = []
var sitters: Array = []
var jet_top: Vector2

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SITE
	var ground_y := _vp.y * GROUND_FRACTION
	var pipe_size := _vp.y * 0.24
	# The connected pipe, water running bright through it.
	for i in range(3):
		var pipe := Props.make_pipe_segment(pipe_size, false)
		pipe.position = Vector2(
			_vp.x * (0.30 + 0.12 * float(i)),
			ground_y - pipe_size * 0.11
		)
		pipe.z_index = 2
		(pipe.get_node("Flow") as Polygon2D).modulate.a = 1.0
		world.add_child(pipe)
		pipes.append(pipe)
	# The fountain waiting for its show.
	fountain = Props.make_fountain(_vp.y * 0.52)
	fountain.position = Vector2(_vp.x * 0.74, ground_y)
	fountain.z_index = 2
	world.add_child(fountain)
	jet_top = fountain.position + Vector2(0.0, -_vp.y * 0.52 * 0.86)
	# Deck chairs with drinks for the town.
	var chair_size := _vp.y * 0.30
	for i in range(2):
		var chair := Props.make_deck_chair(chair_size)
		chair.position = Vector2(_vp.x * (0.08 + 0.15 * float(i)), ground_y)
		chair.z_index = 1
		world.add_child(chair)
		var drink := Props.make_drink(_vp.y * 0.11)
		drink.position = Vector2(chair.position.x + chair_size * 0.42, ground_y)
		drink.z_index = 1
		world.add_child(drink)
		drinks.append(drink)
	# Dribble and the mayor take the chairs; folk stand behind.
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.08)
	dribble.position.y = ground_y - chair_size * 0.24
	sitters.append(dribble)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.23, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	mayor.position.y = ground_y - chair_size * 0.24
	sitters.append(mayor)
	_stage_townsfolk(2, _vp.x * 0.32, _vp.x * 0.40)
	camera.position = _vp * 0.5

## Impact frame: the crown of the jet, where the show blooms from.
func _impact_point() -> Vector2:
	return jet_top

## BEAT 1 — water shimmers through the pipe; the fountain idles.
func _beat_setup() -> void:
	for a in sitters:
		a.set_expression(CartoonActor.Mood.NEUTRAL)
		a.set_arm_pose(CartoonActor.ArmPose.REACH)
		a.start_idle()
	for t in townsfolk:
		t.start_idle()
	for pipe in pipes:
		var flow := pipe.get_node("Flow") as Polygon2D
		var shimmer := _ct(flow).set_loops(3)
		shimmer.tween_property(flow, "modulate:a", 0.55, 0.3)
		shimmer.tween_property(flow, "modulate:a", 1.0, 0.3)
	var jet := fountain.get_node("Jet") as Node2D
	jet.scale = Vector2(0.3, 0.3)
	var trickle := _ct(jet).set_loops(3)
	trickle.tween_property(jet, "scale", Vector2(0.38, 0.38), 0.3)
	trickle.tween_property(jet, "scale", Vector2(0.3, 0.3), 0.3)

## BEAT 2 — THE FOUNTAIN SHOW: jet detonates skyward, spray fans wide,
## droplets arc out of the crown.
func _on_impact() -> void:
	super._on_impact()
	var jet := fountain.get_node("Jet") as Node2D
	var burst := _ct(jet) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst.tween_property(jet, "scale", Vector2(1.3, 1.3), 0.25)
	for i in range(3):
		var spray := jet.get_node("Spray%d" % i) as Polygon2D
		var fan := _ct(spray).set_parallel(true)
		fan.tween_property(spray, "modulate:a", 1.0, 0.18)
		fan.tween_property(spray, "rotation",
			spray.rotation + (0.22 - 0.22 * float(i)), 0.4)
	for i in range(8):
		_spawn_drop(_vp.y * 0.012,
			-PI * 0.5 + (-0.9 + 0.26 * float(i)), _vp.x * (0.10 + 0.02 * float(i % 3)))
	# The crowd freezes mid-sip, then stares.
	for a in sitters:
		a.set_expression(CartoonActor.Mood.SHOCKED)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)

## One arcing water droplet from the jet crown; self-frees.
func _spawn_drop(drop_size: float, ang: float, dist: float) -> void:
	var drop := Polygon2D.new()
	drop.polygon = Props.ellipse(drop_size, drop_size, 8)
	drop.color = Props.WATER
	drop.position = jet_top
	drop.z_index = 6
	world.add_child(drop)
	var tw := _ct(drop)
	tw.tween_property(drop, "position",
		jet_top + Vector2(cos(ang), sin(ang)) * dist * 0.7
			+ Vector2(0.0, -_vp.y * 0.08), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(drop, "position",
		jet_top + Vector2(cos(ang), sin(ang)) * dist
			+ Vector2(0.0, _vp.y * 0.02), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(drop, "modulate:a", 0.0, 0.3)
	tw.tween_callback(drop.queue_free)

## BEAT 3 — the show settles into rhythm; drinks go up.
func _beat_payoff() -> void:
	var jet := fountain.get_node("Jet") as Node2D
	var pulse := _ct(jet).set_loops(2)
	pulse.tween_property(jet, "scale", Vector2(1.1, 1.1), 0.35)
	pulse.tween_property(jet, "scale", Vector2(1.25, 1.25), 0.35)
	for i in range(3):
		var spray := jet.get_node("Spray%d" % i) as Polygon2D
		var wiggle := _ct(spray).set_loops(2)
		wiggle.tween_property(spray, "rotation", spray.rotation - 0.12, 0.3)
		wiggle.tween_property(spray, "rotation", spray.rotation + 0.12, 0.3)
	for i in range(4):
		_spawn_drop(_vp.y * 0.010, -PI * 0.5 + (-0.5 + 0.33 * float(i)), _vp.x * 0.12)
	for a: CartoonActor in sitters:
		a.set_expression(CartoonActor.Mood.HAPPY)
		var lean := _ct(a)
		lean.tween_property(a, "rotation", -0.15, 0.3)
	for drink in drinks:
		var sip := _ct(drink as Node2D).set_parallel(true)
		sip.tween_property(drink, "position:y",
			(drink as Node2D).position.y - _vp.y * 0.06, 0.25)
		sip.tween_property(drink, "rotation", -0.3, 0.25)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.SMUG)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
