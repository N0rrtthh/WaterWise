extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VerifyMPCopy — the words all 12 multiplayer games show the player
## ═══════════════════════════════════════════════════════════════════════════════
## Every multiplayer round opens on an instruction overlay built from the child game's
## get_instructions(), and its HUD carries a controls panel built from
## get_controls_text(). Three things were wrong with that copy across the family:
##
## 1. None of it was localized. Not one of the 12 MP_*.gd files, nor
##    MultiplayerMiniGameBase.gd, ever touched Localization — while Localization defaults
##    to FILIPINO. A Filipino player, the thesis audience, entered co-op and got the only
##    fully English screens in the game.
##
## 2. Eight of the twelve controls panels read "🖱️ Click ..." and MP_CatchRainAquarium
##    told the player to "Use arrow keys or mouse", on a build whose target platform is a
##    low-end Android phone with no mouse and no arrow keys.
##
## 3. Numbers left over from retunes. MP_MopFloor promised tiles dirty "every 5 seconds"
##    with its timer at 8.0 and "Let 10 tiles stay dirty" with MAX_DIRTY_TILES at 12; and
##    the four collector games each promised a win for catching 10 of something, when what
##    they enforce is win_quota measured against team_score() — the SHARED G-Counter total,
##    which the partner's chore points also feed. The measurement below drives a real catch
##    loop with a partner contribution merged in and counts how many catches the round
##    actually lasts.
##
## The copy getters are pure functions of constants, so most of this needs no session and
## no tree: the scenes are instantiated and queried directly. Only the team-quota
## measurement opens a host, because it needs the G-Counter.

const PORT: int = 7808

## Wording that assumes hardware a phone does not have. Kept as fragments rather than
## whole words so "Clicking" and "mouse-over" are caught too.
const DESKTOP_ONLY: Array[String] = ["🖱️", "Click", "click", "mouse", "Mouse", "arrow key", "Arrow Key"]

## At least one of these has to be present, or the panel never tells a phone player how to
## touch anything.
const TOUCH_WORDS: Array[String] = ["👆", "Tap", "tap", "Drag", "drag", "Swipe", "swipe", "Hold", "hold"]

const GAMES: Array[String] = [
	"MP_CatchRainAquarium",
	"MP_CatchTheRain",
	"MP_CollectDishWater",
	"MP_CollectLaundryWater",
	"MP_CollectShowerWater",
	"MP_FillAquarium",
	"MP_FilterWater",
	"MP_FlushToilets",
	"MP_MopFloor",
	"MP_WashCar",
	"MP_WashVegetables",
	"MP_WaterPlants",
]

var results: Array = []


func _ready() -> void:
	print("\n=== VerifyMPCopy ===")
	await get_tree().process_frame
	await _run()
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


## One instance of a game, off the tree. The copy getters read only constants, so nothing
## has to be built, entered or connected to ask them what they say.
func _peek(game_name: String) -> Node:
	var packed := load("res://scenes/multiplayer/%s.tscn" % game_name) as PackedScene
	if packed == null:
		return null
	return packed.instantiate()


func _first_present(text: String, needles: Array[String]) -> String:
	for n in needles:
		if text.contains(n):
			return n
	return ""


## The line a fragment sits on, so a failure points at the wording instead of the file.
func _line_with(text: String, needle: String) -> String:
	for line in text.split("\n"):
		if line.contains(needle):
			return "\"%s\"" % line.strip_edges()
	return "\"%s\"" % needle


func _run() -> void:
	_language_pass()
	_touch_pass()
	_number_pass()
	_target_pass()
	await _team_quota_pass()


## ═══════════════════════════════════════════════════════════════════════════════
## Every string the overlay and the HUD show must follow the language setting
## ═══════════════════════════════════════════════════════════════════════════════
## Asserted on the RENDERED text, not on key presence: a key can exist in the table and
## still never reach the screen if the caller returns a literal, and Localization.get_text()
## falls back to the English value for a key that is missing one language, which would make
## a key-presence check pass on a half-translated entry.
func _language_pass() -> void:
	print("  ── the language setting reaches the co-op screens")
	var was: int = Localization.current_language
	for game_name in GAMES:
		var game := _peek(game_name)
		if game == null:
			_check("[!] %s did not load" % game_name, false)
			continue
		Localization.set_language(Localization.Language.ENGLISH)
		var en_instr: String = String(game.get_instructions())
		var en_ctrl: String = String(game.get_controls_text())
		Localization.set_language(Localization.Language.FILIPINO)
		var tl_instr: String = String(game.get_instructions())
		var tl_ctrl: String = String(game.get_controls_text())
		_check("%s: the instruction overlay follows the language setting" % game_name,
			en_instr != tl_instr and not tl_instr.is_empty(),
			"en %d chars, tl %d chars" % [en_instr.length(), tl_instr.length()])
		_check("%s: the controls panel follows the language setting" % game_name,
			en_ctrl != tl_ctrl and not tl_ctrl.is_empty(),
			"tl reads %s" % tl_ctrl.replace("\n", " / "))
		game.free()
	Localization.set_language(was as Localization.Language)


## ═══════════════════════════════════════════════════════════════════════════════
## Nothing may tell a phone player to use hardware the phone does not have
## ═══════════════════════════════════════════════════════════════════════════════
func _touch_pass() -> void:
	print("  ── the copy speaks to a touchscreen")
	var was: int = Localization.current_language
	Localization.set_language(Localization.Language.ENGLISH)
	for game_name in GAMES:
		var game := _peek(game_name)
		if game == null:
			continue
		var instr: String = String(game.get_instructions())
		var ctrl: String = String(game.get_controls_text())
		var bad_instr: String = _first_present(instr, DESKTOP_ONLY)
		var bad_ctrl: String = _first_present(ctrl, DESKTOP_ONLY)
		_check("%s: the instructions do not ask for a mouse or a keyboard" % game_name,
			bad_instr.is_empty(),
			"" if bad_instr.is_empty() else "%s in %s" % [bad_instr, _line_with(instr, bad_instr)])
		_check("%s: the controls panel does not ask for a mouse" % game_name,
			bad_ctrl.is_empty(),
			"" if bad_ctrl.is_empty() else "%s in %s" % [bad_ctrl, _line_with(ctrl, bad_ctrl)])
		_check("%s: the controls panel names a touch gesture" % game_name,
			not _first_present(ctrl, TOUCH_WORDS).is_empty(),
			ctrl.replace("\n", " / "))
		game.free()
	Localization.set_language(was as Localization.Language)


## ═══════════════════════════════════════════════════════════════════════════════
## The numbers in the copy must be the numbers the game enforces
## ═══════════════════════════════════════════════════════════════════════════════
func _number_pass() -> void:
	print("  ── the numbers in the copy are the numbers enforced")
	var was: int = Localization.current_language
	Localization.set_language(Localization.Language.ENGLISH)

	# MP_MopFloor: both of its numbers were left behind by a retune (timer 5.0 → 8.0,
	# allowance 10 → 12) and both were hardcoded into the string rather than read.
	var mop := _peek("MP_MopFloor")
	if mop != null:
		var consts: Dictionary = mop.get_script().get_script_constant_map()
		var allowance: int = int(consts.get("MAX_DIRTY_TILES", -1))
		var interval: int = int(consts.get("DIRTY_INTERVAL", -1.0))
		var text: String = String(mop.get_instructions())
		_check("MP_MopFloor: the dirty interval is a named constant, not a literal in two places",
			interval > 0, "DIRTY_INTERVAL=%d" % interval)
		_check("MP_MopFloor: the instructions state the dirty interval the timer runs on",
			interval > 0 and text.contains("every %d second" % interval),
			"DIRTY_INTERVAL=%ds, text says %s" % [interval, _line_with(text, "every ")])
		_check("MP_MopFloor: the instructions state the dirty-tile allowance the game enforces",
			allowance > 0 and text.contains("%d " % allowance),
			"MAX_DIRTY_TILES=%d, text says %s" % [allowance, _line_with(text, "stay dirty")])
		mop.free()

	# The four collector games each promised a win for catching 10 of something. What they
	# enforce is win_quota against team_score(), the SHARED total — see _team_quota_pass().
	for game_name in ["MP_CatchRainAquarium", "MP_CollectDishWater", "MP_CollectLaundryWater",
			"MP_CollectShowerWater"]:
		var game := _peek(game_name)
		if game == null:
			continue
		var text: String = String(game.get_instructions())
		var claim: String = _first_present(text, ["to win", "para manalo"])
		_check("%s: does not promise a win for a count of its own catches" % game_name,
			claim.is_empty(),
			"" if claim.is_empty() else "still says %s" % _line_with(text, claim))
		game.free()

	# MP_CatchRainAquarium's miss allowance IS honest — assert it so a future retune cannot
	# quietly desync it the way the others did.
	var rain := _peek("MP_CatchRainAquarium")
	if rain != null:
		var missed: int = int(rain.get_script().get_script_constant_map().get("MAX_MISSED", -1))
		var text: String = String(rain.get_instructions())
		_check("MP_CatchRainAquarium: the instructions state the miss allowance the game enforces",
			missed > 0 and text.contains("%d " % missed),
			"MAX_MISSED=%d, text says %s" % [missed, _line_with(text, "lose 1 life")])
		rain.free()
	Localization.set_language(was as Localization.Language)


## ═══════════════════════════════════════════════════════════════════════════════
## What the collector games actually enforce, measured
## ═══════════════════════════════════════════════════════════════════════════════
## win_quota is compared against team_score(), which is NetworkManager.get_total_score():
## the sum of every peer's G-Counter entry. In the shipping pairing (LevelSets) the partner
## is playing a chore game that pays 10-15 points an action into that same total, so the
## collector's round ends after however many catches are left once the partner has paid in
## — not after the 10 the overlay promised. A partner contribution is merged here through
## _merge_counter(), the same function the partner's points really arrive on.
func _team_quota_pass() -> void:
	print("  ── the collector win line is a shared team total, measured")
	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	var packed := load("res://scenes/multiplayer/MP_CollectDishWater.tscn") as PackedScene
	var game: Node = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while waited < 8.0 and (game.get("buckets") == null or (game.get("buckets") as Array).is_empty()):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1

	var quota: int = int(game.win_quota)
	var per_catch: int = 5
	NetworkManager.reset_g_counter()
	game.set("game_active", true)
	game.set("local_score", 0)

	# The partner has been mopping/flushing/washing for a while: 30 points in.
	var partner_id: int = 999999
	NetworkManager._merge_counter(partner_id, 30)
	var partner_points: int = NetworkManager.get_total_score()
	_check("a partner's points do land in the total this game measures its quota against",
		partner_points == 30, "team_score()=%d after a 30-point partner merge" % partner_points)

	var catches: int = 0
	while catches < 20 and bool(game.game_active):
		game.add_score(per_catch)
		catches += 1
		await get_tree().process_frame
	var solo_catches_promised: int = quota / per_catch
	_check("the round ends on the SHARED total, so the promised catch count is not what is enforced",
		catches < solo_catches_promised,
		"ended after %d catches, not the %d a solo count implies (quota %d team pts, partner had %d)"
			% [catches, solo_catches_promised, quota, partner_points])
	_check("and the shared total at that moment is the quota, not this peer's own score",
		NetworkManager.get_total_score() >= quota and int(game.local_score) < quota,
		"team=%d, local=%d, quota=%d"
			% [NetworkManager.get_total_score(), int(game.local_score), quota])

	game.set("game_active", false)
	get_tree().root.remove_child(game)
	game.free()
	await get_tree().process_frame


## ═══════════════════════════════════════════════════════════════════════════════
## The stated team target is the enforced team target, in both languages
## ═══════════════════════════════════════════════════════════════════════════════
## The collectors no longer promise a win for a count of their own catches; they state the
## shared total they really end on and the points each catch pays into it. Checked in both
## languages, because a translation that dropped a %d would either throw on the format call
## or render a figure that is not the one the game measures.
func _target_pass() -> void:
	print("  ── the stated team target is the enforced team target, in both languages")
	var was: int = Localization.current_language
	var per_const := {
		"MP_CatchRainAquarium": "POINTS_PER_DROP",
		"MP_CollectDishWater": "POINTS_PER_DROP",
		"MP_CollectLaundryWater": "POINTS_PER_CATCH",
		"MP_CollectShowerWater": "POINTS_PER_DROP",
	}
	for lang in [Localization.Language.ENGLISH, Localization.Language.FILIPINO]:
		Localization.set_language(lang)
		var code: String = Localization.get_language_code()
		for game_name in per_const.keys():
			var game := _peek(game_name)
			if game == null:
				continue
			var consts: Dictionary = game.get_script().get_script_constant_map()
			var per: int = int(consts.get(per_const[game_name], -1))
			var target: int = int(consts.get("TEAM_TARGET", -1))
			var text: String = String(game.get_instructions())
			_check("[%s] %s: states the +%d a catch pays and the %d team total it ends on"
					% [code, game_name, per, target],
				per > 0 and target > 0 and text.contains("+%d " % per) and text.contains("%d " % target),
				_line_with(text, "%d" % target))
			game.free()

		# A translation that lost a placeholder renders it literally. Cheap to check, and it
		# covers all 24 strings in both languages rather than only the ones with numbers.
		for game_name in GAMES:
			var game := _peek(game_name)
			if game == null:
				continue
			var instr: String = String(game.get_instructions())
			var ctrl: String = String(game.get_controls_text())
			_check("[%s] %s: no placeholder survived into the rendered copy" % [code, game_name],
				not instr.contains("%d") and not instr.contains("%s")
					and not ctrl.contains("%d") and not ctrl.contains("%s"),
				"instructions %d chars, controls %d chars" % [instr.length(), ctrl.length()])
			game.free()
	Localization.set_language(was as Localization.Language)

	# The two halves of the rain/aquarium bundle measure the SAME shared total. They held 50
	# and 100, so P1's round ended at half the target P2 was still working toward.
	var rain := _peek("MP_CatchRainAquarium")
	var tank := _peek("MP_FillAquarium")
	if rain != null and tank != null:
		var rc: Dictionary = rain.get_script().get_script_constant_map()
		var tc: Dictionary = tank.get_script().get_script_constant_map()
		var rain_target: int = int(rc.get("TEAM_TARGET", -1))
		var tank_target: int = int(tc.get("ADDS_TO_WIN", -1)) * int(tc.get("POINTS_PER_ADD", -1))
		_check("the two halves of the rain/aquarium bundle aim at the same shared total",
			rain_target > 0 and rain_target == tank_target,
			"MP_CatchRainAquarium %d vs MP_FillAquarium %d" % [rain_target, tank_target])
		rain.free()
		tank.free()
