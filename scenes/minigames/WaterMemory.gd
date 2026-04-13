extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## WATER MEMORY - Match pairs of water conservation icons
## ═══════════════════════════════════════════════════════════════════
## A classic memory card game where kids flip cards to find matching
## pairs of water-saving items. Educational + fun!

var card_pairs: Array = [
	["🚰", "🚰"], ["💧", "💧"], ["🌱", "🌱"],
	["🪣", "🪣"], ["☁️", "☁️"], ["🚿", "🚿"],
	["🌊", "🌊"], ["🧊", "🧊"], ["🌧️", "🌧️"],
	["🐟", "🐟"]
]

var grid_cols: int = 4
var grid_rows: int = 3
var total_pairs: int = 6
var pairs_found: int = 0
var first_card: Node = null
var second_card: Node = null
var can_flip: bool = true
var cards: Array = []
var screen_size: Vector2

func _apply_difficulty_settings() -> void:
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)

	match current_difficulty:
		"Easy":
			grid_cols = 3
			grid_rows = 2
			total_pairs = 3
			game_duration = 30.0
		"Medium":
			grid_cols = 4
			grid_rows = 3
			total_pairs = 6
			game_duration = 25.0
		"Hard":
			grid_cols = 4
			grid_rows = 4
			total_pairs = 8
			game_duration = 18.0

	if progressive_level > 0:
		game_duration = max(10.0, game_duration - progressive_level * 1.5)
		if progressive_level >= 3 and grid_cols * grid_rows < 16:
			grid_cols = 4
			grid_rows = 4
			total_pairs = 8
		game_duration = settings.get("time_limit", game_duration)

func _ready():
	game_name = "Water Memory"
	var fallback := "MATCH pairs of water-saving tips!\n"
	fallback += "Find all pairs before time runs out! 🧠"
	game_instruction_text = (
		Localization.get_text("water_memory_instructions")
		if Localization else fallback
	)
	game_duration = 30.0
	game_mode = "quota"

	super._ready()

	screen_size = get_viewport_rect().size

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.25, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)

	# Water pattern overlay
	for i in range(8):
		var wave = Label.new()
		wave.text = "〰️"
		wave.add_theme_font_size_override("font_size", 30)
		wave.modulate = Color(1, 1, 1, 0.1)
		wave.position = Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
		wave.z_index = -9
		add_child(wave)

	# Score display
	var score_display = Label.new()
	score_display.name = "PairScore"
	score_display.text = "🧠 0 / %d pairs" % total_pairs
	score_display.add_theme_font_size_override("font_size", 26)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(20, 120)
	add_child(score_display)

func _on_game_start() -> void:
	_build_card_grid()

func _build_card_grid() -> void:
	# Clear existing cards
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()

	# Pick pairs
	var selected_pairs = card_pairs.slice(0, total_pairs)
	var all_emojis: Array = []
	for pair in selected_pairs:
		all_emojis.append(pair[0])
		all_emojis.append(pair[1])

	# Shuffle
	for i in range(all_emojis.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var tmp = all_emojis[i]
		all_emojis[i] = all_emojis[j]
		all_emojis[j] = tmp

	# Calculate card layout
	var margin_x = 60.0
	var margin_top = 170.0
	var margin_bottom = 80.0
	var available_w = screen_size.x - margin_x * 2
	var available_h = screen_size.y - margin_top - margin_bottom
	var card_w = min(available_w / grid_cols - 10, 120.0)
	var card_h = min(available_h / grid_rows - 10, 120.0)
	var card_size = min(card_w, card_h)
	var total_w = grid_cols * (card_size + 10) - 10
	var total_h = grid_rows * (card_size + 10) - 10
	var start_x = (screen_size.x - total_w) / 2
	var start_y = margin_top + (available_h - total_h) / 2

	var idx = 0
	for row in range(grid_rows):
		for col in range(grid_cols):
			if idx >= all_emojis.size():
				break
			var pos = Vector2(
				start_x + col * (card_size + 10),
				start_y + row * (card_size + 10)
			)
			var card = _create_card(pos, all_emojis[idx], card_size)
			add_child(card)
			cards.append(card)
			idx += 1

func _create_card(pos: Vector2, emoji: String, card_size: float) -> Control:
	var card = Panel.new()
	card.size = Vector2(card_size, card_size)
	card.position = pos
	card.set_meta("emoji", emoji)
	card.set_meta("flipped", false)
	card.set_meta("matched", false)

	# Card back style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.45, 0.7)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.3, 0.6, 0.9)
	card.add_theme_stylebox_override("panel", style)

	# Question mark (face down)
	var back_label = Label.new()
	back_label.name = "BackLabel"
	back_label.text = "❓"
	back_label.add_theme_font_size_override("font_size", int(card_size * 0.5))
	back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(back_label)

	# Emoji (face up, hidden initially)
	var front_label = Label.new()
	front_label.name = "FrontLabel"
	front_label.text = emoji
	front_label.add_theme_font_size_override("font_size", int(card_size * 0.5))
	front_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	front_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	front_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	front_label.visible = false
	card.add_child(front_label)

	# Button overlay for tap
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_card_pressed.bind(card))
	card.add_child(btn)

	return card

func _on_card_pressed(card: Panel) -> void:
	if not game_active or not can_flip:
		return
	if card.get_meta("flipped", false) or card.get_meta("matched", false):
		return

	_flip_card(card, true)

	if first_card == null:
		first_card = card
	elif second_card == null:
		second_card = card
		can_flip = false
		# Check match after a short delay
		get_tree().create_timer(0.6).timeout.connect(_check_match)

func _flip_card(card: Panel, face_up: bool) -> void:
	card.set_meta("flipped", face_up)
	var back = card.get_node_or_null("BackLabel")
	var front = card.get_node_or_null("FrontLabel")
	if back:
		back.visible = not face_up
	if front:
		front.visible = face_up

	if face_up:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.85, 0.92, 1.0)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_color = Color(0.4, 0.7, 1.0)
		card.add_theme_stylebox_override("panel", style)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.45, 0.7)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_color = Color(0.3, 0.6, 0.9)
		card.add_theme_stylebox_override("panel", style)

	if AudioManager:
		AudioManager.play_collect()

func _check_match() -> void:
	if not is_instance_valid(first_card) or not is_instance_valid(second_card):
		can_flip = true
		first_card = null
		second_card = null
		return

	var emoji_1 = first_card.get_meta("emoji", "")
	var emoji_2 = second_card.get_meta("emoji", "")

	if emoji_1 == emoji_2:
		# Match found!
		first_card.set_meta("matched", true)
		second_card.set_meta("matched", true)
		pairs_found += 1
		record_action(true)

		# Matched glow effect
		for card in [first_card, second_card]:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.6, 0.95, 0.6)
			style.corner_radius_top_left = 12
			style.corner_radius_top_right = 12
			style.corner_radius_bottom_left = 12
			style.corner_radius_bottom_right = 12
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_color = Color(0.3, 0.9, 0.3)
			card.add_theme_stylebox_override("panel", style)

		# Update score
		var display = get_node_or_null("PairScore")
		if display:
			display.text = "🧠 %d / %d pairs" % [pairs_found, total_pairs]

		# Check win
		if pairs_found >= total_pairs:
			end_game(true)
	else:
		# No match - flip back
		record_action(false)
		_flip_card(first_card, false)
		_flip_card(second_card, false)

	first_card = null
	second_card = null
	can_flip = true
