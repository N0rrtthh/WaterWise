extends Node

## Does the Multiplayer page's ROUND TIMER actually time both peers' rounds?
##
## WHY THIS CONTROL EXISTS AND WHY IT IS NOT IN SETTINGS
##   P5 asked for the autoplay control to move off Settings onto the Multiplayer page
##   "alongside Ready/Auto Play/Start Game, plus a round-timer control there". The autoplay
##   half was already on that page - what Settings held was an UNSYNCED SECOND WRITER of the
##   same session state: the lobby's AutoPlayButton broadcasts through
##   rpc("_sync_auto_play_state") while Settings' checkbox called
##   AutoPlayManager.set_mp_auto_play_enabled() locally and told the partner nothing. So that
##   row is gone rather than duplicated, and the new round-timer control was built on the
##   Multiplayer page for the same reason: a round clock only means anything while a session
##   exists, and two peers on different clocks is the P1 pause race with a new symptom - one
##   player's timer hits zero while the other is still playing.
##
## WHAT IS MEASURED HERE (two processes, real ENet, real scene loads)
##   1. the control sits in the same column as Ready / Auto Play / Start Game, in that
##      reading order, and is a BaseButton - so MobileUIManager's 48dp touch floor covers it.
##      A SpinBox, which is what this nearly was, is not a BaseButton and would have shipped
##      as a 40-unit target on exactly the phones P3 was about.
##   2. tapping it cycles the authored step list and wraps back to Default.
##   3. the HOST's choice reaches the CLIENT's NetworkManager. This is the load-bearing row:
##      it is asserted in the client process, on a value the client never wrote.
##   4. a real round on BOTH peers is timed by that choice - game_duration AND the timer
##      bar's max_value AND the HUD label. max_value is what proves the override ran before
##      _setup_multiplayer_ui() read game_duration to size the bar, which is the one ordering
##      the fix depends on.
##   5. with the control untouched, the 30 s each scene authored is unchanged. The default is
##      0 = "leave the authored value alone", so a session that never opens the control is
##      byte-identical to before this control existed. Without this row every row above
##      could pass on a coincidence.
##   6. a CLIENT cannot set it: its button is disabled, its direct call is refused, and its
##      hand-rolled rpc() is dropped - checked on both sides of the wire, because
##      @rpc("authority") is enforced on the RECEIVING peer only and "call_local" would
##      otherwise let a client desync itself against a host that never agreed.
##   7. out-of-range values are pulled inside the advertised range rather than rejected, so
##      the two peers cannot disagree about whether a value was legal.
##   8. one change emits exactly one mp_round_seconds_changed; a repeat emits none.
##   9. reset_round_status() does NOT clear it - unlike the per-round "reading" flag, the
##      round length is session state and has to survive every round boundary.
##  10. Settings no longer writes any MP session state, and single player's base
##      (scripts/MiniGameBase.gd) cannot reach any of it. Both read off disk.
##
## Usage (two terminals, or tools/mp2.sh):
##   godot --headless --path . res://tools/VerifyMPRoundTimer.tscn -- host
##   godot --headless --path . res://tools/VerifyMPRoundTimer.tscn -- client

const HOST_IP: String = "127.0.0.1"
## 7827: clear of every port already claimed under tools/ (7781-7823).
const PORT: int = 7827
const CONNECT_TIMEOUT: float = 20.0
## A different specimen from VerifyMPReadingGrace's MP_WashVegetables, so the two harnesses
## cannot interfere through the shared tutorial state even if they are run at the same time.
const MP_SCENE: String = "res://scenes/multiplayer/MP_MopFloor.tscn"
const TUTORIAL_KEY: String = "mp_mop_floor"
const LOBBY_SCENE: String = "res://scenes/ui/MultiplayerLobby.tscn"

## What every one of the twelve MP scenes authors today, and therefore what the untouched
## default has to keep producing.
const AUTHORED: float = 30.0
## The value under test. In the step list, and far enough from AUTHORED that a stale bar
## cannot be mistaken for a fresh one.
const CHOSEN: float = 45.0

var role: String = "host"
var results: Array = []
var t0: float = 0.0
var _detached: bool = false
var _emissions: Array[float] = []
## Restored on the way out; see _park_tutorial_key().
var _key_was_spent: bool = false


func _ready() -> void:
	if not _detached:
		# change_scene_to_file() memdeletes the outgoing current_scene, and this harness IS
		# current_scene. The timeline therefore lives on a twin parented straight to /root.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "RoundTimerProbe"
		get_tree().root.add_child.call_deferred(twin)
		return
	_boot()


func _boot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "client":
			role = "client"
		elif arg == "host":
			role = "host"
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MP ROUND-TIMER HARNESS — role: %s  port: %d" % [role, PORT])
	print("═══════════════════════════════════════════════════════════")
	_park_tutorial_key()
	NetworkManager.mp_round_seconds_changed.connect(_on_emission)
	if role == "host":
		_run_host()
	else:
		_run_client()


## Mark the specimen's first-play beat as already seen, IN MEMORY ONLY, for the length of the
## run. Two reasons, and the second is the one that matters:
##   - determinism: with no beat to build, the round scene boots the same way whether or not
##     this machine had already played MP_MopFloor.
##   - no save-file race: should_show_tutorial() reads this in-memory array, so the beat never
##     builds, so _build_first_play_pages() never reaches its mark_tutorial_shown() call and
##     NEITHER peer writes waterwise_settings.json. VerifyMPReadingGrace has to give the host
##     sole ownership of that file precisely because it does write it; this harness sidesteps
##     the question by never causing a write at all.
func _park_tutorial_key() -> void:
	_key_was_spent = TUTORIAL_KEY in TutorialManager.shown_tutorials
	if not _key_was_spent:
		TutorialManager.shown_tutorials.append(TUTORIAL_KEY)
	print("  [%s] tutorial key %s was %s; parked as seen in memory for this run"
		% [role, TUTORIAL_KEY, "spent" if _key_was_spent else "unspent"])


func _restore_tutorial_key() -> void:
	if not _key_was_spent:
		TutorialManager.shown_tutorials.erase(TUTORIAL_KEY)


func _on_emission(seconds: float) -> void:
	_emissions.append(seconds)


# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail.replace("\n", " | ")])


func _finish() -> void:
	_restore_tutorial_key()
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  %s RESULT: %d passed, %d failed"
		% [role.to_upper(), results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	Engine.get_main_loop().quit(1 if failed > 0 else 0)


func _bail_unless(anchored: Array, label: String) -> void:
	if anchored[0]:
		return
	_check(label, false)
	_finish()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0 - t0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The live round, or null. Identified by a method only the MP base defines, so the lobby
## instance this harness also builds can never be mistaken for one.
func _mg() -> Node:
	var tree := _tree()
	if tree == null or tree.current_scene == null:
		return null
	var cs := tree.current_scene
	return cs if cs.has_method("_on_instruction_dismissed") else null


## Load the round the way _load_next_round() does, so the minigame boots as it does in a
## session. No tap follows, so the round never actually starts: game_duration is written in
## _ready() and the bar is sized in _setup_multiplayer_ui(), both ahead of any input, which is
## everything this harness needs to read.
func _enter_round() -> void:
	NetworkManager.game_in_progress = true
	_tree().change_scene_to_file(MP_SCENE)
	print("  [%s] loading %s at t=%.1fs" % [role, MP_SCENE, _now()])


## The whole point, measured on a real round scene on whichever peer calls it.
##
## max_value is the load-bearing half. game_duration alone would pass even if the override
## ran AFTER _setup_multiplayer_ui() had already sized the bar from the authored 30 - the
## player would then watch a 45 s round drain a bar calibrated for 30 and see it hit empty
## two thirds of the way through. The bar and the label are read from the tree, not from the
## script's own fields, so this is what a player would actually be looking at.
func _assert_round(expected: float, tag: String) -> void:
	var mg := _mg()
	_check("[%s] the round scene is up" % tag, mg != null,
		"current_scene=%s" % ("<null>" if _tree().current_scene == null
			else _tree().current_scene.name))
	if mg == null:
		return
	var got: float = float(mg.get("game_duration"))
	_check("[%s] the round is timed for %.0fs" % [tag, expected],
		is_equal_approx(got, expected), "game_duration=%.1f" % got)

	var bar := mg.find_child("TimerProgress", true, false) as ProgressBar
	_check("[%s] the timer bar exists" % tag, bar != null)
	if bar != null:
		# Proves the override landed BETWEEN _on_multiplayer_ready() and
		# _setup_multiplayer_ui(), which is the one ordering the fix depends on.
		_check("[%s] the timer BAR is calibrated for %.0fs, not for the authored length"
			% [tag, expected], is_equal_approx(bar.max_value, expected),
			"TimerProgress.max_value=%.1f" % bar.max_value)

	var lbl := mg.find_child("TimerLabel", true, false) as Label
	_check("[%s] the HUD label exists" % tag, lbl != null)
	if lbl != null:
		_check("[%s] the HUD label opens on %.0f" % [tag, expected],
			lbl.text == "%.0f" % expected, "TimerLabel.text=\"%s\"" % lbl.text)


# ── the control itself ──────────────────────────────────────────────

## Built from the shipping scene, not from a stub, and torn down again before the rounds load.
## Every row here is about the thing a player's thumb lands on.
func _lobby_checks() -> void:
	var lobby: Node = load(LOBBY_SCENE).instantiate()
	_tree().root.add_child(lobby)
	await _tree().process_frame
	await _tree().process_frame

	var btn: Button = lobby.get("round_timer_button")
	_check("the Multiplayer page has a round-timer control at all", btn != null)
	if btn == null:
		lobby.queue_free()
		return

	var ready_cb: Node = lobby.get("ready_checkbox")
	var auto_btn: Node = lobby.get("auto_play_button")
	var start_btn: Node = lobby.get("start_game_button")
	var same_column: bool = (
		ready_cb != null and auto_btn != null and start_btn != null
		and btn.get_parent() == ready_cb.get_parent()
		and btn.get_parent() == auto_btn.get_parent()
		and btn.get_parent() == start_btn.get_parent()
	)
	# "alongside Ready/Auto Play/Start Game" is the requirement, verbatim.
	_check("it sits in the same column as Ready / Auto Play / Start Game", same_column,
		"parents: round=%s ready=%s auto=%s start=%s" % [
			btn.get_parent().name if btn.get_parent() else "<none>",
			ready_cb.get_parent().name if ready_cb and ready_cb.get_parent() else "<none>",
			auto_btn.get_parent().name if auto_btn and auto_btn.get_parent() else "<none>",
			start_btn.get_parent().name if start_btn and start_btn.get_parent() else "<none>"])
	if same_column:
		# "who is playing, how, for how long, go" - a round length read after the button that
		# commits to it is a control the player has to go back for.
		_check("the reading order is Ready → Auto Play → Round → Start",
			ready_cb.get_index() < auto_btn.get_index()
			and auto_btn.get_index() < btn.get_index()
			and btn.get_index() < start_btn.get_index(),
			"indices ready=%d auto=%d round=%d start=%d" % [ready_cb.get_index(),
				auto_btn.get_index(), btn.get_index(), start_btn.get_index()])

	# The 48dp touch floor is applied by MobileUIManager._on_node_added(), which type-checks
	# for BaseButton and nothing else. This control was nearly a SpinBox, which is a Range,
	# not a BaseButton: it would have entered the tree unnoticed and shipped as a 40-unit
	# target on the two phones that reported P3. Driven through the product's own function
	# rather than asserted about, so it stays true if that function changes.
	_check("it is a BaseButton, so the touch-target floor mechanism sees it", btn is BaseButton)
	var was_mobile: bool = MobileUIManager.is_mobile
	MobileUIManager.is_mobile = true
	MobileUIManager.invalidate_button_min_size_cache()
	var floor_size: Vector2 = MobileUIManager._resolve_button_min_size()
	MobileUIManager._on_node_added(btn)
	_check("a mobile profile raises it to the %.0f-unit touch floor" % floor_size.y,
		btn.custom_minimum_size.y >= floor_size.y,
		"custom_minimum_size=%.0fx%.0f floor=%.0fx%.0f" % [btn.custom_minimum_size.x,
			btn.custom_minimum_size.y, floor_size.x, floor_size.y])
	MobileUIManager.is_mobile = was_mobile
	MobileUIManager.invalidate_button_min_size_cache()

	# Localization.get_text() push-warns and hands the KEY back when a string is missing, so
	# a caption is only proof the three new keys exist if it does not contain them.
	var caption: String = btn.text
	_check("the caption is translated, not a raw key", caption.find("mp_round_timer") == -1,
		"text=\"%s\"" % caption)

	if role == "host":
		_check("the host's control is enabled", not btn.disabled)
		_check("the untouched control reads as the scene default",
			caption.find(Localization.get_text("mp_round_timer_default")) != -1,
			"text=\"%s\"" % caption)
		# The step list, walked with real presses. The list ends by wrapping to Default, so a
		# player who overshoots can always tap back round to "leave it alone" - the value that
		# gives the shipped behaviour - without hunting for a reset.
		var walked: Array[float] = []
		for _i in range(lobby.ROUND_TIMER_STEPS.size()):
			lobby._on_round_timer_pressed()
			walked.append(NetworkManager.mp_round_seconds)
		var expected: Array[float] = [15.0, 30.0, 45.0, 60.0, 90.0, 120.0, 180.0, 0.0]
		_check("tapping cycles the step list and wraps back to Default",
			walked == expected, "walked %s; expected %s" % [str(walked), str(expected)])
		# A caption that says "Default" while the round runs 45 s is worse than no control.
		NetworkManager.set_mp_round_seconds(CHOSEN)
		await _tree().process_frame
		_check("the caption follows the value",
			btn.text.find("%ds" % int(CHOSEN)) != -1, "text=\"%s\"" % btn.text)
		NetworkManager.set_mp_round_seconds(0.0)
		await _tree().process_frame
	else:
		# The client is told by the control rather than finding out when its tap does nothing:
		# set_mp_round_seconds() refuses a client's write and the sync RPC is
		# @rpc("authority"), so a disabled button here is the truth about what the network
		# layer will accept, not a suggestion.
		_check("the client's control is disabled", btn.disabled)
		_check("the client is told why", btn.tooltip_text.strip_edges() != "",
			"tooltip=\"%s\"" % btn.tooltip_text)
		# And it mirrors the host's choice instead of claiming the default: the joiner is
		# brought onto the host's clock in _register_player(), so this reads right on a client
		# that was never near the control.
		_check("the client's control shows the HOST's %.0fs" % CHOSEN,
			btn.text.find("%ds" % int(CHOSEN)) != -1, "text=\"%s\"" % btn.text)

	lobby.queue_free()
	await _tree().process_frame


# ── host timeline ───────────────────────────────────────────────────

func _run_host() -> void:
	var tree := _tree()
	_check("GameManager.host_game() succeeded", GameManager.host_game(PORT))
	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "client connected within %ds" % int(CONNECT_TIMEOUT)))
	var client_id: int = await multiplayer.peer_connected
	anchored[0] = true
	t0 = Time.get_ticks_msec() / 1000.0
	print("  [host] client %d connected — starting timeline" % client_id)
	NetworkManager.rpc("_reset_round_status")

	tree.create_timer(0.3).timeout.connect(_lobby_checks)
	tree.create_timer(1.2).timeout.connect(_host_set_chosen)
	tree.create_timer(2.8).timeout.connect(_enter_round)
	tree.create_timer(4.2).timeout.connect(_assert_round.bind(CHOSEN, "chosen"))
	# The client's illegal attempts land at 2.4s; this reads the host AFTER them.
	tree.create_timer(4.6).timeout.connect(_host_authority_check)
	tree.create_timer(5.2).timeout.connect(_host_back_to_default)
	tree.create_timer(5.8).timeout.connect(_enter_round)
	tree.create_timer(7.2).timeout.connect(_assert_round.bind(AUTHORED, "default"))
	tree.create_timer(7.8).timeout.connect(_clamp_checks)
	tree.create_timer(8.4).timeout.connect(_signal_checks)
	tree.create_timer(9.0).timeout.connect(_round_boundary_check)
	tree.create_timer(9.6).timeout.connect(_static_checks)
	tree.create_timer(9.9).timeout.connect(_broadcast_shape_checks)
	tree.create_timer(10.2).timeout.connect(_finish)


func _host_set_chosen() -> void:
	_emissions.clear()
	NetworkManager.set_mp_round_seconds(CHOSEN)
	_check("the host's write takes on the host",
		is_equal_approx(NetworkManager.mp_round_seconds, CHOSEN),
		"mp_round_seconds=%.1f" % NetworkManager.mp_round_seconds)
	print("  [host] round timer set to %.0fs at t=%.1fs" % [CHOSEN, _now()])


## The other half of row 6. @rpc("authority") is enforced on the RECEIVING side, so the
## client's rpc() arrives here and is dropped by Godot before it reaches NetworkManager - an
## expected "Mismatching authority" error in this log is the evidence, not a fault.
func _host_authority_check() -> void:
	_check("a client cannot move the host off its own round clock",
		is_equal_approx(NetworkManager.mp_round_seconds, CHOSEN),
		"mp_round_seconds=%.1f after the client's refused attempts"
			% NetworkManager.mp_round_seconds)


func _host_back_to_default() -> void:
	NetworkManager.set_mp_round_seconds(0.0)
	print("  [host] round timer back to scene default at t=%.1fs" % _now())


## A hand-typed or stale value outside the advertised range is pulled inside rather than
## rejected: a refusal would leave the two peers disagreeing about whether it was legal, which
## is the failure this control was built to avoid. 0 is not clamped - it is the sentinel for
## "leave whatever the scene authored alone".
func _clamp_checks() -> void:
	var lo: float = NetworkManager.ROUND_SECONDS_MIN
	var hi: float = NetworkManager.ROUND_SECONDS_MAX
	var cases: Array = [
		[5.0, lo, "below the minimum comes up to it"],
		[999.0, hi, "far above the maximum comes down to it"],
		[-3.0, 0.0, "a negative reads as the scene default, not as a clamp to the minimum"],
		[0.0, 0.0, "zero passes through as the scene default"],
		[hi, hi, "the maximum itself is legal"],
		[lo, lo, "the minimum itself is legal"],
	]
	for c in cases:
		var got: float = NetworkManager.sanitize_round_seconds(float(c[0]))
		_check("clamp: %s" % c[2], is_equal_approx(got, float(c[1])),
			"%.0f → %.1f, expected %.1f" % [float(c[0]), got, float(c[1])])
	# Through the real entry point too, not only the helper: a caller that clamped on the way
	# in but stored the raw value would pass every row above.
	NetworkManager.set_mp_round_seconds(5.0)
	_check("the clamp is applied by the entry point the control calls, not just by the helper",
		is_equal_approx(NetworkManager.mp_round_seconds, lo),
		"set_mp_round_seconds(5) left mp_round_seconds=%.1f" % NetworkManager.mp_round_seconds)
	NetworkManager.set_mp_round_seconds(0.0)


## At 10 Hz-ish tap rates this hardly matters, but the signal is what any screen would listen
## to in order to re-caption itself, and an unguarded emit means a repeat of the same value
## re-runs every listener. The lobby's own caption refresh is one of them.
func _signal_checks() -> void:
	NetworkManager.set_mp_round_seconds(0.0)
	_emissions.clear()
	NetworkManager.set_mp_round_seconds(60.0)
	_check("one change emits exactly one signal, carrying that value",
		_emissions.size() == 1 and is_equal_approx(_emissions[0], 60.0),
		"emissions: %s" % str(_emissions))
	NetworkManager.set_mp_round_seconds(60.0)
	NetworkManager.set_mp_round_seconds(60.0)
	_check("a repeat of the same value emits nothing", _emissions.size() == 1,
		"emissions after two further writes of 60: %s" % str(_emissions))
	NetworkManager.set_mp_round_seconds(0.0)
	_check("returning to the default emits exactly one 0",
		_emissions.size() == 2 and is_zero_approx(_emissions[1]),
		"emissions: %s" % str(_emissions))


## Round length is SESSION state, unlike the per-round "still reading" flag that
## reset_round_status() exists to clear. If the reset took the round timer with it, the control
## would appear to work and then silently revert at the first round boundary - the kind of
## defect the P1 log data caught and visual inspection did not.
func _round_boundary_check() -> void:
	NetworkManager.set_mp_round_seconds(60.0)
	_check("the round timer really was set before the reset (guards a vacuous pass)",
		is_equal_approx(NetworkManager.mp_round_seconds, 60.0),
		"mp_round_seconds=%.1f" % NetworkManager.mp_round_seconds)
	NetworkManager.reset_round_status()
	_check("a round boundary does NOT clear the round timer",
		is_equal_approx(NetworkManager.mp_round_seconds, 60.0),
		"mp_round_seconds=%.1f after reset_round_status()" % NetworkManager.mp_round_seconds)
	NetworkManager.set_mp_round_seconds(0.0)


# ── read off disk ───────────────────────────────────────────────────

## Strip comments, so a row cannot pass or fail on prose. The file this matters most for is
## Settings.gd, where the removed row is now DESCRIBED in a comment that names the very call
## being searched for.
func _code_of(path: String) -> String:
	var raw: String = FileAccess.get_file_as_string(path)
	var out: String = ""
	for line in raw.split("\n"):
		var hash_at: int = line.find("#")
		out += (line if hash_at == -1 else line.substr(0, hash_at)) + "\n"
	return out


func _static_checks() -> void:
	var settings_code: String = _code_of("res://scenes/ui/Settings.gd")
	_check("Settings.gd was read", settings_code.strip_edges() != "")
	# The P5 requirement, measured: the unsynced second writer is gone, not merely hidden.
	_check("Settings no longer writes any MP session state",
		settings_code.find("set_mp_auto_play_enabled(") == -1
		and settings_code.find("mp_round_seconds") == -1,
		"set_mp_auto_play_enabled=%s mp_round_seconds=%s" % [
			settings_code.find("set_mp_auto_play_enabled(") != -1,
			settings_code.find("mp_round_seconds") != -1])

	# Single-player isolation. SP rounds run on scripts/MiniGameBase.gd, a different base
	# class; the override lives only in the multiplayer one. "Do not regress single player."
	var sp_code: String = _code_of("res://scripts/MiniGameBase.gd")
	_check("scripts/MiniGameBase.gd was read", sp_code.strip_edges() != "")
	_check("single player's base cannot reach the round timer",
		sp_code.find("round_seconds_for") == -1 and sp_code.find("mp_round_seconds") == -1,
		"round_seconds_for=%s mp_round_seconds=%s" % [
			sp_code.find("round_seconds_for") != -1, sp_code.find("mp_round_seconds") != -1])

	var mp_base: String = _code_of("res://scripts/multiplayer/MultiplayerMiniGameBase.gd")
	_check("the MP base is the only place the override is applied",
		mp_base.find("round_seconds_for(game_duration)") != -1)


## The slice of a file between "func <name>(" and the next top-level func. Comments are
## already stripped by _code_of(), which matters here: the prose above each of these calls
## names the very symbol being searched for.
func _body_of(code: String, fname: String) -> String:
	var at: int = code.find("func %s(" % fname)
	if at == -1:
		return ""
	var next: int = code.find("\nfunc ", at + 1)
	return code.substr(at, (code.length() - at) if next == -1 else (next - at))


## "Both peers time the same round" is made a property of the START BROADCAST rather than
## something inferred from an earlier sync that may have been sent before this client joined,
## or before a value the host changed while sitting in the lobby. Reliable RPCs travel one
## ordered channel, so a sync sent immediately ahead of a round-load broadcast is guaranteed
## to land first. Structural, because a two-process harness cannot observe the ORDER of two
## RPCs from the outside - what it can observe is row 4, that the value did arrive in time.
func _broadcast_shape_checks() -> void:
	var nm: String = _code_of("res://autoload/NetworkManager.gd")
	_check("NetworkManager.gd was read", nm.strip_edges() != "")
	for fname in ["start_multiplayer_game_pair", "_transition_to_next_round"]:
		var body: String = _body_of(nm, fname)
		_check("%s() re-states the round clock before it loads the round" % fname,
			body.find("rpc(\"_sync_mp_round_seconds\"") != -1,
			"body %d chars" % body.length())
	# A joiner has to arrive on the host's clock: the host can pick a length before anyone
	# connects, and nothing else would ever tell the newcomer about it.
	var reg: String = _body_of(nm, "_register_player")
	_check("_register_player() pushes the current round clock to the joiner",
		reg.find("_sync_mp_round_seconds") != -1, "body %d chars" % reg.length())


# ── client timeline ─────────────────────────────────────────────────

func _run_client() -> void:
	var tree := _tree()
	_check("GameManager.join_game() succeeded", GameManager.join_game(HOST_IP, PORT))
	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "connected to host within %ds" % int(CONNECT_TIMEOUT)))
	await multiplayer.connected_to_server
	anchored[0] = true
	t0 = Time.get_ticks_msec() / 1000.0
	print("  [client] connected as peer %d — starting timeline" % multiplayer.get_unique_id())

	# 2.0s: the host writes at 1.2s. Everything before that is the host walking its step list,
	# which this peer deliberately does not sample - a mirror asserted mid-cycle would be
	# testing the harness's own timing, not the sync.
	tree.create_timer(2.0).timeout.connect(_client_mirror)
	tree.create_timer(2.2).timeout.connect(_lobby_checks)
	tree.create_timer(2.4).timeout.connect(_client_illegal)
	tree.create_timer(2.8).timeout.connect(_enter_round)
	tree.create_timer(3.6).timeout.connect(_client_illegal_recheck)
	tree.create_timer(4.2).timeout.connect(_assert_round.bind(CHOSEN, "chosen"))
	tree.create_timer(5.8).timeout.connect(_enter_round)
	tree.create_timer(7.2).timeout.connect(_assert_round.bind(AUTHORED, "default"))
	tree.create_timer(9.6).timeout.connect(_static_checks)
	tree.create_timer(9.9).timeout.connect(_broadcast_shape_checks)
	tree.create_timer(10.2).timeout.connect(_finish)


## The load-bearing row: a value this process never wrote, read in this process.
func _client_mirror() -> void:
	_check("the HOST's choice reached this peer's NetworkManager",
		is_equal_approx(NetworkManager.mp_round_seconds, CHOSEN),
		"mp_round_seconds=%.1f, expected %.0f" % [NetworkManager.mp_round_seconds, CHOSEN])


## Both ways a client could get onto a clock the host never agreed to.
##
## The direct call is refused by set_mp_round_seconds(). The hand-rolled rpc() is the subtler
## one: @rpc("authority") stops the host from ACCEPTING it, but "call_local" means the client
## still runs the body on ITSELF - so without the sender check inside
## _sync_mp_round_seconds() this peer would sit alone on 999 s while the host timed 45. An
## expected "Mismatching authority" error appears in the HOST's log; that is the drop working.
func _client_illegal() -> void:
	NetworkManager.set_mp_round_seconds(999.0)
	_check("a client's direct write is refused",
		is_equal_approx(NetworkManager.mp_round_seconds, CHOSEN),
		"mp_round_seconds=%.1f after set_mp_round_seconds(999)"
			% NetworkManager.mp_round_seconds)
	NetworkManager.rpc("_sync_mp_round_seconds", 999.0)
	_check("a client's own call_local copy of the sync is refused too",
		is_equal_approx(NetworkManager.mp_round_seconds, CHOSEN),
		"mp_round_seconds=%.1f after rpc(\"_sync_mp_round_seconds\", 999)"
			% NetworkManager.mp_round_seconds)


## A round trip later: had the host accepted the rpc above, it would have broadcast 999 back
## to this peer by now and the row would fail here rather than pass by being read too early.
func _client_illegal_recheck() -> void:
	_check("and nothing came back from the host to say otherwise",
		is_equal_approx(NetworkManager.mp_round_seconds, CHOSEN),
		"mp_round_seconds=%.1f a round trip after the refused attempts"
			% NetworkManager.mp_round_seconds)
