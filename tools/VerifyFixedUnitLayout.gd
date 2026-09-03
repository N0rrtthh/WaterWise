extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VerifyFixedUnitLayout — does the layout still fit when the window is not 1920x1080?
## ═══════════════════════════════════════════════════════════════════════════════
## project.godot ships viewport 1920x1080 with stretch/mode="canvas_items" and
## stretch/aspect="expand", so the visible rect GROWS in whichever axis the device has room in:
## a 21:9 phone in landscape gives 2560x1080, a 4:3 tablet 1920x1440. Content authored as
## absolute numbers against the design box therefore drifts, and five specific things did:
##
##   1. the water counter in MP_FillAquarium / MP_FlushToilets / MP_MopFloor / MP_WashCar /
##      MP_WaterPlants was a Control add_child()ed to a Node2D root that owns a Camera2D at
##      (576, 324), so "position = Vector2(20, 100)" meant WORLD (20, 100) and the counter slid
##      across the screen with the aspect ratio;
##   2. MP_FlushToilets pinned six toilets at (350 + col*250, 200 + row*250) — a 500x250 cluster
##      in the middle of a playfield over 1900 wide;
##   3. MP_WashVegetables put its sink at world (576, 500) and spawned into x[100, 1052],
##      y[100, 300] — roughly the middle half of the playfield;
##   4. FixLeak's backdrop was a fixed 1920x1080 ColorRect and its wall a fixed y[150, 900] one,
##      while the leak band was computed from the live viewport — on a 1920x1440 tablet leaks
##      landed as low as y=1180, below the wall, floating in the sky;
##   5. that same scene carried the only Camera2D in scenes/minigames, which broke the
##      world==screen assumption MicrogameShell makes for its input layer and drag mirroring.
##
## Each claim is measured at all three shapes in one process: writing get_window().size re-runs
## the stretch computation headless (verified — tools/ProbeViewportResize.gd), so the viewport
## really does become 2560x1080 and playfield_rect() really does move.
##
## Every positive check is paired with a detector-still-fires guard that measures what the OLD
## code would have produced at the same viewport, so a check that passes because the harness
## stopped looking cannot be mistaken for a check that passes because the layout is right.
##
## Only a host session is opened for the multiplayer half: MultiplayerMiniGameBase gates its
## build on connection_active, which GameManager.host_game() sets by itself, and nothing measured
## here needs a partner. The single-player half runs before any session exists.
##
## Known headless artifact, harmless here: the dummy display driver reports a 1920x1920 viewport
## at boot, so MobileUIManager reads the first resize down to 1080 as "soft keyboard shown" and
## calls _apply_keyboard_inset(). That walks get_tree().current_scene, which stays this harness
## (games are add_child()ed, never made current), and this harness has no Control child — so the
## inset is a no-op and cannot move anything being measured.
##
## Usage:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path E:\waterwise \
##       res://tools/VerifyFixedUnitLayout.tscn

const PORT: int = 7806
const SIZES: Array = [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1920, 1440)]

## The five games whose own HUD panel must hold the SAME screen position whatever the window
## is - see _expected_panel_pos() for why that position is not literally EXPECT_PANEL.
const HUD_GAMES: Array = [
	"res://scenes/multiplayer/MP_FillAquarium.tscn",
	"res://scenes/multiplayer/MP_FlushToilets.tscn",
	"res://scenes/multiplayer/MP_MopFloor.tscn",
	"res://scenes/multiplayer/MP_WashCar.tscn",
	"res://scenes/multiplayer/MP_WaterPlants.tscn",
]
const EXPECT_PANEL: Vector2 = Vector2(20.0, 100.0)
const FIX_LEAK: String = "res://scenes/minigames/FixLeak.tscn"

var results: Array = []
var game: Node = null


func _ready() -> void:
	print("\n=== VerifyFixedUnitLayout ===")
	await get_tree().process_frame
	# The soak harnesses persist auto_play_enabled=true into the save file; an autoplayer
	# patching leaks mid-measurement would empty the set being measured.
	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm != null and apm.get("auto_play_enabled"):
		apm.set_auto_play_enabled(false)
	await _run()
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["OK  " if ok else "FAIL", label, "" if detail.is_empty() else "  — " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Become a device of the given shape. Four frames: one for the window write, one for the
## stretch recompute, one for the resize signal listeners, one for anything they queued.
func _resize(size: Vector2i) -> void:
	get_window().size = size
	await _frames(4)


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


## Where a Control actually lands on the glass, whatever it is parented to.
func _screen_of(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas().origin


func _open(scene_path: String, ready_probe: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	game = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while waited < 12.0:
		var probe = game.get(ready_probe)
		if probe != null and (not (probe is Array) or not (probe as Array).is_empty()):
			await _frames(2)
			return true
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	return false


func _close() -> void:
	if game != null and is_instance_valid(game):
		game.set("game_active", false)
		get_tree().root.remove_child(game)
		game.free()
	game = null
	await get_tree().process_frame


func _run() -> void:
	for s in SIZES:
		await _resize(s as Vector2i)
		print("  ── FixLeak @ %s (viewport %s)" % [str(s), str(_vp())])
		await _fix_leak()

	_check("a host session is open, which is all MultiplayerMiniGameBase gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	for s in SIZES:
		await _resize(s as Vector2i)
		var vp := _vp()
		print("  ── multiplayer @ %s (viewport %s)" % [str(s), str(vp)])
		for path in HUD_GAMES:
			await _hud_panel(String(path))
		await _toilets()
		await _vegetables()


# ── 1. the five water counters ─────────────────────────────────────────────────

## The panel is built inside _on_multiplayer_ready(), which the base calls BEFORE
## _setup_multiplayer_ui(); attach_hud_panel() therefore has to create hud_layer lazily, and this
## check is what proves the panel ended up in it rather than in the world.
func _hud_panel(scene_path: String) -> void:
	var gname: String = scene_path.get_file().get_basename()
	if not await _open(scene_path, "water_indicator_label"):
		_check("[!] %s never built its water counter" % gname, false)
		await _close()
		return

	var label: Control = game.get("water_indicator_label") as Control
	var panel: Control = label
	while panel != null and not (panel is PanelContainer):
		panel = panel.get_parent() as Control
	if panel == null:
		_check("[!] %s: the counter label has no PanelContainer above it" % gname, false)
		await _close()
		return

	var got: Vector2 = _screen_of(panel)
	var want: Vector2 = _expected_panel_pos()
	_check("%s: counter holds screen %s" % [gname, str(want)],
		got.distance_to(want) < 1.5,
		"screen %s, parent %s (%s)" % [str(got), panel.get_parent().name, panel.get_parent().get_class()])

	# Detector still fires: the same offset, parented the OLD way (straight onto the Node2D
	# root, i.e. world space) must NOT land on screen (20, 100) — otherwise this viewport
	# cannot tell the two apart and the check above proves nothing here.
	var twin := PanelContainer.new()
	twin.position = EXPECT_PANEL
	game.add_child(twin)
	await get_tree().process_frame
	var twin_screen: Vector2 = _screen_of(twin)
	_check("%s: world-parented twin drifts, so the check can fail" % gname,
		twin_screen.distance_to(EXPECT_PANEL) > 50.0,
		"old parenting would draw it at %s — %s px away" % [
			str(twin_screen), str(int(twin_screen.distance_to(EXPECT_PANEL)))])
	twin.free()
	await _close()

## Where the counter panel is supposed to sit on screen, recomputed here rather than read off
## the panel being measured.
##
## EXPECT_PANEL alone was wrong, and stayed wrong for a whole batch: the panel's authored
## offset IS (20, 100), but MultiplayerMiniGameBase._finish_hud_panel() then pushes it down
## clear of the top bar, because at the authored offset the first caption sat under a 60%-black
## stylebox and rasterised at 3.53:1. So the shipped panel lands at (20, 134) and this harness
## reported that deliberate fix as five failures at each of three viewports - 15 of them.
##
## The clearance is derived from the live TopBar with the same rule the base uses (its own
## content-height floor of 120, +10 of stylebox expand_margin_bottom, +4 of gap) so this is an
## independent recomputation, not a copy of whatever the product happened to do. What the check
## still pins hard is the part that actually drifts: x stays 20 and y stays put at every
## viewport, which world-space parenting cannot manage.
func _expected_panel_pos() -> Vector2:
	var layer: Node = game.get("hud_layer") if game != null else null
	if layer == null:
		return EXPECT_PANEL
	var bar: Node = layer.get_node_or_null("TopBar")
	if not (bar is Control):
		return EXPECT_PANEL
	var bar_ctrl: Control = bar
	var bottom: float = bar_ctrl.position.y + maxf(bar_ctrl.size.y, 120.0) + 14.0
	return Vector2(EXPECT_PANEL.x, maxf(EXPECT_PANEL.y, bottom))


# ── 2. MP_FlushToilets' six toilets ────────────────────────────────────────────

## The old grid was six 160x170 hit boxes pinned at (350 + col*250, 200 + row*250): a 500x250
## cluster whose bounding box, hit boxes included, covered 660x420 of a playfield 1920x1080 or
## larger. This measures that the grid now derives from playfield_rect() — inside it, below the
## HUD band, and actually spread across it.
func _toilets() -> void:
	if not await _open("res://scenes/multiplayer/MP_FlushToilets.tscn", "toilets"):
		_check("[!] MP_FlushToilets never built its toilets", false)
		await _close()
		return

	var field: Rect2 = game.playfield_rect() as Rect2
	var band_top: float = field.position.y + field.size.y * float(game.get("HUD_BAND_FRAC"))
	var bbox := Rect2()
	var outside: int = 0
	var in_hud: int = 0
	var toilets: Array = game.get("toilets") as Array
	for t in toilets:
		var n := t as Node2D
		var shape := (n.get_child(0) as CollisionShape2D).shape as RectangleShape2D
		var r := Rect2(n.position - shape.size * 0.5, shape.size)
		bbox = r if bbox.size == Vector2.ZERO else bbox.merge(r)
		if not field.encloses(r):
			outside += 1
		if r.position.y < band_top:
			in_hud += 1

	_check("MP_FlushToilets: all %d toilet hit boxes are inside the playfield" % toilets.size(),
		toilets.size() == 6 and outside == 0,
		"playfield %s, grid bbox %s, %d outside" % [str(field), str(bbox), outside])
	_check("MP_FlushToilets: no toilet reaches up into the HUD band", in_hud == 0,
		"band ends at y=%.0f, highest toilet top y=%.0f" % [band_top, bbox.position.y])
	var cover_x: float = bbox.size.x / field.size.x
	var cover_y: float = bbox.size.y / field.size.y
	_check("MP_FlushToilets: the grid spreads across the playfield, not a middle cluster",
		cover_x > 0.6 and cover_y > 0.4,
		"covers %.0f%% of width, %.0f%% of height" % [cover_x * 100.0, cover_y * 100.0])

	# Detector still fires: the authored coordinates, measured against this same playfield.
	var old_bbox := Rect2(Vector2(350.0, 200.0) - Vector2(80.0, 85.0), Vector2(500.0, 250.0) + Vector2(160.0, 170.0))
	_check("MP_FlushToilets: the old fixed grid fails the same two tests",
		(old_bbox.size.x / field.size.x) < 0.6 or not field.encloses(old_bbox),
		"old bbox %s = %.0f%% of width, enclosed=%s" % [
			str(old_bbox), (old_bbox.size.x / field.size.x) * 100.0, str(field.encloses(old_bbox))])
	await _close()


# ── 3. MP_WashVegetables' sink and spawn band ──────────────────────────────────

## The sink sat at world (576, 500) and vegetables spawned into x[100, 1052], y[100, 300] — the
## middle ~50% of the width and a 200-unit strip of a playfield over 1000 tall, both of which
## slide off-centre as soon as the camera centres a wider or taller window.
func _vegetables() -> void:
	if not await _open("res://scenes/multiplayer/MP_WashVegetables.tscn", "sink_area"):
		_check("[!] MP_WashVegetables never built its sink", false)
		await _close()
		return

	var field: Rect2 = game.playfield_rect() as Rect2
	var sink: Node2D = game.get("sink_area") as Node2D
	var sink_size: Vector2 = game.get("SINK_SIZE") as Vector2
	var sink_rect := Rect2(sink.position - sink_size * 0.5, sink_size)
	_check("MP_WashVegetables: the sink is centred in the playfield and inside it",
		absf(sink.position.x - field.get_center().x) < 1.5 and field.encloses(sink_rect),
		"sink %s, playfield centre x=%.0f, bottom y=%.0f" % [
			str(sink.position), field.get_center().x, field.end.y])

	# _spawn_point() is pure — no state to reset — so the band itself can be sampled.
	var margin: float = float(game.get("SPAWN_MARGIN"))
	var reach := Rect2(field.position + Vector2(margin, margin), field.size - Vector2(margin, margin) * 2.0)
	var out_of_reach: int = 0
	var sampled := Rect2()
	for _i in range(400):
		var p: Vector2 = game.call("_spawn_point") as Vector2
		sampled = Rect2(p, Vector2.ZERO) if sampled.size == Vector2.ZERO and sampled.position == Vector2.ZERO \
			else sampled.expand(p)
		if not reach.has_point(p):
			out_of_reach += 1
	_check("MP_WashVegetables: 400 spawns all land where a finger can reach them",
		out_of_reach == 0,
		"reachable band %s, sampled %s, %d outside" % [str(reach), str(sampled), out_of_reach])
	var cover_x: float = sampled.size.x / field.size.x
	_check("MP_WashVegetables: spawns use the whole width, not the middle half",
		cover_x > 0.8,
		"sampled width %.0f of playfield %.0f = %.0f%%" % [
			sampled.size.x, field.size.x, cover_x * 100.0])

	# Detector still fires: the authored band against this same playfield.
	var old_band := Rect2(100.0, 100.0, 952.0, 200.0)
	_check("MP_WashVegetables: the old fixed band fails the same two tests",
		(old_band.size.x / field.size.x) < 0.8 or not reach.encloses(old_band),
		"old band %s = %.0f%% of width, reachable=%s" % [
			str(old_band), (old_band.size.x / field.size.x) * 100.0, str(reach.encloses(old_band))])
	await _close()


# ── 4 + 5. FixLeak: backdrop, wall, leak band, input layer ─────────────────────

## Single-player, so no session and no camera: this scene used to own the only Camera2D in
## scenes/minigames, which is why MicrogameShell's input layer (positioned at Vector2.ZERO and
## sized from the viewport) and its drag mirroring were both wrong here and only here.
func _fix_leak() -> void:
	if not await _open(FIX_LEAK, "shell_input_layer"):
		_check("[!] FixLeak never built its input layer", false)
		await _close()
		return
	var vp := _vp()

	_check("FixLeak: no Camera2D, so world == screen as the shell assumes",
		get_viewport().get_camera_2d() == null,
		"canvas_transform.origin=%s" % str(get_viewport().canvas_transform.origin))

	var layer: Control = game.get("shell_input_layer") as Control
	_check("FixLeak: the input layer covers exactly the visible rect",
		layer.position.is_equal_approx(Vector2.ZERO) and layer.size.distance_to(vp) < 1.5,
		"layer %s at %s vs viewport %s" % [str(layer.size), str(layer.position), str(vp)])

	var sky: ColorRect = game.get_node("Background") as ColorRect
	_check("FixLeak: the sky covers the window with no bare edge",
		sky.position.is_equal_approx(Vector2.ZERO) and sky.size.x >= vp.x - 1.5 and sky.size.y >= vp.y - 1.5,
		"sky %s vs viewport %s" % [str(sky.size), str(vp)])

	var wall: ColorRect = game.get_node("Wall") as ColorRect
	var wall_rect := Rect2(wall.position, wall.size)
	_check("FixLeak: the wall spans the width and stays inside the window",
		wall.size.x >= vp.x - 1.5 and wall_rect.position.y > 0.0 and wall_rect.end.y <= vp.y + 1.5,
		"wall %s" % str(wall_rect))

	await _tap_to_start()
	# Wait for the round: leaks are placed in _shell_start(), after the one-second verb flash.
	# The wait is on the CLOCK, not on a frame count: headless runs uncapped, so 900 process_frame
	# awaits can be a tenth of a second of game time and the flash has not finished — measured, the
	# frame-count version read _placed_count as 0 at all three shapes.
	var waited: float = 0.0
	while int(game.get("_placed_count")) == 0 and waited < 8.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	var placed: int = int(game.get("_placed_count"))
	var tap: float = float(game.get("TAP_RADIUS"))
	var off_wall: int = 0
	var off_screen: int = 0
	var leaks: Array = game.get("leaks") as Array
	for i in range(placed):
		var n := leaks[i] as Node2D
		if not wall_rect.has_point(n.position):
			off_wall += 1
		if n.position.x - tap < 0.0 or n.position.x + tap > vp.x \
				or n.position.y - tap < 0.0 or n.position.y + tap > vp.y:
			off_screen += 1
	_check("FixLeak: all %d leaks of this round are on the wall and fully tappable" % placed,
		placed >= 2 and off_wall == 0 and off_screen == 0,
		"%d off the wall, %d with the tap target clipped" % [off_wall, off_screen])

	# A round only places 2-5 leaks, so the BAND is sampled directly. _find_slot() appends into
	# the pre-sized _placed array, so _placed_count is rewound before each call — spacing is not
	# what is under test here, reach is.
	var band_out: int = 0
	var band := Rect2()
	for _i in range(300):
		game.set("_placed_count", 0)
		var p: Vector2 = game.call("_find_slot") as Vector2
		band = Rect2(p, Vector2.ZERO) if _i == 0 else band.expand(p)
		if not wall_rect.has_point(p) or p.x - tap < 0.0 or p.x + tap > vp.x:
			band_out += 1
	game.set("_placed_count", placed)
	_check("FixLeak: 300 sampled slots all stay on the wall and on screen", band_out == 0,
		"sampled band %s inside wall %s, %d outside" % [str(band), str(wall_rect), band_out])

	# Detector still fires — but honestly: the old geometry was RIGHT at exactly 1920x1080 and
	# wrong at every other shape, which is the whole point. The old wall was a fixed y[150, 900]
	# ColorRect 1920 wide while the leak band ran from the live viewport to _vp_size.y - 260, and
	# the old sky was a fixed 1920x1080 ColorRect. So the expectation is parameterised by shape.
	var old_wall := Rect2(0.0, 150.0, 1920.0, 750.0)
	var old_band := Rect2(110.0, 210.0, vp.x - 220.0, (vp.y - 260.0) - 210.0)
	var off_design: bool = vp.x > 1920.5 or vp.y > 1080.5
	var old_bad: bool = not old_wall.encloses(old_band) or old_wall.size.x < vp.x - 1.5
	_check("FixLeak: the old fixed wall/band %s at this viewport" % ["disagree" if off_design else "agree"],
		old_bad == off_design,
		"old wall %s vs old band %s; band bottom y=%.0f, wall bottom y=900" % [
			str(old_wall), str(old_band), old_band.end.y])
	var uncovered: float = maxf(vp.x - 1920.0, 0.0) * vp.y + maxf(vp.y - 1080.0, 0.0) * minf(vp.x, 1920.0)
	_check("FixLeak: the old fixed sky left %d px^2 of bare window" % int(uncovered),
		(vp.x > 1920.5 or vp.y > 1080.5) == (uncovered > 0.0),
		"viewport %s vs old sky 1920x1080" % str(vp))
	await _close()


## Dismiss the "tap to start" prompt the way a player does.
##
## MiniGameBase._ready() ends in `await _wait_for_input()`, and that polls
## Input.is_mouse_button_pressed() with its own down-edge detector — only Input.parse_input_event
## updates that state (push_input does not), and parse_input_event expects WINDOW coordinates, so
## the position is mapped viewport→window first. Without this the round never starts and every
## leak measurement reads an empty board (measured: _placed_count stayed 0 at all three shapes).
func _tap_to_start() -> void:
	var win_pos: Vector2 = get_tree().root.get_final_transform() * (_vp() * 0.5)
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = win_pos
	dn.global_position = win_pos
	dn.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(dn)
	await _frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = win_pos
	up.global_position = win_pos
	up.button_mask = 0
	Input.parse_input_event(up)
	await _frames(2)
