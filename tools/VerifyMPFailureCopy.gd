extends Node

## ═══════════════════════════════════════════════════════════════════
## VERIFY: THE CO-OP FAILURE COPY
## ═══════════════════════════════════════════════════════════════════
## The brief asks for funny, readable failure states — "replace the bare FAILED with a
## short funny reaction". The SINGLEPLAYER path has them: MiniGameBase._get_result_line_for_key()
## resolves a two-beat line per game for both outcomes, and VerifyNarrativeCopy [7] keeps
## the bare verdict out of that path by sweeping every script under scenes/minigames.
##
## That sweep never covered the co-op path, and the co-op path never got the pass. Three
## screens in MultiplayerMiniGameBase still end a round with a verdict and nothing else:
##
##   1. _show_results_screen(false) — a LOST ROUND. The team still has lives, the next
##      round is still coming, and the screen says "GAME OVER!" in 72 px red. Wrong twice:
##      wrong information, and a bare verdict where the SP twin tells a joke.
##   2. _show_round_summary() — the header is an unconditional green "ROUND COMPLETE",
##      identical whether both players won or both players lost, and carries no reaction.
##   3. _show_game_over_screen() — the session end: "GAME OVER!" over "The team ran out
##      of lives!". Localized since FIX 73, still just the verdict.
##
## Every string below is read off a live Label in a real instantiated round, driven through
## the shell's own builders. The header checks compare the both-won build against the
## both-lost build instead of hardcoding copy, so they keep holding after a rewording.
##
## Usage:
##   godot --headless --path <project> res://tools/VerifyMPFailureCopy.tscn
## ═══════════════════════════════════════════════════════════════════

const SCENE: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const MP_DIR: String = "res://scripts/multiplayer"
const PORT: int = 7810

## The verdict that belongs only on the session-end screen.
const SESSION_VERDICT: Array[String] = ["GAME OVER", "TAPOS NA"]

## Words that only make sense with a mouse and a keyboard.
const DESKTOP_ONLY: Array[String] = [
	"🖱️", "Click", "click", "mouse", "Mouse", "arrow key", "keyboard",
]

## A reaction has to land in one glance on a phone. The longest SP line is 41 characters
## ("Rain hit concrete. Aim over the plants!"), so 64 leaves room for Filipino without
## letting a paragraph through.
const MAX_LEN: int = 64

var results: Array[bool] = []
var _lang_was: int = 0


func _ready() -> void:
	print("\n=== VerifyMPFailureCopy ===")
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


func _preview(arr: Array, limit: int = 5) -> String:
	var shown: Array = arr.slice(0, limit)
	var s: String = " / ".join(shown)
	if arr.size() > limit:
		s += " / … +%d more" % (arr.size() - limit)
	return s


## Every readable string under a node, in pre-order. Nodes already queued for deletion are
## skipped: _show_round_summary() frees the results screen and rebuilds it in the same
## frame, so the dying labels are still in the tree when the walk runs.
func _texts(node: Node, out: Array[String]) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Label or node is Button or node is RichTextLabel:
		var t: String = str(node.get("text")).strip_edges()
		if t != "":
			out.append(t)
	for child in node.get_children():
		_texts(child, out)


## The heading of a screen: the first Label in pre-order. Every one of the three builders
## adds its ColorRect first and its title Label next, so this is the title by construction.
func _heading(node: Node) -> Label:
	if node is Label and not node.is_queued_for_deletion():
		return node as Label
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var found: Label = _heading(child)
		if found != null:
			return found
	return null


## The height the stacked content actually occupies. The three builders all put their rows
## in one VBoxContainer inside a full-rect CenterContainer, so the VBox's own height is the
## content height — and a CenterContainer sizes its child to that child's minimum, so this
## is what the player's screen has to fit.
func _content_h(overlay: Node) -> float:
	if overlay == null:
		return 0.0
	if overlay is VBoxContainer and not overlay.is_queued_for_deletion():
		return (overlay as VBoxContainer).size.y
	for child in overlay.get_children():
		if child.is_queued_for_deletion():
			continue
		var h: float = _content_h(child)
		if h > 0.0:
			return h
	return 0.0


## The 12 co-op games, keyed the way the shell keys them: the script filename with the MP_
## prefix and the .gd suffix taken off, in snake_case. Derived here independently of the
## product so a wrong derivation on either side shows up as a failure rather than agreeing
## with itself.
func _game_keys() -> Array[String]:
	var keys: Array[String] = []
	var dir := DirAccess.open(MP_DIR)
	if dir == null:
		return keys
	for f in dir.get_files():
		if not f.begins_with("MP_") or not f.ends_with(".gd"):
			continue
		var base: String = f.trim_suffix(".gd").trim_prefix("MP_")
		if base != "":
			keys.append(base.to_snake_case())
	keys.sort()
	return keys


func _line(key: String) -> String:
	if Localization and Localization.has_text(key):
		return str(Localization.get_text(key)).strip_edges()
	return ""


func _run() -> void:
	var keys: Array[String] = _game_keys()
	var h_lost: float = 0.0
	var h_sum: float = 0.0
	var h_over: float = 0.0
	print("  co-op game keys (%d): %s" % [keys.size(), ", ".join(keys)])
	Localization.set_language(Localization.Language.ENGLISH)
	await get_tree().process_frame

	GameManager.host_game(PORT)
	await _frames(2)
	var packed := load(SCENE) as PackedScene
	if packed == null:
		_check("[0] the probe round loads", false, SCENE)
		return
	var game: Node = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while game.get("hud_layer") == null and waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	await _frames(3)
	if game.get("hud_layer") == null:
		_check("[0] the probe round builds its HUD", false, "hud_layer stayed null")
		game.queue_free()
		return

	# ── the lost round ────────────────────────────────────────────────
	game._show_results_screen(false)
	await _frames(1)
	var lost: Array[String] = []
	_texts(game.hud_layer, lost)
	var lost_head: String = ""
	var lost_overlay: Node = game.hud_layer.get_node_or_null("ResultsOverlay")
	if lost_overlay:
		var h: Label = _heading(lost_overlay)
		if h:
			lost_head = h.text.strip_edges()
	h_lost = _content_h(lost_overlay)

	var verdict_on_round: Array[String] = []
	for t in lost:
		for v in SESSION_VERDICT:
			if t.to_upper().contains(v) and not verdict_on_round.has(t):
				verdict_on_round.append(t)
	_check("[1] a lost ROUND is not announced as the end of the session",
			verdict_on_round.is_empty(),
			"%d label(s): %s" % [verdict_on_round.size(), _preview(verdict_on_round)])

	# The reaction the booted game should be showing. The key is derived from the scene's own
	# script, so this asserts the wiring, not just the presence of a table row.
	var my_key: String = ""
	var scr = game.get_script()
	if scr and scr.resource_path != "":
		my_key = scr.resource_path.get_file().trim_suffix(".gd").trim_prefix("MP_").to_snake_case()
	var want_fail: String = _line("mp_react_fail_%s" % my_key)
	_check("[2] the lost-round screen shows a reaction, not only a verdict",
			want_fail != "" and lost.has(want_fail),
			"key mp_react_fail_%s -> %s" % [my_key, "(undefined)" if want_fail == "" else "\"%s\"%s" % [want_fail, "" if lost.has(want_fail) else " NOT on screen"]])

	# ── the summary header, both lost vs both won ─────────────────────
	game._show_round_summary(false, false, 4, 6)
	await _frames(1)
	var sum_lost: Array[String] = []
	_texts(game.hud_layer, sum_lost)
	var head_lost: String = ""
	var lost_color: Color = Color.BLACK
	var ov: Node = game.hud_layer.get_node_or_null("ResultsOverlay")
	if ov:
		var hl: Label = _heading(ov)
		if hl:
			head_lost = hl.text.strip_edges()
			lost_color = hl.get_theme_color("font_color")
	h_sum = _content_h(ov)

	game._show_round_summary(true, true, 20, 18)
	await _frames(1)
	var head_won: String = ""
	ov = game.hud_layer.get_node_or_null("ResultsOverlay")
	if ov:
		var hw: Label = _heading(ov)
		if hw:
			head_won = hw.text.strip_edges()

	_check("[3] the summary header tells a wipe apart from a clean round",
			head_lost != "" and head_won != "" and head_lost != head_won,
			"lost=\"%s\" won=\"%s\"" % [head_lost, head_won])
	# 0.4/1.0/0.4 is the celebration green the builder applies unconditionally today.
	var still_green: bool = lost_color.g > 0.85 and lost_color.r < 0.6
	_check("[4] the header is not celebration-green when the team lost the round",
			not still_green,
			"font_color=(%.2f, %.2f, %.2f)" % [lost_color.r, lost_color.g, lost_color.b])

	# ── the session end ───────────────────────────────────────────────
	game._show_game_over_screen()
	await _frames(1)
	var over: Array[String] = []
	_texts(game.hud_layer, over)
	h_over = _content_h(game.hud_layer.get_node_or_null("GameOverOverlay"))
	var want_session: String = _line("mp_react_session_over")
	_check("[5] the session-end screen shows a reaction beyond the verdict",
			want_session != "" and over.has(want_session),
			"key mp_react_session_over -> %s" % ["(undefined)" if want_session == "" else "\"%s\"%s" % [want_session, "" if over.has(want_session) else " NOT on screen"]])

	# Control: a screen that was never built must not pass the sweeps above as "clean".
	var built: bool = false
	for t in over:
		if t.to_upper().contains("GAME OVER") or t.contains("TAPOS"):
			built = true
	_check("[6] control: the three failure screens were actually built",
			built and lost.size() >= 3 and sum_lost.size() >= 5,
			"lost=%d labels, summary=%d labels, session verdict present=%s" % [lost.size(), sum_lost.size(), built])

	game.queue_free()
	await _frames(2)

	# ── the table behind the screens ──────────────────────────────────
	var missing_fail: Array[String] = []
	var missing_win: Array[String] = []
	for k in keys:
		if _line("mp_react_fail_%s" % k) == "":
			missing_fail.append(k)
		if _line("mp_react_win_%s" % k) == "":
			missing_win.append(k)
	_check("[7] every co-op game has its own failure reaction",
			missing_fail.is_empty(),
			"%d of %d missing: %s" % [missing_fail.size(), keys.size(), _preview(missing_fail)])
	_check("[8] every co-op game has its own success reaction",
			missing_win.is_empty(),
			"%d of %d missing: %s" % [missing_win.size(), keys.size(), _preview(missing_win)])

	# Every key the three screens can reach, plus the two new headings.
	var all_keys: Array[String] = ["mp_react_session_over", "mp_round_lost", "mp_round_rough"]
	for k in keys:
		all_keys.append("mp_react_fail_%s" % k)
		all_keys.append("mp_react_win_%s" % k)

	Localization.set_language(Localization.Language.ENGLISH)
	await get_tree().process_frame
	var en: Dictionary = {}
	for k in all_keys:
		en[k] = _line(k)
	Localization.set_language(Localization.Language.FILIPINO)
	await get_tree().process_frame
	var tl: Dictionary = {}
	for k in all_keys:
		tl[k] = _line(k)

	var defined: Array[String] = []
	for k in all_keys:
		if str(en[k]) != "":
			defined.append(k)
	_check("[9] premise: the reaction table is populated",
			defined.size() == all_keys.size(),
			"%d of %d keys defined" % [defined.size(), all_keys.size()])

	var same: Array[String] = []
	for k in defined:
		if str(en[k]) == str(tl[k]):
			same.append("%s=\"%s\"" % [k, en[k]])
	_check("[10] every reaction reads in the player's language",
			same.is_empty(), "%d byte-identical: %s" % [same.size(), _preview(same)])

	# A blanket line pasted across all 12 would satisfy [7] and [8] while telling the player
	# nothing about the game they just lost.
	var seen: Dictionary = {}
	var dupes: Array[String] = []
	for k in defined:
		if not k.begins_with("mp_react_fail_") and not k.begins_with("mp_react_win_"):
			continue
		var v: String = str(en[k])
		if seen.has(v):
			dupes.append("%s == %s" % [k, seen[v]])
		else:
			seen[v] = k
	_check("[11] no two co-op games share a reaction line",
			dupes.is_empty(), "%d shared: %s" % [dupes.size(), _preview(dupes)])

	var too_long: Array[String] = []
	var desktop: Array[String] = []
	for k in defined:
		for lang_text in [str(en[k]), str(tl[k])]:
			if lang_text.length() > MAX_LEN:
				too_long.append("%s (%d)" % [k, lang_text.length()])
			for w in DESKTOP_ONLY:
				if lang_text.contains(w):
					desktop.append("%s: %s" % [k, w])
	_check("[12] every reaction fits one glance on a phone",
			too_long.is_empty(), "%d over %d chars: %s" % [too_long.size(), MAX_LEN, _preview(too_long)])
	_check("[13] no reaction assumes a mouse or a keyboard",
			desktop.is_empty(), "%d site(s): %s" % [desktop.size(), _preview(desktop)])

	# The three screens each grew a wrapped reaction Label. Every co-op scene is authored for a
	# 1152x648 viewport (its camera sits at 576,324), so 648 is the height the stacked content
	# has to fit — not the headless window's, which is far taller and would pass anything.
	const MP_AUTHORED_H: float = 648.0
	var tall: Array[String] = []
	for pair in [["lost round", h_lost], ["round summary", h_sum], ["session end", h_over]]:
		if float(pair[1]) > MP_AUTHORED_H:
			tall.append("%s %.0f px" % [pair[0], float(pair[1])])
	_check("[14] the reaction fits the authored co-op viewport without clipping",
			tall.is_empty() and h_lost > 0.0 and h_sum > 0.0 and h_over > 0.0,
			"lost=%.0f, summary=%.0f, session=%.0f (limit %.0f)" % [h_lost, h_sum, h_over, MP_AUTHORED_H])
