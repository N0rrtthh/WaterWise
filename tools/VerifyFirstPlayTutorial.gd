extends Node

## ═══════════════════════════════════════════════════════════════════
## FIRST-PLAY TUTORIAL HARNESS
## ═══════════════════════════════════════════════════════════════════
## autoload/TutorialManager.gd is 440 lines carrying multi-step bilingual tutorials
## plus a gameplay tip for 8 of the 24 singleplayer games, and a contextual-hint
## table on top of that. Its entire API — should_show_tutorial(),
## create_tutorial_popup(), mark_tutorial_shown(), get_contextual_hint() — had NO
## caller anywhere in the project: the only reference to the file was its own
## autoload line in project.godot. It does not self-wire either (its _ready() only
## reloads persisted state; nothing listens to node_added or scene changes). So every
## first-time player got game_instruction_text, one line, and none of the authored
## teaching content was reachable. For an educational thesis game that is a gap
## between what the build does and what the project claims to teach.
##
## MiniGameBase._show_first_play_tutorial() is now that caller, wired as a REPLACEMENT
## for the one-line instruction overlay on first play rather than as an extra gate, so
## the player still has exactly one thing to dismiss.
##
## What is measured here, each with a control beside it:
##   * the popup appears on first play of a game that HAS authored content, carrying
##     that content's real title;
##   * the one-line overlay is suppressed while it is up, so the two do not stack;
##   * the round still starts and the popup is gone afterwards — the failure mode of
##     a full-screen modal is a soft lock, so this is the check that matters most;
##   * a SECOND visit to the same game shows the plain overlay instead;
##   * a game with no authored entry (16 of the 24) is completely unaffected;
##   * the language actually switches the content, which is the point of authoring
##     both halves.
##
## Player state is snapshotted and restored: mark_tutorial_shown() writes through to
## SaveManager, so a harness that did not restore would consume the real player's
## first-play tutorials.
##
## Usage:
##   godot --headless --path . res://tools/VerifyFirstPlayTutorial.tscn

## Has authored tutorial content.
const TUTORIAL_GAME: String = "res://scenes/minigames/CatchTheRain.tscn"
## Has none — 16 of the 24 games are in this position and must be untouched.
const PLAIN_GAME: String = "res://scenes/minigames/ThirstyPlant.tscn"
## _wait_for_input() returns after 0.8s when autoplay drives the round.
const AUTOPLAY_GATE: float = 0.8

var results: Array = []
var _detached: bool = false

var _orig_shown: Array = []
var _orig_autoplay: bool = false
var _orig_lang: int = 0


func _ready() -> void:
	if not _detached:
		# This harness drives change_scene_to_file(), which memdeletes the outgoing
		# current_scene — for a tool-scene launch that is this node. The timeline runs
		# on a twin parented to /root instead.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "FirstPlayTutorialProbe"
		get_tree().root.add_child.call_deferred(twin)
		return
	await _run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _current() -> Node:
	var t := _tree()
	return t.current_scene if t else null


## The popup TutorialManager builds is named "TutorialOverlay" and is parented to the
## minigame's hud_layer, so it is found by name rather than by guessing at a path.
func _find_popup() -> Node:
	var cs := _current()
	if cs == null:
		return null
	return cs.find_child("TutorialOverlay", true, false)


## The authored title is rendered into the first Label of the popup, prefixed with an
## emoji by TutorialManager. Reading it back proves the popup carries THIS game's
## content and not an empty shell.
func _popup_title() -> String:
	var popup := _find_popup()
	if popup == null:
		return ""
	for label in _all_labels(popup):
		return label.text
	return ""


func _all_labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for child in node.get_children():
		out.append_array(_all_labels(child))
	return out


func _instruction_visible() -> bool:
	var cs := _current()
	if cs == null:
		return false
	var overlay = cs.get("instruction_overlay")
	return overlay != null and is_instance_valid(overlay) and bool(overlay.visible)


func _load(path: String) -> void:
	_tree().change_scene_to_file(path)
	await _tree().process_frame
	await _tree().process_frame
	await _tree().process_frame


func _wait(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await _tree().process_frame


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  FIRST-PLAY TUTORIAL HARNESS")
	print("═══════════════════════════════════════════════════════════")
	_orig_shown = TutorialManager.shown_tutorials.duplicate()
	_orig_autoplay = bool(AutoPlayManager.auto_play_enabled)
	_orig_lang = int(Localization.current_language)
	# Set directly: set_auto_play_enabled() writes the flag through to the player's
	# settings file.
	AutoPlayManager.auto_play_enabled = true
	TutorialManager.shown_tutorials.clear()

	await _first_play()
	await _second_play()
	await _plain_game()
	await _language()

	# Restore every piece of player state this harness touched, including the
	# persisted copy that mark_tutorial_shown() wrote.
	Localization.current_language = _orig_lang
	TutorialManager.shown_tutorials = []
	for g in _orig_shown:
		TutorialManager.shown_tutorials.append(str(g))
	TutorialManager._save_shown_tutorials()
	AutoPlayManager.auto_play_enabled = _orig_autoplay
	print("")
	print("  restored: shown_tutorials=%s autoplay=%s language=%d"
		% [str(TutorialManager.shown_tutorials), str(_orig_autoplay), _orig_lang])

	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	_tree().quit(1 if failed > 0 else 0)


# ── first play of a game with authored content ───────────────────────

func _first_play() -> void:
	Localization.current_language = Localization.Language.ENGLISH
	var key := TUTORIAL_GAME.get_file().get_basename()
	_check("control: TutorialManager has authored content for %s" % key,
		not TutorialManager.get_tutorial(key).is_empty(),
		"tutorial keys present = %s" % str(TutorialManager.tutorials.has(key)))
	_check("control: it has not been marked shown yet",
		TutorialManager.should_show_tutorial(key),
		"should_show_tutorial = %s" % str(TutorialManager.should_show_tutorial(key)))

	await _load(TUTORIAL_GAME)
	var popup := _find_popup()
	_check("first play of %s brings up the authored tutorial" % key,
		popup != null,
		"TutorialOverlay under the minigame = %s" % ("found" if popup else "ABSENT"))
	var title := _popup_title()
	_check("the popup carries this game's authored English title",
		title.contains("Catch The Rain"),
		"first label = \"%s\"" % title)
	_check("the one-line instruction overlay is suppressed while it is up (one gate,"
			+ " not two)",
		not _instruction_visible(),
		"instruction_overlay.visible = %s" % str(_instruction_visible()))
	_check("the popup swallows taps meant for the game underneath",
		popup != null and int(popup.get("mouse_filter")) == Control.MOUSE_FILTER_STOP,
		"mouse_filter = %s" % (str(popup.get("mouse_filter")) if popup else "<none>"))

	# The soft-lock check. A full-screen modal that outlives the wait would leave the
	# player looking at a game they cannot reach.
	await _wait(AUTOPLAY_GATE + 1.2)
	var cs := _current()
	_check("the round still starts with the tutorial in the flow (no soft lock)",
		cs != null and bool(cs.get("game_active")),
		"game_active = %s" % (str(cs.get("game_active")) if cs else "<no scene>"))
	_check("the popup is gone once the round starts",
		_find_popup() == null,
		"TutorialOverlay = %s" % ("STILL PRESENT" if _find_popup() else "freed"))
	_check("showing it marked it shown, so it cannot reappear every visit",
		not TutorialManager.should_show_tutorial(key),
		"should_show_tutorial = %s" % str(TutorialManager.should_show_tutorial(key)))


# ── second visit to the same game ────────────────────────────────────

func _second_play() -> void:
	await _load(TUTORIAL_GAME)
	_check("a second visit shows no tutorial popup",
		_find_popup() == null,
		"TutorialOverlay = %s" % ("PRESENT" if _find_popup() else "absent"))
	_check("a second visit falls back to the one-line instruction overlay",
		_instruction_visible(),
		"instruction_overlay.visible = %s" % str(_instruction_visible()))
	await _wait(AUTOPLAY_GATE + 1.2)
	var cs := _current()
	_check("the second visit starts normally",
		cs != null and bool(cs.get("game_active")),
		"game_active = %s" % (str(cs.get("game_active")) if cs else "<no scene>"))


# ── a game with no authored entry ────────────────────────────────────

func _plain_game() -> void:
	var key := PLAIN_GAME.get_file().get_basename()
	_check("control: %s has no authored tutorial (16 of the 24 do not)" % key,
		TutorialManager.get_tutorial(key).is_empty(),
		"entry present = %s" % str(TutorialManager.tutorials.has(key)))
	await _load(PLAIN_GAME)
	_check("a game with no authored tutorial shows no popup",
		_find_popup() == null,
		"TutorialOverlay = %s" % ("PRESENT" if _find_popup() else "absent"))
	_check("it still shows its one-line instruction overlay, unchanged",
		_instruction_visible(),
		"instruction_overlay.visible = %s" % str(_instruction_visible()))
	await _wait(AUTOPLAY_GATE + 1.2)
	var cs := _current()
	_check("it starts normally",
		cs != null and bool(cs.get("game_active")),
		"game_active = %s" % (str(cs.get("game_active")) if cs else "<no scene>"))


# ── the other authored language ──────────────────────────────────────

func _language() -> void:
	var key := TUTORIAL_GAME.get_file().get_basename()
	TutorialManager.shown_tutorials.erase(key)
	Localization.current_language = Localization.Language.FILIPINO
	_check("control: Filipino is selected",
		not Localization.is_english(),
		"is_english = %s" % str(Localization.is_english()))
	await _load(TUTORIAL_GAME)
	var title := _popup_title()
	_check("the popup switches to the authored Filipino title",
		title.contains("Saluhin ang Ulan"),
		"first label = \"%s\"" % title)
