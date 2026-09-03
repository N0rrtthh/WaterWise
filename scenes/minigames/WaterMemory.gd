extends "res://scripts/MiniGameBase.gd"

## ═══════════════════════════════════════════════════════════════════
## WATER MEMORY - Match pairs of water conservation icons
## ═══════════════════════════════════════════════════════════════════
## A classic memory card game where kids flip cards to find matching
## pairs of water-saving items. Educational + fun!

## Flip beat lengths, in seconds at normal motion speed. Total ~0.27 s: fast enough
## that a player mid-hunt does not wait on it, slow enough to read as a flip.
const FLIP_ANTICIPATE: float = 0.05
const FLIP_SQUEEZE: float = 0.09
const FLIP_RETURN: float = 0.13
## How long a wrong pair stays face-up after the recoil before turning back over.
const MISMATCH_HOLD: float = 0.35

var card_pairs: Array = [
	["🚰", "🚰"], ["💧", "💧"], ["🌱", "🌱"],
	["🌊", "🌊"], ["☁️", "☁️"], ["🚿", "🚿"],
	["🌧️", "🌧️"], ["🐟", "🐟"], ["🌼", "🌼"],
	["⛲", "⛲"]
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
			game_duration = 32.0
		"Hard":
			grid_cols = 4
			grid_rows = 4
			total_pairs = 8
			game_duration = 38.0

	# Progressive pressure applies AFTER the base duration is settled.
	#
	# The old order read `time_limit` from the difficulty settings on the last
	# line, which silently discarded the per-level subtraction above it — so
	# progressive_level had no effect on time at all. It also gave Hard 18 s to
	# clear 8 pairs on a 4x4 grid: 16 flips minimum with no mistakes, which is
	# under 1.1 s per flip including the mismatch flip-back animation. That is
	# not a difficulty curve, it is an unwinnable state.
	#
	# Base durations are now sized so a competent player finishes with a little
	# room, and the squeeze comes from progressive_level with a floor that keeps
	# the round mathematically completable.
	if progressive_level > 0:
		game_duration = maxf(_min_completable_duration(), game_duration - progressive_level * 1.5)

## Lower bound on the timer, derived from the board size rather than a constant.
##
## Each pair needs two flips, each flip needs a beat to read, and a mismatch
## costs a flip-back. 1.6 s per pair plus a 6 s buffer keeps even a maxed-out
## progressive level solvable for a player who is paying attention.
func _min_completable_duration() -> float:
	return 6.0 + float(total_pairs) * 1.6

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("water_memory", "Water Memory")
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
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
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
	score_display.text = _loc("hud_pairs_found", "🧠 %d / %d pairs") % [0, total_pairs]
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
	# scale.x on a Control grows from the top-left unless the pivot is moved, which
	# would make the flip below slide the card instead of hinging it in place.
	card.pivot_offset = card.size * 0.5

	card.add_theme_stylebox_override("panel",
		_card_style(Color(0.2, 0.45, 0.7), Color(0.3, 0.6, 0.9)))

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
		round_delay(0.6).connect(_check_match)

## The flip, as an animation instead of an assignment.
##
## This used to swap back.visible/front.visible and replace the StyleBoxFlat in the
## same frame, so a card changed face with nothing to read as a flip: no anticipation,
## no motion, and a matched pair announced itself only by quietly turning green. In a
## memory game the flip IS the feedback -- it is the moment the player commits and the
## moment they learn -- so it gets the three standard beats: anticipation (a small
## squash), the squeeze through near-zero width where the face is swapped at the hinge
## so the swap is never seen head-on, then the return with a slight overshoot.
##
## Durations go through JuiceEffects.motion_time() so the reduced-motion setting
## shortens the flip instead of this game ignoring the setting entirely. The budget in
## _min_completable_duration() already allows 1.6 s per pair "including the mismatch
## flip-back animation", which this fits inside.
func _flip_card(card: Panel, face_up: bool) -> void:
	card.set_meta("flipped", face_up)

	# A second flip landing on a card that is still mid-flip would leave two tweens
	# fighting over scale, and the loser strands the card at hairline width.
	# has_meta() first: get_meta(name, null) does NOT quietly return null, because a
	# NIL default is indistinguishable from "no default given" inside Godot, so every
	# first flip of every card printed "The object does not have any 'meta' values with
	# the key 'flip_tween'" -- 12 of them in one 7-minute soak.
	var prev: Variant = card.get_meta("flip_tween") if card.has_meta("flip_tween") else null
	if is_instance_valid(prev) and prev is Tween and prev.is_valid():
		prev.kill()
		card.scale = Vector2.ONE

	if face_up and AudioManager:
		# The success/failure cue belongs to record_action(); this is just the flip.
		AudioManager.play_whoosh()

	var t_ant: float = JuiceEffects.motion_time(FLIP_ANTICIPATE)
	var t_sqz: float = JuiceEffects.motion_time(FLIP_SQUEEZE)
	var t_out: float = JuiceEffects.motion_time(FLIP_RETURN * 0.65)
	var t_set: float = JuiceEffects.motion_time(FLIP_RETURN * 0.35)
	var t: Tween = card.create_tween()
	card.set_meta("flip_tween", t)
	t.tween_property(card, "scale", Vector2(1.06, 0.93), t_ant).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2(0.04, 1.05), t_sqz).set_ease(Tween.EASE_IN)
	t.tween_callback(_apply_card_face.bind(card, face_up))
	t.tween_property(card, "scale", Vector2(1.09, 0.95), t_out).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2.ONE, t_set)


## The face swap itself, fired at the hinge of the flip above.
func _apply_card_face(card: Panel, face_up: bool) -> void:
	if not is_instance_valid(card):
		return
	var back := card.get_node_or_null("BackLabel")
	var front := card.get_node_or_null("FrontLabel")
	if back:
		back.visible = not face_up
	if front:
		front.visible = face_up
	card.add_theme_stylebox_override("panel", _card_style(
		Color(0.85, 0.92, 1.0) if face_up else Color(0.2, 0.45, 0.7),
		Color(0.4, 0.7, 1.0) if face_up else Color(0.3, 0.6, 0.9)))


## One rounded panel style. The same twelve lines were written out four times.
func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = border
	return style


## A matched pair pops. The green stylebox alone was a state change with no event
## attached to it -- easy to miss on a 4x4 grid where the player is looking elsewhere.
func _pop_card(card: Panel) -> void:
	if not is_instance_valid(card):
		return
	var prev: Variant = card.get_meta("flip_tween") if card.has_meta("flip_tween") else null
	if is_instance_valid(prev) and prev is Tween and prev.is_valid():
		prev.kill()
	card.scale = Vector2.ONE
	var t: Tween = card.create_tween()
	card.set_meta("flip_tween", t)
	t.tween_property(card, "scale", Vector2(1.22, 1.22),
		JuiceEffects.motion_time(0.11)).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2.ONE,
		JuiceEffects.motion_time(0.17)).set_ease(Tween.EASE_IN_OUT)


## A wrong pair recoils, then holds before flipping back. The old code reverted both
## cards in the same frame the mismatch was decided, which reads as the cards being
## snatched away rather than as a miss the player made.
func _recoil_card(card: Panel) -> void:
	if not is_instance_valid(card):
		return
	var base: float = card.position.x
	var t: Tween = card.create_tween()
	var step: float = JuiceEffects.motion_time(0.045)
	t.tween_property(card, "position:x", base + 9.0, step)
	t.tween_property(card, "position:x", base - 9.0, step)
	t.tween_property(card, "position:x", base + 5.0, step)
	t.tween_property(card, "position:x", base, step)

func _check_match() -> void:
	# The round can end inside the 0.6s this resolve waits on -- the round timer
	# expiring, or the player quitting. Scoring the pair and feeding record_action()
	# into the adaptive-difficulty window after that point credits a round that is
	# already closed and banked. Nothing needs resetting on the way out: a new round
	# rebuilds the grid from scratch.
	if not game_active:
		return

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

		# Matched: green, plus a pop, so the match registers as an event and not only as a
		# colour the player has to notice on their own.
		for card in [first_card, second_card]:
			card.add_theme_stylebox_override("panel",
				_card_style(Color(0.6, 0.95, 0.6), Color(0.3, 0.9, 0.3)))
			_pop_card(card)

		var display = get_node_or_null("PairScore")
		if display:
			display.text = _loc("hud_pairs_found", "🧠 %d / %d pairs") % [pairs_found, total_pairs]

		first_card = null
		second_card = null
		can_flip = true

		if pairs_found >= total_pairs:
			end_game(true)
		return

	# No match. Recoil, hold the two faces up long enough to actually be read, then turn
	# them back over. The board stays locked for that whole beat -- releasing it early
	# lets a third tap land in a half-reverted pair.
	record_action(false)
	var a: Panel = first_card as Panel
	var b: Panel = second_card as Panel
	_recoil_card(a)
	_recoil_card(b)
	first_card = null
	second_card = null
	await round_delay(MISMATCH_HOLD)
	if not game_active:
		return
	if is_instance_valid(a):
		_flip_card(a, false)
	if is_instance_valid(b):
		_flip_card(b, false)
	can_flip = true
