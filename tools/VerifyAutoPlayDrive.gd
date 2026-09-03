extends Node

## Does the auto-play driver reach each game's OWN ai, and can it be trapped by a
## pause it caused itself?
##
## WHAT THIS IS FOR
##   AutoPlayManager is the only thing that plays a 7-minute soak, so every soak
##   result in this audit is downstream of it. Two seams decide whether it plays a
##   game or flails at it:
##     * MiniGameBase._ready() registers with AutoPlayManager.register_game(self,
##       game_name) -- and game_name is the DISPLAY TITLE, which FixLeakV2 builds
##       from Localization. _dispatch_game_strategy() then matches that string
##       against a table of English titles, so under FILIPINO every single-player
##       game falls through to the generic fallback and none of the 24 authored
##       strategies runs.
##     * that fallback presses a Button chosen at random out of everything under
##       the game, filtered by NAME -- but MiniGameBase builds its HUD with
##       Button.new() and never names anything, so the pause glyph and the
##       overlay's RESUME / QUIT GAME are all named "@Button@N" and no word in the
##       skip list can match. Pressing pause freezes the tree, the driver's own
##       _process stops with it, and nothing can ever resume: measured as
##       auto_play_elapsed frozen at 25s across a 420s run whose log reported no
##       failures at all.
##   A soak that silently stops driving at 25s is the vacuous-pass class this
##   audit exists to catch, so the driver needs its own harness.
##
## WHAT IS ASSERTED
##   [0] the probe is non-vacuous: FILIPINO really does change the title, so
##       [1] is measuring a translated string and not an unset language
##   [1] every roster game registers under its SCENE ID, in Filipino
##   [2] registration is language-invariant: the English run agrees with [1]
##   [3] the dispatch table covers every roster id and every handler it names
##       exists -- a typo in a match case is invisible, a missing dictionary key
##       is not
##   [4] driving a game through the FALLBACK strategy never pauses the tree and
##       never changes the scene (the deadlock and the bot quitting to menu)
##   [5] no button inside a hidden overlay is offered to the bot at all -- the
##       structural cause behind [4], reported per game
##   [6] the driver keeps ticking while the tree is paused, so it can act
##   [7] a pause the driver did not intend is recovered from, not waited out
##
## Usage:
##   godot --headless --path . res://tools/VerifyAutoPlayDrive.tscn

const SCENE_FMT: String = "res://scenes/minigames/%s.tscn"
## Words a player reads on a shell control. The bot may press gameplay buttons
## freely; these end or suspend the round, so a bot that presses one has stopped
## testing the game. Harness-owned vocabulary, deliberately wider than the
## driver's own list.
const SHELL_WORDS: Array = [
	"resume", "quit", "exit", "pause", "menu", "back", "restart", "retry",
	"home", "close", "skip", "settings", "continue",
]
## The pause glyph carries no word at all -- MiniGameBase draws it as "II".
const SHELL_GLYPHS: Array = ["ii", "❚❚", "✕", "×"]
## Long enough for MiniGameBase._ready() to finish and register.
const READY_FRAMES: int = 8
## How long the driver is given to notice a pause and undo it.
const RECOVER_SECONDS: float = 2.5

var _pass: int = 0
var _fail: int = 0

var _hazard_hits: Dictionary = {}


## Records that the bot pressed a control it should never have been offered.
## Bound per Button, so the label is what a player would have read on it.
func _note_hazard_press(label: String) -> void:
	_hazard_hits[label] = int(_hazard_hits.get(label, 0)) + 1



func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Real seconds, immune to get_tree().paused -- the checks that matter here run
## WHILE the tree is paused, where a plain process_frame await never returns.
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## Scene id -> registered label, one full _ready() per game.
func _register_all() -> Dictionary:
	var out: Dictionary = {}
	for id in GameManager.ALL_SINGLEPLAYER_MINIGAMES:
		var path: String = SCENE_FMT % str(id)
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var g: Node = packed.instantiate()
		if g == null:
			continue
		AutoPlayManager.auto_play_enabled = true
		AutoPlayManager.game_name = ""
		AutoPlayManager.auto_play_strategy = ""
		get_tree().root.add_child(g)
		await _frames(READY_FRAMES)
		out[str(id)] = {
			"label": str(AutoPlayManager.game_name),
			"strategy": str(AutoPlayManager.auto_play_strategy),
			# The game's OWN display title, read off the instance. [0] needs this to
			# tell a real pass from a vacuous one: if no title is translated then
			# [1] and [2] hold trivially, because there is nothing for the label to
			# have been wrong about.
			"title": str(g.game_name) if "game_name" in g else "",
		}
		AutoPlayManager.auto_play_enabled = false
		AutoPlayManager.current_game = null
		get_tree().paused = false
		g.queue_free()
		await _frames(2)
	return out


## Lower-cased text of a Button, with the accelerator markup Godot leaves in.
func _btn_text(b: Button) -> String:
	return b.text.strip_edges().to_lower()


func _is_shell_button(b: Button) -> bool:
	var t: String = _btn_text(b)
	var n: String = b.name.to_lower()
	if t in SHELL_GLYPHS:
		return true
	for w in SHELL_WORDS:
		if w in t or w in n:
			return true
	return false


## Everything the driver would consider pressing, with the reason each entry is
## unacceptable. Empty means the collector is safe for this game.
func _hazards_offered(g: Node) -> PackedStringArray:
	var bad: PackedStringArray = []
	var offered: Array = AutoPlayManager._collect_all_buttons(g)
	for item in offered:
		var b := item as Button
		if b == null or not is_instance_valid(b):
			continue
		if not b.is_visible_in_tree():
			bad.append("hidden:\"%s\"" % _btn_text(b))
		elif _is_shell_button(b):
			bad.append("shell:\"%s\"" % _btn_text(b))
	return bad


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n=== VerifyAutoPlayDrive ===")
	await _frames(10)

	if not AutoPlayManager or not GameManager or not Localization:
		push_error("[APD] autoloads unavailable")
		_check("[0] autoloads reachable", false)
		_report()
		return

	# ── [0]/[1] Filipino run ─────────────────────────────────────────
	Localization.set_language(Localization.Language.FILIPINO)
	await _frames(4)
	var tl: Dictionary = await _register_all()
	var probe_title: String = str(tl.get("FixLeak", {}).get("title", ""))
	_check(
		"[0] the probe is really translated",
		probe_title != "" and probe_title != "Fix Leak" and probe_title != "FixLeak",
		"FixLeak's display title under FILIPINO is \"%s\"" % probe_title
	)

	var wrong_id: PackedStringArray = []
	for id in tl:
		if _canon(str(tl[id]["label"])) != _canon(str(id)):
			wrong_id.append("%s -> \"%s\"" % [str(id), str(tl[id]["label"])])
	_check(
		"[1] every game registers under its scene id",
		wrong_id.is_empty(),
		"%d of %d wrong: %s" % [
			wrong_id.size(), tl.size(), ", ".join(wrong_id).substr(0, 400)
		]
	)

	# ── [2] English run must agree ───────────────────────────────────
	Localization.set_language(Localization.Language.ENGLISH)
	await _frames(4)
	var en: Dictionary = await _register_all()
	var drift: PackedStringArray = []
	for id in tl:
		if not en.has(id):
			continue
		if _canon(str(en[id]["label"])) != _canon(str(tl[id]["label"])):
			drift.append("%s: en \"%s\" vs tl \"%s\"" % [
				str(id), str(en[id]["label"]), str(tl[id]["label"])
			])
		elif str(en[id]["strategy"]) != str(tl[id]["strategy"]):
			drift.append("%s: strategy en %s vs tl %s" % [
				str(id), str(en[id]["strategy"]), str(tl[id]["strategy"])
			])
	_check(
		"[2] registration and strategy do not depend on the language",
		drift.is_empty(),
		"%d drifted: %s" % [drift.size(), ", ".join(drift).substr(0, 400)]
	)

	# ── [3] the dispatch table is complete and its handlers exist ────
	var table: Dictionary = {}
	if "HANDLERS" in AutoPlayManager:
		table = AutoPlayManager.HANDLERS
	var missing: PackedStringArray = []
	for id in GameManager.ALL_SINGLEPLAYER_MINIGAMES:
		var key: String = _canon(str(id))
		if not table.has(key):
			missing.append("%s (no entry)" % str(id))
		elif not AutoPlayManager.has_method(str(table[key])):
			missing.append("%s -> %s (no such method)" % [str(id), str(table[key])])
	_check(
		"[3] the dispatch table covers the roster",
		not table.is_empty() and missing.is_empty(),
		("no HANDLERS table to verify" if table.is_empty()
			else "%d gap(s): %s" % [missing.size(), ", ".join(missing).substr(0, 400)])
	)

	# ── [4]/[5] the fallback strategy, per game ──────────────────────
	# The fallback is what EVERY single-player game got under Filipino before the
	# id fix, so it is driven here deliberately rather than avoided. Presses are
	# counted at the Button's own `pressed` signal rather than inferred from a side
	# effect: _on_pause_pressed() refuses while game_active is false and
	# _on_exit_pressed() refuses on a repeat, so a press that reached a shell
	# control can otherwise leave no trace at all.
	var paused_by: PackedStringArray = []
	var navigated_by: PackedStringArray = []
	var hazard_by: PackedStringArray = []
	var pressed_by: PackedStringArray = []
	for id in GameManager.ALL_SINGLEPLAYER_MINIGAMES:
		var path: String = SCENE_FMT % str(id)
		if not ResourceLoader.exists(path):
			continue
		var g: Node = (load(path) as PackedScene).instantiate()
		if g == null:
			continue
		get_tree().root.add_child(g)
		await _frames(READY_FRAMES)

		_hazard_hits.clear()
		var haz: PackedStringArray = _hazards_offered(g)
		if not haz.is_empty():
			hazard_by.append("%s[%s]" % [str(id), ", ".join(haz).substr(0, 120)])
		for item in AutoPlayManager._collect_all_buttons(g):
			var b := item as Button
			if b == null or not is_instance_valid(b):
				continue
			if b.is_visible_in_tree() and not _is_shell_button(b):
				continue
			if not b.pressed.is_connected(_note_hazard_press):
				b.pressed.connect(_note_hazard_press.bind(_btn_text(b)))

		var before_scene: String = ""
		if get_tree().current_scene:
			before_scene = get_tree().current_scene.name
		AutoPlayManager.current_game = g
		AutoPlayManager.game_name = "__unrecognised__"
		AutoPlayManager.auto_play_strategy = ""
		for _i in range(40):
			if not is_instance_valid(g):
				break
			# A real soak drives an ACTIVE round; without this the pause press is a
			# no-op and the deadlock hides.
			if "game_active" in g:
				g.game_active = true
			AutoPlayManager.tap_cooldown = 0.0
			AutoPlayManager._dispatch_game_strategy(0.016)
			await _frames(1)
			if get_tree().paused:
				paused_by.append(str(id))
				get_tree().paused = false
				break
		var after_scene: String = ""
		if get_tree().current_scene:
			after_scene = get_tree().current_scene.name
		if after_scene != before_scene:
			navigated_by.append("%s (%s -> %s)" % [str(id), before_scene, after_scene])
		if not _hazard_hits.is_empty():
			var hit_names: PackedStringArray = []
			for k in _hazard_hits:
				hit_names.append("\"%s\"x%d" % [str(k), int(_hazard_hits[k])])
			pressed_by.append("%s[%s]" % [str(id), ", ".join(hit_names).substr(0, 120)])

		AutoPlayManager.current_game = null
		if is_instance_valid(g):
			g.queue_free()
		await _frames(2)

	_check(
		"[4a] the fallback never presses a shell or hidden control",
		pressed_by.is_empty(),
		"%d game(s): %s" % [pressed_by.size(), ", ".join(pressed_by).substr(0, 600)]
	)
	_check(
		"[4b] the fallback strategy never pauses the tree",
		paused_by.is_empty(),
		"%d game(s) paused: %s" % [paused_by.size(), ", ".join(paused_by)]
	)
	_check(
		"[4c] the fallback strategy never leaves the round",
		navigated_by.is_empty(),
		"%d game(s): %s" % [navigated_by.size(), ", ".join(navigated_by)]
	)
	_check(
		"[5] no hidden or shell button is offered to the bot",
		hazard_by.is_empty(),
		"%d game(s): %s" % [hazard_by.size(), ", ".join(hazard_by).substr(0, 600)]
	)
	# ── [6] the driver still ticks while the tree is paused ──────────
	AutoPlayManager.auto_play_enabled = true
	AutoPlayManager.auto_play_start_time = Time.get_ticks_msec()
	await _frames(2)
	get_tree().paused = true
	var t0: float = AutoPlayManager.auto_play_elapsed
	await _wait(0.5)
	var t1: float = AutoPlayManager.auto_play_elapsed
	get_tree().paused = false
	_check(
		"[6] the driver keeps ticking while paused",
		t1 > t0,
		"elapsed %.3f -> %.3f while get_tree().paused was true" % [t0, t1]
	)

	# ── [7] a pause with the overlay up is undone ────────────────────
	var probe: Node = (load(SCENE_FMT % "FixLeak") as PackedScene).instantiate()
	get_tree().root.add_child(probe)
	await _frames(READY_FRAMES)
	AutoPlayManager.auto_play_enabled = true
	AutoPlayManager.current_game = probe
	var overlay_shown: bool = false
	if "pause_menu" in probe and probe.pause_menu and is_instance_valid(probe.pause_menu):
		get_tree().paused = true
		probe.pause_menu.visible = true
		overlay_shown = true
	await _wait(RECOVER_SECONDS)
	var still_paused: bool = get_tree().paused
	var overlay_still_up: bool = (
		overlay_shown and is_instance_valid(probe.pause_menu) and probe.pause_menu.visible
	)
	get_tree().paused = false
	_check(
		"[7] a pause overlay the bot did not want is dismissed",
		overlay_shown and not still_paused and not overlay_still_up,
		("no pause_menu on the probe" if not overlay_shown
			else "paused=%s overlay_visible=%s after %.1fs" % [
				str(still_paused), str(overlay_still_up), RECOVER_SECONDS
			])
	)

	# ── [8] a bare pause, with nothing to dismiss, is also undone ────
	get_tree().paused = true
	await _wait(RECOVER_SECONDS + 2.0)
	var bare_still: bool = get_tree().paused
	get_tree().paused = false
	_check(
		"[8] a pause with no overlay is not waited out forever",
		not bare_still,
		"still paused %.1fs after a bare get_tree().paused = true" % (RECOVER_SECONDS + 2.0)
	)

	AutoPlayManager.current_game = null
	AutoPlayManager.auto_play_enabled = false
	if is_instance_valid(probe):
		probe.queue_free()
	await _frames(2)
	# AutoPlayManager persists this flag into the save, so a harness that leaves it
	# on hands the bot to the next human session.
	AutoPlayManager.set_auto_play_enabled(false)
	_report()


## Same normalisation the driver uses, restated here on purpose: a harness that
## imported the driver's own helper would agree with it even when both are wrong.
func _canon(s: String) -> String:
	var out: String = s.to_lower()
	out = out.replace(" ", "").replace("_", "").replace("-", "")
	if out.ends_with("v2"):
		out = out.substr(0, out.length() - 2)
	return out


func _report() -> void:
	print("\n=== VerifyAutoPlayDrive: %d passed / %d failed ===" % [_pass, _fail])
	await _frames(2)
	get_tree().quit(0 if _fail == 0 else 1)
