extends Node

## Screenshot harness for the UI-bug pass: renders each named screen at a real
## phone geometry with the mobile adaptation path forced on, then writes a PNG.
##
## Windowed only - Control layout and DisplayServer.window_set_size need a real
## window, exactly as tools/AuditMobileUI.gd documents.
##
## Usage:
##   godot --path . res://tools/ShotUI.tscn -- <out_dir> [scene_basename ...]

const DEVICE := {"w": 2400, "h": 1080, "dpi": 420.0}

const SCENES := {
	"initial": "res://scenes/ui/InitialScreen.tscn",
	"settings": "res://scenes/ui/Settings.tscn",
	"customize": "res://scenes/ui/CharacterCustomization.tscn",
	"roadmap": "res://scenes/ui/RoadmapScreen.tscn",
	"shop": "res://scenes/ui/UnlockablesScreen.tscn",
}

var _out_dir: String = "user://shots"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		if _tree().paused:
			_tree().paused = false
		await _tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFUSING: needs a real window")
		_tree().quit(2)
		return

	var args := OS.get_cmdline_user_args()
	var wanted: Array = []
	if args.size() > 0:
		_out_dir = args[0]
		for i in range(1, args.size()):
			wanted.append(str(args[i]))
	if wanted.is_empty():
		wanted = SCENES.keys()

	DirAccess.make_dir_recursive_absolute(_out_dir)

	var mui := get_node_or_null("/root/MobileUIManager")
	if mui:
		mui.debug_mobile_mode = true
		mui.debug_dpi_override = DEVICE["dpi"]
		# No hardware cutout, matching the reported device: its captures show content
		# starting at y = 0. A desktop DisplayServer otherwise reports its own screen
		# rect as the safe area, which insets every scene by ~68 units and makes the
		# capture unrepresentative of the phone being fixed.
		mui.debug_safe_area_px_override = {
			"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0
		}
		if mui.has_method("_detect_platform"):
			mui._detect_platform()
		mui.invalidate_button_min_size_cache()

	DisplayServer.window_set_size(Vector2i(int(DEVICE["w"]), int(DEVICE["h"])))
	await _frames(30)
	if mui and mui.has_method("_detect_platform"):
		mui._detect_platform()
	if mui and mui.has_method("_calculate_safe_area"):
		mui._calculate_safe_area()
	if mui:
		mui.invalidate_button_min_size_cache()
		print("safe area: %s" % str(mui.get_safe_area_margins()))

	print("canvas %s window %s" % [
		str(_tree().root.get_visible_rect().size),
		str(DisplayServer.window_get_size())])

	for key in wanted:
		if not SCENES.has(key):
			print("unknown scene key: %s" % key)
			continue
		await _shoot(str(key), str(SCENES[key]), mui)

	# Second pass over the main menu on a near-fresh save: locked MULTIPLAYER, and a
	# NEXT UNLOCK card holding the two-line "<item>\n💧 N to go" label that used to
	# overflow the panel. 35 droplets with Pinky (50) still locked reproduces the
	# reported state exactly. Restored afterwards; nothing is written to disk because
	# save_all_data() is never called.
	if wanted.has("initial"):
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.player_data is Dictionary:
			var was_games: int = int(sm.player_data.get("games_played", 0))
			var was_drops: int = int(sm.player_data.get("water_droplets", 0))
			var was_chars: Array = (sm.unlocked_content.get("characters", []) as Array).duplicate()
			sm.player_data["games_played"] = 0
			sm.player_data["water_droplets"] = 35
			sm.unlocked_content["characters"] = ["droppy_blue"]
			await _shoot("initial_fresh", str(SCENES["initial"]), mui)
			sm.player_data["games_played"] = was_games
			sm.player_data["water_droplets"] = was_drops
			sm.unlocked_content["characters"] = was_chars

	# Customization with one accessory owned but not equipped, which is the third
	# thumbnail state and the one a full save never shows.
	if wanted.has("customize"):
		var sm2 := get_node_or_null("/root/SaveManager")
		if sm2 and sm2.unlocked_content is Dictionary:
			var owned: Array = sm2.unlocked_content.get("accessories", [])
			var before := owned.duplicate()
			if not owned.has("sun_hat"):
				owned.append("sun_hat")
			if not owned.has("cool_shades"):
				owned.append("cool_shades")
			sm2.unlocked_content["accessories"] = owned
			await _shoot("customize_owned", str(SCENES["customize"]), mui)
			sm2.unlocked_content["accessories"] = before

	# Settings with the Large Touch Targets accessibility option on: the compact list
	# rows are expected to give up their short height and take the 48dp floor.
	if wanted.has("settings"):
		var sm3 := get_node_or_null("/root/SaveManager")
		if sm3 and sm3.has_method("get_setting"):
			var was_large: bool = bool(sm3.get_setting("large_touch_targets", false))
			sm3.settings["large_touch_targets"] = true
			if mui:
				mui.invalidate_button_min_size_cache()
			await _shoot("settings_large_targets", str(SCENES["settings"]), mui)
			sm3.settings["large_touch_targets"] = was_large
			if mui:
				mui.invalidate_button_min_size_cache()

	_tree().quit(0)


## Extra frames captured after scrolling a named ScrollContainer, so the sections
## that only exist below the fold get pictures too.
const SCROLL_SHOTS := {
	"settings": [700, 1400, 2100, 2800],
}


func _shoot(key: String, path: String, mui: Node) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	if mui:
		mui.adapt_scene_for_mobile(inst)
	await _frames(70)

	_save(key, "")
	_dump(key, inst)

	var sc_probe := _find_scroll(inst)
	if sc_probe:
		print("    scroll rect=%s content=%s" % [
			str(sc_probe.get_global_rect()),
			str(sc_probe.get_child(0).get_combined_minimum_size())
				if sc_probe.get_child_count() > 0 else "-"])

	if SCROLL_SHOTS.has(key):
		var sc := _find_scroll(inst)
		if sc:
			for off in SCROLL_SHOTS[key]:
				sc.scroll_vertical = int(off)
				await _frames(3)
				_save(key, "_s%d" % int(off))
		else:
			print("  no ScrollContainer found for %s" % key)

	# Confirmation dialog for the destructive row. Only the popup is exercised:
	# nothing is erased unless `confirmed` fires, which needs a real press on OK.
	if key == "settings" and inst.has_method("_confirm_erase_all_data"):
		inst.call("_confirm_erase_all_data")
		await _frames(12)
		_save(key, "_erase_confirm")

	inst.queue_free()
	await _frames(4)


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node as ScrollContainer
	for c in node.get_children():
		var got := _find_scroll(c)
		if got:
			return got
	return null


func _save(key: String, suffix: String) -> void:
	var img := _tree().root.get_texture().get_image()
	var out := "%s/%s%s.png" % [_out_dir, key, suffix]
	var err := img.save_png(out)
	print("%s%s -> %s (err %d)" % [key, suffix, out, err])


## Measured geometry for the nodes the bug list names, so a fix can be checked
## against numbers as well as pixels.
func _dump(key: String, inst: Node) -> void:
	var paths: Array = []
	match key:
		"settings":
			paths = [
				"CenterContainer/PanelCard",
				"CenterContainer/PanelCard/MarginContainer/ScrollContainer",
			]
		"initial":
			paths = ["UI/BottomLeft", "UI/ButtonContainer/MultiplayerButton"]
	for p in paths:
		var n := inst.get_node_or_null(p) as Control
		if n:
			print("    %s rect=%s min=%s" % [
				p, str(n.get_global_rect()), str(n.get_combined_minimum_size())])
	_dump_rows(inst, 0)


func _dump_rows(node: Node, depth: int) -> void:
	if depth > 12:
		return
	if node is BaseButton or node is Label:
		var c := node as Control
		if c.is_visible_in_tree() and c.size.y > 0.0:
			var txt := ""
			if node is Button:
				txt = (node as Button).text
			elif node is CheckBox:
				txt = (node as CheckBox).text
			elif node is Label:
				txt = (node as Label).text
			if txt.length() > 30:
				txt = txt.substr(0, 30)
			print("      %s | %s | pos=%s size=%s" % [
				node.get_class(), txt.replace("\n", "\\n"),
				str(c.global_position.round()), str(c.size.round())])
	for ch in node.get_children():
		_dump_rows(ch, depth + 1)
