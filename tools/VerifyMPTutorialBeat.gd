extends Node

## Does a first-time co-op player get told how the round works - and only the first time?
##
## THE DEFECT
##   Every single-player round has had a first-play tutorial for as long as there have been
##   rounds: MiniGameBase._show_first_play_tutorial() -> TutorialManager.create_tutorial_popup().
##   None of the twelve live multiplayer rounds had any equivalent. A first-timer got the one
##   line from get_instructions(), which names the action and the numbers and says nothing
##   about the thing co-op actually runs on: that what you are catching is what the OTHER
##   player is standing there waiting for. Two players who do not know that are playing two
##   unrelated games in the same room.
##
## WHY IT IS PAGES INSIDE THE EXISTING OVERLAY
##   Dismissing the instruction overlay IS the readiness handshake - _on_instruction_dismissed()
##   calls NetworkManager.set_local_player_ready(), and six seconds later the host force-starts
##   the round whether the client answered or not. A separate popup on top with its own START
##   button would be dismissed separately, so a player still reading it would never have
##   signalled ready and would be dropped into a round already running. So the beat is PAGES in
##   the overlay and the every-round blurb is the last page: one thing to dismiss, one readiness
##   signal, and the final tap lands on the same text it always did.
##
## WHAT IS MEASURED HERE
##   1. copy coverage: all twelve live rounds have an entry, in both languages, with three
##      steps and a tip, and not one character outside ASCII. The reported phone draws emoji
##      as "unknown character" boxes and this is new copy, so it does not add to that pile.
##   2. that the new keys cannot collide with the eight single-player ones, and that those
##      eight are still there and still whole.
##   3. the paging: page one stands in for the blurb, the prompt reads CONTINUE while pages
##      remain and START on the last one, and each tap advances exactly one page.
##   4. that paging does not ready the player. This is the whole risk of the feature. Measured
##      on NetworkManager.players[id].ready - the state the host actually reads - and not on a
##      signal that could be missed.
##   5. that it is a FIRST-play beat: a second instance of the same round shows the blurb and
##      starts on one tap, and with hints turned off the beat never appears AND its key is not
##      consumed, so turning hints back on still teaches.
##   6. that the panel still fits at both reported device shapes, on every page and on the
##      longest page authored for any of the twelve in either language - measured as no clipped
##      lines, not just as a rect that happens to be inside the screen. This panel was audited
##      in P3 for a one-line blurb; these pages are longer than that.
##   7. that AutoPlay still gets through. AutoPlayManager dismisses this overlay by emitting the
##      ClickCatcher's pressed signal once per frame; a page that ate those presses without ever
##      reaching the dismissal would stall every autoplay run on the instruction screen.
##   8. that Tagalog really renders in Tagalog, and that the tip prefix here is the emoji-free
##      one rather than the single-player bulb.
##
## NOT MEASURED HERE (needs the physical device)
##   That this copy draws with the bundled font on Android 8. What is proved here is that the
##   strings contain nothing outside ASCII; VerifyGlyphCoverage owns the font question.
##
## Usage:
##   godot --headless --path . res://tools/VerifyMPTutorialBeat.tscn

const PORT: int = 7817
## MP_CatchTheRain is the specimen for the same reason VerifyMPFeedback uses it: it is a
## reported round, it is player one of a pairing so its copy has a partner half to explain,
## and it builds without waiting on anything a headless run cannot supply.
const SPECIMEN: String = "res://scenes/multiplayer/MP_CatchTheRain.tscn"
const SPECIMEN_KEY: String = "mp_catch_the_rain"
## The two reported devices. Moto E5 Plus first.
const SHAPES: Array = [Vector2i(2160, 1080), Vector2i(2400, 1080)]
const STEPS_PER_GAME: int = 3
const PANEL_PATH: String = "CenterContainer/PanelContainer"
const LABEL_PATH: String = "CenterContainer/PanelContainer/VBoxContainer/Instructions"
const PROMPT_PATH: String = "CenterContainer/PanelContainer/VBoxContainer/StartPrompt"
## The panel's StyleBoxFlat expands 20 units past the Control's rect on every side, so the box
## the player sees is bigger than panel.size. Containment is checked against the drawn box.
const EXPAND_MARGIN: float = 20.0
## Named rather than counted: a collision that REPLACED one of these would keep the count at
## eight, and a single-player tutorial quietly swapped for a multiplayer one is the exact
## accident the mp_ prefix exists to prevent.
const SP_KEYS: Array = [
	"CatchTheRain", "FixLeak", "GreywaterSorter", "PlugTheLeak",
	"SwipeTheSoap", "QuickShower", "TimingTap", "TurnOffTap",
]

var results: Array = []
var game: MultiplayerMiniGameBase = null
var _scene_before: Node = null
var _shown_was: Array = []
var _hints_was: bool = true
var _lang_was_english: bool = false
var _mp_keys: Array[String] = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	# Newlines flattened: several details quote instruction copy, which carries its own line
	# breaks, and a row that spills onto a second line stops being one greppable row.
	var one_line: String = detail.replace("
", " | ")
	print("  %s %s%s" % ["PASS" if ok else "FAIL", label, "" if one_line.is_empty() else "  - " + one_line])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Become a device of the given shape. Four frames: the window write, the stretch recompute,
## the resize listeners, and whatever they deferred.
func _resize(size: Vector2i) -> void:
	get_window().size = size
	await _frames(4)


func _overlay() -> Control:
	return null if game == null or not is_instance_valid(game) else game.instruction_overlay


func _page_text() -> String:
	var overlay: Control = _overlay()
	if overlay == null:
		return ""
	var label: Label = overlay.get_node_or_null(LABEL_PATH) as Label
	return "" if label == null else label.text


func _prompt_text() -> String:
	var overlay: Control = _overlay()
	if overlay == null:
		return ""
	var prompt: Label = overlay.get_node_or_null(PROMPT_PATH) as Label
	return "" if prompt == null else prompt.text


## One tap on the overlay, through the same button a finger and AutoPlay both press.
func _tap() -> void:
	var overlay: Control = _overlay()
	if overlay == null:
		return
	var catcher: Button = overlay.get_node_or_null("ClickCatcher") as Button
	if catcher != null:
		catcher.pressed.emit()


## The readiness flag the HOST reads when it decides whether to start the round. Checked here
## rather than a signal because a missed connection would make every row below pass.
func _ready_flag() -> bool:
	var uid: int = multiplayer.get_unique_id()
	if not NetworkManager.players.has(uid):
		return false
	return bool(NetworkManager.players[uid].get("ready", false))


func _clear_ready() -> void:
	var uid: int = multiplayer.get_unique_id()
	if NetworkManager.players.has(uid):
		NetworkManager.players[uid]["ready"] = false


## The first character outside ASCII, with enough of its surroundings to find it in the source.
func _non_ascii(s: String) -> String:
	for i in range(s.length()):
		if s.unicode_at(i) > 127:
			return "U+%04X in \"%s\"" % [s.unicode_at(i), s.substr(maxi(i - 15, 0), 32)]
	return ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== VerifyMPTutorialBeat - the first-play how-to-play beat in co-op ===")

	_lang_was_english = Localization.is_english()
	_hints_was = bool(SaveManager.get_setting("show_hints", true))
	_shown_was = TutorialManager.shown_tutorials.duplicate()
	SaveManager.set_setting("show_hints", true)
	_scene_before = get_tree().current_scene

	_copy_coverage()

	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	# Every mp_ key this run touches is forgotten up front so the gating rows cannot pass
	# because a previous run already consumed them, and restored wholesale in _teardown().
	for key in _mp_keys:
		TutorialManager.shown_tutorials.erase(key)
	_check("none of the twelve first-play keys is marked seen in the state this run starts from",
		not (SPECIMEN_KEY in TutorialManager.shown_tutorials),
		"shown_tutorials now holds %d entries" % TutorialManager.shown_tutorials.size())

	await _paging_flow()
	await _second_play()
	await _hints_off()
	await _geometry()
	await _autoplay_gets_through()
	await _localization()

	await _teardown()
	var failed: int = results.count(false)
	print("")
	print("  -- on-device row, not measurable headless --")
	print("     that these pages draw with the bundled font on the Moto E5 Plus. Everything")
	print("     above proves the copy is ASCII, which is what makes that likely rather than")
	print("     certain; VerifyGlyphCoverage owns the font itself.")
	print("")
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


## The twelve keys the LIVE rounds resolve to, derived the way _mp_game_key() derives them -
## off the SCRIPT filename - and read out of LevelSets rather than off a glob of the folder,
## because LevelSets is what the lobby launches. The five MiniGame_*.gd next door are the
## legacy family and are reachable only from DebugMultiplayer.
func _live_keys() -> Array[String]:
	var keys: Array[String] = []
	for level_set in LevelSets.LEVEL_SETS:
		for slot in ["player1_game", "player2_game"]:
			var scene_path: String = str(level_set.get(slot, ""))
			if scene_path == "":
				continue
			var script_path: String = scene_path.replace("scenes/", "scripts/").replace(".tscn", ".gd")
			var key: String = "mp_" + script_path.get_file().trim_suffix(".gd").trim_prefix("MP_").to_snake_case()
			if not keys.has(key):
				keys.append(key)
	return keys


## 1 and 2. The copy itself: is there an entry for every live round, is it shaped like the
## single-player entries the same popup code reads, is any of it going to draw as a box, and
## has any of it landed on top of a single-player key.
func _copy_coverage() -> void:
	print("")
	print("  -- copy for all twelve live rounds --")
	_mp_keys = _live_keys()
	_check("LevelSets still lists twelve distinct live rounds, so the counts below mean something",
		_mp_keys.size() == 12, "%d keys: %s" % [_mp_keys.size(), str(_mp_keys)])

	var missing: Array = []
	var bad_shape: Array = []
	var bad_ascii: Array = []
	var lang_mismatch: Array = []
	for key in _mp_keys:
		if not TutorialManager.tutorials.has(key):
			missing.append(key)
			continue
		var entry: Dictionary = TutorialManager.tutorials[key]
		for lang in ["en", "tl"]:
			if not entry.has(lang):
				bad_shape.append("%s/%s absent" % [key, lang])
				continue
			var d: Dictionary = entry[lang]
			var steps: Array = d.get("steps", [])
			var title: String = str(d.get("title", "")).strip_edges()
			var tip: String = str(d.get("tip", "")).strip_edges()
			if title == "" or tip == "" or steps.size() != STEPS_PER_GAME:
				bad_shape.append("%s/%s title=%d steps=%d tip=%d"
					% [key, lang, title.length(), steps.size(), tip.length()])
			var texts: Array = [title, tip]
			for step in steps:
				texts.append(str(step.get("text", "")).strip_edges())
			for t in texts:
				if str(t) == "":
					bad_shape.append("%s/%s holds an empty string" % [key, lang])
				var offender: String = _non_ascii(str(t))
				if offender != "":
					bad_ascii.append("%s/%s %s" % [key, lang, offender])
		if entry.has("en") and entry.has("tl"):
			var n_en: int = (entry["en"].get("steps", []) as Array).size()
			var n_tl: int = (entry["tl"].get("steps", []) as Array).size()
			if n_en != n_tl:
				lang_mismatch.append("%s en=%d tl=%d" % [key, n_en, n_tl])

	_check("every live round has a first-play entry filed under its own key",
		missing.is_empty(), "without one: %s" % str(missing))
	_check("every entry has both languages, a title, three steps and a tip",
		bad_shape.is_empty(), "%d problems: %s" % [bad_shape.size(), str(bad_shape)])
	# The reported phone renders unicode emoji as "unknown character" boxes. The eight
	# single-player entries above this block are full of them; this new copy is not, and this
	# row is what keeps it that way when someone adds a thirteenth game.
	_check("not one character of the new copy is outside ASCII, so none of it can draw as a box",
		bad_ascii.is_empty(), "%d offenders: %s" % [bad_ascii.size(), str(bad_ascii)])
	_check("Tagalog was translated step for step rather than truncated",
		lang_mismatch.is_empty(), str(lang_mismatch))

	var collided: Array = []
	var lost: Array = []
	for key in SP_KEYS:
		if not TutorialManager.tutorials.has(key):
			lost.append(key)
	for key in _mp_keys:
		if SP_KEYS.has(key):
			collided.append(key)
	_check("the mp_ prefix keeps the new keys clear of the eight single-player ones",
		collided.is_empty(), str(collided))
	_check("and all eight single-player entries are still there",
		lost.is_empty(), "missing: %s" % str(lost))
	_check("the dictionary holds exactly the eight old entries plus twelve new ones",
		TutorialManager.tutorials.size() == SP_KEYS.size() + _mp_keys.size(),
		"%d entries for %d + %d expected"
			% [TutorialManager.tutorials.size(), SP_KEYS.size(), _mp_keys.size()])


## Specimen setup. The round is opened by hand rather than through the lobby: the base gates
## _ready() on is_multiplayer_connected(), which host_game() satisfies on its own, and then
## waits behind the instruction overlay for a tap - which is the thing under test here, so
## unlike VerifyMPFeedback this file does NOT force game_active and does not skip the wait.
func _open_specimen(forget_key: bool) -> bool:
	if forget_key:
		TutorialManager.shown_tutorials.erase(SPECIMEN_KEY)
	_clear_ready()
	var packed := load(SPECIMEN) as PackedScene
	if packed == null:
		return false
	game = packed.instantiate() as MultiplayerMiniGameBase
	get_tree().root.add_child(game)
	# The base resolves the round through get_tree().current_scene in five places, and
	# AutoPlayManager finds the overlay the same way, so the slot has to be handed over.
	get_tree().current_scene = game
	NetworkManager.clear_shared_target()
	# _ready() awaits a frame of its own before it builds anything. Waited out in real time
	# because headless runs uncapped and a frame count is not a duration.
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var overlay: Control = _overlay()
		if overlay != null and overlay.visible:
			return true
	return false


## Dismissing the overlay starts a six-second coroutine ON THE ROUND: "if the partner never
## signals ready, force-start the countdown". Left in flight it resumes after the specimen has
## been freed and reports a call into a freed instance, so it is run out here instead - clock
## sped up rather than waited on, with game_active already true so the force-start is inert.
func _drain_host_fallback() -> void:
	if game == null or not is_instance_valid(game):
		return
	if not game._instruction_dismissed:
		return
	game.game_active = true
	var was: float = Engine.time_scale
	Engine.time_scale = 30.0
	await get_tree().create_timer(7.0).timeout
	Engine.time_scale = was
	await _frames(2)


func _close_specimen() -> void:
	await _drain_host_fallback()
	if game != null and is_instance_valid(game):
		# current_scene back FIRST: freeing the node it points at leaves the tree holding a
		# freed pointer, and the next section in this same process reads it.
		get_tree().current_scene = _scene_before
		get_tree().root.remove_child(game)
		game.free()
	game = null
	await _frames(2)


## 3 and 4. The paging, and the one thing a paging tap must never do.
func _paging_flow() -> void:
	print("")
	print("  -- first play: the pages, and what a page tap must not do --")
	if not await _open_specimen(true):
		_check("the round opens with its instruction overlay up", false, "overlay never appeared")
		return
	_check("the round opens with its instruction overlay up", true,
		"pages=%d" % game._tutorial_pages.size())

	_check("the specimen resolves to the key this copy is filed under",
		game._mp_game_key() == "catch_the_rain" and SPECIMEN_KEY == "mp_" + game._mp_game_key(),
		"_mp_game_key() returned \"%s\"" % game._mp_game_key())

	var blurb: String = game.get_instructions()
	var pages: Array = game._tutorial_pages.duplicate()
	_check("the beat is three taught pages plus the every-round blurb",
		pages.size() == STEPS_PER_GAME + 1, "%d pages" % pages.size())
	if pages.size() != STEPS_PER_GAME + 1:
		await _close_specimen()
		return
	_check("the last page IS the blurb, so the tap that starts the round lands where it always did",
		str(pages[pages.size() - 1]) == blurb,
		"last page %d chars, blurb %d chars" % [str(pages[pages.size() - 1]).length(), blurb.length()])
	# A fourth tap in front of a round that is already slow to start is what P4(c) exists to
	# remove, so the tip rides along on the third taught page instead of getting its own.
	_check("the tip rides on the last taught page rather than costing a fourth tap",
		str(pages[2]).contains(Localization.get_text("mp_tutorial_tip_prefix")),
		"page three ends: \"%s\"" % str(pages[2]).substr(maxi(str(pages[2]).length() - 40, 0)))
	# Validity, not regression: if page one were the blurb the whole beat would be invisible
	# and every row below would pass without anything new being shown to anybody.
	_check("page one shows a taught line and not the blurb",
		_page_text() == str(pages[0]) and _page_text() != blurb,
		"on screen: \"%s\"" % _page_text().substr(0, 60))
	_check("the prompt reads CONTINUE while pages remain, not START",
		_prompt_text() == Localization.get_text("mp_tap_to_continue"),
		"prompt: \"%s\"" % _prompt_text())

	var taps: int = 0
	var texts: Array = []
	var prompts: Array = []
	var readied_early: bool = false
	var hidden_early: bool = false
	while taps < 10 and not game._instruction_dismissed:
		_tap()
		taps += 1
		await _frames(1)
		if not game._instruction_dismissed:
			texts.append(_page_text())
			prompts.append(_prompt_text())
			if _ready_flag():
				readied_early = true
			if not _overlay().visible:
				hidden_early = true

	_check("it takes exactly four taps to get through the beat on a first play",
		taps == STEPS_PER_GAME + 1, "%d taps" % taps)
	_check("each tap advanced exactly one page",
		texts == [str(pages[1]), str(pages[2]), blurb],
		"%d pages seen, first 24 chars each: %s" % [texts.size(), str(_heads(texts))])
	# The whole risk of the feature in one row. A tap that only pages must not reach
	# set_local_player_ready(): the host starts the round six seconds after it sees that flag,
	# so a peer that readied on page one is force-started while still reading page two.
	var ready_detail: String = "players[%d].ready %s" % [
		multiplayer.get_unique_id(),
		"went true mid-beat" if readied_early else "stayed false for every paging tap",
	]
	_check("no tap that only pages ever signals readiness", not readied_early, ready_detail)
	_check("no tap that only pages hides the overlay", not hidden_early)
	_check("the tap on the last page does signal readiness", _ready_flag(),
		"players[%d].ready=%s" % [multiplayer.get_unique_id(), str(_ready_flag())])
	_check("the prompt turned to START exactly on the last page, and not before",
		prompts == [
			Localization.get_text("mp_tap_to_continue"),
			Localization.get_text("mp_tap_to_continue"),
			Localization.get_text("tap_to_start"),
		],
		"prompts after each tap: %s" % str(prompts))

	var hidden: bool = false
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not _overlay().visible:
			hidden = true
			break
	_check("the last tap dismisses the overlay for good", hidden,
		"overlay visible=%s after the fade" % str(_overlay().visible))
	await _close_specimen()


func _heads(texts: Array) -> Array:
	var out: Array = []
	for t in texts:
		out.append(str(t).substr(0, 24))
	return out



## 5. That it is a FIRST-play beat. A second instance of the same round must go straight to the
## blurb on one tap - a "tutorial" that reappears every round is the intro-cutscene bug in P6,
## and this one would cost three extra taps at the head of every round of a twelve-round set.
func _second_play() -> void:
	print("")
	print("  -- second play: the beat is spent --")
	# Deliberately NOT forgetting the key: what is under test is that _paging_flow() marking it
	# is what suppresses the beat here.
	_check("the key was marked seen by the first play, which is what should suppress it now",
		SPECIMEN_KEY in TutorialManager.shown_tutorials,
		"shown_tutorials holds %d entries" % TutorialManager.shown_tutorials.size())
	if not await _open_specimen(false):
		_check("the round still opens on a second play", false, "overlay never appeared")
		return
	_check("the round still opens on a second play", true)

	var blurb: String = game.get_instructions()
	_check("no pages were built the second time",
		game._tutorial_pages.is_empty(), "%d pages" % game._tutorial_pages.size())
	_check("the overlay shows the every-round blurb straight away",
		_page_text() == blurb, "on screen: \"%s\"" % _page_text().substr(0, 60))
	_check("and the prompt says START rather than CONTINUE",
		_prompt_text() == Localization.get_text("tap_to_start"),
		"prompt: \"%s\"" % _prompt_text())

	var taps: int = 0
	while taps < 6 and not game._instruction_dismissed:
		_tap()
		taps += 1
		await _frames(1)
	_check("one tap starts the round, exactly as before this feature existed", taps == 1,
		"%d taps" % taps)
	_check("that one tap signals readiness", _ready_flag())
	await _close_specimen()


## And that the hints setting still means what it says. should_show_tutorial() reads
## show_hints, so a player who turned hints off must not get the beat - AND the key must not be
## consumed while it is off, or turning hints back on would teach them nothing.
func _hints_off() -> void:
	print("")
	print("  -- hints off: no beat, and the key survives for when they are turned back on --")
	SaveManager.set_setting("show_hints", false)
	TutorialManager.shown_tutorials.erase(SPECIMEN_KEY)
	_check("the setting is the only thing suppressing the beat in this section",
		not (SPECIMEN_KEY in TutorialManager.shown_tutorials)
			and not TutorialManager.should_show_tutorial(SPECIMEN_KEY),
		"key marked=%s should_show=%s"
			% [str(SPECIMEN_KEY in TutorialManager.shown_tutorials),
				str(TutorialManager.should_show_tutorial(SPECIMEN_KEY))])
	if not await _open_specimen(false):
		_check("the round opens with hints off", false, "overlay never appeared")
		SaveManager.set_setting("show_hints", true)
		return
	_check("the round opens with hints off", true)

	_check("with hints off no pages are built",
		game._tutorial_pages.is_empty(), "%d pages" % game._tutorial_pages.size())
	_check("the blurb is shown on its own, as it was before this feature",
		_page_text() == game.get_instructions(),
		"on screen: \"%s\"" % _page_text().substr(0, 60))
	# The trap: marking the key while the beat was never shown would silently burn the one
	# first play the player has, so turning hints back on would teach them nothing.
	_check("the key is NOT consumed while hints are off, so turning them back on still teaches",
		not (SPECIMEN_KEY in TutorialManager.shown_tutorials))

	var taps: int = 0
	while taps < 6 and not game._instruction_dismissed:
		_tap()
		taps += 1
		await _frames(1)
	_check("and it is still one tap to start", taps == 1, "%d taps" % taps)
	await _close_specimen()
	SaveManager.set_setting("show_hints", true)


## The longest page any of the twelve rounds could ever put on this label, in either language.
## Composed exactly the way _build_first_play_pages() composes it, tip included - the tip is
## appended to the third taught page, which is what makes that page the tall one.
func _longest_authored_page() -> Dictionary:
	var best: Dictionary = {"key": "", "lang": "", "text": ""}
	var prefix: String = Localization.get_text("mp_tutorial_tip_prefix")
	for key in _mp_keys:
		var entry: Dictionary = TutorialManager.tutorials.get(key, {})
		for lang in ["en", "tl"]:
			var data: Dictionary = entry.get(lang, {})
			var steps: Array = data.get("steps", [])
			var tip: String = str(data.get("tip", "")).strip_edges()
			for i in range(steps.size()):
				var text: String = str(steps[i].get("text", "")).strip_edges()
				if i == steps.size() - 1 and tip != "":
					text += "\n\n" + prefix + tip
				if text.length() > str(best["text"]).length():
					best = {"key": key, "lang": lang, "text": text}
	return best


func _force_page(text: String) -> void:
	var overlay: Control = _overlay()
	if overlay == null:
		return
	var label: Label = overlay.get_node_or_null(LABEL_PATH) as Label
	if label != null:
		label.text = text


## How many lines the words currently in the label wrap to. The panel's height follows this and
## not the character count, so it is what two page shapes are compared on.
func _line_count() -> int:
	var overlay: Control = _overlay()
	if overlay == null:
		return 0
	var label: Label = overlay.get_node_or_null(LABEL_PATH) as Label
	return 0 if label == null else label.get_line_count()


## "" when the page is safe, otherwise the reason it is not. Two separate failures, because they
## fail differently: a panel bigger than the screen, and a label whose box is too short for the
## words in it. AUTOWRAP_WORD_SMART means longer copy grows the panel downward until the
## CenterContainer runs out of room, and then it stops growing and starts hiding lines - so a
## rect that is inside the viewport is NOT on its own evidence that the text is readable.
func _fit_problem() -> String:
	var overlay: Control = _overlay()
	if overlay == null:
		return "no overlay"
	var panel: Control = overlay.get_node_or_null(PANEL_PATH) as Control
	var label: Label = overlay.get_node_or_null(LABEL_PATH) as Label
	if panel == null or label == null:
		return "panel or label missing"
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = Rect2(panel.get_global_transform_with_canvas().origin, panel.size)
	var box: Rect2 = rect.grow(EXPAND_MARGIN)
	var out_of_bounds: bool = (
		box.position.x < -0.5 or box.position.y < -0.5
		or box.end.x > vp.x + 0.5 or box.end.y > vp.y + 0.5
	)
	if out_of_bounds:
		return "drawn panel %.0f,%.0f to %.0f,%.0f in a %.0fx%.0f viewport" % [
			box.position.x, box.position.y, box.end.x, box.end.y, vp.x, vp.y]
	var lines: int = label.get_line_count()
	var drawn: int = label.get_visible_line_count()
	if drawn < lines:
		return "only %d of %d wrapped lines are drawn" % [drawn, lines]
	return ""


## 6. The panel at both reported device shapes. P3 audited this overlay while it held one line of
## blurb; a taught page is three or four times that, and the VBox has a 600-unit minimum width
## with no maximum, so from here on it is the words that set the panel's height.
func _geometry() -> void:
	print("")
	print("  -- the panel at both reported device shapes, on every page --")
	var longest: Dictionary = _longest_authored_page()
	var longest_text: String = str(longest["text"])
	for shape in SHAPES:
		await _resize(shape)
		if not await _open_specimen(true):
			_check("the round opens at %dx%d" % [shape.x, shape.y], false, "overlay never appeared")
			continue
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var pages: Array = game._tutorial_pages.duplicate()
		var blurb: String = game.get_instructions()
		print("     %dx%d window, %.0fx%.0f viewport units, %d pages"
			% [shape.x, shape.y, vp.x, vp.y, pages.size()])

		var bad: Array = []
		for i in range(pages.size()):
			_force_page(str(pages[i]))
			await _frames(2)
			var problem: String = _fit_problem()
			if problem != "":
				bad.append("page %d: %s" % [i + 1, problem])
		_check("at %dx%d every page of this round's beat is fully drawn inside the screen"
			% [shape.x, shape.y], bad.is_empty(), str(bad))

		# One round's pages passing says nothing about the other eleven, and the panel is shared,
		# so the worst case authored anywhere goes through the same label.
		_force_page(longest_text)
		await _frames(2)
		var worst: String = _fit_problem()
		_check("at %dx%d the longest page authored for ANY of the twelve fits too"
			% [shape.x, shape.y], worst.is_empty(),
			"%s/%s, %d chars%s" % [str(longest["key"]), str(longest["lang"]),
				longest_text.length(), "" if worst.is_empty() else " - " + worst])
		# Validity: with no pages built, the rows above would have walked an empty list and
		# passed without one line of the beat ever reaching the label.
		_check("the rows above measured the whole beat at this shape rather than an empty list",
			pages.size() == STEPS_PER_GAME + 1, "%d pages measured" % pages.size())
		# The panel's height follows wrapped LINES, not character count. The blurb turns out to be
		# the longer STRING of the two - it carries its own newlines and the formatted numbers - so
		# what this section adds to P3's audit is not a longer page but a differently shaped one:
		# a taught line, a blank line, and a tip underneath. Both counts are printed so the
		# relationship is on the record rather than assumed.
		var lines_longest: int = _line_count()
		_force_page(blurb)
		await _frames(2)
		_check("that tallest page is a wrapped multi-line block and not one short line",
			lines_longest >= 3,
			"longest page %d chars over %d wrapped lines; blurb %d chars over %d"
				% [longest_text.length(), lines_longest, blurb.length(), _line_count()])
		await _close_specimen()


## 7. That AutoPlay still gets through. AutoPlayManager._process_mp_auto_play() dismisses this
## overlay by emitting the ClickCatcher's pressed signal once per frame while the round is
## inactive, so a beat that ate those presses without ever reaching the dismissal would strand
## every autoplay run - and the long unattended runs are how the session logs this whole task is
## built from get produced. The real function is called here, not a stand-in for it.
func _autoplay_gets_through() -> void:
	print("")
	print("  -- AutoPlay pages through the beat on its own --")
	if not await _open_specimen(true):
		_check("the round opens for the autoplay pass", false, "overlay never appeared")
		return
	var pages: int = game._tutorial_pages.size()
	# Validity: with no pages built this section would prove only that autoplay can dismiss a
	# one-page overlay, which it always could.
	_check("the beat is actually in autoplay's way for this pass",
		pages == STEPS_PER_GAME + 1, "%d pages" % pages)

	var spent: int = 0
	while spent < 30 and not game._instruction_dismissed:
		AutoPlayManager._try_dismiss_mp_instruction_overlay()
		spent += 1
		await _frames(1)

	_check("autoplay reaches the dismissal rather than paging forever",
		game._instruction_dismissed, "%d frames of pressing and still not dismissed" % spent)
	# One frame per page and no more: the presses are once-per-frame, so a page that swallowed a
	# press without advancing would show up here as a longer run, and a page that advanced twice
	# on one press as a shorter one.
	_check("it costs autoplay exactly one frame per page and nothing else",
		spent == STEPS_PER_GAME + 1,
		"%d frames for %d pages" % [spent, STEPS_PER_GAME + 1])
	_check("and the round it dismissed is a round autoplay has signalled ready for",
		_ready_flag(), "players[%d].ready=%s" % [multiplayer.get_unique_id(), str(_ready_flag())])
	await _close_specimen()


## 8. Tagalog. The default language of this build is Filipino, so the Tagalog half is not the
## edge case here - it is what most players will read. Asserted on the RENDERED page rather than
## on the presence of a key, because a key can exist and still be shadowed by an English string
## upstream of it.
func _localization() -> void:
	print("")
	print("  -- both languages, measured on what lands on the label --")
	for key in ["mp_tap_to_continue", "mp_tutorial_tip_prefix"]:
		_check("\"%s\" resolves to real copy rather than echoing its own key back" % key,
			Localization.has_text(key) and Localization.get_text(key) != key,
			"resolves to \"%s\"" % Localization.get_text(key))
	# The single-player prefix is "<bulb> TIP: " and that glyph is one of the boxes P6 is about.
	# This beat uses an emoji-free twin instead of borrowing it; the single-player one is left
	# alone because touching it is P6's business and not this item's.
	var prefix: String = Localization.get_text("mp_tutorial_tip_prefix")
	_check("the prefix the beat puts on the tip has nothing outside ASCII in it",
		_non_ascii(prefix) == "",
		"\"%s\" (single player still uses \"%s\")"
			% [prefix, Localization.get_text("tutorial_tip_prefix")])

	var seen: Dictionary = {}
	for lang in [Localization.Language.ENGLISH, Localization.Language.FILIPINO]:
		Localization.set_language(lang)
		await _frames(2)
		if not await _open_specimen(true):
			_check("the round opens in language %d" % int(lang), false, "overlay never appeared")
			continue
		seen[lang] = {"page": _page_text(), "prompt": _prompt_text()}
		await _close_specimen()
	if seen.size() != 2:
		return

	var en: Dictionary = seen[Localization.Language.ENGLISH]
	var tl: Dictionary = seen[Localization.Language.FILIPINO]
	_check("the taught page is rendered in Tagalog when the language is Filipino, not in English",
		str(en["page"]) != str(tl["page"]) and str(tl["page"]) != "",
		"en: \"%s\" / tl: \"%s\"" % [str(en["page"]).substr(0, 34), str(tl["page"]).substr(0, 34)])
	_check("the CONTINUE prompt is translated too rather than hardcoded",
		str(en["prompt"]) != str(tl["prompt"]) and str(tl["prompt"]) != "",
		"en: \"%s\" / tl: \"%s\"" % [str(en["prompt"]), str(tl["prompt"])])
	_check("neither rendered page is a raw key that leaked through a missing translation",
		not str(en["page"]).begins_with("mp_") and not str(tl["page"]).begins_with("mp_"),
		"en: \"%s\" / tl: \"%s\"" % [str(en["page"]).substr(0, 24), str(tl["page"]).substr(0, 24)])


## Everything this run touched, put back: the language, the hints setting, and above all the
## shown_tutorials list, which is persisted to the save file - a harness that left twelve keys
## marked would silently spend the first play of every multiplayer round on the dev machine.
func _teardown() -> void:
	Engine.time_scale = 1.0
	await _close_specimen()
	get_tree().current_scene = _scene_before
	Localization.set_language(
		Localization.Language.ENGLISH if _lang_was_english else Localization.Language.FILIPINO
	)
	SaveManager.set_setting("show_hints", _hints_was)
	TutorialManager.shown_tutorials.assign(_shown_was)
	TutorialManager._save_shown_tutorials()
	_check("the save state this run borrowed is handed back exactly as it was found",
		TutorialManager.shown_tutorials.size() == _shown_was.size()
			and bool(SaveManager.get_setting("show_hints", true)) == _hints_was
			and Localization.is_english() == _lang_was_english,
		"%d keys, show_hints=%s, english=%s"
			% [TutorialManager.shown_tutorials.size(),
				str(SaveManager.get_setting("show_hints", true)), str(Localization.is_english())])
	NetworkManager.clear_shared_target()
	GameManager.disconnect_multiplayer()
	await _frames(2)
