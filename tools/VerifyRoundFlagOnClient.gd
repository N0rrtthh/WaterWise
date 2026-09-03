extends Node
## WATERWISE — CLIENT-SIDE ROUND-FLAG VERIFICATION (two processes)
##
## Covers the ONE thing no existing harness does: entering a round through the shipping
## production path, NetworkManager.start_multiplayer_game_pair(), which is what
## MultiplayerLobby.gd:803 calls. Every other multiplayer harness starts its round by
## instantiating the scene itself, because that is the only way for the harness to outlive
## the round it is watching — and instantiating bypasses _load_game_scene() entirely, so the
## flag this file is about was never observed on the client by anything.
##
## The defect being verified fixed: NetworkManager.game_in_progress was set only on the HOST
## (start_multiplayer_game / start_multiplayer_game_pair) plus on the start_game() scenario
## path via _receive_game_start(). The pair path sends only _reset_round_status and
## _load_game_scene, neither of which touched it, so the CLIENT played whole rounds with
## game_in_progress == false and two guards read the wrong answer there:
##   NetworkManager._on_player_disconnected()  → the "host vanished mid-round" fallback
##   NetworkManager._on_grace_period_timeout() → the round resolution after the window
##
## Making the flag truthful makes that fallback live on the client for the first time, so
## this harness also has to prove the newly-reachable branch does not double-load the lobby:
## on the client, peer_disconnected already reaches GameManager._on_peer_disconnected() and
## MultiplayerMiniGameBase's own handler, ~30 ms ahead of server_disconnected (measured in
## tools/VerifyHostDeparture.gd). Three handlers, one transition.
##
## Assertions live on a SUBJECT parented to /root, never on this scene root: _load_game_scene
## calls change_scene_to_packed(), which frees the current scene — this node.
##
## Run BOTH, host first:
##   godot --headless --path . res://tools/VerifyRoundFlagOnClient.tscn -- host
##   godot --headless --path . res://tools/VerifyRoundFlagOnClient.tscn -- client

const PORT: int = 7802
const REHOST_PORT: int = 7803
const HOST_IP: String = "127.0.0.1"
const P1_SCENE: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const P2_SCENE: String = "res://scenes/multiplayer/MP_FillAquarium.tscn"
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"
const CONNECT_TIMEOUT: float = 30.0
## Seconds the round is left running before the host's socket closes. Long enough for the
## client to load its scene and for both flags to be sampled, short enough that neither game
## finishes on its own timer.
const DROP_AT: float = 4.0

## The departure notice the client's lobby must show, keyed by language code because a headless
## run inherits whatever language the save holds and this project defaults to Filipino. Spelled
## out here so a silent change to either end of the channel — the producer in NetworkManager or
## the string in the lobby's own table — fails this harness instead of showing the player nothing.
const NOTICE_KEY: String = "notice_host_left"
const EXPECTED_NOTICE: Dictionary = {
	"en": "The host left the game. Round cancelled.",
	"tl": "Umalis ang host. Kanselado ang round.",
}


func _ready() -> void:
	var role := _resolve_role()
	print("\n═══════════════════════════════════════════════════════════")
	print("  WATERWISE CLIENT ROUND-FLAG VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	# One frame first: /root is still "busy setting up children" during this _ready(), so
	# add_child() on it fails outright (scene/main/node.cpp:1689) and the Subject never enters
	# the tree.
	await get_tree().process_frame
	var subject := Subject.new()
	subject.name = "RoundFlagSubject"
	subject.role = role
	get_tree().root.add_child(subject)
	subject.run()


func _resolve_role() -> String:
	var args := OS.get_cmdline_user_args()
	for a in args:
		var t := String(a).strip_edges().to_lower()
		if t == "host" or t == "client":
			return t
	return "host"


class Subject extends Node:
	var role: String = "host"
	var results: Array = []
	var lobby_roots: Array = []
	var drop_seen: bool = false
	## Sampled inside multiplayer.peer_disconnected, the FIRST signal that carries the drop
	## and the one the repaired fallback branch reads game_in_progress from. By the time
	## anything can be polled the teardown has already cleared it.
	var first_snap: Dictionary = {}


	func _check(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail.is_empty():
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


	func _eventually(label: String, cond: Callable, timeout_s: float = 6.0,
			detail: Callable = Callable()) -> bool:
		var waited := 0.0
		while waited < timeout_s:
			if cond.call():
				_check(label, true, ("%s (after %.1fs)" % [_detail(detail), waited]).strip_edges())
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_check(label, false, "%s (timed out after %.1fs)" % [_detail(detail), timeout_s])
		return false


	func _detail(d: Callable) -> String:
		return "" if not d.is_valid() else String(d.call())


	func _state() -> String:
		var cs := get_tree().current_scene
		return "scene=%s NM[in_progress=%s active=%s players=%d] GM[session=%s] paused=%s" % [
			("<freed>" if cs == null or not is_instance_valid(cs) else cs.scene_file_path.get_file()),
			str(NetworkManager.game_in_progress), str(NetworkManager.connection_active),
			NetworkManager.players.size(), str(GameManager.session_active),
			str(get_tree().paused)]


	func _scene_file() -> String:
		var cs := get_tree().current_scene
		if cs == null or not is_instance_valid(cs):
			return ""
		return cs.scene_file_path

	func _lobby_panel(node_name: String) -> Control:
		var cs := get_tree().current_scene
		if cs == null or not is_instance_valid(cs):
			return null
		return cs.get_node_or_null("MarginContainer/VBoxContainer/" + node_name) as Control



	func _on_any_node_added(n: Node) -> void:
		if n.scene_file_path == LOBBY_PATH and n.get_parent() == get_tree().root:
			lobby_roots.append(n.get_instance_id())


	func _on_peer_disconnected_seen(id: int) -> void:
		if id != 1 or not first_snap.is_empty():
			return
		drop_seen = true
		first_snap = {
			"game_in_progress": NetworkManager.game_in_progress,
			"is_host": NetworkManager.is_host,
			"scene": _scene_file().get_file(),
		}
		print("  [%s] peer_disconnected(1) — NM.game_in_progress=%s scene=%s"
			% [role, str(first_snap["game_in_progress"]), str(first_snap["scene"])])


	func _finish() -> void:
		var passed := 0
		var failed: Array = []
		for r in results:
			if r["ok"]:
				passed += 1
			else:
				failed.append(r["label"])
		print("\n═══════════════════════════════════════════════════════════")
		print("  %s RESULT: %d passed, %d failed" % [role.to_upper(), passed, failed.size()])
		for f in failed:
			print("    ✗ %s" % f)
		print("═══════════════════════════════════════════════════════════\n")
		NetworkManager.disconnect_multiplayer()
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0 if failed.is_empty() else 1)


	func run() -> void:
		get_tree().node_added.connect(_on_any_node_added)
		if role == "host":
			await _run_host()
		else:
			await _run_client()
		await _finish()


	func _run_host() -> void:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected_seen)
		_check("GameManager.host_game() opened a server", GameManager.host_game(PORT), _state())
		# Not silent while it waits: a bare timeout here cannot tell "the client never
		# launched" from "the client reached a different server".
		var paired := await _eventually("the client joined and both slots are registered",
			func() -> bool: return NetworkManager.players.size() >= 2, CONNECT_TIMEOUT,
			func() -> String: return "peers=%s nm_players=%s" % [str(multiplayer.get_peers()), str(NetworkManager.players.keys())])
		if not paired:
			return

		NetworkManager.set_ready(true)
		var ready := await _eventually("both players are ready, so the pair path's gate opens",
			func() -> bool: return NetworkManager.are_all_players_ready(), 20.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		if not ready:
			_check("[!] start_multiplayer_game_pair() refuses to run without are_all_players_ready()",
				false, "the round can never load, so no flag can be sampled on either side")
			return

		_check("no round is in progress before the pair path runs",
			not NetworkManager.game_in_progress, _state())
		# The production entry point, reached from MultiplayerLobby.gd:803.
		NetworkManager.start_multiplayer_game_pair(P1_SCENE, P2_SCENE)
		await _eventually("the host loaded its OWN half of the pairing",
			func() -> bool: return _scene_file() == P1_SCENE, 15.0,
			func() -> String: return _state())
		# The control: the host's flag was never the broken one.
		_check("the host's round flag is set",
			NetworkManager.game_in_progress, _state())

		await get_tree().create_timer(DROP_AT).timeout
		print("  [host] closing the socket under a live round")
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
		await get_tree().create_timer(2.5).timeout


	func _run_client() -> void:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected_seen)
		_check("GameManager.join_game() started a client",
			GameManager.join_game(HOST_IP, PORT), _state())
		var connected := await _eventually("connected to the host",
			func() -> bool: return NetworkManager.connection_active and multiplayer.get_unique_id() != 1,
			CONNECT_TIMEOUT, func() -> String: return _state())
		if not connected:
			return

		_check("no round is in progress on the client before one loads",
			not NetworkManager.game_in_progress, _state())
		NetworkManager.set_ready(true)

		# The host drives the start; this peer only ever receives rpc_id(_load_game_scene).
		var loaded := await _eventually("the client loaded the OTHER half of the pairing",
			func() -> bool: return _scene_file() == P2_SCENE, 30.0,
			func() -> String: return _state())
		if not loaded:
			_check("[!] nothing further can be measured: the pair path delivered no scene here",
				false, _state())
			return

		# ── the assertion this harness exists for ──
		_check("the CLIENT's round flag is set once the pair path loads its scene",
			NetworkManager.game_in_progress,
			"NM.game_in_progress=%s on the peer that only ever receives _load_game_scene"
				% str(NetworkManager.game_in_progress))
		_check("the client did not become an accidental host",
			not NetworkManager.is_host and GameManager.local_player_num == 2, _state())

		var noticed := await _eventually("the client noticed the host's departure",
			func() -> bool: return drop_seen, 25.0, func() -> String: return _state())
		if not noticed:
			_check("[!] the departure never arrived, so the fallback cannot be observed",
				false, _state())
			return

		_check("the fallback branch's precondition was TRUE at first notice",
			bool(first_snap.get("game_in_progress", false)),
			"game_in_progress=%s inside peer_disconnected — the client branch of "
				% str(first_snap.get("game_in_progress"))
				+ "_on_player_disconnected() is reachable on a client for the first time")

		await _eventually("the client leaves the dead round instead of soft-locking in it",
			func() -> bool: return lobby_roots.size() > 0, 12.0,
			func() -> String: return _state())
		# Let every one of the three handlers finish before counting: the point of the count
		# is that the two later ones found a transition already running and did nothing.
		await get_tree().create_timer(1.5).timeout
		_check("exactly one lobby was loaded, not one per handler",
			lobby_roots.size() == 1,
			"%d MultiplayerLobby root(s) entered the tree" % lobby_roots.size())
		_check("the current scene is the multiplayer lobby", _scene_file() == LOBBY_PATH, _state())
		# The player has to be TOLD why the round vanished, and this is the only harness where that
		# claim is measurable: its client entered the round through start_multiplayer_game_pair(), so
		# NetworkManager.game_in_progress is genuinely true here and the client branch of
		# _on_player_disconnected() — the notice's producer — actually runs. VerifyHostDeparture
		# instantiates its round instead, which correctly gates the producer off.
		var subtitle := _lobby_panel("SubtitleLabel") as Label
		var notice_text: String = "" if subtitle == null else subtitle.text
		var lang: String = "tl" if Localization.current_language == Localization.Language.FILIPINO else "en"
		var expected: String = str(EXPECTED_NOTICE.get(lang, ""))
		print("  [client] language=%s lobby subtitle=\"%s\"" % [lang, notice_text])
		# Pinned per language rather than in English only: a headless run inherits whatever language
		# the save holds, and this project's default is Filipino.
		_check("the notice has a string in the language this run resolved to",
			not expected.is_empty(),
			"language=%s expects \"%s\"" % [lang, expected])
		_check("the lobby explains why the round ended",
			notice_text == expected,
			"SubtitleLabel=\"%s\" (expected \"%s\" for language %s)" % [notice_text, expected, lang])
		# A key on screen would mean the notice reached the label without passing through a
		# translation table, which is how "notice_host_left" ends up shown to a player.
		_check("the notice is rendered, not a raw localization key",
			notice_text != NOTICE_KEY and not notice_text.begins_with("notice_"),
			"SubtitleLabel=\"%s\"" % notice_text)
		# Reading clears: otherwise the same explanation reappears, out of context, the next time
		# this player opens multiplayer.
		_check("the notice was consumed by the screen that showed it",
			GameManager.consume_multiplayer_notice().is_empty(),
			"a second read returns empty")
		_check("the round flag was cleared on the way out",
			not NetworkManager.game_in_progress, _state())
		_check("NetworkManager's half is clear",
			not NetworkManager.connection_active and NetworkManager.players.is_empty(), _state())
		_check("no reconnect window is still ticking behind the lobby",
			not NetworkManager.grace_period_active and NetworkManager.disconnection_timer.is_stopped(),
			"grace=%s timer_stopped=%s" % [str(NetworkManager.grace_period_active),
				str(NetworkManager.disconnection_timer.is_stopped())])
		_check("GameManager's half is clear",
			not GameManager.session_active and not GameManager.is_multiplayer_connected, _state())
		_check("the multiplayer peer was released", multiplayer.multiplayer_peer == null, _state())
		_check("the tree is not left paused under the lobby", not get_tree().paused, _state())
		_check("no scene transition is left half-finished",
			not bool(GameManager.get("_is_transitioning")),
			"_is_transitioning=%s" % str(GameManager.get("_is_transitioning")))
		_check("this peer can immediately open a new session",
			GameManager.host_game(REHOST_PORT),
			"host_game(%d) %s" % [REHOST_PORT, _state()])
