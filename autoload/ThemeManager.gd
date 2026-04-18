extends Node

## ═══════════════════════════════════════════════════════════════════
## THEME MANAGER - CENTRALIZED DARK/LIGHT MODE
## ═══════════════════════════════════════════════════════════════════
## Handles theme switching across all UI screens
## Works with GameManager.dark_mode_enabled flag
## ═══════════════════════════════════════════════════════════════════

signal theme_changed(is_dark: bool)

# Global full-screen tint colors. Dark mode is intentionally cool-toned,
# not pure black, so the game remains colorful while still distinct.
const LIGHT_SCENE_TINT := Color(1.0, 0.97, 0.88, 0.06)
const DARK_SCENE_TINT := Color(0.30, 0.45, 0.68, 0.18)

var _theme_tint_layer: CanvasLayer
var _theme_tint_rect: ColorRect
var _theme_tint_tween: Tween

# Color palettes
const LIGHT_PALETTE := {
	"background": Color(0.95, 0.97, 1.0),  # Light blue-white
	"panel": Color(1.0, 1.0, 1.0, 0.95),
	"panel_border": Color(0.7, 0.8, 0.9),
	"text_primary": Color(0.15, 0.2, 0.3),
	"text_secondary": Color(0.4, 0.45, 0.5),
	"accent": Color(0.2, 0.6, 0.9),  # Water blue
	"accent_hover": Color(0.3, 0.7, 1.0),
	"button_bg": Color(0.2, 0.6, 0.9),
	"button_text": Color(1.0, 1.0, 1.0),
	"success": Color(0.2, 0.8, 0.4),
	"error": Color(0.9, 0.3, 0.3),
	"warning": Color(0.95, 0.7, 0.2)
}

const DARK_PALETTE := {
	# Deliberately colorful moonlight palette (not near-black).
	"background": Color(0.27, 0.33, 0.48),
	"panel": Color(0.24, 0.39, 0.56, 0.95),
	"panel_border": Color(0.52, 0.70, 0.86),
	"text_primary": Color(0.96, 0.98, 1.0),
	"text_secondary": Color(0.83, 0.90, 0.96),
	"accent": Color(0.35, 0.82, 1.0),
	"accent_hover": Color(0.48, 0.90, 1.0),
	"button_bg": Color(0.22, 0.64, 0.88),
	"button_text": Color(1.0, 1.0, 1.0),
	"success": Color(0.52, 0.93, 0.62),
	"error": Color(1.0, 0.55, 0.60),
	"warning": Color(1.0, 0.84, 0.42)
}

# Mini-game visual themes (bright, kid-friendly, and readable)
const MINIGAME_THEME_PALETTES := {
	"aqua_blue": {
		"bg_primary": Color(0.73, 0.90, 0.99, 1.0),
		"bg_secondary": Color(0.56, 0.79, 0.95, 1.0),
		"bg_wash": Color(0.86, 0.95, 1.0, 0.32),
		"tint_modulate": Color(0.96, 0.99, 1.0, 1.0),
		"scene_blend": 0.24,
	},
	"garden_green": {
		"bg_primary": Color(0.82, 0.95, 0.74, 1.0),
		"bg_secondary": Color(0.67, 0.88, 0.55, 1.0),
		"bg_wash": Color(0.93, 1.0, 0.86, 0.30),
		"tint_modulate": Color(0.97, 1.0, 0.95, 1.0),
		"scene_blend": 0.26,
	},
	"bubble_pop": {
		"bg_primary": Color(0.94, 0.87, 0.97, 1.0),
		"bg_secondary": Color(0.78, 0.88, 1.0, 1.0),
		"bg_wash": Color(1.0, 0.97, 1.0, 0.27),
		"tint_modulate": Color(0.99, 0.97, 1.0, 1.0),
		"scene_blend": 0.23,
	},
	"earthy_orange": {
		"bg_primary": Color(0.98, 0.88, 0.74, 1.0),
		"bg_secondary": Color(0.93, 0.67, 0.46, 1.0),
		"bg_wash": Color(1.0, 0.95, 0.85, 0.28),
		"tint_modulate": Color(1.0, 0.97, 0.93, 1.0),
		"scene_blend": 0.24,
	},
	"sunny_yellow": {
		"bg_primary": Color(1.0, 0.95, 0.74, 1.0),
		"bg_secondary": Color(1.0, 0.86, 0.49, 1.0),
		"bg_wash": Color(1.0, 0.99, 0.88, 0.28),
		"tint_modulate": Color(1.0, 0.98, 0.94, 1.0),
		"scene_blend": 0.22,
	},
}

const MINIGAME_THEME_KEYWORDS: Array[Dictionary] = [
	{
		"id": "garden_green",
		"keywords": ["vegetable", "plant", "thirsty", "leaf", "garden"],
	},
	{
		"id": "bubble_pop",
		"keywords": ["soap", "shower", "scrub", "wring", "bath", "wash"],
	},
	{
		"id": "earthy_orange",
		"keywords": ["mud", "pie", "bucket"],
	},
	{
		"id": "sunny_yellow",
		"keywords": ["timing", "memory", "dash"],
	},
	{
		"id": "aqua_blue",
		"keywords": [
			"rain",
			"water",
			"leak",
			"pipe",
			"tap",
			"drum",
			"cloud",
			"filter",
			"grey",
			"toilet",
			"speck",
			"rice",
		],
	},
]
const DEFAULT_MINIGAME_THEME_ID := "aqua_blue"

func _ready() -> void:
	_ensure_theme_tint_layer()
	if not theme_changed.is_connected(_on_theme_changed):
		theme_changed.connect(_on_theme_changed)

	# Apply saved theme on startup
	call_deferred("_apply_initial_theme")

func _apply_initial_theme() -> void:
	theme_changed.emit(is_dark_mode())

func is_dark_mode() -> bool:
	return GameManager.dark_mode_enabled if GameManager else false

func toggle_theme() -> void:
	set_dark_mode(not is_dark_mode())
	print("Theme toggled: ", "Dark" if is_dark_mode() else "Light")

func set_dark_mode(enabled: bool) -> void:
	if GameManager:
		GameManager.dark_mode_enabled = enabled
		_persist_theme_preference()
	theme_changed.emit(enabled)


func _persist_theme_preference() -> void:
	if GameManager and GameManager.has_method("save_persistent_data"):
		GameManager.save_persistent_data()

func get_color(color_name: String) -> Color:
	# Get a color from the current palette.
	var palette: Dictionary = DARK_PALETTE if is_dark_mode() else LIGHT_PALETTE
	if palette.has(color_name):
		return palette[color_name]
	push_warning("ThemeManager: Unknown color: " + color_name)
	return Color.WHITE

func get_palette() -> Dictionary:
	# Get the current color palette.
	return DARK_PALETTE if is_dark_mode() else LIGHT_PALETTE


func get_minigame_theme_id_for_name(minigame_name: String) -> String:
	var key = _normalize_minigame_theme_key(minigame_name)
	if key.is_empty():
		return DEFAULT_MINIGAME_THEME_ID

	for bucket in MINIGAME_THEME_KEYWORDS:
		var theme_id = str(bucket.get("id", ""))
		var keywords: Array = bucket.get("keywords", [])
		for raw_kw in keywords:
			var kw = _normalize_minigame_theme_key(str(raw_kw))
			if not kw.is_empty() and key.contains(kw):
				if MINIGAME_THEME_PALETTES.has(theme_id):
					return theme_id

	return DEFAULT_MINIGAME_THEME_ID


func get_minigame_theme_for_name(minigame_name: String) -> Dictionary:
	var theme_id = get_minigame_theme_id_for_name(minigame_name)
	var base_theme: Dictionary = MINIGAME_THEME_PALETTES.get(
		theme_id,
		MINIGAME_THEME_PALETTES[DEFAULT_MINIGAME_THEME_ID]
	)

	if not is_dark_mode():
		return base_theme

	return _build_dark_mode_minigame_variant(base_theme)


func _normalize_minigame_theme_key(raw_text: String) -> String:
	var t = raw_text.strip_edges().to_lower()
	t = t.replace("_", "")
	t = t.replace("-", "")
	t = t.replace(" ", "")
	return t


func _build_dark_mode_minigame_variant(base_theme: Dictionary) -> Dictionary:
	var variant: Dictionary = base_theme.duplicate(true)

	var primary: Color = variant.get("bg_primary", Color(0.73, 0.90, 0.99, 1.0))
	var secondary: Color = variant.get("bg_secondary", Color(0.56, 0.79, 0.95, 1.0))
	var wash: Color = variant.get("bg_wash", Color(0.86, 0.95, 1.0, 0.32))
	var tint_modulate: Color = variant.get("tint_modulate", Color(1.0, 1.0, 1.0, 1.0))

	var cool_primary := Color(0.34, 0.46, 0.67, 1.0)
	var cool_secondary := Color(0.26, 0.38, 0.58, 1.0)
	var cool_wash := Color(0.62, 0.77, 0.96, wash.a)

	variant["bg_primary"] = primary.lerp(cool_primary, 0.46)
	variant["bg_secondary"] = secondary.lerp(cool_secondary, 0.40)

	var updated_wash = wash.lerp(cool_wash, 0.34)
	updated_wash.a = min(0.40, wash.a + 0.05)
	variant["bg_wash"] = updated_wash

	variant["tint_modulate"] = tint_modulate.lerp(Color(0.86, 0.93, 1.0, 1.0), 0.62)
	variant["scene_blend"] = clamp(float(base_theme.get("scene_blend", 0.24)) + 0.06, 0.0, 0.50)
	return variant


func _on_theme_changed(is_dark: bool) -> void:
	_ensure_theme_tint_layer()
	var target_tint: Color = DARK_SCENE_TINT if is_dark else LIGHT_SCENE_TINT
	_apply_theme_tint(target_tint)


func _ensure_theme_tint_layer() -> void:
	if _theme_tint_layer and is_instance_valid(_theme_tint_layer):
		return

	_theme_tint_layer = CanvasLayer.new()
	_theme_tint_layer.name = "ThemeTintLayer"
	_theme_tint_layer.layer = 95
	add_child(_theme_tint_layer)

	_theme_tint_rect = ColorRect.new()
	_theme_tint_rect.name = "ThemeTint"
	_theme_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_theme_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme_tint_rect.color = LIGHT_SCENE_TINT
	_theme_tint_layer.add_child(_theme_tint_rect)


func _apply_theme_tint(target_tint: Color) -> void:
	if not _theme_tint_rect:
		return

	if _theme_tint_tween and _theme_tint_tween.is_valid():
		_theme_tint_tween.kill()

	_theme_tint_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_theme_tint_tween.tween_property(_theme_tint_rect, "color", target_tint, 0.25)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER METHODS FOR UI ELEMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func apply_to_label(label: Label, is_primary: bool = true) -> void:
	# Apply theme colors to a Label.
	var color := get_color("text_primary") if is_primary else get_color("text_secondary")
	label.add_theme_color_override("font_color", color)

func apply_to_button(button: Button) -> void:
	# Apply theme colors to a Button.
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = get_color("button_bg")
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.content_margin_left = 20
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = get_color("accent_hover")
	
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = get_color("accent").darkened(0.2)
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", get_color("button_text"))
	button.add_theme_color_override("font_hover_color", get_color("button_text"))
	button.add_theme_color_override("font_pressed_color", get_color("button_text"))

func apply_to_panel(panel: PanelContainer) -> void:
	# Apply theme colors to a PanelContainer.
	var style := StyleBoxFlat.new()
	style.bg_color = get_color("panel")
	style.border_color = get_color("panel_border")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	
	panel.add_theme_stylebox_override("panel", style)

func apply_to_background(control: Control) -> void:
	# Apply theme background color to a Control via ColorRect child.
	var bg_rect := control.get_node_or_null("Background") as ColorRect
	if bg_rect:
		bg_rect.color = get_color("background")
	else:
		# Try to set modulate on the control itself
		if control is ColorRect:
			control.color = get_color("background")

func apply_to_control(control: Control) -> void:
	# Auto-detect control type and apply appropriate theme.
	if control is Label:
		apply_to_label(control as Label, true)
	elif control is CheckBox or control is CheckButton:
		control.add_theme_color_override("font_color", get_color("text_primary"))
	elif control is Button:
		apply_to_button(control as Button)
	elif control is PanelContainer:
		apply_to_panel(control as PanelContainer)
	elif control is ColorRect:
		control.color = get_color("background")

func apply_to_tree(root: Control) -> void:
	# Recursively apply theme to all children of a control.
	apply_to_control(root)
	for child in root.get_children():
		if child is Control:
			apply_to_tree(child)


func apply_theme(root: Control) -> void:
	# Backward-compatible alias for screens that call apply_theme.
	apply_to_tree(root)
