extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO PLAYER-FACING PATHS THAT EXISTED ONLY IN CODE
## ═══════════════════════════════════════════════════════════════════
## SECTION A — the Reduce Motion toggle.
##
## Three layers of this project honour AccessibilityManager.get_animation_speed()
## (JuiceEffects, the cutscene players via MiniGameBase/MiniGameIntroBridge, and
## ButtonAnimator), each locked in by its own harness. None of it could be turned
## on: Settings exposed colorblind, large touch targets, audio cues, haptics,
## screen shake and particles — but NOT reduced motion — and
## set_reduced_motion() had no caller outside tools/. The only way to enable the
## feature was to hand-edit user://waterwise_settings.json.
##
## Checked here: the row exists in the accessibility grid, its initial state
## reflects the saved value, toggling it drives AccessibilityManager AND persists
## through SaveManager, get_animation_speed() moves 1.0 <-> 3.0 with it, and the
## label is authored in both shipped languages.
##
## SECTION B — MiniGameResults' RETRY button.
##
## Its handler called GameManager.replay_current_minigame(), which existed
## nowhere in the project, so the press raised "Invalid call. Nonexistent
## function" and the player stayed on the results screen. The method is now
## implemented against a new last_launched_minigame_name, because round_scores
## records the DISPLAY name ("Water Plant") and no scene path can be built from
## that.
##
## The replay check compares node instance ids across the reload: asserting only
## that the path matches would pass on a replay that did nothing at all.
##
## Run:
##   godot --headless --path . res://tools/VerifyReduceMotionToggle.tscn

const SETTINGS_SCENE: String = "res://scenes/ui/Settings.tscn"
const REPLAY_GAME: String = "ThirstyPlant"
const REPLAY_PATH: String = "res://scenes/minigames/ThirstyPlant.tscn"

var results: Array = []

## Restored on the way out — every one of these writes to the real player's file.
var _orig_reduced: bool = false
var _orig_language: int = 0
var _detached: bool = false


func _ready() -> void:
	if not _detached:
		# Section B ends in change_scene_to_file(), which memdeletes the outgoing
		# current_scene — this node, for a tool-scene launch. The timeline runs on
		# a twin parented to /root instead.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "ReduceMotionProbe"
		get_tree().root.add_child.call_deferred(twin)
		return
	_run.call_deferred()

# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _finish() -> void:
	# Put the player's own settings back before reporting.
	AccessibilityManager.set_reduced_motion(_orig_reduced)
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


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame

# ── SECTION A: the Reduce Motion row ────────────────────────────────

## The Label sitting immediately before the checkbox in the 2-column grid, found
## by position rather than by text so the assertion on its text is not circular.
func _row_label(grid: Node, box: Node) -> Label:
	var kids := grid.get_children()
	var idx := kids.find(box)
	if idx <= 0:
		return null
	return kids[idx - 1] as Label


func _section_a() -> void:
	print("")
	print("── SECTION A: Settings → Reduce Motion ─────────────────────")
	AccessibilityManager.set_reduced_motion(false)
	SaveManager.set_setting("reduced_motion", false)

	var packed := load(SETTINGS_SCENE) as PackedScene
	_check("Settings.tscn loaded", packed != null)
	if packed == null:
		_finish()
		return
	var settings: Node = packed.instantiate()
	_tree().root.add_child(settings)
	await _frames(4)

	var box := settings.get("reduced_motion_check") as CheckBox
	_check("Settings built a Reduce Motion checkbox",
		box != null and is_instance_valid(box),
		"reduced_motion_check = %s" % str(box))
	if box == null:
		settings.queue_free()
		_finish()
		return

	var grid: Node = settings.get("accessibility_section")
	_check("the checkbox is live in the accessibility grid the player scrolls",
		box.is_inside_tree() and grid != null and grid.is_ancestor_of(box),
		"parent = %s" % str(box.get_parent()))

	# Initial state must mirror the saved value, or the row would lie about
	# whatever the player last chose.
	_check("the row opens showing the saved value (off)",
		box.button_pressed == false,
		"button_pressed = %s" % str(box.button_pressed))

	# ON. Setting button_pressed emits toggled(), which is exactly what a tap does.
	box.button_pressed = true
	await _frames(2)
	_check("toggling it ON reaches AccessibilityManager",
		AccessibilityManager.reduced_motion == true,
		"reduced_motion = %s" % str(AccessibilityManager.reduced_motion))
	_check("get_animation_speed() becomes the 3.0 divisor the animation layers read",
		is_equal_approx(AccessibilityManager.get_animation_speed(), 3.0),
		"speed = %s" % str(AccessibilityManager.get_animation_speed()))
	_check("should_reduce_motion() agrees", AccessibilityManager.should_reduce_motion())
	_check("the choice persists through SaveManager",
		bool(SaveManager.get_setting("reduced_motion", false)) == true,
		"saved = %s" % str(SaveManager.get_setting("reduced_motion", false)))

	# OFF again — a one-way switch would strand a player who turned it on by accident.
	box.button_pressed = false
	await _frames(2)
	_check("toggling it OFF restores full-speed animation",
		AccessibilityManager.reduced_motion == false
			and is_equal_approx(AccessibilityManager.get_animation_speed(), 1.0),
		"reduced_motion = %s speed = %s" % [str(AccessibilityManager.reduced_motion),
			str(AccessibilityManager.get_animation_speed())])
	_check("the OFF choice persists too",
		bool(SaveManager.get_setting("reduced_motion", true)) == false,
		"saved = %s" % str(SaveManager.get_setting("reduced_motion", true)))

	# Bilingual, like every other string in this project. Asserted on the LIVE
	# label so this covers the localization entry and the re-apply on switch.
	var lbl := _row_label(grid, box)
	_check("the row has a label", lbl != null)
	if lbl != null:
		Localization.set_language(Localization.Language.ENGLISH)
		await _frames(2)
		var en := lbl.text
		Localization.set_language(Localization.Language.FILIPINO)
		await _frames(2)
		var tl := lbl.text
		_check("the label is authored in English",
			en.contains("Reduce Motion"), "en = '%s'" % en)
		_check("the label is authored in Filipino and follows a live switch",
			tl.contains("Paggalaw") and tl != en, "tl = '%s' (en was '%s')" % [tl, en])

	settings.queue_free()
	await _frames(2)

# ── SECTION B: MiniGameResults RETRY → replay_current_minigame() ─────

func _section_b() -> void:
	print("")
	print("── SECTION B: RETRY replays the round it was pressed on ─────")
	GameManager.current_game_mode = GameManager.GameMode.SINGLE_PLAYER
	# A stocked bag is what makes "the roster did not advance" measurable: an
	# empty one cannot be drained, so the check would pass on any behaviour.
	GameManager._refresh_available_minigames()
	GameManager._rebuild_minigame_random_bag()
	_check("control: the random bag is stocked, so draining it would be visible",
		GameManager.minigame_random_bag.size() > 1,
		"bag = %d entries" % GameManager.minigame_random_bag.size())

	GameManager.last_launched_minigame_name = ""
	GameManager.pending_next_minigame_name = REPLAY_GAME
	GameManager.launch_pending_minigame()
	await _frames(8)

	var first: Node = _tree().current_scene
	var first_path := first.scene_file_path if first else "<null>"
	var first_id := first.get_instance_id() if first else 0
	_check("control: the round loaded on the shipped launch path",
		first_path == REPLAY_PATH, "current_scene = %s" % first_path)
	_check("launching recorded the scene basename a replay needs",
		GameManager.last_launched_minigame_name == REPLAY_GAME,
		"last_launched_minigame_name = '%s'" % GameManager.last_launched_minigame_name)

	var bag_before := GameManager.minigame_random_bag.size()
	var played_before: int = GameManager.minigames_played_this_session
	var lives_before: int = GameManager.session_lives
	var score_before: int = GameManager.session_score

	# What the RETRY button does. Before the fix this raised
	# "Invalid call. Nonexistent function 'replay_current_minigame'".
	GameManager.replay_current_minigame()
	await _frames(10)

	var second: Node = _tree().current_scene
	var second_path := second.scene_file_path if second else "<null>"
	var second_id := second.get_instance_id() if second else 0

	_check("RETRY reloads the SAME round, not the next one",
		second_path == REPLAY_PATH, "current_scene = %s" % second_path)
	# Instance ids, because a matching path alone would also be reported by a
	# replay that did nothing whatsoever.
	_check("it is a genuinely fresh instance of that round",
		second_id != 0 and second_id != first_id,
		"first id %d, second id %d" % [first_id, second_id])
	_check("the round is playable again (the scene is live in the tree)",
		second != null and second.is_inside_tree())
	_check("replaying does not consume a roster slot from the random bag",
		GameManager.minigame_random_bag.size() == bag_before,
		"bag %d -> %d" % [bag_before, GameManager.minigame_random_bag.size()])
	_check("replaying does not rewind or advance the run economy",
		GameManager.minigames_played_this_session == played_before
			and GameManager.session_lives == lives_before
			and GameManager.session_score == score_before,
		"played %d->%d lives %d->%d score %d->%d"
			% [played_before, GameManager.minigames_played_this_session,
				lives_before, GameManager.session_lives,
				score_before, GameManager.session_score])
	_check("the basename is still recorded, so RETRY works twice in a row",
		GameManager.last_launched_minigame_name == REPLAY_GAME,
		"last_launched_minigame_name = '%s'" % GameManager.last_launched_minigame_name)


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  REDUCE-MOTION TOGGLE + RETRY-REPLAY HARNESS")
	print("═══════════════════════════════════════════════════════════")
	_orig_reduced = AccessibilityManager.reduced_motion
	_orig_language = Localization.current_language
	await _section_a()
	await _section_b()
	_finish()
