extends Control

## ═══════════════════════════════════════════════════════════════════
## STORY SCREEN - Narrates the water conservation journey between games
## ═══════════════════════════════════════════════════════════════════
## Shows story chapters that unlock as the player completes minigames.
## Bilingual (EN/FIL) with animated text and illustrations.

signal story_finished

var _chapters: Array = []
var _current_chapter: Dictionary = {}
var _current_page: int = 0
var _bg: ColorRect
var _title_label: Label
var _text_label: Label
var _emoji_label: Label
var _page_indicator: Label
var _tap_hint: Label
var _container: VBoxContainer
var _is_animating: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_story_data()
	_build_ui()
	_show_current_page()

func _load_story_data() -> void:
	var file := FileAccess.open("res://data/story/chapters.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		file.close()
		if err == OK and json.data is Dictionary:
			_chapters = json.data.get("chapters", [])

func get_next_unlocked_chapter() -> Dictionary:
	var games_played := 0
	if GameManager:
		games_played = GameManager.minigames_played_this_session
	for chapter in _chapters:
		var threshold: int = chapter.get("unlocks_after_games", 0)
		if games_played >= threshold:
			_current_chapter = chapter
	return _current_chapter

func set_chapter(chapter: Dictionary) -> void:
	_current_chapter = chapter
	_current_page = 0

func _build_ui() -> void:
	# Full-screen background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color.from_string("#1a3a5c", Color(0.1, 0.23, 0.36))
	add_child(_bg)

	# Dark overlay for readability
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.3)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 24)
	_container.custom_minimum_size = Vector2(800, 0)
	center.add_child(_container)

	# Chapter title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title_label.add_theme_constant_override("outline_size", 5)
	_container.add_child(_title_label)

	# Emoji illustration
	_emoji_label = Label.new()
	_emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emoji_label.add_theme_font_size_override("font_size", 72)
	_container.add_child(_emoji_label)

	# Story text
	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 28)
	_text_label.add_theme_color_override("font_color", Color.WHITE)
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_text_label.add_theme_constant_override("outline_size", 3)
	_text_label.custom_minimum_size = Vector2(700, 100)
	_container.add_child(_text_label)

	# Page indicator
	_page_indicator = Label.new()
	_page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_indicator.add_theme_font_size_override("font_size", 20)
	_page_indicator.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_container.add_child(_page_indicator)

	# Tap hint
	_tap_hint = Label.new()
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_hint.add_theme_font_size_override("font_size", 22)
	_tap_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_container.add_child(_tap_hint)

	# Start with fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _show_current_page() -> void:
	if _current_chapter.is_empty():
		get_next_unlocked_chapter()
	if _current_chapter.is_empty():
		story_finished.emit()
		return

	var pages: Array = _current_chapter.get("pages", [])
	if _current_page >= pages.size():
		_finish_story()
		return

	var page: Dictionary = pages[_current_page]
	var is_english := true
	if Localization:
		is_english = Localization.is_english()

	# Update title
	if is_english:
		_title_label.text = _current_chapter.get("title_en", "")
	else:
		_title_label.text = _current_chapter.get("title_tl", "")

	# Update background color
	var bg_hex: String = page.get("bg_color", "#1a3a5c")
	_bg.color = Color.from_string(bg_hex, Color(0.1, 0.23, 0.36))

	# Animate text in
	_is_animating = true
	_emoji_label.text = page.get("emoji", "💧")
	_emoji_label.modulate.a = 0.0
	_text_label.modulate.a = 0.0

	var text_key := "text_en" if is_english else "text_tl"
	_text_label.text = page.get(text_key, "")

	var total_pages: int = pages.size()
	_page_indicator.text = "%d / %d" % [_current_page + 1, total_pages]

	var hint_text := (
		Localization.get_text("story_tap_continue")
		if Localization else "👆 Tap to continue"
	)
	if _current_page >= total_pages - 1:
		hint_text = Localization.get_text("story_tap_play") if Localization else "👆 Tap to play!"
	_tap_hint.text = hint_text

	# Animate elements in
	var tween := create_tween()
	tween.tween_property(_emoji_label, "modulate:a", 1.0, 0.4)
	tween.tween_property(_text_label, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func(): _is_animating = false)

	# Pulse tap hint
	var pulse := create_tween().set_loops()
	pulse.tween_property(_tap_hint, "modulate:a", 0.3, 0.8)
	pulse.tween_property(_tap_hint, "modulate:a", 1.0, 0.8)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance_page()
	elif event is InputEventScreenTouch and event.pressed:
		_advance_page()

func _advance_page() -> void:
	if _is_animating:
		return
	if AudioManager:
		AudioManager.play_click()
	_current_page += 1
	var pages: Array = _current_chapter.get("pages", [])
	if _current_page >= pages.size():
		_finish_story()
	else:
		_show_current_page()

func _finish_story() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	story_finished.emit()
