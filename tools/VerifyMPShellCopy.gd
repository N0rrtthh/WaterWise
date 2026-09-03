extends Node

## ═══════════════════════════════════════════════════════════════════
## VERIFY: THE CO-OP SHELL'S OWN COPY
## ═══════════════════════════════════════════════════════════════════
## FIX 72 moved all 24 strings of the 12 MP_* games onto Localization. The FRAME around
## those games did not move: MultiplayerMiniGameBase builds the HUD, the pause menu, the
## waiting overlay, the countdown, the instruction overlay, the controls panel, the
## disconnect notice, the game-over screen and the round summary out of English literals
## in code. The language setting defaults to FILIPINO, so on a default install the player
## reads a Filipino instruction body inside an English frame.
##
## Three defect classes are measured here, all through the shell's OWN builders:
##   1. copy that ignores the language — every human-readable label is rendered twice,
##      once per language, and a label that comes out byte-identical is a label the
##      setting cannot reach;
##   2. desktop-only wording on an Android target — the instruction overlay ends with
##      "Click anywhere to start" (the SP path has said "TAP ANYWHERE TO START" for as
##      long as the tap_to_start key has existed);
##   3. copy that already HAS a translation nobody sees — round_transition_*,
##      multiplayer_final_score, multiplayer_rounds_survived, role_collector and
##      role_user are all in the table, and their only consumers (RoundTransition.gd,
##      MultiplayerGameOver.gd) are loaded solely by MultiplayerCoordinator, which its
##      own banner records as unreferenced.
##
## Nothing here reads a source file. Every string is pulled off a live Label or Button in
## a real instantiated round, and the marquee list below fails the run if a screen was
## never built — a missing screen must not pass as "no untranslated text found".
##
## Usage:
##   godot --headless --path <project> res://tools/VerifyMPShellCopy.tscn
## ═══════════════════════════════════════════════════════════════════

const SCENE: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const PORT: int = 7809

## Words that only make sense with a mouse and a keyboard.
const DESKTOP_ONLY: Array[String] = [
	"🖱️", "Click", "click", "mouse", "Mouse", "arrow key", "Arrow Key", "keyboard",
]

## English fragments that prove a screen actually got built. Checked against the ENGLISH
## pass only, so they stay valid after the copy is localized.
const MARQUEE: Array[String] = [
	"PAUSED", "RESUME", "QUIT", "CONTROLS", "GAME OVER", "ROUND COMPLETE",
	"Return to Lobby", "Waiting for partner", "Your Role", "Final Score",
	"Life Lost", "next round", "Team Score This Round", "Partner (Player",
	"YOUR RESULT", "Your Score",
]

## Human copy that is legitimately spelled the same in both languages would go here. It
## is empty on purpose: every string in this shell has a Filipino form.
const SAME_IN_BOTH: Array[String] = []

var results: Array[bool] = []
var _lang_was: int = 0
var _reported: Dictionary = {}


func _ready() -> void:
	print("\n=== VerifyMPShellCopy ===")
	await get_tree().process_frame
	_lang_was = Localization.current_language
	await _run()
	Localization.set_language(_lang_was as Localization.Language)
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## A string is HUMAN copy if it holds two or more letters once the digits, the punctuation
## and the emoji are taken out. " x3", "%02d:%02d" and "" are not; "GO!" is.
func _is_human(s: String) -> bool:
	var letters: int = 0
	for c in s:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			letters += 1
	return letters >= 2


## Pre-order walk of everything the player can read. Nodes already queued for deletion are
## skipped: _show_round_summary() frees the results screen and rebuilds it in the same
## frame, so the dying labels are still in the tree when the walk runs.
func _texts(node: Node, stage: String, out: Array[String]) -> void:
	if node.is_queued_for_deletion():
		return
	var t: String = ""
	if node is Label or node is Button or node is RichTextLabel:
		t = str(node.get("text"))
	if t.strip_edges() != "":
		out.append("%s|%s" % [stage, t])
	for child in node.get_children():
		_texts(child, stage, out)


## Boots a real round in one language and returns every readable string in it, stage by
## stage. The five overlays are built by _setup_multiplayer_ui() at boot, so only the
## screens that appear later have to be driven — and each is driven through the shell's
## own method, never by poking a Label.
func _collect(lang: int) -> Array[String]:
	var out: Array[String] = []
	Localization.set_language(lang as Localization.Language)
	await get_tree().process_frame
	var packed := load(SCENE) as PackedScene
	if packed == null:
		return out
	var game: Node = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while game.get("hud_layer") == null and waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	await _frames(3)
	if game.get("hud_layer") == null:
		game.queue_free()
		return out
	_texts(game, "boot", out)
	# The countdown's last tick. _on_countdown_tick() sets the label and only THEN awaits, so
	# the text is in place when the call returns; the round it would start a second later
	# does not matter because this instance is freed below.
	game._on_countdown_tick(0)
	await _frames(1)
	_texts(game.hud_layer, "countdown", out)
	# The local "I finished, my partner has not" screen, then the both-players summary that
	# replaces it in place.
	game._show_results_screen(true)
	await _frames(1)
	_texts(game.hud_layer, "results", out)
	game._show_round_summary(true, false, 20, 10)
	await _frames(1)
	_texts(game.hud_layer, "summary", out)
	# FIX 74 made the summary header conditional on the TEAM outcome, so both branches have to
	# be rendered: the mixed round for the ❌ FAIL token in the partner row, and the clean
	# round for the celebratory header. Reading only one of the two would let the other's copy
	# go untranslated unnoticed.
	game._show_round_summary(true, true, 20, 18)
	await _frames(1)
	_texts(game.hud_layer, "summary_clean", out)
	game._show_game_over_screen()
	await _frames(1)
	_texts(game.hud_layer, "gameover", out)
	# The partner-left notice. Two seconds after it is raised the shell returns to the lobby,
	# which would take this harness's own scene with it, so the instance is freed right after
	# the read and the pending continuation dies with it.
	game._on_player_left_session(0)
	await _frames(1)
	_texts(game.hud_layer, "disconnect", out)
	game.queue_free()
	await _frames(2)
	return out


func _preview(arr: Array[String], limit: int = 6) -> String:
	var shown: Array[String] = arr.slice(0, limit)
	var s: String = " / ".join(shown)
	if arr.size() > limit:
		s += " / … +%d more" % (arr.size() - limit)
	return s


func _run() -> void:
	_check("a session is open, which is what the shell gates on before it builds anything",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	var en: Array[String] = await _collect(Localization.Language.ENGLISH)
	var tl: Array[String] = await _collect(Localization.Language.FILIPINO)
	print("  rendered %d readable label(s) in English, %d in Filipino" % [en.size(), tl.size()])
	_check("both passes built the same screens, so the two lists line up label for label",
		en.size() == tl.size() and en.size() >= 30,
		"en %d / tl %d" % [en.size(), tl.size()])
	if en.size() != tl.size() or en.is_empty():
		_check("[!] the two passes cannot be compared, so no copy claim can be made here",
			false, "aborting the copy checks")
		return

	var joined_en: String = "\n".join(en)
	var joined_tl: String = "\n".join(tl)

	# Vacuity guard: a screen that never got built must fail the run, not pass it quietly.
	var missing: Array[String] = []
	for frag in MARQUEE:
		if not joined_en.contains(frag):
			missing.append(frag)
	_check("every screen under test actually got built and rendered",
		missing.is_empty(),
		"%d marquee string(s) never rendered: %s" % [missing.size(), _preview(missing, 20)])

	# 1. the setting reaches the frame, not just the games inside it
	var stuck: Array[String] = []
	for i in range(en.size()):
		var body: String = en[i].split("|", true, 1)[1] if en[i].contains("|") else en[i]
		if not _is_human(body) or SAME_IN_BOTH.has(body):
			continue
		if en[i] == tl[i] and not stuck.has(body):
			stuck.append(body)
	_check("the language setting reaches the co-op SHELL's copy, not only the games' copy",
		stuck.is_empty(),
		"%d string(s) rendered byte-identical in both languages: %s" % [stuck.size(), _preview(stuck, 30)])

	# 2. no desktop-only wording on a touch target
	var desktop: Array[String] = []
	for arr: Array[String] in [en, tl]:
		for entry in arr:
			for w in DESKTOP_ONLY:
				if entry.contains(w) and not desktop.has(entry):
					desktop.append(entry)
	_check("no co-op screen asks a phone player to click, mouse or press a key",
		desktop.is_empty(),
		"%d label(s): %s" % [desktop.size(), _preview(desktop, 4)])
	_check("the start prompt is the same touch wording the solo path already ships",
		joined_en.contains("TAP ANYWHERE TO START"),
		"tap_to_start is in the table; the co-op overlay did not use it")

	# 3. the identifiers the shell shows the player are translated, not passed through raw
	_check("the role line names the role in the player's language, not by its internal id",
		not joined_tl.contains("Collector") and not joined_tl.contains("User"),
		"the Filipino pass still shows the raw role id from NetworkManager.player_roles")
	_check("the win/fail token inside the summary rows is translated too",
		not joined_tl.contains("WIN") and not joined_tl.contains("FAIL"),
		"a translated row can still carry an English verdict token")

	# 4. nothing rendered with its placeholder intact
	var leftover: Array[String] = []
	for arr: Array[String] in [en, tl]:
		for entry in arr:
			var bad: bool = entry.contains("%d") or entry.contains("%s") or entry.contains("%.")
			if bad and not leftover.has(entry):
				leftover.append(entry)
	_check("no format placeholder survived into a rendered label",
		leftover.is_empty(),
		"%d label(s): %s" % [leftover.size(), _preview(leftover, 4)])

	# 5. the translations that already existed are now on the shipping path. Their only
	# consumers were RoundTransition.gd and MultiplayerGameOver.gd, both loaded solely by
	# MultiplayerCoordinator, which its own banner records as unreferenced.
	var shipped: Array[String] = []
	for key in ["multiplayer_final_score", "multiplayer_rounds_survived", "tap_to_start"]:
		var tl_form: String = Localization.get_text(key)
		var head: String = tl_form.split("%")[0].strip_edges()
		if head.length() >= 4 and not joined_tl.contains(head):
			shipped.append("%s (\"%s\")" % [key, head])
	_check("the co-op keys that were already in the table are the ones the round now shows",
		shipped.is_empty(),
		"%d key(s) still unreached by any shipping screen: %s" % [shipped.size(), _preview(shipped, 4)])
