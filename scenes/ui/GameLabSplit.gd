extends Control

## DEV TOOL — Game Lab / LOCAL SPLIT SCREEN (Settings → Dev Mode → 🧪 Game Lab → SPLIT).
##
## WHAT WAS WRONG
##   The Lab could not let one developer play both sides of a co-op round. Its MP list was
##   playable only while a second device was actually connected, and with nothing connected
##   the Lab stood in for the missing peer - a simulation of the networking and the algorithm
##   rather than a round anyone could play. This screen is the real thing running twice,
##   locally: the two halves of an authored co-op pair, in two live panes, each with its own
##   touch input.
##
## HOW BOTH SIDES EXIST IN ONE PROCESS
##   A co-op round is a PAIR. LevelSets hands player 1 one minigame and player 2 a DIFFERENT
##   one - MP_WashVegetables next to MP_WaterPlants, say - each with its own role name. So the
##   two panes are not two copies of one scene: pane 1 runs player1_game as player1_role and
##   pane 2 runs player2_game as player2_role. That is what makes this both sides rather than
##   the same game twice.
##
##   MultiplayerMiniGameBase reads which side it is exactly once, in _ready(), out of
##   NetworkManager.get_local_player_num() - which returns the plain member local_player_id.
##   So this runner sets that member to 1, adds pane 1, waits for pane 1's _ready() to get
##   past its own `await get_tree().process_frame`, sets it to 2, and adds pane 2. Each
##   instance keeps the number it read, in its own my_player_num, for the rest of the round.
##
## NO NETWORK, AND NOTHING SIMULATED
##   The session is opened on an OfflineMultiplayerPeer: a real MultiplayerPeer that is always
##   connected, always the server, and owns no socket. Nothing listens on a port, and nothing
##   is being faked - is_multiplayer_connected() is true because a session genuinely exists in
##   this process with both sides in it. tools/VerifyGameLabSplit.tscn asserts the peer is not
##   an ENetMultiplayerPeer, so "not a network simulation" is measured rather than promised.
##
## WHAT IS SHARED HERE, AND WHAT IS NOT (read this before judging a round in here)
##   SHARED, because both panes talk to the one NetworkManager autoload: the team score and
##   the baseline its round quota is measured from, the shared life pool, the round clock, and
##   pause. Two panes racing one quota out of one life pool is the co-op pressure, and it is
##   real in here.
##   NOT SHARED - the reason this screen is flagged "stretch, revisit later": send_resource()
##   and mark_task() are @rpc("any_peer") with no "call_local", and they attribute the sender
##   from multiplayer.get_unique_id(), which is 1 for both panes because there is one peer. So
##   a bucket handed over in pane 1 does not arrive in pane 2. Delivering it locally means
##   NetworkManager has to take the sender's number from its caller instead of from the peer
##   id - a change to the shared multiplayer path that the P1/P4/P5 harnesses guard, and not
##   one worth making for a dev tool inside this time box. The status line says so on screen
##   so nobody reads a dead hand-off as a game bug.
##
## ISOLATION
##   The Lab is already inside GameManager.enter_sandbox() when this opens and stays there, so
##   nothing here reaches the save file, the session score or lives, the exported session
##   JSON, AdaptiveDifficulty or CoopAdaptation. On the way out every NetworkManager member
##   this screen wrote is restored from a snapshot taken before it wrote anything, and the peer
##   is handed back as it was found. The screen refuses to open while a REAL session is live,
##   so it can never overwrite the identity of a session that has a second device in it.
##
## Usage from code (the Lab does this):
##   var s := load("res://scenes/ui/GameLabSplit.gd")
##   s.requested_set_id = "water_reuse_vegetables"   # "" means the first authored pair
##   get_tree().change_scene_to_file("res://scenes/ui/GameLabSplit.tscn")

## Which authored pair to run. A static var rather than a GameManager field: the handoff is
## between two Lab screens and has no business in a production autoload.
static var requested_set_id: String = ""

## The peer id parked in NetworkManager.players for the second side. There is no second peer -
## this is the entry a real host would hold for its client, and it is what makes two-player
## bookkeeping (partner name, role lookup, "are both ready") answer for two sides instead of
## one. No RPC is ever addressed to it; the offline peer has nowhere to send it.
const SYNTHETIC_PEER_ID: int = 2

## Every NetworkManager member this screen writes, snapshotted before the first write and put
## back verbatim on the way out. Named rather than inferred so a member added to the session
## setup below without being added here is a visible omission.
const SESSION_MEMBERS: Array[String] = [
	"network", "is_host", "connection_active", "local_player_id", "remote_player_id",
	"players", "player_roles", "game_in_progress", "current_scenario_id",
	"round_score_baseline", "_ready_signal_emitted", "_countdown_started_this_round",
	# Round bookkeeping the panes themselves mutate while they play, plus what
	# reset_team_lives() clears on the way in. Restored for the same reason the Lab is a sandbox
	# at all: points scored and lives lost in here must not survive the Lab. g_counter is the
	# team score's CRDT, team_lives the shared pool.
	"g_counter", "team_lives", "rounds_survived",
	"mp_session_p1_score", "mp_session_p2_score",
]

var _panes: Array[SubViewport] = []
var _pane_games: Array[Node] = []
var _level_set: Dictionary = {}
var _snapshot: Dictionary = {}
var _session_open: bool = false
var _status_label: Label = null
var _pane_box: HBoxContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_set = _resolve_level_set()
	_build_ui()

	if _level_set.is_empty():
		_status_label.text = "No authored co-op pair to run - LevelSets is empty."
		return
	if not _open_local_session():
		return
	# One frame so the panes are added to a tree whose NetworkManager already answers
	# "connected": the games' own _ready() awaits a frame and then asks.
	await get_tree().process_frame
	await _spawn_panes()
	_status_label.text = _status_text()


## Which pair to run. get_level_set_by_id() rather than get_random_level_set(): the random
## one advances a round counter and swaps the two roles on alternate calls, so the pair a
## developer chose in the Lab would not be the pair that came up here.
func _resolve_level_set() -> Dictionary:
	if LevelSets == null:
		return {}
	var want: String = requested_set_id.strip_edges()
	if want != "":
		var by_id: Dictionary = LevelSets.get_level_set_by_id(want)
		if not by_id.is_empty():
			return by_id
	var all: Array = LevelSets.get_all_level_sets()
	return all[0] if all.size() > 0 else {}


# 
# THE LOCAL SESSION
# 

## Open a real two-sided co-op session inside this one process, or refuse and say why.
##
## ASSUMPTION (Lab-only, stated where it is made): NetworkManager's identity accessors are
## plain member reads - get_local_player_num() returns local_player_id,
## is_multiplayer_connected() returns connection_active, is_server() returns is_host - so
## writing those members IS opening a session as far as every consumer is concerned. Nothing
## in the production path is edited to make this work.
func _open_local_session() -> bool:
	if NetworkManager == null:
		_status_label.text = "NetworkManager is missing; cannot open a local session."
		return false

	# Never overwrite the identity of a session that has a real second device in it. Anything
	# that is not the socket-less offline peer is treated as real, which also covers a peer a
	# lobby left open behind us.
	var live: MultiplayerPeer = multiplayer.multiplayer_peer
	if live != null and not (live is OfflineMultiplayerPeer):
		_status_label.text = (
			"A real multiplayer session is open (%s). Leave it first - the Lab will not\n"
			+ "overwrite a live session's player identity."
		) % live.get_class()
		return false

	_snapshot_session()

	# A real MultiplayerPeer that is always connected, always the server and owns no socket.
	# has_multiplayer_peer() is true, so RPCs with "call_local" execute; RPCs without it go
	# nowhere, because there is genuinely nobody else. Nothing is being simulated: the session
	# below exists, it just has no network under it.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	# NetworkManager.adopt_existing_peer(true) is the obvious way in, and it CANNOT be used
	# here. Its first line is `network = existing_peer`, and that member is declared
	# `var network: ENetMultiplayerPeer`, so handing it anything else is a runtime type error
	# that aborts the function half-done - connection_active still false, players still empty.
	# Measured rather than assumed: the first run of tools/VerifyGameLabSplit.tscn printed
	# "Trying to assign value of type 'OfflineMultiplayerPeer' to a variable of type
	# 'ENetMultiplayerPeer'" and every session row below failed with it. Widening that
	# declaration is not a safe drive-by either - create_server() and create_client() are
	# called on it, and neither exists on the base MultiplayerPeer - so the Lab opens the
	# session by writing the members itself and leaves `network` null. Null is the right value:
	# it is exactly what GameManager.disconnect_multiplayer() tests before closing an ENet peer,
	# and there is no ENet peer here to close.
	NetworkManager.is_host = true
	NetworkManager.connection_active = true
	NetworkManager.local_player_id = 1
	NetworkManager.remote_player_id = SYNTHETIC_PEER_ID
	NetworkManager._ready_signal_emitted = false
	NetworkManager._countdown_started_this_round = false
	# Peer 1 is this process (OfflineMultiplayerPeer.get_unique_id() is 1). The second entry is
	# the one a real host would hold for its client: two-player bookkeeping - partner name, role
	# lookup, "are both sides ready" - answers for two sides instead of one because of it. No
	# RPC is ever addressed to it; the offline peer has nowhere to send one.
	NetworkManager.players = {
		1: {"player_num": 1, "ready": true, "name": "Player 1 (Lab pane 1)"},
		SYNTHETIC_PEER_ID: {"player_num": 2, "ready": true, "name": "Player 2 (Lab pane 2)"},
	}

	# The authored role names for THIS pair, so pane 1 reads "Vegetable Washer" and pane 2
	# "Plant Waterer" rather than the {Collector, User} placeholder adopt_existing_peer()
	# falls back to.
	NetworkManager.assign_round_roles(_level_set)
	# A full life pool, so a Lab round does not inherit "1 life left" from whatever session ran
	# before it. Host-only inside, which is why is_host is already true above; its broadcast rpc
	# reaches nobody, as intended.
	NetworkManager.reset_team_lives()
	NetworkManager.game_in_progress = true
	NetworkManager.current_scenario_id = str(_level_set.get("id", ""))
	# This round's quota is measured from the total as it stands now. The G-Counter cannot be
	# cleared (it is a CRDT), so the baseline is how a round starts at zero.
	NetworkManager.round_score_baseline = NetworkManager.get_total_score()

	_session_open = true
	return true


## Photograph every member the session setup writes, before it writes any of them.
## Dictionaries are duplicated: assigning the live one back would hand back a reference this
## screen then mutated.
func _snapshot_session() -> void:
	_snapshot.clear()
	for key in SESSION_MEMBERS:
		var v: Variant = NetworkManager.get(key)
		_snapshot[key] = v.duplicate() if v is Dictionary or v is Array else v
	_snapshot["__peer"] = multiplayer.multiplayer_peer


## Put it all back and hand the peer back as it was found. Runs from _exit_tree(), so it also
## covers the exits this screen does not own - a pane's own QUIT button, or a finished round
## routing itself back to the Lab.
func _restore_session() -> void:
	if _snapshot.is_empty():
		return
	for key in SESSION_MEMBERS:
		if _snapshot.has(key):
			NetworkManager.set(key, _snapshot[key])
	multiplayer.multiplayer_peer = _snapshot.get("__peer", null)
	_snapshot.clear()
	_session_open = false


# 
# UI
# 

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.11)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	var title := Label.new()
	title.text = "SPLIT SCREEN — %s" % str(_level_set.get("name", "no pair"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	var end_btn := Button.new()
	end_btn.text = "END SPLIT"
	end_btn.custom_minimum_size = Vector2(0, 56)
	end_btn.add_theme_font_size_override("font_size", 20)
	end_btn.pressed.connect(_on_end_split)
	header.add_child(end_btn)

	# The panes come BEFORE the notes, and they are the only child allowed to expand. An
	# autowrapping Label in a VBoxContainer reports a minimum height for the width it had when
	# it last measured, and this one's text is four long paragraphs: the first version of this
	# screen put it above the panes, it claimed ~714 units of a 1080-unit screen, and the panes
	# were pushed 250 units off the bottom edge - measured, not theorised
	# (tools/VerifyGameLabSplit.tscn reported pane rects running to y=1330). Same class of
	# defect as the P3 overflow reports, so the notes now live in a scroller with a capped
	# height and cannot push anything again.
	_pane_box = HBoxContainer.new()
	_pane_box.name = "PaneBox"
	_pane_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane_box.add_theme_constant_override("separation", 10)
	column.add_child(_pane_box)

	var notes := ScrollContainer.new()
	notes.name = "Notes"
	# A vertical scroller's own minimum height does not include its content's, which is what
	# keeps this block from growing; the cap is what it is allowed to take, and the text
	# scrolls inside it. Without the scroller the text would just be unreachable on a phone.
	notes.custom_minimum_size = Vector2(0, 108)
	notes.size_flags_vertical = Control.SIZE_FILL
	notes.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(notes)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.76, 0.86))
	notes.add_child(_status_label)


## What is shared, what is not, and what the two panes are. Said on screen because a
## developer judging co-op feel in here has to know that an un-arrived bucket is this
## screen's limit and not the game's bug.
func _status_text() -> String:
	var lines: Array[String] = []
	lines.append("Pair: %s   |   link: %s" % [
		str(_level_set.get("description", "?")),
		str(_level_set.get("connection_description", "?"))])
	lines.append("SHARED and live across both panes: team score and this round's quota, "
		+ "the team life pool, the round clock, and pause.")
	lines.append("NOT shared (stretch, revisit later): a resource handed over in one pane "
		+ "does not arrive in the other. send_resource()/mark_task() are @rpc(\"any_peer\") "
		+ "with no \"call_local\" and read the sender from the peer id, which is 1 for both "
		+ "panes - bridging it means changing the shared multiplayer path.")
	lines.append("Touch and mouse go to the pane under them. Arrow keys are read from the "
		+ "global Input singleton and drive BOTH panes.")
	return "\n".join(lines)


# 
# THE TWO PANES
# 

## Pane 1 gets player1_game as player 1, pane 2 gets player2_game as player 2.
##
## The order is the mechanism. MultiplayerMiniGameBase._ready() awaits one process frame and
## then reads its side once out of NetworkManager.get_local_player_num(). So the member is set
## to 1, pane 1 is added and given enough frames to get past its own await, and only then is
## the member set to 2 for pane 2. Each instance keeps what it read in its own my_player_num.
func _spawn_panes() -> void:
	var p1_path: String = str(_level_set.get("player1_game", ""))
	var p2_path: String = str(_level_set.get("player2_game", ""))

	NetworkManager.local_player_id = 1
	await _add_pane(1, p1_path)
	NetworkManager.local_player_id = 2
	await _add_pane(2, p2_path)

	# Left as the host's own number. Both games have already latched their side; what still
	# reads this member afterwards is round-summary attribution in NetworkManager, which in
	# here will credit pane 1. Documented rather than papered over: there is one autoload and
	# it can only be one player at a time.
	NetworkManager.local_player_id = 1


## One pane: a header naming the side, and a 16:9 SubViewport holding the real minigame.
func _add_pane(player_num: int, scene_path: String) -> void:
	var half := VBoxContainer.new()
	half.name = "Pane%d" % player_num
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.add_theme_constant_override("separation", 4)
	_pane_box.add_child(half)

	var role: String = str(NetworkManager.get_player_role(player_num))
	var caption := Label.new()
	caption.text = "P%d · %s · %s" % [player_num, role, scene_path.get_file().get_basename()]
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color",
		Color(0.55, 0.85, 1.0) if player_num == 1 else Color(1.0, 0.82, 0.5))
	half.add_child(caption)

	# 16:9 so a phone-shaped game is not squashed into a half-width pane. STRETCH_FIT
	# letterboxes inside the half instead of distorting it.
	var ratio := AspectRatioContainer.new()
	ratio.ratio = 1920.0 / 1080.0
	ratio.stretch_mode = AspectRatioContainer.STRETCH_FIT
	ratio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.add_child(ratio)

	# stretch = true sizes the SubViewport to the container; size_2d_override then lays the
	# game out at the authored 1920x1080 and scales that into whatever the pane is, so the
	# game's own anchors and font sizes are the ones it was designed with.
	var box := SubViewportContainer.new()
	box.name = "Pane%dView" % player_num
	box.stretch = true
	# Explicit rather than relying on the default: this is the property that decides whether a
	# touch inside this half is forwarded into this half's viewport at all, and it is the whole
	# "two independent inputs" half of the requirement. Mouse, touch and screen-drag events
	# reach a SubViewportContainer through gui_input, which an IGNORE filter never receives.
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ratio.add_child(box)

	var vp := SubViewport.new()
	vp.name = "Pane%dViewport" % player_num
	vp.size_2d_override = Vector2i(1920, 1080)
	vp.size_2d_override_stretch = true
	vp.handle_input_locally = true
	vp.gui_disable_input = false
	vp.physics_object_picking = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	_panes.append(vp)

	if scene_path == "" or not ResourceLoader.exists(scene_path):
		var missing := Label.new()
		missing.text = "missing scene:\n%s" % scene_path
		vp.add_child(missing)
		return

	var game: Node = load(scene_path).instantiate()
	vp.add_child(game)
	_pane_games.append(game)
	# Two frames, not one: the base awaits a process frame before it reads its side, so the
	# member must still say this pane's number on the frame AFTER the add_child.
	await get_tree().process_frame
	await get_tree().process_frame


# 
# LEAVING
# 

func _on_end_split() -> void:
	if AudioManager:
		AudioManager.play_click()
	# _exit_tree() does the restoring, so the same teardown runs whether the developer
	# leaves through this button, a pane's own QUIT, or a round that ended and routed
	# itself back to the Lab.
	get_tree().change_scene_to_file("res://scenes/ui/GameLab.tscn")


func _exit_tree() -> void:
	_restore_session()
	# The Lab entered the sandbox and every exit from here has to close it, including the
	# ones this screen does not own (a pane's QUIT goes to the real MultiplayerLobby and
	# would otherwise leave the session parked in sandbox mode for the rest of the run).
	# Going back to the Lab is safe too: GameLab._ready() enters the sandbox again.
	if GameManager and GameManager.has_method("exit_sandbox") and GameManager.is_sandbox():
		GameManager.exit_sandbox()
