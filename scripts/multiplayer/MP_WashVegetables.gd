extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## ═══════════════════════════════════════════════════════════════════
## MP_WashVegetables - Player 1 Game (Water Reuse Theme)
## ═══════════════════════════════════════════════════════════════════
## Player 1 washes vegetables by dragging them to the sink
## Dirty water is sent to Player 2 for watering plants
## Must complete quota: Wash required number of vegetables
## ═══════════════════════════════════════════════════════════════════

const DIRTY_WATER_PER_VEGGIE: int = 1  # Each vegetable produces 1 unit of water
const MAX_MISSES: int = 8   # was 5 — more forgiving
const QUOTA_P1: int = 8   # was 12 — shorter game, P2 gets water sooner
## WHAT A WASHED VEGETABLE PAYS, AND THE TEAM TOTAL THAT ENDS THE ROUND
##
## The payout was a bare add_score(10) and there was no win_quota at all, which in
## MultiplayerMiniGameBase means the round takes the survival branch: end_game(true) fires
## unconditionally on time-up, so a player who washed nothing "won" and CoopAdaptation read
## success from a round that never happened. The target is the quota the instruction text
## already promises (QUOTA_P1 vegetables), priced in points, so the two cannot drift apart -
## and MP_WaterPlants derives the same 80 from its own quota, which matters because win_quota
## is compared against the shared G-Counter total on both peers.
const POINTS_PER_VEGGIE: int = 10
const TEAM_TARGET: int = QUOTA_P1 * POINTS_PER_VEGGIE
const MAX_ON_SCREEN: int = 6   # new — when exceeded oldest is "missed" to keep pressure fair
## HOW BIG A VEGETABLE IS TO GRAB, AS OPPOSED TO HOW BIG IT LOOKS
##
## VEGETABLE_SIZE was doing both jobs and gave a 60-unit circle - 20dp on the densest profile,
## under half the 48dp Android/WCAG floor (147 canvas units on WVGA 4.5in). Nothing grows an
## Area2D collision shape, so a drag that starts on a vegetable had to start inside 60 units of
## its centre no matter what device it shipped to.
##
## The two are now separate numbers. The grab circle is 150 units across, above the floor. The art
## is 110, big enough to aim at and still read as a carrot rather than a boulder - Android sizes
## the TARGET at 48dp and lets the visual inside it be smaller. Overlap between two grab circles
## is harmless here: every vegetable behaves identically, so whichever one the finger lands on is
## the right one, which is why this can be grown rather than re-laid-out.
const GRAB_RADIUS: float = 75.0
const VEGETABLE_ART: float = 110.0
## The drop texture is generated at this radius and the Sprite2D is scaled up to VEGETABLE_ART,
## because MiniGameAssets.create_drop_texture() is a per-pixel GDScript loop: drawing 110x110
## instead of 60x60 would triple the cost of every spawn, and one spawns every 1.5s mid-round.
const VEGETABLE_TEX_RADIUS: int = 30

## WHERE THE SINK SITS AND WHERE VEGETABLES ARRIVE
##
## Both were absolute points in the 1152x648 box these scenes were authored against: the sink at
## (576, 500) and the spawn band at x[100, 1052], y[100, 300]. The Camera2D at (576, 324) makes
## the visible world x[-384, 1536], y[-216, 864] on a 1920x1080 window and wider still under
## stretch/aspect="expand", so the band covered the middle 50% of the playfield and left ~480
## units of bare tile down each side, while the sink floated mid-screen instead of sitting at the
## near edge where a drag ends. Both are now fractions of playfield_rect(), so the layout tracks
## whatever viewport the device reports.
const SINK_BOTTOM_FRAC: float = 0.18
const SINK_SIZE: Vector2 = Vector2(200.0, 150.0)
## Vegetables arrive between these fractions of the visible height: below the HUD band at the top,
## above the sink at the bottom, so nothing spawns already-in-the-sink or under the score.
const SPAWN_TOP_FRAC: float = 0.22
const SPAWN_BOTTOM_FRAC: float = 0.55
## Side margin for a spawn, wide enough that the whole grab circle lands on screen.
const SPAWN_MARGIN: float = GRAB_RADIUS + 40.0

var vegetables_washed: int = 0
var vegetables_missed: int = 0
var spawn_timer: Timer
var vegetables: Array = []
var dragging_vegetable: Area2D = null
var sink_area: Area2D = null

## The emoji lives inside the table entry rather than being concatenated here, so a
## translator can move it (Filipino puts no article in front of the noun) and so the
## chip is one lookup instead of a literal plus a lookup.
var vegetable_types = [
	{"key": "mp_veg_carrot", "color": Color(1.0, 0.5, 0.2)},
	{"key": "mp_veg_lettuce", "color": Color(0.3, 0.8, 0.3)},
	{"key": "mp_veg_tomato", "color": Color(1.0, 0.3, 0.3)},
	{"key": "mp_veg_cucumber", "color": Color(0.2, 0.7, 0.3)}
]

func get_instructions() -> String:
	return Localization.get_text("mp_wash_vegetables_instructions") % [QUOTA_P1, MAX_MISSES]

func get_controls_text() -> String:
	return Localization.get_text("mp_wash_vegetables_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Wash Vegetables"
	title_key = "mp_title_wash_vegetables"
	connection_type = "resource_transfer"
	win_quota = TEAM_TARGET # a TEAM total — the partner pays into it too
	set_process_input(true)
	
	_create_sink()
	
	# Create spawn timer for endless spawning
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.5   # was 2.0 — more vegetables = more water sent to P2
	spawn_timer.timeout.connect(_spawn_vegetable)
	add_child(spawn_timer)
	
	_log("🥕 Wash %d vegetables (%d team pts)! Miss %d = lose 1 life" % [QUOTA_P1, TEAM_TARGET, MAX_MISSES])

func _on_game_start() -> void:
	spawn_timer.start()
	_log("🚿 Start washing!")
	if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
		AutoPlayManager.register_multiplayer_game(self, my_role)

## The visible world rect, with the authored design box as the pre-first-frame fallback.
## playfield_rect() returns an empty Rect2 while the viewport has no size, which is the state
## _on_multiplayer_ready() runs in under the headless driver.
func _field() -> Rect2:
	var field := playfield_rect()
	if field.size.x <= 1.0:
		return Rect2(Vector2(576.0, 324.0) - Vector2(960.0, 540.0), Vector2(1920.0, 1080.0))
	return field

## Where the next vegetable appears: anywhere across the visible width, in the band between the
## HUD at the top and the sink at the bottom.
func _spawn_point() -> Vector2:
	var field := _field()
	return Vector2(
		randf_range(field.position.x + SPAWN_MARGIN, field.end.x - SPAWN_MARGIN),
		randf_range(field.position.y + field.size.y * SPAWN_TOP_FRAC,
			field.position.y + field.size.y * SPAWN_BOTTOM_FRAC))

func _create_sink() -> void:
	# Create sink area where vegetables are washed
	sink_area = Area2D.new()
	# Centred on the playfield and parked near the bottom edge, so a wash is a drag toward
	# the player rather than toward a point that moves with the aspect ratio.
	var field := _field()
	sink_area.position = Vector2(
		field.get_center().x, field.end.y - field.size.y * SINK_BOTTOM_FRAC)
	add_child(sink_area)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = SINK_SIZE
	collision.shape = shape
	sink_area.add_child(collision)
	
	# Visual sink
	var sink_visual = ColorRect.new()
	sink_visual.size = SINK_SIZE
	sink_visual.position = -SINK_SIZE * 0.5
	sink_visual.color = Color(0.6, 0.8, 1.0, 0.3)
	sink_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sink_area.add_child(sink_visual)
	
	# Label
	var label = Label.new()
	label.text = Localization.get_text("mp_sink_label")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -50)
	label.add_theme_font_size_override("font_size", 24)
	sink_area.add_child(label)

func _spawn_vegetable() -> void:
	var veggie_type = vegetable_types[randi() % vegetable_types.size()]
	
	var veggie = Area2D.new()
	veggie.position = _spawn_point()
	veggie.set_meta("type", "vegetable")
	veggie.set_meta("veggie_data", veggie_type)
	add_child(veggie)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = GRAB_RADIUS
	collision.shape = shape
	veggie.add_child(collision)
	
	# Visual
	var visual = Sprite2D.new()
	visual.texture = MiniGameAssets.create_drop_texture(VEGETABLE_TEX_RADIUS, veggie_type["color"]) # Reuse drop shape for simple veggie
	visual.scale = Vector2.ONE * (VEGETABLE_ART / float(VEGETABLE_TEX_RADIUS * 2))
	veggie.add_child(visual)
	
	# Label
	var label = Label.new()
	label.text = Localization.get_text(str(veggie_type["key"]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -VEGETABLE_ART * 0.5 - 24.0)  # above the enlarged art, not on top of it
	label.add_theme_font_size_override("font_size", 20)
	veggie.add_child(label)
	
	# Connect input
	veggie.input_event.connect(_on_veggie_input.bind(veggie))
	
	vegetables.append(veggie)

	# Enforce on-screen cap — if too many pile up, remove oldest as a miss
	if vegetables.size() > MAX_ON_SCREEN:
		var oldest: Area2D = vegetables[0]
		vegetables.remove_at(0)
		oldest.queue_free()
		_on_vegetable_missed()

func _on_veggie_input(_viewport: Node, event: InputEvent, _shape_idx: int, veggie: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_vegetable = veggie

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if event is InputEventMouseMotion and dragging_vegetable:
		dragging_vegetable.position = get_global_mouse_position()
	
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging_vegetable:
			_check_wash_vegetable()
			dragging_vegetable = null

func _check_wash_vegetable() -> void:
	if not dragging_vegetable or not sink_area:
		return
	
	# Check if vegetable is in sink
	var distance = dragging_vegetable.global_position.distance_to(sink_area.global_position)
	if distance < 100:
		_wash_vegetable()

func _wash_vegetable() -> void:
	if not dragging_vegetable:
		return
	
	vegetables_washed += 1
	_log("🚿 Washed vegetable! Total: %d" % vegetables_washed)

	# Score for P1 (G-Counter), then send P2 their water, and only then test the quota.
	# end_game() is not a marker: it calls NetworkManager.report_player_completion() with
	# local_score as it stands, and that dictionary is what _check_both_completed() and
	# CoopAdaptation read. Awarding afterwards published a score short by exactly this
	# vegetable — measured as 70 against a true 80 by tools/VerifyMPWashWater.tscn — and
	# drew that short number on the results screen too.
	add_score(POINTS_PER_VEGGIE)
	
	# Send dirty water to P2
	send_resource_to_partner("dirty_water", DIRTY_WATER_PER_VEGGIE, 1.0)
	
	# Check for win condition
	if vegetables_washed >= QUOTA_P1:
		end_game(true)
	
	# Visual effect
	_play_wash_effect(dragging_vegetable.global_position)
	
	# Remove vegetable
	vegetables.erase(dragging_vegetable)
	dragging_vegetable.queue_free()
	dragging_vegetable = null

func _on_vegetable_missed() -> void:
	# Vegetable fell off screen or timeout
	vegetables_missed += 1
	_log("❌ Missed vegetable! (%d/%d)" % [vegetables_missed, MAX_MISSES])
	
	if vegetables_missed >= MAX_MISSES:
		_log("💔 Too many misses - lose 1 life!")
		vegetables_missed = 0  # Reset counter
		report_miss_to_host()  # Lose shared life

func _play_wash_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0, 1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2(0, 300)
	particles.color = Color(0.5, 0.7, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _on_game_over() -> void:
	_log("Game over! Vegetables washed: %d" % vegetables_washed)
	super._on_game_over()
