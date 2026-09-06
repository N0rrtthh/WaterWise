extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS "ROUND 2 STILL GETS A COUNTDOWN" HARNESS
## ═══════════════════════════════════════════════════════════════════
## Companion to tools/VerifyCountdownOnce.tscn, which locked in ONE countdown
## per round. This one measures the other half of that fix: that the per-round
## state actually CLEARS between rounds.
##
## NetworkManager keeps three pieces of per-round state that gate the countdown:
##
##     _ready_signal_emitted          # _check_all_players_ready() returns early
##     _countdown_started_this_round  # start_countdown() returns early
##     players[peer]["ready"]         # the readiness tally itself
##
## All three are cleared by _reset_round_status(). Before this fix that function
## was reachable only from start_multiplayer_game_pair() and _load_next_round() —
## NOT from GameManager._load_next_multiplayer_minigame(), which is the shipped
## round advance (start_next_minigame -> rpc("_load_next_multiplayer_minigame")).
##
## So from round 2 onward every flag was still latched at ROUND 1's values:
##   * _check_all_players_ready() bailed on `if _ready_signal_emitted: return`,
##     so the normal "both players ready" route never asked for a countdown;
##   * players[peer]["ready"] was still true, so the tally was meaningless;
##   * and once start_countdown() gained its own one-per-round guard, the host's
##     6 s partner-ready fallback was rejected too — leaving round 2 with NO
##     countdown at all and both players stuck on the waiting overlay.
##
## Fix: _load_next_multiplayer_minigame() now calls NetworkManager's
## _reset_round_status() directly (it runs on every peer via "call_local", and
## _reset_round_status is authority-only, so a local call is the correct pairing).
##
## Running it also exposed a second defect on the same code path. The choice of
## WHICH game comes next, and the random mode assignment, were both made inside the
## "call_local" RPC — i.e. once per peer, from each peer's own unseeded RNG. First
## measured run: the host loaded MP_MopFloor and the client loaded MP_FillAquarium
## from the same round advance. Fixed by moving the decision into a host-only
## advance_multiplayer_round() that broadcasts it as RPC arguments, the pattern
## NetworkManager._load_next_round() already used. Each process prints
## ROUND2_SCENE=<path> for a cross-log comparison, since neither process can see the
## other's scene from inside itself.
##
## Timeline — one real round, the real round advance, then a second real round:
##   t=0.5   both peers enter round 1
##   t=2.0   host dismisses instructions      t=3.0 client dismisses
##   t=9.0   sample the three flags — expect LATCHED (round 1 armed them)
##   t=10.0  host: GameManager.rpc("_load_next_multiplayer_minigame")
##   t=12.0  sample the three flags again — expect CLEARED
##   t=14.0  host dismisses round 2           t=15.0 client dismisses
##   t=22.0  assert round 2 ran a single clean countdown and started
##
## The t=9.0 sample is what makes the t=12.0 sample non-vacuous: flags that were
## never set would "pass" a cleared check while proving nothing.
##
## The t=8.0 discriminator: round 2's first countdown tick must arrive within 4 s
## of the local dismissal. The ready route fires immediately; the host's fallback
## fires at dismissal + 6 s. A round that only ever started via the fallback is
## a 6 s stall before every round, and is a FAIL here even though it "works".
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyRoundAdvance.tscn -- host
##   godot --headless --path . res://tools/VerifyRoundAdvance.tscn -- client

const HOST_IP: String = "127.0.0.1"
## 7784: 7777/7778, 7781/7782 and 7783 belong to the other multiplayer harnesses.
const PORT: int = 7784
const CONNECT_TIMEOUT: float = 20.0
const MP_SCENE: String = "res://scenes/multiplayer/MP_WashVegetables.tscn"
## Ticks at or after this timeline second belong to round 2. Round 1's countdown
## is done by ~t=7 and round 2's cannot begin before the t=14 dismissal, so the
## split sits in a 7-second dead zone rather than on a knife edge.
const ROUND2_FROM: float = 11.0
## Round 2 must get its countdown from the ready route, not from the host's 6 s
## partner-ready fallback.
const READY_ROUTE_MAX_DELAY: float = 4.0

var role: String = "host"
var results: Array = []

var ticks: Array = []            ## one {count, t} per round_starting emission
var game_started_count_r2: int = 0
var advance_seen: bool = false

## Flag samples: {ready_emitted, countdown_started, any_player_ready, sampled}
var latched: Dictionary = {"sampled": false}
var cleared: Dictionary = {"sampled": false}

var r1_active_at_sample: bool = false
var r1_scene: String = ""
var r2_scene: String = ""
var r2_node_id: int = 0
var r2_dismiss_t: float = -1.0
var t0: float = 0.0

var _detached: bool = false

func _ready() -> void:
	if not _detached:
		# This harness drives two change_scene_to_file()s (round 1 and the round
		# advance), each of which memdeletes the outgoing current_scene — which for
		# a tool-scene launch is this node. The timeline therefore runs on a twin
		# parented to /root. Deferred because /root is still busy setting up
		# children during this _ready().
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "RoundAdvanceProbe"
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
	print("  ROUND-ADVANCE / PER-ROUND-RESET HARNESS — role: %s  port: %d" % [role, PORT])
	print("═══════════════════════════════════════════════════════════")
	NetworkManager.round_starting.connect(_on_round_starting)
	if role == "host":
		_run_host()
	else:
		_run_client()

# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _finish() -> void:
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("  tick log: %s" % _tick_str())
	print("  ROUND1_SCENE=%s" % r1_scene)
	print("  ROUND2_SCENE=%s" % r2_scene)
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


func _now() -> float:
	return (Time.get_ticks_msec() / 1000.0) - t0


func _tick_str() -> String:
	var parts: Array = []
	for e in ticks:
		parts.append("%d@%.1fs" % [e["count"], e["t"]])
	return ", ".join(parts) if not parts.is_empty() else "(none)"


func _on_round_starting(count: int) -> void:
	ticks.append({"count": count, "t": _now()})


func _r2_ticks() -> Array:
	var out: Array = []
	for e in ticks:
		if e["t"] >= ROUND2_FROM:
			out.append(e)
	return out

# ── observation helpers ─────────────────────────────────────────────

func _mg() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var cs := tree.current_scene
	if cs and cs.has_method("_on_instruction_dismissed"):
		return cs
	return null


func _scene_path() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return "<null>"
	return tree.current_scene.scene_file_path


## Count the Timer children carrying start_game()'s per-round UI timer, matched on
## the connection start_game() makes rather than on a name (Timer.new() leaves the
## name auto-generated, so a duplicate is just another child).
func _ui_timer_count() -> int:
	var mg := _mg()
	if mg == null:
		return -1
	var n := 0
	var cb := Callable(mg, "_update_timer_display")
	for child in mg.get_children():
		if child is Timer and child.timeout.is_connected(cb):
			n += 1
	return n


## Read the three pieces of per-round state that gate the countdown. `players` is
## read for ANY peer still flagged ready, because a single stale entry is enough to
## make the readiness tally lie.
func _sample_flags(tag: String) -> Dictionary:
	var any_ready := false
	for pid in NetworkManager.players.keys():
		if bool(NetworkManager.players[pid].get("ready", false)):
			any_ready = true
	var d := {
		"sampled": true,
		"ready_emitted": bool(NetworkManager.get("_ready_signal_emitted")),
		"countdown_started": bool(NetworkManager.get("_countdown_started_this_round")),
		"any_player_ready": any_ready,
	}
	print(("  [%s] t=%.1fs %s: _ready_signal_emitted=%s"
		+ " _countdown_started_this_round=%s any_player_ready=%s")
		% [role, _now(), tag, str(d["ready_emitted"]), str(d["countdown_started"]),
			str(any_ready)])
	return d


func _bail_unless(anchored: Array, label: String) -> void:
	if anchored[0]:
		return
	_check(label, false)
	_finish()

# ── timeline steps ──────────────────────────────────────────────────

func _enter_round() -> void:
	NetworkManager.game_in_progress = true
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(MP_SCENE)
	print("  [%s] loading %s" % [role, MP_SCENE])


## Dismiss the instruction overlay the way a tap does — the handler is called
## directly so the harness does not depend on where the overlay lands on screen.
## Everything downstream of it is untouched production code.
func _dismiss(tag: String) -> void:
	var mg := _mg()
	if mg == null:
		_check("%s: the MP round scene was up to dismiss instructions on" % tag, false,
			"current_scene = %s" % _scene_path())
		return
	print("  [%s] dismissing %s at t=%.1fs" % [role, tag, _now()])
	# See VerifyCountdownOnce._dismiss: the first-play beat pages inside this overlay, and
	# only the last page signals readiness.
	var taps: int = 0
	while taps < 8 and not bool(mg.get("_instruction_dismissed")):
		mg.call("_on_instruction_dismissed")
		taps += 1
		await get_tree().process_frame
	print("  [%s] %d tap(s) to clear the overlay" % [role, taps])


func _dismiss_round2() -> void:
	var mg := _mg()
	if mg != null:
		r2_scene = _scene_path()
		r2_node_id = mg.get_instance_id()
		if not mg.game_started.is_connected(_on_game_started_r2):
			mg.game_started.connect(_on_game_started_r2)
	r2_dismiss_t = _now()
	await _dismiss("round 2")


func _on_game_started_r2() -> void:
	game_started_count_r2 += 1
	print("  [%s] round 2 game_started #%d at t=%.1fs"
		% [role, game_started_count_r2, _now()])


func _sample_latched() -> void:
	var mg := _mg()
	r1_active_at_sample = mg != null and bool(mg.get("game_active"))
	r1_scene = _scene_path()
	latched = _sample_flags("after round 1")


func _do_advance() -> void:
	# The shipped round advance. advance_multiplayer_round() is host-only: it picks
	# the next game and mode assignment and broadcasts them, so both peers load the
	# same scene. Before that fix each peer shuffled its own order inside the
	# call_local RPC and they diverged — compare ROUND2_SCENE across the two logs.
	advance_seen = true
	print("  [%s] calling the real round advance at t=%.1fs" % [role, _now()])
	GameManager.advance_multiplayer_round()


func _sample_cleared() -> void:
	cleared = _sample_flags("after the round advance")

# ── assertions ──────────────────────────────────────────────────────

func _assert_common() -> void:
	var mg := _mg()
	var r2 := _r2_ticks()
	var go := 0
	for e in r2:
		if e["count"] == 0:
			go += 1

	# Controls first — every check below is vacuous if round 1 never ran or the
	# advance never produced a second round scene.
	_check("control: round 1 actually started",
		r1_active_at_sample,
		"game_active at t=9s = %s scene = %s" % [str(r1_active_at_sample), r1_scene])
	_check("control: the round advance brought up a second round scene",
		r2_node_id != 0 and mg != null,
		"round2 scene = %s (round1 was %s)" % [r2_scene, r1_scene])

	# The non-vacuity half: round 1 must have LATCHED the state, or "cleared" below
	# would pass on state that was never set. _ready_signal_emitted and
	# _countdown_started_this_round are host-side by construction — both
	# _check_all_players_ready() and start_countdown() open with `if not is_host:
	# return` — so only the readiness tally, which IS mirrored to clients via
	# _sync_ready_status, is checked on the client.
	var latched_ok := bool(latched.get("sampled", false)) \
		and bool(latched.get("any_player_ready", false))
	if role == "host":
		latched_ok = latched_ok \
			and bool(latched.get("ready_emitted", false)) \
			and bool(latched.get("countdown_started", false))
	_check("round 1 latched the per-round state (so the reset has something to do)",
		latched_ok,
		"sampled=%s ready_emitted=%s countdown_started=%s any_player_ready=%s"
			% [str(latched.get("sampled", false)), str(latched.get("ready_emitted")),
				str(latched.get("countdown_started")),
				str(latched.get("any_player_ready"))])

	# THE fix under test.
	_check("the round advance cleared NetworkManager's per-round state",
		bool(cleared.get("sampled", false))
			and not bool(cleared.get("ready_emitted", true))
			and not bool(cleared.get("countdown_started", true))
			and not bool(cleared.get("any_player_ready", true)),
		("sampled=%s ready_emitted=%s countdown_started=%s any_player_ready=%s"
			+ " — latched flags leave round 2 with no countdown at all")
			% [str(cleared.get("sampled", false)), str(cleared.get("ready_emitted")),
				str(cleared.get("countdown_started")),
				str(cleared.get("any_player_ready"))])

	# Consequences, measured on round 2 itself.
	_check("round 2 got a countdown",
		r2.size() > 0, "%d ticks after t=%.0fs | %s" % [r2.size(), ROUND2_FROM, _tick_str()])
	_check("round 2's countdown emitted exactly 4 times (3,2,1,0)",
		r2.size() == 4, "%d emissions | %s" % [r2.size(), _tick_str()])
	_check("round 2 had exactly one GO tick",
		go == 1, "%d GO ticks" % go)
	_check("round 2 actually started",
		mg != null and bool(mg.get("game_active")),
		"game_active = %s scene = %s"
			% [(str(mg.get("game_active")) if mg else "<no scene>"), _scene_path()])
	_check("round 2's game_started fired exactly once",
		game_started_count_r2 == 1, "%d emissions" % game_started_count_r2)
	var tc := _ui_timer_count()
	_check("exactly one live ui_timer child on the round 2 node",
		tc == 1, "%d timers" % tc)

	# The route discriminator: ready route (immediate) vs the host's 6 s fallback.
	var first_delay := -1.0
	if not r2.is_empty() and r2_dismiss_t >= 0.0:
		first_delay = float(r2[0]["t"]) - r2_dismiss_t
	_check("round 2's countdown came from the ready route, not the 6 s fallback",
		first_delay >= 0.0 and first_delay < READY_ROUTE_MAX_DELAY,
		("first tick %.1fs after the local dismissal (limit %.1fs; the host fallback"
			+ " fires at +6.0s, which would stall every round)")
			% [first_delay, READY_ROUTE_MAX_DELAY])

# ── HOST ────────────────────────────────────────────────────────────

func _run_host() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_check("GameManager.host_game() succeeded", GameManager.host_game(PORT))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "client connected within %ds" % int(CONNECT_TIMEOUT)))
	var client_id: int = await multiplayer.peer_connected
	anchored[0] = true
	t0 = Time.get_ticks_msec() / 1000.0
	print("  [host] client %d connected — starting timeline" % client_id)

	# The real flow clears the stale per-round flags on every peer before the FIRST
	# round scene loads; this stands in for that, so round 1 starts from a clean
	# slate and the latched/cleared samples are about the ADVANCE, nothing else.
	NetworkManager.rpc("_reset_round_status")

	tree.create_timer(0.5).timeout.connect(_enter_round)
	tree.create_timer(2.0).timeout.connect(_dismiss.bind("round 1"))
	tree.create_timer(9.0).timeout.connect(_sample_latched)
	tree.create_timer(10.0).timeout.connect(_do_advance)
	tree.create_timer(12.0).timeout.connect(_sample_cleared)
	tree.create_timer(14.0).timeout.connect(_dismiss_round2)
	tree.create_timer(22.0).timeout.connect(_host_assert)
	tree.create_timer(25.0).timeout.connect(_finish)


func _host_assert() -> void:
	_assert_common()
	_check("control: the host really issued the round advance",
		advance_seen, "advance_seen = %s" % str(advance_seen))

# ── CLIENT ──────────────────────────────────────────────────────────

func _run_client() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_check("GameManager.join_game() succeeded", GameManager.join_game(HOST_IP, PORT))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "connected to host within %ds" % int(CONNECT_TIMEOUT)))
	await multiplayer.connected_to_server
	anchored[0] = true
	t0 = Time.get_ticks_msec() / 1000.0
	print("  [client] connected as peer %d — starting timeline"
		% multiplayer.get_unique_id())

	tree.create_timer(0.5).timeout.connect(_enter_round)
	# One second after the host, so the "both ready" route is what completes.
	tree.create_timer(3.0).timeout.connect(_dismiss.bind("round 1"))
	tree.create_timer(9.0).timeout.connect(_sample_latched)
	tree.create_timer(12.0).timeout.connect(_sample_cleared)
	tree.create_timer(15.0).timeout.connect(_dismiss_round2)
	tree.create_timer(22.0).timeout.connect(_assert_common)
	tree.create_timer(25.0).timeout.connect(_finish)

