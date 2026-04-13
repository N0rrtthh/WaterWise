extends Control

# =====================================================================
# INITIAL SCREEN — Dumb Ways to Die inspired main menu
# Light, bouncy, cartoon. Optimized for Cortex-A53 <3GB.
# =====================================================================
# Perf budget: <=15 tweens total, <=30 draw nodes, 0 particles.

@onready var droplet_label = $UI/TopLeft/CoinBG/HBox/DropletCount
@onready var droplet_icon = $UI/TopLeft/CoinBG/HBox/DropletIcon
@onready var play_button = $UI/ButtonContainer/PlayButton
@onready var multiplayer_button = $UI/ButtonContainer/MultiplayerButton
@onready var welcome_popup = $WelcomePopup
@onready var welcome_panel = $WelcomePopup/Panel
@onready var highscore_label = $UI/HighscorePanel/HighscoreLabel
@onready var next_unlock_panel = $UI/BottomLeft

# Pool of running tweens so we can kill them on exit
var _tweens: Array[Tween] = []

# Scene root containers
var _bg_layer: Node2D
var _char_layer: Node2D
var _title_node: Label

# Characters (max 4 for perf)
var _characters: Array[Node2D] = []
const MAX_BG_CHARS := 4
const CHAR_COLORS: Array[Color] = [
	Color(0.35, 0.72, 0.95),
	Color(0.55, 0.88, 0.55),
	Color(0.95, 0.72, 0.35),
	Color(0.88, 0.48, 0.72),
]
const CHAR_HATS: Array[String] = [
	"\U0001F380", "\U0001F3A9", "\U0001F452", "\U0001F9E2",
]


func _ready() -> void:
	_build_background()
	_spawn_characters()
	_build_title()
	_animate_entrance()

	# UI data
	if SaveManager:
		droplet_label.text = str(SaveManager.get_droplets())
		var hs = SaveManager.get_high_score()
		highscore_label.text = "%s: %d" % [
			Localization.get_text("high_score") if Localization else "HIGH SCORE",
			hs,
		]
	if ThemeManager:
		ThemeManager.apply_theme(self)
	_setup_welcome_popup()

	# Button connections
	play_button.pressed.connect(_on_play_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)


# ── Background ──────────────────────────────────────────────────────

func _build_background() -> void:
	var vp = get_viewport_rect().size
	_bg_layer = Node2D.new()
	_bg_layer.z_index = -10
	add_child(_bg_layer)
	move_child(_bg_layer, 0)

	# Gentle green hill
	var hill = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(21):
		var t = float(i) / 20.0
		var x = t * vp.x
		var y = vp.y * 0.65 + sin(t * PI) * -80.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(vp.x, vp.y))
	pts.append(Vector2(0, vp.y))
	hill.polygon = pts
	hill.color = Color(0.35, 0.75, 0.35)
	_bg_layer.add_child(hill)

	# Simple oval pool (border + water + shimmer)
	var cx = vp.x * 0.5
	var cy = vp.y * 0.72
	var pool_border = Polygon2D.new()
	pool_border.polygon = _oval(135, 55, 20)
	pool_border.position = Vector2(cx, cy)
	pool_border.color = Color(0.22, 0.55, 0.8)
	_bg_layer.add_child(pool_border)

	var pool_water = Polygon2D.new()
	pool_water.polygon = _oval(120, 44, 18)
	pool_water.position = Vector2(cx, cy)
	pool_water.color = Color(0.45, 0.82, 0.95)
	_bg_layer.add_child(pool_water)

	var shimmer = Polygon2D.new()
	shimmer.polygon = _oval(55, 16, 10)
	shimmer.position = Vector2(cx - 20, cy - 12)
	shimmer.color = Color(1, 1, 1, 0.18)
	_bg_layer.add_child(shimmer)


# ── Characters ──────────────────────────────────────────────────────

func _spawn_characters() -> void:
	var vp = get_viewport_rect().size
	_char_layer = Node2D.new()
	_char_layer.z_index = -5
	add_child(_char_layer)

	var spacing = vp.x / (MAX_BG_CHARS + 1)
	for i in range(MAX_BG_CHARS):
		var ch = _build_droplet(
			CHAR_COLORS[i], CHAR_HATS[i]
		)
		ch.position = Vector2(
			spacing * (i + 1), vp.y * 0.58
		)
		ch.scale = Vector2.ZERO  # start invisible for entrance
		_char_layer.add_child(ch)
		_characters.append(ch)


func _build_droplet(color: Color, hat: String) -> Node2D:
	var root = Node2D.new()

	# Body (teardrop)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -40), Vector2(18, -26), Vector2(26, -4),
		Vector2(22, 14), Vector2(12, 28), Vector2(0, 32),
		Vector2(-12, 28), Vector2(-22, 14), Vector2(-26, -4),
		Vector2(-18, -26),
	])
	body.color = color
	root.add_child(body)

	# Highlight
	var hl = Polygon2D.new()
	hl.polygon = PackedVector2Array([
		Vector2(-10, -30), Vector2(-6, -22),
		Vector2(-14, -18),
	])
	hl.color = Color(1, 1, 1, 0.35)
	root.add_child(hl)

	# Eyes
	for xoff in [-9, 9]:
		var ew = Polygon2D.new()
		ew.polygon = _oval(5.5, 6, 8)
		ew.position = Vector2(xoff, -6)
		ew.color = Color.WHITE
		root.add_child(ew)
		var pupil = Polygon2D.new()
		pupil.polygon = _oval(2.8, 3, 6)
		pupil.position = Vector2(xoff, -5)
		pupil.color = Color.BLACK
		root.add_child(pupil)

	# Smile
	var smile = Line2D.new()
	smile.points = PackedVector2Array([
		Vector2(-8, 6), Vector2(-3, 12),
		Vector2(3, 12), Vector2(8, 6),
	])
	smile.width = 2.0
	smile.default_color = Color(0.15, 0.15, 0.15)
	root.add_child(smile)

	# Arms
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.points = PackedVector2Array([
			Vector2(side * 22, 0), Vector2(side * 34, -10),
		])
		arm.width = 3.5
		arm.default_color = color.darkened(0.15)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		root.add_child(arm)

	# Legs
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.points = PackedVector2Array([
			Vector2(side * 8, 28), Vector2(side * 12, 42),
		])
		leg.width = 3.5
		leg.default_color = color.darkened(0.15)
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		root.add_child(leg)

	# Hat emoji
	var hat_lbl = Label.new()
	hat_lbl.text = hat
	hat_lbl.position = Vector2(-12, -62)
	hat_lbl.add_theme_font_size_override("font_size", 22)
	root.add_child(hat_lbl)

	return root


# ── Title ───────────────────────────────────────────────────────────

func _build_title() -> void:
	_title_node = Label.new()
	_title_node.text = "WATERWISE"
	_title_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_node.add_theme_font_size_override("font_size", 56)
	_title_node.add_theme_color_override("font_color", Color(1, 1, 1))
	_title_node.add_theme_color_override("font_outline_color", Color(0.1, 0.3, 0.6))
	_title_node.add_theme_constant_override("outline_size", 10)
	_title_node.position = Vector2(
		get_viewport_rect().size.x * 0.5 - 160, 18
	)
	_title_node.modulate.a = 0.0  # start hidden
	add_child(_title_node)


# ── Entrance animation ─────────────────────────────────────────────

func _animate_entrance() -> void:
	# Title slide-down
	var title_tw = create_tween()
	_tweens.append(title_tw)
	_title_node.position.y -= 40
	title_tw.tween_property(_title_node, "modulate:a", 1.0, 0.4)
	title_tw.parallel().tween_property(
		_title_node, "position:y",
		_title_node.position.y + 40, 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Title gentle sway (infinite)
	var sway = create_tween().set_loops()
	_tweens.append(sway)
	sway.tween_property(_title_node, "rotation", deg_to_rad(2), 1.8).set_trans(Tween.TRANS_SINE)
	sway.tween_property(_title_node, "rotation", deg_to_rad(-2), 1.8).set_trans(Tween.TRANS_SINE)

	# Characters staggered drop-in with squash-stretch
	for i in range(_characters.size()):
		var ch = _characters[i]
		var delay = 0.3 + i * 0.15
		var base_y = ch.position.y
		ch.position.y -= 200  # start above screen

		var drop = create_tween()
		_tweens.append(drop)
		drop.tween_interval(delay)
		drop.tween_property(ch, "scale", Vector2(0.8, 1.2), 0.01)
		drop.tween_property(
			ch, "position:y", base_y, 0.35
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Squash on land
		drop.tween_property(ch, "scale", Vector2(1.3, 0.6), 0.06)
		drop.tween_property(ch, "scale", Vector2(0.9, 1.15), 0.06)
		drop.tween_property(ch, "scale", Vector2(1.0, 1.0), 0.05)

	# Start idle loops after entrance finishes
	var idle_delay = create_tween()
	_tweens.append(idle_delay)
	idle_delay.tween_interval(0.3 + _characters.size() * 0.15 + 0.6)
	idle_delay.tween_callback(_start_idle_loops)

	# Play button pop-in
	play_button.scale = Vector2.ZERO
	play_button.pivot_offset = play_button.size * 0.5
	var btn_tw = create_tween()
	_tweens.append(btn_tw)
	btn_tw.tween_interval(0.8)
	var _s = btn_tw.tween_property(
		play_button, "scale", Vector2(1.15, 1.15), 0.15
	)
	_s.set_trans(Tween.TRANS_BACK)
	btn_tw.tween_property(play_button, "scale", Vector2(1.0, 1.0), 0.08)

	multiplayer_button.scale = Vector2.ZERO
	multiplayer_button.pivot_offset = multiplayer_button.size * 0.5
	var mbtn = create_tween()
	_tweens.append(mbtn)
	mbtn.tween_interval(1.0)
	var _ms = mbtn.tween_property(
		multiplayer_button, "scale",
		Vector2(1.15, 1.15), 0.15
	)
	_ms.set_trans(Tween.TRANS_BACK)
	mbtn.tween_property(multiplayer_button, "scale", Vector2(1.0, 1.0), 0.08)


func _start_idle_loops() -> void:
	for ch in _characters:
		var base_y = ch.position.y
		var bounce = create_tween().set_loops()
		_tweens.append(bounce)
		bounce.tween_property(
			ch, "position:y", base_y - 10, 0.55
		).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(
			ch, "scale", Vector2(1.05, 0.92), 0.12
		)
		bounce.tween_property(
			ch, "position:y", base_y, 0.55
		).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(
			ch, "scale", Vector2(1.0, 1.0), 0.12
		)


# ── Button handlers ─────────────────────────────────────────────────

func _on_play_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	# Characters squish + jump off
	for i in range(_characters.size()):
		var ch = _characters[i]
		var exit_tw = create_tween()
		exit_tw.tween_interval(i * 0.08)
		exit_tw.tween_property(ch, "scale", Vector2(1.3, 0.5), 0.08)
		exit_tw.tween_property(
			ch, "position:y", ch.position.y - 400, 0.35
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	# Transition after last character exits
	await get_tree().create_timer(0.6).timeout
	if GameManager:
		GameManager.start_session()
	else:
		get_tree().change_scene_to_file("res://scenes/minigames/MiniGame_Rain.tscn")


func _on_multiplayer_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.transition_to_scene("res://scenes/multiplayer/Lobby.tscn")


func _on_customize_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.transition_to_scene("res://scenes/ui/Customize.tscn")


func _on_store_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.transition_to_scene("res://scenes/ui/Store.tscn")


func _on_settings_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.transition_to_scene("res://scenes/ui/Settings.tscn")


func _on_accessibility_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if AccessibilityManager:
		AccessibilityManager.toggle_menu()


# ── Welcome popup ───────────────────────────────────────────────────

func _setup_welcome_popup() -> void:
	if not SaveManager:
		welcome_popup.visible = false
		return
	var first = SaveManager.is_first_launch()
	welcome_popup.visible = first
	if first:
		welcome_panel.modulate.a = 0.0
		welcome_panel.scale = Vector2(0.85, 0.85)
		var tw = create_tween()
		tw.tween_property(welcome_panel, "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(
			welcome_panel, "scale", Vector2(1.0, 1.0), 0.35
		).set_trans(Tween.TRANS_BACK)


func _on_welcome_ok_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	var tw = create_tween()
	tw.tween_property(welcome_panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): welcome_popup.visible = false)


# ── Helpers ─────────────────────────────────────────────────────────

func _oval(w: float, h: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a) * w, sin(a) * h))
	return pts


func _exit_tree() -> void:
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
