extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VisualSweepHard — one readability pass over all 37 live minigames at Hard
## ═══════════════════════════════════════════════════════════════════════════════
## Hard is the tier that stresses layout: it is where the difficulty tree emits the most
## simultaneous entities, the shortest timers, the extra HUD copy and (via chaos_effects) screen
## shake and tint overlays. Anything that only just fits at Easy stops fitting here.
##
## What is measured, per game, on a settled frame of a real round:
##   • every visible piece of text — is its box fully inside the visible rect, or is part of the
##     word off the edge of a phone screen;
##   • do two pieces of text overlap by more than a third of the smaller box (the score sitting on
##     top of the timer, a floating "+10" landing on the quota);
##   • in-rect contrast: the WCAG ratio between the lightest and darkest pixel inside each text
##     box, read out of the rendered frame. For text on a solid ground that IS the text/background
##     contrast; antialiasing pulls the extremes a few percent toward each other, so the number is
##     a slight UNDER-estimate and a pass is therefore trustworthy. 4.5:1 is the WCAG AA floor for
##     body text, 3:1 for large text (>= 24 px at this canvas scale).
##   • the smallest font actually used, in canvas units.
##
## One PNG per game is written next to the numbers so a human can look at what was measured
## rather than take the harness's word for it.
##
## Runs WINDOWED, not headless: get_viewport().get_texture() has nothing in it under the dummy
## renderer, and every contrast number here comes out of the rendered frame.
##
## Usage:
##   Godot_v4.5.1-stable_win64_console.exe --path E:\waterwise res://tools/VisualSweepHard.tscn
##   ... -- only=MP_MopFloor,FixLeak     (optional filter, substring match)

const PORT: int = 7807
const OUT_DIR: String = "res://tools/probe_frames/sweep_hard"
const LIVE_SETTLE: float = 0.9
const RETRY_SETTLE: float = 0.3
const BUILD_TIMEOUT: float = 12.0
const AA_FLOOR: float = 4.5
const LARGE_TEXT_FLOOR: float = 3.0
const LARGE_TEXT_PX: float = 24.0
## Overlap counts as a defect past a third of the smaller box — two labels sharing an edge pixel
## is a layout coincidence, one sitting on top of the other is not.
const OVERLAP_FRAC: float = 0.34
## WCAG 1.4.11 asks 3:1 of a graphic that carries meaning, and asks nothing at all of decoration.
## An opaque symbol in the HUD is the former: the pause glyph, a ✓ verdict, a ⬇ direction cue all
## have to be told apart from the art behind them, but they are not prose and the 4.5:1 body floor
## is not the right bar for them.
const ICON_FLOOR: float = 3.0

const SP_GAMES: Array = [
	"CloudCatcher", "CoverTheDrum", "DropletDash", "FilterBuilder", "MudPieMaker",
	"PlugTheLeak", "QuickShower", "RiceWashRescue", "ScrubToSave", "SpotTheSpeck",
	"SwipeTheSoap", "ThirstyPlant", "TimingTap", "ToiletTankFix", "TracePipePath",
	"TurnOffTap", "VegetableBath", "WaterMemory", "WaterPlant", "WringItOut",
	"BucketBrigade", "CatchTheRain", "FixLeak", "GreywaterSorter",
]
const MP_GAMES: Array = [
	"MP_CatchRainAquarium", "MP_CatchTheRain", "MP_CollectDishWater", "MP_CollectLaundryWater",
	"MP_CollectShowerWater", "MP_FillAquarium", "MP_FilterWater", "MP_FlushToilets",
	"MP_MopFloor", "MP_WashCar", "MP_WashVegetables", "MP_WaterPlants",
]
## The 37th scene, and the awkward one. It is co-op only: _ready() bails to the menu with
## change_scene_to_file() unless GameManager is in MULTIPLAYER_COOP with a live connection, and
## that scene change frees the harness along with the tree - which is why this sweep, tools/
## VerifyTouchTargets.gd and tools/VerifyFairness.gd all used to skip it outright. It does not
## need skipping here: this sweep already opens a lone-host session for the 12 MP scenes, and
## both of those guards pass under it, so it is probed after them instead of excluded.
##
## It is also in neither roster - not ALL_SINGLEPLAYER_MINIGAMES, not the multiplayer set - so no
## menu can launch it and no player will see these pixels today. Measured anyway: the scene, its
## script and its three cutscene beats are all authored and shipped, and a readability sweep that
## quietly covers 36 of 37 is the kind of gap this pass exists to close.
const RAINWATER: String = "RainwaterHarvesting"
const RAINWATER_NOTE: String = (
	"RainwaterHarvesting is co-op only and in no roster; probed last, under the lone-host session"
)

var rows: Array = []
var failures: Array = []
var only: String = ""
var paint: bool = false
var game: Node = null

func _ready() -> void:
	_parse_args()
	# The capture pauses the tree so an unattended round cannot end mid-settle; the harness has to
	# keep ticking through that pause to grab and score the frame.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		# Every contrast number below is read out of a rendered frame. The dummy renderer hands
		# back a blank texture, so headless would report a uniform luminance of 0 and "pass"
		# everything - a fake metric, which is worse than no metric.
		print("[SWEEP] refusing to run headless: run WINDOWED, the pixels are the measurement")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _frames(4)
	await _run()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "only":
			only = kv[1]
		if kv.size() == 2 and kv[0] == "paint":
			paint = kv[1] == "1"


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _wanted(g: String) -> bool:
	if only.is_empty():
		return true
	for want in only.split(","):
		if g.contains(want):
			return true
	return false


func _run() -> void:
	# One shape, the shipping design size, so the framebuffer scale is 1.0 and a 16px glyph is
	# sampled at 16 pixels. Batch 4 already proved these layouts hold at 2560x1080 and 1920x1440
	# by measurement; this pass is about what the pixels look like, so it wants the clean sample.
	get_window().size = Vector2i(1920, 1080)
	await _frames(4)
	print("\n[SWEEP] viewport ", _vp(), "  window ", get_window().size)
	print("[SWEEP] ", RAINWATER_NOTE)
	for g in SP_GAMES:
		if _wanted(g):
			await _probe(g, "res://scenes/minigames/%s.tscn" % g, false)
	var hosted: bool = GameManager != null and bool(GameManager.host_game(PORT))
	print("\n[SWEEP] lone-host session for the 12 MP scenes: ", hosted)
	for g in MP_GAMES:
		if _wanted(g):
			await _probe(g, "res://scenes/multiplayer/%s.tscn" % g, true)
	# The 37th scene, probed last because it needs the lone-host session above (see
	# RAINWATER_NOTE). It extends Node2D rather than MiniGameBase, so its round flag is
	# game_started, not game_active, and nothing dismisses an overlay for it: _ready() runs
	# a 3.5s countdown of its own and then flips the flag, which is inside BUILD_TIMEOUT.
	if _wanted(RAINWATER):
		await _probe(RAINWATER, "res://scenes/minigames/%s.tscn" % RAINWATER, true,
			LIVE_SETTLE, true, "game_started")
	_report()
	get_tree().quit(0 if failures.is_empty() else 1)


## Boots one game at Hard and measures the settled frame.
##
## Difficulty is re-forced immediately before every instantiate, not once at the top: the games
## read AdaptiveDifficulty from inside their own _ready(), and a round that ends mid-sweep feeds
## add_performance() and can adapt the tier out from under the next game.
func _probe(gname: String, path: String, is_mp: bool, settle: float = LIVE_SETTLE,
		retry: bool = true, live_prop: String = "game_active") -> void:
	AdaptiveDifficulty.current_difficulty = "Hard"
	AdaptiveDifficulty.progressive_level = 0
	if not ResourceLoader.exists(path):
		_fail(gname, "scene missing at " + path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail(gname, "scene would not load")
		return
	game = packed.instantiate()
	get_tree().root.add_child(game)
	await _wait(0.4)

	# MiniGameBase._ready() ends in _wait_for_input(), whose down-edge detector reads the Input
	# singleton, so only a parse_input_event tap starts a single-player round. The MP base instead
	# spends ~9s in host fallback plus countdown with no partner, so start_game() is called
	# directly - it self-guards on game_active, which is the same entry the countdown uses.
	if is_mp:
		if game.has_method("_on_instruction_dismissed"):
			game.call("_on_instruction_dismissed")
		if game.has_method("start_game") and not bool(game.get("game_active")):
			game.call("start_game")
	else:
		await _tap()

	var waited: float = 0.0
	while waited < BUILD_TIMEOUT and not bool(game.get(live_prop)):
		await _wait(0.05)
		waited += 0.05
	var live: bool = bool(game.get(live_prop))
	
	# Let the entrance animations land, then freeze the tree before grabbing. Measuring the first
	# frame of a round would read mid-tween positions and half-faded modulates - but leaving the
	# clock running for a full settle is worse: an unattended round at Hard can reach its own fail
	# state in well under two seconds, and the results overlay then covers the screen, so the
	# "settled frame" would be a frame of the outro with every label buried behind it. Pausing holds
	# the round live and the HUD on screen while stopping every gameplay timer; SceneTree timers and
	# process_frame both still fire while paused, so the harness itself keeps running.
	await _wait(settle)
	if not is_instance_valid(game):
		_fail(gname, "instance died during the round - it changed scene under the harness")
		game = null
		return
	var ended: bool = live and not bool(game.get(live_prop))
	if ended:
		# Detach and spend a frame before freeing, so the parked _wait_for_input() coroutine can return.
		get_tree().root.remove_child(game)
		await _frames(1)
		game.free()
		game = null
		await _frames(5)
		if retry:
			print("        [retry] %s ended unattended within %.2fs - re-probing with a %.2fs settle"
				% [gname, settle, RETRY_SETTLE])
			await _probe(gname, path, is_mp, RETRY_SETTLE, false, live_prop)
		else:
			_fail(gname, "round reached its own fail state %.2fs after starting, so it has no settled live frame to measure" % settle)
		return
	get_tree().paused = true
	await _frames(3)
	var img: Image = await _grab()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, gname]))
	var texts: Array = _collect(game)
	var row: Dictionary = _score(gname, texts, img, live)
	_annotate(img, texts).save_png(
		ProjectSettings.globalize_path("%s/%s_boxes.png" % [OUT_DIR, gname]))
	if paint:
		_repaint(texts)
		await _frames(4)
		var painted: Image = await _grab()
		painted.save_png(
			ProjectSettings.globalize_path("%s/%s_paint.png" % [OUT_DIR, gname]))
	rows.append(row)
	_print_row(row)
	
	get_tree().paused = false
	# Detach, let the parked coroutine notice, then free.
	#
	# The round is still blocked on the instruction overlay here, so
	# MiniGameBase._wait_for_input() is parked on `await get_tree().process_frame`. Freeing
	# the node destroys the tree connection that would have resumed it, and the orphaned
	# GDScriptFunctionState is never released - one per game instantiated, named by
	# `Orphan StringName: _wait_for_input` in a --verbose exit dump. Detaching first and
	# spending one frame lets the loop resume, see is_inside_tree() go false and return.
	get_tree().root.remove_child(game)
	await _frames(1)
	game.free()
	game = null
	await _frames(5)


func _tap() -> void:
	var win_pos: Vector2 = get_tree().root.get_final_transform() * (_vp() * 0.5)
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = win_pos
	dn.global_position = win_pos
	dn.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(dn)
	await _frames(3)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = win_pos
	up.global_position = win_pos
	up.button_mask = 0
	Input.parse_input_event(up)
	await _frames(2)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## ── TEXT DISCOVERY ────────────────────────────────────────────────────────────
## Two rectangles per piece of text.
##
## `rect` is the CONTROL's box in canvas units, and `glyph` is where the letters actually land
## inside it, derived from the same Font the label draws with. The difference matters: most HUD
## copy in this project is a full-width centred Label, so the control box spans the whole screen
## and would report "on screen, no overlap, high contrast" no matter where the words were. The
## glyph box is what the eye sees. Where the glyph box cannot be derived honestly - wrapped or
## multi-line text, or a control with no font - the control box is used instead and the row is
## counted as approximate, so it is reported and not asserted on.
func _collect(n: Node) -> Array:
	var out: Array = []
	_walk(n, out)
	return out


func _walk(n: Node, out: Array) -> void:
	for child in n.get_children():
		if child is Control:
			var c: Control = child
			if c.is_visible_in_tree():
				var t: String = _text_of(c)
				if not t.strip_edges().is_empty():
					out.append(_entry(c, t, out.size()))
		_walk(child, out)


## Copy is text a player has to read; everything else is art that happens to be built out of a
## Label. The split matters because the two are held to different bars: prose gets the WCAG text
## floors, a HUD symbol gets the non-text floor, and background decoration gets measured and
## printed but not asserted.
##
## The test is whether the string contains a letter or a digit in a writing system, which is what
## separates "3 / 5 closed" and "II" from "✦", "〰️", "❓" and "🚰". Codepoint ranges rather than
## \p{L}, so the classification is inspectable in this file and does not depend on how PCRE2 was
## compiled into the engine build.
static func _is_copy(t: String) -> bool:
	for i in range(t.length()):
		var ch: int = t.unicode_at(i)
		if (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122):
			return true  # ASCII digits and letters: en and fil are both written in these
		if ch >= 0x00C0 and ch <= 0x024F:
			return true  # Latin-1 Supplement through Latin Extended-B: ñ, á, accented vowels
		if ch >= 0x0370 and ch <= 0x04FF:
			return true  # Greek and Cyrillic
		if ch >= 0x3040 and ch <= 0x9FFF:
			return true  # kana and CJK ideographs
		if ch >= 0xAC00 and ch <= 0xD7AF:
			return true  # Hangul syllables
	return false


func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return (c as LineEdit).text
	return ""


func _font_size_of(c: Control) -> int:
	var key: String = "normal_font_size" if c is RichTextLabel else "font_size"
	var fs: int = c.get_theme_font_size(key)
	return fs if fs > 0 else 16


func _entry(c: Control, t: String, seq: int) -> Dictionary:
	var xf: Transform2D = c.get_global_transform_with_canvas()
	var sc: Vector2 = xf.get_scale()
	var full := Rect2(xf.origin, c.size * sc)
	var fs: int = _font_size_of(c)
	var glyph: Rect2 = full
	var tight: bool = false
	var wrapped: bool = c is RichTextLabel or c is LineEdit or t.contains("\n")
	if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		wrapped = true
	var f: Font = c.get_theme_font("font")
	if not wrapped and f != null:
		var ss: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var line_h: float = f.get_height(fs)
		var w: float = ss.x * sc.x
		var h: float = line_h * sc.y
		if w > 0.5 and w <= full.size.x + 1.0 and h <= full.size.y + 1.0:
			var ha: int = HORIZONTAL_ALIGNMENT_LEFT
			var va: int = VERTICAL_ALIGNMENT_TOP
			if c is Label:
				ha = int((c as Label).horizontal_alignment)
				va = int((c as Label).vertical_alignment)
			elif c is Button:
				ha = int((c as Button).alignment)
				va = VERTICAL_ALIGNMENT_CENTER
			var gx: float = full.position.x
			if ha == HORIZONTAL_ALIGNMENT_CENTER or ha == HORIZONTAL_ALIGNMENT_FILL:
				gx += (full.size.x - w) * 0.5
			elif ha == HORIZONTAL_ALIGNMENT_RIGHT:
				gx += full.size.x - w
			var gy: float = full.position.y
			if va == VERTICAL_ALIGNMENT_CENTER or va == VERTICAL_ALIGNMENT_FILL:
				gy += (full.size.y - h) * 0.5
			elif va == VERTICAL_ALIGNMENT_BOTTOM:
				gy += full.size.y - h
			glyph = Rect2(Vector2(gx, gy), Vector2(w, h))
			tight = true
	return {
		"c": c, "path": String(c.name), "text": t.substr(0, 28).replace("\n", "|"),
		"rect": full, "glyph": glyph, "fs": fs, "tight": tight,
		# A CanvasLayer between this Control and the game root means HUD: MiniGameBase's hud_layer
		# and MultiplayerMiniGameBase's _ensure_hud_layer() are both CanvasLayers, and world content
		# hangs directly off the game's Node2D, where get_canvas_layer_node() is null.
		"hud": c.get_canvas_layer_node() != null,
		# A Control can be visible_in_tree and still draw nothing, because visibility and opacity are
		# separate: modulate.a multiplies down the CanvasItem chain, so one faded ancestor hides a
		# whole HUD while every child still reports itself visible. Carrying the product here is what
		# separates "dim" from "not drawn at all", which are different bugs with different fixes.
		"alpha": _eff_alpha(c),
		# The colour the glyphs are actually drawn in, and the outline width behind them. modulate
		# alpha is not the only way to make text invisible: a font_color with a=0, or a font_color
		# equal to the backdrop, both draw nothing a player can see while every visibility flag on
		# the node still reads true.
		"fg": c.get_theme_color("font_color"),
		"outline": c.get_theme_constant("outline_size"),
		"why": _why_invisible(c),
		"layer": _layer_of(c),
		# Prose or art. See _is_copy(): it decides which contrast floor this text answers to, and
		# whether something drawn on top of it counts as a collision or as intended layering.
		"copy": _is_copy(t),
		# Where this text sits in the draw order, as the three keys the renderer itself sorts by:
		# CanvasLayer first, then accumulated z_index, then tree order. Overlap on its own says
		# nothing about readability - what matters is which of the two is on top.
		"z": _z_of(c),
		"seq": seq,
		# A disabled control is greyed on purpose. WCAG 1.4.3 and 1.4.11 both exempt the text of an
		# inactive component for that reason, and asserting a floor here would push the project to
		# make a dead button look live: FilterBuilder's undo starts disabled because nothing has
		# been placed yet, and its 3.11:1 is the disabled style doing its job.
		"disabled": c is Button and (c as Button).disabled,
	}


## ── CONTRAST ──────────────────────────────────────────────────────────────────
## WCAG relative luminance, then the WCAG ratio between the lightest and the darkest pixel found
## inside the glyph box of the captured frame. For letters drawn over a solid ground that ratio IS
## the text/background contrast; antialiasing drags both extremes inward by a few percent, so the
## figure is a slight under-estimate, which makes a PASS safe and a marginal FAIL worth a look at
## the PNG rather than an automatic edit.
func _lum(c: Color) -> float:
	var ch: PackedFloat32Array = PackedFloat32Array([c.r, c.g, c.b])
	for i in range(3):
		var v: float = ch[i]
		ch[i] = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


## Canvas units -> framebuffer pixels. The captured image is the window's render target, while
## every rect above is in the stretched canvas space, so a window that is not exactly the
## content-scale size needs the root's final transform applied or the sample lands elsewhere.
func _to_px(r: Rect2) -> Rect2:
	var xf: Transform2D = get_tree().root.get_final_transform()
	var a: Vector2 = xf * r.position
	var b: Vector2 = xf * (r.position + r.size)
	return Rect2(a, b - a)


func _contrast(img: Image, r: Rect2) -> float:
	var p: Rect2 = _to_px(r)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var x0: int = clampi(int(floor(p.position.x)), 0, w - 1)
	var y0: int = clampi(int(floor(p.position.y)), 0, h - 1)
	var x1: int = clampi(int(ceil(p.position.x + p.size.x)), x0 + 1, w)
	var y1: int = clampi(int(ceil(p.position.y + p.size.y)), y0 + 1, h)
	if (x1 - x0) * (y1 - y0) < 4:
		return -1.0
	# A stride keeps a long headline from costing a hundred thousand get_pixel() calls. Glyph
	# strokes at these sizes are several pixels wide, so every letter is still sampled; the stride
	# only ever costs a sub-pixel antialiased extreme, which pulls the ratio down, never up.
	var stride: int = maxi(1, int(sqrt(float((x1 - x0) * (y1 - y0)) / 40000.0)))
	var lo: float = 2.0
	var hi: float = -1.0
	for y in range(y0, y1, stride):
		for x in range(x0, x1, stride):
			var l: float = _lum(img.get_pixel(x, y))
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return (hi + 0.05) / (lo + 0.05)


## ── SCORING ───────────────────────────────────────────────────────────────────
func _score(gname: String, texts: Array, img: Image, live: bool) -> Dictionary:
	var vp: Vector2 = _vp()
	var bounds := Rect2(Vector2(-1.0, -1.0), vp + Vector2(2.0, 2.0))
	var off: Array = []
	var wander: Array = []
	var dim: Array = []
	var faint: Array = []
	var approx: int = 0
	var worst: float = 99.0
	var worst_of: String = "-"
	var worst_deco: float = 99.0
	var worst_deco_of: String = "-"
	var min_fs: int = 999
	for e in texts:
		var g: Rect2 = e["glyph"]
		min_fs = mini(min_fs, int(e["fs"]))
		# Off-screen is asserted for HUD copy and only reported for world content, and the split is
		# the CanvasLayer the text lives under. A HUD label that runs past the edge is always a bug:
		# it is anchored, it never moves, and a phone would simply cut the word in half. A world
		# entity crossing the edge is usually the design - CloudCatcher spawns its clouds at x=-80
		# and screen_size.x+80 and frees them 120 units past the far edge, so half its targets are
		# mid-entry on any given frame. Asserting on those would fail every spawner in the project
		# for doing exactly what it was written to do, so they are printed instead of failed.
		if not bounds.encloses(g):
			var where: String = "%s \"%s\" at %s size %s" % [
				e["path"], e["text"], g.position.round(), g.size.round()]
			if bool(e["hud"]):
				off.append(where)
			else:
				wander.append(where)
		# Contrast is measured on tight glyph boxes only, and the order matters for run time as much
		# as for honesty: a fallback box can be the whole 1920x1080 canvas, and reading two million
		# pixels through get_pixel() per label would make the sweep take longer than the rounds do.
		if not bool(e["tight"]):
			approx += 1
			continue
		var ratio: float = _contrast(img, g)
		if ratio < 0.0:
			continue
		# Which floor this text answers to, and whether it answers to one at all. Prose gets the
		# WCAG text floors. An opaque HUD symbol gets the 3:1 non-text floor. World decoration -
		# CoverTheDrum's stars at alpha 0.3, WaterMemory's waves at 0.1, DropletDash's flow marks -
		# is measured and printed but not asserted: it is background texture drawn faint on purpose,
		# and holding a deliberately faint sparkle to a prose floor would only push the project to
		# make its own atmosphere opaque. Decoration that buries copy is still caught, by _overlaps.
		var floor_needed: float = 0.0
		if bool(e["disabled"]):
			pass  # inactive component: measured below, never asserted
		elif bool(e["copy"]):
			floor_needed = LARGE_TEXT_FLOOR if float(e["fs"]) >= LARGE_TEXT_PX else AA_FLOOR
		elif bool(e["hud"]):
			floor_needed = ICON_FLOOR
		var detail: String = "%s \"%s\" %.2f:1 needs %.1f:1 at %dpx  box=%s+%s alpha=%.2f layer=%d fg=%s out=%d %s" % [
			e["path"], e["text"], ratio, floor_needed, int(e["fs"]),
			g.position.round(), g.size.round(),
			float(e["alpha"]), int(e["layer"]), str(e["fg"]), int(e["outline"]), String(e["why"])]
		if floor_needed <= 0.0:
			if ratio < worst_deco:
				worst_deco = ratio
				worst_deco_of = "%s \"%s\"" % [e["path"], e["text"]]
			if ratio < AA_FLOOR:
				var kind: String = "disabled control" if bool(e["disabled"]) else "decoration"
				faint.append(detail.replace("needs 0.0:1", kind + ", not asserted"))
			continue
		if ratio < worst:
			worst = ratio
			worst_of = "%s \"%s\"" % [e["path"], e["text"]]
		if ratio < floor_needed:
			dim.append(detail)

	var ovl_all: Dictionary = _overlaps(texts)
	var ovl: Array = ovl_all["hard"]
	var row: Dictionary = {
		"g": gname, "n": texts.size(), "live": live, "off": off, "ovl": ovl, "dim": dim,
		"wander": wander, "faint": faint, "soft_ovl": ovl_all["soft"],
		"worst": worst, "worst_of": worst_of, "min_fs": min_fs, "approx": approx,
		"worst_deco": worst_deco, "worst_deco_of": worst_deco_of,
	}
	if not live:
		_fail(gname, "round never went active within %.0fs - frame is not a live round" % BUILD_TIMEOUT)
	if texts.is_empty():
		_fail(gname, "no visible text at all on the settled frame")
	for o in off:
		_fail(gname, "text off screen: " + o)
	for o in ovl:
		_fail(gname, "text collides: " + o)
	for d in dim:
		_fail(gname, "contrast below WCAG floor: " + d)
	return row


## Two pieces of text sharing more than a third of the smaller box are stacked, not adjacent.
## Identical strings are excused: several games draw a label twice, offset a couple of units, as a
## hand-rolled drop shadow, and that is deliberate.
##
## Which of the two is a defect depends on which one is underneath. Overlap is only a bug when the
## thing being covered is something the player needs - copy, or any HUD element. Ambient art under
## a card or under the HUD is the normal case in this project: WaterMemory scatters eight waves at
## z -9 behind its grid and CoverTheDrum scatters twenty stars at z -9 behind a CanvasLayer HUD, so
## box math alone reported the star as "covering 100% of the title" when the title is drawn over it.
## Those go to soft. A label buried under something opaque still goes to hard.
func _overlaps(texts: Array) -> Dictionary:
	var out: Array = []
	var soft: Array = []
	for i in range(texts.size()):
		for j in range(i + 1, texts.size()):
			var a: Dictionary = texts[i]
			var b: Dictionary = texts[j]
			if String(a["text"]) == String(b["text"]):
				continue
			var ca: Control = a["c"]
			var cb: Control = b["c"]
			if ca.is_ancestor_of(cb) or cb.is_ancestor_of(ca):
				continue
			var ra: Rect2 = a["glyph"]
			var rb: Rect2 = b["glyph"]
			var hit: Rect2 = ra.intersection(rb)
			var area: float = hit.size.x * hit.size.y
			if area <= 0.0:
				continue
			var smaller: float = minf(ra.size.x * ra.size.y, rb.size.x * rb.size.y)
			if smaller <= 0.0 or area / smaller <= OVERLAP_FRAC:
				continue
			var a_on_top: bool = _draw_key(a) > _draw_key(b)
			var top: Dictionary = a if a_on_top else b
			var bot: Dictionary = b if a_on_top else a
			var line: String = "%s \"%s\" over %s \"%s\" (%.0f%% of the smaller box)" % [
				top["path"], top["text"], bot["path"], bot["text"], 100.0 * area / smaller]
			if bool(bot["copy"]) or bool(bot["hud"]):
				out.append(line)
			else:
				soft.append(line + " - covered text is world decoration")
	return {"hard": out, "soft": soft}


## Draw order as one comparable number: CanvasLayer, then accumulated z_index, then tree order,
## which is the order the renderer resolves them in. Tree order is the weakest of the three and only
## decides ties, so the ±4096 z range and the layer range stay separated by the multipliers.
func _draw_key(e: Dictionary) -> int:
	return ((int(e["layer"]) * 100000) + int(e["z"])) * 100000 + int(e["seq"])


## ── REPORTING ─────────────────────────────────────────────────────────────────
func _fail(gname: String, why: String) -> void:
	failures.append("%s: %s" % [gname, why])


func _print_row(row: Dictionary) -> void:
	var bad: int = int(row["off"].size()) + int(row["ovl"].size()) + int(row["dim"].size())
	var mark: String = "ok  " if bad == 0 and bool(row["live"]) else "FAIL"
	var worst: String = "n/a" if float(row["worst"]) > 90.0 else "%.2f:1" % float(row["worst"])
	print("  [%s] %-22s texts=%-3d minfont=%-3d worst=%-8s approx=%-2d off=%d collide=%d dim=%d%s" % [
		mark, String(row["g"]), int(row["n"]), int(row["min_fs"]), worst, int(row["approx"]),
		int(row["off"].size()), int(row["ovl"].size()), int(row["dim"].size()),
		"" if bool(row["live"]) else "  <- ROUND NEVER STARTED"])
	for o in row["off"]:
		print("        off screen: ", o)
	for o in row["ovl"]:
		print("        collide:    ", o)
	for d in row["dim"]:
		print("        dim:        ", d)
	for o in row["wander"]:
		print("        INFO world text crosses the edge: ", o)
	for o in row["soft_ovl"]:
		print("        INFO layered:  ", o)
	for d in row["faint"]:
		print("        INFO faint decoration: ", d)


func _report() -> void:
	print("\n" + "=".repeat(78))
	print("VISUAL / READABILITY SWEEP AT HARD - ", rows.size(), " games measured")
	print("=".repeat(78))
	var xf: Transform2D = get_tree().root.get_final_transform()
	print("canvas ", _vp(), " -> framebuffer scale ", "%.3f" % xf.get_scale().x,
		"   frames in ", OUT_DIR)
	var worst_g: String = "-"
	var worst_v: float = 99.0
	var never: Array = []
	for row in rows:
		if float(row["worst"]) < worst_v:
			worst_v = float(row["worst"])
			worst_g = "%s / %s" % [String(row["g"]), String(row["worst_of"])]
		if not bool(row["live"]):
			never.append(String(row["g"]))
	if worst_v < 90.0:
		print("tightest asserted contrast: %.2f:1  (%s)" % [worst_v, worst_g])
	var wd: float = 99.0
	var wd_g: String = "-"
	var soft_n: int = 0
	var faint_n: int = 0
	for row in rows:
		soft_n += int(row["soft_ovl"].size())
		faint_n += int(row["faint"].size())
		if float(row["worst_deco"]) < wd:
			wd = float(row["worst_deco"])
			wd_g = "%s / %s" % [String(row["g"]), String(row["worst_deco_of"])]
	if wd < 90.0:
		print("tightest decoration contrast: %.2f:1  (%s)  - reported, not asserted" % [wd, wd_g])
	print("reported and not failed: %d layered pairs over world decoration, %d faint decoration glyphs"
		% [soft_n, faint_n])
	if not never.is_empty():
		print("rounds that never went active: ", ", ".join(never))
	print("note: ", RAINWATER_NOTE)
	if failures.is_empty():
		print("\nRESULT: %d games, 0 readability failures at Hard" % rows.size())
		print("VISUAL SWEEP: GREEN")
	else:
		print("\n%d READABILITY FAILURES:" % failures.size())
		for f in failures:
			print("  - ", f)
		print("VISUAL SWEEP: RED")


## Product of modulate and self_modulate alpha up the CanvasItem chain. The walk stops at the
## CanvasLayer, which is not a CanvasItem and carries no modulate of its own.
func _eff_alpha(c: CanvasItem) -> float:
	var a: float = 1.0
	var n: Node = c
	while n != null and n is CanvasItem:
		var ci: CanvasItem = n
		a *= ci.modulate.a * ci.self_modulate.a
		n = ci.get_parent()
	return a


## Accumulated z_index. z_as_relative (the default) makes a node's z an offset from its parent's,
## so the flat property is not the drawn depth: WaterMemory's waves sit at -9 under a root at 0,
## and a card built inside a Panel at +2 draws above them however the child's own z reads.
func _z_of(c: CanvasItem) -> int:
	var z: int = 0
	var n: Node = c
	while n != null and n is CanvasItem:
		var ci: CanvasItem = n
		z += ci.z_index
		if not ci.z_as_relative:
			break
		n = ci.get_parent()
	return z


func _layer_of(c: CanvasItem) -> int:
	var cl: CanvasLayer = c.get_canvas_layer_node()
	return cl.layer if cl != null else 0


## ── SELF-CHECK: DRAW WHAT WAS MEASURED ────────────────────────────────────────
## Every number above depends on the glyph box landing where the letters actually are, and that
## box is computed, not observed - so it is drawn back into a copy of the frame. If a box in
## <game>_boxes.png does not sit on its text, the number for that row is measuring background.
func _annotate(img: Image, texts: Array) -> Image:
	var out: Image = img.duplicate()
	for e in texts:
		var col: Color = Color(1.0, 0.0, 1.0) if bool(e["tight"]) else Color(1.0, 0.6, 0.0)
		_outline(out, _to_px(e["glyph"]), col)
	return out


func _outline(img: Image, r: Rect2, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var x0: int = clampi(int(r.position.x), 0, w - 1)
	var y0: int = clampi(int(r.position.y), 0, h - 1)
	var x1: int = clampi(int(r.position.x + r.size.x), 0, w - 1)
	var y1: int = clampi(int(r.position.y + r.size.y), 0, h - 1)
	for x in range(x0, x1 + 1):
		img.set_pixel(x, y0, col)
		img.set_pixel(x, y1, col)
	for y in range(y0, y1 + 1):
		img.set_pixel(x0, y, col)
		img.set_pixel(x1, y, col)


## The two overrides that beat everything reported above. A LabelSettings resource replaces the
## theme's font and colour outright, so get_theme_color("font_color") describes something the
## Label is not using; and visible_ratio gates how much of an already-laid-out string is actually
## rasterised, so a reveal effect that never finishes leaves a correctly sized, fully opaque,
## fully visible Label drawing nothing at all.
func _why_invisible(c: Control) -> String:
	var bits: PackedStringArray = PackedStringArray()
	if c is Label:
		var l: Label = c
		if l.visible_ratio < 0.999:
			bits.append("visible_ratio=%.2f" % l.visible_ratio)
		if l.label_settings != null:
			var ls: LabelSettings = l.label_settings
			bits.append("label_settings fg=%s out=%d" % [str(ls.font_color), int(ls.outline_size)])
		if l.uppercase:
			bits.append("uppercase")
	return " ".join(bits)


## paint=1 repaints every measured Label in flat magenta with a fat outline and grabs a second
## frame. It answers the one question the numbers cannot: when a glyph box comes back perfectly
## uniform, is the text drawn in a colour that happens to match the backdrop, or is it not being
## rasterised at all? Magenta at full alpha over any of this project's backdrops is unmissable, so
## a box that is still empty in <game>_paint.png is a label the renderer never drew.
func _repaint(texts: Array) -> void:
	for e in texts:
		var c: Control = e["c"]
		c.add_theme_color_override("font_color", Color(1.0, 0.0, 1.0, 1.0))
		c.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		c.add_theme_constant_override("outline_size", 8)
