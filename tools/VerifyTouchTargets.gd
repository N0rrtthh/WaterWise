extends Node

## Are the things a finger has to hit big enough to hit?
##
## tools/AuditMobileUI.gd already answers this for the six MENU scenes. It never looks at a
## minigame, and the minigames are where the touching happens: 80 BaseButton.new() sites across
## 25 scripts, plus Area2D hit shapes that no Control-based adaptation can reach at all.
##
## WHY THIS MEASURES ON ONE PROFILE AND STILL COVERS SEVEN
##
## A target comes in one of two kinds, and the binding profile is the same for both:
##
##   BaseButton  MobileUIManager._on_node_added() grows every button's custom_minimum_size to
##               _dp_to_canvas_units(48) as it enters the tree, so its canvas size DEPENDS on the
##               profile - it is largest where the floor is largest.
##   Area2D      nothing grows a collision shape. Its canvas size is whatever the script authored,
##               constant across profiles, so it is worst where the floor is highest.
##
## The floor is highest on the smallest, densest screen - WVGA 4.5in, 217.7dpi, 854/1920 stretch,
## which puts 48dp at 147 canvas units against 75 on the 9.7in tablet. Both kinds are therefore
## hardest there, so a game that passes on WVGA passes on all seven, and measuring once instead of
## seven times keeps this harness inside a single Bash call.
##
## The floors themselves are read from the PRODUCTION conversion, not recomputed here: dpi comes
## from AuditMobileUI._dpi() and units come from MobileUIManager._dp_to_canvas_units(). A harness
## that did its own arithmetic would be free to disagree with the code that ships.
const SP_DIR := "res://scenes/minigames"
const MP_DIR := "res://scenes/multiplayer"

## RainwaterHarvesting calls change_scene_to_file() in _ready(), which tears the tree out from
## under the harness - the same exclusion tools/VerifyFairness.gd carries, for the same reason.
const SKIP: Array[String] = ["RainwaterHarvesting"]

## Frames to let a game build itself. _ready() spawns the layout and _on_game_start() spawns the
## interactive objects, and several games do both after an await.
const SETTLE_FRAMES: int = 6

## How long to watch one round, and how often to read it. Long enough for the spawners: the
## slowest SP spawn interval at Hard is under 1.5s, and the MP base runs a 3s countdown before
## its round starts at all.
const SP_WINDOW_SEC: float = 3.2
const MP_WINDOW_SEC: float = 5.5
const SAMPLE_SEC: float = 0.1

## Grace after the sampling window for spawn animations that were still running when it closed.
## The longest is CloudCatcher's 0.4s condense.
const SETTLE_TAIL_SEC: float = 0.6

## A lone host satisfies NetworkManager.connection_active, which is the only thing
## MultiplayerMiniGameBase._ready() gates on. Without it every MP round push_errors and calls
## GameManager.return_to_multiplayer_lobby(), which changes the scene - and since this harness IS
## the current scene, that frees the harness mid-run. The first attempt died exactly that way.
const MP_PORT: int = 28051
	
var _pass: int = 0
var _fail: int = 0
var _floors: Array = []
var _worst: Dictionary = {}
	
func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	
	
## THE WINDOW WILL NOT RESIZE, SO THE PROFILE IS INJECTED INSTEAD
##
## tools/AuditMobileUI.gd emulates a device with DisplayServer.window_set_size(), and in this
## environment that call does nothing at all: project.godot sets window/size/mode=3 (fullscreen),
## and probing it directly (windowed and headless, three frames after each call, mode forced to
## WINDOW_MODE_WINDOWED first) the window stayed 1920x1080 for every requested size, and headless
## reports (0, 0) forever. So MobileUIManager._stretch_ratio() reads back 1.0 no matter which
## profile the loop believes it is on.
##
## Rather than fight it, the profile enters through the one override the production code already
## provides for tests. The shipping conversion is
##
##   units = ceil(dp * (dpi / 160) / ratio)
##
## and with ratio pinned at 1.0 by the readback, setting debug_dpi_override to dpi / ratio makes
## MobileUIManager._dp_to_canvas_units() compute exactly the profile's real floor - same function,
## same ceiling, same out-of-range clamps. Nothing here re-implements the formula.
##
## ratio is the one quantity that cannot be read back, so it is derived: stretch mode
## canvas_items with aspect expand scales by the axis that runs out first, min(w/1920, h/1080),
## and lets the other axis grow the canvas. The derivation is checked against the single profile
## this environment can actually realize - FHD 6.0in, where window equals canvas and both the
## formula and the live readback must say 1.0.
func _measure_floors(mui: Node) -> void:
	var audit := load("res://tools/AuditMobileUI.gd") as GDScript
	var devices: Array = audit.get_script_constant_map().get("DEVICES", [])
	var helper: Node = audit.new()
	var base_w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	var base_h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var live_ratio: float = float(mui.call("_stretch_ratio"))
	_check(is_equal_approx(live_ratio, 1.0),
		"live stretch ratio is 1.0, so dpi/ratio injection is exact",
		"read %.4f" % live_ratio)
	var min_dp: float = float((mui.get_script() as GDScript) \
		.get_script_constant_map().get("MIN_TOUCH_TARGET_DP", 48.0))
	for d in devices:
		var dpi: float = float(helper.call("_dpi", d))
		var ratio: float = minf(float(d["w"]) / base_w, float(d["h"]) / base_h)
		mui.set("debug_dpi_override", dpi / ratio)
		if mui.has_method("invalidate_button_min_size_cache"):
			mui.call("invalidate_button_min_size_cache")
		var units: float = float(mui.call("_dp_to_canvas_units", min_dp))
		_floors.append({
			"name": str(d["name"]), "dpi": dpi, "ratio": ratio, "units": units,
			"w": int(d["w"]), "h": int(d["h"]),
		})
	helper.free()
	
	
func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
	
## Every target a finger could actually hit, with its smallest on-screen dimension in canvas
## units. Both kinds are collected in one walk: a Control target and an Area2D target are
## indistinguishable to the player, and a game can mix them (FixLeak does).
##
## HUD CHROME IS MARKED, NOT DROPPED
##
## Every game has a pause button, and MobileUIManager grows it to the floor like any other
## Control - so a game whose playfield targets never spawned still reports one passing target and
## looks fine. Neither pause button sets .name (MiniGameBase.gd:1277, 50x50; and
## MultiplayerMiniGameBase.gd:477), so they cannot be filtered by name; what separates them is
## that HUD lives under a CanvasLayer and playfield objects do not. The flag rides along on each
## target and the verdict below requires evidence of a PLAYFIELD target, so a pause-button-only
## pass is not possible.
func _collect(node: Node, out: Array, hud: bool = false) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		# Disabled or input-ignoring controls are not targets, and counting them would pad the
		# failure list with things no player can press.
		if b.is_visible_in_tree() and not b.disabled \
			and b.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var sc: Vector2 = b.get_global_transform().get_scale().abs()
			var s: Vector2 = b.size * sc
			out.append({"kind": "Button", "name": String(b.name), "min": minf(s.x, s.y), "hud": hud})
	elif node is TouchScreenButton:
		var t := node as TouchScreenButton
		if t.is_visible_in_tree() and t.texture_normal != null:
			var sc2: Vector2 = t.get_global_transform().get_scale().abs()
			var s2: Vector2 = Vector2(t.texture_normal.get_size()) * sc2
			out.append({"kind": "TouchBtn", "name": String(t.name), "min": minf(s2.x, s2.y), "hud": hud})
	elif node is Area2D:
		var a := node as Area2D
		# input_pickable defaults to TRUE on every Area2D, so collision-only bodies - falling
		# droplets, obstacles, the water a bucket catches - are indistinguishable from tap
		# targets by that flag alone. Requiring a connected input_event is what separates
		# them: an Area2D nobody listens to cannot be tapped. Without this the sweep reported
		# MP_CatchTheRain at 30 units and MP_CatchRainAquarium at 40, which were the droplets.
		if a.input_pickable and a.is_visible_in_tree() \
			and a.get_signal_connection_list("input_event").size() > 0:
			for c in a.get_children():
				if c is CollisionShape2D:
					var dim: float = _shape_min(c as CollisionShape2D)
					if dim > 0.0:
						out.append({"kind": "Area2D", "name": String(a.name), "min": dim, "hud": hud})
	for ch in node.get_children():
		_collect(ch, out, hud or node is CanvasLayer)
	
	
## The smallest across-dimension of a collision shape, in canvas units, scale included.
## Only the shapes this project actually uses; anything else returns -1 rather than a guess.
func _shape_min(cs: CollisionShape2D) -> float:
	var sh := cs.shape
	if sh == null or not cs.is_visible_in_tree():
		return -1.0
	var sc: Vector2 = cs.get_global_transform().get_scale().abs()
	var iso: float = minf(sc.x, sc.y)
	if sh is CircleShape2D:
		return (sh as CircleShape2D).radius * 2.0 * iso
	if sh is RectangleShape2D:
		var rs: Vector2 = (sh as RectangleShape2D).size * sc
		return minf(rs.x, rs.y)
	if sh is CapsuleShape2D:
		return (sh as CapsuleShape2D).radius * 2.0 * iso
	return -1.0
	
## POINTER HIT TESTS THE NODE WALK CANNOT SEE
##
## The dominant interaction model in the single-player set is not a Button and not an Area2D - it
## is a literal radius or Rect2 compared against the pointer inside _input(). Nothing in the scene
## tree carries that number, so the runtime walk above reports those games as having exactly one
## target (the HUD pause button) and would pass them vacuously.
##
## Each entry names a real site. The harness re-reads the source at run time and FAILS the entry
## if the needle is gone, so a refactor that renames or deletes a hit test is reported instead of
## silently dropping the target from the sweep.
##
##   k = "radius"  the number is a distance threshold; the target measures 2 x radius
##   k = "rect"    the last Vector2 on the line is the box size; the target is its smaller side
##   k = "vec2"    the token is a Vector2 half-extent constant; the target is 2 x its smaller axis
##
## A bare number is read literally. An identifier is resolved through the script's own constant
## map, so the number this harness checks is the number the game runs.
const HIT: Array = [
	{"g": "CoverTheDrum", "s": "res://scenes/minigames/CoverTheDrum.gd", "w": "drum tap",
		"k": "radius", "n": "tap_pos.distance_to(drum.position) <"},
	{"g": "ScrubToSave", "s": "res://scenes/minigames/ScrubToSave.gd", "w": "dish scrub",
		"k": "radius", "n": "mouse_pos.distance_to(current_dish.position) <"},
	{"g": "ThirstyPlant", "s": "res://scenes/minigames/ThirstyPlant.gd", "w": "bucket pick-up",
		"k": "radius", "n": "tap_pos.distance_to(bucket.position) <"},
	{"g": "TracePipePath", "s": "res://scenes/minigames/TracePipePath.gd", "w": "path start",
		"k": "radius", "n": "mouse_pos.distance_to(target_path[0]) <"},
	{"g": "TurnOffTap", "s": "res://scenes/minigames/TurnOffTap.gd", "w": "tap fixture",
		"k": "radius", "n": "if distance <"},
	{"g": "VegetableBath", "s": "res://scenes/minigames/VegetableBath.gd", "w": "veggie grab",
		"k": "radius", "n": "if d <"},
	{"g": "PlugTheLeak", "s": "res://scenes/minigames/PlugTheLeak.gd", "w": "pipe hold",
		"k": "rect", "n": "var pipe_rect = Rect2(pipe.position -"},
	{"g": "FilterBuilder", "s": "res://scenes/minigames/FilterBuilder.gd", "w": "layer grab",
		"k": "vec2", "n": "var cand_rect := Rect2(candidate.position -"},
	{"g": "FixLeak", "s": "res://scripts/minigames_v2/FixLeakV2.gd", "w": "leak tap",
		"k": "radius", "n": "hit_test(pos, leak.position,"},
	{"g": "BucketBrigade", "s": "res://scripts/minigames_v2/BucketBrigadeV2.gd", "w": "person tap",
		"k": "radius", "n": "hit_test(tap_pos, (people[i] as Node2D).position,"},
	{"g": "GreywaterSorter", "s": "res://scripts/minigames_v2/GreywaterSorterV2.gd",
		"w": "bucket grab", "k": "radius", "n": "hit_test(pos, b.position,"},
]

## GAMES WHOSE TARGET IS THE WHOLE SCREEN
##
## A swipe-anywhere or hold-anywhere game has no target to measure and needs none: the hit area
## is the viewport, which is 1920x1080 canvas units and clears every floor by two orders of
## magnitude. They still have to be DECLARED, because "this game has no small targets" and "this
## harness could not find this game's targets" look identical from the outside, and the second is
## the failure mode a sweep like this exists to catch.
##
## Each entry names the line that makes the input whole-screen - a touch handler that reads
## event.pressed or a drag that snaps to event.position, with no position test anywhere in it. If
## that line goes away the entry fails, so a game that later grows a small tap target cannot keep
## coasting on a gesture declaration it no longer earns.
const GESTURE: Array = [
	{"g": "SpotTheSpeck", "s": "res://scenes/minigames/SpotTheSpeck.gd", "w": "swipe up/down anywhere",
		"n": "if direction.length() > 60 and abs(direction.y) > abs(direction.x):"},
	{"g": "MudPieMaker", "s": "res://scenes/minigames/MudPieMaker.gd", "w": "hold anywhere to pour",
		"n": "pouring = event.pressed"},
	{"g": "QuickShower", "s": "res://scenes/minigames/QuickShower.gd", "w": "tap anywhere to stop",
		"n": "elif event is InputEventScreenTouch and event.pressed:"},
	{"g": "WringItOut", "s": "res://scenes/minigames/WringItOut.gd", "w": "tap anywhere to wring",
		"n": "tap_requested = true"},
	{"g": "TimingTap", "s": "res://scenes/minigames/TimingTap.gd", "w": "hold anywhere to fill",
		"n": "_touch_holding = event.pressed"},
	{"g": "DropletDash", "s": "res://scenes/minigames/DropletDash.gd", "w": "swipe anywhere to dodge",
		"n": "if absf(diff.x) > SWIPE_THRESHOLD:"},
	{"g": "SwipeTheSoap", "s": "res://scenes/minigames/SwipeTheSoap.gd", "w": "swipe anywhere",
		"n": "if swipe_delta.length() > 50:"},
	{"g": "RiceWashRescue", "s": "res://scenes/minigames/RiceWashRescue.gd",
		"w": "basin tracks the finger", "n": "target_x = TouchInputManager.get_touch_position(0).x"},
	{"g": "ToiletTankFix", "s": "res://scenes/minigames/ToiletTankFix.gd", "w": "hold anywhere to fill",
		"n": "is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)"},
	{"g": "CatchTheRain", "s": "res://scripts/minigames_v2/CatchTheRainV2.gd",
		"w": "drag anywhere moves the drum", "n": "func _shell_drag(pos: Vector2) -> void:"},
	{"g": "MP_CatchTheRain", "s": "res://scripts/multiplayer/MP_CatchTheRain.gd",
		"w": "bucket eases to the finger", "n": "func _note_pointer(screen_pos: Vector2) -> void:"},
	{"g": "MP_CatchRainAquarium", "s": "res://scripts/multiplayer/MP_CatchRainAquarium.gd",
		"w": "bucket eases to the finger", "n": "func _note_pointer(screen_pos: Vector2) -> void:"},
]

var _src: Dictionary = {}
	
## One script's text, split into lines, read once.
func _source(path: String) -> PackedStringArray:
	if _src.has(path):
		return _src[path]
	var lines := PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		lines = f.get_as_text().split("\n")
		f.close()
	_src[path] = lines
	return lines
	
	
## The first line containing needle, or "" if the needle is gone.
func _needle_line(path: String, needle: String) -> String:
	for l in _source(path):
		if l.contains(needle):
			return l
	return ""
	
	
## The token immediately after needle, stripped of the punctuation GDScript leaves on it -
## "TAP_RADIUS):" and "100:" both come back as the bare token.
func _token_after(line: String, needle: String) -> String:
	var at := line.find(needle)
	if at < 0:
		return ""
	var rest := line.substr(at + needle.length()).strip_edges()
	if rest.is_empty():
		return ""
	var tok: String = rest.split(" ")[0]
	while tok.length() > 0 and ")],:;".contains(tok.right(1)):
		tok = tok.left(tok.length() - 1)
	return tok
	
	
## A number the game actually runs: a literal, or one of the script's own constants.
##
## Object.get() cannot see a script constant and neither can a plain property read, so the
## resolution goes through get_script_constant_map() - the same table the compiler built. NAN
## comes back when the token is neither, and every caller turns that into a failure rather than
## a pass: a number this harness cannot resolve is a number it is not checking.
func _const_number(script_path: String, tok: String) -> float:
	if tok.is_valid_float():
		return tok.to_float()
	var gs := load(script_path) as GDScript
	if gs == null:
		return NAN
	var v: Variant = gs.get_script_constant_map().get(tok, null)
	if v is float or v is int:
		return float(v)
	return NAN
	
	
## A Vector2 constant of the script, or ZERO if the token is not one.
func _const_vec2(script_path: String, tok: String) -> Vector2:
	var gs := load(script_path) as GDScript
	if gs == null:
		return Vector2.ZERO
	var v: Variant = gs.get_script_constant_map().get(tok, null)
	return v if v is Vector2 else Vector2.ZERO
	
	
## The last Vector2(x, y) literal on a line - the size argument of
## Rect2(pipe.position - Vector2(75, 75), Vector2(150, 150)).
func _last_vector2(line: String) -> Vector2:
	var at := line.rfind("Vector2(")
	if at < 0:
		return Vector2.ZERO
	var open := at + 8
	var close := line.find(")", open)
	if close < 0:
		return Vector2.ZERO
	var parts := line.substr(open, close - open).split(",")
	if parts.size() < 2:
		return Vector2.ZERO
	return Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())
	
	
## The across-size in canvas units of one pointer hit test, read from source.
## -1 means the needle is gone or the number would not resolve, and the caller FAILS on it.
func _static_size(e: Dictionary) -> float:
	var path := String(e["s"])
	var line := _needle_line(path, String(e["n"]))
	if line.is_empty():
		return -1.0
	match String(e["k"]):
		"radius":
			var r := _const_number(path, _token_after(line, String(e["n"])))
			return -1.0 if is_nan(r) else r * 2.0
		"rect":
			var sz := _last_vector2(line)
			return -1.0 if sz == Vector2.ZERO else minf(sz.x, sz.y)
		"vec2":
			var h := _const_vec2(path, _token_after(line, String(e["n"])))
			return -1.0 if h == Vector2.ZERO else minf(h.x, h.y) * 2.0
	return -1.0

## Scene names, from the directories rather than a hand-kept list - a fourth parallel family
## list is a defect this audit is already carrying, not one to add to.
func _list(dir_path: String, prefix: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension() not in ["tscn", "scn", "remap"]:
			continue
		var base := f.get_basename()
		if base.get_extension() != "":
			base = base.get_basename()
		if base in SKIP or out.has(base):
			continue
		if prefix != "" and not base.begins_with(prefix):
			continue
		out.append(base)
	out.sort()
	return out
	
	
## Instantiates one game at Hard, lets it build, and returns its targets.
## Runs one game at Hard and returns, per target, the largest across-dimension it ever settled
## at, keyed "kind|name".
##
## WHY A SAMPLING WINDOW AND NOT A SNAPSHOT
##
## The first version of this took one reading six frames after start_game(), and every game
## reported exactly one target: the pause button. Six frames is 0.1s, and almost nothing a finger
## aims at exists that early - MiniGameBase._ready() blocks on the instruction overlay, spawners
## run on 0.5-2s timers, and the MP base runs a countdown before its round. So the window here is
## seconds long and samples repeatedly.
##
## WHY THE MAXIMUM PER TARGET, NOT THE MINIMUM
##
## Spawn animations start at or near zero scale and overshoot into place - that polish is
## deliberate and this audit added some of it. Sampling the minimum would fail a 160-unit button
## for the two frames it spent at scale 0.2, which is not a target the player is trying to hit
## yet. The settled size is what gets aimed at, so each target keeps its peak and the game is
## judged on the smallest peak among its targets.
func _probe(dir_path: String, scene_name: String, is_mp: bool) -> Dictionary:
	var out: Dictionary = {}
	var path := "%s/%s.tscn" % [dir_path, scene_name]
	if not ResourceLoader.exists(path):
		return out
	if AdaptiveDifficulty:
		# Hard is the crowded tier: more objects in the same frame is where a game is most
		# tempted to shrink them. Forced the way the algorithm forces it, before instantiate,
		# because _ready() applies the tier.
		AdaptiveDifficulty.current_difficulty = "Hard"
		AdaptiveDifficulty.progressive_level = 0
	var packed := load(path) as PackedScene
	if packed == null:
		return out
	var game: Node = packed.instantiate()
	# Parented to the root rather than to this node, matching the other MP harnesses: a game that
	# walks up looking for the scene root finds a plausible one.
	get_tree().root.add_child(game)
	await _frames(SETTLE_FRAMES)
	# Past the tap-to-start prompt. The SP base sits in _wait_for_input() and the MP base waits on
	# its instruction overlay; both expose the dismissal the tap would have triggered, and using it
	# means the round starts the way a player starts it.
	if is_mp:
		if game.has_method("_on_instruction_dismissed"):
			game.call("_on_instruction_dismissed")
		# AND THEN START THE ROUND, RATHER THAN WAITING OUT THE HANDSHAKE
		#
		# Dismissing the overlay only makes this peer ready. With no partner to answer, the round
		# begins on MultiplayerMiniGameBase's host fallback - await create_timer(6.0), then
		# start_countdown(), then three more seconds of countdown - so nothing a subclass spawns in
		# _on_game_start() exists until roughly nine seconds in. The 5.5s window measured everything
		# built in _on_multiplayer_ready() and none of the per-round spawns, which is why
		# MP_FilterWater's dirt and MP_WashVegetables' vegetables reported as no playfield target at
		# all. start_game() is the very call the countdown ends in, and it guards itself on
		# game_active, so calling it here starts the round the way the countdown starts it.
		if game.has_method("start_game") and not bool(game.get("game_active")):
			game.call("start_game")
	else:
		if game.has_method("_hide_instruction_overlay"):
			game.call("_hide_instruction_overlay")
		if game.has_method("start_game") and not bool(game.get("game_active")):
			game.call("start_game")
	
	var window: float = MP_WINDOW_SEC if is_mp else SP_WINDOW_SEC
	var waited: float = 0.0
	while waited < window:
		var seen: Array = []
		_collect(game, seen)
		for t in seen:
			var key: String = "%s|%s" % [t["kind"], t["name"]]
			if not out.has(key) or float(t["min"]) > float(out[key]["min"]):
				out[key] = t
		await get_tree().create_timer(SAMPLE_SEC).timeout
		waited += SAMPLE_SEC

	# One more reading after the spawners have had SETTLE_TAIL_SEC to finish what was in flight
	# when the window closed. A target that spawns in the last tenth of a second is caught
	# mid-animation - CloudCatcher's cloud condenses from scale 0.6 over 0.4s, so the sweep
	# reported it at 110 units instead of its settled 147 purely because of when the clock
	# stopped. Waiting past the longest spawn animation and re-reading measures the size the
	# player actually aims at, without letting a genuinely small target off.
	await get_tree().create_timer(SETTLE_TAIL_SEC).timeout
	var tail: Array = []
	_collect(game, tail)
	for t in tail:
		var tk: String = "%s|%s" % [t["kind"], t["name"]]
		if not out.has(tk) or float(t["min"]) > float(out[tk]["min"]):
			out[tk] = t
	
	# set game_active false first: several games poll it in _process and would otherwise take one
	# more step against a half-torn-down tree.
	game.set("game_active", false)
	get_tree().root.remove_child(game)
	# One frame between the detach and the free, not after it: _wait_for_input() is parked
	# on `await get_tree().process_frame` and only releases its GDScriptFunctionState if it
	# gets that frame while the node still exists. Freeing first stranded 12 of them.
	await _frames(1)
	game.free()
	await _frames(1)
	return out
	
func _ready() -> void:
	await get_tree().process_frame
	print("\n=== VerifyTouchTargets ===")
	var mui: Node = get_node_or_null("/root/MobileUIManager")
	if mui == null:
		printerr("MobileUIManager autoload missing")
		get_tree().quit(1)
		return
	# The production floor is only enforced when MobileUIManager believes it is on a phone, and
	# the point of this harness is to exercise that path rather than a parallel one. Setting the
	# flag alone is not enough - is_mobile is recomputed in _detect_platform(), which this call
	# re-runs.
	if mui.has_method("enable_debug_mobile_mode"):
		mui.call("enable_debug_mobile_mode", true)
	await _frames(2)
	_check(bool(mui.get("is_mobile")), "MobileUIManager is in mobile mode")
	
	# Measurements are in canvas units, so the canvas has to be the shipping one. Headless brings
	# it up square (1920x1920), which would stretch every viewport-relative target vertically, so
	# this harness runs windowed - the same reason tools/VisualProbe.tscn does.
	#
	# Windowed, the window ALSO has to be asked for the shipping shape. Launching without
	# --headless lands on the desktop work area (1920x1035 here: screen minus taskbar), and
	# aspect=expand turns that into a 1975x1080 canvas - which fails the guard below and, worse,
	# would put _stretch_ratio() at something other than 1.0 and silently skew the dpi/ratio
	# injection _measure_floors() depends on. tools/AuditMobileUI.gd resizes the window for each
	# of its seven profiles and gets exactly what it asks for, so the note further up about
	# window_set_size() being inert is true of the FULLSCREEN mode project.godot ships, not of a
	# windowed run: SaveManager._apply_fullscreen_setting() has already forced
	# WINDOW_MODE_WINDOWED by the time this runs (saved "fullscreen": false).
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		await _frames(6)
	var base := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	var canvas: Vector2 = get_tree().root.get_visible_rect().size
	_check(canvas.is_equal_approx(base),
		"canvas is the shipping %s" % str(base), "got %s - run WITHOUT --headless" % str(canvas))
	if not canvas.is_equal_approx(base):
		print("\n=== %d passed / %d failed ===" % [_pass, _fail])
		get_tree().quit(1)
		return
	
	await _measure_floors(mui)
	if _floors.is_empty():
		printerr("no device profiles read from AuditMobileUI")
		get_tree().quit(1)
		return
	print("  48dp floor by profile, in canvas units:")
	for f in _floors:
		print("    %-16s %6.1f dpi  ratio %.4f -> %5.0f units" % [
			f["name"], f["dpi"], f["ratio"], f["units"]])
	
	# Measure on the profile with the highest floor. It is the binding case for both kinds of
	# target: a BaseButton is grown by _on_node_added() in proportion to the floor, so it is
	# largest exactly where the floor is largest, and an Area2D collision shape is never grown at
	# all, so its fixed canvas size is worst where the floor is highest. A game that clears the
	# highest floor clears all seven.
	var worst_floor: Dictionary = _floors[0]
	for f in _floors:
		if float(f["units"]) > float(worst_floor["units"]):
			worst_floor = f
	var floor_units: float = float(worst_floor["units"])
	mui.set("debug_dpi_override", float(worst_floor["dpi"]) / float(worst_floor["ratio"]))
	if mui.has_method("invalidate_button_min_size_cache"):
		mui.call("invalidate_button_min_size_cache")
	await _frames(3)
	print("  measuring against %s: %.0f canvas units" % [worst_floor["name"], floor_units])
	
	var families: Array = [
		{"dir": SP_DIR, "prefix": "", "label": "SP", "mp": false},
		{"dir": MP_DIR, "prefix": "MP_", "label": "MP", "mp": true},
	]
	var rows: Array = []
	print("\n  per-game smallest settled target, streamed as measured:")
	for fam in families:
		if bool(fam["mp"]):
			# Opened once, for the whole MP family.
			var hosted: bool = GameManager != null and bool(GameManager.host_game(MP_PORT))
			_check(hosted and NetworkManager != null and bool(NetworkManager.connection_active),
				"a lone-host session is open, which is all MultiplayerMiniGameBase gates on",
				"connection_active=%s" % str(NetworkManager.connection_active if NetworkManager else "<none>"))
			await _frames(6)
		for scene_name in _list(String(fam["dir"]), String(fam["prefix"])):
			var targets: Dictionary = await _probe(
				String(fam["dir"]), scene_name, bool(fam["mp"]))
			var smallest: Dictionary = {}
			var under: Array = []
			var playfield: int = 0
			for k in targets:
				var t: Dictionary = targets[k]
				if not bool(t.get("hud", false)):
					playfield += 1
				if smallest.is_empty() or float(t["min"]) < float(smallest["min"]):
					smallest = t
				if float(t["min"]) < floor_units:
					under.append(t)
			# The hit tests the walk cannot see, read out of this game's own source.
			var statics: Array = []
			for e in HIT:
				if String(e["g"]) != scene_name:
					continue
				statics.append({"w": String(e["w"]), "min": _static_size(e), "n": String(e["n"])})
			var gest: Array = []
			for e2 in GESTURE:
				if String(e2["g"]) == scene_name:
					gest.append({"w": String(e2["w"]),
						"ok": not _needle_line(String(e2["s"]), String(e2["n"])).is_empty()})
			var row := {
				"family": String(fam["label"]), "game": scene_name, "count": targets.size(),
				"playfield": playfield, "smallest": smallest, "under": under,
				"statics": statics, "gest": gest,
			}
			rows.append(row)
			# Printed here rather than after the sweep: if a game tears the scene out from
			# under this harness, everything measured so far is already in the log.
			var extra: String = ""
			for st in statics:
				extra += "   %s %s%.0f" % [st["w"],
					"NEEDLE GONE " if float(st["min"]) < 0.0 else "", float(st["min"])]
			for gs in gest:
				extra += "   gesture:%s%s" % [
					gs["w"], "" if bool(gs["ok"]) else " NEEDLE GONE"]
			if row["count"] == 0:
				print("    %-24s  no scene-tree targets%s" % [scene_name, extra])
			else:
				print("    %-24s %2d tgt (%d field)  smallest %6.1f  %-8s %s%s%s" % [
					scene_name, int(row["count"]), playfield, float(smallest["min"]),
					smallest["kind"], smallest["name"],
					"" if under.is_empty() else "   UNDER x%d" % under.size(), extra])
	
	# Anything at or above the highest floor is above all seven.
	#
	# There are three ways a game can show it HAS a target, and it needs at least one: a playfield
	# node in the scene tree, a pointer hit test in its source, or a declared whole-screen gesture.
	# HUD chrome alone does not count - see _collect() - so a game whose playfield never spawned
	# fails here instead of riding its pause button to a pass. Every target found by any of the
	# three then has to clear the floor, and a static needle that no longer resolves reports as
	# gone rather than as passing.
	for r in rows:
		var names: Array = []
		for u in r["under"]:
			names.append("%s:%s=%.0f" % [u["kind"], u["name"], float(u["min"])])
		var static_ok: bool = true
		for s2 in r["statics"]:
			var sm: float = float(s2["min"])
			if sm < 0.0:
				static_ok = false
				names.append("hit test gone: %s (%s)" % [s2["w"], s2["n"]])
			elif sm < floor_units:
				static_ok = false
				names.append("%s=%.0f" % [s2["w"], sm])
		var gest_ok: bool = true
		for g2 in r["gest"]:
			if not bool(g2["ok"]):
				gest_ok = false
				names.append("gesture gone: %s" % g2["w"])
		var evidence: bool = int(r["playfield"]) > 0 or not r["statics"].is_empty() \
			or not r["gest"].is_empty()
		if not evidence:
			names.append("no playfield target, no hit test, no declared gesture")
		_check(evidence and r["under"].is_empty() and static_ok and gest_ok,
			"%s %s targets >= %.0f units" % [r["family"], r["game"], floor_units],
			", ".join(names))
	
	print("\n=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
