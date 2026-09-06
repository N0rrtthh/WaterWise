extends Control

## ═══════════════════════════════════════════════════════════════════
## STORY SCREEN - Narrates the water conservation journey between games
## ═══════════════════════════════════════════════════════════════════
## Shows story chapters that unlock as the player completes minigames.
## Bilingual (EN/FIL) with animated text and illustrations.

signal story_finished

var _chapters: Array = []

const STORY_DATA_PATH: String = "res://data/story/chapters.json"
## Id of the one chapter the inline fallback below carries; kept equal to the first id in
## chapters.json on purpose. See read_chapter_ids().
const FALLBACK_CHAPTER_ID: String = "ch1_awakening"
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
var _is_finishing: bool = false
## Set once this screen has written its chapter to the save file. See _mark_current_chapter_seen().
var _chapter_marked_seen: bool = false
var _tap_hint_pulse: Tween = null
var _safety_timer: Timer = null
var _is_mobile: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50  # Above all InitialScreen UI (z_index=10)
	_is_mobile = (
		OS.has_feature("mobile") or OS.has_feature("android") or
		OS.has_feature("ios") or OS.get_name() == "Android" or
		OS.get_name() == "iOS"
	)
	_load_story_data()
	
	# Safety guard: if no chapters loaded, skip immediately
	if _chapters.is_empty():
		print("📖 StoryScreen: No chapters found, finishing immediately")
		call_deferred("_finish_story")
		return
	
	_build_ui()
	_show_current_page()
	
	# Mobile safety: auto-advance timeout so it never gets stuck
	if _is_mobile:
		_start_safety_timer()

## The chapter ids, in authored order, without building a screen. GameManager asks this before
## it creates the full-screen overlay: with every chapter already read there is nothing to show,
## and creating the layer anyway would put a black CanvasLayer on the glass for the frame it
## takes _show_current_page() to notice {} and emit story_finished. One frame is still a visible
## flash on the reported device.
##
## Ids only, so this stays a cheap file read - the selection itself (which chapter, which page,
## which language) remains get_next_unlocked_chapter()'s job.
static func read_chapter_ids() -> Array[String]:
	var ids: Array[String] = []
	var f := FileAccess.open(STORY_DATA_PATH, FileAccess.READ)
	if f:
		var json := JSON.new()
		var err := json.parse(f.get_as_text())
		f.close()
		if err == OK and json.data is Dictionary:
			for chapter in json.data.get("chapters", []):
				if chapter is Dictionary:
					var id := str(chapter.get("id", ""))
					if id != "":
						ids.append(id)
	if ids.is_empty():
		# The same single chapter the inline fallback in _load_story_data() carries, so a build
		# that lost the JSON is still answered consistently by both paths.
		ids.append(FALLBACK_CHAPTER_ID)
	return ids

func _load_story_data() -> void:
	# Try loading from the packed JSON file first.
	var file := FileAccess.open(STORY_DATA_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		file.close()
		if err == OK and json.data is Dictionary:
			_chapters = json.data.get("chapters", [])

	# Fallback: if the file failed to load (e.g. export filter omitted it on
	# older builds), use a minimal inline chapter so the story always shows.
	if _chapters.is_empty():
		push_warning("StoryScreen: chapters.json not loaded — using inline fallback.")
		_chapters = [
			{
				"id": "ch1_awakening",
				"title_en": "The Waking River",
				"title_tl": "Ang Paggising ng Ilog",
				"pages": [
					{
						"text_en": (
							"In a small barrio by the river, a young water droplet "
							+ "named Droppy wakes up with a splash."
						),
						"text_tl": (
							"Sa isang maliit na baryo, isang batang patak ng tubig "
							+ "na nagngangalang Droppy ay nagising na may sabog."
						),
						"emoji": "💧🌅",
						"bg_color": "#1a3a5c"
					},
					{
						"text_en": (
							"\"The river is getting smaller!\" cries Lola Tubig, "
							+ "the wise elder of the water spirits."
						),
						"text_tl": (
							"\"Pumapaliit na ang ilog!\" sigaw ni Lola Tubig, "
							+ "ang matalinong matanda ng mga espiritu ng tubig."
						),
						"emoji": "👵💦",
						"bg_color": "#1a3a5c"
					},
					{
						"text_en": (
							"\"Droppy, you must teach the children how to save water. "
							+ "Every drop counts!\""
						),
						"text_tl": (
							"\"Droppy, kailangan mong turuan ang mga bata kung paano "
							+ "magtipid ng tubig. Bawat patak ay mahalaga!\""
						),
						"emoji": "✨📖",
						"bg_color": "#1a3a5c"
					}
				]
			}
		]

## The first chapter this player has never finished, or {} when the story is used up.
##
## THE DEFECT THIS REPLACES
##   The chapter used to be picked as (minigames_played_this_session / 5) % _chapters.size().
##   That counter is session-local: it is 0 at every launch. So the answer at every press of
##   Play was index 0, "The Waking River", forever - and a player who plays fewer than five
##   games at a sitting never advanced past it at all. The reported symptom ("the intro plays
##   every time") and the hidden one (chapters 2-6 unreachable in normal play) are the same
##   line of code.
##
## The progression is now the save file, so it survives the process: each chapter is handed out
## once, in order, and {} means there is nothing left to show. Callers already treat {} as "no
## story" - _show_current_page() emits story_finished immediately on it, and
## GameManager._should_show_story() checks for it before building an overlay at all - so the
## overlay stops being created once the six chapters are read rather than being created empty.
func get_next_unlocked_chapter() -> Dictionary:
	if _chapters.is_empty():
		return {}
	for chapter in _chapters:
		if not (chapter is Dictionary):
			continue
		var id := str(chapter.get("id", ""))
		# A chapter with no id cannot be recorded as seen, so it would replay forever - the
		# exact bug being fixed. Skipped instead, and warned about, since only authored data
		# can cause it.
		if id == "":
			push_warning("StoryScreen: chapter without an \"id\" skipped; it could never " \
				+ "be marked as read.")
			continue
		if SaveManager and SaveManager.is_story_chapter_seen(id):
			continue
		_current_chapter = chapter
		return _current_chapter
	return {}

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

# ── Emoji sanitisation ──────────────────────────────────────────────────────
# (Removed) The strip workaround is obsolete: ThemeManager installs the Noto
# Emoji fallback font on the bundled display fonts, so emoji render directly.

func _show_current_page() -> void:
	if _current_chapter.is_empty():
		get_next_unlocked_chapter()
	if _current_chapter.is_empty():
		_stop_tap_hint_pulse()
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
	# NOTE: emoji now render via the Noto Emoji fallback font installed by
	# ThemeManager._install_emoji_fallback() — no stripping needed.
	_emoji_label.visible = _emoji_label.text != ""
	_text_label.modulate.a = 0.0

	var text_key := "text_en" if is_english else "text_tl"
	_text_label.text = page.get(text_key, "")

	var total_pages: int = pages.size()
	_page_indicator.text = "%d / %d" % [_current_page + 1, total_pages]

	var hint_text := (
		Localization.get_text("story_tap_continue")
		if Localization else "Tap to continue"
	)
	if _current_page >= total_pages - 1:
		hint_text = Localization.get_text("story_tap_play") if Localization else "Tap to play!"
	_tap_hint.text = hint_text

	# Animate elements in
	var tween := create_tween()
	tween.tween_property(_emoji_label, "modulate:a", 1.0, 0.4)
	tween.tween_property(_text_label, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func(): _is_animating = false)

	# Pulse tap hint
	_stop_tap_hint_pulse()
	_tap_hint_pulse = create_tween().set_loops()
	_tap_hint_pulse.tween_property(_tap_hint, "modulate:a", 0.3, 0.8)
	_tap_hint_pulse.tween_property(_tap_hint, "modulate:a", 1.0, 0.8)

func _input(event: InputEvent) -> void:
	if _is_finishing:
		return
	if event is InputEventMouseButton and event.pressed:
		advance_page()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		advance_page()
		get_viewport().set_input_as_handled()

func advance_page() -> void:
	_advance_page()

func _advance_page() -> void:
	if _is_animating or _is_finishing:
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
	if _is_finishing:
		return
	_is_finishing = true
	_stop_tap_hint_pulse()
	# Recorded HERE, at the top, and not after the fade below. Two reasons, both of which would
	# reintroduce the replay bug: the caller frees this node's whole CanvasLayer as soon as
	# story_finished fires, and a tween killed by that free never emits `finished`, so anything
	# written under the await is not guaranteed to run at all. Marking before the animation also
	# means the safety timer's auto-advance path (30 s, for a stuck screen) records the chapter
	# just the same - a player who sat through it once should not be shown it again because the
	# tap that would have ended it never arrived.
	_mark_current_chapter_seen()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	story_finished.emit()

## Idempotent, so the safety timer firing on top of a normal finish cannot append twice
## (SaveManager also guards, but this keeps the "seen once" record a property of this screen
## rather than of the store's implementation).
func _mark_current_chapter_seen() -> void:
	if _chapter_marked_seen:
		return
	var id := str(_current_chapter.get("id", ""))
	if id == "":
		return
	_chapter_marked_seen = true
	if SaveManager:
		SaveManager.mark_story_chapter_seen(id)

func _exit_tree() -> void:
	_stop_tap_hint_pulse()
	_stop_safety_timer()

func _stop_tap_hint_pulse() -> void:
	if _tap_hint_pulse:
		_tap_hint_pulse.kill()
		_tap_hint_pulse = null

func _start_safety_timer() -> void:
	_stop_safety_timer()
	_safety_timer = Timer.new()
	_safety_timer.wait_time = 30.0  # Auto-advance after 30s if stuck
	_safety_timer.one_shot = true
	_safety_timer.timeout.connect(func():
		print("📖 StoryScreen: Safety timer triggered, auto-advancing")
		_finish_story()
	)
	add_child(_safety_timer)
	_safety_timer.start()

func _stop_safety_timer() -> void:
	if _safety_timer and is_instance_valid(_safety_timer):
		_safety_timer.stop()
		_safety_timer.queue_free()
		_safety_timer = null
