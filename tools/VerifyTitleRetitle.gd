extends Node

## ═══════════════════════════════════════════════════════════════════
## THE HUD TITLE FOLLOWS A LANGUAGE CHANGE MID-ROUND
## ═══════════════════════════════════════════════════════════════════
## MiniGameBase._setup_ui() used to bake the title into the HUD once:
## `hud_name_label.text = game_name.to_upper()`, with game_name resolved from
## Localization at _ready() time and never revisited. Every other string a round
## shows is re-resolved or short-lived; the title was the one that could not move.
##
## Named in the _retitle_for_language() doc comment as the harness that proves it,
## so it has to exist and it has to be able to FAIL. It therefore asserts the
## rendered Label text changes, not that a key exists — a key lookup would pass
## against the old baked-in behaviour too (see the memory note on localized keys
## being shadowed upstream).
##
## Three games are driven, all three with a title row in both languages, and all
## three are ordinary MiniGameBase subclasses launched the way GameManager
## launches them. For each: read the HUD title, flip Localization to the other
## language, let a frame pass, read it again, assert it moved AND that it matches
## what Localization now returns for that game's identity key.
##
## Run:
##   godot --headless --path . res://tools/VerifyTitleRetitle.tscn

const GAMES: Array = [
	{"key": "thirsty_plant", "path": "res://scenes/minigames/ThirstyPlant.tscn"},
	{"key": "turn_off_tap", "path": "res://scenes/minigames/TurnOffTap.tscn"},
	{"key": "quick_shower", "path": "res://scenes/minigames/QuickShower.tscn"},
]

var results: Array = []
var _orig_language: int = 0


func _ready() -> void:
	_orig_language = Localization.current_language
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


## The HUD title Label. Found by walking to the label MiniGameBase itself kept a
## reference to, so the harness and the fix agree on which node is under test.
func _title_label(game: Node) -> Label:
	var lbl = game.get("_hud_name_label")
	if lbl is Label:
		return lbl
	return null


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  HUD TITLE vs LANGUAGE CHANGE")
	print("═══════════════════════════════════════════════════════════")
	for entry in GAMES:
		await _one(entry["key"], entry["path"])
	_finish()


func _one(key: String, path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		_check("%s loads" % key, false, "load() returned null")
		return
	var game: Node = packed.instantiate()
	_tree().root.add_child(game)
	await _frames(4)

	var lbl := _title_label(game)
	if lbl == null:
		_check("%s exposes its HUD title label" % key, false, "_hud_name_label unset")
		game.queue_free()
		await _frames(2)
		return
	_check("%s exposes its HUD title label" % key, true)

	# Both shipped languages must actually have a row, or the assertion below would
	# be measuring a missing translation rather than the retitle path.
	if not Localization.has_text(key):
		_check("%s has a title row" % key, false, "no '%s' key" % key)
		game.queue_free()
		await _frames(2)
		return

	var before: String = lbl.text
	var other: int = (
		Localization.Language.ENGLISH
		if Localization.current_language == Localization.Language.FILIPINO
		else Localization.Language.FILIPINO
	)
	Localization.set_language(other)
	await _frames(3)
	var after: String = lbl.text
	var expected: String = Localization.get_text(key).to_upper()

	_check(
		"%s title changes with the language" % key,
		after != before,
		"'%s' -> '%s'" % [before, after]
	)
	_check(
		"%s title matches the new locale's row" % key,
		after == expected,
		"got '%s', row says '%s'" % [after, expected]
	)
	# game_name is the display field the results screen reads; it has to move too.
	_check(
		"%s game_name follows the label" % key,
		String(game.get("game_name")).to_upper() == after,
		"game_name='%s'" % String(game.get("game_name"))
	)

	# Flip back and confirm it is not a one-way write.
	Localization.set_language(_orig_language)
	await _frames(3)
	_check(
		"%s title returns on the way back" % key,
		lbl.text == before,
		"'%s' vs original '%s'" % [lbl.text, before]
	)

	game.queue_free()
	await _frames(2)


func _finish() -> void:
	Localization.set_language(_orig_language)
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	Engine.get_main_loop().quit(1 if failed > 0 else 0)
