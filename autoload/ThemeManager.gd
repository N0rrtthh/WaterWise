extends Node

## ═══════════════════════════════════════════════════════════════════
## THEME MANAGER - CENTRALIZED DARK/LIGHT MODE
## ═══════════════════════════════════════════════════════════════════
## Handles theme switching across all UI screens
## Works with GameManager.dark_mode_enabled flag
## ═══════════════════════════════════════════════════════════════════

signal theme_changed(is_dark: bool)

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
	"background": Color(0.1, 0.12, 0.18),  # Dark blue
	"panel": Color(0.15, 0.18, 0.25, 0.95),
	"panel_border": Color(0.3, 0.35, 0.45),
	"text_primary": Color(0.95, 0.95, 0.97),
	"text_secondary": Color(0.7, 0.72, 0.75),
	"accent": Color(0.4, 0.75, 1.0),  # Lighter water blue
	"accent_hover": Color(0.5, 0.85, 1.0),
	"button_bg": Color(0.3, 0.55, 0.8),
	"button_text": Color(1.0, 1.0, 1.0),
	"success": Color(0.3, 0.9, 0.5),
	"error": Color(1.0, 0.4, 0.4),
	"warning": Color(1.0, 0.8, 0.3)
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
	# Apply saved theme on startup
	call_deferred("_apply_initial_theme")

func _apply_initial_theme() -> void:
	if GameManager and GameManager.dark_mode_enabled:
		theme_changed.emit(true)

func is_dark_mode() -> bool:
	return GameManager.dark_mode_enabled if GameManager else false

func toggle_theme() -> void:
	if GameManager:
		GameManager.dark_mode_enabled = not GameManager.dark_mode_enabled
		theme_changed.emit(GameManager.dark_mode_enabled)
		print("🎨 Theme toggled: ", "Dark" if GameManager.dark_mode_enabled else "Light")

func set_dark_mode(enabled: bool) -> void:
	if GameManager:
		GameManager.dark_mode_enabled = enabled
		theme_changed.emit(enabled)

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
	return MINIGAME_THEME_PALETTES.get(
		theme_id,
		MINIGAME_THEME_PALETTES[DEFAULT_MINIGAME_THEME_ID]
	)


func _normalize_minigame_theme_key(raw_text: String) -> String:
	var t = raw_text.strip_edges().to_lower()
	t = t.replace("_", "")
	t = t.replace("-", "")
	t = t.replace(" ", "")
	return t

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
