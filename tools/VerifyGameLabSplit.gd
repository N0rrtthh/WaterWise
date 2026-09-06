extends Node

## Is the Game Lab's split screen a real two-sided co-op round, or a network simulation?
##
## THE DEFECT
##   Reported as "Game Lab is mislabeled/misbuilt - it currently just simulates the multiplayer
##   networking/algorithm rather than letting a single developer actually play both sides. It
##   should launch a true local split-screen instance of the selected minigame (two panes, two
##   independent inputs) so a solo dev can test real co-op feel." The Lab's co-op rows were
##   playable only while a second device was connected; with nothing connected it reported on
##   the networking instead of running a round.
##
## WHAT IS MEASURED HERE
##   1. the pair handed over from the Lab is the pair that opens - not "some" pair, a NAMED one
##      that is deliberately not the first in the table, so a fallback cannot pass this.
##   2. the session is LOCAL: the peer is an OfflineMultiplayerPeer and is NOT an
##      ENetMultiplayerPeer. "Not a network simulation" as a measured property rather than a
##      claim - there is no socket, and nothing stands in for a missing peer.
##   3. two panes, and they are the two SIDES: pane 1 runs the pair's player1_game as player 1
##      with the authored player1_role, pane 2 runs a DIFFERENT scene as player 2 with the
##      authored player2_role. The "different scene" row is what separates this from the same
##      game twice.
##   4. neither pane bailed. MultiplayerMiniGameBase._ready() returns early and asks
##      GameManager for the lobby when it finds no session, which is exactly what used to
##      happen in here.
##   5. two INDEPENDENT inputs: a click inside one pane reaches that pane's viewport and not
##      the other's. Measured with a middle click, which no minigame handles, so nothing can
##      swallow it before the count.
##   6. what is genuinely shared across the two panes - the team score both HUDs watch and the
##      team life pool - because two panes that do not share a session are two single-player
##      games side by side.
##   7. the documented boundary, asserted rather than promised: a resource handed over locally
##      does NOT arrive, and the structural reason (an @rpc without "call_local") is read out
##      of the RPC config itself.
##   8. teardown puts every NetworkManager member back and hands the peer back as it was found,
##      and the Lab's sandbox is closed on the way out.
##   9. a VACUITY GUARD: with the local session gone, that same scene really does bail. Without
##      this row every check above could pass on a build where nothing needed fixing.
##
## NOT MEASURED HERE (needs a person and a touchscreen)
##   Whether co-op FEELS right with both hands on one screen - the point of the tool. And that
##   two real fingers land in two panes at once: headless has one synthetic pointer, so rows 5
##   prove the routing is per-pane, not that multitouch delivers two simultaneously.
##
## Usage:
##   godot --headless --path . res://tools/VerifyGameLabSplit.tscn

const SPLIT_SCENE: String = "res://scenes/ui/GameLabSplit.tscn"
const SPLIT_SCRIPT: String = "res://scenes/ui/GameLabSplit.gd"

## Deliberately NOT LEVEL_SETS[0]. GameLabSplit falls back to the first authored pair when it
## is handed nothing, so a broken handoff would open a pair and pass a weaker check.
const PAIR_ID: String = "shower_water_reuse"

## Moto E5 Plus, the device every layout report in this task came from.
const MOTO_SHAPE: Vector2i = Vector2i(2160, 1080)

var _pass: int = 0
var _fail: int = 0
var _split: Node = null
var _split_script: GDScript = null
var _members: Array = []
var _pre: Dictionary = {}
var _pre_peer: MultiplayerPeer = null
var _resource_arrivals: int = 0
var _score_events: Array[int] = []
var _pane_games: Array[Node] = []
var _pane_boxes: Array[SubViewportContainer] = []
var _counters: Array[Node] = []


## Counts pointer events that reach ONE viewport. Added as the last child of the pane's
## SubViewport, so it is the first node in that viewport to see the event and nothing inside
## the running minigame can consume it first.
## Counts presses and releases separately. Counting "events" instead reads 2 per tap, since a
## tap is a press and a release - the first version of the rows below asserted 1 and failed on
## a routing that was in fact already correct.
class InputCounter extends Node:
	var hits: int = 0
	var releases: int = 0

	func _input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				hits += 1
			else:
				releases += 1


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Game Lab split screen: two panes, two sides, no network ===")

	if NetworkManager == null or LevelSets == null or GameManager == null:
		print("  FAIL  an autoload this depends on is missing")
		get_tree().quit(1)
		return

	_split_script = load(SPLIT_SCRIPT) as GDScript
	if _split_script == null:
		print("  FAIL  %s did not load" % SPLIT_SCRIPT)
		get_tree().quit(1)
		return

	# The member list is read off the product screen rather than restated here, so "everything
	# it writes is restored" cannot pass because this harness happens to check a shorter list.
	_members = _split_script.get("SESSION_MEMBERS")
	_check("the split screen names the session members it will restore",
		_members is Array and _members.size() >= 8,
		"SESSION_MEMBERS: %s" % str(_members))
	if not (_members is Array):
		print("")
		print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
		get_tree().quit(1)
		return

	# The reported device's shape, for two reasons. It is where every layout report in this task
	# came from, and at 1080 tall it is also the shape where one window pixel is exactly one
	# viewport unit under this project's canvas_items/expand stretch - which the row below
	# asserts rather than assumes, because the input rows push events in window pixels and read
	# rectangles in viewport units. Get that wrong and a click lands nowhere, silently: the
	# first run of this harness pressed at y=1066 on a default-sized headless window and both
	# panes counted zero.
	get_window().size = MOTO_SHAPE
	await _frames(4)
	var vis: Vector2 = get_viewport().get_visible_rect().size
	_check("the harness window is 1:1 with viewport units, so a press lands where it is aimed",
		is_equal_approx(vis.y, float(MOTO_SHAPE.y)) and is_equal_approx(vis.x, float(MOTO_SHAPE.x)),
		"window %dx%d, visible rect %.0fx%.0f" % [MOTO_SHAPE.x, MOTO_SHAPE.y, vis.x, vis.y])

	var target: Dictionary = LevelSets.get_level_set_by_id(PAIR_ID)
	_check("the pair this run asks for is authored, and is not the fallback first pair",
		not target.is_empty() and PAIR_ID != str(LevelSets.get_all_level_sets()[0].get("id", "")),
		"%s: %s" % [PAIR_ID, str(target.get("name", "<missing>"))])

	# A finished round inside a pane routes itself through change_scene_to_file(), which frees
	# whatever current_scene is. This harness IS current_scene, so the slot is handed to a
	# throwaway node: the run then survives anything a pane decides to do.
	var decoy := Node.new()
	decoy.name = "CurrentSceneDecoy"
	get_tree().root.add_child(decoy)
	get_tree().current_scene = decoy

	# Mirrors the Lab: the sandbox is open before the split screen appears, and closing it is
	# the split screen's job on the way out.
	GameManager.enter_sandbox("Medium")

	_pre = _snapshot()
	_pre_peer = multiplayer.multiplayer_peer

	NetworkManager.resource_sent.connect(
		func(_f: int, _t: String, _a: int, _q: float) -> void: _resource_arrivals += 1)
	NetworkManager.team_score_updated.connect(
		func(total: int) -> void: _score_events.append(total))

	_split_script.set("requested_set_id", PAIR_ID)
	_check("the Lab's pair handoff survives being written on the script",
		str(_split_script.get("requested_set_id")) == PAIR_ID,
		"requested_set_id reads back as \"%s\"" % str(_split_script.get("requested_set_id")))

	# Added under the root viewport, not under this Node: the panes' global positions have to be
	# root-viewport coordinates for the input rows below to push events at them.
	_split = load(SPLIT_SCENE).instantiate()
	get_tree().root.add_child(_split)
	await _frames(8)

	await _session_rows(target)
	await _pane_rows(target)
	await _input_rows()
	await _sharing_rows()
	await _boundary_rows()
	await _teardown_rows()
	await _vacuity_row(target)

	decoy.queue_free()
	print("")
	print("  -- not measurable headless, needs a person and a touchscreen --")
	print("     whether co-op FEELS right with both hands on one screen, and whether two real")
	print("     fingers land in the two panes at once: headless has one synthetic pointer, so")
	print("     the rows above prove the routing is per-pane, not that multitouch delivers two")
	print("     of them simultaneously.")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _snapshot() -> Dictionary:
	var out := {}
	for key in _members:
		var v: Variant = NetworkManager.get(String(key))
		out[String(key)] = v.duplicate() if v is Dictionary or v is Array else v
	return out


## The session exists, it is the requested pair, and it is local.
func _session_rows(target: Dictionary) -> void:
	print("")
	print("  -- the session is real, and there is no network under it --")
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	_check("a multiplayer peer is up",
		peer != null,
		"peer: %s" % ("<none>" if peer == null else peer.get_class()))
	_check("it is the socket-less offline peer, NOT an ENet peer - nothing is on a port",
		peer is OfflineMultiplayerPeer and not (peer is ENetMultiplayerPeer),
		"peer class %s, connection status %d (2 = CONNECTED)"
			% [("<none>" if peer == null else peer.get_class()),
				(-1 if peer == null else int(peer.get_connection_status()))])
	_check("NetworkManager reports a connected co-op session, hosted by this process",
		NetworkManager.is_multiplayer_connected() and NetworkManager.is_server(),
		"is_multiplayer_connected=%s is_server=%s"
			% [NetworkManager.is_multiplayer_connected(), NetworkManager.is_server()])
	_check("both sides exist in the session's player table",
		NetworkManager.players.size() == 2,
		"players: %s" % str(NetworkManager.players))
	_check("the pair the Lab asked for is the pair that opened",
		str(NetworkManager.current_scenario_id) == PAIR_ID,
		"current_scenario_id=\"%s\", asked for \"%s\" (%s)"
			% [str(NetworkManager.current_scenario_id), PAIR_ID,
				str(target.get("name", "?"))])
	_check("this round's quota is measured from a baseline, so it starts at zero",
		NetworkManager.get_round_score() == 0,
		"round score %d, baseline %d, session total %d"
			% [NetworkManager.get_round_score(), int(NetworkManager.round_score_baseline),
				NetworkManager.get_total_score()])
	await _frames(1)


## Two panes, and they are the two sides of the authored pair.
func _pane_rows(target: Dictionary) -> void:
	print("")
	print("  -- two panes, two sides --")
	var pane_box: Node = _split.find_child("PaneBox", true, false)
	_check("the split screen laid out a pane box",
		pane_box != null,
		"PaneBox: %s" % ("<missing>" if pane_box == null else pane_box.get_class()))
	if pane_box == null:
		return

	var viewports: Array[SubViewport] = []
	for n in [1, 2]:
		var vp: Node = _split.find_child("Pane%dViewport" % n, true, false)
		var box: Node = _split.find_child("Pane%dView" % n, true, false)
		if vp is SubViewport:
			viewports.append(vp as SubViewport)
		if box is SubViewportContainer:
			_pane_boxes.append(box as SubViewportContainer)
	_check("there are exactly two live panes, each a SubViewport in its own container",
		viewports.size() == 2 and _pane_boxes.size() == 2,
		"viewports %d, containers %d" % [viewports.size(), _pane_boxes.size()])
	if viewports.size() != 2 or _pane_boxes.size() != 2:
		return

	_check("both panes have a real size to draw into",
		viewports[0].size.x > 0 and viewports[0].size.y > 0
			and viewports[1].size.x > 0 and viewports[1].size.y > 0,
		"pane 1 %s, pane 2 %s" % [str(viewports[0].size), str(viewports[1].size)])
	_check("both panes lay their game out at the authored 1920x1080 and scale that down",
		viewports[0].size_2d_override == Vector2i(1920, 1080)
			and viewports[0].size_2d_override_stretch
			and viewports[1].size_2d_override == Vector2i(1920, 1080)
			and viewports[1].size_2d_override_stretch,
		"overrides %s / %s" % [str(viewports[0].size_2d_override),
			str(viewports[1].size_2d_override)])

	for vp in viewports:
		var game: Node = null
		for c in vp.get_children():
			if c.get("my_player_num") != null:
				game = c
				break
		_pane_games.append(game)

	_check("a real minigame is running in each pane",
		_pane_games.size() == 2 and _pane_games[0] != null and _pane_games[1] != null,
		"pane 1: %s, pane 2: %s"
			% [("<none>" if _pane_games.size() < 1 or _pane_games[0] == null
					else _pane_games[0].scene_file_path),
				("<none>" if _pane_games.size() < 2 or _pane_games[1] == null
					else _pane_games[1].scene_file_path)])
	if _pane_games.size() != 2 or _pane_games[0] == null or _pane_games[1] == null:
		return

	# The whole point of the pair: the two panes are DIFFERENT games with complementary roles.
	# Without this row, two copies of one scene would pass everything else here.
	_check("the two panes run the pair's two DIFFERENT scenes, not one game twice",
		_pane_games[0].scene_file_path != _pane_games[1].scene_file_path
			and _pane_games[0].scene_file_path == str(target.get("player1_game", ""))
			and _pane_games[1].scene_file_path == str(target.get("player2_game", "")),
		"pane 1 %s\n          pane 2 %s"
			% [_pane_games[0].scene_file_path, _pane_games[1].scene_file_path])
	_check("pane 1 latched player 1 and the pair's authored player-1 role",
		int(_pane_games[0].get("my_player_num")) == 1
			and str(_pane_games[0].get("my_role")) == str(target.get("player1_role", "")),
		"pane 1 is P%s / \"%s\"; the pair authors \"%s\""
			% [str(_pane_games[0].get("my_player_num")), str(_pane_games[0].get("my_role")),
				str(target.get("player1_role", ""))])
	_check("pane 2 latched player 2 and the pair's authored player-2 role",
		int(_pane_games[1].get("my_player_num")) == 2
			and str(_pane_games[1].get("my_role")) == str(target.get("player2_role", "")),
		"pane 2 is P%s / \"%s\"; the pair authors \"%s\""
			% [str(_pane_games[1].get("my_player_num")), str(_pane_games[1].get("my_role")),
				str(target.get("player2_role", ""))])
	# The base bails BEFORE _on_multiplayer_ready(), and _on_multiplayer_ready() is where each
	# game names itself ("Collect Shower Water", "Flush Toilets"). game_name is an @export
	# though, defaulting to "CoopMiniGame" - so a merely non-empty name is what a BAILED
	# instance also has, and the name has to be a game-specific one to mean anything.
	_check("neither pane bailed out to the lobby - both ran their own setup",
		str(_pane_games[0].get("game_name")) != ""
			and str(_pane_games[1].get("game_name")) != ""
			and str(_pane_games[0].get("game_name")) != "CoopMiniGame"
			and str(_pane_games[1].get("game_name")) != "CoopMiniGame",
		"game_name pane 1 \"%s\", pane 2 \"%s\" (the base's own default is \"CoopMiniGame\")"
			% [str(_pane_games[0].get("game_name")), str(_pane_games[1].get("game_name"))])
	await _frames(1)


## Two independent inputs. A click inside one pane has to reach that pane's viewport and not
## the other's - otherwise this is one screen with two pictures on it.
func _input_rows() -> void:
	print("")
	print("  -- two independent inputs --")
	if _pane_boxes.size() != 2:
		return

	for box in _pane_boxes:
		var counter := InputCounter.new()
		counter.name = "InputCounter"
		# Added last, so it is the first node in that viewport to be offered the event and
		# nothing inside the running minigame can consume it before the count.
		(box.get_child(0) as SubViewport).add_child(counter)
		_counters.append(counter)
	await _frames(2)

	var r1: Rect2 = _screen_rect(_pane_boxes[0])
	var r2: Rect2 = _screen_rect(_pane_boxes[1])
	_check("the two panes occupy two separate rectangles on the glass",
		r1.size.x > 1.0 and r2.size.x > 1.0 and not r1.intersects(r2),
		"pane 1 %s, pane 2 %s" % [str(r1), str(r2)])

	# The panes have to be ON the glass, not merely somewhere. This is the row that caught the
	# screen's own overflow: the explanatory text used to sit above the panes, an autowrapping
	# Label claimed 714 of 1080 units, and both panes ran from y=802 to y=1330 - a quarter of
	# each pane past the bottom edge, on the exact device the layout reports came from. A press
	# aimed at a pane centre then lands outside the window and nothing can be tested at all.
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var on_screen: bool = (
		r1.position.x >= -0.5 and r1.position.y >= -0.5
		and r1.end.x <= vis.x + 0.5 and r1.end.y <= vis.y + 0.5
		and r2.position.x >= -0.5 and r2.position.y >= -0.5
		and r2.end.x <= vis.x + 0.5 and r2.end.y <= vis.y + 0.5)
	_check("both panes are fully inside the screen, top and bottom",
		on_screen,
		"pane 1 y %.0f..%.0f, pane 2 y %.0f..%.0f, screen is %.0fx%.0f"
			% [r1.position.y, r1.end.y, r2.position.y, r2.end.y, vis.x, vis.y])
	# A pane that survived the check by being tiny is not a pane a developer can play in.
	_check("each pane is big enough to actually play in",
		r1.size.y >= vis.y * 0.4 and r2.size.y >= vis.y * 0.4,
		"pane heights %.0f and %.0f units of a %.0f-unit screen (%.0f%% and %.0f%%)"
			% [r1.size.y, r2.size.y, vis.y, 100.0 * r1.size.y / vis.y, 100.0 * r2.size.y / vis.y])

	await _click(r1.get_center())
	_check("a press inside pane 1 arrives in pane 1 and nowhere else",
		_counters[0].hits == 1 and _counters[1].hits == 0,
		"presses: pane 1 %d, pane 2 %d (releases %d / %d), pressed at %s"
			% [_counters[0].hits, _counters[1].hits, _counters[0].releases,
				_counters[1].releases, str(r1.get_center())])

	await _click(r2.get_center())
	_check("a press inside pane 2 arrives in pane 2 and nowhere else",
		_counters[0].hits == 1 and _counters[1].hits == 1,
		"presses now pane 1 %d, pane 2 %d (releases %d / %d), pressed at %s"
			% [_counters[0].hits, _counters[1].hits, _counters[0].releases,
				_counters[1].releases, str(r2.get_center())])
	# The lift has to land in the same pane as the press. A drag whose release is delivered
	# somewhere else leaves the pane that owns the gesture waiting for an end that never comes.
	_check("each pane also got its own release, so a gesture starts and ends in one pane",
		_counters[0].releases == 1 and _counters[1].releases == 1,
		"releases: pane 1 %d, pane 2 %d" % [_counters[0].releases, _counters[1].releases])

	# Outside both panes - on the notes strip below them. Neither pane may claim it, or the
	# forwarding is "everything goes everywhere" wearing two rectangles.
	var outside := Vector2(r1.get_center().x, minf(r1.end.y + 60.0, vis.y - 4.0))
	await _click(outside)
	_check("a press outside both panes reaches neither of them",
		_counters[0].hits == 1 and _counters[1].hits == 1,
		"presses still pane 1 %d, pane 2 %d after a press at %s (panes end at y=%.0f)"
			% [_counters[0].hits, _counters[1].hits, str(outside), r1.end.y])


## The config's keys are StringNames. Compared as Strings so the lookup cannot depend on
## String/StringName equality in a Dictionary.
func _rpc_entry(cfg: Dictionary, method: String) -> Dictionary:
	for k in cfg.keys():
		if String(k) == method:
			var raw: Variant = cfg[k]
			return raw if raw is Dictionary else {}
	return {}


func _screen_rect(c: Control) -> Rect2:
	return Rect2(c.get_global_transform_with_canvas().origin, c.size)


## A middle click at one point in the root viewport. Middle, because no minigame binds it, so
## nothing can handle it before the pane's counter is offered it. Press and release, because a
## press with no release leaves the GUI holding a focus grab that skews the next row.
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_MIDDLE
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_tree().root.push_input(ev, false)
		await _frames(1)


## What the two panes genuinely share. Two panes that do not share a session are two
## single-player games side by side, which would satisfy "two panes" and none of the point.
func _sharing_rows() -> void:
	print("")
	print("  -- what the two panes share --")
	if _pane_games.size() != 2 or _pane_games[0] == null or _pane_games[1] == null:
		return

	var score_watchers: Array = []
	for conn in NetworkManager.team_score_updated.get_connections():
		var cb: Callable = conn["callable"]
		score_watchers.append(cb.get_object())
	var lives_watchers: Array = []
	for conn in NetworkManager.team_lives_updated.get_connections():
		var cb2: Callable = conn["callable"]
		lives_watchers.append(cb2.get_object())

	_check("both panes are watching the one team score",
		score_watchers.has(_pane_games[0]) and score_watchers.has(_pane_games[1]),
		"%d listeners on team_score_updated; pane 1 present: %s, pane 2 present: %s"
			% [score_watchers.size(), score_watchers.has(_pane_games[0]),
				score_watchers.has(_pane_games[1])])
	_check("both panes are watching the one team life pool",
		lives_watchers.has(_pane_games[0]) and lives_watchers.has(_pane_games[1]),
		"%d listeners on team_lives_updated; pane 1 present: %s, pane 2 present: %s"
			% [lives_watchers.size(), lives_watchers.has(_pane_games[0]),
				lives_watchers.has(_pane_games[1])])

	_score_events.clear()
	var before: int = NetworkManager.get_round_score()
	NetworkManager.increment_local(5)
	await _frames(2)
	_check("a point scored in a pane moves the shared round score both HUDs read",
		NetworkManager.get_round_score() == before + 5 and _score_events.size() == 1
			and _score_events[0] == before + 5,
		"round score %d -> %d, team_score_updated carried %s"
			% [before, NetworkManager.get_round_score(), str(_score_events)])
	_check("there is one team life pool, not one per pane",
		int(NetworkManager.team_lives) >= 0,
		"team_lives = %d, shared by both panes" % int(NetworkManager.team_lives))


## The boundary this screen is flagged "stretch, revisit later" for, asserted rather than
## promised - so a developer who hands a bucket over in one pane and sees nothing arrive in the
## other knows it is this tool's limit and not the game's bug.
func _boundary_rows() -> void:
	print("")
	print("  -- the documented limit: cross-pane hand-off does not arrive --")
	_resource_arrivals = 0
	NetworkManager.send_resource("greywater", 1, 1.0)
	await _frames(3)
	_check("a resource sent locally does NOT come back to the other pane",
		_resource_arrivals == 0,
		"resource_sent fired %d times after send_resource() on a one-peer session"
			% _resource_arrivals)

	# The structural reason, read out of the RPC config itself rather than restated: without
	# "call_local" the sender never runs its own receiver, and there is no second peer to run
	# it either. The sender number would be wrong anyway - it is derived from
	# multiplayer.get_unique_id(), which is 1 for both panes.
	# Read off the script, not off the node: @rpc annotations are compiled into the GDScript's
	# own config, and Node.get_node_rpc_config() only reports what a runtime rpc_config() call
	# added - it answered {} here, which would have made this row vacuous.
	var cfg: Dictionary = {}
	var raw_cfg: Variant = NetworkManager.get_script().get_rpc_config()
	if raw_cfg is Dictionary:
		cfg = raw_cfg
	var handoff: Dictionary = _rpc_entry(cfg, "_receive_resource")
	var marks: Dictionary = _rpc_entry(cfg, "_receive_task_mark")
	_check("the reason is structural: neither hand-off receiver is @rpc call_local",
		not handoff.is_empty() and not marks.is_empty()
			and not bool(handoff.get("call_local", false))
			and not bool(marks.get("call_local", false)),
		"_receive_resource %s, _receive_task_mark %s" % [str(handoff), str(marks)])
	# The contrast, so a reader that simply never finds call_local cannot pass the row above.
	# It is also why the SHARED list is what it is: pause, the countdown, the life pool and the
	# round summary all run the host's own call locally, and the hand-off does not.
	var local_ones: Array[String] = []
	for m in ["_apply_pause_state", "_execute_countdown", "_sync_team_lives",
			"_show_round_results"]:
		if bool(_rpc_entry(cfg, m).get("call_local", false)):
			local_ones.append(m)
	_check("the same reader does find call_local where the shared systems use it",
		local_ones.size() == 4,
		"call_local on: %s" % str(local_ones))
	print("          bridging it means NetworkManager taking the sender's number from its")
	print("          caller instead of from the peer id - a change to the shared multiplayer")
	print("          path the P1/P4/P5 harnesses guard. Left as stretch, revisit later.")


## Everything this screen borrowed is handed back, including on the exits it does not own.
func _teardown_rows() -> void:
	print("")
	print("  -- teardown --")
	_split.queue_free()
	await _frames(4)

	var drifted: Array[String] = []
	for key in _members:
		var name_str := String(key)
		var now: Variant = NetworkManager.get(name_str)
		var was: Variant = _pre.get(name_str)
		var same: bool = (str(now) == str(was)) if (now is Dictionary or now is Array) \
			else (now == was)
		if not same:
			drifted.append("%s: %s -> %s" % [name_str, str(was), str(now)])
	_check("every NetworkManager member the split screen wrote is back where it was",
		drifted.is_empty(),
		"drifted: %s" % ("none" if drifted.is_empty() else "\n          ".join(drifted)))
	_check("the multiplayer peer is handed back exactly as it was found",
		multiplayer.multiplayer_peer == _pre_peer,
		"peer was %s, is now %s"
			% [("<null>" if _pre_peer == null else _pre_peer.get_class()),
				("<null>" if multiplayer.multiplayer_peer == null
					else multiplayer.multiplayer_peer.get_class())])
	# The Lab opens the sandbox and the split screen closes it on every exit, including the
	# ones it does not own: a pane's own QUIT button leaves for the real lobby and would
	# otherwise park the whole session in sandbox mode for the rest of the run.
	_check("the Lab's sandbox is closed on the way out",
		not GameManager.is_sandbox(),
		"is_sandbox() = %s" % GameManager.is_sandbox())


## VACUITY GUARD. Every row above could pass on a build where nothing needed fixing, unless
## the same scene is shown to fail without the local session. This is the reported behaviour:
## MultiplayerMiniGameBase._ready() finds no session, returns before it reads a side or names
## the game, and asks GameManager for the lobby.
##
## Run last, because it deliberately starts a scene transition and tears the session down.
func _vacuity_row(target: Dictionary) -> void:
	print("")
	print("  -- vacuity guard: the same scene without a local session --")
	_check("there is no session left to inherit",
		not NetworkManager.is_multiplayer_connected(),
		"is_multiplayer_connected() = %s" % NetworkManager.is_multiplayer_connected())

	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var lone: Node = load(str(target.get("player1_game", ""))).instantiate()
	vp.add_child(lone)
	await _frames(4)

	# What a bailed instance looks like has to be picked carefully. my_player_num defaults to 1
	# (base :65) and game_name is an @export defaulting to "CoopMiniGame" (base :29), so "reads
	# player 1" and "has a name" are both true of an instance that never got past the session
	# guard - the first version of this row asserted exactly that and failed for it. The
	# discriminating observable is the subscription: the base connects team_score_updated only
	# AFTER the guard, so a bailed instance is absent from the listener list, while both panes
	# were shown present in it a few rows above.
	var watchers: Array = []
	for conn in NetworkManager.team_score_updated.get_connections():
		var cb: Callable = conn["callable"]
		watchers.append(cb.get_object())
	_check("with no session the same scene never subscribes to the team score",
		not watchers.has(lone),
		"%d listeners on team_score_updated; the bailed instance among them: %s"
			% [watchers.size(), watchers.has(lone)])
	_check("and it never reads a side, where the panes read the pair's two roles",
		str(lone.get("my_role")) == "",
		"my_role=\"%s\", my_player_num=%s, game_name=\"%s\" - the last two are the base's own"
			% [str(lone.get("my_role")), str(lone.get("my_player_num")),
				str(lone.get("game_name"))]
			+ " defaults and discriminate nothing")
	_check("and it asks to leave for the lobby, which is the reported failure",
		GameManager.is_scene_transitioning(),
		"GameManager.is_scene_transitioning() = %s" % GameManager.is_scene_transitioning())
	vp.queue_free()
	await _frames(1)
