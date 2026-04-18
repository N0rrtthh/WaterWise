extends Control

@onready var result_title = $CenterContainer/VBoxContainer/ResultTitle
@onready var accuracy_label = $CenterContainer/VBoxContainer/Stats/Accuracy
@onready var time_label = $CenterContainer/VBoxContainer/Stats/Time
@onready var mistakes_label = $CenterContainer/VBoxContainer/Stats/Mistakes
@onready var difficulty_label = $CenterContainer/VBoxContainer/Stats/Difficulty

var current_accuracy: float = 0.0
var _round_score: int = 0
var _lives_left: int = 3
var _max_lives: int = 3
var _character_nodes: Array[Node2D] = []

# DWTD-style palette
const BG_CREAM := Color(0.96, 0.93, 0.87)
const DROP_BLUE := Color(0.42, 0.76, 0.95)
const DROP_BLUE_DARK := Color(0.32, 0.62, 0.88)
const DROP_BLUE_PALE := Color(0.65, 0.88, 1.0)
const YELLOW_BTN := Color(0.92, 0.82, 0.32)
const PINK_BTN := Color(0.9, 0.45, 0.52)
const TEXT_DARK := Color(0.22, 0.22, 0.2)
const TEXT_MID := Color(0.38, 0.38, 0.34)
const STEAM_COL := Color(0.78, 0.9, 1.0, 0.5)

func _ready() -> void:
	await get_tree().process_frame
	_fetch_data()
	_build_dwtd_background()
	_build_lives_characters()
	_build_score_display()
	_display_stat_lines()
	_setup_buttons()
	if AudioManager:
		AudioManager.play_fanfare()

func _fetch_data() -> void:
	if not GameManager:
		return
	_lives_left = GameManager.team_lives
	_max_lives = GameManager.MAX_TEAM_LIVES
	if AdaptiveDifficulty and AdaptiveDifficulty.performance_history.size() > 0:
		var last_perf = AdaptiveDifficulty.performance_history[-1]
		current_accuracy = last_perf["accuracy"]
		var time_ms = last_perf["reaction_time"]
		var mistakes = last_perf["mistakes"]
		var difficulty = last_perf["difficulty"]
		accuracy_label.text = "Accuracy: %.0f%%" % (current_accuracy * 100)
		time_label.text = "Time: %.1fs" % (time_ms / 1000.0)
		mistakes_label.text = "Mistakes: %d" % mistakes
		difficulty_label.text = "Difficulty: %s" % difficulty
	if GameManager.round_scores.size() > 0:
		_round_score = int(GameManager.round_scores[-1].get("score", 0))

# ═════════════════════════════════════════════════════════════
# DWTD-STYLE WARM BACKGROUND
# ═════════════════════════════════════════════════════════════

func _build_dwtd_background() -> void:
	var bg = get_node_or_null("Background")
	if bg:
		bg.color = BG_CREAM

	# Hide the default layout — we draw everything procedurally
	$CenterContainer.visible = false

	# Soft ground strip at bottom
	var vp = get_viewport_rect().size
	var ground = ColorRect.new()
	ground.size = Vector2(vp.x, vp.y * 0.18)
	ground.position = Vector2(0, vp.y * 0.82)
	ground.color = Color(0.90, 0.85, 0.76)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

# ═════════════════════════════════════════════════════════════
# WATER DROP LIVES (alive = water drop character, lost = evaporation)
# ═════════════════════════════════════════════════════════════

func _build_lives_characters() -> void:
	var vp = get_viewport_rect().size
	var total_slots = _max_lives
	var slot_width = 150.0
	var total_width = total_slots * slot_width
	var start_x = (vp.x - total_width) / 2.0 + slot_width / 2.0
	var char_y = vp.y * 0.32

	for i in range(total_slots):
		var slot_x = start_x + i * slot_width
		var is_alive = i < _lives_left

		if is_alive:
			_spawn_water_drop(Vector2(slot_x, char_y), i)
		else:
			_spawn_evaporating_drop(Vector2(slot_x, char_y), i)

# ── Alive water drop character (teardrop shape with face, arms, legs) ──
func _spawn_water_drop(pos: Vector2, idx: int) -> void:
	var character = Node2D.new()
	character.position = pos
	character.scale = Vector2.ZERO
	character.modulate.a = 0.0
	add_child(character)
	_character_nodes.append(character)

	# Slightly varied tints per slot
	var tints = [DROP_BLUE, Color(0.48, 0.78, 0.96), Color(0.38, 0.72, 0.92)]
	var body_col = tints[idx % tints.size()]

	# ── Teardrop body (pointed top, round bottom) ──
	var body = Polygon2D.new()
	body.name = "Body"
	var pts = PackedVector2Array()
	# Build teardrop: narrow top tip → widens → round bottom
	pts.append(Vector2(0, -48))  # tip
	# Right side curve
	for i in range(1, 13):
		var t = float(i) / 12.0
		var rx = 34.0 * sin(t * PI * 0.92)
		var ry = -48 + t * 96
		pts.append(Vector2(rx, ry))
	# Bottom arc
	for i in range(8):
		var a = float(i) / 7.0 * PI
		pts.append(Vector2(cos(a) * 34, 48 + sin(a) * 6))
	# Left side curve (mirror)
	for i in range(12, 0, -1):
		var t = float(i) / 12.0
		var rx = -34.0 * sin(t * PI * 0.92)
		var ry = -48 + t * 96
		pts.append(Vector2(rx, ry))
	body.polygon = pts
	body.color = body_col
	character.add_child(body)

	# ── Highlight shine on upper body ──
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-6, -34), Vector2(2, -40), Vector2(6, -30), Vector2(0, -24),
	])
	shine.color = Color(1, 1, 1, 0.45)
	character.add_child(shine)

	# ── Big cute eyes ──
	for xoff in [-12, 12]:
		var eye = Polygon2D.new()
		var ep = PackedVector2Array()
		for i in range(14):
			var a = i * TAU / 14
			ep.append(Vector2(cos(a) * 9, sin(a) * 10) + Vector2(xoff, -4))
		eye.polygon = ep
		eye.color = Color.WHITE
		character.add_child(eye)

		var pupil = Polygon2D.new()
		var pp = PackedVector2Array()
		for i in range(10):
			var a = i * TAU / 10
			pp.append(Vector2(cos(a) * 4.5, sin(a) * 5) + Vector2(xoff, -2))
		pupil.polygon = pp
		pupil.color = Color(0.08, 0.08, 0.08)
		character.add_child(pupil)

		# Eye sparkle
		var sparkle = Polygon2D.new()
		sparkle.polygon = PackedVector2Array([
			Vector2(0, -2), Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0),
		])
		sparkle.position = Vector2(xoff - 2, -6)
		sparkle.color = Color(1, 1, 1, 0.9)
		character.add_child(sparkle)

	# ── Happy smile ──
	var mouth = Line2D.new()
	mouth.width = 2.5
	mouth.default_color = Color(0.12, 0.12, 0.12)
	for i in range(7):
		var mt = float(i) / 6.0
		var mx = lerp(-10.0, 10.0, mt)
		var my = 14.0 + sin(mt * PI) * 7.0
		mouth.add_point(Vector2(mx, my))
	character.add_child(mouth)

	# ── Rosy blush cheeks ──
	for sx in [-18, 18]:
		var blush = Polygon2D.new()
		var bp = PackedVector2Array()
		for i in range(8):
			var a = i * TAU / 8
			bp.append(Vector2(cos(a) * 6, sin(a) * 3.5) + Vector2(sx, 10))
		blush.polygon = bp
		blush.color = Color(0.95, 0.5, 0.55, 0.25)
		character.add_child(blush)

	# ── Noodly arms ──
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.name = "Arm_L" if side < 0 else "Arm_R"
		arm.width = 4.5
		arm.default_color = body_col.darkened(0.08)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		var wave_off = idx * 0.4
		arm.add_point(Vector2(side * 30, 6))
		arm.add_point(Vector2(side * 44, -8 + sin(wave_off) * 6))
		arm.add_point(Vector2(side * 50, -24 + cos(wave_off) * 5))
		character.add_child(arm)

	# ── Stubby legs ──
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.width = 5.0
		leg.default_color = body_col.darkened(0.12)
		leg.add_point(Vector2(side * 12, 48))
		leg.add_point(Vector2(side * 14, 62))
		leg.add_point(Vector2(side * 18, 66))
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		character.add_child(leg)

	# ── Bounce-in entrance (staggered) ──
	var delay = 0.3 + idx * 0.2
	var enter = create_tween()
	enter.tween_interval(delay)
	enter.tween_property(character, "modulate:a", 1.0, 0.08)
	enter.tween_property(character, "scale", Vector2(1.3, 0.5), 0.12).set_ease(Tween.EASE_OUT)
	enter.tween_property(character, "scale", Vector2(0.75, 1.3), 0.12).set_ease(Tween.EASE_OUT)
	enter.tween_property(character, "scale", Vector2(1.1, 0.9), 0.08)
	enter.tween_property(character, "scale", Vector2(1.0, 1.0), 0.06)

	# ── Idle bounce loop ──
	var idle = create_tween().set_loops()
	idle.tween_interval(delay + 0.5)
	idle.tween_property(character, "position:y", pos.y - 6, 0.45).set_trans(Tween.TRANS_SINE)
	idle.tween_property(character, "scale", Vector2(1.03, 0.97), 0.18)
	idle.tween_property(character, "position:y", pos.y, 0.45).set_trans(Tween.TRANS_SINE)
	idle.tween_property(character, "scale", Vector2(0.97, 1.03), 0.18)
	idle.tween_property(character, "scale", Vector2(1.0, 1.0), 0.1)

	# ── Arm wave (offset per character) ──
	var arm_l = character.get_node_or_null("Arm_L")
	var arm_r = character.get_node_or_null("Arm_R")
	if arm_l:
		var wave = create_tween().set_loops()
		wave.tween_interval(delay + 0.3 + idx * 0.15)
		wave.tween_property(arm_l, "rotation_degrees", -16.0, 0.35)
		wave.tween_property(arm_l, "rotation_degrees", 6.0, 0.35)
		wave.tween_property(arm_l, "rotation_degrees", 0.0, 0.25)
	if arm_r:
		var wave2 = create_tween().set_loops()
		wave2.tween_interval(delay + 0.5 + idx * 0.15)
		wave2.tween_property(arm_r, "rotation_degrees", 16.0, 0.35)
		wave2.tween_property(arm_r, "rotation_degrees", -6.0, 0.35)
		wave2.tween_property(arm_r, "rotation_degrees", 0.0, 0.25)

# ── Lost life: water drop evaporation animation ──
func _spawn_evaporating_drop(pos: Vector2, idx: int) -> void:
	var character = Node2D.new()
	character.position = pos
	character.scale = Vector2.ZERO
	character.modulate.a = 0.0
	add_child(character)
	_character_nodes.append(character)

	var ghost_col = Color(0.65, 0.82, 0.95, 0.35)

	# ── Ghost teardrop outline (faded, like it was once there) ──
	var ghost_body = Polygon2D.new()
	var pts = PackedVector2Array()
	pts.append(Vector2(0, -48))
	for i in range(1, 13):
		var t = float(i) / 12.0
		var rx = 34.0 * sin(t * PI * 0.92)
		var ry = -48 + t * 96
		pts.append(Vector2(rx, ry))
	for i in range(8):
		var a = float(i) / 7.0 * PI
		pts.append(Vector2(cos(a) * 34, 48 + sin(a) * 6))
	for i in range(12, 0, -1):
		var t = float(i) / 12.0
		var rx = -34.0 * sin(t * PI * 0.92)
		var ry = -48 + t * 96
		pts.append(Vector2(rx, ry))
	ghost_body.polygon = pts
	ghost_body.color = ghost_col
	character.add_child(ghost_body)

	# ── Sad X-eyes on ghost ──
	for xoff in [-12, 12]:
		for rot in [-0.6, 0.6]:
			var x_line = Line2D.new()
			x_line.width = 2.5
			x_line.default_color = Color(0.5, 0.6, 0.7, 0.4)
			x_line.add_point(Vector2(xoff - 4, -8))
			x_line.add_point(Vector2(xoff + 4, 2))
			x_line.rotation = rot
			character.add_child(x_line)

	# ── Wobbly sad mouth ──
	var mouth = Line2D.new()
	mouth.width = 2.0
	mouth.default_color = Color(0.5, 0.6, 0.7, 0.4)
	for i in range(5):
		var mt = float(i) / 4.0
		mouth.add_point(Vector2(lerp(-8.0, 8.0, mt), 16.0 - sin(mt * PI) * 4.0))
	character.add_child(mouth)

	# ── Steam/vapor particles rising from ghost ──
	var steam_container = Node2D.new()
	steam_container.name = "Steam"
	character.add_child(steam_container)

	for i in range(5):
		var steam = Polygon2D.new()
		steam.name = "SteamPuff_%d" % i
		var sp = PackedVector2Array()
		var sz = randf_range(4, 8)
		for j in range(8):
			var a = j * TAU / 8
			sp.append(Vector2(cos(a) * sz, sin(a) * sz * 0.65))
		steam.polygon = sp
		steam.color = STEAM_COL
		steam.position = Vector2(randf_range(-20, 20), randf_range(-30, 10))
		steam.modulate.a = 0.0
		steam_container.add_child(steam)

	# ── Small puddle below (residue) ──
	var puddle = Polygon2D.new()
	var puddle_pts = PackedVector2Array()
	for i in range(12):
		var a = i * TAU / 12
		puddle_pts.append(Vector2(cos(a) * 22, sin(a) * 5) + Vector2(0, 54))
	puddle.polygon = puddle_pts
	puddle.color = Color(0.6, 0.8, 0.95, 0.3)
	character.add_child(puddle)

	# ── Entrance: appear then evaporate ──
	var delay = 0.5 + idx * 0.25
	var enter = create_tween()
	enter.tween_interval(delay)
	enter.tween_property(character, "modulate:a", 1.0, 0.2)
	enter.tween_property(
		character, "scale", Vector2(1.0, 1.0), 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Wobble then shrink (evaporation)
	var evap = create_tween()
	evap.tween_interval(delay + 0.5)
	evap.tween_property(ghost_body, "scale", Vector2(1.05, 0.95), 0.15)
	evap.tween_property(ghost_body, "scale", Vector2(0.95, 1.05), 0.15)
	evap.tween_property(ghost_body, "scale", Vector2(0.7, 0.7), 0.6).set_ease(Tween.EASE_IN)
	evap.tween_property(ghost_body, "modulate:a", 0.15, 0.4)

	# Steam puffs rise upward in sequence
	for i in range(5):
		var puff = steam_container.get_node("SteamPuff_%d" % i)
		var st = create_tween()
		st.tween_interval(delay + 0.6 + i * 0.18)
		st.tween_property(puff, "modulate:a", 0.6, 0.2)
		st.tween_property(
			puff, "position:y", puff.position.y - 40 - randf_range(10, 30), 1.2
		).set_ease(Tween.EASE_OUT)
		var sf = create_tween()
		sf.tween_interval(delay + 1.2 + i * 0.18)
		sf.tween_property(puff, "modulate:a", 0.0, 0.5)

# ═════════════════════════════════════════════════════════════
# SCORE DISPLAY — "YOU EARNED" + big number
# ═════════════════════════════════════════════════════════════

func _build_score_display() -> void:
	var vp = get_viewport_rect().size

	var earned_label = Label.new()
	earned_label.text = "YOU EARNED"
	earned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	earned_label.add_theme_font_size_override("font_size", 32)
	earned_label.add_theme_color_override("font_color", TEXT_MID)
	earned_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	earned_label.position = Vector2(-120, vp.y * 0.54)
	earned_label.size = Vector2(240, 44)
	earned_label.modulate.a = 0.0
	earned_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(earned_label)

	var score_num = Label.new()
	score_num.name = "ScoreNumber"
	score_num.text = "0"
	score_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_num.add_theme_font_size_override("font_size", 78)
	score_num.add_theme_color_override("font_color", TEXT_DARK)
	score_num.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_num.position = Vector2(-160, vp.y * 0.54 + 38)
	score_num.size = Vector2(320, 95)
	score_num.modulate.a = 0.0
	score_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_num)

	# Animate entrance
	var tw1 = create_tween()
	tw1.tween_interval(0.9)
	tw1.tween_property(earned_label, "modulate:a", 1.0, 0.3)
	tw1.tween_property(score_num, "modulate:a", 1.0, 0.2)

	# Count up animation
	var count_tw = create_tween()
	count_tw.tween_interval(1.2)
	count_tw.tween_method(func(val: float):
		score_num.text = str(int(val))
	, 0.0, float(_round_score), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Pop on finish
	var pop_tw = create_tween()
	pop_tw.tween_interval(2.2)
	pop_tw.tween_property(score_num, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tw.tween_property(score_num, "scale", Vector2(0.95, 0.95), 0.08)
	pop_tw.tween_property(score_num, "scale", Vector2(1.0, 1.0), 0.06)

func _display_stat_lines() -> void:
	var vp = get_viewport_rect().size

	var stats_container = VBoxContainer.new()
	stats_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stats_container.position = Vector2(-160, vp.y * 0.54 + 130)
	stats_container.size = Vector2(320, 100)
	stats_container.add_theme_constant_override("separation", 4)
	stats_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_container)

	var stat_texts: Array[String] = []
	if AdaptiveDifficulty and AdaptiveDifficulty.performance_history.size() > 0:
		var last_perf = AdaptiveDifficulty.performance_history[-1]
		stat_texts.append("ACCURACY  %.0f%%" % (last_perf["accuracy"] * 100))
		stat_texts.append("MISTAKES  %d" % last_perf["mistakes"])

	for i in stat_texts.size():
		var lbl = Label.new()
		lbl.text = stat_texts[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", TEXT_MID)
		lbl.modulate.a = 0.0
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_container.add_child(lbl)

		var st = create_tween()
		st.tween_interval(2.4 + i * 0.2)
		st.tween_property(lbl, "modulate:a", 1.0, 0.3)

# ═════════════════════════════════════════════════════════════
# BUTTONS — Reparent from hidden CenterContainer to visible root
# ═════════════════════════════════════════════════════════════

func _setup_buttons() -> void:
	var buttons_node = $CenterContainer/VBoxContainer/Buttons
	if not buttons_node:
		return

	var continue_btn = buttons_node.get_node_or_null("ContinueButton")
	var retry_btn = buttons_node.get_node_or_null("RetryButton")

	# Create a new visible container at the bottom
	var btn_row = HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_row.position = Vector2(-220, -90)
	btn_row.size = Vector2(440, 70)
	btn_row.add_theme_constant_override("separation", 24)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.modulate.a = 0.0
	add_child(btn_row)

	# Reparent each button with DWTD pill style
	for btn in [continue_btn, retry_btn]:
		if not btn:
			continue
		btn.get_parent().remove_child(btn)
		btn_row.add_child(btn)

		var style = StyleBoxFlat.new()
		if btn.name == "ContinueButton":
			style.bg_color = YELLOW_BTN
			btn.text = "CONTINUE"
		else:
			style.bg_color = PINK_BTN
			btn.text = "RETRY"
		style.corner_radius_top_left = 28
		style.corner_radius_top_right = 28
		style.corner_radius_bottom_right = 28
		style.corner_radius_bottom_left = 28
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", style)
		var hover = style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.12)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed = style.duplicate()
		pressed.bg_color = style.bg_color.darkened(0.1)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.custom_minimum_size = Vector2(170, 52)

	# Hide the original title
	if result_title:
		result_title.visible = false

	# Fade in buttons
	var btw = create_tween()
	btw.tween_interval(2.6)
	btw.tween_property(btn_row, "modulate:a", 1.0, 0.35)

func _on_continue_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.start_next_minigame()

func _on_retry_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.replay_current_minigame()
