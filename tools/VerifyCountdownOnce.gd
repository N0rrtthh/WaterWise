extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS "ONE COUNTDOWN PER ROUND" HARNESS
## ═══════════════════════════════════════════════════════════════════
## Every multiplayer round in the shipped flow is one of the twelve
## res://scenes/multiplayer/MP_*.tscn scenes (GameManager.multiplayer_minigames ->
## get_next_multiplayer_game), and all twelve extend MultiplayerMiniGameBase. Its
## _on_instruction_dismissed() does two things:
##
##     NetworkManager.set_local_player_ready()        # -> _check_all_players_ready()
##     ...
##     if NetworkManager.is_server():                 # HOST FALLBACK
##         await get_tree().create_timer(6.0).timeout
##         if not game_active:
##             NetworkManager.start_countdown()
##
## The fallback exists for a real case — the client's ready RPC is lost, so no
## countdown ever starts — but it bypasses the guard that protects the normal
## route. _check_all_players_ready() is idempotent (`if _ready_signal_emitted:
## return`); start_countdown() itself was not:
##
##     func start_countdown() -> void:
##         if not is_host: return
##         rpc("_execute_countdown", 3)
##
## So whenever the partner became ready between 2 s and 6 s after the host
## dismissed instructions, TWO chains ran. _execute_countdown recurses 3->2->1->0
## once per second, and the fallback's `game_active` guard cannot help: game_active
## only becomes true a full second AFTER the GO tick, because _on_countdown_tick(0)
## awaits 1.0 s before calling _on_countdown_complete() -> start_game(). A countdown
## that began at t+2..t+6 has therefore not reached start_game() by t+6.
##
## The consequences all land in the round the player is about to play:
##   * round_starting fires 8 times instead of 4, so _on_countdown_tick rebuilds
##     the overlay and its tween twice per number,
##   * TWO GO ticks reach _on_countdown_complete(),
##   * start_game() runs twice: game_active reset, game_started re-emitted,
##     _on_game_start() (the per-game spawn setup) re-run, and a SECOND
##     `ui_timer = Timer.new(); add_child(ui_timer)` left as a live child, both
##     instances writing the same timer label every second.
##
## This harness drives exactly that timing on the real network, in a real MP_*
## scene, through the real _on_instruction_dismissed():
##   host   t=2.0  dismiss instructions -> fallback armed for t=8.0
##   client t=6.5  dismiss instructions -> ready RPC -> host start_countdown()
##
## Assertions (both processes):
##   1. round_starting emitted exactly 4 times (3,2,1,0) — not 8.
##   2. exactly ONE GO tick (count == 0).
##   3. game_started emitted exactly once.
##   4. exactly one live ui_timer Timer child on the minigame node.
## Controls, so none of the above can pass by nothing having happened:
##   5. the countdown really ran and the round really started.
##   6. HOST ONLY: game_active was still false at t=7.9, i.e. the fallback's own
##      `if not game_active` guard was satisfied and the fallback DID reach
##      start_countdown() a second time. Without this, a green run could equally
##      mean the fallback never fired.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyCountdownOnce.tscn -- host
##   godot --headless --path . res://tools/VerifyCountdownOnce.tscn -- client

const HOST_IP: String = "127.0.0.1"
## 7783: 7777/7778 belong to VerifyMultiplayer / VerifyMultiplayerReconnect and
## 7781/7782 to VerifyReturnToLobby. A lingering socket from any of those must not
## fail this harness's bind for a reason unrelated to what it measures.
const PORT: int = 7783
const CONNECT_TIMEOUT: float = 20.0
## player1_game of LevelSets set 1. Any MP_* scene exercises the same base-class
## countdown path; this one is picked because it is the first the shipped level
## sets hand to player 1.
const MP_SCENE: String = "res://scenes/multiplayer/MP_WashVegetables.tscn"

var role: String = "host"
var results: Array = []

## One entry per round_starting emission: {count, t}.
var ticks: Array = []
var game_started_count: int = 0
var game_active_at_fallback: bool = true
var sampled_fallback_window: bool = false
var t0: float = 0.0

## Set on the twin only. See _ready().
var _detached: bool = false

func _ready() -> void:
	if not _detached:
		# The tool scene IS get_tree().current_scene, and this harness replaces the
		# current scene with the MP minigame — change_scene_to_file() memdeletes the
		# outgoing one. The timeline therefore lives on a twin parented straight to
		# /root, which a scene change leaves alone. Deferred because /root is still
		# "busy setting up children" during this _ready(): a direct add_child() there
		# fails outright, leaving the twin unattached, no timeline armed, and a
		# headless run that hangs until the outer timeout.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "CountdownOnceProbe"
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
	print("  ONE-COUNTDOWN-PER-ROUND HARNESS — role: %s  port: %d" % [role, PORT])
	print("═══════════════════════════════════════════════════════════")
	# Connected before anything can emit, so the tick log is complete.
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


func _go_ticks() -> int:
	var n := 0
	for e in ticks:
		if e["count"] == 0:
			n += 1
	return n

# ── observation helpers ─────────────────────────────────────────────

## The live MP round node, or null if the scene is not up. Identified by the
## handler under test rather than by class, so it cannot match the tool scene.
func _mg() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var cs := tree.current_scene
	if cs and cs.has_method("_on_instruction_dismissed"):
		return cs
	return null


## Count the live Timer children carrying start_game()'s per-round UI timer.
## Matched on the connection start_game() makes, not on a name: Timer.new()
## leaves the name auto-generated, so a second one is simply another child with a
## different auto name and nothing else distinguishes it.
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


func _bail_unless(anchored: Array, label: String) -> void:
	if anchored[0]:
		return
	_check(label, false)
	_finish()

# ── shared timeline ─────────────────────────────────────────────────

## Load the real MP round scene through change_scene_to_file — the same call
## _load_next_round() uses, so the minigame boots exactly as it does in a session.
func _enter_round() -> void:
	NetworkManager.game_in_progress = true
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(MP_SCENE)
	print("  [%s] loading %s" % [role, MP_SCENE])


## Dismiss the instruction overlay the way a tap does. The handler is called
## directly rather than by synthesising an InputEvent, which keeps the harness
## independent of where the overlay lands on screen; everything downstream of the
## tap — set_local_player_ready(), the waiting overlay and the host's 6 s fallback
## — is untouched production code.
func _dismiss(tag: String) -> void:
	var mg := _mg()
	if mg == null:
		_check("%s: the MP round scene was up to dismiss instructions on" % tag, false,
			"current_scene = %s" % _scene_path())
		return
	if not mg.game_started.is_connected(_on_game_started):
		mg.game_started.connect(_on_game_started)
	print("  [%s] dismissing instructions at t=%.1fs" % [role, _now()])
	# The first-play beat pages inside this same overlay, so one tap only turns a page -
	# readiness is signalled on the LAST page. A player taps until the overlay is gone.
	var taps: int = 0
	while taps < 8 and not bool(mg.get("_instruction_dismissed")):
		mg.call("_on_instruction_dismissed")
		taps += 1
		await get_tree().process_frame
	print("  [%s] %d tap(s) to clear the overlay" % [role, taps])


func _scene_path() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return "<null>"
	return tree.current_scene.scene_file_path


func _on_game_started() -> void:
	game_started_count += 1
	print("  [%s] game_started #%d at t=%.1fs" % [role, game_started_count, _now()])


## Sampled at t=7.9, the instant before the production fallback's own timer fires:
## whatever game_active reads here is what `if not game_active` will read.
func _sample_fallback_window() -> void:
	var mg := _mg()
	if mg == null:
		return
	sampled_fallback_window = true
	game_active_at_fallback = bool(mg.get("game_active"))
	print("  [%s] t=%.1fs game_active=%s (the fallback's own guard reads this)"
		% [role, _now(), str(game_active_at_fallback)])

func _assert_common() -> void:
	var mg := _mg()
	var go_count := _go_ticks()

	# Controls first: with no countdown at all, every count below is vacuous.
	_check("control: the countdown ran and reached GO",
		go_count >= 1, "GO ticks = %d | %s" % [go_count, _tick_str()])
	_check("control: the round actually started",
		mg != null and bool(mg.get("game_active")),
		"game_active = %s scene = %s"
			% [(str(mg.get("game_active")) if mg else "<no scene>"), _scene_path()])

	_check("round_starting emitted exactly 4 times (3,2,1,0)",
		ticks.size() == 4,
		"%d emissions — a second chain re-runs the overlay tween per number | %s"
			% [ticks.size(), _tick_str()])
	_check("exactly one GO tick reached _on_countdown_complete()",
		go_count == 1,
		"%d GO ticks — each one calls start_game() a second later" % go_count)
	_check("game_started emitted exactly once",
		game_started_count == 1,
		"%d emissions — _on_game_start() re-runs the per-game spawn setup"
			% game_started_count)
	var tc := _ui_timer_count()
	_check("exactly one live ui_timer child on the round node",
		tc == 1,
		("%d timers — start_game() add_child()s a new one on every call and never"
			+ " frees the old, so two write the same label each second") % tc)

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

	# The real flow clears the stale per-round flags on every peer before the round
	# scenes load (start_multiplayer_game_pair and _load_next_round both do it), and
	# _ready_signal_emitted is one of them.
	NetworkManager.rpc("_reset_round_status")

	tree.create_timer(0.5).timeout.connect(_enter_round)
	# t=2.0 dismiss -> arms the production 6 s fallback for t=8.0.
	tree.create_timer(2.0).timeout.connect(_dismiss.bind("host"))
	tree.create_timer(7.9).timeout.connect(_sample_fallback_window)
	tree.create_timer(14.0).timeout.connect(_host_assert)
	tree.create_timer(17.0).timeout.connect(_finish)


func _host_assert() -> void:
	_assert_common()
	# THE control that makes "exactly one GO" mean "the duplicate was suppressed"
	# rather than "the fallback never fired".
	_check("control: the host fallback's guard was satisfied, so it did fire",
		sampled_fallback_window and not game_active_at_fallback,
		("sampled=%s game_active_at_7.9s=%s — if game_active was already true the"
			+ " fallback skipped start_countdown() and the checks above prove nothing")
			% [str(sampled_fallback_window), str(game_active_at_fallback)])

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
	# t=6.5: deliberately inside the host's 2.0..8.0 fallback window, and late
	# enough that chain A cannot reach start_game() before the fallback fires.
	tree.create_timer(6.5).timeout.connect(_dismiss.bind("client"))
	tree.create_timer(14.0).timeout.connect(_assert_common)
	tree.create_timer(17.0).timeout.connect(_finish)
