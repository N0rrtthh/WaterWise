extends Control

signal cutscene_finished

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Center/VBox/Title
@onready var line_label: Label = $Panel/Center/VBox/Line
@onready var stats_label: Label = $Panel/Center/VBox/Stats
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var icon_label: Label
var streak_back: ColorRect
var streak_front: ColorRect
var flash_beat: ColorRect
var _water_droplet: Node2D = null
var _outro_particles: Array[Node] = []
var _scene_bg: Control = null
var _is_success: bool = true
var _scene_key: String = ""

var anim_options: Dictionary = {
	"speed": 1.0,
	"distance": 1.0,
	"pop": 1.0
}

func _ready() -> void:
	_ensure_cinematic_nodes()
	_rebuild_animation()

func configure(
	success: bool,
	line: String,
	score: int,
	combo: int,
	lives: int,
	options: Dictionary = {}
) -> void:
	_is_success = success
	_ensure_cinematic_nodes()
	var outcome_theme := _build_outcome_theme(success)
	title_label.text = "Scene Complete" if success else "Scene Failed"
	title_label.add_theme_color_override("font_color", outcome_theme["title_color"])
	if icon_label:
		icon_label.text = str(outcome_theme["icon"])
	line_label.text = line
	line_label.add_theme_color_override("font_color", outcome_theme["line_color"])
	stats_label.add_theme_color_override("font_color", outcome_theme["stats_color"])
	overlay.color = outcome_theme["overlay_color"]
	if streak_back:
		streak_back.color = outcome_theme["streak_back_color"]
	if streak_front:
		streak_front.color = outcome_theme["streak_front_color"]
	stats_label.text = "+%d pts   |   Combo x%d   |   Lives %s" % [
		score,
		combo,
		"❤".repeat(max(lives, 0))
	]
	for key in options.keys():
		anim_options[key] = options[key]
	_rebuild_animation()

func play_cutscene() -> void:
	_scene_key = _extract_scene_key()
	if AudioManager:
		AudioManager.play_game_end()
		AudioManager.play_music("outcome_win" if _is_success else "outcome_fail", 0.3)
	if not animation_player.has_animation("outro"):
		_rebuild_animation()
	
	# Spawn full-scene DWTD-style background
	_build_scene_background()
	
	# Spawn animated droplet character
	_spawn_outro_droplet()
	_spawn_outcome_particles()
	
	# Check if animation exists after rebuild
	if animation_player.has_animation("outro"):
		animation_player.play("outro")
		_run_outro_character_vfx()
		await animation_player.animation_finished
	else:
		_run_outro_character_vfx()
		await get_tree().create_timer(5.0).timeout
	
	_cleanup_outro_vfx()
	cutscene_finished.emit()

func _rebuild_animation() -> void:
	_ensure_cinematic_nodes()
	var speed = max(0.4, float(anim_options.get("speed", 1.0)))
	var distance = clamp(float(anim_options.get("distance", 1.0)), 0.6, 1.6)
	var pop = clamp(float(anim_options.get("pop", 1.0)), 0.6, 1.6)
	var length = 5.0 / speed
	var in_t = length * 0.12
	var hold_t = length * 0.85

	var enter_from_y = -170.0 - (110.0 * distance)
	var enter_to_y = -170.0
	var exit_to_y = -220.0 - (25.0 * distance)
	var scale_from = 0.82
	var scale_peak = 1.0 + (0.03 * pop)
	var icon_pop = 1.0 + (0.09 * pop)

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
	anim.track_insert_key(streak_back_alpha, in_t * 0.6, 0.65)
	anim.track_insert_key(streak_back_alpha, hold_t, 0.35)
	anim.track_insert_key(streak_back_alpha, length, 0.0)

	var streak_back_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_back_pos, NodePath("StreakBack:position:x"))
	anim.track_insert_key(streak_back_pos, 0.0, 260.0)
	anim.track_insert_key(streak_back_pos, hold_t, -160.0)
	anim.track_insert_key(streak_back_pos, length, -260.0)

	var streak_front_alpha := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_front_alpha, NodePath("StreakFront:modulate:a"))
	anim.track_insert_key(streak_front_alpha, 0.0, 0.0)
	anim.track_insert_key(streak_front_alpha, in_t, 0.55)
	anim.track_insert_key(streak_front_alpha, hold_t, 0.2)
	anim.track_insert_key(streak_front_alpha, length, 0.0)

	var streak_front_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(streak_front_pos, NodePath("StreakFront:position:x"))
	anim.track_insert_key(streak_front_pos, 0.0, -340.0)
	anim.track_insert_key(streak_front_pos, hold_t, 60.0)
	anim.track_insert_key(streak_front_pos, length, 220.0)

	var flash_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(flash_track, NodePath("FlashBeat:modulate:a"))
	anim.track_insert_key(flash_track, 0.0, 0.0)
	anim.track_insert_key(flash_track, in_t * 0.9, 0.28)
	anim.track_insert_key(flash_track, in_t * 1.2, 0.0)

	var panel_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(panel_track, NodePath("Panel:offset_top"))
	anim.track_insert_key(panel_track, 0.0, enter_from_y)
	anim.track_insert_key(panel_track, in_t, enter_to_y)
	anim.track_insert_key(panel_track, hold_t, enter_to_y)
	anim.track_insert_key(panel_track, length, exit_to_y)

	var scale_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(scale_track, NodePath("Panel:scale"))
	anim.track_insert_key(scale_track, 0.0, Vector2(scale_from, scale_from))
	anim.track_insert_key(scale_track, in_t * 1.1, Vector2(scale_peak, scale_peak))
	anim.track_insert_key(scale_track, in_t * 1.9, Vector2(1.0, 1.0))

	var icon_scale_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(icon_scale_track, NodePath("Panel/Center/VBox/Icon:scale"))
	anim.track_insert_key(icon_scale_track, 0.0, Vector2(0.75, 0.75))
	anim.track_insert_key(icon_scale_track, in_t * 1.1, Vector2(icon_pop, icon_pop))
	anim.track_insert_key(icon_scale_track, in_t * 1.8, Vector2(1.0, 1.0))

	var icon_rot_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(icon_rot_track, NodePath("Panel/Center/VBox/Icon:rotation"))
	anim.track_insert_key(icon_rot_track, 0.0, -0.18)
	anim.track_insert_key(icon_rot_track, in_t * 1.3, 0.06)
	anim.track_insert_key(icon_rot_track, in_t * 1.8, 0.0)

	var icon_alpha_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(icon_alpha_track, NodePath("Panel/Center/VBox/Icon:modulate:a"))
	anim.track_insert_key(icon_alpha_track, 0.0, 0.0)
	anim.track_insert_key(icon_alpha_track, in_t * 1.0, 1.0)

	var title_alpha_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(title_alpha_track, NodePath("Panel/Center/VBox/Title:modulate:a"))
	anim.track_insert_key(title_alpha_track, 0.0, 0.0)
	anim.track_insert_key(title_alpha_track, in_t * 1.1, 1.0)

	var stats_alpha_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(stats_alpha_track, NodePath("Panel/Center/VBox/Stats:modulate:a"))
	anim.track_insert_key(stats_alpha_track, 0.0, 0.0)
	anim.track_insert_key(stats_alpha_track, in_t * 1.45, 1.0)

	# Ensure animation_player exists and is ready
	if not animation_player or not is_instance_valid(animation_player):
		push_error("AnimationPlayer node not found or invalid in MiniGameOutroCutscene")
		return
	
	# Get or create the animation library
	var library: AnimationLibrary = null
	if animation_player.has_animation_library(""):
		library = animation_player.get_animation_library("")
	
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	
	# Add or replace the animation
	if library.has_animation("outro"):
		library.remove_animation("outro")
	library.add_animation("outro", anim)

func _ensure_cinematic_nodes() -> void:
	if not has_node("StreakBack"):
		streak_back = ColorRect.new()
		streak_back.name = "StreakBack"
		streak_back.color = Color(0.15, 0.95, 0.85, 0.5)
		streak_back.size = Vector2(680, 30)
		streak_back.position = Vector2(260, 210)
		add_child(streak_back)

	if not has_node("StreakFront"):
		streak_front = ColorRect.new()
		streak_front.name = "StreakFront"
		streak_front.color = Color(1.0, 0.85, 0.3, 0.4)
		streak_front.size = Vector2(520, 18)
		streak_front.position = Vector2(-300, 500)
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
		icon_label.text = "🏆"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 66)
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

func _build_outcome_theme(success: bool) -> Dictionary:
	var key := _extract_scene_key()
	var hue_seed = abs(hash(key)) % 1000
	var hue = float(hue_seed) / 1000.0
	var hue_shifted = fmod(hue + 0.14, 1.0)

	var title_color = (
		Color.from_hsv(hue, 0.55, 0.98)
		if success
		else Color.from_hsv(hue_shifted, 0.72, 1.0)
	)
	var line_color = (
		Color.from_hsv(hue, 0.35, 0.95)
		if success
		else Color.from_hsv(hue_shifted, 0.45, 0.96)
	)
	var stats_color = (
		Color.from_hsv(hue, 0.55, 0.95)
		if success
		else Color.from_hsv(hue_shifted, 0.62, 0.98)
	)
	var overlay_color = (
		Color.from_hsv(hue, 0.65, 0.23, 0.84)
		if success
		else Color.from_hsv(hue_shifted, 0.75, 0.2, 0.88)
	)
	var streak_back_color = (
		Color.from_hsv(hue, 0.65, 0.95, 0.5)
		if success
		else Color.from_hsv(hue_shifted, 0.65, 0.95, 0.45)
	)
	var streak_front_color = (
		Color.from_hsv(fmod(hue + 0.06, 1.0), 0.55, 1.0, 0.45)
		if success
		else Color.from_hsv(fmod(hue_shifted + 0.06, 1.0), 0.62, 1.0, 0.4)
	)

	return {
		"icon": _pick_icon_for_key(success, key),
		"title_color": title_color,
		"line_color": line_color,
		"stats_color": stats_color,
		"overlay_color": overlay_color,
		"streak_back_color": streak_back_color,
		"streak_front_color": streak_front_color
	}

func _extract_scene_key() -> String:
	var scene_name = name
	for suffix in ["WinOutro", "LoseOutro", "Outro", "Cutscene"]:
		scene_name = scene_name.trim_suffix(suffix)
	if scene_name == "":
		return "MiniGame"
	return scene_name

func _pick_icon_for_key(success: bool, key: String) -> String:
	if "Rain" in key:
		return "🌦" if success else "🌧"
	if "Leak" in key or "Tap" in key or "Pipe" in key:
		return "🔧" if success else "🫗"
	if "Plant" in key or "Vegetable" in key:
		return "🌿" if success else "🥀"
	if "Filter" in key or "Speck" in key or "Sort" in key:
		return "🧪" if success else "🧫"
	if "Shower" in key or "Soap" in key or "Scrub" in key:
		return "🫧" if success else "🧼"
	if "Bucket" in key or "Drum" in key or "Tank" in key:
		return "🪣" if success else "🛢"
	if "Rice" in key or "Mud" in key:
		return "🍃" if success else "💧"
	if "Timing" in key or "Trace" in key:
		return "🎯" if success else "⌛"
	return "🏆" if success else "💥"

# ── Full-Scene DWTD-style Backgrounds ─────────────────────────────

func _build_scene_background() -> void:
	var vp = get_viewport_rect().size
	_scene_bg = Control.new()
	_scene_bg.name = "SceneBG"
	_scene_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_bg.modulate.a = 0.0
	add_child(_scene_bg)
	# Put behind the panel but above the overlay
	move_child(_scene_bg, 1)

	if _is_success:
		_build_success_scene(vp)
	else:
		_build_failure_scene(vp)

	# Fade in the whole background scene
	var fade = create_tween()
	fade.tween_property(_scene_bg, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)

func _build_success_scene(vp: Vector2) -> void:
	# Warm celebration background — sunny golden stage
	var sky = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = Color(0.98, 0.92, 0.75)  # Warm cream/beige
	_scene_bg.add_child(sky)

	# Subtle gradient overlay — lighter at top
	var gradient_top = ColorRect.new()
	gradient_top.size = Vector2(vp.x, vp.y * 0.4)
	gradient_top.color = Color(1.0, 0.98, 0.88, 0.5)
	_scene_bg.add_child(gradient_top)

	# Ground / stage floor
	var ground = ColorRect.new()
	ground.size = Vector2(vp.x, vp.y * 0.25)
	ground.position = Vector2(0, vp.y * 0.75)
	ground.color = Color(0.88, 0.78, 0.6)  # Sandy
	_scene_bg.add_child(ground)

	# Stage spotlight glow (center circle)
	var spotlight = Polygon2D.new()
	var sp_pts = PackedVector2Array()
	for i in range(20):
		var a = i * TAU / 20
		sp_pts.append(
			Vector2(cos(a) * vp.x * 0.3, sin(a) * vp.y * 0.15)
			+ Vector2(vp.x * 0.5, vp.y * 0.72)
		)
	spotlight.polygon = sp_pts
	spotlight.color = Color(1.0, 1.0, 0.85, 0.2)
	_scene_bg.add_child(spotlight)

	# Confetti / celebration bunting across top
	for i in range(8):
		var bunting = Polygon2D.new()
		var bx = vp.x * (float(i) / 7.0)
		var by = 30.0 + sin(i * 0.9) * 15.0
		bunting.polygon = PackedVector2Array([
			Vector2(bx - 8, by), Vector2(bx + 8, by),
			Vector2(bx, by + 18),
		])
		bunting.color = [
			Color(1.0, 0.4, 0.4, 0.7), Color(0.4, 0.8, 1.0, 0.7),
			Color(1.0, 0.85, 0.3, 0.7), Color(0.5, 1.0, 0.5, 0.7),
			Color(1.0, 0.6, 0.8, 0.7), Color(0.6, 0.5, 1.0, 0.7),
			Color(1.0, 0.7, 0.3, 0.7), Color(0.3, 0.9, 0.8, 0.7),
		][i % 8]
		_scene_bg.add_child(bunting)

	# Bunting string across top
	var string_line = Line2D.new()
	string_line.width = 2.0
	string_line.default_color = Color(0.5, 0.4, 0.3, 0.5)
	for i in range(9):
		var sx = vp.x * (float(i) / 8.0)
		var sy = 28.0 + sin(i * 0.9) * 12.0
		string_line.add_point(Vector2(sx, sy))
	_scene_bg.add_child(string_line)

	# Floating confetti pieces
	for i in range(12):
		var conf = ColorRect.new()
		conf.size = Vector2(randf_range(4, 10), randf_range(4, 10))
		conf.position = Vector2(randf_range(20, vp.x - 20), randf_range(40, vp.y * 0.6))
		conf.rotation = randf_range(0, TAU)
		conf.color = [
			Color(1.0, 0.4, 0.4, 0.4), Color(0.4, 0.8, 1.0, 0.4),
			Color(1.0, 0.85, 0.3, 0.4), Color(0.5, 1.0, 0.5, 0.4),
		][i % 4]
		conf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_bg.add_child(conf)
		# Slowly spin and drift
		var ct = create_tween()
		ct.set_loops(10)
		ct.tween_property(conf, "rotation", conf.rotation + randf_range(-2, 2), 1.5)
		ct.tween_property(conf, "position:y", conf.position.y + randf_range(10, 30), 1.5)

func _build_failure_scene(vp: Vector2) -> void:
	# DWTD hospital / clinical failure scene
	var wall = ColorRect.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.color = Color(0.85, 0.9, 0.92)  # Pale clinical blue-grey
	_scene_bg.add_child(wall)

	# Floor tiles
	var floor_rect = ColorRect.new()
	floor_rect.size = Vector2(vp.x, vp.y * 0.2)
	floor_rect.position = Vector2(0, vp.y * 0.8)
	floor_rect.color = Color(0.78, 0.82, 0.78)  # Green linoleum
	_scene_bg.add_child(floor_rect)

	# Floor line divider
	var floor_line = Line2D.new()
	floor_line.width = 2.0
	floor_line.default_color = Color(0.65, 0.7, 0.65, 0.5)
	floor_line.add_point(Vector2(0, vp.y * 0.8))
	floor_line.add_point(Vector2(vp.x, vp.y * 0.8))
	_scene_bg.add_child(floor_line)

	# Hospital bed (right side)
	var bed_base = Polygon2D.new()
	bed_base.polygon = PackedVector2Array([
		Vector2(-50, -5), Vector2(50, -5), Vector2(50, 5), Vector2(-50, 5),
	])
	bed_base.color = Color(0.6, 0.6, 0.65)
	bed_base.position = Vector2(vp.x * 0.65, vp.y * 0.68)
	_scene_bg.add_child(bed_base)

	# Bed mattress
	var mattress = Polygon2D.new()
	mattress.polygon = PackedVector2Array([
		Vector2(-48, -12), Vector2(48, -12), Vector2(48, -2), Vector2(-48, -2),
	])
	mattress.color = Color(0.95, 0.95, 0.98)
	mattress.position = Vector2(vp.x * 0.65, vp.y * 0.68)
	_scene_bg.add_child(mattress)

	# Pillow
	var pillow = Polygon2D.new()
	var pill_pts = PackedVector2Array()
	for i in range(10):
		var a = i * TAU / 10
		pill_pts.append(
			Vector2(cos(a) * 14, sin(a) * 8)
			+ Vector2(vp.x * 0.65 + 30, vp.y * 0.68 - 16)
		)
	pillow.polygon = pill_pts
	pillow.color = Color(0.98, 0.98, 1.0)
	_scene_bg.add_child(pillow)

	# Bed legs
	for lx in [-48, 48]:
		var leg = Line2D.new()
		leg.width = 4.0
		leg.default_color = Color(0.5, 0.5, 0.55)
		leg.add_point(Vector2(vp.x * 0.65 + lx, vp.y * 0.68 + 5))
		leg.add_point(Vector2(vp.x * 0.65 + lx, vp.y * 0.68 + 25))
		_scene_bg.add_child(leg)

	# IV drip stand (left of bed)
	var iv_stand = Line2D.new()
	iv_stand.width = 3.0
	iv_stand.default_color = Color(0.6, 0.6, 0.65)
	iv_stand.add_point(Vector2(vp.x * 0.5, vp.y * 0.75))
	iv_stand.add_point(Vector2(vp.x * 0.5, vp.y * 0.35))
	_scene_bg.add_child(iv_stand)

	# IV hook
	var iv_hook = Line2D.new()
	iv_hook.width = 2.5
	iv_hook.default_color = Color(0.6, 0.6, 0.65)
	iv_hook.add_point(Vector2(vp.x * 0.5 - 8, vp.y * 0.35))
	iv_hook.add_point(Vector2(vp.x * 0.5 + 8, vp.y * 0.35))
	_scene_bg.add_child(iv_hook)

	# IV bag
	var iv_bag = Polygon2D.new()
	iv_bag.polygon = PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(5, 10), Vector2(-5, 10),
	])
	iv_bag.color = Color(0.7, 0.85, 1.0, 0.7)
	iv_bag.position = Vector2(vp.x * 0.5, vp.y * 0.35 + 14)
	_scene_bg.add_child(iv_bag)

	# IV tube going to bed
	var iv_tube = Line2D.new()
	iv_tube.width = 1.5
	iv_tube.default_color = Color(0.5, 0.7, 0.9, 0.5)
	iv_tube.add_point(Vector2(vp.x * 0.5, vp.y * 0.35 + 24))
	iv_tube.add_point(Vector2(vp.x * 0.55, vp.y * 0.55))
	iv_tube.add_point(Vector2(vp.x * 0.6, vp.y * 0.65))
	_scene_bg.add_child(iv_tube)

	# Heart monitor (small beeping lines)
	var monitor_bg = Polygon2D.new()
	monitor_bg.polygon = PackedVector2Array([
		Vector2(-18, -14), Vector2(18, -14), Vector2(18, 14), Vector2(-18, 14),
	])
	monitor_bg.color = Color(0.15, 0.18, 0.2)
	monitor_bg.position = Vector2(vp.x * 0.82, vp.y * 0.45)
	_scene_bg.add_child(monitor_bg)

	# Monitor EKG line
	var ekg = Line2D.new()
	ekg.name = "EKGLine"
	ekg.width = 1.5
	ekg.default_color = Color(0.3, 1.0, 0.4)
	var mon_x = vp.x * 0.82
	var mon_y = vp.y * 0.45
	ekg.add_point(Vector2(mon_x - 14, mon_y))
	ekg.add_point(Vector2(mon_x - 8, mon_y))
	ekg.add_point(Vector2(mon_x - 5, mon_y - 8))
	ekg.add_point(Vector2(mon_x - 2, mon_y + 6))
	ekg.add_point(Vector2(mon_x + 2, mon_y - 4))
	ekg.add_point(Vector2(mon_x + 5, mon_y))
	ekg.add_point(Vector2(mon_x + 14, mon_y))
	_scene_bg.add_child(ekg)

	# Red cross on wall
	var cross_h = ColorRect.new()
	cross_h.size = Vector2(20, 6)
	cross_h.position = Vector2(vp.x * 0.15 - 10, vp.y * 0.25 - 3)
	cross_h.color = Color(0.9, 0.2, 0.2, 0.7)
	_scene_bg.add_child(cross_h)
	var cross_v = ColorRect.new()
	cross_v.size = Vector2(6, 20)
	cross_v.position = Vector2(vp.x * 0.15 - 3, vp.y * 0.25 - 10)
	cross_v.color = Color(0.9, 0.2, 0.2, 0.7)
	_scene_bg.add_child(cross_v)

# ── Animated Water Droplet Character ──────────────────────────────

func _spawn_outro_droplet() -> void:
	var vp = get_viewport_rect().size
	_water_droplet = Node2D.new()
	_water_droplet.position = Vector2(vp.x * 0.5, vp.y * 0.48)
	_water_droplet.scale = Vector2.ZERO
	_water_droplet.modulate.a = 0.0
	add_child(_water_droplet)

	# ── Round blobby body (DWTD-style bean) ──
	var body = Polygon2D.new()
	body.name = "Body"
	var body_pts = PackedVector2Array()
	for i in range(20):
		var a = i * TAU / 20
		var rx = 30.0 + sin(a * 2) * 4
		var ry = 38.0 + cos(a * 3) * 3
		body_pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	body.polygon = body_pts
	body.color = Color(0.3, 0.72, 1.0) if _is_success else Color(0.45, 0.5, 0.75)
	_water_droplet.add_child(body)

	# ── Shine ──
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-10, -22), Vector2(-3, -26), Vector2(4, -22), Vector2(-3, -15),
	])
	shine.color = Color(1, 1, 1, 0.55)
	_water_droplet.add_child(shine)

	# ── Eyes ──
	if _is_success:
		for xoff in [-12, 12]:
			var eye = Polygon2D.new()
			var ep = PackedVector2Array()
			for i in range(16):
				var a = i * TAU / 16
				ep.append(Vector2(cos(a) * 11, sin(a) * 11) + Vector2(xoff, -8))
			eye.polygon = ep
			eye.color = Color.WHITE
			_water_droplet.add_child(eye)
			var pupil = Polygon2D.new()
			var pp = PackedVector2Array()
			for i in range(12):
				var a = i * TAU / 12
				pp.append(Vector2(cos(a) * 5.5, sin(a) * 5.5) + Vector2(xoff, -6))
			pupil.polygon = pp
			pupil.color = Color(0.08, 0.08, 0.08)
			_water_droplet.add_child(pupil)
			# Sparkle
			var sparkle = Polygon2D.new()
			var sp = PackedVector2Array()
			for i in range(4):
				var a2 = i * TAU / 4
				var r = 2.5 if i % 2 == 0 else 1.2
				sp.append(Vector2(cos(a2) * r, sin(a2) * r) + Vector2(xoff - 3, -11))
			sparkle.polygon = sp
			sparkle.color = Color(1, 1, 0.8)
			_water_droplet.add_child(sparkle)
	else:
		# X-eyes for failure
		for xoff in [-12, 12]:
			var eye_bg = Polygon2D.new()
			var ebp = PackedVector2Array()
			for i in range(16):
				var a = i * TAU / 16
				ebp.append(Vector2(cos(a) * 11, sin(a) * 11) + Vector2(xoff, -8))
			eye_bg.polygon = ebp
			eye_bg.color = Color(0.95, 0.95, 0.95)
			_water_droplet.add_child(eye_bg)
			for rot in [0.785, -0.785]:
				var x_line = Line2D.new()
				x_line.width = 3.0
				x_line.default_color = Color(0.2, 0.2, 0.2)
				x_line.add_point(Vector2(xoff - 5, -13))
				x_line.add_point(Vector2(xoff + 5, -3))
				x_line.rotation = rot
				_water_droplet.add_child(x_line)

	# ── Mouth ──
	var mouth = Line2D.new()
	mouth.name = "Mouth"
	mouth.width = 3.0
	mouth.default_color = Color(0.1, 0.1, 0.1)
	if _is_success:
		for i in range(9):
			var mt = float(i) / 8.0
			mouth.add_point(Vector2(lerp(-16.0, 16.0, mt), 10.0 + sin(mt * PI) * 12.0))
	else:
		for i in range(9):
			var mt = float(i) / 8.0
			mouth.add_point(Vector2(lerp(-14.0, 14.0, mt), 14.0 + sin(mt * PI * 3.0) * 3.5))
	_water_droplet.add_child(mouth)

	# ── Arms ──
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.name = "Arm_L" if side < 0 else "Arm_R"
		arm.width = 5.0
		arm.default_color = Color(0.25, 0.65, 0.95) if _is_success else Color(0.4, 0.45, 0.7)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		if _is_success:
			arm.add_point(Vector2(side * 28, 2))
			arm.add_point(Vector2(side * 44, -12))
			arm.add_point(Vector2(side * 50, -28))
		else:
			arm.add_point(Vector2(side * 28, 5))
			arm.add_point(Vector2(side * 40, 18))
			arm.add_point(Vector2(side * 38, 30))
		_water_droplet.add_child(arm)

	# ── Legs ──
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.name = "Leg_L" if side < 0 else "Leg_R"
		leg.width = 5.0
		leg.default_color = Color(0.25, 0.6, 0.9) if _is_success else Color(0.38, 0.42, 0.65)
		leg.add_point(Vector2(side * 10, 36))
		leg.add_point(Vector2(side * 12, 50))
		leg.add_point(Vector2(side * 16, 54))
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		_water_droplet.add_child(leg)

	# ── Blush (success only) ──
	if _is_success:
		for sx in [-22, 22]:
			var blush = Polygon2D.new()
			var bp = PackedVector2Array()
			for i in range(10):
				var a = i * TAU / 10
				bp.append(Vector2(cos(a) * 6, sin(a) * 4) + Vector2(sx, 6))
			blush.polygon = bp
			blush.color = Color(1, 0.45, 0.55, 0.28)
			_water_droplet.add_child(blush)

	# ── Failure extras: sweat + dizzy stars ──
	if not _is_success:
		for idx in range(2):
			var sweat = Polygon2D.new()
			sweat.polygon = PackedVector2Array([
				Vector2(0, -4), Vector2(2.5, 0), Vector2(1.5, 3),
				Vector2(0, 5), Vector2(-1.5, 3), Vector2(-2.5, 0),
			])
			sweat.color = Color(0.6, 0.85, 1.0, 0.7)
			sweat.position = Vector2([-22, 24][idx], [-26, -22][idx])
			_water_droplet.add_child(sweat)
		var stars_container = Node2D.new()
		stars_container.name = "DizzyStars"
		stars_container.position = Vector2(0, -55)
		_water_droplet.add_child(stars_container)
		for i in 3:
			var star = Label.new()
			star.text = ["⭐", "💫", "✦"][i]
			star.add_theme_font_size_override("font_size", 14)
			star.position = Vector2(cos(i * TAU / 3.0) * 20, sin(i * TAU / 3.0) * 8)
			stars_container.add_child(star)

	# ── Game-specific outcome props ──
	_add_outcome_props(_water_droplet, _scene_key, _is_success)

func _add_outcome_props(parent: Node2D, key: String, success: bool) -> void:
	match key:
		"WringItOut":
			if success:
				# Neatly folded clothes + sparkles
				_add_outcome_clothes(parent, Vector2(50, -10), true)
				_add_outcome_sparkles(parent, Vector2(50, -20), 3)
				# Crowd hearts (adored!)
				_add_outcome_hearts(parent, Vector2(-50, -30), 4)
			else:
				# Character "naked" with hands covering (leaf/barrel)
				_add_outcome_barrel_cover(parent, Vector2(0, 12))
				# Embarrassed blush lines
				_add_outcome_embarrass_lines(parent)
		"CatchTheRain":
			if success:
				# Full bucket with sparkle
				_add_outcome_full_bucket(parent, Vector2(48, -10))
				_add_outcome_sparkles(parent, Vector2(48, -20), 3)
			else:
				# Empty bucket, rain missed
				_add_outcome_empty_bucket(parent, Vector2(48, 10))
				_add_outcome_puddle(parent, Vector2(30, 40))
		"FixLeak", "PlugTheLeak":
			if success:
				# Pipe fixed with tape/wrench, water stopped
				_add_outcome_fixed_pipe(parent, Vector2(-55, 5))
				_add_outcome_sparkles(parent, Vector2(-55, -5), 2)
			else:
				# Water gushing everywhere
				_add_outcome_gushing_pipe(parent, Vector2(-55, 5))
				_add_outcome_puddle(parent, Vector2(0, 40))
		"FilterBuilder":
			if success:
				# Clean water in beaker
				_add_outcome_clean_beaker(parent, Vector2(50, 0))
				_add_outcome_sparkles(parent, Vector2(50, -15), 3)
			else:
				# Murky water, filter collapsed
				_add_outcome_dirty_beaker(parent, Vector2(50, 0))
		"QuickShower":
			if success:
				# Character with towel, clean and happy, timer shows good time
				_add_outcome_towel_wrap(parent, Vector2(0, 15))
				_add_outcome_sparkles(parent, Vector2(0, -20), 3)
			else:
				# Still dripping, wasted water indicator
				_add_outcome_dripping(parent, Vector2(0, -15), 5)
				_add_outcome_water_waste(parent, Vector2(50, 25))
		"CoverTheDrum":
			if success:
				# Drum sealed, clean water safe
				_add_outcome_sealed_drum(parent, Vector2(50, 15))
				_add_outcome_sparkles(parent, Vector2(50, 0), 2)
			else:
				# Bugs got in!
				_add_outcome_bugged_drum(parent, Vector2(50, 15))
		"RiceWashRescue":
			if success:
				# Rice water saved in jug, plant being watered
				_add_outcome_saved_water(parent, Vector2(50, 10))
				_add_outcome_happy_plant(parent, Vector2(50, -10))
			else:
				# Water poured down drain
				_add_outcome_wasted_down_drain(parent, Vector2(50, 15))
		"VegetableBath":
			if success:
				# Clean veggies, water reused
				_add_outcome_clean_veggies(parent, Vector2(50, 5))
				_add_outcome_sparkles(parent, Vector2(50, -8), 2)
			else:
				# Water wasted, veggies still dirty
				_add_outcome_dirty_veggies(parent, Vector2(50, 5))
		"GreywaterSorter":
			if success:
				# Properly sorted buckets
				_add_outcome_sorted_buckets(parent)
				_add_outcome_sparkles(parent, Vector2(0, -10), 3)
			else:
				# Mixed up mess
				_add_outcome_mixed_buckets(parent)
		"ThirstyPlant":
			if success:
				_add_outcome_happy_plant(parent, Vector2(50, 5))
				_add_outcome_sparkles(parent, Vector2(55, -10), 2)
			else:
				_add_outcome_dead_plant(parent, Vector2(50, 5))
		"MudPieMaker":
			if success:
				# Perfect mud pie
				_add_outcome_mud_pie(parent, Vector2(48, 5), true)
			else:
				# Too watery/dry mess
				_add_outcome_mud_pie(parent, Vector2(48, 5), false)
		"SpotTheSpeck":
			if success:
				# Clean water glass
				_add_outcome_clean_glass(parent, Vector2(50, 0))
				_add_outcome_sparkles(parent, Vector2(50, -12), 2)
			else:
				# Still dirty water
				_add_outcome_dirty_glass(parent, Vector2(50, 0))
		"SwipeTheSoap":
			if success:
				# Clean hands, minimal water
				_add_outcome_clean_hands(parent, Vector2(45, -15))
				_add_outcome_sparkles(parent, Vector2(45, -25), 3)
			else:
				# Soap flew away, water still running
				_add_outcome_flying_soap(parent)
		"BucketBrigade":
			if success:
				# All buckets delivered
				_add_outcome_bucket_stack(parent, Vector2(50, 15), true)
				_add_outcome_sparkles(parent, Vector2(50, 0), 3)
			else:
				# Spilled buckets
				_add_outcome_bucket_stack(parent, Vector2(50, 15), false)
				_add_outcome_puddle(parent, Vector2(45, 40))
		"TurnOffTap":
			if success:
				# Tap off, water saved
				_add_outcome_closed_tap(parent, Vector2(50, -10))
				_add_outcome_sparkles(parent, Vector2(50, -20), 2)
			else:
				# Water still gushing
				_add_outcome_open_tap(parent, Vector2(50, -10))
				_add_outcome_puddle(parent, Vector2(45, 35))
		_:
			if success:
				_add_outcome_sparkles(parent, Vector2(0, -35), 4)
				_add_outcome_hearts(parent, Vector2(0, -45), 3)
			else:
				_add_outcome_puddle(parent, Vector2(30, 40))

# ═══════════════════════════════════════════════════════════════
# OUTCOME PROP BUILDERS
# ═══════════════════════════════════════════════════════════════

func _add_outcome_clothes(parent: Node2D, pos: Vector2, folded: bool) -> void:
	var cloth = Polygon2D.new()
	cloth.name = "OutcomeCloth"
	if folded:
		cloth.polygon = PackedVector2Array([
			Vector2(-10, -5), Vector2(10, -5), Vector2(10, 5), Vector2(-10, 5),
		])
	else:
		cloth.polygon = PackedVector2Array([
			Vector2(-8, -12), Vector2(8, -12), Vector2(10, 8),
			Vector2(6, 16), Vector2(-6, 14), Vector2(-10, 4),
		])
	cloth.color = Color(0.9, 0.3, 0.3)
	cloth.position = pos
	parent.add_child(cloth)

func _add_outcome_sparkles(parent: Node2D, pos: Vector2, count: int) -> void:
	for i in count:
		var star = Label.new()
		star.name = "Sparkle_%d" % i
		star.text = "✨"
		star.add_theme_font_size_override("font_size", 12)
		star.position = pos + Vector2(randf_range(-18, 18), randf_range(-12, 12))
		parent.add_child(star)

func _add_outcome_hearts(parent: Node2D, pos: Vector2, count: int) -> void:
	for i in count:
		var h = Label.new()
		h.name = "Heart_%d" % i
		h.text = "❤"
		h.add_theme_font_size_override("font_size", 12)
		h.position = pos + Vector2(i * 14 - count * 7, randf_range(-6, 6))
		parent.add_child(h)

func _add_outcome_barrel_cover(parent: Node2D, pos: Vector2) -> void:
	# Barrel covering the "naked" character
	var barrel = Polygon2D.new()
	barrel.name = "CoverBarrel"
	barrel.polygon = PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12), Vector2(14, 18), Vector2(-14, 18),
	])
	barrel.color = Color(0.5, 0.38, 0.22)
	barrel.position = pos
	parent.add_child(barrel)

func _add_outcome_embarrass_lines(parent: Node2D) -> void:
	for i in 3:
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = Color(1, 0.4, 0.4, 0.5)
		var x = -18 + i * 18
		line.add_point(Vector2(x, -18))
		line.add_point(Vector2(x + 2, -12))
		parent.add_child(line)

func _add_outcome_full_bucket(parent: Node2D, pos: Vector2) -> void:
	var bucket = Polygon2D.new()
	bucket.polygon = PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	bucket.color = Color(0.5, 0.4, 0.3)
	bucket.position = pos
	parent.add_child(bucket)
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-8, -5), Vector2(8, -5), Vector2(7, 6), Vector2(-7, 6),
	])
	water.color = Color(0.3, 0.6, 1.0, 0.6)
	water.position = pos
	parent.add_child(water)

func _add_outcome_empty_bucket(parent: Node2D, pos: Vector2) -> void:
	var bucket = Polygon2D.new()
	bucket.polygon = PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	bucket.color = Color(0.5, 0.4, 0.3)
	bucket.position = pos
	bucket.rotation = 0.3  # Tipped over
	parent.add_child(bucket)

func _add_outcome_puddle(parent: Node2D, pos: Vector2) -> void:
	var puddle = Polygon2D.new()
	puddle.name = "OutcomePuddle"
	var pp = PackedVector2Array()
	for i in range(10):
		var a = i * TAU / 10
		pp.append(Vector2(cos(a) * 20, sin(a) * 6) + pos)
	puddle.polygon = pp
	puddle.color = Color(0.3, 0.55, 0.85, 0.35)
	parent.add_child(puddle)

func _add_outcome_fixed_pipe(parent: Node2D, pos: Vector2) -> void:
	var pipe = Line2D.new()
	pipe.width = 8.0
	pipe.default_color = Color(0.5, 0.5, 0.55)
	pipe.add_point(pos + Vector2(-15, 0))
	pipe.add_point(pos + Vector2(15, 0))
	parent.add_child(pipe)
	# Tape patch
	var tape = Polygon2D.new()
	tape.polygon = PackedVector2Array([
		Vector2(-4, -6), Vector2(4, -6), Vector2(4, 6), Vector2(-4, 6),
	])
	tape.color = Color(0.6, 0.6, 0.6)
	tape.position = pos
	parent.add_child(tape)

func _add_outcome_gushing_pipe(parent: Node2D, pos: Vector2) -> void:
	var pipe = Line2D.new()
	pipe.width = 8.0
	pipe.default_color = Color(0.5, 0.5, 0.55)
	pipe.add_point(pos + Vector2(-15, 0))
	pipe.add_point(pos)
	parent.add_child(pipe)
	for i in 4:
		var spray = Line2D.new()
		spray.width = 2.0
		spray.default_color = Color(0.4, 0.7, 1.0, 0.6)
		spray.add_point(pos)
		spray.add_point(pos + Vector2(10 + i * 5, -8 + i * 4))
		parent.add_child(spray)

func _add_outcome_clean_beaker(parent: Node2D, pos: Vector2) -> void:
	var beaker = Polygon2D.new()
	beaker.polygon = PackedVector2Array([
		Vector2(-6, -12), Vector2(6, -12), Vector2(7, 10), Vector2(-7, 10),
	])
	beaker.color = Color(0.7, 0.9, 1.0, 0.5)
	beaker.position = pos
	parent.add_child(beaker)
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-5, -2), Vector2(5, -2), Vector2(6, 8), Vector2(-6, 8),
	])
	water.color = Color(0.4, 0.75, 1.0, 0.5)
	water.position = pos
	parent.add_child(water)

func _add_outcome_dirty_beaker(parent: Node2D, pos: Vector2) -> void:
	var beaker = Polygon2D.new()
	beaker.polygon = PackedVector2Array([
		Vector2(-6, -12), Vector2(6, -12), Vector2(7, 10), Vector2(-7, 10),
	])
	beaker.color = Color(0.6, 0.55, 0.45, 0.5)
	beaker.position = pos
	parent.add_child(beaker)
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-5, -2), Vector2(5, -2), Vector2(6, 8), Vector2(-6, 8),
	])
	water.color = Color(0.45, 0.38, 0.25, 0.6)
	water.position = pos
	parent.add_child(water)

func _add_outcome_towel_wrap(parent: Node2D, pos: Vector2) -> void:
	var towel = Polygon2D.new()
	towel.polygon = PackedVector2Array([
		Vector2(-18, -15), Vector2(18, -15), Vector2(16, 20), Vector2(-16, 20),
	])
	towel.color = Color(1, 1, 0.85, 0.7)
	towel.position = pos
	parent.add_child(towel)

func _add_outcome_dripping(parent: Node2D, pos: Vector2, count: int) -> void:
	for i in count:
		var drip = Polygon2D.new()
		drip.name = "OutcomeDrip_%d" % i
		drip.polygon = PackedVector2Array([
			Vector2(0, -2), Vector2(1.5, 0), Vector2(1, 3), Vector2(-1, 3), Vector2(-1.5, 0),
		])
		drip.color = Color(0.4, 0.7, 1.0, 0.6)
		drip.position = pos + Vector2(randf_range(-20, 20), i * 6)
		parent.add_child(drip)

func _add_outcome_water_waste(parent: Node2D, pos: Vector2) -> void:
	var waste = Label.new()
	waste.text = "💧💧💧"
	waste.add_theme_font_size_override("font_size", 10)
	waste.position = pos
	parent.add_child(waste)

func _add_outcome_sealed_drum(parent: Node2D, pos: Vector2) -> void:
	var drum = Polygon2D.new()
	drum.polygon = PackedVector2Array([
		Vector2(-14, -16), Vector2(14, -16), Vector2(12, 16), Vector2(-12, 16),
	])
	drum.color = Color(0.3, 0.35, 0.5)
	drum.position = pos
	parent.add_child(drum)
	var lid = Polygon2D.new()
	lid.polygon = PackedVector2Array([
		Vector2(-16, -3), Vector2(16, -3), Vector2(16, 3), Vector2(-16, 3),
	])
	lid.color = Color(0.4, 0.42, 0.55)
	lid.position = pos + Vector2(0, -18)
	parent.add_child(lid)

func _add_outcome_bugged_drum(parent: Node2D, pos: Vector2) -> void:
	var drum = Polygon2D.new()
	drum.polygon = PackedVector2Array([
		Vector2(-14, -16), Vector2(14, -16), Vector2(12, 16), Vector2(-12, 16),
	])
	drum.color = Color(0.35, 0.35, 0.4)
	drum.position = pos
	parent.add_child(drum)
	for i in 2:
		var bug = Label.new()
		bug.text = ["🦟", "🪲"][i]
		bug.add_theme_font_size_override("font_size", 12)
		bug.position = pos + Vector2(i * 12 - 6, -8)
		parent.add_child(bug)

func _add_outcome_saved_water(parent: Node2D, pos: Vector2) -> void:
	var jug = Polygon2D.new()
	jug.polygon = PackedVector2Array([
		Vector2(-5, -10), Vector2(5, -10), Vector2(6, 8), Vector2(-6, 8),
	])
	jug.color = Color(0.55, 0.4, 0.28)
	jug.position = pos
	parent.add_child(jug)

func _add_outcome_happy_plant(parent: Node2D, pos: Vector2) -> void:
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(8, 0), Vector2(6, 10), Vector2(-6, 10),
	])
	pot.color = Color(0.6, 0.32, 0.18)
	pot.position = pos
	parent.add_child(pot)
	var stem = Line2D.new()
	stem.width = 2.5
	stem.default_color = Color(0.25, 0.75, 0.25)
	stem.add_point(pos + Vector2(0, 0))
	stem.add_point(pos + Vector2(0, -16))
	parent.add_child(stem)
	for side in [-1, 1]:
		var leaf = Polygon2D.new()
		leaf.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(side * 7, -3), Vector2(side * 5, -8), Vector2(0, -5),
		])
		leaf.color = Color(0.2, 0.8, 0.3)
		leaf.position = pos + Vector2(0, -10)
		parent.add_child(leaf)

func _add_outcome_dead_plant(parent: Node2D, pos: Vector2) -> void:
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(8, 0), Vector2(6, 10), Vector2(-6, 10),
	])
	pot.color = Color(0.5, 0.3, 0.15)
	pot.position = pos
	parent.add_child(pot)
	var stem = Line2D.new()
	stem.width = 2.0
	stem.default_color = Color(0.5, 0.42, 0.2)
	stem.add_point(pos + Vector2(0, 0))
	stem.add_point(pos + Vector2(2, -10))
	stem.add_point(pos + Vector2(5, -5))
	parent.add_child(stem)

func _add_outcome_wasted_down_drain(parent: Node2D, pos: Vector2) -> void:
	# Drain circle
	var drain = Polygon2D.new()
	var dp = PackedVector2Array()
	for i in range(10):
		var a = i * TAU / 10
		dp.append(Vector2(cos(a) * 10, sin(a) * 10) + pos)
	drain.polygon = dp
	drain.color = Color(0.2, 0.2, 0.25)
	parent.add_child(drain)
	# Swirl lines
	var swirl = Line2D.new()
	swirl.width = 1.5
	swirl.default_color = Color(0.4, 0.6, 0.9, 0.5)
	for i in 8:
		var a = i * 0.8
		var r = 8.0 - i * 0.8
		swirl.add_point(Vector2(cos(a) * r, sin(a) * r) + pos)
	parent.add_child(swirl)

func _add_outcome_clean_veggies(parent: Node2D, pos: Vector2) -> void:
	var emoji = ["🥕", "🥬"]
	for i in 2:
		var v = Label.new()
		v.text = emoji[i]
		v.add_theme_font_size_override("font_size", 14)
		v.position = pos + Vector2(i * 14 - 7, 0)
		parent.add_child(v)

func _add_outcome_dirty_veggies(parent: Node2D, pos: Vector2) -> void:
	var bowl = Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-12, -3), Vector2(12, -3), Vector2(8, 8), Vector2(-8, 8),
	])
	bowl.color = Color(0.5, 0.42, 0.3)
	bowl.position = pos
	parent.add_child(bowl)

func _add_outcome_sorted_buckets(parent: Node2D) -> void:
	for i in 2:
		var b = Polygon2D.new()
		b.polygon = PackedVector2Array([
			Vector2(-8, -6), Vector2(8, -6), Vector2(7, 6), Vector2(-7, 6),
		])
		b.color = [Color(0.3, 0.8, 0.4), Color(0.4, 0.6, 0.9)][i]
		b.position = Vector2(-50 + i * 100, 30)
		parent.add_child(b)
		var check = Label.new()
		check.text = "✓"
		check.add_theme_font_size_override("font_size", 12)
		check.add_theme_color_override("font_color", Color.WHITE)
		check.position = Vector2(-50 + i * 100, 20)
		parent.add_child(check)

func _add_outcome_mixed_buckets(parent: Node2D) -> void:
	for i in 2:
		var b = Polygon2D.new()
		b.polygon = PackedVector2Array([
			Vector2(-8, -6), Vector2(8, -6), Vector2(7, 6), Vector2(-7, 6),
		])
		b.color = Color(0.5, 0.4, 0.35)
		b.position = Vector2(-50 + i * 100, 30)
		b.rotation = randf_range(-0.2, 0.2)
		parent.add_child(b)

func _add_outcome_mud_pie(parent: Node2D, pos: Vector2, good: bool) -> void:
	var pie = Polygon2D.new()
	var pp = PackedVector2Array()
	for i in range(10):
		var a = i * TAU / 10
		var r = 12.0 if good else randf_range(8, 16)
		pp.append(Vector2(cos(a) * r, sin(a) * r * 0.6) + pos)
	pie.polygon = pp
	pie.color = Color(0.45, 0.32, 0.18) if good else Color(0.4, 0.35, 0.25)
	parent.add_child(pie)
	if good:
		var flag = Line2D.new()
		flag.width = 1.5
		flag.default_color = Color(0.9, 0.3, 0.3)
		flag.add_point(pos + Vector2(0, -4))
		flag.add_point(pos + Vector2(0, -14))
		flag.add_point(pos + Vector2(5, -11))
		parent.add_child(flag)

func _add_outcome_clean_glass(parent: Node2D, pos: Vector2) -> void:
	var glass = Polygon2D.new()
	glass.polygon = PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(5, 10), Vector2(-5, 10),
	])
	glass.color = Color(0.7, 0.9, 1.0, 0.5)
	glass.position = pos
	parent.add_child(glass)

func _add_outcome_dirty_glass(parent: Node2D, pos: Vector2) -> void:
	var glass = Polygon2D.new()
	glass.polygon = PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(5, 10), Vector2(-5, 10),
	])
	glass.color = Color(0.55, 0.5, 0.4, 0.5)
	glass.position = pos
	parent.add_child(glass)
	for i in 3:
		var speck = Polygon2D.new()
		var sp = PackedVector2Array()
		for j in range(4):
			var a = j * TAU / 4
			sp.append(Vector2(cos(a) * 1.5, sin(a) * 1.5))
		speck.polygon = sp
		speck.color = Color(0.4, 0.3, 0.2, 0.6)
		speck.position = pos + Vector2(randf_range(-3, 3), randf_range(-6, 6))
		parent.add_child(speck)

func _add_outcome_clean_hands(parent: Node2D, pos: Vector2) -> void:
	var hand = Polygon2D.new()
	hand.polygon = PackedVector2Array([
		Vector2(-6, -4), Vector2(6, -4), Vector2(5, 6), Vector2(-5, 6),
	])
	hand.color = Color(0.35, 0.75, 1.0)
	hand.position = pos
	parent.add_child(hand)

func _add_outcome_flying_soap(parent: Node2D) -> void:
	var soap = Polygon2D.new()
	soap.name = "FlyingSoap"
	soap.polygon = PackedVector2Array([
		Vector2(-5, -3), Vector2(5, -3), Vector2(6, 3), Vector2(-6, 3),
	])
	soap.color = Color(0.9, 0.8, 1.0)
	soap.position = Vector2(55, -35)
	soap.rotation = 0.5
	parent.add_child(soap)

func _add_outcome_bucket_stack(parent: Node2D, pos: Vector2, neat: bool) -> void:
	for i in 3:
		var b = Polygon2D.new()
		b.polygon = PackedVector2Array([
			Vector2(-6, -4), Vector2(6, -4), Vector2(5, 4), Vector2(-5, 4),
		])
		b.color = Color(0.5, 0.5, 0.7)
		if neat:
			b.position = pos + Vector2(0, -i * 10)
		else:
			b.position = pos + Vector2(randf_range(-10, 10), -i * 8)
			b.rotation = randf_range(-0.5, 0.5)
		parent.add_child(b)

func _add_outcome_closed_tap(parent: Node2D, pos: Vector2) -> void:
	var faucet = Polygon2D.new()
	faucet.polygon = PackedVector2Array([
		Vector2(-3, -6), Vector2(3, -6), Vector2(3, 0),
		Vector2(8, 0), Vector2(8, 3), Vector2(-3, 3),
	])
	faucet.color = Color(0.7, 0.7, 0.75)
	faucet.position = pos
	parent.add_child(faucet)
	# Green checkmark
	var check = Label.new()
	check.text = "✓"
	check.add_theme_font_size_override("font_size", 14)
	check.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	check.position = pos + Vector2(-4, -18)
	parent.add_child(check)

func _add_outcome_open_tap(parent: Node2D, pos: Vector2) -> void:
	var faucet = Polygon2D.new()
	faucet.polygon = PackedVector2Array([
		Vector2(-3, -6), Vector2(3, -6), Vector2(3, 0),
		Vector2(8, 0), Vector2(8, 3), Vector2(-3, 3),
	])
	faucet.color = Color(0.7, 0.7, 0.75)
	faucet.position = pos
	parent.add_child(faucet)
	# Water stream
	for i in 3:
		var stream = Line2D.new()
		stream.width = 2.0
		stream.default_color = Color(0.4, 0.7, 1.0, 0.5)
		stream.add_point(pos + Vector2(3 + i * 2, 3))
		stream.add_point(pos + Vector2(3 + i * 2, 25))
		parent.add_child(stream)

func _spawn_outcome_particles(count: int = 12) -> void:
	var vp = get_viewport_rect().size
	for i in count:
		var p = ColorRect.new()
		var sz = randf_range(4, 12) if _is_success else randf_range(3, 7)
		p.size = Vector2(sz, sz)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.0
		p.position = Vector2(
			randf_range(30, vp.x - 30),
			randf_range(vp.y * 0.2, vp.y * 0.85)
		)
		p.rotation = randf_range(0, TAU)
		if _is_success:
			p.color = [
				Color(1.0, 0.95, 0.3), Color(0.3, 1.0, 0.5),
				Color(0.5, 0.85, 1.0), Color(1.0, 0.6, 0.8),
			][i % 4]
		else:
			p.color = Color(0.4, 0.45, 0.7, 0.5)
		add_child(p)
		_outro_particles.append(p)

func _run_outro_character_vfx() -> void:
	var speed = max(0.4, float(anim_options.get("speed", 1.0)))
	var length = 5.0 / speed
	var vp = get_viewport_rect().size

	if _water_droplet:
		var target_pos = _water_droplet.position
		if _is_success:
			# ══ SUCCESS: Triumphant jump-in from below ══
			_water_droplet.position.y = vp.y + 80
			_water_droplet.scale = Vector2(0.7, 1.4)
			_water_droplet.modulate.a = 1.0

			# Rocket upward
			var jump = create_tween()
			jump.tween_property(
				_water_droplet, "position:y", target_pos.y - 30, 0.5
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			jump.tween_property(
				_water_droplet, "scale", Vector2(0.8, 1.4), 0.2
			)
			jump.tween_callback(func():
				if AudioManager: AudioManager.play_success()
			)
			# Land with squash
			jump.tween_property(
				_water_droplet, "position:y", target_pos.y, 0.25
			).set_ease(Tween.EASE_IN)
			jump.tween_property(
				_water_droplet, "scale", Vector2(1.5, 0.55), 0.15
			).set_ease(Tween.EASE_OUT)
			# Spring back
			jump.tween_property(
				_water_droplet, "scale", Vector2(0.8, 1.3), 0.2
			)
			jump.tween_property(
				_water_droplet, "scale", Vector2(1.1, 0.9), 0.15
			)
			jump.tween_property(
				_water_droplet, "scale", Vector2(1.0, 1.0), 0.12
			)

			# Victory spin!
			var spin = create_tween()
			spin.tween_interval(1.2)
			spin.tween_property(
				_water_droplet, "rotation", TAU, 0.6
			).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			spin.tween_property(_water_droplet, "rotation", 0.0, 0.01)

			# Arm fist-pump celebration
			var arm_l = _water_droplet.get_node_or_null("Arm_L")
			var arm_r = _water_droplet.get_node_or_null("Arm_R")
			if arm_l and arm_r:
				var pump = create_tween()
				pump.tween_interval(0.9)
				var pump_loop = pump.set_loops(4)
				pump_loop.tween_property(arm_l, "rotation_degrees", -25.0, 0.18)
				pump_loop.tween_property(arm_l, "rotation_degrees", 10.0, 0.18)
				pump_loop.tween_property(arm_l, "rotation_degrees", 0.0, 0.12)
				var pump2 = create_tween()
				pump2.tween_interval(1.0)
				var pump2_loop = pump2.set_loops(4)
				pump2_loop.tween_property(arm_r, "rotation_degrees", 25.0, 0.18)
				pump2_loop.tween_property(arm_r, "rotation_degrees", -10.0, 0.18)
				pump2_loop.tween_property(arm_r, "rotation_degrees", 0.0, 0.12)

			# Happy bouncing dance
			var dance = create_tween()
			dance.tween_interval(1.8)
			var d_loop = dance.set_loops(4)
			d_loop.tween_property(_water_droplet, "scale", Vector2(1.2, 0.75), 0.18)
			d_loop.tween_property(
				_water_droplet, "position:y",
				target_pos.y - 20, 0.22
			).set_ease(Tween.EASE_OUT)
			d_loop.tween_property(_water_droplet, "scale", Vector2(0.85, 1.2), 0.18)
			d_loop.tween_property(
				_water_droplet, "position:y",
				target_pos.y, 0.22
			).set_ease(Tween.EASE_IN)
			d_loop.tween_property(_water_droplet, "scale", Vector2(1.4, 0.55), 0.14)
			d_loop.tween_property(_water_droplet, "scale", Vector2(1.0, 1.0), 0.16)

		else:
			# ══ FAILURE: Fall from sky, splat on ground ══
			_water_droplet.position = Vector2(target_pos.x, -80)
			_water_droplet.modulate.a = 1.0
			_water_droplet.scale = Vector2(0.7, 1.4)

			# Plummet down
			var fall = create_tween()
			fall.tween_property(
				_water_droplet, "position:y", target_pos.y, 0.55
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			fall.tween_callback(func():
				if AudioManager: AudioManager.play_damage()
			)
			# SPLAT — extreme pancake squash
			fall.tween_property(
				_water_droplet, "scale", Vector2(1.8, 0.3), 0.12
			).set_ease(Tween.EASE_OUT)
			# Slow jelly recovery
			fall.tween_property(
				_water_droplet, "scale", Vector2(0.6, 1.5), 0.3
			).set_ease(Tween.EASE_OUT)
			fall.tween_property(
				_water_droplet, "scale", Vector2(1.15, 0.85), 0.2
			)
			fall.tween_property(
				_water_droplet, "scale", Vector2(1.0, 1.0), 0.2
			)

			# Violent dizzy shake
			var shake = create_tween()
			shake.tween_interval(1.2)
			for k in range(6):
				var dir = 1.0 if k % 2 == 0 else -1.0
				var mag = 0.2 - k * 0.025
				shake.tween_property(_water_droplet, "rotation", dir * mag, 0.1)
			shake.tween_property(_water_droplet, "rotation", 0.0, 0.1)

			# Spinning dizzy stars
			var stars = _water_droplet.get_node_or_null("DizzyStars")
			if stars:
				var star_spin = create_tween().set_loops(6)
				star_spin.tween_property(
					stars, "rotation",
					stars.rotation + TAU, 1.2
				).set_trans(Tween.TRANS_LINEAR)

			# Limp arm swing
			var arm_l = _water_droplet.get_node_or_null("Arm_L")
			var arm_r = _water_droplet.get_node_or_null("Arm_R")
			if arm_l:
				var limp = create_tween().set_loops(4)
				limp.tween_interval(1.2)
				limp.tween_property(arm_l, "rotation_degrees", 15.0, 0.5)
				limp.tween_property(arm_l, "rotation_degrees", 5.0, 0.6)
			if arm_r:
				var limp2 = create_tween().set_loops(4)
				limp2.tween_interval(1.4)
				limp2.tween_property(arm_r, "rotation_degrees", -12.0, 0.5)
				limp2.tween_property(arm_r, "rotation_degrees", -4.0, 0.6)

			# Slow dejected shrink + sway
			var sad = create_tween()
			sad.tween_interval(2.0)
			sad.tween_property(_water_droplet, "scale", Vector2(0.85, 0.85), 0.7)
			sad.tween_property(_water_droplet, "rotation", -0.08, 0.5)
			sad.tween_property(_water_droplet, "rotation", 0.0, 0.4)

		# ── Animate game-specific outcome props ──
		_animate_outcome_props(length)

		# ── Fade out ──
		var dout = create_tween()
		dout.tween_interval(length * 0.80)
		if _is_success:
			# Exit with a flip
			dout.tween_property(_water_droplet, "rotation", -TAU, 0.45)
			dout.tween_property(_water_droplet, "scale", Vector2(0.05, 0.05), 0.3)
		else:
			# Melt down sadly
			dout.tween_property(_water_droplet, "scale", Vector2(1.5, 0.2), 0.5)
		dout.tween_property(_water_droplet, "modulate:a", 0.0, 0.3)

	# Particles float upward
	for p in _outro_particles:
		var delay = randf_range(0.1, 0.8)
		var rise = randf_range(50, 150)
		var drift = randf_range(-40, 40)
		var pt = create_tween()
		pt.tween_interval(delay)
		pt.set_parallel(true)
		pt.tween_property(p, "modulate:a", randf_range(0.4, 0.8), 0.5)
		pt.tween_property(p, "position:y", p.position.y - rise, 2.2).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "position:x", p.position.x + drift, 2.2)
		pt.tween_property(p, "rotation", p.rotation + randf_range(-1.5, 1.5), 2.2)
		var pf = create_tween()
		pf.tween_interval(delay + 1.5)
		pf.tween_property(p, "modulate:a", 0.0, 0.8)

func _animate_outcome_props(_length: float) -> void:
	if not _water_droplet:
		return
	# Animate sparkles pulsing
	for i in 10:
		var s = _water_droplet.get_node_or_null("Sparkle_%d" % i)
		if s:
			var ts = create_tween()
			ts.tween_interval(1.2 + i * 0.25)
			var lp = ts.set_loops(4)
			lp.tween_property(s, "modulate:a", 0.3, 0.4)
			lp.tween_property(s, "modulate:a", 1.0, 0.4)

	# Animate hearts floating up
	for i in 10:
		var h = _water_droplet.get_node_or_null("Heart_%d" % i)
		if h:
			var th = create_tween()
			th.tween_interval(1.4 + i * 0.35)
			th.tween_property(h, "position:y", h.position.y - 20, 2.0).set_ease(Tween.EASE_OUT)
			th.tween_property(h, "modulate:a", 0.0, 0.7)

	# Animate outcome puddle growing (failure)
	var puddle = _water_droplet.get_node_or_null("OutcomePuddle")
	if puddle:
		var tp = create_tween()
		tp.tween_interval(1.2)
		tp.tween_property(puddle, "scale", Vector2(1.4, 1.2), 3.5).set_ease(Tween.EASE_OUT)

	# Flying soap (SwipeTheSoap failure)
	var soap = _water_droplet.get_node_or_null("FlyingSoap")
	if soap:
		var ts = create_tween()
		ts.tween_interval(1.0)
		var lp = ts.set_loops(3)
		lp.tween_property(soap, "position", soap.position + Vector2(20, -15), 0.5)
		lp.tween_property(soap, "position", soap.position + Vector2(-15, 10), 0.5)
		lp.tween_property(soap, "position", soap.position, 0.4)
		lp.tween_property(soap, "rotation", soap.rotation + 1.0, 0.25)

	# Outcome drips falling (shower failure)
	for i in 10:
		var d = _water_droplet.get_node_or_null("OutcomeDrip_%d" % i)
		if d:
			var td = create_tween()
			td.tween_interval(1.2 + i * 0.25)
			var lp = td.set_loops(3)
			lp.tween_property(d, "position:y", d.position.y + 15, 0.7).set_ease(Tween.EASE_IN)
			lp.tween_property(d, "modulate:a", 0.0, 0.25)
			lp.tween_callback(func():
				if is_instance_valid(d):
					d.position.y -= 15
					d.modulate.a = 0.6
			)
			lp.tween_interval(0.25)

	# WringItOut success: clothes glow
	var cloth = _water_droplet.get_node_or_null("OutcomeCloth")
	if cloth and _is_success:
		var tc = create_tween()
		tc.tween_interval(1.2)
		var lp = tc.set_loops(3)
		lp.tween_property(cloth, "modulate", Color(1.2, 1.2, 1.2), 0.5)
		lp.tween_property(cloth, "modulate", Color.WHITE, 0.5)

	# WringItOut failure: cover barrel wobbles
	var cover = _water_droplet.get_node_or_null("CoverBarrel")
	if cover:
		var tcv = create_tween()
		tcv.tween_interval(1.5)
		var lp = tcv.set_loops(3)
		lp.tween_property(cover, "rotation", 0.08, 0.25)
		lp.tween_property(cover, "rotation", -0.08, 0.25)
		lp.tween_property(cover, "rotation", 0.0, 0.2)

func _cleanup_outro_vfx() -> void:
	for p in _outro_particles:
		if is_instance_valid(p):
			p.queue_free()
	_outro_particles.clear()
	if is_instance_valid(_water_droplet):
		_water_droplet.queue_free()
		_water_droplet = null
	if is_instance_valid(_scene_bg):
		_scene_bg.queue_free()
		_scene_bg = null
