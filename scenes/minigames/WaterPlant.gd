extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## WATER PLANT — Tap thirsty plants to water them!
## ═══════════════════════════════════════════════════════════════════
## Each plant has a hydration meter. Plants get thirsty over time.
## TAP a thirsty plant to water it. Don't overwater healthy ones!
## Keep ALL plants alive until the timer runs out to win.
## ═══════════════════════════════════════════════════════════════════

var plants: Array[Dictionary] = []   # [{node, bar, emoji, hydration, wilt_rate}]
var screen_size: Vector2

## Difficulty-scaled
var num_plants: int = 4
var wilt_speed: float = 0.08

## Seconds of LIVE round, for the idle animations below. They used to read
## Time.get_ticks_msec(), which keeps advancing while the tree is paused — and
## MobileUIManager pauses the tree when the app loses focus — so pulling down a
## notification and coming back snapped every wiggling sprite to an unrelated phase.
## This clock only advances while game_active, so there is nothing to snap to.
var _anim_t: float = 0.0
var overwater_penalty: bool = false

const PLANT_EMOJIS := ["🌱", "🌿", "🌻", "🌼", "🌷", "🌾"]

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			num_plants = 3
			wilt_speed = 0.055
			overwater_penalty = false
			game_duration = 20.0
		"Medium":
			num_plants = 4
			wilt_speed = 0.08
			overwater_penalty = true
			game_duration = 25.0
		"Hard":
			num_plants = 5
			wilt_speed = 0.11
			overwater_penalty = true
			game_duration = 28.0

func _ready() -> void:
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("water_plant", "Water Plant")
	game_instruction_text = Localization.get_text("water_plant_instructions") if Localization else "TAP thirsty plants to water them! 🌱\nDon't let any plant die! 💧"
	game_duration = 25.0
	game_mode = "survival"
	show_quota = false

	super._ready()

	screen_size = get_viewport_rect().size

	# ── Background: garden scene ─────────────────────────────────────
	var sky = ColorRect.new()
	sky.color = Color(0.55, 0.82, 1.0)
	sky.position = Vector2.ZERO
	sky.size = get_viewport_rect().size
	sky.z_index = -10
	add_child(sky)

	# Sun
	var sun = Label.new()
	sun.text = "☀️"
	sun.add_theme_font_size_override("font_size", 72)
	# Clear of the HUD strip: at (x-110, 20) this 72px glyph sat behind the timer,
	# the score and the pause button, covering 93% and 100% of their boxes.
	sun.position = Vector2(screen_size.x - 150, 108)
	sun.z_index = -9
	add_child(sun)

	# Clouds
	for i in range(3):
		var cloud = Label.new()
		cloud.text = "☁️"
		cloud.add_theme_font_size_override("font_size", 44)
		cloud.position = Vector2(80 + i * 280, 30 + randf() * 40)
		cloud.modulate = Color(1, 1, 1, 0.7)
		cloud.z_index = -9
		add_child(cloud)

	# Dirt ground
	var dirt = ColorRect.new()
	dirt.color = Color(0.45, 0.32, 0.18)
	dirt.size = Vector2(screen_size.x, 180)
	dirt.position = Vector2(0, screen_size.y - 180)
	dirt.z_index = -5
	add_child(dirt)

	# Grass strip on top of dirt
	var grass = ColorRect.new()
	grass.color = Color(0.35, 0.65, 0.25)
	grass.size = Vector2(screen_size.x, 20)
	grass.position = Vector2(0, screen_size.y - 180)
	grass.z_index = -4
	add_child(grass)

	# Status label
	var status = Label.new()
	status.name = "StatusLabel"
	status.text = _loc("hud_keep_plants_alive", "🌱 Keep all plants alive!")
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 3)
	status.position = Vector2(screen_size.x / 2 - 120, 120)
	add_child(status)

func _on_game_start() -> void:
	_spawn_plants()

func _spawn_plants() -> void:
	var spacing = screen_size.x / (num_plants + 1)
	var base_y = screen_size.y - 280

	for i in range(num_plants):
		var x_pos = spacing * (i + 1)
		var emoji_text: String = PLANT_EMOJIS[i % PLANT_EMOJIS.size()]

		# ── Plant container ──────────────────────────────────────────
		var container = Node2D.new()
		container.position = Vector2(x_pos, base_y)
		add_child(container)

		# Pot (polygon trapezoid)
		var pot = Polygon2D.new()
		pot.polygon = PackedVector2Array([
			Vector2(-40, 10), Vector2(40, 10),
			Vector2(35, 70), Vector2(-35, 70)
		])
		pot.color = Color(0.65, 0.38, 0.22)
		container.add_child(pot)

		# Pot rim
		var rim = Polygon2D.new()
		rim.polygon = PackedVector2Array([
			Vector2(-44, 4), Vector2(44, 4),
			Vector2(42, 16), Vector2(-42, 16)
		])
		rim.color = Color(0.75, 0.45, 0.28)
		container.add_child(rim)

		# Dirt in pot
		var pot_dirt = Polygon2D.new()
		pot_dirt.polygon = PackedVector2Array([
			Vector2(-36, 16), Vector2(36, 16),
			Vector2(34, 28), Vector2(-34, 28)
		])
		pot_dirt.color = Color(0.4, 0.28, 0.15)
		container.add_child(pot_dirt)

		# Plant emoji
		var plant_lbl = Label.new()
		plant_lbl.name = "PlantEmoji"
		plant_lbl.text = emoji_text
		plant_lbl.add_theme_font_size_override("font_size", 64)
		plant_lbl.position = Vector2(-36, -80)
		container.add_child(plant_lbl)

		# Thirst bubble (shows when plant needs water)
		var bubble = Label.new()
		bubble.name = "ThirstBubble"
		bubble.text = "💧"
		bubble.add_theme_font_size_override("font_size", 28)
		bubble.position = Vector2(30, -95)
		bubble.visible = false
		container.add_child(bubble)

		# Hydration bar background
		var bar_bg = ColorRect.new()
		bar_bg.size = Vector2(60, 10)
		bar_bg.position = Vector2(-30, 78)
		bar_bg.color = Color(0.2, 0.2, 0.2, 0.7)
		container.add_child(bar_bg)

		# Hydration bar fill
		var bar_fill = ColorRect.new()
		bar_fill.name = "HydrationBar"
		bar_fill.size = Vector2(56, 6)
		bar_fill.position = Vector2(-28, 80)
		bar_fill.color = Color(0.3, 0.7, 1.0)
		container.add_child(bar_fill)

		# Tap button (invisible, covers the whole plant area)
		var btn = Button.new()
		btn.flat = true
		btn.position = Vector2(-50, -100)
		btn.size = Vector2(100, 180)
		btn.modulate = Color(1, 1, 1, 0)  # Invisible
		btn.pressed.connect(_on_plant_tapped.bind(i))
		container.add_child(btn)

		# Store plant data
		var plant_data: Dictionary = {
			"node": container,
			"emoji_label": plant_lbl,
			"bubble": bubble,
			"bar": bar_fill,
			"hydration": 0.7 + randf() * 0.3,  # Start mostly hydrated
			"wilt_rate": wilt_speed * (0.85 + randf() * 0.3),  # Slight per-plant variation
			"original_emoji": emoji_text,
		}
		plants.append(plant_data)

func _on_plant_tapped(index: int) -> void:
	if not game_active:
		return
	if index < 0 or index >= plants.size():
		return

	var plant = plants[index]
	var hydration: float = plant["hydration"]

	if hydration < 0.75:
		# Plant is thirsty — good tap!
		plant["hydration"] = min(1.0, hydration + 0.35)
		record_action(true)
		_show_water_effect(plant["node"].position)

		if AudioManager:
			AudioManager.play_collect()
	else:
		# Plant is already healthy — overwatering!
		if overwater_penalty:
			record_action(false)
			plant["hydration"] = min(1.0, hydration + 0.15)  # Still waters a bit
			_show_overwater_warning(plant["node"].position)
			if AudioManager:
				AudioManager.play_damage()
		else:
			# Easy mode: just do nothing, no penalty
			plant["hydration"] = min(1.0, hydration + 0.1)
			if AudioManager:
				AudioManager.play_click()

func _show_water_effect(pos: Vector2) -> void:
	var effect = Label.new()
	effect.text = "💧"
	effect.add_theme_font_size_override("font_size", 32)
	effect.position = pos + Vector2(-12, -30)
	add_child(effect)

	var tw = create_tween()
	tw.tween_property(effect, "position:y", effect.position.y - 40, 0.4)
	tw.parallel().tween_property(effect, "modulate:a", 0.0, 0.4)
	tw.tween_callback(effect.queue_free)

func _show_overwater_warning(pos: Vector2) -> void:
	var warn = Label.new()
	warn.text = _loc("hud_too_much_water", "💦 Too much!")
	warn.add_theme_font_size_override("font_size", 20)
	warn.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
	warn.add_theme_color_override("font_outline_color", Color.BLACK)
	warn.add_theme_constant_override("outline_size", 3)
	warn.position = pos + Vector2(-40, -50)
	add_child(warn)

	var tw = create_tween()
	tw.tween_property(warn, "position:y", warn.position.y - 30, 0.5)
	tw.parallel().tween_property(warn, "modulate:a", 0.0, 0.5)
	tw.tween_callback(warn.queue_free)

func _process(delta: float) -> void:
	super._process(delta)
	if not game_active:
		return
	_anim_t += delta

	var any_dead := false
	var all_count := 0
	var healthy_count := 0

	for plant in plants:
		# Dehydrate over time
		plant["hydration"] = max(0.0, plant["hydration"] - plant["wilt_rate"] * delta)
		var h: float = plant["hydration"]

		# Update hydration bar
		var bar: ColorRect = plant["bar"]
		if bar and is_instance_valid(bar):
			bar.size.x = 56.0 * h

			# Color: blue → yellow → red
			if h > 0.6:
				bar.color = Color(0.3, 0.7, 1.0)
			elif h > 0.3:
				bar.color = Color(0.95, 0.8, 0.2)
			else:
				bar.color = Color(0.95, 0.3, 0.2)

		# Update plant visual
		var emoji_lbl: Label = plant["emoji_label"]
		if emoji_lbl and is_instance_valid(emoji_lbl):
			if h <= 0.0:
				emoji_lbl.text = "🥀"  # Dead
				emoji_lbl.modulate = Color(0.5, 0.5, 0.5)
			elif h < 0.25:
				emoji_lbl.text = "🍂"  # Very dry — wilting badly
				emoji_lbl.modulate = Color(0.8, 0.7, 0.5)
			elif h < 0.5:
				emoji_lbl.text = plant["original_emoji"]
				emoji_lbl.modulate = Color(0.85, 0.85, 0.6)  # Slightly yellow
			else:
				emoji_lbl.text = plant["original_emoji"]
				emoji_lbl.modulate = Color.WHITE  # Healthy

		# Show/hide thirst bubble
		var bubble: Label = plant["bubble"]
		if bubble and is_instance_valid(bubble):
			bubble.visible = (h < 0.4 and h > 0.0)
			# Pulse the bubble
			if bubble.visible:
				bubble.modulate.a = 0.6 + sin(_anim_t * 6.0) * 0.4

		# Track stats
		all_count += 1
		if h > 0.3:
			healthy_count += 1
		if h <= 0.0:
			any_dead = true

	# Update status
	var status_lbl = get_node_or_null("StatusLabel")
	if status_lbl:
		if any_dead:
			status_lbl.text = _loc("hud_plant_died", "🥀 A plant died!")
			status_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
		else:
			status_lbl.text = _loc("hud_plants_happy", "🌱 %d/%d plants happy") % [healthy_count, all_count]

	# Lose if any plant dies
	if any_dead:
		end_game(false)
