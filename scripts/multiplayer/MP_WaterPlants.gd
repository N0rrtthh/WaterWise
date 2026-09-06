extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## ═══════════════════════════════════════════════════════════════════
## MP_WaterPlants - Player 2 Game (Water Reuse Theme)
## ═══════════════════════════════════════════════════════════════════
## Player 2 waters plants using dirty water from Player 1
## Can only water when P1 sends dirty water
## Must complete quota: Water required number of plants
## ═══════════════════════════════════════════════════════════════════

const PLANT_SIZE: float = 150.0   # 48dp floor on WVGA is 147 canvas units
const PLANT_TEX_PX: int = 80      # art resolution; the sprite is scaled to PLANT_SIZE
const WATER_PER_PLANT: int = 1  # Each plant needs 1 unit of water
const MAX_WILTED: int = 8   # was 5 — more tolerance while P2 waits for P1
## How long a dry plant survives before it wilts. This was a bare 15.0 buried inside
## _check_wilted_plants() while the timer driving that check had been retuned to 20.0, so
## the documented "plants wilt more slowly" change never actually took effect.
const WILT_SECONDS: float = 20.0
## How long a watered — or wilted — plant takes to come back dry and waterable.
const PLANT_RECOVERY_SECONDS: float = 10.0
const QUOTA_P2: int = 8   # was 12 — shorter quota matches P1’s
## WHAT A WATERED PLANT PAYS, AND THE TEAM TOTAL THAT ENDS THE ROUND
##
## This paid add_score(1) for the same kind of action its partner MP_WashVegetables is paid 10
## for, on a scoreboard both players can see and that CoopAdaptation reads to decide who is the
## weaker player: 8 plants earned 8 points against the same 8 vegetables' 80. And with no
## win_quota the round took MultiplayerMiniGameBase's survival branch — an unconditional
## end_game(true) on time-up — so watering nothing still "won". The target is the quota the
## instruction text already promises, priced the same as a vegetable, which lands on the same 80
## MP_WashVegetables derives; both peers must agree, because win_quota is measured against the
## shared G-Counter total.
const POINTS_PER_PLANT: int = 10
const TEAM_TARGET: int = QUOTA_P2 * POINTS_PER_PLANT

var plants_watered: int = 0
var plants_wilted: int = 0
var wilt_timer: Timer
var available_water: int = 0  # Water units received from P1
var plants: Array = []
var selected_plant: Area2D = null
var water_indicator_label: Label = null

## Flower names carry their emoji inside the table entry: the chip is one lookup, and a
## translator can reorder glyph and noun without touching this file.
var plant_types = [
	{"key": "mp_plant_sunflower", "color": Color(1.0, 0.9, 0.2)},
	{"key": "mp_plant_rose", "color": Color(1.0, 0.3, 0.4)},
	{"key": "mp_plant_herb", "color": Color(0.3, 0.8, 0.3)},
	{"key": "mp_plant_hibiscus", "color": Color(1.0, 0.4, 0.6)}
]

func get_instructions() -> String:
	return Localization.get_text("mp_water_plants_instructions") % [QUOTA_P2, int(WILT_SECONDS), MAX_WILTED]

func get_controls_text() -> String:
	return Localization.get_text("mp_water_plants_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Water Plants"
	title_key = "mp_title_water_plants"
	connection_type = "resource_transfer"
	win_quota = TEAM_TARGET # a TEAM total — the partner pays into it too
	
	_create_water_indicator()
	_spawn_plants()
	
	# Wilt timer - plants wilt if not watered
	wilt_timer = Timer.new()
	# Polls well under WILT_SECONDS so a plant wilts AT its wilt age. This period used to BE
	# the wilt age (raised 15→20 while the threshold inside the check stayed 15.0), which
	# left that retune unrealised and let the real wilt moment land anywhere in a 20s window.
	wilt_timer.wait_time = 1.0
	wilt_timer.timeout.connect(_check_wilted_plants)
	add_child(wilt_timer)
	
	_log("🌱 Water %d plants (%d team pts) before they wilt! %d preventable wilts = lose 1 life" % [QUOTA_P2, TEAM_TARGET, MAX_WILTED])

func _on_game_start() -> void:
	# Start every plant's wilt clock HERE, not where the plant was built. The instruction
	# overlay between the two waits on a player tap with no timeout, so that gap is however
	# long the player reads for, and the clock was stamped at build time. An 18s read put
	# all 12 plants past the wilt age before the round even began: the first tick wiped the
	# whole board at once and spent a shared life for it (measured 12 of 12 by
	# tools/VerifyMPWashWater.tscn).
	var now: int = Time.get_ticks_msec()
	for plant in plants:
		if is_instance_valid(plant):
			plant.set_meta("spawn_time", now)
	wilt_timer.start()
	_log("🚿 Waiting for water from partner...")
	# Give P2 starter water so they can water the first plants
	# before P1 washes the very first vegetable.
	available_water = 3
	_update_water_display()
	_log("💧 Starting with %d dirty water" % available_water)
	if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
		AutoPlayManager.register_multiplayer_game(self, my_role)

func _create_water_indicator() -> void:
	# Show available water from P1
	var panel = PanelContainer.new()
	panel.size = Vector2(200, 100)
	# Screen space, not world space: the Camera2D would otherwise drag this counter
	# across the screen with the aspect ratio. See attach_hud_panel() in the base.
	attach_hud_panel(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("mp_res_available_water")
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var water_label = Label.new()
	water_label.name = "WaterLabel"
	water_label.text = "💧 x 0"
	water_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(water_label)
	water_indicator_label = water_label
	
	var info = Label.new()
	info.text = Localization.get_text("mp_hint_click_plants")
	info.add_theme_font_size_override("font_size", 14)
	vbox.add_child(info)

func _update_water_display() -> void:
	if water_indicator_label:
		water_indicator_label.text = "💧 x %d" % available_water

func _spawn_plants() -> void:
	# Spawn plants that need watering
	for i in range(12):  # Spawn 12 plants
		_spawn_plant()

func _spawn_plant() -> void:
	var plant_type = plant_types[randi() % plant_types.size()]
	
	var plant = Area2D.new()
	# Integer division on purpose: `row` is a row INDEX. This was `plants.size() / 4.0`,
	# float division, which advanced the row a quarter step per plant and turned the
	# intended 4x3 grid into a 12-step staircase (y = 150, 195, 240 … 645).
	@warning_ignore("integer_division")
	var row: int = plants.size() / 4
	var col: int = plants.size() % 4
	plant.position = Vector2(
		300 + col * 200,
		150 + row * 180
	)
	plant.set_meta("type", "plant")
	plant.set_meta("plant_data", plant_type)
	plant.set_meta("watered", false)
	plant.set_meta("spawn_time", Time.get_ticks_msec())
	add_child(plant)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = PLANT_SIZE / 2
	collision.shape = shape
	plant.add_child(collision)
	
	# Visual (dry plant)
	var visual = Sprite2D.new()
	visual.name = "Visual"
	visual.texture = MiniGameAssets.create_plant_texture(PLANT_TEX_PX, Color(0.5, 0.4, 0.3))
	# create_plant_texture() fills size x size pixels from GDScript, so the art is
	# generated once at 80 and scaled onto the 150-unit hit circle instead.
	visual.scale = Vector2.ONE * (PLANT_SIZE / float(PLANT_TEX_PX))
	visual.modulate = Color(0.7, 0.6, 0.5) # Dry look
	plant.add_child(visual)
	
	# Label
	var label = Label.new()
	label.name = "Label"
	label.text = Localization.get_text("mp_plant_dry")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -PLANT_SIZE * 0.5 - 24)
	label.add_theme_font_size_override("font_size", 18)
	MiniGameAssets.outline_text(label)
	plant.add_child(label)
	
	# Connect input
	plant.input_event.connect(_on_plant_clicked.bind(plant))
	
	plants.append(plant)

func _on_plant_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, plant: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_water_plant(plant)

func _try_water_plant(plant: Area2D) -> void:
	if not game_active:
		return
	
	if plant.get_meta("dead", false):
		_log("⚠️ That plant is gone — it wilted. Try another one!")
		return
	
	if plant.get_meta("watered", false):
		_log("⚠️ Plant already watered!")
		return
	
	if available_water <= 0:
		_log("⚠️ No water available! Wait for partner to wash vegetables")
		return
	
	# Use water
	available_water -= WATER_PER_PLANT
	_update_water_display()
	
	# Water the plant
	plant.set_meta("watered", true)
	plants_watered += 1
	_log("💧 Watered plant! (%d/%d)" % [plants_watered, QUOTA_P2])

	# Score for P2 (G-Counter) first, then test the quota. end_game() publishes
	# local_score to NetworkManager on the spot, so awarding afterwards reported a
	# score short by exactly this plant — measured as 7 against a true 8 by
	# tools/VerifyMPWashWater.tscn.
	add_score(POINTS_PER_PLANT, true, plant)
	
	# Check for win condition
	if plants_watered >= QUOTA_P2:
		end_game(true)
	
	# Update visual
	var visual = plant.get_node("Visual")
	var plant_data = plant.get_meta("plant_data")
	visual.modulate = plant_data["color"]  # Healthy color
	
	var label = plant.get_node("Label")
	label.text = Localization.get_text(str(plant_data["key"]))
	
	# Visual effect
	_play_water_effect(plant.global_position)
	
	# Reset the plant after some time (endless spawning)
	await get_tree().create_timer(PLANT_RECOVERY_SECONDS).timeout
	if is_instance_valid(plant):
		_make_plant_dry(plant)

func _check_wilted_plants() -> void:
	# Check for plants that wilted (not watered in time)
	var current_time = Time.get_ticks_msec()
	for plant in plants:
		if not is_instance_valid(plant):
			continue
		
		if bool(plant.get_meta("dead", false)) or bool(plant.get_meta("watered", false)):
			continue
		
		var spawn_time = plant.get_meta("spawn_time", current_time)
		var elapsed = (current_time - spawn_time) / 1000.0
		
		if elapsed > WILT_SECONDS:
			# A WILT ONLY COUNTS AGAINST THE TEAM IF THE PLAYER COULD HAVE PREVENTED IT
			#
			# Watering costs a unit of water only P1 can send. A plant that dried out while this
			# player had nothing to pour is P1's pace, not a mistake, and charging one of three
			# shared lives for it is the least fair thing a co-op round can do. The plant still
			# dies — that is the honest state of the garden — but the tally that spends lives
			# counts preventable deaths only. Gating the penalty instead of the tally would be
			# worse than not gating at all: the count would sit at MAX_WILTED through the whole
			# dry spell and take a life on the very frame P1's water arrived.
			var preventable: bool = available_water > 0
			if preventable:
				plants_wilted += 1
			_log("💀 Plant wilted! (%d/%d)%s" % [plants_wilted, MAX_WILTED,
				"" if preventable else " — no water to give, not charged"])
			# A dead plant is flagged `dead`, not `watered`. It used to borrow the
			# `watered` flag to keep itself from being counted twice, which made
			# _try_water_plant() answer "Plant already watered!" over a corpse and left
			# the plant dead for the rest of the round — a board that wilted faster than
			# the quota could no longer be finished at all.
			plant.set_meta("dead", true)
			plant.get_node("Visual").modulate = Color(0.3, 0.2, 0.1, 0.8)
			plant.get_node("Label").text = Localization.get_text("mp_plant_dead")
			_revive_plant_after(plant, PLANT_RECOVERY_SECONDS)
			
			if preventable and plants_wilted >= MAX_WILTED:
				_log("💔 Too many wilted plants - lose 1 life!")
				plants_wilted = 0
				report_miss_to_host(plant)

## Returns a plant to the dry, waterable state and restarts its wilt clock.
## Shared by the watered path and the wilted path so neither can strand a plant.
func _make_plant_dry(plant: Area2D) -> void:
	if not is_instance_valid(plant):
		return
	plant.set_meta("watered", false)
	plant.set_meta("dead", false)
	plant.set_meta("spawn_time", Time.get_ticks_msec())
	var visual := plant.get_node_or_null("Visual") as Sprite2D
	if visual:
		visual.modulate = Color(0.7, 0.6, 0.5)  # Back to dry
	var label := plant.get_node_or_null("Label") as Label
	if label:
		label.text = Localization.get_text("mp_plant_dry")

func _revive_plant_after(plant: Area2D, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	_make_plant_dry(plant)

func _on_resource_received(from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	# Receive dirty water from Player 1
	if resource_type == "dirty_water":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d dirty water from P%d (Total: %d)" % [amount, from_player, available_water])
		
		# Visual feedback
		var indicator = get_node_or_null("PanelContainer")
		if indicator:
			var tween = create_tween()
			tween.set_loops(1)
			tween.tween_property(indicator, "modulate", Color(0.5, 1.0, 1.0), 0.2)
			tween.tween_property(indicator, "modulate", Color.WHITE, 0.2)

func _play_water_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 25
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0, 200)
	particles.color = Color(0.3, 0.6, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _on_game_over() -> void:
	_log("Game over! Plants watered: %d" % plants_watered)
	super._on_game_over()
