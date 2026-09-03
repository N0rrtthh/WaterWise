## CatchTheRain - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CatchTheRainIntro.tscn

extends MicrogameIntroBase

## Catch The Rain — CAUSE clip.
## res://scenes/ui/cutscenes/beats/CatchTheRainIntro.tscn
##
## BEAT 1  The camera pans down off a rolling storm front onto an EMPTY rain
##         drum; Dribble stands ready beside it, Mayor Ripple yells from the
##         side ("keep it clean!").
## BEAT 2  (flash-only impact) The first droplets break loose — Dribble clocks
##         that some of them are BROWN. That's the round: keep it clean.
## BEAT 3  The shower starts: clean drops plink into the drum while dirty ones
##         splat on the ground beside it. SNAP: whip-pan into gameplay.

const Props := preload("res://scripts/cutscenes/beats/CatchTheRainProps.gd")

var drum: Node2D
var cloud_bank: Node2D

func _setup_stage() -> void:
	_stage_townsfolk(3, _vp.x * 0.08, _vp.x * 0.24)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.80, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.42)
	drum = Props.make_drum(false)
	drum.name = "RainDrum"
	drum.position = Vector2(_vp.x * 0.56, _vp.y * GROUND_FRACTION)
	drum.scale = Vector2.ONE * _content_scale * 1.15
	drum.z_index = -1
	world.add_child(drum)
	_make_clouds()
	# Beat 1 starts high and tight on the storm front, then pans down.
	camera.zoom = Vector2(1.24, 1.24)
	camera.position = _vp * 0.5 + Vector2(0.0, -170.0) * _content_scale

## Storm front: a bank of grey clouds sliding in across the top of the frame.
func _make_clouds() -> void:
	cloud_bank = Node2D.new()
	cloud_bank.name = "CloudBank"
	cloud_bank.z_index = -4
	for i in range(4):
		var c := Props.make_cloud(1.0 + 0.25 * float(i % 2))
		c.position = Vector2(
			_vp.x * (0.12 + 0.26 * float(i)), _vp.y * (0.10 + 0.03 * float(i % 2))
		)
		cloud_bank.add_child(c)
	world.add_child(cloud_bank)

## BEAT 1 — the storm rolls in; cast settles; pan down onto the empty drum.
func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.drip_sweat()
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(cloud_bank, "position:x", -60.0 * _content_scale, _setup_sec()) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. First drop breaks loose; Dribble sees it.
func _on_impact() -> void:
	_impact_flash()
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.drip_sweat()
	_fall_drop(true, drum.position + Vector2(0.0, -86.0 * _content_scale), 0.0, _plink)

## BEAT 3 — the shower starts. Clean drops plink into the drum; dirty ones
## splat on the ground beside it. The mayor hammers the point home.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	for i in range(4):
		var delay := 0.05 + 0.09 * float(i)
		var target := drum.position \
			+ Vector2(randf_range(-14.0, 14.0), -86.0) * _content_scale
		_fall_drop(true, target, delay, _plink)
	# Dirty runoff misses — three brown splats ring the drum.
	for i in range(3):
		var side := -1.0 if i % 2 == 0 else 1.0
		var ground_y := _vp.y * GROUND_FRACTION
		var splat_at := Vector2(
			drum.position.x + side * (52.0 + 12.0 * float(i)) * _content_scale,
			ground_y - 2.0
		)
		_fall_drop(false, splat_at, 0.14 + 0.10 * float(i), _splat_down)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.10 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(26.0, 0.26))
	dribble.hop(34.0, 0.34)

## Spawns a droplet at cloud height and tweens it down to `target`; `land`
## decides what happens when it arrives (drum plink vs ground splat).
func _fall_drop(clean: bool, target: Vector2, delay: float, land: Callable) -> void:
	var drop := Props.make_droplet(clean, 1.1)
	drop.position = target + Vector2(0.0, -_vp.y * 0.34)
	drop.z_index = 10
	world.add_child(drop)
	var t := _ct()
	t.tween_interval(delay)
	t.tween_property(drop, "position", target, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(land.bind(drop))

## Clean drop lands in the drum: droplet vanishes, drum takes the plink.
func _plink(drop: Node2D) -> void:
	drop.queue_free()
	var t := _ct()
	t.tween_property(drum, "scale:y", drum.scale.y * 0.94, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(drum, "scale:y", drum.scale.y, 0.10) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Dirty drop lands on the ground: swap it for a lingering murk splat.
func _splat_down(drop: Node2D) -> void:
	var splat := Props.make_splat(1.0)
	splat.position = drop.position
	splat.scale = Vector2.ONE * _content_scale
	world.add_child(splat)
	drop.queue_free()
