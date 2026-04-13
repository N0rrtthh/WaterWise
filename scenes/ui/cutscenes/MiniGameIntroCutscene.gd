extends Control

signal cutscene_finished

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Center/VBox/Title
@onready var subtitle_label: Label = $Panel/Center/VBox/Subtitle
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var icon_label: Label
var streak_back: ColorRect
var streak_front: ColorRect
var flash_beat: ColorRect
var _particles: Array[Node] = []
var _water_droplet: Node2D = null

var anim_options: Dictionary = {
	"speed": 1.0,
	"distance": 1.0,
	"pop": 1.0
}
var _current_game_key: String = ""

func _ready() -> void:
	_ensure_cinematic_nodes()
	_rebuild_animation()

func configure(
	title: String,
	subtitle: String = "Get ready...",
	options: Dictionary = {}
) -> void:
	_ensure_cinematic_nodes()
	_current_game_key = title
	title_label.text = _prettify_title(title)
	subtitle_label.text = _get_game_instruction(title)
	if icon_label:
		icon_label.text = _get_intro_icon_for_title(title)

	# Set a thematic overlay color per game category
	var theme_color = _get_theme_color_for_title(title)
	overlay.color = Color(theme_color.r, theme_color.g, theme_color.b, 0.88)

	for key in options.keys():
		anim_options[key] = options[key]
	_rebuild_animation()

func play_cutscene() -> void:
	if AudioManager:
		AudioManager.play_game_start()
		AudioManager.play_music("cutscene", 0.3)
	if not animation_player.has_animation("intro"):
		_rebuild_animation()

	# Spawn animated mascot with game-specific scene
	_spawn_water_droplet()

	if animation_player.has_animation("intro"):
		animation_player.play("intro")
		_run_intro_vfx()
		await animation_player.animation_finished
	else:
		_run_intro_vfx()
		await get_tree().create_timer(4.0).timeout

	_cleanup_vfx()
	cutscene_finished.emit()

func _spawn_water_droplet() -> void:
	var vp = get_viewport_rect().size
	_water_droplet = Node2D.new()
	_water_droplet.position = Vector2(vp.x * 0.5, vp.y * 0.48)
	_water_droplet.scale = Vector2.ZERO
	_water_droplet.modulate.a = 0.0
	add_child(_water_droplet)

	# Build the base character (always present)
	_build_base_character(_water_droplet)

	# Add game-specific props and context items
	_add_game_props(_water_droplet, _current_game_key)

func _build_base_character(parent: Node2D) -> void:
	# ── Chubby round body (DWTD-style bean person) ──
	var body = Polygon2D.new()
	body.name = "Body"
	var body_pts = PackedVector2Array()
	for i in range(20):
		var a = i * TAU / 20
		var rx = 30.0 + sin(a * 2) * 4  # Slightly blobby
		var ry = 38.0 + cos(a * 3) * 3
		body_pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	body.polygon = body_pts
	body.color = Color(0.35, 0.75, 1.0)
	parent.add_child(body)

	# ── Shine ──
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-10, -22), Vector2(-3, -26), Vector2(4, -22), Vector2(-3, -15),
	])
	shine.color = Color(1, 1, 1, 0.55)
	parent.add_child(shine)

	# ── BIG googly eyes (oversized, expressive) ──
	for xoff in [-12, 12]:
		var eye = Polygon2D.new()
		eye.name = "Eye_L" if xoff < 0 else "Eye_R"
		var ep = PackedVector2Array()
		for i in range(16):
			var a = i * TAU / 16
			ep.append(Vector2(cos(a) * 11, sin(a) * 11) + Vector2(xoff, -8))
		eye.polygon = ep
		eye.color = Color.WHITE
		parent.add_child(eye)

		var pupil = Polygon2D.new()
		pupil.name = "Pupil_L" if xoff < 0 else "Pupil_R"
		var pp = PackedVector2Array()
		for i in range(12):
			var a = i * TAU / 12
			pp.append(Vector2(cos(a) * 5.5, sin(a) * 5.5) + Vector2(xoff, -6))
		pupil.polygon = pp
		pupil.color = Color(0.08, 0.08, 0.08)
		parent.add_child(pupil)

		# Sparkle
		var sparkle = Polygon2D.new()
		var sp = PackedVector2Array()
		for i in range(4):
			var a = i * TAU / 4
			var r = 2.5 if i % 2 == 0 else 1.2
			sp.append(Vector2(cos(a) * r, sin(a) * r) + Vector2(xoff - 3, -11))
		sparkle.polygon = sp
		sparkle.color = Color.WHITE
		parent.add_child(sparkle)

	# ── Big happy grin ──
	var mouth = Line2D.new()
	mouth.name = "Mouth"
	mouth.width = 3.0
	mouth.default_color = Color(0.1, 0.1, 0.1)
	for i in range(9):
		var t = float(i) / 8.0
		var x = lerp(-16.0, 16.0, t)
		var y = 10.0 + sin(t * PI) * 12.0
		mouth.add_point(Vector2(x, y))
	parent.add_child(mouth)

	# ── Tongue ──
	var tongue = Polygon2D.new()
	tongue.name = "Tongue"
	tongue.polygon = PackedVector2Array([
		Vector2(-4, 18), Vector2(4, 18), Vector2(5, 25),
		Vector2(2, 28), Vector2(-2, 28), Vector2(-5, 25),
	])
	tongue.color = Color(1.0, 0.45, 0.5)
	parent.add_child(tongue)

	# ── Noodly arms ──
	var left_arm = Line2D.new()
	left_arm.name = "LeftArm"
	left_arm.width = 5.0
	left_arm.default_color = Color(0.3, 0.68, 0.95)
	left_arm.add_point(Vector2(-28, 2))
	left_arm.add_point(Vector2(-44, -12))
	left_arm.add_point(Vector2(-50, -28))
	left_arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
	left_arm.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(left_arm)

	var right_arm = Line2D.new()
	right_arm.name = "RightArm"
	right_arm.width = 5.0
	right_arm.default_color = Color(0.3, 0.68, 0.95)
	right_arm.add_point(Vector2(28, 2))
	right_arm.add_point(Vector2(44, -12))
	right_arm.add_point(Vector2(50, -28))
	right_arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
	right_arm.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(right_arm)

	# ── Stubby legs ──
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.name = "Leg_L" if side < 0 else "Leg_R"
		leg.width = 5.0
		leg.default_color = Color(0.28, 0.62, 0.9)
		leg.add_point(Vector2(side * 10, 36))
		leg.add_point(Vector2(side * 12, 50))
		leg.add_point(Vector2(side * 16, 54))
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		parent.add_child(leg)

	# ── Rosy blush cheeks ──
	for sx in [-22, 22]:
		var blush = Polygon2D.new()
		var bp = PackedVector2Array()
		for i in range(10):
			var a = i * TAU / 10
			bp.append(Vector2(cos(a) * 6, sin(a) * 4) + Vector2(sx, 6))
		blush.polygon = bp
		blush.color = Color(1, 0.45, 0.55, 0.28)
		parent.add_child(blush)

func _add_game_props(parent: Node2D, game_key: String) -> void:
	# Each game gets unique props that tell a visual story
	match game_key:
		"WringItOut":
			# Wet t-shirt dangling from right hand
			_add_prop_cloth(parent, Vector2(48, -20), Color(0.9, 0.3, 0.3))
			# Laundry basket on the side
			_add_prop_basket(parent, Vector2(55, 40))
			# Water drops dripping from cloth
			_add_prop_drips(parent, Vector2(50, -8), 3)
		"CatchTheRain":
			# Holding a bucket up high with both hands
			_add_prop_bucket(parent, Vector2(0, -48), Color(0.6, 0.4, 0.2))
			# Rain cloud above
			_add_prop_cloud(parent, Vector2(0, -85), Color(0.6, 0.65, 0.72))
			# Raindrops falling
			_add_prop_rain(parent, Vector2(0, -70), 5)
		"FixLeak", "PlugTheLeak":
			# Wrench in right hand
			_add_prop_wrench(parent, Vector2(50, -15))
			# Leaking pipe on the side
			_add_prop_pipe(parent, Vector2(-60, 10), true)
			# Water spraying from leak
			_add_prop_spray(parent, Vector2(-50, 5))
		"FilterBuilder":
			# Filter layers stacked beside character
			_add_prop_filter_stack(parent, Vector2(55, 10))
			# Beaker in hand
			_add_prop_beaker(parent, Vector2(-50, -15))
		"QuickShower":
			# Shower head above with water
			_add_prop_showerhead(parent, Vector2(0, -80))
			# Towel draped on arm
			_add_prop_towel(parent, Vector2(-45, 0), Color(1, 1, 0.8))
			# Timer/clock floating
			_add_prop_clock(parent, Vector2(55, -30))
		"CoverTheDrum":
			# Big water drum/barrel
			_add_prop_drum(parent, Vector2(50, 15))
			# Lid in hand, about to cover
			_add_prop_lid(parent, Vector2(30, -35))
			# Bugs/leaves trying to get in
			_add_prop_bugs(parent, Vector2(60, -10))
		"RiceWashRescue":
			# Bowl of rice in hand
			_add_prop_bowl(parent, Vector2(-48, -10), Color(1, 0.95, 0.85))
			# Water jug on side
			_add_prop_jug(parent, Vector2(50, 20))
			# Rice grains scattered
			_add_prop_rice_grains(parent, Vector2(0, 35))
		"VegetableBath":
			# Bowl of vegetables
			_add_prop_bowl(parent, Vector2(-50, -5), Color(0.4, 0.85, 0.3))
			# Faucet with controlled stream
			_add_prop_faucet(parent, Vector2(50, -25))
			# Veggie items floating
			_add_prop_veggies(parent, Vector2(-45, -15))
		"GreywaterSorter":
			# Two buckets: clean + dirty
			_add_prop_bucket(parent, Vector2(-55, 30), Color(0.3, 0.8, 0.4))
			_add_prop_bucket(parent, Vector2(55, 30), Color(0.7, 0.4, 0.3))
			# Sorting arrows
			_add_prop_arrows(parent, Vector2(0, 15))
		"ThirstyPlant":
			# Wilting plant beside character
			_add_prop_plant(parent, Vector2(55, 15), false)
			# Watering can in hand
			_add_prop_watering_can(parent, Vector2(-45, -15))
		"MudPieMaker":
			# Mud bowl
			_add_prop_bowl(parent, Vector2(50, 10), Color(0.5, 0.35, 0.2))
			# Water measuring cup
			_add_prop_measuring_cup(parent, Vector2(-48, -10))
			# Mud splatter
			_add_prop_mud_splats(parent)
		"SpotTheSpeck":
			# Magnifying glass in hand
			_add_prop_magnifier(parent, Vector2(45, -18))
			# Water glass with specks
			_add_prop_water_glass(parent, Vector2(-50, 5))
		"WaterPlant":
			# Happy plant
			_add_prop_plant(parent, Vector2(55, 15), true)
			# Hose in hand
			_add_prop_hose(parent, Vector2(-45, -5))
		"SwipeTheSoap":
			# Soap bar in hand (slippery!)
			_add_prop_soap(parent, Vector2(45, -20))
			# Sink faucet
			_add_prop_faucet(parent, Vector2(-50, -25))
			# Bubbles floating
			_add_prop_bubbles(parent, Vector2(0, -40), 5)
		"ToiletTankFix":
			# Toilet tank outline
			_add_prop_toilet(parent, Vector2(55, 10))
			# Wrench in hand
			_add_prop_wrench(parent, Vector2(-45, -15))
		"TracePipePath":
			# Map/blueprint in hand
			_add_prop_map(parent, Vector2(-48, -10))
			# Pipe segments on ground
			_add_prop_pipe_segments(parent, Vector2(40, 25))
		"ScrubToSave":
			# Sponge in hand
			_add_prop_sponge(parent, Vector2(45, -15))
			# Dirty plate
			_add_prop_plate(parent, Vector2(-50, 5))
			# Small water stream (not a flood)
			_add_prop_drips(parent, Vector2(-40, -15), 2)
		"BucketBrigade":
			# Bucket in each hand, running pose
			_add_prop_bucket(parent, Vector2(-48, -10), Color(0.5, 0.5, 0.8))
			_add_prop_bucket(parent, Vector2(48, -10), Color(0.5, 0.5, 0.8))
			# More buckets in line behind
			_add_prop_bucket_line(parent, Vector2(0, 45))
		"TimingTap":
			# Musical notes floating
			_add_prop_music_notes(parent, Vector2(0, -55))
			# Tap/faucet
			_add_prop_faucet(parent, Vector2(50, -10))
		"TurnOffTap":
			# Running faucet with water gushing
			_add_prop_faucet(parent, Vector2(50, -15))
			# Hand reaching for tap
			_add_prop_reaching_hand(parent, Vector2(35, -25))
			# Water puddle growing
			_add_prop_puddle(parent, Vector2(45, 40))
		"RainwaterHarvesting":
			# Rain cloud + collection system
			_add_prop_cloud(parent, Vector2(0, -85), Color(0.5, 0.55, 0.65))
			_add_prop_rain(parent, Vector2(0, -70), 4)
			_add_prop_barrel(parent, Vector2(50, 20))
		_:
			# Fallback — generic water theme
			_add_prop_bucket(parent, Vector2(48, -10), Color(0.5, 0.7, 0.9))
			_add_prop_drips(parent, Vector2(48, 0), 2)

# ═══════════════════════════════════════════════════════════════
# PROP BUILDERS — Each creates a recognizable mini-object
# ═══════════════════════════════════════════════════════════════

func _add_prop_cloth(parent: Node2D, pos: Vector2, col: Color) -> void:
	var cloth = Polygon2D.new()
	cloth.name = "Cloth"
	cloth.polygon = PackedVector2Array([
		Vector2(-8, -12), Vector2(8, -12), Vector2(10, -4),
		Vector2(12, 8), Vector2(6, 16), Vector2(-2, 18),
		Vector2(-10, 14), Vector2(-12, 4),
	])
	cloth.color = col
	cloth.position = pos
	parent.add_child(cloth)
	# Collar detail
	var collar = Line2D.new()
	collar.width = 2.0
	collar.default_color = col.darkened(0.2)
	collar.add_point(Vector2(-6, -10) + pos)
	collar.add_point(Vector2(0, -8) + pos)
	collar.add_point(Vector2(6, -10) + pos)
	parent.add_child(collar)

func _add_prop_basket(parent: Node2D, pos: Vector2) -> void:
	var basket = Polygon2D.new()
	basket.polygon = PackedVector2Array([
		Vector2(-15, -8), Vector2(15, -8), Vector2(12, 8),
		Vector2(-12, 8),
	])
	basket.color = Color(0.6, 0.45, 0.25)
	basket.position = pos
	parent.add_child(basket)
	# Basket weave lines
	for i in range(3):
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = Color(0.5, 0.35, 0.18)
		var y = -4 + i * 4
		line.add_point(Vector2(-13, y) + pos)
		line.add_point(Vector2(13, y) + pos)
		parent.add_child(line)

func _add_prop_drips(parent: Node2D, pos: Vector2, count: int) -> void:
	for i in count:
		var drip = Polygon2D.new()
		drip.name = "Drip_%d" % i
		drip.polygon = PackedVector2Array([
			Vector2(0, -3), Vector2(2, 0), Vector2(1.5, 3),
			Vector2(0, 4.5), Vector2(-1.5, 3), Vector2(-2, 0),
		])
		drip.color = Color(0.4, 0.7, 1.0, 0.7)
		drip.position = pos + Vector2(randf_range(-8, 8), i * 8)
		parent.add_child(drip)

func _add_prop_bucket(parent: Node2D, pos: Vector2, col: Color) -> void:
	var bucket = Polygon2D.new()
	bucket.polygon = PackedVector2Array([
		Vector2(-12, -10), Vector2(12, -10), Vector2(10, 10),
		Vector2(-10, 10),
	])
	bucket.color = col
	bucket.position = pos
	parent.add_child(bucket)
	# Handle
	var handle = Line2D.new()
	handle.width = 2.0
	handle.default_color = Color(0.4, 0.4, 0.4)
	handle.add_point(Vector2(-10, -10) + pos)
	handle.add_point(Vector2(0, -18) + pos)
	handle.add_point(Vector2(10, -10) + pos)
	parent.add_child(handle)

func _add_prop_cloud(parent: Node2D, pos: Vector2, col: Color) -> void:
	var cloud = Polygon2D.new()
	cloud.name = "Cloud"
	var cp = PackedVector2Array()
	# Bumpy cloud shape
	for i in range(16):
		var a = i * TAU / 16
		var r = 22.0 + sin(a * 3) * 8 + cos(a * 5) * 4
		cp.append(Vector2(cos(a) * r, sin(a) * r * 0.6) + pos)
	cloud.polygon = cp
	cloud.color = col
	parent.add_child(cloud)

func _add_prop_rain(parent: Node2D, pos: Vector2, count: int) -> void:
	for i in count:
		var drop = Line2D.new()
		drop.name = "Rain_%d" % i
		drop.width = 2.0
		drop.default_color = Color(0.5, 0.75, 1.0, 0.6)
		var x = pos.x + randf_range(-25, 25)
		var y = pos.y + randf_range(0, 20)
		drop.add_point(Vector2(x, y))
		drop.add_point(Vector2(x - 1, y + 10))
		parent.add_child(drop)

func _add_prop_wrench(parent: Node2D, pos: Vector2) -> void:
	var wrench = Polygon2D.new()
	wrench.name = "Wrench"
	wrench.polygon = PackedVector2Array([
		Vector2(-2, -16), Vector2(2, -16), Vector2(3, -4),
		Vector2(6, -2), Vector2(6, 4), Vector2(3, 6),
		Vector2(-3, 6), Vector2(-6, 4), Vector2(-6, -2),
		Vector2(-3, -4),
	])
	wrench.color = Color(0.7, 0.7, 0.75)
	wrench.position = pos
	parent.add_child(wrench)

func _add_prop_pipe(parent: Node2D, pos: Vector2, leaking: bool) -> void:
	var pipe = Line2D.new()
	pipe.name = "Pipe"
	pipe.width = 8.0
	pipe.default_color = Color(0.5, 0.5, 0.55)
	pipe.add_point(pos + Vector2(-20, 0))
	pipe.add_point(pos)
	pipe.add_point(pos + Vector2(0, 25))
	parent.add_child(pipe)
	if leaking:
		_add_prop_spray(parent, pos + Vector2(0, 8))

func _add_prop_spray(parent: Node2D, pos: Vector2) -> void:
	for i in 3:
		var sp = Line2D.new()
		sp.name = "Spray_%d" % i
		sp.width = 1.5
		sp.default_color = Color(0.4, 0.7, 1.0, 0.6)
		var angle = randf_range(-0.5, 0.5)
		sp.add_point(pos)
		sp.add_point(pos + Vector2(cos(angle) * 12, sin(angle) * 12 - 5))
		parent.add_child(sp)

func _add_prop_filter_stack(parent: Node2D, pos: Vector2) -> void:
	var colors = [Color(0.85, 0.75, 0.5), Color(0.5, 0.5, 0.5), Color(0.3, 0.3, 0.35)]
	for i in 3:
		var layer = Polygon2D.new()
		layer.polygon = PackedVector2Array([
			Vector2(-10, -3), Vector2(10, -3), Vector2(10, 3), Vector2(-10, 3),
		])
		layer.color = colors[i]
		layer.position = pos + Vector2(0, i * 8 - 8)
		parent.add_child(layer)

func _add_prop_beaker(parent: Node2D, pos: Vector2) -> void:
	var beaker = Polygon2D.new()
	beaker.polygon = PackedVector2Array([
		Vector2(-6, -12), Vector2(6, -12), Vector2(8, 10),
		Vector2(-8, 10),
	])
	beaker.color = Color(0.7, 0.85, 1.0, 0.6)
	beaker.position = pos
	parent.add_child(beaker)
	# Water inside
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(7, 10), Vector2(-7, 10),
	])
	water.color = Color(0.3, 0.6, 1.0, 0.5)
	water.position = pos
	parent.add_child(water)

func _add_prop_showerhead(parent: Node2D, pos: Vector2) -> void:
	# Shower head
	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-10, -4), Vector2(10, -4), Vector2(8, 4), Vector2(-8, 4),
	])
	head.color = Color(0.75, 0.75, 0.8)
	head.position = pos
	parent.add_child(head)
	# Pipe going up
	var pipe = Line2D.new()
	pipe.width = 4.0
	pipe.default_color = Color(0.6, 0.6, 0.65)
	pipe.add_point(pos + Vector2(0, -4))
	pipe.add_point(pos + Vector2(0, -20))
	pipe.add_point(pos + Vector2(15, -20))
	parent.add_child(pipe)
	# Water streams
	for i in 4:
		var stream = Line2D.new()
		stream.name = "ShowerStream_%d" % i
		stream.width = 1.5
		stream.default_color = Color(0.5, 0.75, 1.0, 0.5)
		var x = pos.x - 6 + i * 4
		stream.add_point(Vector2(x, pos.y + 4))
		stream.add_point(Vector2(x, pos.y + 22))
		parent.add_child(stream)

func _add_prop_towel(parent: Node2D, pos: Vector2, col: Color) -> void:
	var towel = Polygon2D.new()
	towel.polygon = PackedVector2Array([
		Vector2(-4, -10), Vector2(4, -10), Vector2(6, 10),
		Vector2(8, 18), Vector2(-2, 20), Vector2(-6, 10),
	])
	towel.color = col
	towel.position = pos
	parent.add_child(towel)

func _add_prop_clock(parent: Node2D, pos: Vector2) -> void:
	# Clock face
	var face = Polygon2D.new()
	var fp = PackedVector2Array()
	for i in range(12):
		var a = i * TAU / 12
		fp.append(Vector2(cos(a) * 12, sin(a) * 12) + pos)
	face.polygon = fp
	face.color = Color(1, 1, 0.9)
	parent.add_child(face)
	# Hands
	var hand1 = Line2D.new()
	hand1.width = 2.0
	hand1.default_color = Color.BLACK
	hand1.add_point(pos)
	hand1.add_point(pos + Vector2(0, -9))
	parent.add_child(hand1)
	var hand2 = Line2D.new()
	hand2.width = 1.5
	hand2.default_color = Color(0.8, 0.1, 0.1)
	hand2.add_point(pos)
	hand2.add_point(pos + Vector2(7, -4))
	parent.add_child(hand2)

func _add_prop_drum(parent: Node2D, pos: Vector2) -> void:
	var drum = Polygon2D.new()
	drum.polygon = PackedVector2Array([
		Vector2(-16, -18), Vector2(16, -18), Vector2(14, 18),
		Vector2(-14, 18),
	])
	drum.color = Color(0.3, 0.35, 0.5)
	drum.position = pos
	parent.add_child(drum)
	# Water inside
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-13, -5), Vector2(13, -5), Vector2(12, 16), Vector2(-12, 16),
	])
	water.color = Color(0.3, 0.55, 0.85, 0.6)
	water.position = pos
	parent.add_child(water)

func _add_prop_lid(parent: Node2D, pos: Vector2) -> void:
	var lid = Polygon2D.new()
	lid.name = "Lid"
	lid.polygon = PackedVector2Array([
		Vector2(-18, -3), Vector2(18, -3), Vector2(16, 3), Vector2(-16, 3),
	])
	lid.color = Color(0.4, 0.42, 0.55)
	lid.position = pos
	lid.rotation = -0.3
	parent.add_child(lid)

func _add_prop_bugs(parent: Node2D, pos: Vector2) -> void:
	for i in 2:
		var bug = Label.new()
		bug.name = "Bug_%d" % i
		bug.text = ["🦟", "🍂"][i]
		bug.add_theme_font_size_override("font_size", 14)
		bug.position = pos + Vector2(i * 15 - 8, i * 10 - 5)
		parent.add_child(bug)

func _add_prop_bowl(parent: Node2D, pos: Vector2, col: Color) -> void:
	var bowl = Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-14, -4), Vector2(14, -4), Vector2(10, 10),
		Vector2(-10, 10),
	])
	bowl.color = col
	bowl.position = pos
	parent.add_child(bowl)
	# Bowl rim
	var rim = Line2D.new()
	rim.width = 2.0
	rim.default_color = col.darkened(0.15)
	rim.add_point(pos + Vector2(-14, -4))
	rim.add_point(pos + Vector2(14, -4))
	parent.add_child(rim)

func _add_prop_jug(parent: Node2D, pos: Vector2) -> void:
	var jug = Polygon2D.new()
	jug.polygon = PackedVector2Array([
		Vector2(-6, -14), Vector2(6, -14), Vector2(8, 12),
		Vector2(-8, 12),
	])
	jug.color = Color(0.6, 0.45, 0.3)
	jug.position = pos
	parent.add_child(jug)
	# Handle
	var handle = Line2D.new()
	handle.width = 2.5
	handle.default_color = Color(0.5, 0.38, 0.25)
	handle.add_point(pos + Vector2(8, -8))
	handle.add_point(pos + Vector2(14, 0))
	handle.add_point(pos + Vector2(8, 6))
	parent.add_child(handle)

func _add_prop_rice_grains(parent: Node2D, pos: Vector2) -> void:
	for i in 5:
		var grain = Polygon2D.new()
		grain.polygon = PackedVector2Array([
			Vector2(-1.5, -3), Vector2(1.5, -3), Vector2(1, 3), Vector2(-1, 3),
		])
		grain.color = Color(1, 0.95, 0.85)
		grain.position = pos + Vector2(randf_range(-20, 20), randf_range(-5, 5))
		grain.rotation = randf_range(0, TAU)
		parent.add_child(grain)

func _add_prop_faucet(parent: Node2D, pos: Vector2) -> void:
	# Faucet body
	var faucet = Polygon2D.new()
	faucet.polygon = PackedVector2Array([
		Vector2(-4, -8), Vector2(4, -8), Vector2(4, 0),
		Vector2(12, 0), Vector2(12, 4), Vector2(-4, 4),
	])
	faucet.color = Color(0.7, 0.7, 0.75)
	faucet.position = pos
	parent.add_child(faucet)
	# Knob
	var knob = Polygon2D.new()
	var kp = PackedVector2Array()
	for i in range(8):
		var a = i * TAU / 8
		kp.append(Vector2(cos(a) * 4, sin(a) * 4) + pos + Vector2(0, -12))
	knob.polygon = kp
	knob.color = Color(0.4, 0.6, 0.8)
	parent.add_child(knob)

func _add_prop_veggies(parent: Node2D, pos: Vector2) -> void:
	var emoji = ["🥕", "🥬", "🍅"]
	for i in 3:
		var v = Label.new()
		v.text = emoji[i]
		v.add_theme_font_size_override("font_size", 14)
		v.position = pos + Vector2(i * 10 - 10, randf_range(-6, 6))
		parent.add_child(v)

func _add_prop_plant(parent: Node2D, pos: Vector2, healthy: bool) -> void:
	# Pot
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0), Vector2(8, 14), Vector2(-8, 14),
	])
	pot.color = Color(0.65, 0.35, 0.2)
	pot.position = pos
	parent.add_child(pot)
	# Stem
	var stem = Line2D.new()
	stem.width = 3.0
	stem.default_color = Color(0.3, 0.7, 0.2) if healthy else Color(0.5, 0.45, 0.2)
	stem.add_point(pos + Vector2(0, 0))
	stem.add_point(pos + Vector2(0, -18))
	parent.add_child(stem)
	# Leaves
	for side in [-1, 1]:
		var leaf = Polygon2D.new()
		leaf.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(side * 8, -4), Vector2(side * 10, -8),
			Vector2(side * 6, -10), Vector2(0, -6),
		])
		leaf.color = Color(0.2, 0.8, 0.3) if healthy else Color(0.6, 0.5, 0.2)
		leaf.position = pos + Vector2(0, -12)
		if not healthy:
			leaf.rotation = side * 0.4  # Wilting
		parent.add_child(leaf)

func _add_prop_watering_can(parent: Node2D, pos: Vector2) -> void:
	var can = Polygon2D.new()
	can.polygon = PackedVector2Array([
		Vector2(-8, -6), Vector2(8, -6), Vector2(10, 8),
		Vector2(16, -2), Vector2(18, 0), Vector2(12, 10),
		Vector2(-10, 10),
	])
	can.color = Color(0.3, 0.7, 0.4)
	can.position = pos
	parent.add_child(can)

func _add_prop_measuring_cup(parent: Node2D, pos: Vector2) -> void:
	var cup = Polygon2D.new()
	cup.polygon = PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(7, 8), Vector2(-7, 8),
	])
	cup.color = Color(0.8, 0.85, 0.9, 0.7)
	cup.position = pos
	parent.add_child(cup)
	# Measurement lines
	for i in 3:
		var ml = Line2D.new()
		ml.width = 1.0
		ml.default_color = Color(0.3, 0.3, 0.3, 0.5)
		var y = -6 + i * 4
		ml.add_point(pos + Vector2(5, y))
		ml.add_point(pos + Vector2(7, y))
		parent.add_child(ml)

func _add_prop_mud_splats(parent: Node2D) -> void:
	for i in 3:
		var splat = Polygon2D.new()
		var sp = PackedVector2Array()
		for j in range(6):
			var a = j * TAU / 6
			var r = randf_range(3, 6)
			sp.append(Vector2(cos(a) * r, sin(a) * r))
		splat.polygon = sp
		splat.color = Color(0.45, 0.32, 0.18, 0.6)
		splat.position = Vector2(randf_range(-35, 35), randf_range(20, 45))
		parent.add_child(splat)

func _add_prop_magnifier(parent: Node2D, pos: Vector2) -> void:
	# Glass circle
	var glass = Polygon2D.new()
	var gp = PackedVector2Array()
	for i in range(14):
		var a = i * TAU / 14
		gp.append(Vector2(cos(a) * 10, sin(a) * 10) + pos)
	glass.polygon = gp
	glass.color = Color(0.8, 0.9, 1.0, 0.4)
	parent.add_child(glass)
	# Rim
	var rim = Line2D.new()
	rim.width = 2.0
	rim.default_color = Color(0.6, 0.5, 0.3)
	for i in range(15):
		var a = i * TAU / 14
		rim.add_point(Vector2(cos(a) * 10, sin(a) * 10) + pos)
	parent.add_child(rim)
	# Handle
	var handle = Line2D.new()
	handle.width = 3.0
	handle.default_color = Color(0.5, 0.4, 0.25)
	handle.add_point(pos + Vector2(7, 7))
	handle.add_point(pos + Vector2(16, 16))
	parent.add_child(handle)

func _add_prop_water_glass(parent: Node2D, pos: Vector2) -> void:
	var glass = Polygon2D.new()
	glass.polygon = PackedVector2Array([
		Vector2(-7, -12), Vector2(7, -12), Vector2(6, 12), Vector2(-6, 12),
	])
	glass.color = Color(0.7, 0.85, 1.0, 0.4)
	glass.position = pos
	parent.add_child(glass)
	# Specks inside
	for i in 3:
		var speck = Polygon2D.new()
		var sp = PackedVector2Array()
		for j in range(4):
			var a = j * TAU / 4
			sp.append(Vector2(cos(a) * 1.5, sin(a) * 1.5))
		speck.polygon = sp
		speck.color = Color(0.4, 0.35, 0.2, 0.7)
		speck.position = pos + Vector2(randf_range(-4, 4), randf_range(-8, 8))
		parent.add_child(speck)

func _add_prop_hose(parent: Node2D, pos: Vector2) -> void:
	var hose = Line2D.new()
	hose.width = 4.0
	hose.default_color = Color(0.2, 0.6, 0.3)
	hose.add_point(pos)
	hose.add_point(pos + Vector2(-10, 12))
	hose.add_point(pos + Vector2(-5, 24))
	hose.add_point(pos + Vector2(0, 30))
	hose.begin_cap_mode = Line2D.LINE_CAP_ROUND
	hose.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(hose)

func _add_prop_soap(parent: Node2D, pos: Vector2) -> void:
	var soap = Polygon2D.new()
	soap.name = "Soap"
	soap.polygon = PackedVector2Array([
		Vector2(-7, -5), Vector2(7, -5), Vector2(8, 5),
		Vector2(-8, 5),
	])
	soap.color = Color(0.9, 0.8, 1.0)
	soap.position = pos
	parent.add_child(soap)

func _add_prop_bubbles(parent: Node2D, pos: Vector2, count: int) -> void:
	for i in count:
		var bub = Polygon2D.new()
		bub.name = "Bubble_%d" % i
		var bp = PackedVector2Array()
		var r = randf_range(3, 7)
		for j in range(8):
			var a = j * TAU / 8
			bp.append(Vector2(cos(a) * r, sin(a) * r))
		bub.polygon = bp
		bub.color = Color(0.7, 0.85, 1.0, 0.35)
		bub.position = pos + Vector2(randf_range(-30, 30), randf_range(-15, 15))
		parent.add_child(bub)

func _add_prop_toilet(parent: Node2D, pos: Vector2) -> void:
	# Tank
	var tank = Polygon2D.new()
	tank.polygon = PackedVector2Array([
		Vector2(-12, -16), Vector2(12, -16), Vector2(12, 8), Vector2(-12, 8),
	])
	tank.color = Color(0.9, 0.9, 0.92)
	tank.position = pos
	parent.add_child(tank)
	# Lid
	var lid = Line2D.new()
	lid.width = 3.0
	lid.default_color = Color(0.8, 0.8, 0.82)
	lid.add_point(pos + Vector2(-13, -16))
	lid.add_point(pos + Vector2(13, -16))
	parent.add_child(lid)
	# Handle
	var handle = Line2D.new()
	handle.width = 2.0
	handle.default_color = Color(0.7, 0.7, 0.75)
	handle.add_point(pos + Vector2(10, -10))
	handle.add_point(pos + Vector2(16, -10))
	parent.add_child(handle)

func _add_prop_map(parent: Node2D, pos: Vector2) -> void:
	var paper = Polygon2D.new()
	paper.polygon = PackedVector2Array([
		Vector2(-12, -10), Vector2(12, -10), Vector2(14, 10), Vector2(-14, 10),
	])
	paper.color = Color(0.95, 0.9, 0.8)
	paper.position = pos
	parent.add_child(paper)
	# Lines on map
	for i in 3:
		var ml = Line2D.new()
		ml.width = 1.5
		ml.default_color = Color(0.3, 0.5, 0.8, 0.4)
		var y = -6 + i * 5
		ml.add_point(pos + Vector2(-8 + randf_range(-2, 2), y))
		ml.add_point(pos + Vector2(8 + randf_range(-2, 2), y))
		parent.add_child(ml)

func _add_prop_pipe_segments(parent: Node2D, pos: Vector2) -> void:
	for i in 3:
		var seg = Polygon2D.new()
		seg.polygon = PackedVector2Array([
			Vector2(-3, -8), Vector2(3, -8), Vector2(3, 8), Vector2(-3, 8),
		])
		seg.color = Color(0.5, 0.5, 0.55)
		seg.position = pos + Vector2(i * 12 - 12, 0)
		seg.rotation = randf_range(-0.3, 0.3)
		parent.add_child(seg)

func _add_prop_sponge(parent: Node2D, pos: Vector2) -> void:
	var sponge = Polygon2D.new()
	sponge.polygon = PackedVector2Array([
		Vector2(-8, -5), Vector2(8, -5), Vector2(7, 5), Vector2(-7, 5),
	])
	sponge.color = Color(0.95, 0.85, 0.2)
	sponge.position = pos
	parent.add_child(sponge)

func _add_prop_plate(parent: Node2D, pos: Vector2) -> void:
	var plate = Polygon2D.new()
	var pp = PackedVector2Array()
	for i in range(14):
		var a = i * TAU / 14
		pp.append(Vector2(cos(a) * 14, sin(a) * 6) + pos)
	plate.polygon = pp
	plate.color = Color(0.9, 0.9, 0.92)
	parent.add_child(plate)
	# Dirt marks (dirty plate)
	for i in 2:
		var dirt = Polygon2D.new()
		var dp = PackedVector2Array()
		for j in range(5):
			var a = j * TAU / 5
			dp.append(Vector2(cos(a) * 3, sin(a) * 2))
		dirt.polygon = dp
		dirt.color = Color(0.5, 0.4, 0.3, 0.4)
		dirt.position = pos + Vector2(randf_range(-6, 6), randf_range(-3, 3))
		parent.add_child(dirt)

func _add_prop_bucket_line(parent: Node2D, pos: Vector2) -> void:
	for i in 3:
		var b = Polygon2D.new()
		b.polygon = PackedVector2Array([
			Vector2(-6, -5), Vector2(6, -5), Vector2(5, 5), Vector2(-5, 5),
		])
		b.color = Color(0.5, 0.5, 0.7, 0.5)
		b.position = pos + Vector2(i * 18 - 18, 0)
		parent.add_child(b)

func _add_prop_music_notes(parent: Node2D, pos: Vector2) -> void:
	var notes = ["♪", "♫", "♩"]
	for i in 3:
		var n = Label.new()
		n.name = "Note_%d" % i
		n.text = notes[i]
		n.add_theme_font_size_override("font_size", 18)
		n.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		n.position = pos + Vector2(i * 20 - 20, randf_range(-10, 10))
		parent.add_child(n)

func _add_prop_reaching_hand(parent: Node2D, pos: Vector2) -> void:
	var hand = Line2D.new()
	hand.name = "ReachHand"
	hand.width = 4.0
	hand.default_color = Color(0.3, 0.68, 0.95)
	hand.add_point(pos)
	hand.add_point(pos + Vector2(10, -8))
	hand.add_point(pos + Vector2(14, -12))
	hand.begin_cap_mode = Line2D.LINE_CAP_ROUND
	hand.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(hand)

func _add_prop_puddle(parent: Node2D, pos: Vector2) -> void:
	var puddle = Polygon2D.new()
	puddle.name = "Puddle"
	var pp = PackedVector2Array()
	for i in range(10):
		var a = i * TAU / 10
		pp.append(Vector2(cos(a) * 18, sin(a) * 6) + pos)
	puddle.polygon = pp
	puddle.color = Color(0.3, 0.55, 0.85, 0.35)
	parent.add_child(puddle)

func _add_prop_barrel(parent: Node2D, pos: Vector2) -> void:
	var barrel = Polygon2D.new()
	barrel.polygon = PackedVector2Array([
		Vector2(-12, -16), Vector2(12, -16), Vector2(14, 0),
		Vector2(12, 16), Vector2(-12, 16), Vector2(-14, 0),
	])
	barrel.color = Color(0.45, 0.35, 0.22)
	barrel.position = pos
	parent.add_child(barrel)
	# Bands
	for i in 2:
		var band = Line2D.new()
		band.width = 2.0
		band.default_color = Color(0.55, 0.45, 0.3)
		var y = -8 + i * 16
		band.add_point(pos + Vector2(-13, y))
		band.add_point(pos + Vector2(13, y))
		parent.add_child(band)

func _add_prop_arrows(parent: Node2D, pos: Vector2) -> void:
	for i in 2:
		var arrow = Polygon2D.new()
		var dir = -1.0 + i * 2.0  # -1 left, +1 right
		arrow.polygon = PackedVector2Array([
			Vector2(0, -6), Vector2(dir * 14, 0), Vector2(0, 6),
		])
		arrow.color = Color(0.3, 0.7, 0.9)
		arrow.position = pos + Vector2(dir * 25, 0)
		parent.add_child(arrow)

func _run_intro_vfx() -> void:
	var speed_f = max(0.4, float(anim_options.get("speed", 1.0)))
	var length = 4.0 / speed_f
	var vp = get_viewport_rect().size

	if _water_droplet:
		var target_pos = _water_droplet.position
		# ── Phase 1: Quick bounce in from off-screen ──
		_water_droplet.position = Vector2(vp.x + 80, target_pos.y - 20)
		_water_droplet.modulate.a = 1.0
		_water_droplet.rotation = 0.3

		var crash = create_tween()
		crash.tween_property(_water_droplet, "position", target_pos + Vector2(-15, 8), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		crash.tween_callback(func():
			if AudioManager: AudioManager.play_click()
		)
		crash.tween_property(_water_droplet, "scale", Vector2(1.3, 0.6), 0.1).set_ease(Tween.EASE_OUT)
		crash.tween_property(_water_droplet, "scale", Vector2(0.7, 1.3), 0.12).set_ease(Tween.EASE_OUT)
		crash.tween_property(_water_droplet, "position", target_pos + Vector2(8, -5), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		crash.tween_property(_water_droplet, "scale", Vector2(1.1, 0.9), 0.1)
		crash.tween_property(_water_droplet, "position", target_pos, 0.15).set_ease(Tween.EASE_OUT)
		crash.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.12)

		var unrot = create_tween()
		unrot.tween_property(_water_droplet, "rotation", -0.08, 0.2).set_ease(Tween.EASE_OUT)
		unrot.tween_property(_water_droplet, "rotation", 0.03, 0.12)
		unrot.tween_property(_water_droplet, "rotation", 0.0, 0.1)

		# ── Phase 2: Game-specific contextual animation ──
		_run_game_specific_intro(length)

		# ── Phase 3: Quick exit ──
		var dout = create_tween()
		dout.tween_interval(length * 0.78)
		dout.tween_property(_water_droplet, "rotation", TAU * 0.5, 0.3).set_ease(Tween.EASE_IN)
		dout.tween_property(_water_droplet, "scale", Vector2(0.1, 0.1), 0.25)
		dout.tween_property(_water_droplet, "modulate:a", 0.0, 0.2)

	# Ambient sparkle particles
	for i in 10:
		var p = ColorRect.new()
		p.size = Vector2(randf_range(3, 8), randf_range(3, 8))
		p.color = Color(randf_range(0.5, 1), randf_range(0.8, 1), 1.0, 0.0)
		p.position = Vector2(randf_range(50, vp.x - 50), randf_range(50, vp.y - 50))
		p.rotation = randf_range(0, TAU)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		_particles.append(p)

		var delay = randf_range(0.05, 0.3)
		var pt = create_tween()
		pt.tween_interval(delay)
		pt.tween_property(p, "modulate:a", randf_range(0.4, 0.7), 0.15)
		pt.tween_interval(randf_range(0.3, 0.6))
		pt.tween_property(p, "modulate:a", 0.0, 0.2)

func _run_game_specific_intro(length: float) -> void:
	if not _water_droplet:
		return
	var left_arm = _water_droplet.get_node_or_null("LeftArm")
	var right_arm = _water_droplet.get_node_or_null("RightArm")
	var leg_l = _water_droplet.get_node_or_null("Leg_L")
	var leg_r = _water_droplet.get_node_or_null("Leg_R")
	var tongue = _water_droplet.get_node_or_null("Tongue")

	match _current_game_key:
		"WringItOut":
			var cloth = _water_droplet.get_node_or_null("Cloth")
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(4)
				lp.tween_property(right_arm, "rotation_degrees", -35.0, 0.35)
				lp.tween_property(right_arm, "rotation_degrees", 25.0, 0.35)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.25)
			if left_arm:
				var t2 = create_tween()
				t2.tween_interval(1.3)
				var lp2 = t2.set_loops(4)
				lp2.tween_property(left_arm, "rotation_degrees", 25.0, 0.35)
				lp2.tween_property(left_arm, "rotation_degrees", -20.0, 0.35)
				lp2.tween_property(left_arm, "rotation_degrees", 0.0, 0.25)
			if cloth:
				var tc = create_tween()
				tc.tween_interval(1.2)
				var lpc = tc.set_loops(5)
				lpc.tween_property(cloth, "rotation_degrees", 18.0, 0.25)
				lpc.tween_property(cloth, "rotation_degrees", -18.0, 0.25)
				lpc.tween_property(cloth, "rotation_degrees", 0.0, 0.2)
			_animate_drips_flying(_water_droplet, 1.4, 5)
			_animate_effort_squish(1.3, 4)

		"CatchTheRain":
			var cloud = _water_droplet.get_node_or_null("Cloud")
			if cloud:
				cloud.modulate.a = 0.0
				var tc = create_tween()
				tc.tween_property(cloud, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)
			_animate_excited_hop(1.2, 5)
			if left_arm and right_arm:
				var ta = create_tween()
				ta.tween_interval(1.0)
				ta.tween_property(left_arm, "rotation_degrees", -20.0, 0.4)
				ta.tween_property(right_arm, "rotation_degrees", 20.0, 0.4)
			_animate_rain_falling(_water_droplet, 1.4)

		"FixLeak", "PlugTheLeak":
			_animate_panic_shake(1.0, 3)
			if right_arm:
				var t = create_tween()
				t.tween_interval(2.0)
				var lp = t.set_loops(3)
				lp.tween_property(right_arm, "rotation_degrees", -40.0, 0.4)
				lp.tween_property(right_arm, "rotation_degrees", 10.0, 0.3)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.25)
			_animate_spray_burst(_water_droplet, 1.2)
			_animate_effort_squish(2.2, 3)

		"FilterBuilder":
			if left_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(3)
				lp.tween_property(left_arm, "rotation_degrees", -35.0, 0.5)
				lp.tween_property(left_arm, "rotation_degrees", -10.0, 0.5)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.4)
			if right_arm:
				var t2 = create_tween()
				t2.tween_interval(1.4)
				var lp2 = t2.set_loops(3)
				lp2.tween_property(right_arm, "rotation_degrees", 30.0, 0.5)
				lp2.tween_property(right_arm, "rotation_degrees", 5.0, 0.5)
				lp2.tween_property(right_arm, "rotation_degrees", 0.0, 0.4)
			_animate_careful_wobble(1.2, 4)

		"QuickShower":
			_animate_shower_dance(1.2, 4)
			if left_arm and right_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(4)
				lp.tween_property(left_arm, "rotation_degrees", -22.0, 0.3)
				lp.tween_property(left_arm, "rotation_degrees", 22.0, 0.3)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.2)
				var t2 = create_tween()
				t2.tween_interval(1.4)
				var lp2 = t2.set_loops(4)
				lp2.tween_property(right_arm, "rotation_degrees", 18.0, 0.3)
				lp2.tween_property(right_arm, "rotation_degrees", -25.0, 0.3)
				lp2.tween_property(right_arm, "rotation_degrees", 0.0, 0.2)
			if tongue:
				_animate_tongue_wiggle(tongue, 1.2, 4)

		"CoverTheDrum":
			_animate_panic_shake(1.0, 2)
			var lid = _water_droplet.get_node_or_null("Lid")
			if lid:
				var tl = create_tween()
				tl.tween_interval(2.0)
				tl.tween_property(lid, "rotation", 0.0, 0.5).set_ease(Tween.EASE_OUT)
				tl.tween_property(lid, "position:y", lid.position.y + 15, 0.4)
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.8)
				t.tween_property(right_arm, "rotation_degrees", -30.0, 0.5)
				t.tween_property(right_arm, "rotation_degrees", 15.0, 0.4)
				t.tween_property(right_arm, "rotation_degrees", 0.0, 0.3)
			_animate_effort_squish(1.8, 3)

		"RiceWashRescue":
			if left_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(4)
				lp.tween_property(left_arm, "rotation_degrees", -18.0, 0.35)
				lp.tween_property(left_arm, "rotation_degrees", 18.0, 0.35)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.25)
			_animate_gentle_sway(1.0, 5)

		"VegetableBath":
			if left_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(4)
				lp.tween_property(left_arm, "rotation_degrees", -25.0, 0.3)
				lp.tween_property(left_arm, "rotation_degrees", 10.0, 0.3)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.22)
			_animate_bubbles_floating(_water_droplet, 1.4, 4)
			_animate_gentle_sway(1.2, 4)

		"GreywaterSorter":
			_animate_look_left_right(1.2, 3)
			if left_arm and right_arm:
				var t = create_tween()
				t.tween_interval(1.4)
				var lp = t.set_loops(3)
				lp.tween_property(left_arm, "rotation_degrees", -30.0, 0.4)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.3)
				lp.tween_property(right_arm, "rotation_degrees", 30.0, 0.4)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.3)

		"ThirstyPlant":
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(4)
				lp.tween_property(right_arm, "rotation_degrees", 22.0, 0.4)
				lp.tween_property(right_arm, "rotation_degrees", 5.0, 0.3)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.25)
			_animate_gentle_sway(1.0, 5)
			_animate_drips_flying(_water_droplet, 1.6, 3)

		"MudPieMaker":
			_animate_excited_hop(1.2, 4)
			if left_arm and right_arm:
				var t = create_tween()
				t.tween_interval(1.4)
				var lp = t.set_loops(4)
				lp.tween_property(left_arm, "rotation_degrees", -22.0, 0.3)
				lp.tween_property(right_arm, "rotation_degrees", 22.0, 0.3)
				lp.tween_property(left_arm, "rotation_degrees", 18.0, 0.3)
				lp.tween_property(right_arm, "rotation_degrees", -18.0, 0.3)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.15)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.15)
			if tongue:
				_animate_tongue_wiggle(tongue, 1.2, 4)

		"SpotTheSpeck":
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.0)
				t.tween_property(right_arm, "rotation_degrees", -15.0, 0.5)
			_animate_lean_peer(1.4, 3)

		"WaterPlant":
			if left_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(4)
				lp.tween_property(left_arm, "rotation_degrees", -12.0, 0.4)
				lp.tween_property(left_arm, "rotation_degrees", -28.0, 0.4)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.3)
			_animate_gentle_sway(1.0, 4)

		"SwipeTheSoap":
			_animate_panic_shake(1.0, 2)
			if left_arm and right_arm:
				var t = create_tween()
				t.tween_interval(1.6)
				var lp = t.set_loops(3)
				lp.tween_property(left_arm, "rotation_degrees", -40.0, 0.22)
				lp.tween_property(right_arm, "rotation_degrees", 35.0, 0.22)
				lp.tween_property(left_arm, "rotation_degrees", 20.0, 0.22)
				lp.tween_property(right_arm, "rotation_degrees", -30.0, 0.22)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.15)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.15)
			_animate_bubbles_floating(_water_droplet, 1.4, 5)

		"ToiletTankFix":
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(3)
				lp.tween_property(right_arm, "rotation_degrees", -35.0, 0.4)
				lp.tween_property(right_arm, "rotation_degrees", 10.0, 0.3)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.25)
			_animate_careful_wobble(1.2, 4)
			_animate_effort_squish(2.0, 3)

		"TracePipePath":
			_animate_look_left_right(1.2, 3)
			if left_arm:
				var t = create_tween()
				t.tween_interval(1.6)
				var lp = t.set_loops(3)
				lp.tween_property(left_arm, "rotation_degrees", -22.0, 0.5)
				lp.tween_property(left_arm, "rotation_degrees", -5.0, 0.4)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.3)
			_animate_careful_wobble(1.2, 3)

		"ScrubToSave":
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.2)
				var lp = t.set_loops(5)
				lp.tween_property(right_arm, "rotation_degrees", -28.0, 0.2)
				lp.tween_property(right_arm, "rotation_degrees", 18.0, 0.2)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.12)
			_animate_effort_squish(1.2, 4)

		"BucketBrigade":
			_animate_excited_hop(1.0, 5)
			if leg_l and leg_r:
				var t = create_tween()
				t.tween_interval(1.0)
				var lp = t.set_loops(5)
				lp.tween_property(leg_l, "rotation_degrees", -30.0, 0.22)
				lp.tween_property(leg_r, "rotation_degrees", 30.0, 0.22)
				lp.tween_property(leg_l, "rotation_degrees", 0.0, 0.22)
				lp.tween_property(leg_r, "rotation_degrees", 0.0, 0.22)
			if left_arm and right_arm:
				var ta = create_tween()
				ta.tween_interval(1.2)
				var lpa = ta.set_loops(4)
				lpa.tween_property(left_arm, "rotation_degrees", -22.0, 0.28)
				lpa.tween_property(right_arm, "rotation_degrees", 22.0, 0.28)
				lpa.tween_property(left_arm, "rotation_degrees", 0.0, 0.28)
				lpa.tween_property(right_arm, "rotation_degrees", 0.0, 0.28)

		"TimingTap":
			_animate_rhythm_bounce(1.0, 6)
			if right_arm:
				var t = create_tween()
				t.tween_interval(1.0)
				var lp = t.set_loops(6)
				lp.tween_property(right_arm, "rotation_degrees", -18.0, 0.28)
				lp.tween_property(right_arm, "rotation_degrees", 5.0, 0.22)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.15)

		"TurnOffTap":
			_animate_panic_shake(1.0, 3)
			if left_arm and right_arm:
				var t = create_tween()
				t.tween_interval(1.6)
				var lp = t.set_loops(3)
				lp.tween_property(right_arm, "rotation_degrees", -40.0, 0.35)
				lp.tween_property(right_arm, "rotation_degrees", -15.0, 0.28)
				lp.tween_property(right_arm, "rotation_degrees", 0.0, 0.22)
			var puddle = _water_droplet.get_node_or_null("Puddle")
			if puddle:
				var tp = create_tween()
				tp.tween_interval(1.2)
				tp.tween_property(puddle, "scale", Vector2(1.5, 1.3), 3.0).set_ease(Tween.EASE_OUT)

		_:
			_animate_excited_hop(1.2, 5)
			if left_arm:
				var t = create_tween()
				t.tween_interval(1.5)
				var lp = t.set_loops(4)
				lp.tween_property(left_arm, "rotation_degrees", -25.0, 0.25)
				lp.tween_property(left_arm, "rotation_degrees", 10.0, 0.25)
				lp.tween_property(left_arm, "rotation_degrees", 0.0, 0.15)
			if right_arm:
				var t2 = create_tween()
				t2.tween_interval(1.8)
				var lp2 = t2.set_loops(4)
				lp2.tween_property(right_arm, "rotation_degrees", 20.0, 0.25)
				lp2.tween_property(right_arm, "rotation_degrees", -10.0, 0.25)
				lp2.tween_property(right_arm, "rotation_degrees", 0.0, 0.18)
			if tongue:
				_animate_tongue_wiggle(tongue, 1.2, 4)

# ═══════════════════════════════════════════════════════════════
# REUSABLE ANIMATION HELPERS for game-specific intros
# ═══════════════════════════════════════════════════════════════

func _animate_excited_hop(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 3))
	lp.tween_property(_water_droplet, "position:y", _water_droplet.position.y - 18, 0.16).set_ease(Tween.EASE_OUT)
	lp.tween_property(_water_droplet, "scale", Vector2(0.88, 1.15), 0.1)
	lp.tween_property(_water_droplet, "position:y", _water_droplet.position.y, 0.16).set_ease(Tween.EASE_IN)
	lp.tween_property(_water_droplet, "scale", Vector2(1.1, 0.88), 0.08)
	lp.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.08)

func _animate_panic_shake(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 3))
	lp.tween_property(_water_droplet, "rotation", 0.16, 0.08)
	lp.tween_property(_water_droplet, "rotation", -0.16, 0.08)
	lp.tween_property(_water_droplet, "rotation", 0.1, 0.06)
	lp.tween_property(_water_droplet, "rotation", -0.04, 0.05)
	lp.tween_property(_water_droplet, "rotation", 0.0, 0.04)

func _animate_effort_squish(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 3))
	lp.tween_property(_water_droplet, "scale", Vector2(1.15, 0.8), 0.15)
	lp.tween_property(_water_droplet, "scale", Vector2(0.88, 1.18), 0.15)
	lp.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.1)

func _animate_gentle_sway(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 3))
	lp.tween_property(_water_droplet, "rotation", 0.08, 0.25)
	lp.tween_property(_water_droplet, "rotation", -0.08, 0.25)
	lp.tween_property(_water_droplet, "rotation", 0.0, 0.18)

func _animate_careful_wobble(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(loops)
	lp.tween_property(_water_droplet, "rotation", 0.06, 0.3)
	lp.tween_property(_water_droplet, "rotation", -0.05, 0.25)
	lp.tween_property(_water_droplet, "rotation", 0.0, 0.2)

func _animate_shower_dance(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 3))
	lp.tween_property(_water_droplet, "position:x", _water_droplet.position.x + 12, 0.18)
	lp.tween_property(_water_droplet, "scale", Vector2(1.1, 0.9), 0.1)
	lp.tween_property(_water_droplet, "position:x", _water_droplet.position.x - 12, 0.18)
	lp.tween_property(_water_droplet, "scale", Vector2(0.9, 1.1), 0.1)
	lp.tween_property(_water_droplet, "position:x", _water_droplet.position.x, 0.1)
	lp.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.08)

func _animate_tongue_wiggle(tongue: Node, delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(loops)
	lp.tween_property(tongue, "rotation_degrees", 12.0, 0.18)
	lp.tween_property(tongue, "rotation_degrees", -12.0, 0.18)
	lp.tween_property(tongue, "rotation_degrees", 0.0, 0.12)

func _animate_look_left_right(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 2))
	lp.tween_property(_water_droplet, "rotation", -0.12, 0.2)
	lp.tween_interval(0.2)
	lp.tween_property(_water_droplet, "rotation", 0.12, 0.2)
	lp.tween_interval(0.2)
	lp.tween_property(_water_droplet, "rotation", 0.0, 0.15)

func _animate_lean_peer(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 2))
	lp.tween_property(_water_droplet, "scale", Vector2(1.06, 0.94), 0.22)
	lp.tween_property(_water_droplet, "position:x", _water_droplet.position.x + 8, 0.18)
	lp.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.15)
	lp.tween_property(_water_droplet, "position:x", _water_droplet.position.x, 0.15)

func _animate_rhythm_bounce(delay: float, loops: int) -> void:
	var t = create_tween()
	t.tween_interval(delay)
	var lp = t.set_loops(mini(loops, 4))
	lp.tween_property(_water_droplet, "scale", Vector2(1.08, 0.92), 0.12)
	lp.tween_property(_water_droplet, "position:y", _water_droplet.position.y - 8, 0.1)
	lp.tween_property(_water_droplet, "scale", Vector2(0.92, 1.08), 0.1)
	lp.tween_property(_water_droplet, "position:y", _water_droplet.position.y, 0.1)
	lp.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.08)

func _animate_drips_flying(parent: Node2D, delay: float, count: int) -> void:
	for i in count:
		var d = parent.get_node_or_null("Drip_%d" % i)
		if d:
			var td = create_tween()
			td.tween_interval(delay + i * 0.12)
			td.tween_property(d, "position:y", d.position.y + 20, 0.3).set_ease(Tween.EASE_IN)
			td.tween_property(d, "modulate:a", 0.0, 0.15)
			td.tween_callback(func():
				if is_instance_valid(d):
					d.position.y -= 20
					d.modulate.a = 0.7
			)

func _animate_rain_falling(parent: Node2D, delay: float) -> void:
	for i in 5:
		var r = parent.get_node_or_null("Rain_%d" % i)
		if r:
			var tr = create_tween()
			tr.tween_interval(delay + i * 0.1)
			var lp = tr.set_loops(4)
			lp.tween_property(r, "position:y", r.position.y + 25, 0.2).set_ease(Tween.EASE_IN)
			lp.tween_property(r, "modulate:a", 0.0, 0.05)
			lp.tween_callback(func():
				if is_instance_valid(r):
					r.position.y -= 25
					r.modulate.a = 0.6
			)
			lp.tween_interval(0.05)

func _animate_spray_burst(parent: Node2D, delay: float) -> void:
	for i in 3:
		var s = parent.get_node_or_null("Spray_%d" % i)
		if s:
			var ts = create_tween()
			ts.tween_interval(delay + i * 0.08)
			var lp = ts.set_loops(4)
			lp.tween_property(s, "scale", Vector2(1.4, 1.4), 0.1)
			lp.tween_property(s, "scale", Vector2(0.8, 0.8), 0.1)
			lp.tween_property(s, "scale", Vector2(1.0, 1.0), 0.08)

func _animate_bubbles_floating(parent: Node2D, delay: float, count: int) -> void:
	for i in count:
		var b = parent.get_node_or_null("Bubble_%d" % i)
		if b:
			var tb = create_tween()
			tb.tween_interval(delay + i * 0.15)
			var lp = tb.set_loops(3)
			lp.tween_property(b, "position:y", b.position.y - 15, 0.4).set_ease(Tween.EASE_OUT)
			lp.tween_property(b, "modulate:a", 0.0, 0.1)
			lp.tween_callback(func():
				if is_instance_valid(b):
					b.position.y += 15
					b.modulate.a = 0.35
			)
			lp.tween_interval(0.1)

func _cleanup_vfx() -> void:
	for p in _particles:
		if is_instance_valid(p):
			p.queue_free()
	_particles.clear()
	if is_instance_valid(_water_droplet):
		_water_droplet.queue_free()

func _prettify_title(raw: String) -> String:
	# Convert PascalCase to spaced: "CatchTheRain" → "Catch The Rain"
	var result = ""
	for i in raw.length():
		var c = raw[i]
		if c == c.to_upper() and i > 0 and raw[i - 1] != " ":
			result += " "
		result += c
	return result

func _get_game_instruction(title: String) -> String:
	var instructions = {
		"CatchTheRain": "Tap the falling drops!",
		"FixLeak": "Find and seal the leaks!",
		"PlugTheLeak": "Plug the pipe fast!",
		"FilterBuilder": "Stack the filter layers!",
		"QuickShower": "Finish before time runs out!",
		"CoverTheDrum": "Cover it before contamination!",
		"RiceWashRescue": "Save the rice water!",
		"VegetableBath": "Rinse veggies efficiently!",
		"GreywaterSorter": "Sort the water streams!",
		"WringItOut": "Squeeze every last drop!",
		"ThirstyPlant": "Water just the right amount!",
		"MudPieMaker": "Mix the perfect ratio!",
		"SpotTheSpeck": "Find all the particles!",
		"WaterPlant": "Water with precision!",
		"SwipeTheSoap": "Swipe fast, save water!",
		"ToiletTankFix": "Calibrate the flush!",
		"TracePipePath": "Follow the pipe route!",
		"ScrubToSave": "Scrub smart, not wet!",
		"BucketBrigade": "Pass the buckets!",
		"TimingTap": "Tap on the beat!",
		"TurnOffTap": "Cut the flow on time!",
	}
	return instructions.get(title, "Get ready...")

func _get_theme_color_for_title(title: String) -> Color:
	if "Rain" in title or "Catch" in title:
		return Color(0.02, 0.06, 0.18)
	if "Leak" in title or "Pipe" in title or "Plug" in title:
		return Color(0.04, 0.08, 0.16)
	if "Plant" in title or "Vegetable" in title or "Thirsty" in title:
		return Color(0.02, 0.12, 0.04)
	if "Filter" in title or "Speck" in title or "Sort" in title:
		return Color(0.06, 0.04, 0.14)
	if "Shower" in title or "Soap" in title or "Scrub" in title:
		return Color(0.04, 0.08, 0.14)
	return Color(0.02, 0.08, 0.14)

func _rebuild_animation() -> void:
	_ensure_cinematic_nodes()
	var speed = max(0.4, float(anim_options.get("speed", 1.0)))
	var distance = clamp(float(anim_options.get("distance", 1.0)), 0.6, 1.6)
	var pop = clamp(float(anim_options.get("pop", 1.0)), 0.6, 1.6)
	var length = 4.0 / speed
	var in_t = length * 0.12
	var hold_t = length * 0.85

	var enter_from_y = -140.0 - (120.0 * distance)
	var enter_to_y = -140.0
	var exit_to_y = -190.0 - (30.0 * distance)
	var scale_from = 0.82
	var scale_peak = 1.0 + (0.03 * pop)
	var icon_pop = 1.0 + (0.08 * pop)

	var anim := Animation.new()
	anim.length = length

	var overlay_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(overlay_track, NodePath("Overlay:modulate:a"))
	anim.track_insert_key(overlay_track, 0.0, 0.0)
	anim.track_insert_key(overlay_track, in_t * 0.8, 1.0)
	anim.track_insert_key(overlay_track, hold_t, 1.0)
	anim.track_insert_key(overlay_track, length, 0.0)

	var streak_back_alpha := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_back_alpha, NodePath("StreakBack:modulate:a"))
	anim.track_insert_key(streak_back_alpha, 0.0, 0.0)
	anim.track_insert_key(streak_back_alpha, in_t * 0.6, 0.7)
	anim.track_insert_key(streak_back_alpha, hold_t, 0.45)
	anim.track_insert_key(streak_back_alpha, length, 0.0)

	var streak_back_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_back_pos, NodePath("StreakBack:position:x"))
	anim.track_insert_key(streak_back_pos, 0.0, -320.0)
	anim.track_insert_key(streak_back_pos, hold_t, 120.0)
	anim.track_insert_key(streak_back_pos, length, 220.0)

	var streak_front_alpha := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_front_alpha, NodePath("StreakFront:modulate:a"))
	anim.track_insert_key(streak_front_alpha, 0.0, 0.0)
	anim.track_insert_key(streak_front_alpha, in_t, 0.55)
	anim.track_insert_key(streak_front_alpha, hold_t, 0.25)
	anim.track_insert_key(streak_front_alpha, length, 0.0)

	var streak_front_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_front_pos, NodePath("StreakFront:position:x"))
	anim.track_insert_key(streak_front_pos, 0.0, 420.0)
	anim.track_insert_key(streak_front_pos, hold_t, -40.0)
	anim.track_insert_key(streak_front_pos, length, -220.0)

	var flash_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(flash_track, NodePath("FlashBeat:modulate:a"))
	anim.track_insert_key(flash_track, 0.0, 0.0)
	anim.track_insert_key(flash_track, in_t * 0.9, 0.35)
	anim.track_insert_key(flash_track, in_t * 1.2, 0.0)

	var panel_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(panel_track, NodePath("Panel:position:y"))
	anim.track_insert_key(panel_track, 0.0, enter_from_y)
	anim.track_insert_key(panel_track, in_t, enter_to_y)
	anim.track_insert_key(panel_track, hold_t, enter_to_y)
	anim.track_insert_key(panel_track, length, exit_to_y)

	var scale_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(scale_track, NodePath("Panel:scale"))
	anim.track_insert_key(scale_track, 0.0, Vector2(scale_from, scale_from))
	anim.track_insert_key(scale_track, in_t * 1.1, Vector2(scale_peak, scale_peak))
	anim.track_insert_key(scale_track, in_t * 1.8, Vector2(1.0, 1.0))

	var icon_scale_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(icon_scale_track, NodePath("Panel/Center/VBox/Icon:scale"))
	anim.track_insert_key(icon_scale_track, 0.0, Vector2(0.75, 0.75))
	anim.track_insert_key(icon_scale_track, in_t * 1.1, Vector2(icon_pop, icon_pop))
	anim.track_insert_key(icon_scale_track, in_t * 1.8, Vector2(1.0, 1.0))

	var icon_rot_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(icon_rot_track, NodePath("Panel/Center/VBox/Icon:rotation"))
	anim.track_insert_key(icon_rot_track, 0.0, -0.22)
	anim.track_insert_key(icon_rot_track, in_t * 1.3, 0.08)
	anim.track_insert_key(icon_rot_track, in_t * 1.8, 0.0)

	var icon_alpha_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(icon_alpha_track, NodePath("Panel/Center/VBox/Icon:modulate:a"))
	anim.track_insert_key(icon_alpha_track, 0.0, 0.0)
	anim.track_insert_key(icon_alpha_track, in_t * 1.0, 1.0)

	var title_alpha_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(title_alpha_track, NodePath("Panel/Center/VBox/Title:modulate:a"))
	anim.track_insert_key(title_alpha_track, 0.0, 0.0)
	anim.track_insert_key(title_alpha_track, in_t * 1.1, 1.0)

	var subtitle_alpha_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(subtitle_alpha_track, NodePath("Panel/Center/VBox/Subtitle:modulate:a"))
	anim.track_insert_key(subtitle_alpha_track, 0.0, 0.0)
	anim.track_insert_key(subtitle_alpha_track, in_t * 1.4, 1.0)

	# Ensure animation_player exists and is ready
	if not animation_player or not is_instance_valid(animation_player):
		push_error("AnimationPlayer node not found or invalid in MiniGameIntroCutscene")
		return
	
	# Get or create the animation library
	var library: AnimationLibrary = null
	if animation_player.has_animation_library(""):
		library = animation_player.get_animation_library("")
	
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	
	# Add or replace the animation
	if library.has_animation("intro"):
		library.remove_animation("intro")
	library.add_animation("intro", anim)

func _ensure_cinematic_nodes() -> void:
	if not has_node("StreakBack"):
		streak_back = ColorRect.new()
		streak_back.name = "StreakBack"
		streak_back.color = Color(0.2, 0.85, 1.0, 0.55)
		streak_back.size = Vector2(720, 32)
		streak_back.position = Vector2(-260, 160)
		add_child(streak_back)

	if not has_node("StreakFront"):
		streak_front = ColorRect.new()
		streak_front.name = "StreakFront"
		streak_front.color = Color(1.0, 0.95, 0.35, 0.4)
		streak_front.size = Vector2(560, 20)
		streak_front.position = Vector2(320, 520)
		add_child(streak_front)

	if not has_node("FlashBeat"):
		flash_beat = ColorRect.new()
		flash_beat.name = "FlashBeat"
		flash_beat.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_beat.color = Color(1, 1, 1, 0.0)
		add_child(flash_beat)

	if not has_node("Panel/Center/VBox/Icon"):
		icon_label = Label.new()
		icon_label.name = "Icon"
		icon_label.text = "⚡"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 64)
		icon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		icon_label.add_theme_constant_override("outline_size", 6)
		var vbox = $Panel/Center/VBox
		vbox.add_child(icon_label)
		vbox.move_child(icon_label, 0)

	streak_back = get_node("StreakBack") as ColorRect
	streak_front = get_node("StreakFront") as ColorRect
	flash_beat = get_node("FlashBeat") as ColorRect
	icon_label = get_node("Panel/Center/VBox/Icon") as Label

	if streak_back:
		move_child(streak_back, 1)
	if streak_front:
		move_child(streak_front, 2)
	if flash_beat:
		move_child(flash_beat, get_child_count() - 1)

func _get_intro_icon_for_title(title: String) -> String:
	if "Rain" in title:
		return "🌧"
	if "Leak" in title or "Pipe" in title:
		return "🔧"
	if "Filter" in title:
		return "🧪"
	if "Plant" in title:
		return "🌱"
	if "Tap" in title:
		return "🚰"
	if "Bucket" in title:
		return "🪣"
	return "⚡"
