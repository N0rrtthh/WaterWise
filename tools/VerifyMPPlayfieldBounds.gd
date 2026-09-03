extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VerifyMPPlayfieldBounds — the five multiplayer games that read the viewport
## ═══════════════════════════════════════════════════════════════════════════════
## Every scenes/multiplayer/MP_*.tscn is a Node2D world with a Camera2D at (576, 324): the centre
## of the 1152x648 viewport these scenes were authored against. The project ships 1920x1080 with
## stretch/aspect="expand". The camera therefore centres the authored art and the visible world
## rect becomes x[-384, 1536], y[-216, 864] on desktop (taller still in this headless run, and on
## a phone). get_viewport().get_visible_rect() returns (0, 0, 1920, 1080) — the right SIZE at the wrong ORIGIN.
##
## Five games used that rect, or hardcoded authoring numbers, as world coordinates:
##   MP_CatchTheRain        rain spawned across world x[50, 1870] with the visible right edge at
##                          1536, so ~18% of drops were uncatchable and cost a shared life every
##                          eighth time, while the leftmost 434 px never saw a drop;
##   MP_CollectDishWater    dragged buckets clamped to x<=1870, 334 px off-screen right;
##   MP_CollectShowerWater  same clamp, plus catchers seated at authored y=450;
##   MP_CollectLaundryWater same clamp at 75..1845, containers seated at y=500;
##   MP_FilterWater         clickable dirt spawned down to y=980 (1820 in this viewport) with the
##                          visible bottom at 864 (1284) and bounced off walls further out still —
##                          dirt the player cannot reach, and the water queue only drains when
##                          dirt is tapped.
## The three collect games also counted a falling object missed at y > 700, which is 164 px above
## the visible bottom here, several hundred on a phone: drops died in mid-air.
##
## Only a host is opened: MultiplayerMiniGameBase gates on connection_active, which host_game()
## sets by itself, and nothing measured here needs a partner. game_active is written directly
## because the base normally opens a round behind an instruction overlay and a countdown, and the
## code under test only runs while it is true. Input is delivered by calling the handler the
## engine would call, with a viewport-local position: headless cannot move the OS mouse (verified
## — push_input, warp_mouse and parse_input_event all leave get_mouse_position() at (0, 0)) and a
## window-space push_input would apply the content-scale transform a second time.

const PORT: int = 7805

## One row per game under test. `catchers` names the array of draggables (empty for the games that
## have none), `spawn` the method that creates one falling object, and `missed` the counter that
## must tick exactly once when one leaves the screen.
const GAMES: Array = [
	{
		"scene": "res://scenes/multiplayer/MP_CatchTheRain.tscn",
		"catchers": "", "single": "bucket",
		"half_w": "BUCKET_HALF_W", "margin_bottom": "BUCKET_MARGIN_BOTTOM",
		"spawn": "_spawn_raindrop", "spawn_margin": "SPAWN_MARGIN",
		"missed": "drops_missed", "meta_type": "raindrop",
		"old_band": [50.0, -1.0], "old_miss": -1.0,
	},
	{
		"scene": "res://scenes/multiplayer/MP_CollectDishWater.tscn",
		"catchers": "buckets", "single": "",
		"half_w": "BUCKET_HALF_W", "margin_bottom": "BUCKET_MARGIN_BOTTOM",
		"spawn": "_spawn_water_drop", "spawn_margin": "SPAWN_MARGIN",
		"missed": "spills", "meta_type": "dishwater",
		"old_band": [150.0, 1002.0], "old_miss": 700.0,
	},
	{
		"scene": "res://scenes/multiplayer/MP_CollectShowerWater.tscn",
		"catchers": "buckets", "single": "",
		"half_w": "BUCKET_HALF_W", "margin_bottom": "BUCKET_MARGIN_BOTTOM",
		"spawn": "_spawn_water_drop", "spawn_margin": "SPAWN_MARGIN",
		"missed": "overflows", "meta_type": "",
		"old_band": [100.0, 1000.0], "old_miss": 700.0,
	},
	{
		"scene": "res://scenes/multiplayer/MP_CollectLaundryWater.tscn",
		"catchers": "containers", "single": "",
		"half_w": "CONTAINER_HALF_W", "margin_bottom": "CONTAINER_MARGIN_BOTTOM",
		"spawn": "_spawn_water_stream", "spawn_margin": "SPAWN_MARGIN",
		"missed": "water_missed", "meta_type": "water",
		"old_band": [200.0, 952.0], "old_miss": 700.0,
	},
]

var results: Array = []
var game: Node = null


func _ready() -> void:
	print("\n=== VerifyMPPlayfieldBounds ===")
	await get_tree().process_frame
	await _run()
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _view() -> Rect2:
	return game.playfield_rect() as Rect2


## Loads one MP scene as the round under test and waits until its own setup has run.
func _open(scene_path: String, ready_probe: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	game = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while waited < 8.0:
		var probe = game.get(ready_probe)
		if probe != null and (not (probe is Array) or not (probe as Array).is_empty()):
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return false


func _close() -> void:
	if game != null and is_instance_valid(game):
		game.set("game_active", false)
		get_tree().root.remove_child(game)
		game.free()
	game = null
	await get_tree().process_frame


## Everything the game spawned that moves: the falling objects all five games track by a
## "velocity" meta on a direct Area2D child.
func _falling() -> Array:
	var out: Array = []
	for c in game.get_children():
		if c is Area2D and c.has_meta("velocity") and not c.has_meta("water_level") \
				and not c.has_meta("capacity"):
			out.append(c)
	return out


func _free_falling() -> void:
	for d in _falling():
		d.free()


## A falling object parked at a known y with no velocity, so the miss line is sampled where the
## check puts it instead of wherever a moving object happened to be on that frame.
func _park(y: float, meta_type: String) -> Area2D:
	var d := Area2D.new()
	d.position = Vector2(_view().get_center().x, y)
	d.set_meta("velocity", Vector2.ZERO)
	if not meta_type.is_empty():
		d.set_meta("type", meta_type)
	game.add_child(d)
	return d


func _run() -> void:
	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	for spec in GAMES:
		await _one_game(spec as Dictionary)
	await _filter_water()
	await _mop_floor()


func _one_game(spec: Dictionary) -> void:
	var gname: String = String(spec["scene"]).get_file().get_basename()
	print("  ── %s" % gname)
	var probe: String = String(spec["catchers"]) if not String(spec["catchers"]).is_empty() \
		else String(spec["single"])
	if not await _open(String(spec["scene"]), probe):
		_check("[!] %s never finished building, so nothing further can be measured" % gname, false)
		await _close()
		return

	var view: Rect2 = _view()
	var half_w: float = float(game.get(String(spec["half_w"])))
	var margin_bottom: float = float(game.get(String(spec["margin_bottom"])))
	var min_x: float = view.position.x + half_w
	var max_x: float = view.end.x - half_w

	# The premise of the whole fix: the visible rect is NOT the viewport rect.
	_check("%s: the playfield is offset from the viewport rect by the camera" % gname,
		absf(view.position.x - (-384.0)) < 1.0 and view.position.y < -1.0,
		"playfield %s vs get_viewport().get_visible_rect() %s" % [str(view), str(get_viewport().get_visible_rect())])

	# -- catchers: seated across the visible width, above the visible bottom --
	var catchers: Array = []
	if not String(spec["catchers"]).is_empty():
		catchers = game.get(String(spec["catchers"])) as Array
	elif not String(spec["single"]).is_empty():
		catchers = [game.get(String(spec["single"]))]
	var off_screen: int = 0
	var wrong_y: int = 0
	var xs: Array = []
	for c in catchers:
		var n := c as Node2D
		if n == null:
			continue
		xs.append(n.position.x)
		if n.position.x < min_x - 0.5 or n.position.x > max_x + 0.5:
			off_screen += 1
		if absf(n.position.y - (view.end.y - margin_bottom)) > 1.0:
			wrong_y += 1
	_check("%s: every catcher is inside the visible width" % gname,
		not catchers.is_empty() and off_screen == 0,
		"%d catchers at %s within [%.0f, %.0f]" % [catchers.size(), str(xs), min_x, max_x])
	_check("%s: every catcher sits on the visible bottom, not at an authored y" % gname,
		wrong_y == 0,
		"expected y=%.1f (visible bottom %.1f - %.0f)" % [view.end.y - margin_bottom, view.end.y, margin_bottom])

	# -- the drag clamp: aim a pointer far outside the frame on both sides --
	game.set("game_active", true)
	if not String(spec["catchers"]).is_empty() and not catchers.is_empty():
		var handle := catchers[0] as Area2D
		var grabber: String = "dragging_container" if String(spec["catchers"]) == "containers" \
			else "dragging_bucket"
		game.set(grabber, handle)
		for aim_x in [view.end.x + 900.0, view.position.x - 900.0]:
			var motion := InputEventMouseMotion.new()
			motion.position = get_viewport().get_canvas_transform() * Vector2(aim_x, view.get_center().y)
			game._input(motion)
			await get_tree().process_frame
			_check("%s: a drag aimed %.0f px outside the frame stops at the edge" % [gname, 900.0],
				handle.position.x >= min_x - 0.5 and handle.position.x <= max_x + 0.5,
				"aimed at world x=%.0f, landed at %.1f within [%.0f, %.0f]"
					% [aim_x, handle.position.x, min_x, max_x])
		# The old clamp let the same drag leave the frame. Stated as a measurement, not a claim.
		_check("%s: the old clamp really did allow off-screen positions on this camera" % gname,
			get_viewport().get_visible_rect().size.x - 50.0 > max_x + 50.0,
			"old max x=%.0f vs visible max %.0f (%.0f px off-screen)"
				% [get_viewport().get_visible_rect().size.x - 50.0, max_x, get_viewport().get_visible_rect().size.x - 50.0 - max_x])
		game.set(grabber, null)

	# -- spawning: across the visible width, entering from above the visible top --
	game.set("game_active", false)
	_free_falling()
	await get_tree().process_frame
	var spawn_margin: float = float(game.get(String(spec["spawn_margin"])))
	game.set("game_active", true)
	for _i in range(40):
		game.call(String(spec["spawn"]))
	await get_tree().process_frame
	var spawned: Array = _falling()
	var out_of_band: int = 0
	var on_screen_already: int = 0
	var old_off_screen: int = 0
	var old_lo: float = float((spec["old_band"] as Array)[0])
	var old_hi: float = float((spec["old_band"] as Array)[1])
	if old_hi < 0.0:
		old_hi = get_viewport().get_visible_rect().size.x - 50.0
	for d in spawned:
		var dn := d as Node2D
		if dn.position.x < view.position.x + spawn_margin - 1.0 \
				or dn.position.x > view.end.x - spawn_margin + 1.0:
			out_of_band += 1
		if dn.position.y >= view.position.y:
			on_screen_already += 1
	_check("%s: 40 spawns all land inside the visible width" % gname,
		spawned.size() >= 40 and out_of_band == 0,
		"%d objects, %d outside [%.0f, %.0f]"
			% [spawned.size(), out_of_band, view.position.x + spawn_margin, view.end.x - spawn_margin])
	_check("%s: they enter from above the visible top instead of blinking in" % gname,
		on_screen_already == 0, "%d of %d started on screen" % [on_screen_already, spawned.size()])
	# What the authored band would have done here, measured rather than asserted from memory.
	var old_span: float = old_hi - old_lo
	if old_span > 0.0:
		var reachable_lo: float = maxf(old_lo, view.position.x)
		var reachable_hi: float = minf(old_hi, view.end.x)
		old_off_screen = int(round(100.0 * (1.0 - (reachable_hi - reachable_lo) / old_span)))
		_check("%s: the authored spawn band no longer matches the visible width" % gname,
			absf(old_lo - view.position.x) > 100.0 or absf(old_hi - view.end.x) > 100.0,
			"old band [%.0f, %.0f] vs visible [%.0f, %.0f]; %d%% of it was off-screen"
				% [old_lo, old_hi, view.position.x, view.end.x, old_off_screen])

	# -- the miss line: at the visible bottom, not at an authored y --
	_free_falling()
	await get_tree().process_frame
	var counter: String = String(spec["missed"])
	game.set(counter, 0)
	var meta_type: String = String(spec["meta_type"])
	var high := _park(view.end.y - 40.0, meta_type)
	await _frames(3)
	_check("%s: an object still on screen is not counted as missed" % gname,
		is_instance_valid(high) and int(game.get(counter)) == 0,
		"alive=%s %s=%s" % [str(is_instance_valid(high)), counter, str(game.get(counter))])
	var low := _park(game.playfield_exit_y() + 20.0, meta_type)
	await _frames(3)
	_check("%s: an object that has left the screen is counted exactly once" % gname,
		not is_instance_valid(low) and int(game.get(counter)) == 1,
		"freed=%s %s=%s" % [str(not is_instance_valid(low)), counter, str(game.get(counter))])
	var old_miss: float = float(spec["old_miss"])
	if old_miss > 0.0:
		_check("%s: the old miss line sat above the visible bottom on this camera" % gname,
			view.end.y > old_miss,
			"y > %.0f fired %.0f px before the drop left the screen" % [old_miss, view.end.y - old_miss])

	# -- a resize re-seats without teleporting what the player is holding --
	game.set("game_active", false)
	_free_falling()
	if not String(spec["catchers"]).is_empty() and not catchers.is_empty():
		var held := catchers[0] as Node2D
		var steered_x: float = view.get_center().x + 150.0
		held.position.x = steered_x
		var old_size: Vector2i = get_window().size
		get_window().size = Vector2i(1080, 1920)
		await _frames(5)
		var view2: Rect2 = _view()
		if absf(view2.size.x - view.size.x) < 1.0 and absf(view2.size.y - view.size.y) < 1.0:
			_check("[!] %s: the viewport did not resize in this build, so rotation is unmeasured" % gname,
				false, "size still %s" % str(view2.size))
		else:
			_check("%s: a resize re-seats catchers on the new visible bottom" % gname,
				absf(held.position.y - (view2.end.y - margin_bottom)) < 1.0,
				"y=%.1f new visible bottom %.1f" % [held.position.y, view2.end.y])
			_check("%s: a resize does not teleport a catcher the player dragged" % gname,
				absf(held.position.x - steered_x) < 1.0,
				"x stayed %.1f (slot would be elsewhere)" % held.position.x)
		get_window().size = old_size
		await _frames(3)
	await _close()


## MP_FilterWater is the P2 half of the shipping rain/aquarium sets and the worst case of the
## defect class: its dirt is the only thing that drains the water queue P1 keeps filling, so dirt
## the player cannot reach is not a cosmetic problem — the round stops being winnable.
func _filter_water() -> void:
	var gname: String = "MP_FilterWater"
	print("  ── %s" % gname)
	if not await _open("res://scenes/multiplayer/MP_FilterWater.tscn", "aquarium"):
		_check("[!] %s never finished building, so nothing further can be measured" % gname, false)
		await _close()
		return

	var view: Rect2 = _view()
	var margin: float = float(game.DIRT_MARGIN)
	var margin_bottom: float = float(game.DIRT_MARGIN_BOTTOM)
	var aquarium := game.get("aquarium") as Node2D
	_check("%s: the aquarium is centred in the visible rect, above its bottom edge" % gname,
		aquarium != null and absf(aquarium.position.x - view.get_center().x) < 1.0
			and absf(aquarium.position.y - (view.end.y - 170.0)) < 1.0,
		"aquarium=%s expected %s"
			% [str(aquarium.position) if aquarium else "null",
			str(Vector2(view.get_center().x, view.end.y - 170.0))])

	# -- dirt spawns where the player can see and reach it --
	game._spawn_dirt_particles(30)
	await get_tree().process_frame
	var dirt: Array = game.get("dirt_particles") as Array
	var outside: int = 0
	var behind_glass: int = 0
	for d in dirt:
		var n := d as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n.position.x < view.position.x + margin - 1.0 or n.position.x > view.end.x - margin + 1.0 \
				or n.position.y < view.position.y + margin - 1.0 \
				or n.position.y > view.end.y - margin_bottom + 1.0:
			outside += 1
		if n.position.y > view.end.y - 250.0:
			behind_glass += 1
	_check("%s: all 30 dirt particles spawn inside the visible rect" % gname,
		dirt.size() == 30 and outside == 0,
		"%d particles, %d outside x[%.0f, %.0f] y[%.0f, %.0f]"
			% [dirt.size(), outside, view.position.x + margin, view.end.x - margin,
			view.position.y + margin, view.end.y - margin_bottom])
	_check("%s: none of them spawn in the strip the aquarium occupies" % gname,
		behind_glass == 0, "%d of %d inside the bottom 250 px" % [behind_glass, dirt.size()])
	_check("%s: the old spawn box reached below the visible bottom on this camera" % gname,
		get_viewport().get_visible_rect().size.y - 100.0 > view.end.y,
		"old max y=%.0f vs visible bottom %.0f (%.0f px of unreachable dirt)"
			% [get_viewport().get_visible_rect().size.y - 100.0, view.end.y,
			get_viewport().get_visible_rect().size.y - 100.0 - view.end.y])

	# -- the bounce walls stand at the visible edges --
	# Parked against each wall with an outward velocity, so the turn happens on a known frame
	# instead of whenever a drifting particle reached an edge.
	game.set("game_active", true)
	var probes: Array = [
		{"pos": Vector2(view.end.x - 55.0, view.get_center().y), "vel": Vector2(150.0, 0.0), "edge": "right"},
		{"pos": Vector2(view.position.x + 55.0, view.get_center().y), "vel": Vector2(-150.0, 0.0), "edge": "left"},
		{"pos": Vector2(view.get_center().x, view.position.y + 55.0), "vel": Vector2(0.0, -150.0), "edge": "top"},
		{"pos": Vector2(view.get_center().x, view.end.y - 55.0), "vel": Vector2(0.0, 150.0), "edge": "bottom"},
	]
	for probe in (probes as Array):
		var p := probe as Dictionary
		var particle := dirt[0] as Node2D
		particle.position = p["pos"]
		particle.set_meta("velocity", p["vel"])
		await _frames(6)
		var vel: Vector2 = particle.get_meta("velocity")
		var turned: bool = vel.dot(p["vel"] as Vector2) < 0.0
		var inside: bool = view.grow(-40.0).has_point(particle.position)
		_check("%s: a particle drifting into the %s edge turns back and stays in frame"
				% [gname, String(p["edge"])],
			turned and inside,
			"velocity %s -> %s, position %s inside %s"
				% [str(p["vel"]), str(vel), str(particle.position), str(view)])

	# -- and nothing escapes over a longer run --
	for d in dirt:
		var n := d as Node2D
		if n != null and is_instance_valid(n):
			n.set_meta("velocity", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 150.0)
	await _frames(240)
	var escaped: int = 0
	for d in dirt:
		var n := d as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if not view.grow(20.0).has_point(n.position):
			escaped += 1
	_check("%s: after 240 frames of drift every particle is still in frame" % gname,
		escaped == 0, "%d of %d outside %s" % [escaped, dirt.size(), str(view)])

	# The base's shared gradient background. It used to be a Control parented straight to the
	# Node2D root with PRESET_FULL_RECT, which resolves against Node2D's zero-size anchorable
	# rect: it measured 0x0 here and every multiplayer round drew on the grey clear colour.
	# It now lives under a CanvasLayer, so its anchor parent is the viewport and it must cover
	# the whole window. Asserted on the window rect, not the playfield: a CanvasLayer Control
	# is screen space by construction, which is the point of moving it there.
	var bg := game.find_child("Background", true, false) as Control
	var screen := get_viewport().get_visible_rect()
	_check("%s: the shared gradient background exists and is not 0x0" % gname,
		bg != null and bg.size.x > 1.0 and bg.size.y > 1.0,
		"size=%s" % [str(bg.size) if bg != null else "<missing>"])
	if bg != null:
		_check("%s: the background covers the whole window" % gname,
			bg.global_position.is_equal_approx(screen.position) and bg.size.is_equal_approx(screen.size),
			"bg pos=%s size=%s vs window %s" % [str(bg.global_position), str(bg.size), str(screen)])
		_check("%s: the background sits in a layer behind the gameplay" % gname,
			bg.get_parent() is CanvasLayer and (bg.get_parent() as CanvasLayer).layer < 0,
			"parent=%s layer=%d" % [bg.get_parent().get_class(),
				(bg.get_parent() as CanvasLayer).layer if bg.get_parent() is CanvasLayer else 0])
		_check("%s: it has a texture to draw, so it is not an invisible node" % gname,
			bg is TextureRect and (bg as TextureRect).texture != null,
			"texture=%s" % [str((bg as TextureRect).texture) if bg is TextureRect else "<not a TextureRect>"])
	await _close()


## MP_MopFloor is one of the six games that place STATIC targets from authored constants
## instead of reading the viewport, so nothing here was off-screen - but the tiles are the
## only clickable objects in the round, so "all 20 are inside the visible rect" is worth
## holding. This section also guards the cleanup that removed a textureless TextureRect
## from every tile: TextureRect draws nothing while texture == null, so those 20 nodes were
## invisible by construction and only cost tree walk and layout on the low-end target.
func _mop_floor() -> void:
	var gname: String = "MP_MopFloor"
	print("  ── %s" % gname)
	if not await _open("res://scenes/multiplayer/MP_MopFloor.tscn", "floor_tiles"):
		_check("%s: the scene comes up and builds its floor" % gname, false, "floor_tiles empty after 8s")
		return
	game.set("game_active", true)
	await _frames(2)

	var tiles: Array = game.get("floor_tiles") as Array
	_check("%s: the floor is the full 4x5 grid" % gname, tiles.size() == 20,
		"%d tiles" % tiles.size())

	var view := _view()
	var missing_visual: int = 0
	var outside: int = 0
	var dead_rects: int = 0
	for t in tiles:
		var tile := t as Node2D
		if tile == null or not is_instance_valid(tile):
			continue
		var visual := tile.get_node_or_null("Visual") as ColorRect
		if visual == null or visual.size.x < 1.0 or visual.size.y < 1.0:
			missing_visual += 1
		else:
			var world := Rect2(tile.position + visual.position, visual.size)
			if not (view.has_point(world.position) and view.has_point(world.end)):
				outside += 1
		for c in tile.find_children("*", "TextureRect", true, false):
			if (c as TextureRect).texture == null:
				dead_rects += 1

	_check("%s: every tile has the ColorRect that actually draws it" % gname,
		missing_visual == 0, "%d of %d tiles without a sized Visual" % [missing_visual, tiles.size()])
	_check("%s: every tile is fully inside the visible rect, so all 20 are clickable" % gname,
		outside == 0, "%d of %d outside %s" % [outside, tiles.size(), str(view)])
	_check("%s: no textureless TextureRect is left on the tiles" % gname,
		dead_rects == 0, "%d invisible TextureRects found" % dead_rects)
	await _close()
