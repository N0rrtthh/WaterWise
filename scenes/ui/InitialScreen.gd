extends Control

# =====================================================================
# INITIAL SCREEN — Dumb Ways to Die inspired main menu
# Light, bouncy, cartoon. Optimized for Cortex-A53 <3GB.
# =====================================================================
# Perf budget: <=15 tweens total, <=30 draw nodes, 0 particles.

@onready var droplet_label = $UI/TopLeft/CoinBG/HBox/DropletCount
@onready var droplet_icon = $UI/TopLeft/CoinBG/HBox/DropletIcon
@onready var ui_root = $UI
@onready var top_left_panel = $UI/TopLeft
@onready var top_right_panel = $UI/TopRight
@onready var button_container = $UI/ButtonContainer
@onready var highscore_panel = $UI/HighscorePanel
@onready var play_button = $UI/ButtonContainer/PlayButton
@onready var multiplayer_button = $UI/ButtonContainer/MultiplayerButton
@onready var customize_button = $UI/TopRight/CustomizeButton
@onready var store_button = $UI/TopRight/StoreButton
@onready var roadmap_button = $UI/TopRight/RoadmapButton
@onready var settings_button = $UI/TopRight/SettingsButton
@onready var welcome_popup = $WelcomePopup
@onready var welcome_panel = $WelcomePopup/Panel
@onready var close_button = $WelcomePopup/Panel/CloseButton
@onready var highscore_label = $UI/HighscorePanel/HighscoreLabel
@onready var next_unlock_panel = $UI/BottomLeft
@onready var next_unlock_progress = $UI/BottomLeft/VBox/Progress
@onready var next_unlock_label = $UI/BottomLeft/VBox/ItemName

# Pool of running tweens so we can kill them on exit
var _tweens: Array[Tween] = []

var _is_loading_game: bool = false
var _loading_overlay: Control
var _loading_bar: ProgressBar
var _loading_text: Label
var _loading_started_ms: int = 0

const MIN_LOADING_VISIBLE_MS: int = 500
const UI_FONT_BRICK := preload("res://fonts/NTBrickSans.otf")


# Scene root containers
var _bg_layer: Node2D
var _char_layer: Node2D
var _title_node: Label
var _main_character: Node2D


# PSD background layers
var _wave_sprites: Array = []  # TextureRect nodes for wave animation
var _wave_base_y: Array[float] = []  # base Y position per wave layer
var _wave_time: float = 0.0
# Per-layer: [scroll_speed, vert_amplitude, vert_speed, phase_offset]
const _WAVE_CFG: Array = [
	[0.04, 2.0, 0.30, 0.0],   # Waves1 — back, very gentle
	[0.06, 3.0, 0.40, 1.4],   # Waves2 — mid
	[0.09, 4.0, 0.50, 2.8],   # Waves3 — front, slightly livelier
]
var _cloud_nodes: Array = []
var _psd_scale: float = 1.0
var _psd_offset: Vector2 = Vector2.ZERO
var _signboard_label: Label
const PSD_SIZE := Vector2(2360, 1640)

# Crowd characters on the platform
var _characters: Array[Node2D] = []
var _crowd_walk_speeds: Array[float] = []   # px/sec per character
var _crowd_walk_dirs: Array[float] = []     # +1 or -1
var _crowd_left_bound: float = 0.0
var _crowd_right_bound: float = 0.0
var _crowd_idle_started: bool = false
const MAX_CROWD_CHARS := 10
# Persists across scene reloads — skip drop-in on return visits
static var _has_been_shown: bool = false

# Decorations (boat, etc.)
var _boat_node: Node2D
const CHAR_COLORS: Array[Color] = [
	Color(0.35, 0.72, 0.95),
	Color(0.55, 0.88, 0.55),
	Color(0.95, 0.72, 0.35),
	Color(0.88, 0.48, 0.72),
]
const CHAR_HATS: Array[String] = [
	"\U0001F380", "\U0001F3A9", "\U0001F452", "\U0001F9E2",
]
const CHARACTER_UNLOCK_THRESHOLDS: Array[int] = [0, 50, 100, 150, 200, 300, 400, 500]
const MAIN_CHARACTER_PRESETS: Dictionary = {
	"droppy_blue": {"color": Color(0.3, 0.6, 1.0), "hat": "💧", "name": "Droppy", "trait": "hero"},
	"pinky": {"color": Color(1.0, 0.6, 0.8), "hat": "🎀", "name": "Pinky", "trait": "dancer"},
	"minty": {"color": Color(0.6, 1.0, 0.8), "hat": "🧢", "name": "Minty", "trait": "jogger"},
	"sunny": {"color": Color(1.0, 0.9, 0.4), "hat": "☀️", "name": "Sunny", "trait": "jumper"},
	"lavvy": {"color": Color(0.8, 0.6, 1.0), "hat": "✨", "name": "Lavvy", "trait": "waver"},
	"peachy": {"color": Color(1.0, 0.8, 0.7), "hat": "🍑", "name": "Peachy", "trait": "spinner"},
	"cyanny": {"color": Color(0.4, 1.0, 1.0), "hat": "🌊", "name": "Cyanny", "trait": "bouncer"},
	"coral": {"color": Color(1.0, 0.5, 0.5), "hat": "🪸", "name": "Coral", "trait": "cheerer"},
}
const BG_CHARACTER_ROLES: Array[String] = [
	"dancer", "musician", "baller", "cheerer",
]
const HERO_BASE_SCALE := 1.9
const HERO_BOUNCE_AMPLITUDE := 8.0
const MOBILE_HERO_SCALE_MULTIPLIER := 0.82
const MOBILE_HERO_BOUNCE_MULTIPLIER := 0.72


func _ready() -> void:
	_ensure_fullscreen_backdrop()
	_build_background()
	_spawn_characters()
	_build_title()
	_setup_signboard_highscore()
	_apply_responsive_layout()
	_animate_entrance()
	_animate_waves()
	_animate_clouds()
	_spawn_decorations()

	# Re-layout when viewport resizes (mobile rotation, window drag, etc.)
	get_viewport().size_changed.connect(_on_viewport_resized)

	# UI data
	if SaveManager:
		droplet_label.text = str(SaveManager.get_droplets())
		_update_next_unlock_panel(SaveManager.get_droplets())
	else:
		droplet_label.text = "0"
		_update_next_unlock_panel(0)

	# NOTE: Skip ThemeManager.apply_theme on InitialScreen — it overrides
	# the custom sky-blue background and gold button styles with generic
	# theme colors. InitialScreen has its own bespoke visual design.
	_setup_welcome_popup()

	# Ensure button callbacks stay wired even if .tscn signal names drift.
	_connect_button_if_needed(play_button, "_on_play_button_pressed")
	_connect_button_if_needed(multiplayer_button, "_on_multiplayer_button_pressed")
	_connect_button_if_needed(customize_button, "_on_customize_button_pressed")
	_connect_button_if_needed(store_button, "_on_store_button_pressed")
	_connect_button_if_needed(roadmap_button, "_on_roadmap_button_pressed")
	_connect_button_if_needed(settings_button, "_on_settings_button_pressed")
	_connect_button_if_needed(close_button, "_on_close_popup_pressed")

	if TouchInputManager and TouchInputManager.has_method("enable_haptics_for_scene"):
		TouchInputManager.enable_haptics_for_scene(self)


func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback


func _process(delta: float) -> void:
	# Smooth sinusoidal vertical bob for each wave layer
	_wave_time += delta
	for i in range(mini(_wave_sprites.size(), _WAVE_CFG.size())):
		if i >= _wave_base_y.size():
			break
		var spr: Control = _wave_sprites[i]
		if not is_instance_valid(spr):
			continue
		var cfg: Array = _WAVE_CFG[i]
		spr.position.y = _wave_base_y[i] + sin(_wave_time * cfg[2] + cfg[3]) * cfg[1]

	if not _crowd_idle_started:
		return
	# Walk crowd characters horizontally across the platform
	for i in range(_characters.size()):
		var ch = _characters[i]
		if not is_instance_valid(ch):
			continue
		var spd = _crowd_walk_speeds[i] if i < _crowd_walk_speeds.size() else 30.0
		var dir = _crowd_walk_dirs[i] if i < _crowd_walk_dirs.size() else 1.0
		ch.position.x += spd * dir * delta

		# Flip direction at platform edges
		if ch.position.x > _crowd_right_bound:
			ch.position.x = _crowd_right_bound
			_crowd_walk_dirs[i] = -1.0
			ch.scale.x = -absf(ch.scale.x)  # face left
		elif ch.position.x < _crowd_left_bound:
			ch.position.x = _crowd_left_bound
			_crowd_walk_dirs[i] = 1.0
			ch.scale.x = absf(ch.scale.x)   # face right


func _connect_button_if_needed(button: BaseButton, method_name: String) -> void:
	if not button:
		return
	var cb := Callable(self, method_name)
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)





func _is_mobile_layout() -> bool:
	if MobileUIManager and MobileUIManager.has_method("is_mobile_platform"):
		return MobileUIManager.is_mobile_platform()
	return OS.get_name() in ["Android", "iOS"]


func _is_portrait_viewport(vp_size: Vector2) -> bool:
	return vp_size.y > vp_size.x


func _get_safe_margins() -> Dictionary:
	if MobileUIManager and MobileUIManager.has_method("get_safe_area_margins"):
		return MobileUIManager.get_safe_area_margins()
	if TouchInputManager and TouchInputManager.has_method("get_safe_area_margins"):
		return TouchInputManager.get_safe_area_margins()
	return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}


func _get_side_character_slots(vp_size: Vector2) -> Array[float]:
	if _is_mobile_layout() and _is_portrait_viewport(vp_size):
		return [0.14, 0.33, 0.67, 0.86]
	return [0.20, 0.40, 0.60, 0.80]


func _get_side_character_y_factor(vp_size: Vector2) -> float:
	# Place side characters on the PSD platform ground level.
	if _is_mobile_layout() and _is_portrait_viewport(vp_size):
		return 0.56
	return 0.59


func _get_main_character_y_factor(vp_size: Vector2) -> float:
	# Main character on the platform, feet touching ground.
	if _is_mobile_layout() and _is_portrait_viewport(vp_size):
		return 0.50
	if _is_mobile_layout():
		return 0.52
	return 0.54


func _get_hero_base_scale() -> float:
	var hero_scale = HERO_BASE_SCALE
	if _is_mobile_layout():
		hero_scale *= MOBILE_HERO_SCALE_MULTIPLIER
	return hero_scale


func _get_hero_bounce_amplitude() -> float:
	if _is_mobile_layout():
		return HERO_BOUNCE_AMPLITUDE * MOBILE_HERO_BOUNCE_MULTIPLIER
	return HERO_BOUNCE_AMPLITUDE


func _should_reduce_mobile_motion() -> bool:
	if not _is_mobile_layout():
		return false
	if AccessibilityManager and AccessibilityManager.has_method("should_reduce_motion"):
		return AccessibilityManager.should_reduce_motion()
	return true


func _layout_characters_for_viewport(vp_size: Vector2) -> void:
	# Update walk bounds for new viewport size
	_crowd_left_bound = vp_size.x * 0.08
	_crowd_right_bound = vp_size.x * 0.92
	var side_y = vp_size.y * _get_side_character_y_factor(vp_size)
	for i in range(_characters.size()):
		# Keep current X (walking) but update Y for platform level
		_characters[i].position.y = side_y + randf_range(-4, 4)
		# Clamp X to new bounds
		_characters[i].position.x = clampf(
			_characters[i].position.x, _crowd_left_bound, _crowd_right_bound
		)

	if _main_character:
		_main_character.position = Vector2(
			vp_size.x * 0.5,
			vp_size.y * _get_main_character_y_factor(vp_size)
		)


func _apply_responsive_layout() -> void:
	var vp_size = get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		return

	_layout_characters_for_viewport(vp_size)

	if _title_node:
		var title_width = _title_node.size.x
		if title_width <= 1.0:
			title_width = 390.0
		_title_node.position.x = (vp_size.x - title_width) * 0.5

	if not _is_mobile_layout():
		return

	var margins = _get_safe_margins()
	var safe_top = float(margins.get("top", 0.0))
	var safe_bottom = float(margins.get("bottom", 0.0))
	var safe_left = float(margins.get("left", 0.0))
	var safe_right = float(margins.get("right", 0.0))
	var portrait = _is_portrait_viewport(vp_size)

	# LayoutManager not available; safe-area padding applied directly below.

	if top_left_panel:
		top_left_panel.offset_left = safe_left + 14.0
		top_left_panel.offset_top = safe_top + 12.0

	if top_right_panel:
		top_right_panel.offset_top = safe_top + 10.0
		top_right_panel.offset_bottom = top_right_panel.offset_top + (66.0 if portrait else 70.0)
		top_right_panel.offset_right = -safe_right - 12.0
		top_right_panel.offset_left = -((340.0 if portrait else 390.0) + safe_right)
		top_right_panel.add_theme_constant_override("separation", 8 if portrait else 12)

	if store_button:
		store_button.custom_minimum_size = Vector2(64, 64) if portrait else Vector2(70, 70)
		store_button.add_theme_font_size_override("font_size", 30 if portrait else 34)
	if roadmap_button:
		roadmap_button.custom_minimum_size = Vector2(64, 64) if portrait else Vector2(70, 70)
		roadmap_button.add_theme_font_size_override("font_size", 30 if portrait else 34)
	if settings_button:
		settings_button.custom_minimum_size = Vector2(64, 64) if portrait else Vector2(70, 70)
	if customize_button:
		customize_button.custom_minimum_size = Vector2(64, 64) if portrait else Vector2(70, 70)
		customize_button.add_theme_font_size_override("font_size", 30 if portrait else 34)

	if button_container:
		var container_width = clamp(vp_size.x * 0.72, 300.0, 520.0)
		button_container.offset_left = -container_width * 0.5
		button_container.offset_right = container_width * 0.5
		button_container.offset_bottom = -safe_bottom - 18.0
		button_container.offset_top = (
			button_container.offset_bottom - (186.0 if portrait else 160.0)
		)
		button_container.add_theme_constant_override("separation", 12 if portrait else 15)

	if play_button:
		play_button.custom_minimum_size = Vector2(clamp(vp_size.x * 0.72, 300.0, 520.0), 86.0)
	if multiplayer_button:
		multiplayer_button.custom_minimum_size = Vector2(
			clamp(vp_size.x * 0.66, 280.0, 460.0),
			56.0
		)

	if highscore_panel:
		highscore_panel.offset_top = max(safe_top + 86.0, 140.0)
		highscore_panel.offset_bottom = highscore_panel.offset_top + 50.0

	if next_unlock_panel:
		next_unlock_panel.offset_left = safe_left + 14.0
		next_unlock_panel.offset_right = (
			next_unlock_panel.offset_left + (220.0 if portrait else 250.0)
		)
		next_unlock_panel.offset_bottom = -safe_bottom - 16.0
		next_unlock_panel.offset_top = next_unlock_panel.offset_bottom - 118.0


func _on_viewport_resized() -> void:
	var vp = get_viewport_rect().size
	if vp == Vector2.ZERO:
		return

	# Reposition characters to match new viewport
	_layout_characters_for_viewport(vp)

	# Reposition title
	if _title_node:
		var title_width = _title_node.size.x
		if title_width <= 1.0:
			title_width = 390.0
		_title_node.position.x = (vp.x - title_width) * 0.5

	# Signboard uses fixed coords (HighscorePost is fixed-size, anchored top-left)

	# Re-apply mobile layout adjustments
	_apply_responsive_layout()


func _go_to_scene(scene_candidates: Array[String]) -> void:
	for scene_path in scene_candidates:
		if ResourceLoader.exists(scene_path):
			if GameManager and GameManager.has_method("transition_to_scene"):
				GameManager.transition_to_scene(scene_path)
			else:
				get_tree().change_scene_to_file(scene_path)
			return

	push_warning("No valid scene found in candidates: %s" % [scene_candidates])


func _ensure_fullscreen_backdrop() -> void:
	# Sky is now the visible blue background from .tscn — keep it.
	# Hide only the old Ground node — PSD layers replace it.
	var ground_node = get_node_or_null("Ground")
	if ground_node:
		ground_node.visible = false

	var sky_blue = Color(0.529, 0.808, 0.922, 1.0)  # Match Sky node color
	var backdrop = get_node_or_null("RuntimeBackdrop") as ColorRect
	if backdrop:
		backdrop.color = sky_blue
		RenderingServer.set_default_clear_color(sky_blue)
		return

	backdrop = ColorRect.new()
	backdrop.name = "RuntimeBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = sky_blue
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	add_child(backdrop)
	move_child(backdrop, 0)
	RenderingServer.set_default_clear_color(sky_blue)


# ── Background (PSD layers from .tscn) ──────────────────────────────

func _build_background() -> void:
	var vp = get_viewport_rect().size

	# BGLayers are placed in the .tscn as TextureRect nodes for editor visibility.
	# Compute PSD→viewport scale for signboard label positioning.
	var scale_x = vp.x / PSD_SIZE.x
	var scale_y = vp.y / PSD_SIZE.y
	_psd_scale = max(scale_x, scale_y)
	_psd_offset = (vp - PSD_SIZE * _psd_scale) * 0.5

	# Gather the wave TextureRect nodes for animation.
	var bg_layers = get_node_or_null("BGLayers")
	if bg_layers:
		for wave_name in ["Waves1", "Waves2", "Waves3"]:
			var wave_node = bg_layers.get_node_or_null(wave_name)
			if wave_node:
				_wave_sprites.append(wave_node)

	# Create a layer for runtime-only nodes (clouds).
	_bg_layer = Node2D.new()
	_bg_layer.z_index = -18  # Above BGLayers (-19), below chars
	add_child(_bg_layer)

	# Spawn drifting clouds over the sky area
	_spawn_clouds(vp)


func _spawn_clouds(vp: Vector2) -> void:
	var cloud_container = Node2D.new()
	cloud_container.name = "Clouds"
	cloud_container.z_index = 7  # Above highscore post, still behind characters
	_bg_layer.add_child(cloud_container)

	var cloud_data = [
		{"x": vp.x * 0.10, "y": vp.y * 0.06, "w": 240, "h": 78, "speed": 12.0, "alpha": 0.55},
		{"x": vp.x * 0.35, "y": vp.y * 0.12, "w": 300, "h": 90, "speed": 8.0, "alpha": 0.50},
		{"x": vp.x * 0.62, "y": vp.y * 0.04, "w": 220, "h": 66, "speed": 15.0, "alpha": 0.50},
		{"x": vp.x * 0.85, "y": vp.y * 0.10, "w": 260, "h": 82, "speed": 10.0, "alpha": 0.45},
	]

	for cd in cloud_data:
		var cloud = Node2D.new()
		cloud.position = Vector2(cd.x, cd.y)
		cloud.set_meta("speed", cd.speed)
		cloud.set_meta("base_x", cd.x)

		# Build cloud from overlapping ovals
		for j in range(3):
			var puff = Polygon2D.new()
			var pw = cd.w * (0.6 + 0.2 * j)
			var ph = cd.h * (0.8 + 0.1 * j)
			puff.polygon = _oval(pw * 0.5, ph * 0.5, 16)
			puff.position = Vector2((j - 1) * cd.w * 0.28, (j % 2) * -cd.h * 0.15)
			puff.color = Color(1, 1, 1, cd.alpha)
			cloud.add_child(puff)

		cloud_container.add_child(cloud)
		_cloud_nodes.append(cloud)


func _animate_waves() -> void:
	# Apply a UV-scroll shader to each wave layer for smooth rolling motion.
	# Vertical bobbing is handled in _process via perfect sine math.
	var wave_shader: Shader = load("res://shaders/wave_scroll.gdshader")
	for i in range(mini(_wave_sprites.size(), _WAVE_CFG.size())):
		var spr: Control = _wave_sprites[i]
		var cfg: Array = _WAVE_CFG[i]
		_wave_base_y.append(spr.position.y)

		var mat := ShaderMaterial.new()
		mat.shader = wave_shader
		mat.set_shader_parameter("scroll_speed", cfg[0])
		spr.material = mat
		# Enable mirror repeat so the texture tiles seamlessly
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR


func _animate_clouds() -> void:
	var vp = get_viewport_rect().size
	for cloud in _cloud_nodes:
		var speed = float(cloud.get_meta("speed", 10.0))
		var base_x = float(cloud.get_meta("base_x", cloud.position.x))
		var drift_range = vp.x * 0.08

		var cloud_tw = create_tween().set_loops()
		_tweens.append(cloud_tw)
		cloud_tw.tween_property(
			cloud, "position:x", base_x + drift_range, speed
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cloud_tw.tween_property(
			cloud, "position:x", base_x - drift_range, speed * 2.0
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cloud_tw.tween_property(
			cloud, "position:x", base_x, speed
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Gentle vertical bob
		var cloud_bob = create_tween().set_loops()
		_tweens.append(cloud_bob)
		var base_y = cloud.position.y
		cloud_bob.tween_property(
			cloud, "position:y", base_y - 6, speed * 0.7
		).set_trans(Tween.TRANS_SINE)
		cloud_bob.tween_property(
			cloud, "position:y", base_y + 4, speed * 0.7
		).set_trans(Tween.TRANS_SINE)


func _spawn_decorations() -> void:
	# Check if boat decoration is enabled
	var show_boat := false
	if SaveManager:
		if SaveManager.has_method("is_decoration_enabled"):
			show_boat = SaveManager.is_decoration_enabled("boat")
		elif SaveManager.has_method("get_decoration_state"):
			show_boat = SaveManager.get_decoration_state("boat")
	if not show_boat:
		return

	var vp = get_viewport_rect().size
	_boat_node = _build_procedural_boat()
	_boat_node.position = Vector2(vp.x * 0.72, vp.y * 0.78)
	_boat_node.z_index = -2  # Above waves, below characters
	add_child(_boat_node)

	# Gentle rocking motion
	var rock = create_tween().set_loops()
	_tweens.append(rock)
	rock.tween_property(
		_boat_node, "rotation_degrees", 4.0, 1.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock.tween_property(
		_boat_node, "rotation_degrees", -4.0, 1.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Bob up and down with waves
	var base_y = _boat_node.position.y
	var bob = create_tween().set_loops()
	_tweens.append(bob)
	bob.tween_property(
		_boat_node, "position:y", base_y - 8, 2.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(
		_boat_node, "position:y", base_y + 6, 2.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Slow horizontal drift
	var base_x = _boat_node.position.x
	var drift = create_tween().set_loops()
	_tweens.append(drift)
	drift.tween_property(
		_boat_node, "position:x", base_x + 30, 6.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(
		_boat_node, "position:x", base_x - 30, 6.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_procedural_boat() -> Node2D:
	var boat = Node2D.new()
	boat.name = "Boat"

	# Hull (brown wooden boat)
	var hull = Polygon2D.new()
	hull.polygon = PackedVector2Array([
		Vector2(-50, 0), Vector2(-40, 18),
		Vector2(-30, 24), Vector2(30, 24),
		Vector2(40, 18), Vector2(50, 0),
		Vector2(35, -4), Vector2(-35, -4),
	])
	hull.color = Color(0.55, 0.35, 0.18)
	boat.add_child(hull)

	# Hull highlight stripe
	var stripe = Polygon2D.new()
	stripe.polygon = PackedVector2Array([
		Vector2(-42, 2), Vector2(-34, 14),
		Vector2(34, 14), Vector2(42, 2),
		Vector2(35, -1), Vector2(-35, -1),
	])
	stripe.color = Color(0.65, 0.45, 0.25)
	boat.add_child(stripe)

	# Mast
	var mast = Line2D.new()
	mast.points = PackedVector2Array([
		Vector2(0, -2), Vector2(0, -50),
	])
	mast.width = 3.0
	mast.default_color = Color(0.45, 0.3, 0.15)
	boat.add_child(mast)

	# Sail (triangle)
	var sail = Polygon2D.new()
	sail.polygon = PackedVector2Array([
		Vector2(2, -48), Vector2(2, -12),
		Vector2(32, -18),
	])
	sail.color = Color(1.0, 1.0, 1.0, 0.9)
	boat.add_child(sail)

	# Sail accent line
	var accent = Line2D.new()
	accent.points = PackedVector2Array([
		Vector2(2, -48), Vector2(32, -18), Vector2(2, -12),
	])
	accent.width = 1.5
	accent.default_color = Color(0.7, 0.7, 0.7)
	boat.add_child(accent)

	# Flag at top
	var flag = Polygon2D.new()
	flag.polygon = PackedVector2Array([
		Vector2(0, -50), Vector2(12, -46),
		Vector2(0, -42),
	])
	flag.color = Color(0.9, 0.3, 0.3)
	boat.add_child(flag)

	return boat


func _setup_signboard_highscore() -> void:
	# Hide the original HighscorePanel UI element
	if highscore_panel:
		highscore_panel.visible = false

	# Place highscore text on the wooden signboard plank.
	# HighscorePost is now a fixed-size node (2360x1640) anchored top-left,
	# so it stays in the same position regardless of viewport width.
	# With scale 0.75 and 1:1 texture mapping, plank texture coords
	# (439,220)→(912,351) map to screen:
	#   x: (-42 + 439)*0.75 = 298  →  (-42 + 912)*0.75 = 653
	#   y: (-61 + 220)*0.75 = 119  →  (-61 + 351)*0.75 = 218
	_signboard_label = Label.new()
	_signboard_label.name = "SignboardScore"
	_signboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_signboard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var font_res = UI_FONT_BRICK
	if font_res:
		_signboard_label.add_theme_font_override("font", font_res)
	_signboard_label.add_theme_font_size_override("font_size", 30)
	_signboard_label.add_theme_color_override(
		"font_color", Color(0.25, 0.18, 0.1)
	)
	_signboard_label.clip_text = false
	_signboard_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Plank is slightly tilted in the texture — match the angle.
	# Plank screen rect (approx): (255, 95) → (665, 210), center ~(460, 152)
	_signboard_label.position = Vector2(255, 95)
	_signboard_label.size = Vector2(410, 115)
	_signboard_label.pivot_offset = Vector2(205, 57)
	_signboard_label.rotation = deg_to_rad(-3.5)
	_signboard_label.z_index = 8
	add_child(_signboard_label)

	# Set the score text — show highest score across all minigames
	var score_value := 0
	if SaveManager and SaveManager.has_method("get_high_score"):
		# Check all known minigame IDs for the best score
		var game_ids = [
			"catch_rain", "pipe_connect", "water_cycle",
			"pollution_cleanup", "water_quiz", "conservation",
			"ecosystem",
		]
		for gid in game_ids:
			var hs_result = SaveManager.call("get_high_score", gid)
			if hs_result is Dictionary:
				var s = int(hs_result.get("score", 0))
				if s > score_value:
					score_value = s

	_signboard_label.text = "%s\n%d" % [
		_loc("initial_highscore_sign", "HIGHSCORE"),
		score_value
	]


# ── Characters ──────────────────────────────────────────────────────

func _spawn_characters() -> void:
	var vp = get_viewport_rect().size
	_char_layer = Node2D.new()
	_char_layer.z_index = -5
	add_child(_char_layer)

	# Build crowd from all character presets + extra generic ones.
	# Unlocked characters get their hat; locked ones are plain.
	var crowd_entries: Array[Dictionary] = []
	var selected_id := "droppy_blue"
	if SaveManager and SaveManager.has_method("get_selected_character"):
		selected_id = str(SaveManager.get_selected_character())

	for preset_id in MAIN_CHARACTER_PRESETS:
		if preset_id == selected_id:
			continue  # Hero is spawned separately
		var p = MAIN_CHARACTER_PRESETS[preset_id]
		var unlocked = SaveManager and SaveManager.has_method("is_character_unlocked") \
			and SaveManager.is_character_unlocked(preset_id)
		var hat_str = str(p.get("hat", "")) if unlocked else ""
		var char_trait = str(p.get("trait", "idle"))
		crowd_entries.append({
			"color": p.get("color", Color(0.5, 0.5, 0.5)),
			"hat": hat_str,
			"unlocked": unlocked,
			"trait": char_trait,
		})

	# Pad with generic colored extras if fewer than MAX
	var generic_idx := 0
	while crowd_entries.size() < MAX_CROWD_CHARS:
		crowd_entries.append({
			"color": CHAR_COLORS[generic_idx % CHAR_COLORS.size()].lightened(0.15),
			"hat": "",
			"unlocked": true,
			"trait": BG_CHARACTER_ROLES[generic_idx % BG_CHARACTER_ROLES.size()],
		})
		generic_idx += 1

	# Shuffle for organic feel
	crowd_entries.shuffle()

	# Platform walk bounds (viewport proportional)
	_crowd_left_bound = vp.x * 0.08
	_crowd_right_bound = vp.x * 0.92
	var side_y = vp.y * _get_side_character_y_factor(vp)

	# Spawn crowd characters spread across the platform
	_characters.clear()
	_crowd_walk_speeds.clear()
	_crowd_walk_dirs.clear()
	var count = mini(crowd_entries.size(), MAX_CROWD_CHARS)
	for i in range(count):
		var entry = crowd_entries[i]
		var role = str(entry.get("trait", BG_CHARACTER_ROLES[i % BG_CHARACTER_ROLES.size()]))
		var ch = _build_droplet(entry.color, entry.hat, false, role)

		# Varied scale for depth: 0.7–1.0
		var depth_scale = randf_range(0.72, 1.0)
		ch.set_meta("depth_scale", depth_scale)

		# Distribute across the platform width
		var spread = _crowd_right_bound - _crowd_left_bound
		var start_x = _crowd_left_bound + (float(i) / float(count)) * spread + randf_range(-30, 30)
		start_x = clampf(start_x, _crowd_left_bound, _crowd_right_bound)
		ch.position = Vector2(start_x, side_y + randf_range(-4, 4))
		ch.scale = Vector2.ZERO  # start invisible for entrance
		_char_layer.add_child(ch)
		_characters.append(ch)

		# Walk speed varies per character (px/sec)
		_crowd_walk_speeds.append(randf_range(18.0, 50.0) * depth_scale)
		_crowd_walk_dirs.append(1.0 if randf() > 0.5 else -1.0)

	# Spawn the selected main character as a prominent center piece.
	var preset := _get_selected_character_preset()
	var selected_color: Color = preset.get("color", Color(0.3, 0.6, 1.0))
	var selected_hat: String = _get_equipped_hat(str(preset.get("hat", "💧")))
	_main_character = _build_droplet(selected_color, selected_hat, true, "hero")
	_main_character.position = Vector2(vp.x * 0.5, vp.y * _get_main_character_y_factor(vp))
	_main_character.scale = Vector2.ZERO
	_main_character.z_index = 12
	_char_layer.add_child(_main_character)


func _get_selected_character_preset() -> Dictionary:
	var selected_id := "droppy_blue"
	if SaveManager and SaveManager.has_method("get_selected_character"):
		selected_id = str(SaveManager.get_selected_character())

	if MAIN_CHARACTER_PRESETS.has(selected_id):
		return MAIN_CHARACTER_PRESETS[selected_id]

	return MAIN_CHARACTER_PRESETS["droppy_blue"]


func _get_equipped_hat(default_hat: String) -> String:
	if not SaveManager:
		return default_hat

	# Try per-character accessory first
	var char_id := "droppy_blue"
	if SaveManager.has_method("get_selected_character"):
		char_id = str(SaveManager.get_selected_character())

	var accessory_id := "character_default"
	if SaveManager.has_method("get_character_accessory"):
		accessory_id = str(SaveManager.get_character_accessory(char_id))
	elif SaveManager.has_method("get_selected_accessory"):
		accessory_id = str(SaveManager.get_selected_accessory())

	if accessory_id == "" or accessory_id == "character_default":
		return default_hat

	if (
		SaveManager.has_method("is_accessory_unlocked")
		and not SaveManager.is_accessory_unlocked(accessory_id)
	):
		return default_hat

	if SaveManager.has_method("get_accessory_icon"):
		var icon = str(SaveManager.get_accessory_icon(accessory_id))
		if not icon.is_empty():
			return icon

	return default_hat


func _build_droplet(
	color: Color,
	hat: String,
	is_main: bool = false,
	role: String = "idle"
) -> Node2D:
	var root = Node2D.new()
	root.set_meta("role", role)
	root.set_meta("is_main", is_main)

	var body_scale = 1.2 if is_main else 1.0
	var eye_scale = 1.16 if is_main else 1.0
	var limb_scale = 1.12 if is_main else 1.0

	# Body (teardrop)
	var body = Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -40 * body_scale), Vector2(18 * body_scale, -26 * body_scale),
		Vector2(26 * body_scale, -4 * body_scale), Vector2(22 * body_scale, 14 * body_scale),
		Vector2(12 * body_scale, 28 * body_scale), Vector2(0, 32 * body_scale),
		Vector2(-12 * body_scale, 28 * body_scale), Vector2(-22 * body_scale, 14 * body_scale),
		Vector2(-26 * body_scale, -4 * body_scale), Vector2(-18 * body_scale, -26 * body_scale),
	])
	body.color = color
	root.add_child(body)

	# Highlight
	var hl = Polygon2D.new()
	hl.polygon = PackedVector2Array([
		Vector2(-10 * body_scale, -30 * body_scale),
		Vector2(-6 * body_scale, -22 * body_scale),
		Vector2(-14 * body_scale, -18 * body_scale),
	])
	hl.color = Color(1, 1, 1, 0.35)
	root.add_child(hl)

	# Eyes
	for xoff in [-9, 9]:
		var ew = Polygon2D.new()
		ew.polygon = _oval(5.5 * eye_scale, 6 * eye_scale, 8)
		ew.position = Vector2(xoff * eye_scale, -6 * eye_scale)
		ew.color = Color.WHITE
		root.add_child(ew)
		var pupil = Polygon2D.new()
		pupil.polygon = _oval(2.8 * eye_scale, 3 * eye_scale, 6)
		pupil.position = Vector2(xoff * eye_scale, -5 * eye_scale)
		pupil.color = Color.BLACK
		root.add_child(pupil)

	# Smile
	var smile = Line2D.new()
	smile.name = "Smile"
	smile.points = PackedVector2Array([
		Vector2(-8 * eye_scale, 6 * eye_scale), Vector2(-3 * eye_scale, 12 * eye_scale),
		Vector2(3 * eye_scale, 12 * eye_scale), Vector2(8 * eye_scale, 6 * eye_scale),
	])
	smile.width = 2.0
	smile.default_color = Color(0.15, 0.15, 0.15)
	root.add_child(smile)

	# Arms (behind body)
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.points = PackedVector2Array([
			Vector2(side * 22 * limb_scale, 0), Vector2(side * 34 * limb_scale, -10 * limb_scale),
		])
		arm.width = 3.5
		arm.default_color = color.darkened(0.15)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		arm.z_index = -1
		root.add_child(arm)

	# Legs (behind body)
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.points = PackedVector2Array([
			Vector2(side * 8 * limb_scale, 28 * limb_scale),
			Vector2(side * 12 * limb_scale, 42 * limb_scale),
		])
		leg.width = 3.5
		leg.default_color = color.darkened(0.15)
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		leg.z_index = -1
		root.add_child(leg)

	# Hat emoji — show on main character and on crowd members that have one
	if hat != "":
		var hat_lbl = Label.new()
		hat_lbl.name = "HatLabel"
		hat_lbl.text = hat
		hat_lbl.position = Vector2(-12 * body_scale, -62 * body_scale)
		hat_lbl.add_theme_font_size_override("font_size", 26 if is_main else 18)
		root.add_child(hat_lbl)

	# Role props on main character, and personality visuals on crowd
	if is_main:
		_attach_role_prop(root, role)
	else:
		_attach_crowd_personality(root, role, color, body_scale)

	return root


func _attach_crowd_personality(
	root: Node2D, char_trait: String,
	color: Color, body_scale: float
) -> void:
	match char_trait:
		"dancer":
			# Little skirt / tutu
			var skirt = Polygon2D.new()
			skirt.name = "Skirt"
			skirt.polygon = PackedVector2Array([
				Vector2(-18 * body_scale, 20 * body_scale),
				Vector2(-24 * body_scale, 36 * body_scale),
				Vector2(-8 * body_scale, 34 * body_scale),
				Vector2(0, 38 * body_scale),
				Vector2(8 * body_scale, 34 * body_scale),
				Vector2(24 * body_scale, 36 * body_scale),
				Vector2(18 * body_scale, 20 * body_scale),
			])
			skirt.color = color.lightened(0.35)
			skirt.z_index = 1
			root.add_child(skirt)
			# Music note above head
			var note = Label.new()
			note.text = "🎵"
			note.position = Vector2(14 * body_scale, -56 * body_scale)
			note.add_theme_font_size_override("font_size", 14)
			root.add_child(note)
		"jogger":
			# Headband
			var band = Line2D.new()
			band.name = "Headband"
			band.points = PackedVector2Array([
				Vector2(-16 * body_scale, -28 * body_scale),
				Vector2(0, -32 * body_scale),
				Vector2(16 * body_scale, -28 * body_scale),
			])
			band.width = 3.0
			band.default_color = Color.RED
			root.add_child(band)
		"cheerer":
			# Pom-pom arms (small dots at hand tips)
			for side in [-1, 1]:
				var pom = Polygon2D.new()
				pom.polygon = _oval(4, 4, 6)
				pom.position = Vector2(side * 36 * body_scale, -14 * body_scale)
				pom.color = Color(1.0, 0.8, 0.2)
				root.add_child(pom)


func _attach_role_prop(root: Node2D, role: String) -> void:
	if role == "hero":
		var crown = Label.new()
		crown.name = "RoleProp"
		crown.text = "✨"
		crown.position = Vector2(16, -90)
		crown.add_theme_font_size_override("font_size", 22)
		root.add_child(crown)
		return

	var prop = Label.new()
	prop.name = "RoleProp"
	prop.add_theme_font_size_override("font_size", 22)

	match role:
		"dancer":
			prop.text = "🎵"
			prop.position = Vector2(-8, -72)
		"musician":
			prop.text = "🎸"
			prop.position = Vector2(12, 8)
			var note = Label.new()
			note.name = "RoleNote"
			note.text = "♪"
			note.position = Vector2(30, -28)
			note.modulate.a = 0.8
			note.add_theme_font_size_override("font_size", 20)
			root.add_child(note)
		"baller":
			prop.text = "⚽"
			prop.position = Vector2(14, 44)
		"cheerer":
			prop.text = "🎉"
			prop.position = Vector2(-8, -74)
		_:
			return

	root.add_child(prop)


# ── Title ───────────────────────────────────────────────────────────

func _build_title() -> void:
	_title_node = Label.new()
	_title_node.text = _loc("title", "WATERVILLE")
	_title_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_node.add_theme_font_size_override("font_size", 56)
	var title_font = UI_FONT_BRICK
	if title_font:
		_title_node.add_theme_font_override("font", title_font)
	_title_node.add_theme_color_override("font_color", Color(1, 1, 1))
	_title_node.add_theme_color_override("font_outline_color", Color(0.1, 0.3, 0.6))
	_title_node.add_theme_constant_override("outline_size", 10)
	_title_node.position = Vector2(0, 18)
	_title_node.modulate.a = 0.0  # start hidden
	add_child(_title_node)


# ── Entrance animation ─────────────────────────────────────────────

func _animate_entrance() -> void:
	# Title gentle sway (always — even on return visits)
	var sway = create_tween().set_loops()
	_tweens.append(sway)
	sway.tween_property(_title_node, "rotation", deg_to_rad(2), 1.8).set_trans(Tween.TRANS_SINE)
	sway.tween_property(_title_node, "rotation", deg_to_rad(-2), 1.8).set_trans(Tween.TRANS_SINE)

	# Return visit: characters fade in from their spawn positions — no drop-in
	if _has_been_shown:
		_title_node.modulate.a = 1.0
		for ch in _characters:
			var ds := float(ch.get_meta("depth_scale", 1.0))
			ch.scale = Vector2(ds, ds)
			ch.modulate.a = 0.0
			var ft := create_tween()
			_tweens.append(ft)
			ft.tween_property(ch, "modulate:a", 1.0, 0.3)
		if _main_character:
			var hs := _get_hero_base_scale()
			_main_character.scale = Vector2(hs, hs)
			_main_character.modulate.a = 0.0
			var ft2 := create_tween()
			_tweens.append(ft2)
			ft2.tween_property(_main_character, "modulate:a", 1.0, 0.35)
		_start_idle_loops()
		return
	_has_been_shown = true

	# First visit only: title slide-down
	var title_tw = create_tween()
	_tweens.append(title_tw)
	_title_node.position.y -= 40
	title_tw.tween_property(_title_node, "modulate:a", 1.0, 0.4)
	title_tw.parallel().tween_property(
		_title_node, "position:y",
		_title_node.position.y + 40, 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Characters staggered drop-in with squash-stretch
	for i in range(_characters.size()):
		var ch = _characters[i]
		var delay = 0.2 + i * 0.08  # faster stagger for larger crowd
		var base_y = ch.position.y
		ch.position.y -= 200  # start above screen

		var drop = create_tween()
		_tweens.append(drop)
		drop.tween_interval(delay)
		drop.tween_property(ch, "scale", Vector2(0.92, 1.08), 0.03)
		drop.tween_property(
			ch, "position:y", base_y, 0.35
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# Gentle settle keeps motion soft.
		drop.tween_property(ch, "scale", Vector2(1.08, 0.92), 0.08)
		drop.tween_property(ch, "scale", Vector2(0.98, 1.03), 0.08)
		drop.tween_property(ch, "scale", Vector2(1.0, 1.0), 0.08)

	if _main_character:
		var hero_scale = _get_hero_base_scale()
		var hero_base_y = _main_character.position.y
		_main_character.position.y -= 260

		var hero_drop = create_tween()
		_tweens.append(hero_drop)
		hero_drop.tween_interval(0.5)
		hero_drop.tween_property(
			_main_character,
			"scale",
			Vector2(hero_scale * 0.88, hero_scale * 1.08),
			0.08
		)
		hero_drop.tween_property(
			_main_character, "position:y", hero_base_y, 0.4
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		hero_drop.tween_property(
			_main_character,
			"scale",
			Vector2(hero_scale * 1.06, hero_scale * 0.94),
			0.12
		)
		hero_drop.tween_property(
			_main_character,
			"scale",
			Vector2(hero_scale, hero_scale),
			0.12
		)

	# Start idle loops after entrance finishes
	var idle_delay = create_tween()
	_tweens.append(idle_delay)
	idle_delay.tween_interval(0.2 + _characters.size() * 0.08 + 0.6)
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
	_crowd_idle_started = true
	for i in range(_characters.size()):
		var ch = _characters[i]
		var depth_scale = float(ch.get_meta("depth_scale", 1.0))
		# Apply depth scale now (entrance animation ends at 1,1)
		ch.scale = Vector2(depth_scale, depth_scale)
		# Face initial walk direction
		if i < _crowd_walk_dirs.size() and _crowd_walk_dirs[i] < 0:
			ch.scale.x = -depth_scale

		var base_y = ch.position.y
		var char_trait = str(ch.get_meta("role", "idle"))

		# Trait-specific bounce/motion
		match char_trait:
			"jumper":
				# Big bouncy jumps
				var jump = create_tween().set_loops()
				_tweens.append(jump)
				jump.tween_interval(0.05 * i)
				jump.tween_property(
					ch, "position:y",
					base_y - 18 * depth_scale, 0.30
				).set_trans(Tween.TRANS_QUAD).set_ease(
					Tween.EASE_OUT
				)
				jump.tween_property(
					ch, "position:y", base_y, 0.30
				).set_trans(Tween.TRANS_QUAD).set_ease(
					Tween.EASE_IN
				)
				jump.tween_interval(0.3)
			"spinner":
				# Slow spin while walking
				var spin = create_tween().set_loops()
				_tweens.append(spin)
				spin.tween_property(
					ch, "rotation", TAU, 2.5
				).set_trans(Tween.TRANS_LINEAR)
				var bob = create_tween().set_loops()
				_tweens.append(bob)
				bob.tween_property(
					ch, "position:y",
					base_y - 4 * depth_scale, 0.5
				).set_trans(Tween.TRANS_SINE)
				bob.tween_property(
					ch, "position:y", base_y, 0.5
				).set_trans(Tween.TRANS_SINE)
			"bouncer":
				# Springy bounce
				var spr = create_tween().set_loops()
				_tweens.append(spr)
				spr.tween_interval(0.05 * i)
				spr.tween_property(
					ch, "position:y",
					base_y - 10 * depth_scale, 0.25
				).set_trans(Tween.TRANS_BACK).set_ease(
					Tween.EASE_OUT
				)
				spr.tween_property(
					ch, "position:y", base_y, 0.25
				).set_trans(Tween.TRANS_BOUNCE).set_ease(
					Tween.EASE_OUT
				)
				spr.tween_interval(0.15)
			"waver":
				# Big arm wave side to side
				var wave_b = create_tween().set_loops()
				_tweens.append(wave_b)
				wave_b.tween_property(
					ch, "position:y",
					base_y - 3 * depth_scale, 0.45
				).set_trans(Tween.TRANS_SINE)
				wave_b.tween_property(
					ch, "position:y", base_y, 0.45
				).set_trans(Tween.TRANS_SINE)
			_:
				# Default gentle bob (dancer, jogger, cheerer, etc.)
				var bob_amp = (3.0 + 0.5 * float(i % 3)) * depth_scale
				var bob_dur = 0.45 + 0.05 * (i % 4)
				var bounce = create_tween().set_loops()
				_tweens.append(bounce)
				bounce.tween_interval(0.05 * i)
				bounce.tween_property(
					ch, "position:y",
					base_y - bob_amp, bob_dur
				).set_trans(Tween.TRANS_SINE)
				bounce.tween_property(
					ch, "position:y", base_y, bob_dur
				).set_trans(Tween.TRANS_SINE)

		# Walking leg swing + trait-specific arm motion
		_start_walk_leg_animation(ch, i)

	if _main_character:
		_start_main_character_showtime()


func _start_walk_leg_animation(ch: Node2D, char_index: int) -> void:
	var left_leg = ch.get_node_or_null("LeftLeg") as Line2D
	var right_leg = ch.get_node_or_null("RightLeg") as Line2D
	if not left_leg or not right_leg:
		return
	var spd_factor = 1.0
	if char_index < _crowd_walk_speeds.size():
		spd_factor = _crowd_walk_speeds[char_index] / 35.0  # normalize around avg
	var step_dur = clampf(0.30 / spd_factor, 0.18, 0.50)
	var walk_legs = create_tween().set_loops()
	_tweens.append(walk_legs)
	walk_legs.tween_property(left_leg, "rotation_degrees", -12.0, step_dur)
	walk_legs.parallel().tween_property(right_leg, "rotation_degrees", 12.0, step_dur)
	walk_legs.tween_property(left_leg, "rotation_degrees", 12.0, step_dur)
	walk_legs.parallel().tween_property(right_leg, "rotation_degrees", -12.0, step_dur)

	# Arm swing
	var left_arm = ch.get_node_or_null("LeftArm") as Line2D
	var right_arm = ch.get_node_or_null("RightArm") as Line2D
	if left_arm and right_arm:
		var arm_swing = create_tween().set_loops()
		_tweens.append(arm_swing)
		arm_swing.tween_property(left_arm, "rotation_degrees", 10.0, step_dur)
		arm_swing.parallel().tween_property(right_arm, "rotation_degrees", -10.0, step_dur)
		arm_swing.tween_property(left_arm, "rotation_degrees", -10.0, step_dur)
		arm_swing.parallel().tween_property(right_arm, "rotation_degrees", 10.0, step_dur)

	if _main_character:
		_start_main_character_showtime()


func _start_character_personality_animation(ch: Node2D, char_index: int = 0) -> void:
	if not ch:
		return

	var reduce_motion = _should_reduce_mobile_motion()
	var role = str(ch.get_meta("role", "idle"))
	var left_arm = ch.get_node_or_null("LeftArm") as Line2D
	var right_arm = ch.get_node_or_null("RightArm") as Line2D
	var left_leg = ch.get_node_or_null("LeftLeg") as Line2D
	var right_leg = ch.get_node_or_null("RightLeg") as Line2D
	var prop = ch.get_node_or_null("RoleProp") as Label
	var note = ch.get_node_or_null("RoleNote") as Label
	var base_x = ch.position.x
	var phase_offset = 0.08 * char_index

	match role:
		"dancer":
			var groove = create_tween().set_loops()
			_tweens.append(groove)
			groove.tween_interval(phase_offset)
			groove.tween_property(ch, "rotation", deg_to_rad(3.2), 0.60)
			groove.parallel().tween_property(ch, "position:x", base_x + 3.5, 0.60)
			groove.tween_property(ch, "rotation", deg_to_rad(-2.8), 0.62)
			groove.parallel().tween_property(ch, "position:x", base_x - 3.0, 0.62)
			groove.tween_property(ch, "rotation", 0.0, 0.44)
			groove.parallel().tween_property(ch, "position:x", base_x, 0.44)
			if left_arm and right_arm and not reduce_motion:
				var arms = create_tween().set_loops()
				_tweens.append(arms)
				arms.tween_interval(phase_offset)
				arms.tween_property(left_arm, "rotation_degrees", -14.0, 0.55)
				arms.parallel().tween_property(right_arm, "rotation_degrees", 12.0, 0.55)
				arms.tween_property(left_arm, "rotation_degrees", 7.0, 0.55)
				arms.parallel().tween_property(right_arm, "rotation_degrees", -6.0, 0.55)
		"musician":
			if right_arm:
				var strum = create_tween().set_loops()
				_tweens.append(strum)
				strum.tween_interval(phase_offset)
				strum.tween_property(right_arm, "rotation_degrees", 18.0, 0.42)
				strum.tween_property(right_arm, "rotation_degrees", -8.0, 0.42)
				strum.tween_property(right_arm, "rotation_degrees", 4.0, 0.40)
			if left_arm:
				var hold = create_tween().set_loops()
				_tweens.append(hold)
				hold.tween_interval(phase_offset)
				hold.tween_property(left_arm, "rotation_degrees", -4.0, 0.90)
				hold.tween_property(left_arm, "rotation_degrees", 2.0, 0.90)
			if note and not reduce_motion:
				var note_float = create_tween().set_loops()
				_tweens.append(note_float)
				var note_base = note.position
				note_float.tween_interval(phase_offset)
				note_float.tween_property(note, "position:y", note_base.y - 6, 0.75)
				note_float.parallel().tween_property(note, "modulate:a", 0.55, 0.75)
				note_float.tween_property(note, "position:y", note_base.y, 0.75)
				note_float.parallel().tween_property(note, "modulate:a", 0.9, 0.75)
		"baller":
			if prop:
				var ball = create_tween().set_loops()
				_tweens.append(ball)
				var ball_base = prop.position
				ball.tween_interval(phase_offset)
				ball.tween_property(prop, "position:y", ball_base.y - 9, 0.34)
				ball.tween_property(prop, "position:y", ball_base.y, 0.24)
				ball.tween_property(prop, "position:y", ball_base.y - 4, 0.22)
				ball.tween_property(prop, "position:y", ball_base.y, 0.22)
			if left_leg and right_leg and not reduce_motion:
				var footwork = create_tween().set_loops()
				_tweens.append(footwork)
				footwork.tween_interval(phase_offset)
				footwork.tween_property(left_leg, "rotation_degrees", -8.0, 0.52)
				footwork.parallel().tween_property(right_leg, "rotation_degrees", 6.0, 0.52)
				footwork.tween_property(left_leg, "rotation_degrees", 3.5, 0.52)
				footwork.parallel().tween_property(right_leg, "rotation_degrees", -2.5, 0.52)
		"cheerer":
			if left_arm and right_arm:
				var cheer = create_tween().set_loops()
				_tweens.append(cheer)
				cheer.tween_interval(phase_offset)
				cheer.tween_property(left_arm, "rotation_degrees", -18.0, 0.46)
				cheer.parallel().tween_property(right_arm, "rotation_degrees", 4.0, 0.46)
				cheer.tween_property(left_arm, "rotation_degrees", -4.0, 0.42)
				cheer.parallel().tween_property(right_arm, "rotation_degrees", 17.0, 0.42)
				cheer.tween_property(left_arm, "rotation_degrees", -10.0, 0.38)
				cheer.parallel().tween_property(right_arm, "rotation_degrees", 8.0, 0.38)
			if prop and not reduce_motion:
				var confetti = create_tween().set_loops()
				_tweens.append(confetti)
				var prop_base = prop.position
				confetti.tween_interval(phase_offset)
				confetti.tween_property(prop, "position:y", prop_base.y - 5, 0.64)
				confetti.parallel().tween_property(prop, "modulate:a", 0.65, 0.64)
				confetti.tween_property(prop, "position:y", prop_base.y, 0.64)
				confetti.parallel().tween_property(prop, "modulate:a", 1.0, 0.64)


func _start_main_character_showtime() -> void:
	if not _main_character:
		return

	var hero_scale = _get_hero_base_scale()
	var hero_bounce_amp = _get_hero_bounce_amplitude()
	var reduce_motion = _should_reduce_mobile_motion()
	var hero_base_y = _main_character.position.y
	var hero_base_x = _main_character.position.x
	var left_arm = _main_character.get_node_or_null("LeftArm") as Line2D
	var right_arm = _main_character.get_node_or_null("RightArm") as Line2D
	var left_leg = _main_character.get_node_or_null("LeftLeg") as Line2D
	var right_leg = _main_character.get_node_or_null("RightLeg") as Line2D
	var sparkle = _main_character.get_node_or_null("RoleProp") as Label

	var hero_bounce = create_tween().set_loops()
	_tweens.append(hero_bounce)
	hero_bounce.tween_property(
		_main_character,
		"position:y",
		hero_base_y - hero_bounce_amp,
		1.05
	).set_trans(Tween.TRANS_SINE)
	hero_bounce.tween_property(
		_main_character,
		"scale",
		Vector2(hero_scale * 1.02, hero_scale * 0.98),
		0.38
	)
	hero_bounce.tween_property(
		_main_character,
		"position:y",
		hero_base_y,
		1.05
	).set_trans(Tween.TRANS_SINE)
	hero_bounce.tween_property(
		_main_character,
		"scale",
		Vector2(hero_scale, hero_scale),
		0.38
	)

	var hero_sway = create_tween().set_loops()
	_tweens.append(hero_sway)
	hero_sway.tween_property(_main_character, "rotation", deg_to_rad(2.4), 1.10)
	hero_sway.parallel().tween_property(_main_character, "position:x", hero_base_x + 3.0, 1.10)
	hero_sway.tween_property(_main_character, "rotation", deg_to_rad(-2.0), 1.06)
	hero_sway.parallel().tween_property(_main_character, "position:x", hero_base_x - 2.8, 1.06)
	hero_sway.tween_property(_main_character, "rotation", 0.0, 0.72)
	hero_sway.parallel().tween_property(_main_character, "position:x", hero_base_x, 0.72)

	if left_arm and right_arm:
		var hero_wave = create_tween().set_loops()
		_tweens.append(hero_wave)
		hero_wave.tween_property(left_arm, "rotation_degrees", -14.0, 0.62)
		hero_wave.parallel().tween_property(right_arm, "rotation_degrees", 11.0, 0.62)
		hero_wave.tween_property(left_arm, "rotation_degrees", 6.0, 0.62)
		hero_wave.parallel().tween_property(right_arm, "rotation_degrees", -5.0, 0.62)

	if left_leg and right_leg and not reduce_motion:
		var hero_steps = create_tween().set_loops()
		_tweens.append(hero_steps)
		hero_steps.tween_property(left_leg, "rotation_degrees", -5.0, 0.70)
		hero_steps.parallel().tween_property(right_leg, "rotation_degrees", 4.0, 0.70)
		hero_steps.tween_property(left_leg, "rotation_degrees", 2.5, 0.70)
		hero_steps.parallel().tween_property(right_leg, "rotation_degrees", -2.0, 0.70)

	if sparkle:
		var star_twinkle = create_tween().set_loops()
		_tweens.append(star_twinkle)
		var sparkle_base = sparkle.position
		star_twinkle.tween_property(sparkle, "position:y", sparkle_base.y - 5, 0.68)
		star_twinkle.parallel().tween_property(sparkle, "modulate:a", 0.55, 0.68)
		star_twinkle.tween_property(sparkle, "position:y", sparkle_base.y, 0.68)
		star_twinkle.parallel().tween_property(sparkle, "modulate:a", 1.0, 0.68)


# ── Button handlers ─────────────────────────────────────────────────

func _on_play_pressed() -> void:
	if _is_loading_game:
		return

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

	if _main_character:
		var hero_scale = _get_hero_base_scale()
		var hero_exit = create_tween()
		hero_exit.tween_interval(0.24)
		hero_exit.tween_property(
			_main_character,
			"scale",
			Vector2(hero_scale * 1.16, hero_scale * 0.68),
			0.08
		)
		hero_exit.tween_property(
			_main_character, "position:y", _main_character.position.y - 470, 0.38
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	# Transition after last character exits
	await get_tree().create_timer(0.6).timeout
	await _load_game_entry_and_start()


func _load_game_entry_and_start() -> void:
	_is_loading_game = true
	_show_loading_overlay()

	var bridge_scene_path := "res://scenes/ui/cutscenes/MiniGameIntroBridge.tscn"
	var request_err := ResourceLoader.load_threaded_request(
		bridge_scene_path,
		"PackedScene",
		false
	)
	if request_err != OK:
		push_warning(
			"Could not start threaded load for %s (%d)."
			% [bridge_scene_path, request_err]
		)
		_loading_bar.value = 100.0
		await _finish_loading_and_start()
		return

	while _is_loading_game:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(bridge_scene_path, progress)

		if not progress.is_empty() and _loading_bar:
			_loading_bar.value = clamp(float(progress[0]) * 100.0, 0.0, 100.0)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(bridge_scene_path)
			if _loading_bar:
				_loading_bar.value = 100.0
			await _finish_loading_and_start()
			return

		if (
			status == ResourceLoader.THREAD_LOAD_FAILED
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		):
			push_warning("Threaded load failed for %s" % bridge_scene_path)
			if _loading_bar:
				_loading_bar.value = 100.0
			await _finish_loading_and_start()
			return

		await get_tree().process_frame


func _start_session_flow() -> void:
	if GameManager:
		if GameManager.has_method("start_session"):
			GameManager.start_session()
		elif GameManager.has_method("start_new_session"):
			GameManager.start_new_session()
			if GameManager.has_method("start_next_minigame"):
				GameManager.start_next_minigame()
	else:
		get_tree().change_scene_to_file("res://scenes/minigames/CatchTheRain.tscn")


func _show_loading_overlay() -> void:
	if _loading_overlay and is_instance_valid(_loading_overlay):
		_loading_overlay.queue_free()

	_loading_overlay = Control.new()
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.z_index = 220
	add_child(_loading_overlay)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_loading_overlay.add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 140)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading_overlay.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.98, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	vbox.offset_left = 22
	vbox.offset_top = 18
	vbox.offset_right = -22
	vbox.offset_bottom = -18
	panel.add_child(vbox)

	_loading_text = Label.new()
	_loading_text.text = _loc("loading_game", "Loading game...")
	_loading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_text.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_loading_text)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(0, 24)
	_loading_bar.show_percentage = true
	_loading_bar.value = 0.0
	vbox.add_child(_loading_bar)

	_loading_started_ms = Time.get_ticks_msec()


func _finish_loading_and_start() -> void:
	var elapsed_ms = Time.get_ticks_msec() - _loading_started_ms
	if elapsed_ms < MIN_LOADING_VISIBLE_MS:
		var wait_seconds = float(MIN_LOADING_VISIBLE_MS - elapsed_ms) / 1000.0
		await get_tree().create_timer(wait_seconds).timeout

	_hide_loading_overlay()
	_is_loading_game = false
	_start_session_flow()


func _hide_loading_overlay() -> void:
	if _loading_overlay and is_instance_valid(_loading_overlay):
		_loading_overlay.queue_free()
	_loading_overlay = null
	_loading_bar = null
	_loading_text = null
	_loading_started_ms = 0


func _on_multiplayer_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_go_to_scene([
		"res://scenes/ui/MultiplayerLobby.tscn",
		"res://scenes/ui/MultiplayerMenu.tscn"
	])


func _on_customize_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_go_to_scene(["res://scenes/ui/CharacterCustomization.tscn"])


func _on_store_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_go_to_scene(["res://scenes/ui/UnlockablesScreen.tscn"])


func _on_roadmap_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_go_to_scene([
		"res://scenes/ui/RoadmapScreen.tscn",
		"res://scenes/ui/UnlockablesScreen.tscn"
	])


func _on_settings_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_go_to_scene(["res://scenes/ui/Settings.tscn"])


func _on_accessibility_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if AccessibilityManager:
		AccessibilityManager.toggle_menu()


# ── Welcome popup ───────────────────────────────────────────────────

func _setup_welcome_popup() -> void:
	var first := false
	if GameManager and GameManager.has_method("should_show_welcome_popup"):
		first = GameManager.should_show_welcome_popup()
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
	if GameManager and GameManager.has_method("mark_welcome_shown"):
		GameManager.mark_welcome_shown()
	var tw = create_tween()
	tw.tween_property(welcome_panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): welcome_popup.visible = false)


# Compatibility wrappers for signal names stored in InitialScreen.tscn.
func _on_play_button_pressed() -> void:
	_on_play_pressed()


func _on_multiplayer_button_pressed() -> void:
	_on_multiplayer_pressed()


func _on_customize_button_pressed() -> void:
	_on_customize_pressed()


func _on_store_button_pressed() -> void:
	_on_store_pressed()


func _on_roadmap_button_pressed() -> void:
	_on_roadmap_pressed()


func _on_settings_button_pressed() -> void:
	_on_settings_pressed()


func _on_close_popup_pressed() -> void:
	_on_welcome_ok_pressed()


func _update_next_unlock_panel(current_droplets: int) -> void:
	if not next_unlock_progress or not next_unlock_label:
		return

	var previous_threshold := 0
	var next_threshold := -1

	for threshold in CHARACTER_UNLOCK_THRESHOLDS:
		if current_droplets < threshold:
			next_threshold = threshold
			break
		previous_threshold = threshold

	if next_threshold < 0:
		next_unlock_progress.value = 100.0
		next_unlock_label.text = _loc(
			"all_character_unlocks_owned",
			"All character unlocks owned"
		)
		return

	var segment = max(1, next_threshold - previous_threshold)
	var in_segment = max(0, current_droplets - previous_threshold)
	next_unlock_progress.value = clamp((float(in_segment) / float(segment)) * 100.0, 0.0, 100.0)
	var remaining = next_threshold - current_droplets
	next_unlock_label.text = _loc("points_to_go", "%d points to go") % remaining


# ── Helpers ─────────────────────────────────────────────────────────

func _oval(w: float, h: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a) * w, sin(a) * h))
	return pts


func _get_texturerect_drawn_rect(tex_rect: TextureRect) -> Rect2:
	# Returns the screen-space Rect2 where the texture is actually
	# drawn, accounting for stretch_mode KEEP_ASPECT_COVERED (6).
	if not tex_rect or not tex_rect.texture:
		return Rect2(tex_rect.global_position, tex_rect.size * tex_rect.scale)
	var tex_sz = tex_rect.texture.get_size()
	var node_sz = tex_rect.size * tex_rect.scale
	var sx = node_sz.x / tex_sz.x
	var sy = node_sz.y / tex_sz.y
	var s = max(sx, sy)  # keep_aspect_covered uses max
	var drawn_sz = tex_sz * s
	var offset = (node_sz - drawn_sz) * 0.5
	return Rect2(
		tex_rect.global_position + offset,
		drawn_sz
	)


func _exit_tree() -> void:
	_is_loading_game = false
	_hide_loading_overlay()
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
