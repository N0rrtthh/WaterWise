extends Node

## ProbeShellInput — reproduces the HUMAN input path for the v2 shell games.
##
## The AutoPlay soak never exercises real input: AutoPlayManager calls
## _on_leak_clicked / _sort_bucket / _shell_drag directly. This probe instead
## pushes genuine InputEventMouseMotion / InputEventMouseButton through
## Input.parse_input_event, so touch emulation, viewport GUI picking and
## gui_input delivery all run exactly as they do for a human player.
##
## A logger is attached to each game's shell_input_layer.gui_input so we can
## SEE which events actually arrive. If the logged events look right but the
## game does not react, the bug is in the game's hit-testing; if the events
## never arrive, the bug is in delivery.
##
## Usage:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path E:\waterwise res://tools/ProbeShellInput.tscn

const FIX_LEAK_SCENE := "res://scenes/minigames/FixLeak.tscn"
const GREYWATER_SCENE := "res://scenes/minigames/GreywaterSorter.tscn"
const FRAME_GUARD: int = 900  # ~15 s at 60 fps

var _tag: String = "???"


func _ready() -> void:
	print("[PROBE] boot, viewport=", get_viewport().get_visible_rect().size)
	await get_tree().process_frame
	await get_tree().process_frame
	# CRITICAL: the soak harnesses persist auto_play_enabled=true into the
	# save file, which hijacks gameplay and voids any human-input probe.
	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm and apm.get("auto_play_enabled"):
		print("[PROBE] AutoPlay was ON (leaked from save) — disabling")
		apm.set_auto_play_enabled(false)
	print("[PROBE] AutoPlay now: ", apm.is_auto_play_enabled() if apm else "n/a")
	await _probe_fix_leak()
	await _probe_greywater()
	print("[PROBE] done")
	get_tree().quit(0)


var _watch_count: int = 0

func _input(event: InputEvent) -> void:
	if _watch_count > 40:
		return
	if event is InputEventMouseMotion:
		return  # too noisy
	_watch_count += 1
	var pos := "?"
	if event is InputEventMouse:
		pos = str(event.position)
	print("[PROBE][TREE] ", event.get_class(), " pos=", pos,
			" device=", event.device)


# ── FixLeak: hover + click on the first leak ────────────────────────────────

func _probe_fix_leak() -> void:
	print("[PROBE] ── FixLeak ──")
	var game: Node = await _boot_game(FIX_LEAK_SCENE)
	if game == null:
		return

	# Wait for the first leak to be acquired and visible.
	var guard := 0
	while (game.leaks.is_empty() or not game.leaks[0].visible) and guard < FRAME_GUARD:
		await get_tree().process_frame
		guard += 1
	if not game.leaks[0].visible:
		print("[PROBE][FAIL] no visible leak appeared")
		game.queue_free()
		return

	var leak: Node2D = game.leaks[0]
	var pos: Vector2 = leak.global_position
	print("[PROBE] leak0 pos=", pos, " tap_radius+=", 60.0 + 26.0)

	_dump_controls("before FixLeak click")
	_hover(pos)
	await get_tree().process_frame
	var hovered := get_tree().root.gui_get_hovered_control()
	print("[PROBE] hovered control after motion: ",
			hovered.name if hovered else "<none>",
			" (", hovered.get_class() if hovered else "-", ")")
	_click(pos)
	await get_tree().process_frame
	await get_tree().process_frame

	print("[PROBE] FixLeak fixed_leaks=", game.fixed_leaks,
			" score=", game.current_score)
	if game.fixed_leaks == 0:
		print("[PROBE][FAIL] real click did NOT fix the leak")
		# Control experiment: the AutoPlay contract call must still work.
		game._on_leak_clicked(leak)
		await get_tree().process_frame
		print("[PROBE] control: direct _on_leak_clicked → fixed_leaks=",
				game.fixed_leaks)
	else:
		print("[PROBE][OK] real click fixed the leak")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ── GreywaterSorter: press bucket → drag left → release ─────────────────────

func _probe_greywater() -> void:
	print("[PROBE] ── GreywaterSorter ──")
	var game: Node = await _boot_game(GREYWATER_SCENE)
	if game == null:
		return

	var bucket: Node2D = null
	var guard := 0
	while bucket == null and guard < FRAME_GUARD:
		await get_tree().process_frame
		for i in range(game.buckets.size()):
			var b: Node2D = game.buckets[i]
			if b.visible and b.position.y > 0.0:
				bucket = b
				break
		guard += 1
	if bucket == null:
		print("[PROBE][FAIL] no visible bucket appeared")
		game.queue_free()
		return

	var vp := get_viewport().get_visible_rect().size
	var grab: Vector2 = bucket.global_position
	var drop := Vector2(vp.x * 0.12, grab.y)
	print("[PROBE] bucket pos=", grab, " → drag to ", drop)

	_press(grab)
	await get_tree().process_frame
	for step in range(6):
		var t := (float(step) + 1.0) / 6.0
		_drag(grab.lerp(drop, t))
		await get_tree().process_frame
	_release(drop)
	await get_tree().process_frame
	await get_tree().process_frame

	print("[PROBE] Greywater sorted_correct=", game.sorted_correct,
			" mistakes=", game.mistakes_made,
			" current_bucket=", game.current_bucket,
			" score=", game.current_score)
	if game.sorted_correct > 0 or game.mistakes_made > 0:
		print("[PROBE][OK] swipe reached the sorter (correct or miss)")
	else:
		print("[PROBE][FAIL] swipe did NOT sort a bucket")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ── Shared boot: instantiate, skip "tap to start", wait for game_active ─────

func _boot_game(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		print("[PROBE][FAIL] cannot load ", scene_path)
		return null
	var game: Node = packed.instantiate()
	_tag = scene_path.get_file().get_basename()
	add_child(game)

	var guard := 0
	while game.get("shell_input_layer") == null and guard < FRAME_GUARD:
		await get_tree().process_frame
		guard += 1
	if game.get("shell_input_layer") == null:
		print("[PROBE][FAIL] shell_input_layer never built for ", _tag)
		game.queue_free()
		return null
	game.shell_input_layer.gui_input.connect(_log_gui_input)
	print("[PROBE] logger connections on shell_input_layer.gui_input: ",
			game.shell_input_layer.gui_input.get_connections().size())
	print("[PROBE] ShellInput rect=", game.shell_input_layer.get_global_rect(),
			" anchors=", game.shell_input_layer.anchor_left, ",",
			game.shell_input_layer.anchor_top, ",",
			game.shell_input_layer.anchor_right, ",",
			game.shell_input_layer.anchor_bottom,
			" parent=", game.shell_input_layer.get_parent().name,
			" parent_class=", game.shell_input_layer.get_parent().get_class())

	# _wait_for_input() polls Input.is_mouse_button_pressed() with a manual
	# down-edge detector — only Input.parse_input_event updates that state
	# (push_input does not). Hold a parsed press for two frames, then release.
	_boot_click()
	await get_tree().process_frame
	await get_tree().process_frame
	_boot_release()
	await get_tree().process_frame

	guard = 0
	while not game.game_active and guard < FRAME_GUARD:
		await get_tree().process_frame
		guard += 1
	print("[PROBE] ", _tag, " game_active=", game.game_active,
			" (guard=", guard, ")")
	if not game.game_active:
		print("[PROBE][FAIL] game never became active")
		game.queue_free()
		return null
	return game


# ── Event injection (the human path: Input.parse_input_event) ───────────────
#
# parse_input_event expects WINDOW coordinates. With canvas_items+expand
# stretch the root window applies its final transform to incoming events, so
# every injected position must be mapped viewport→window first.

# ── Event injection ─────────────────────────────────────────────────────────
#
# push_input(ev, true) treats the event as already in LOCAL (viewport)
# coordinates — exactly what the root window hands the scene on a real 1:1
# fullscreen display. parse_input_event would require WINDOW coords, and the
# headless 64×36 window applies a lossy expand-stretch transform that a real
# 16:9 fullscreen session never sees.

func _hover(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.button_mask = 0
	get_tree().root.push_input(m, true)


func _click(pos: Vector2) -> void:
	_press(pos)
	_release(pos)


func _press(pos: Vector2) -> void:
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = pos
	dn.global_position = pos
	dn.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(dn, true)


func _drag(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.relative = Vector2(20.0, 0.0)
	get_tree().root.push_input(m, true)


func _release(pos: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	up.button_mask = 0
	get_tree().root.push_input(up, true)


## Start-card click only: must go through Input.parse_input_event so the
## Input singleton's is_mouse_button_pressed() state updates. Positions are
## mapped viewport→window first.
func _boot_click() -> void:
	var vp_pos := Vector2(960.0, 540.0)
	var win_pos := get_tree().root.get_final_transform() * vp_pos
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = win_pos
	dn.global_position = win_pos
	dn.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(dn)


func _boot_release() -> void:
	var vp_pos := Vector2(960.0, 540.0)
	var win_pos := get_tree().root.get_final_transform() * vp_pos
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = win_pos
	up.global_position = win_pos
	up.button_mask = 0
	Input.parse_input_event(up)

## its rect, mouse filter and owning CanvasLayer — the GUI pick suspects.
func _dump_controls(when: String) -> void:
	print("[PROBE][CTRL] ── visible STOP/PASS controls (", when, ") ──")
	_dump_controls_rec(get_tree().root, -1.0)
	print("[PROBE][CTRL] ── end ──")


func _dump_controls_rec(node: Node, layer_y: float) -> void:
	if node is CanvasLayer:
		layer_y = (node as CanvasLayer).layer
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var dr := c.get_global_rect()
			if dr.size.x > 1.0 and dr.size.y > 1.0 and dr.position.y > -2000.0:
				print("[PROBE][CTRL] layer=", layer_y, " ", _path_of(c),
						" rect=", dr, " filter=", c.mouse_filter)
	for child in node.get_children():
		_dump_controls_rec(child, layer_y)


func _path_of(n: Node) -> String:
	var p := n.name
	var cur := n
	while cur.get_parent() != null and cur.get_parent() != get_tree().root:
		cur = cur.get_parent()
		p = cur.name + "/" + p
	return p


func _log_gui_input(ev: InputEvent) -> void:
	var pos := "?"
	if ev is InputEventMouse or ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		pos = str(ev.position)
	var pressed := "?"
	if "pressed" in ev:
		pressed = str(ev.pressed)
	print("[PROBE][EVT ", _tag, "] ", ev.get_class(), " pos=", pos,
			" pressed=", pressed)
