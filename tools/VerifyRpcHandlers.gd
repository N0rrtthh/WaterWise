extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS RPC-HANDLER COVERAGE HARNESS
## ═══════════════════════════════════════════════════════════════════
## NetworkManager and GameManager expose 55 @rpc handlers between them. The other
## multiplayer harnesses in tools/ cover the ones on the shipped session path —
## registration, readiness, countdown, round advance, lives, pause, reconnect,
## return-to-lobby, the water pipeline and the G-Counter merge. This one covers the
## remainder, which were network-reachable but never exercised:
##
##   NetworkManager._sync_flow_speed          host → client, authority
##   NetworkManager._sync_difficulty          host → client, authority
##   GameManager._sync_difficulty             host → client, authority + call_local
##   NetworkManager._show_round_results       host → all, authority + call_local
##   NetworkManager.sync_game_state           client → host, any_peer (relay)
##   NetworkManager._broadcast_game_state     host → client, authority
##   NetworkManager.send_performance_data     client → host, any_peer (relay)
##   NetworkManager._broadcast_performance    host → client, authority
##   NetworkManager.notify_game_end           local, host-only decision
##   NetworkManager._broadcast_game_end       host → client, authority
##   NetworkManager._receive_resource         client → host, any_peer + sender check
##   NetworkManager._receive_task_mark        client → host, any_peer + sender check
##   NetworkManager._sync_ready_status        client → host → all, any_peer relay
##   NetworkManager.sync_mp_auto_play         host → client, any_peer
##   NetworkManager._load_next_round          host → all, authority + call_local
##   NetworkManager._show_game_over           host → all, authority + call_local
##
## Every handler is reached through its PRODUCTION sender wherever one exists
## (update_flow_speed, send_resource, mark_task, set_ready, notify_game_end); where
## the production sender is a bare rpc() on the last line of a host-only routine, the
## harness issues that same rpc() and says so in the step comment. Nothing is called
## via call() or reflection — the wire path is the real one.
##
## Each check asserts the EFFECT on the receiving peer (a mirrored field, an emitted
## signal with its arguments, a scene change, a node that appeared), never "the call
## did not error". Two of them are negative checks — a client claiming to be P1 in
## _receive_resource / _receive_task_mark — and each sits directly beside the
## legitimate call that must still get through, so a rejected-everything regression
## cannot pass them.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyRpcHandlers.tscn -- host
##   godot --headless --path . res://tools/VerifyRpcHandlers.tscn -- client

const HOST_IP: String = "127.0.0.1"
## 7785: 7777/7778, 7781-7784 belong to the other multiplayer harnesses.
const PORT: int = 7785
const CONNECT_TIMEOUT: float = 20.0

## Payload constants — distinctive values so a mirrored field cannot pass by
## coincidentally already holding the default.
const FLOW_SPEED: float = 2.75
const DIFF_FLOW: float = 1.85
const DIFF_EFF: float = 0.65
const GM_MULT: float = 1.4
const RR_P1: int = 120
const RR_P2: int = 80
const RR_TEAM: int = 200
const RR_SESSION_P1: int = 340
const RR_SESSION_P2: int = 260
const RES_TYPE: String = "greywater"
const RES_AMOUNT: int = 3
const RES_QUALITY: float = 0.8
const TASK_ID: int = 7
const TASK_POS: Vector2 = Vector2(120.0, 340.0)

var role: String = "host"
var results: Array = []
var t0: float = 0.0
var _detached: bool = false

## Signal captures. Each is the full argument list of the last emission, or empty.
var cap_round_completed: Array = []
var cap_game_state: Array = []
var cap_performance: Array = []
var cap_resource: Array = []
var cap_task: Array = []
var n_resource: int = 0
var n_task: int = 0

## Samples taken at fixed timeline points, so a later handler that writes the same
## field cannot destroy the evidence for an earlier one.
var s_flow: float = -1.0
var s_diff_flow: float = -1.0
var s_diff_eff: float = -1.0
var s_gm_mult: float = -1.0
var s_session_p1: int = -1
var s_session_p2: int = -1
var s_gip_before_local_end: bool = false
var s_gip_after_local_end: bool = true
var s_gip_after_host_end: bool = true
var s_autoplay_before: bool = true
var s_autoplay_after: bool = false
var s_ready_after_autoplay: bool = false
var s_host_sees_ready_true: bool = false
var s_host_sees_ready_false: bool = true
var s_client_sees_ready_false: bool = true
var s_scene_after_round: String = ""
var s_flags_after_round: String = ""
var s_overlay_found: bool = false
var s_overlay_scene_had_hook: bool = false

## Expected next-round scenes, learned from the host over the harness's own RPC so
## each peer can assert the exact path rather than "some multiplayer scene".
var expect_p1: String = ""
var expect_p2: String = ""
var expect_received: bool = false

func _ready() -> void:
	if not _detached:
		# _load_next_round ends in change_scene_to_file(), which memdeletes
		# get_tree().current_scene — for a tool-scene launch that IS this node. The
		# timeline therefore runs on a twin parented to /root, which survives.
		# Deferred because /root is still adding children during this _ready().
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "RpcHandlersProbe"
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
	print("  RPC-HANDLER COVERAGE HARNESS — role: %s  port: %d" % [role, PORT])
	print("═══════════════════════════════════════════════════════════")

	NetworkManager.round_completed.connect(_on_round_completed)
	NetworkManager.game_state_synced.connect(_on_game_state_synced)
	NetworkManager.performance_data_received.connect(_on_performance)
	NetworkManager.resource_sent.connect(_on_resource_sent)
	NetworkManager.task_marked.connect(_on_task_marked)

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
	print("  ROUND_SCENE=%s" % s_scene_after_round)
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

func _bail_unless(anchored: Array, label: String) -> void:
	if anchored[0]:
		return
	_check(label, false)
	_finish()

# ── signal captures ─────────────────────────────────────────────────

func _on_round_completed(p1: int, p2: int, team: int) -> void:
	cap_round_completed = [p1, p2, team]
	print("  [%s] round_completed(%d, %d, %d) at t=%.1fs" % [role, p1, p2, team, _now()])


func _on_game_state_synced(state: Dictionary) -> void:
	cap_game_state = [state]
	print("  [%s] game_state_synced(%s) at t=%.1fs" % [role, str(state), _now()])


func _on_performance(player_num: int, performance: Dictionary) -> void:
	cap_performance = [player_num, performance]
	print("  [%s] performance_data_received(P%d, %s) at t=%.1fs"
		% [role, player_num, str(performance), _now()])


func _on_resource_sent(from_player: int, resource_type: String, amount: int,
		quality: float) -> void:
	n_resource += 1
	cap_resource = [from_player, resource_type, amount, quality]
	print("  [%s] resource_sent(P%d, %s, x%d, q%.2f) #%d at t=%.1fs"
		% [role, from_player, resource_type, amount, quality, n_resource, _now()])


func _on_task_marked(from_player: int, task_id: int, position: Vector2) -> void:
	n_task += 1
	cap_task = [from_player, task_id, position]
	print("  [%s] task_marked(P%d, #%d, %s) #%d at t=%.1fs"
		% [role, from_player, task_id, str(position), n_task, _now()])

# ── the harness's own RPC ───────────────────────────────────────────

## The host tells the client which scenes the level set it is about to broadcast
## assigns to P1 and P2. Neither peer can read the other's _load_next_round argument,
## and "loaded some multiplayer scene" would pass even if the peers diverged — which
## is exactly the defect class already found on the other round-advance path.
@rpc("any_peer", "reliable")
func _expect_round(p1_scene: String, p2_scene: String) -> void:
	expect_p1 = p1_scene
	expect_p2 = p2_scene
	expect_received = true
	print("  [%s] expecting P1=%s P2=%s" % [role, p1_scene, p2_scene])

# ── timeline steps: sends ───────────────────────────────────────────

func _arm() -> void:
	# A field that is already at the value under test proves nothing, so both peers
	# start from the opposite of every expectation.
	NetworkManager.game_in_progress = true
	NetworkManager.team_lives = 3
	NetworkManager.mp_session_p1_score = 0
	NetworkManager.mp_session_p2_score = 0
	NetworkManager.current_flow_speed = 9.9
	NetworkManager.combined_efficiency = 0.01
	GameManager.difficulty_multiplier = 1.0
	var ap := get_node_or_null("/root/AutoPlayManager")
	if ap:
		ap.set_mp_auto_play_enabled(false)
	print("  [%s] armed at t=%.1fs (players=%d)"
		% [role, _now(), NetworkManager.players.size()])


## Production sender: NetworkManager.update_flow_speed(), whose last lines are
## `if connection_active and is_host: rpc("_sync_flow_speed", current_flow_speed)`.
func _send_flow_speed() -> void:
	NetworkManager.update_flow_speed(FLOW_SPEED)


## Production sender: the final line of NetworkManager's host-only difficulty
## adjustment — `rpc("_sync_difficulty", current_flow_speed, combined_efficiency)`.
## Issued here with fixed values so the mirrored fields are checkable.
func _send_nm_difficulty() -> void:
	NetworkManager.rpc("_sync_difficulty", DIFF_FLOW, DIFF_EFF)


## Production sender: GameManager's spawn-pacer adjustment ends in
## `if is_host and is_multiplayer_connected: rpc("_sync_difficulty", difficulty_multiplier)`.
func _send_gm_difficulty() -> void:
	GameManager.rpc("_sync_difficulty", GM_MULT)


## Production sender: NetworkManager's round-completion broadcast, which ends in
## `rpc("_show_round_results", p1, p2, team, rounds_survived, session_p1, session_p2)`.
func _send_round_results() -> void:
	NetworkManager.rpc("_show_round_results", RR_P1, RR_P2, RR_TEAM, 3,
		RR_SESSION_P1, RR_SESSION_P2)


## Client → host. sync_game_state is itself the @rpc, so game code reaches it with
## rpc("sync_game_state", state); the host then relays via _broadcast_game_state.
func _send_game_state() -> void:
	NetworkManager.rpc("sync_game_state", {"phase": "washing", "units": 4})


## Client → host, same shape: send_performance_data is the @rpc, and the host relays
## it to every peer as _broadcast_performance.
func _send_performance() -> void:
	NetworkManager.rpc("send_performance_data",
		{"accuracy": 0.9, "reaction_time": 420, "mistakes": 1})


## Production sender: NetworkManager.send_resource(), which stamps the caller's own
## player number and rpc()s _receive_resource.
func _send_resource() -> void:
	NetworkManager.send_resource(RES_TYPE, RES_AMOUNT, RES_QUALITY)


## The spoof beside it: the same handler, called directly with a from_player the
## sender does not own. _sender_is_player_num() must drop it, so the host's
## resource_sent count has to stay at 1.
func _spoof_resource() -> void:
	print("  [%s] spoofing _receive_resource as P1 at t=%.1fs" % [role, _now()])
	NetworkManager.rpc("_receive_resource", 1, "water", 99, 1.0)


## Production sender: NetworkManager.mark_task().
func _send_task() -> void:
	NetworkManager.mark_task(TASK_ID, TASK_POS)


func _spoof_task() -> void:
	print("  [%s] spoofing _receive_task_mark as P1 at t=%.1fs" % [role, _now()])
	NetworkManager.rpc("_receive_task_mark", 1, 99, Vector2.ZERO)


## Client-side call of a host-only decision. notify_game_end() is @rpc("any_peer"),
## so it is reachable, but its own guard must refuse a non-host caller — the client's
## game_in_progress therefore has to survive its own call.
func _client_tries_game_end() -> void:
	print("  [%s] calling notify_game_end() as a client at t=%.1fs" % [role, _now()])
	NetworkManager.notify_game_end({"success": true, "score": 999})


## The legitimate one, from the host.
func _host_ends_game() -> void:
	NetworkManager.notify_game_end({"success": true, "score": RR_TEAM})


## Production sender: the lobby auto-play toggle rpc()s sync_mp_auto_play to the
## partner, which mirrors the flag AND marks the receiver lobby-ready.
func _send_autoplay() -> void:
	NetworkManager.rpc("sync_mp_auto_play", true)


## Production sender: NetworkManager.set_ready(), which on a client is
## rpc_id(1, "_sync_ready_status", ...) and is then re-broadcast by the host.
## Sent as false because sync_mp_auto_play just left it true — the transition is what
## makes the host-side check non-vacuous.
func _client_clears_ready() -> void:
	NetworkManager.set_ready(false)


## Production sender: NetworkManager._transition_to_next_round(), whose last line is
## `rpc("_load_next_round", level_set, get_total_score(), team_lives, rounds_survived)`.
## The level set is picked here rather than inside that function so the harness can
## tell both peers which scene each is supposed to land on — LevelSets.
## get_random_level_set() consumes a set from a per-peer shuffled pool, so calling it
## on the client for comparison would pick a different one.
func _send_next_round() -> void:
	var level_set: Dictionary = LevelSets.get_random_level_set()
	_expect_round(level_set["player1_game"], level_set["player2_game"])
	rpc("_expect_round", level_set["player1_game"], level_set["player2_game"])
	print("  [%s] broadcasting _load_next_round at t=%.1fs" % [role, _now()])
	NetworkManager.rpc("_load_next_round", level_set,
		NetworkManager.get_total_score(), NetworkManager.team_lives, 1)


## Production sender: the same host-only routine takes this branch instead when
## team_lives has hit zero — `rpc("_show_game_over")`.
func _send_game_over() -> void:
	print("  [%s] broadcasting _show_game_over at t=%.1fs" % [role, _now()])
	NetworkManager.rpc("_show_game_over")

# ── timeline steps: samples ─────────────────────────────────────────

func _sample_flow() -> void:
	s_flow = NetworkManager.current_flow_speed


func _sample_nm_difficulty() -> void:
	s_diff_flow = NetworkManager.current_flow_speed
	s_diff_eff = NetworkManager.combined_efficiency


func _sample_gm_difficulty() -> void:
	s_gm_mult = GameManager.difficulty_multiplier


func _sample_session_totals() -> void:
	s_session_p1 = NetworkManager.mp_session_p1_score
	s_session_p2 = NetworkManager.mp_session_p2_score


func _sample_gip_before() -> void:
	s_gip_before_local_end = NetworkManager.game_in_progress


func _sample_gip_after_local() -> void:
	s_gip_after_local_end = NetworkManager.game_in_progress


func _sample_gip_after_host() -> void:
	s_gip_after_host_end = NetworkManager.game_in_progress


func _ap_enabled() -> bool:
	var ap := get_node_or_null("/root/AutoPlayManager")
	if ap and ap.has_method("is_mp_auto_play_enabled"):
		return bool(ap.is_mp_auto_play_enabled())
	return false


func _my_ready() -> bool:
	var me: int = multiplayer.get_unique_id()
	return bool(NetworkManager.players.get(me, {}).get("ready", false))


func _client_ready_seen_by_host() -> bool:
	for pid in NetworkManager.players.keys():
		if pid != 1:
			return bool(NetworkManager.players[pid].get("ready", false))
	return false


func _sample_autoplay_before() -> void:
	s_autoplay_before = _ap_enabled()


func _sample_autoplay_after() -> void:
	s_autoplay_after = _ap_enabled()
	s_ready_after_autoplay = _my_ready()
	s_host_sees_ready_true = _client_ready_seen_by_host()
	print("  [%s] autoplay=%s my_ready=%s host_sees_client_ready=%s at t=%.1fs"
		% [role, str(s_autoplay_after), str(s_ready_after_autoplay),
			str(s_host_sees_ready_true), _now()])


func _sample_ready_cleared() -> void:
	s_host_sees_ready_false = _client_ready_seen_by_host()
	s_client_sees_ready_false = _my_ready()


func _sample_round_scene() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	s_scene_after_round = "<null>"
	if tree and tree.current_scene:
		s_scene_after_round = tree.current_scene.scene_file_path
	s_flags_after_round = "ready_emitted=%s countdown=%s round_in_progress=%s" % [
		str(NetworkManager.get("_ready_signal_emitted")),
		str(NetworkManager.get("_countdown_started_this_round")),
		str(NetworkManager.round_in_progress),
	]
	print("  [%s] after _load_next_round: %s | %s"
		% [role, s_scene_after_round, s_flags_after_round])


## _show_game_over calls _show_game_over_screen() on current_scene when it has it —
## MultiplayerMiniGameBase does, and _load_next_round just put one on screen. The
## overlay it builds is a Control named "GameOverOverlay" under hud_layer.
func _sample_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var cs: Node = tree.current_scene if tree else null
	s_overlay_scene_had_hook = cs != null and cs.has_method("_show_game_over_screen")
	s_overlay_found = cs != null and cs.find_child("GameOverOverlay", true, false) != null
	print("  [%s] game-over overlay=%s (scene exposes the hook: %s)"
		% [role, str(s_overlay_found), str(s_overlay_scene_had_hook)])


## The spoof rejections below only mean anything if the host actually knows the
## client's player number: _sender_is_player_num() lets a claim through when it cannot
## resolve the sender (actual == 0), so an unregistered peer would "pass" the spoof.
func _client_player_num_at_host() -> int:
	for pid in NetworkManager.players.keys():
		if pid != 1:
			return int(NetworkManager.players[pid].get("player_num", 0))
	return 0

# ── assertions ──────────────────────────────────────────────────────

func _assert_common() -> void:
	_check("control: both peers are registered",
		NetworkManager.players.size() == 2,
		"players = %s" % str(NetworkManager.players.keys()))

	_check("_show_round_results delivered the round scores",
		cap_round_completed == [RR_P1, RR_P2, RR_TEAM],
		"round_completed = %s (expected [%d, %d, %d])"
			% [str(cap_round_completed), RR_P1, RR_P2, RR_TEAM])
	_check("_show_round_results synced the session accumulators",
		s_session_p1 == RR_SESSION_P1 and s_session_p2 == RR_SESSION_P2,
		"session P1=%d P2=%d (expected %d / %d)"
			% [s_session_p1, s_session_p2, RR_SESSION_P1, RR_SESSION_P2])

	var gs_ok: bool = cap_game_state.size() == 1 \
		and (cap_game_state[0] as Dictionary).get("phase", "") == "washing" \
		and int((cap_game_state[0] as Dictionary).get("units", -1)) == 4
	_check("game state crossed the wire intact",
		gs_ok, "game_state_synced = %s" % str(cap_game_state))

	var perf_ok: bool = cap_performance.size() == 2 and int(cap_performance[0]) == 2
	if perf_ok:
		var p := cap_performance[1] as Dictionary
		perf_ok = int(p.get("player_id", -1)) == 2 \
			and int(p.get("reaction_time", -1)) == 420 \
			and int(p.get("mistakes", -1)) == 1
	_check("performance data arrived stamped with the sending player's number",
		perf_ok, "performance_data_received = %s" % str(cap_performance))

	_check("the host's notify_game_end cleared game_in_progress on this peer",
		not s_gip_after_host_end,
		"game_in_progress = %s" % str(s_gip_after_host_end))

	# _load_next_round. Each peer gets the SAME level_set dictionary and picks its own
	# half of it by player number, so the two peers must land on different scenes —
	# checked here against the host's announced pair rather than against "some
	# multiplayer scene", which a divergence would still satisfy.
	var my_num: int = NetworkManager.get_local_player_num()
	var want: String = expect_p1 if my_num == 1 else expect_p2
	_check("control: the host announced which pair of scenes this round uses",
		expect_received and expect_p1 != "" and expect_p2 != "" and expect_p1 != expect_p2,
		"P1=%s P2=%s" % [expect_p1, expect_p2])
	_check("_load_next_round loaded this peer's half of the level set",
		s_scene_after_round == want,
		"player %d loaded %s, level set assigns it %s" % [my_num, s_scene_after_round, want])
	_check("_load_next_round cleared the per-round state on the way in",
		s_flags_after_round == "ready_emitted=false countdown=false round_in_progress=false",
		s_flags_after_round)

	_check("control: the loaded round scene exposes the game-over hook",
		s_overlay_scene_had_hook, "has _show_game_over_screen = %s"
			% str(s_overlay_scene_had_hook))
	_check("_show_game_over put the game-over overlay up on this peer",
		s_overlay_found, "GameOverOverlay found = %s" % str(s_overlay_found))

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

	tree.create_timer(0.5).timeout.connect(_arm)
	tree.create_timer(1.0).timeout.connect(_send_flow_speed)
	tree.create_timer(2.5).timeout.connect(_send_nm_difficulty)
	tree.create_timer(4.0).timeout.connect(_send_gm_difficulty)
	tree.create_timer(5.5).timeout.connect(_send_round_results)
	tree.create_timer(6.5).timeout.connect(_sample_session_totals)
	tree.create_timer(12.0).timeout.connect(_sample_host_transfers)
	tree.create_timer(13.5).timeout.connect(_host_ends_game)
	tree.create_timer(14.5).timeout.connect(_sample_gip_after_host)
	tree.create_timer(15.0).timeout.connect(_send_autoplay)
	tree.create_timer(16.0).timeout.connect(_sample_autoplay_after)
	tree.create_timer(17.5).timeout.connect(_sample_ready_cleared)
	tree.create_timer(18.0).timeout.connect(_send_next_round)
	tree.create_timer(21.0).timeout.connect(_sample_round_scene)
	tree.create_timer(22.0).timeout.connect(_send_game_over)
	tree.create_timer(24.0).timeout.connect(_sample_overlay)
	tree.create_timer(25.0).timeout.connect(_host_assert)
	tree.create_timer(28.0).timeout.connect(_finish)


var s_client_num: int = 0
var s_res_count_at_sample: int = 0
var s_task_count_at_sample: int = 0

func _sample_host_transfers() -> void:
	s_client_num = _client_player_num_at_host()
	s_res_count_at_sample = n_resource
	s_task_count_at_sample = n_task
	print("  [host] client is player %d | resource emissions=%d task emissions=%d"
		% [s_client_num, s_res_count_at_sample, s_task_count_at_sample])


func _host_assert() -> void:
	_assert_common()

	_check("control: the host resolved the client to a player number",
		s_client_num == 2, "client player_num = %d — 0 would make both spoof checks"
			% s_client_num + " pass without the ownership test running")

	_check("_receive_resource delivered the partner's transfer",
		cap_resource == [2, RES_TYPE, RES_AMOUNT, RES_QUALITY],
		"resource_sent = %s (expected [2, %s, %d, %.2f])"
			% [str(cap_resource), RES_TYPE, RES_AMOUNT, RES_QUALITY])
	_check("_receive_resource dropped the client's claim to be player 1",
		s_res_count_at_sample == 1,
		"%d emissions — the legitimate one plus a spoof would be 2"
			% s_res_count_at_sample)

	_check("_receive_task_mark delivered the partner's mark",
		cap_task == [2, TASK_ID, TASK_POS],
		"task_marked = %s (expected [2, %d, %s])" % [str(cap_task), TASK_ID, str(TASK_POS)])
	_check("_receive_task_mark dropped the client's claim to be player 1",
		s_task_count_at_sample == 1,
		"%d emissions" % s_task_count_at_sample)

	# _sync_ready_status, host side. sync_mp_auto_play's documented side effect sets the
	# client ready; set_ready(false) then clears it. Both directions are asserted, so a
	# handler that simply never writes cannot pass.
	_check("sync_mp_auto_play's ready side effect reached the host",
		s_host_sees_ready_true, "host saw client ready = %s" % str(s_host_sees_ready_true))
	_check("_sync_ready_status carried the client's ready change to the host",
		not s_host_sees_ready_false,
		"host saw client ready = %s after set_ready(false)" % str(s_host_sees_ready_false))

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

	tree.create_timer(0.5).timeout.connect(_arm)
	tree.create_timer(0.8).timeout.connect(_sample_autoplay_before)
	tree.create_timer(2.0).timeout.connect(_sample_flow)
	tree.create_timer(3.5).timeout.connect(_sample_nm_difficulty)
	tree.create_timer(5.0).timeout.connect(_sample_gm_difficulty)
	tree.create_timer(6.5).timeout.connect(_sample_session_totals)
	tree.create_timer(7.0).timeout.connect(_send_game_state)
	tree.create_timer(8.5).timeout.connect(_send_performance)
	tree.create_timer(10.0).timeout.connect(_send_resource)
	tree.create_timer(10.5).timeout.connect(_spoof_resource)
	tree.create_timer(11.0).timeout.connect(_send_task)
	tree.create_timer(11.5).timeout.connect(_spoof_task)
	tree.create_timer(12.2).timeout.connect(_sample_gip_before)
	tree.create_timer(12.5).timeout.connect(_client_tries_game_end)
	tree.create_timer(13.0).timeout.connect(_sample_gip_after_local)
	tree.create_timer(14.5).timeout.connect(_sample_gip_after_host)
	tree.create_timer(16.0).timeout.connect(_sample_autoplay_after)
	tree.create_timer(16.5).timeout.connect(_client_clears_ready)
	tree.create_timer(17.5).timeout.connect(_sample_ready_cleared)
	tree.create_timer(21.0).timeout.connect(_sample_round_scene)
	tree.create_timer(24.0).timeout.connect(_sample_overlay)
	tree.create_timer(25.0).timeout.connect(_client_assert)
	tree.create_timer(28.0).timeout.connect(_finish)


func _client_assert() -> void:
	_assert_common()

	_check("_sync_flow_speed mirrored the host's flow speed",
		is_equal_approx(s_flow, FLOW_SPEED),
		"current_flow_speed = %.3f (expected %.2f, armed at 9.9)" % [s_flow, FLOW_SPEED])

	_check("NetworkManager._sync_difficulty mirrored both difficulty fields",
		is_equal_approx(s_diff_flow, DIFF_FLOW) and is_equal_approx(s_diff_eff, DIFF_EFF),
		"flow=%.3f eff=%.3f (expected %.2f / %.2f, armed at 9.9 / 0.01)"
			% [s_diff_flow, s_diff_eff, DIFF_FLOW, DIFF_EFF])

	_check("GameManager._sync_difficulty mirrored the spawn-pacer multiplier",
		is_equal_approx(s_gm_mult, GM_MULT),
		"difficulty_multiplier = %.3f (expected %.2f, armed at 1.0)" % [s_gm_mult, GM_MULT])

	_check("control: the client's game was in progress before it tried to end it",
		s_gip_before_local_end, "game_in_progress = %s" % str(s_gip_before_local_end))
	_check("notify_game_end refused a client trying to end the game",
		s_gip_after_local_end,
		"game_in_progress = %s after the client's own call — false means the client"
			% str(s_gip_after_local_end) + " ended the round for the team")

	_check("control: MP auto-play started off on this peer",
		not s_autoplay_before, "was %s" % str(s_autoplay_before))
	_check("sync_mp_auto_play mirrored the partner's toggle",
		s_autoplay_after, "is_mp_auto_play_enabled() = %s" % str(s_autoplay_after))
	_check("sync_mp_auto_play also marked this peer lobby-ready",
		s_ready_after_autoplay, "own ready flag = %s" % str(s_ready_after_autoplay))
	_check("_sync_ready_status echoed the cleared flag back to the client",
		not s_client_sees_ready_false,
		"own ready flag = %s after set_ready(false)" % str(s_client_sees_ready_false))
