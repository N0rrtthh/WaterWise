extends Node

## Can the host force-start a partner out of the first-play how-to-play beat?
##
## THE DEFECT
##   The beat (MultiplayerMiniGameBase._build_first_play_pages) pages three taught steps
##   through the instruction overlay ahead of the every-round blurb, and only the LAST page
##   signals readiness. That much was deliberate - one thing to dismiss, one readiness
##   signal - and its own docstring claims it stops a reader being "force-started into a
##   round it never said it was ready for". It does not, on its own. The host arms a
##   six-second force-start when IT finishes dismissing, and six seconds is nothing next to
##   three pages of instructions. The common shape is asymmetric: the phone's owner has
##   played before, taps straight through, and their partner is new. The new player's
##   overlay was then torn off mid-sentence by start_game() - and permanently, because the
##   tutorial key is marked shown when the pages are BUILT, not when they are read.
##
##   The fix is not a longer sleep. A peer part-way through the beat now says so
##   (NetworkManager.set_local_player_reading), which is the one thing the fallback could
##   not previously tell apart: a missing ready signal that is a lost packet, versus one
##   that is a person reading. Six seconds still applies to the packet case.
##
## WHAT IS MEASURED HERE (two processes, real ENet, real scene loads)
##   1. the old deadline really does elapse mid-read - otherwise every row below is vacuous
##   2. at that moment the round has NOT started, on either peer
##   3. the reader keeps every page: no page is skipped, and the overlay is still up
##   4. the round starts on the reader's last tap, not on a timer
##   5. the flag is cleared by that last tap, so it cannot hold the next round's fallback
##   6. the ordinary fallback is INTACT: with nobody reading, a partner that never readies
##      is still force-started at ~6 s. A fix that quietly disabled the safety net would
##      pass rows 1-5 and leave a hang in the tree.
##   7. single player cannot reach any of it
##
## Usage (two terminals, or tools/mp2.sh):
##   godot --headless --path . res://tools/VerifyMPReadingGrace.tscn -- host
##   godot --headless --path . res://tools/VerifyMPReadingGrace.tscn -- client

const HOST_IP: String = "127.0.0.1"
## 7823: clear of 7777/7778 (VerifyMultiplayer), 7781/7782 (VerifyReturnToLobby), 7783
## (VerifyCountdownOnce), 7817/7819 (the two P4 harnesses).
const PORT: int = 7823
const CONNECT_TIMEOUT: float = 20.0
## The same specimen VerifyCountdownOnce uses: player1_game of level set 1, so the round a
## real session hands player 1 first.
const MP_SCENE: String = "res://scenes/multiplayer/MP_WashVegetables.tscn"
const TUTORIAL_KEY: String = "mp_wash_vegetables"
## What the fallback was before this change, and still is when nobody is reading.
const OLD_DEADLINE: float = 6.0

var role: String = "host"
var results: Array = []
var t0: float = 0.0
var _detached: bool = false
## 0 while phase A is live, 1 once the round has been reset for phase B. Both roles set it,
## so _watch_active() can tell which round it is latching on either peer.
var _phase: int = 0
## Instance id of the round phase A latched. Phase B is only ever latched on a DIFFERENT
## round node: the reset that opens phase B happens while phase A is still on screen and
## still active, so a phase check alone re-latches the old round the same frame.
var _a_round_id: int = 0

## Phase A samples, taken on the timeline and asserted at the end so a missed sample is
## visible as a null rather than as a row that never ran.
var _pages_total: int = -1
var _pages_seen: Array[String] = []
var _sample_taken: bool = false
var _sample_active: bool = false
var _sample_page: int = -1
var _sample_overlay_up: bool = false
var _sample_reading_flag: bool = false
var _host_dismiss_t: float = -1.0
var _client_last_tap_t: float = -1.0
var _active_t: float = -1.0

## Phase B samples.
var _b_dismiss_t: float = -1.0
var _b_active_t: float = -1.0
var _b_reading_flag: bool = true

## Restored at the end. Only the host writes the save file; see _prepare_key().
var _key_was_spent: bool = false


func _ready() -> void:
	if not _detached:
		# change_scene_to_file() memdeletes the outgoing current_scene, and this harness IS
		# current_scene. The timeline therefore lives on a twin parented straight to /root.
		# Deferred because /root is still busy setting up children during this _ready().
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "ReadingGraceProbe"
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
	print("  READING-GRACE HARNESS — role: %s  port: %d" % [role, PORT])
	print("═══════════════════════════════════════════════════════════")
	_prepare_key()
	if role == "host":
		_run_host()
	else:
		_run_client()


## Make this a first play again. The host owns the save file: if both peers wrote it, the
## one that captured its "original" after the other had already cleared would restore the
## wrong value. The client only needs the in-memory array, which is what
## should_show_tutorial() actually reads.
func _prepare_key() -> void:
	_key_was_spent = TUTORIAL_KEY in TutorialManager.shown_tutorials
	TutorialManager.shown_tutorials.erase(TUTORIAL_KEY)
	if role == "host":
		TutorialManager._save_shown_tutorials()
	print("  [%s] tutorial key %s was %s; cleared for this run"
		% [role, TUTORIAL_KEY, "spent" if _key_was_spent else "unspent"])


## Hand the key back. The product marks it shown again the moment the pages are built, on
## both peers, so a machine where it was already spent ends exactly where it started.
func _restore_key() -> void:
	if role != "host":
		return
	if _key_was_spent:
		TutorialManager.mark_tutorial_shown(TUTORIAL_KEY)
	else:
		TutorialManager.shown_tutorials.erase(TUTORIAL_KEY)
		TutorialManager._save_shown_tutorials()


# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail.replace("\n", " | ")])


func _finish() -> void:
	_restore_key()
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


func _mg() -> Node:
	var tree := _tree()
	if tree == null or tree.current_scene == null:
		return null
	var cs := tree.current_scene
	return cs if cs.has_method("_on_instruction_dismissed") else null


# ── shared timeline ─────────────────────────────────────────────────

## Load the round through the same call _load_next_round() uses, so the minigame boots the
## way it does in a session.
func _enter_round() -> void:
	NetworkManager.game_in_progress = true
	_tree().change_scene_to_file(MP_SCENE)
	print("  [%s] loading %s at t=%.1fs" % [role, MP_SCENE, _now()])


## One tap. Records the page text it lands on so a skipped page is visible later, and
## returns false once the overlay has been dismissed for good.
func _tap() -> bool:
	var mg := _mg()
	if mg == null:
		return false
	if bool(mg.get("_instruction_dismissed")):
		return false
	if _pages_total < 0:
		var pages: Array = mg.get("_tutorial_pages")
		_pages_total = pages.size()
	var before: String = _page_text(mg)
	if before != "" and not _pages_seen.has(before):
		_pages_seen.append(before)
	mg.call("_on_instruction_dismissed")
	var after: String = _page_text(mg)
	if after != "" and not _pages_seen.has(after):
		_pages_seen.append(after)
	return true


func _page_text(mg: Node) -> String:
	var overlay: Control = mg.get("instruction_overlay") as Control
	if overlay == null:
		return ""
	var label: Label = overlay.get_node_or_null(
		"CenterContainer/PanelContainer/VBoxContainer/Instructions"
	) as Label
	return "" if label == null else label.text


func _overlay_up() -> bool:
	var mg := _mg()
	if mg == null:
		return false
	var overlay: Control = mg.get("instruction_overlay") as Control
	return overlay != null and overlay.visible


func _active() -> bool:
	var mg := _mg()
	return mg != null and bool(mg.get("game_active"))


## Latch the moment the round becomes playable, on whichever peer this is.
func _watch_active() -> void:
	while true:
		await _tree().process_frame
		if not _active():
			continue
		var mg := _mg()
		if mg == null:
			continue
		if _phase == 0:
			if _active_t < 0.0:
				_active_t = _now()
				_a_round_id = mg.get_instance_id()
				print("  [%s] round became playable at t=%.1fs" % [role, _active_t])
		elif _b_active_t < 0.0 and mg.get_instance_id() != _a_round_id:
			_b_active_t = _now()
			print("  [%s] phase B round became playable at t=%.1fs" % [role, _b_active_t])


# ── HOST ────────────────────────────────────────────────────────────

## The fast reader. Taps through every page as soon as the round is up, which is what arms
## the force-start - so the whole question is what that fallback then does to the partner.
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
	# The real flow clears the stale per-round flags on every peer before the round scenes
	# load; _ready_signal_emitted is one of them.
	NetworkManager.rpc("_reset_round_status")
	_watch_active()

	tree.create_timer(0.5).timeout.connect(_enter_round)
	tree.create_timer(2.0).timeout.connect(_host_read_fast)
	# 8.6 s: past the host's own dismissal plus the old 6 s deadline, with slack. Under the
	# old code the round is running here and the partner's overlay is already gone.
	tree.create_timer(8.6).timeout.connect(_sample)
	tree.create_timer(16.0).timeout.connect(_assert_phase_a)
	# Phase B: same scene, key now spent, so no beat and nobody reading.
	tree.create_timer(17.0).timeout.connect(_phase_b_reset)
	tree.create_timer(17.6).timeout.connect(_enter_round)
	tree.create_timer(19.0).timeout.connect(_phase_b_dismiss)
	tree.create_timer(28.0).timeout.connect(_assert_phase_b)
	tree.create_timer(29.0).timeout.connect(_finish)


func _host_read_fast() -> void:
	var taps: int = 0
	while _tap():
		taps += 1
		if taps > 8:
			break
	_host_dismiss_t = _now()
	print("  [host] read the whole beat in %d tap(s) at t=%.1fs — fallback armed"
		% [taps, _host_dismiss_t])
	_check("the host really did get through the beat and arm the fallback",
		taps >= 1 and _mg() != null and bool(_mg().get("_instruction_dismissed")),
		"%d tap(s); _instruction_dismissed=%s" % [taps, str(
			_mg() != null and bool(_mg().get("_instruction_dismissed")))])


func _phase_b_reset() -> void:
	_phase = 1
	NetworkManager.game_in_progress = false
	NetworkManager.reset_round_status()
	_check("the round reset clears the still-reading flag",
		not NetworkManager.any_player_still_reading(),
		"any_player_still_reading()=%s after reset_round_status()"
			% str(NetworkManager.any_player_still_reading()))


func _phase_b_dismiss() -> void:
	var taps: int = 0
	while _tap():
		taps += 1
		if taps > 8:
			break
	_b_dismiss_t = _now()
	_b_reading_flag = NetworkManager.any_player_still_reading()
	print("  [host] phase B dismissed in %d tap(s) at t=%.1fs (reading flag=%s)"
		% [taps, _b_dismiss_t, str(_b_reading_flag)])
	# Vacuity for phase B: if the beat had run again, the deadline under test would be the
	# 60 s grace and not the 6 s packet-loss fallback.
	_check("phase B really is a later play with no beat to read",
		taps == 1, "%d tap(s) to clear the overlay the second time" % taps)


## Taken on both peers at 8.6 s: the old deadline has passed and the reader is still reading.
func _sample() -> void:
	_sample_taken = true
	_sample_active = _active()
	_sample_overlay_up = _overlay_up()
	_sample_reading_flag = NetworkManager.any_player_still_reading()
	var mg := _mg()
	_sample_page = -1 if mg == null else int(mg.get("_tutorial_page"))
	print("  [%s] sample at t=%.1fs — active=%s overlay=%s page=%d reading_flag=%s"
		% [role, _now(), str(_sample_active), str(_sample_overlay_up), _sample_page,
			str(_sample_reading_flag)])


func _assert_phase_a() -> void:
	print("")
	print("  -- phase A: a slow reader against the host's force-start --")
	_check("the sample was actually taken", _sample_taken,
		"nothing was measured at 8.6s, so the rows below prove nothing")
	# VACUITY, split by role because neither peer can see the other's clock. The host knows
	# when it armed the fallback; the reader knows it was still mid-beat when that deadline
	# passed. If either were false the old code would not have force-started anyone here and
	# every row below would pass without the fix existing.
	if role == "host":
		var old_deadline_t: float = _host_dismiss_t + OLD_DEADLINE
		_check("the OLD deadline had already passed when the sample was taken",
			_host_dismiss_t >= 0.0 and old_deadline_t < 8.6,
			"armed at t=%.1fs, old deadline t=%.1fs, sampled at t=8.6s"
				% [_host_dismiss_t, old_deadline_t])
	else:
		_check("the reader really was still mid-beat at the sample (guards a vacuous pass)",
			_sample_overlay_up and _sample_page >= 0
				and _sample_page < maxi(_pages_total - 1, 1),
			"overlay up=%s, on page %d of %d at t=8.6s"
				% [str(_sample_overlay_up), _sample_page, _pages_total])
	# THE LOAD-BEARING ROW. Under the old code this is true on both peers.
	_check("the round has NOT started while a partner is still on a tutorial page",
		not _sample_active,
		"game_active=%s at t=8.6s (host armed its fallback at t=%.1fs, %.1fs before)"
			% [str(_sample_active), _host_dismiss_t, 8.6 - _host_dismiss_t])
	_check("the host knew a partner was reading rather than assuming a lost packet",
		_sample_reading_flag,
		"any_player_still_reading()=%s at the moment the old deadline had passed"
			% str(_sample_reading_flag))
	_check("the round did eventually start", _active_t > 0.0,
		"became playable at t=%.1fs" % _active_t)
	if role == "host":
		_check("it started later than the old six-second fallback would have started it",
			_active_t > _host_dismiss_t + OLD_DEADLINE,
			"playable t=%.1fs vs old forced start t=%.1fs"
				% [_active_t, _host_dismiss_t + OLD_DEADLINE])
	else:
		_check("it started on the reader's last tap and not on a timer",
			_active_t > 0.0 and _client_last_tap_t > 0.0
				and _active_t > _client_last_tap_t
				and _active_t - _client_last_tap_t < 4.0,
			"last tap t=%.1fs, playable t=%.1fs (%.1fs of countdown between them)"
				% [_client_last_tap_t, _active_t, _active_t - _client_last_tap_t])
		_check("the reader was shown every page of the beat, none skipped",
			_pages_total > 1 and _pages_seen.size() == _pages_total,
			"%d distinct pages rendered of %d built" % [_pages_seen.size(), _pages_total])
	_check("the still-reading flag is clear once the beat is done",
		not NetworkManager.any_player_still_reading(),
		"any_player_still_reading()=%s after both peers finished"
			% str(NetworkManager.any_player_still_reading()))


## The safety net itself. With the beat spent nobody is reading, so a partner that never
## readies must still be force-started on the ordinary six-second deadline - otherwise this
## change has swapped a torn-off tutorial for a round that never starts.
func _assert_phase_b() -> void:
	print("")
	print("  -- phase B: the ordinary lost-ready fallback, with nobody reading --")
	_check("nobody was flagged as reading in phase B", not _b_reading_flag,
		"any_player_still_reading()=%s at the phase B dismissal" % str(_b_reading_flag))
	_check("a partner that never readies is still force-started", _b_active_t > 0.0,
		"phase B became playable at t=%.1fs (dismissed t=%.1fs)"
			% [_b_active_t, _b_dismiss_t])
	var waited: float = _b_active_t - _b_dismiss_t
	# Upper bound is the fallback plus its 3x0.6 countdown and the GO hold, with slack; the
	# lower bound is what says it waited at all rather than starting on the spot.
	_check("and on the ordinary deadline, not the reading grace",
		_b_active_t > 0.0 and waited >= OLD_DEADLINE - 0.6 and waited <= OLD_DEADLINE + 4.0,
		"forced start %.1fs after the host dismissed (deadline %.1fs, grace %.0fs)"
			% [waited, OLD_DEADLINE, MultiplayerMiniGameBase.READING_GRACE_SECONDS])
	# The two deadlines have to be genuinely different numbers for phase A and phase B to be
	# measuring two different things.
	_check("the grace is a longer deadline than the packet-loss fallback",
		MultiplayerMiniGameBase.READING_GRACE_SECONDS
			> MultiplayerMiniGameBase.PARTNER_READY_FALLBACK_SECONDS,
		"grace %.0fs vs fallback %.0fs"
			% [MultiplayerMiniGameBase.READING_GRACE_SECONDS,
				MultiplayerMiniGameBase.PARTNER_READY_FALLBACK_SECONDS])
	_check("the fallback constant still is the six seconds this harness measured against",
		is_equal_approx(MultiplayerMiniGameBase.PARTNER_READY_FALLBACK_SECONDS, OLD_DEADLINE),
		"PARTNER_READY_FALLBACK_SECONDS=%.1f, harness OLD_DEADLINE=%.1f"
			% [MultiplayerMiniGameBase.PARTNER_READY_FALLBACK_SECONDS, OLD_DEADLINE])
	# Single player shares MiniGameBase, not this one, and reads no player dictionary at all.
	var sp: String = FileAccess.get_file_as_string("res://scripts/MiniGameBase.gd")
	_check("single player cannot reach the grace, the flag or the fallback",
		not sp.contains("READING_GRACE_SECONDS")
			and not sp.contains("set_local_player_reading")
			and not sp.contains("any_player_still_reading"),
		"MiniGameBase.gd is %d chars and mentions none of the three" % sp.length())


# ── CLIENT ──────────────────────────────────────────────────────────

## The slow reader. One page early, then a long pause across the old deadline, then the rest.
func _run_client() -> void:
	var tree := _tree()
	_check("GameManager.join_game() succeeded", GameManager.join_game(HOST_IP, PORT))
	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "connected to host within %ds" % int(CONNECT_TIMEOUT)))
	await multiplayer.connected_to_server
	anchored[0] = true
	t0 = Time.get_ticks_msec() / 1000.0
	print("  [client] connected as peer %d — starting timeline"
		% multiplayer.get_unique_id())
	_watch_active()

	tree.create_timer(0.5).timeout.connect(_enter_round)
	# One page at 2.5s, so the flag is set and the beat is visibly under way, then nothing
	# until 12.0s - 4.0s past the old forced start at ~8.0s.
	tree.create_timer(2.5).timeout.connect(_read_one_page)
	tree.create_timer(8.6).timeout.connect(_sample)
	tree.create_timer(12.0).timeout.connect(_finish_reading)
	tree.create_timer(16.0).timeout.connect(_assert_phase_a)
	# Phase B: enters the round and never taps, which is the lost-ready case the host's
	# ordinary fallback exists for.
	tree.create_timer(17.0).timeout.connect(_phase_b_client)
	tree.create_timer(17.6).timeout.connect(_enter_round)
	tree.create_timer(29.0).timeout.connect(_finish)


func _read_one_page() -> void:
	_tap()
	var mg := _mg()
	print("  [client] one page read at t=%.1fs — on page %d of %d"
		% [_now(), -1 if mg == null else int(mg.get("_tutorial_page")), _pages_total])
	_check("a first play really did build a multi-page beat here", _pages_total > 1,
		"%d pages built for %s" % [_pages_total, TUTORIAL_KEY])


func _finish_reading() -> void:
	var taps: int = 0
	while _tap():
		taps += 1
		if taps > 8:
			break
	_client_last_tap_t = _now()
	print("  [client] finished the beat at t=%.1fs after %d more tap(s)"
		% [_client_last_tap_t, taps])


func _phase_b_client() -> void:
	_phase = 1
	# The client only has to be present and silent in phase B: the host owes a forced start
	# to a partner whose ready signal never arrives, and this is that partner.
	print("  [client] phase B — entering the round and never tapping")
