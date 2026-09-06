extends Control

## DEV TOOL — Beat Clip Viewer (Settings → Dev Mode → 🎬 Beat Viewer).
##
## Lists every minigame (single-player + multiplayer) with its authored beat
## clips, so animations can be inspected without playing a round:
##   * Pick a game from the list (all 25, tagged SP/MP).
##   * Press INTRO / WIN / LOSE to play that clip fullscreen.
##   * Any clip can be exited instantly with STOP.
##
## Clips resolve from res://scenes/ui/cutscenes/beats/<Game>{Intro,WinOutro,
## LoseOutro}.tscn — the same paths MiniGameIntroBridge / MiniGameBase use,
## so what you preview here is exactly what ships in-game.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"
const GAMES_DIR := "res://scenes/minigames"

## Games that have a co-op/multiplayer implementation (scripts/multiplayer/).
const MULTIPLAYER_GAMES := [
	"BucketBrigade", "GreywaterSorter", "CatchTheRain",
	"RainwaterHarvesting", "CloudCatcher",
]

const CLIP_KINDS := [
	["Intro", "INTRO", "play_cause"],
	["WinOutro", "WIN", "play_win"],
	["LoseOutro", "LOSE", "play_lose"],
]

var game_list: ItemList
var clip_buttons: Array[Button] = []
var status_label: Label
var stop_button: Button
var back_button: Button
var preview_holder: Control

var _games: Array[String] = []
var _playing := false
var _play_gen: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.1, 0.15)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "BEAT CLIP VIEWER — all minigames & animations"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)

	# -- Left: minigame list (single + multiplayer) --
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.55
	body.add_child(left)

	var list_caption := Label.new()
	list_caption.text = "Minigames (tap one, then play a clip)"
	list_caption.add_theme_font_size_override("font_size", 18)
	left.add_child(list_caption)

	game_list = ItemList.new()
	game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_list.add_theme_font_size_override("font_size", 20)
	game_list.item_selected.connect(_on_game_selected)
	left.add_child(game_list)

	# -- Right: clip playback --
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.45
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 16)
	body.add_child(right)

	for kind in CLIP_KINDS:
		var b := Button.new()
		b.text = "> " + kind[1]
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = true
		# Read the selected game at press time — pressed carries no args, so
		# only the clip kind is bound here (fixes "expected 3 args, got 2").
		var kind_name: String = kind[0]
		var method_name: String = kind[2]
		b.pressed.connect(func() -> void:
			var sel := game_list.get_selected_items()
			if sel.size() > 0:
				_play_clip(_games[sel[0]], kind_name, method_name)
		)
		right.add_child(b)
		clip_buttons.append(b)

	stop_button = Button.new()
	stop_button.text = "STOP"
	stop_button.custom_minimum_size = Vector2(0, 48)
	stop_button.add_theme_font_size_override("font_size", 20)
	stop_button.disabled = true
	stop_button.pressed.connect(_stop_preview)
	right.add_child(stop_button)

	status_label = Label.new()
	status_label.text = "Select a minigame."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	right.add_child(status_label)

	back_button = Button.new()
	back_button.text = "< Back to Settings"
	back_button.custom_minimum_size = Vector2(0, 56)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.pressed.connect(_on_back)
	column.add_child(back_button)

	preview_holder = Control.new()
	preview_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Click-through: the viewer's buttons (STOP etc.) must stay reachable
	# while a clip renders underneath/overhead.
	preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.visible = false
	add_child(preview_holder)

	_populate_games()


func _populate_games() -> void:
	_games = _collect_game_names(_scene_file_listing())
	if _games.is_empty():
		status_label.text = "No minigame scenes resolved under %s" % GAMES_DIR
		return
	for g in _games:
		var tag := "MP" if MULTIPLAYER_GAMES.has(g) else "SP"
		var has_beats := _clip_path(g, "Intro") != ""
		var mark := "" if has_beats else "  !! NO CLIPS"
		game_list.add_item("%s  [%s]%s" % [g, tag, mark])


## THE DEFECT THIS REPLACES: the Beat Viewer came up with an EMPTY list on the phone.
##
## The list used to be a DirAccess walk of res://scenes/minigames keeping every entry whose
## name ends_with(".tscn"). That is 25 names in the editor and ZERO in an exported build:
## editor/export/convert_text_resources_to_binary is true (the engine default, and unset in
## project.godot, so it is what the Android build used), so the export stores each Foo.tscn as
## a binary Foo.scn plus a Foo.tscn.remap stub. Neither of those names ends with ".tscn", the
## filter matched nothing, and every row downstream - the SP/MP tag, the NO CLIPS mark, the
## INTRO/WIN/LOSE buttons - had nothing to hang off. Nothing errored, which is why this looked
## like a rendering fault rather than a listing one.
##
## So the list is now built from a source that is IDENTICAL in both kinds of build - the same
## constants the game itself picks rounds from - and the directory listing is demoted to an
## extra source, accepted in whatever spelling a build hands it over in:
##
##   GameManager.ALL_SINGLEPLAYER_MINIGAMES (24) is the single-player pool.
##   MULTIPLAYER_GAMES adds RainwaterHarvesting, which is co-op only. Together they are
##   exactly the 25 scenes on disk, so on this project the scan is currently redundant; it
##   stays because a scene dropped into the folder and not yet added to either list should
##   still show up in the dev tool that exists to preview it.
##
## Every candidate is then confirmed with ResourceLoader.exists(), which resolves through the
## .remap and so answers correctly in an export as well as in the editor. That is what keeps a
## name with no scene behind it out of a list whose rows all call load() eventually.
func _collect_game_names(listing: PackedStringArray) -> Array[String]:
	var seen := {}
	for g in GameManager.ALL_SINGLEPLAYER_MINIGAMES:
		seen[String(g)] = true
	for g in MULTIPLAYER_GAMES:
		seen[String(g)] = true
	for f in listing:
		var base := _scene_base_name(String(f))
		if base != "":
			seen[base] = true
	var out: Array[String] = []
	for n in seen.keys():
		if ResourceLoader.exists("%s/%s.tscn" % [GAMES_DIR, n]):
			out.append(String(n))
	out.sort()
	return out


## A scene file name in any spelling a build can report, reduced to the game name.
## Editor: "FixLeak.tscn". Exported: "FixLeak.scn" AND "FixLeak.tscn.remap" - both, for the
## same scene, which is why the caller dedupes. The longest suffixes are tested first so
## "FixLeak.tscn.remap" is not left as "FixLeak.tscn" by an earlier match.
func _scene_base_name(file_name: String) -> String:
	for suffix in [".tscn.remap", ".scn.remap", ".tscn", ".scn"]:
		if file_name.ends_with(suffix):
			return file_name.trim_suffix(suffix)
	return ""


## Whatever the filesystem reports for the minigame folder, or nothing at all when it cannot be
## read. An unreadable folder is no longer a dead end - the constants above already carry the
## whole list - so this returns an empty listing instead of the "Cannot open" message that used
## to replace the screen's contents.
func _scene_file_listing() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(GAMES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return out


func _clip_path(game: String, kind: String) -> String:
	var p := "%s/%s%s.tscn" % [BEATS_DIR, game, kind]
	return p if ResourceLoader.exists(p) else ""


func _on_game_selected(index: int) -> void:
	if _playing:
		return
	var g := _games[index]
	for i in clip_buttons.size():
		clip_buttons[i].disabled = _clip_path(g, CLIP_KINDS[i][0]) == ""
	var missing: Array[String] = []
	for kind in CLIP_KINDS:
		if _clip_path(g, kind[0]) == "":
			missing.append(kind[1])
	if missing.is_empty():
		status_label.text = "%s — INTRO / WIN / LOSE all authored." % g
	else:
		status_label.text = "%s — missing: %s" % [g, ", ".join(missing)]


func _play_clip(game: String, kind: String, method: String) -> void:
	if _playing:
		return
	var path := _clip_path(game, kind)
	if path == "":
		return
	var packed: PackedScene = load(path)
	if packed == null:
		status_label.text = "Failed to load " + path
		return
	_playing = true
	# Generation token: STOP and every later playback bump it (see the tail of this function).
	_play_gen += 1
	var gen: int = _play_gen
	_set_ui_locked(true)
	# Clips render fullscreen BEHIND this panel — bring the holder to front
	# and make it visible, otherwise the clip plays invisibly and the
	# viewer appears to do nothing.
	preview_holder.visible = true
	preview_holder.move_to_front()
	status_label.text = "Playing %s %s…" % [game, kind]
	var clip := packed.instantiate()
	preview_holder.add_child(clip)
	var done := [false]
	if clip.has_signal("outro_finished"):
		clip.connect("outro_finished", func() -> void: done[0] = true)
	clip.call(method)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
		if not is_instance_valid(clip):
			break
	if is_instance_valid(clip):
		clip.queue_free()
	# A coroutine that was still awaiting when the user pressed STOP and started another clip must
	# not run its tail over the new playback: these three lines hide the holder and unlock the
	# buttons, which blanked a clip started in the same frame the previous one was stopped.
	if gen != _play_gen:
		return
	_playing = false
	_set_ui_locked(false)
	preview_holder.visible = false
	if done[0]:
		status_label.text = "Finished %s %s." % [game, kind]
	else:
		status_label.text = "Stopped %s %s." % [game, kind]


func _stop_preview() -> void:
	_play_gen += 1
	for c in preview_holder.get_children():
		c.queue_free()
	preview_holder.visible = false
	_playing = false
	_set_ui_locked(false)
	status_label.text = "Stopped."


func _set_ui_locked(playing: bool) -> void:
	stop_button.disabled = not playing
	# NOTE: ItemList has no "disabled" property — setting it aborted this
	# function and left the UI half-locked (the viewer "hang"). Selection is
	# instead guarded by _playing inside _on_game_selected.
	back_button.disabled = playing
	for b in clip_buttons:
		b.disabled = playing
	if not playing:
		var sel := game_list.get_selected_items()
		if sel.size() > 0:
			_on_game_selected(sel[0])


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")
