extends Node

## ═══════════════════════════════════════════════════════════════════
## VERIFY: THE CO-OP ROLE NAMES
## ═══════════════════════════════════════════════════════════════════
## LevelSets names both halves of every pair — "Vegetable Washer" / "Plant Waterer",
## "Rain Catcher" / "Aquarium Keeper" — and swaps them every round. Ten authored names,
## and the HUD shows none of them:
##
##   1. ROUND 1. MultiplayerLobby._load_level_set_games() holds the level set, prints both
##      role names to the console, then calls start_multiplayer_game_pair(p1, p2) — which
##      takes only the two scene paths. The roles stay on the {1:"Collector", 2:"User"}
##      placeholder set at connect time, on both peers.
##   2. ROUNDS 2+. The host assigns the pair before broadcasting _load_next_round(), but
##      the RPC body — the code the CLIENT runs — never touches player_roles. So the host
##      reads "Rain Catcher" while the client still reads "User": the two peers disagree
##      about the client's own role for the rest of the session.
##   3. Nothing translates them. FIX 73 gave _role_display() a mp_role_<slug> lookup, and
##      only the two placeholder ids have a row. A Filipino player would read the English.
##
## The role STRING is an id as well as a caption: RainwaterHarvesting.gd branches on
## player_role == "Collector". That scene is reachable from nothing (its own audit banner
## records it), and the host has been overwriting player_roles with flavour names from
## round 2 since before this harness existed, so the branch is already dead either way —
## but it is why the fix localizes at the display layer instead of translating in place.
##
## The second entry in NetworkManager.players below stands in for a real client: the ready
## gate needs two registered peers. The one "Attempt to call RPC with unknown peer ID: 2" in
## this log is the hand-off's rpc_id(_load_game_scene) reaching for that stand-in, not a defect.
##
## Usage:
##   godot --headless --path <project> res://tools/VerifyMPRoles.tscn
## ═══════════════════════════════════════════════════════════════════

const SCENE: String = "res://scenes/multiplayer/MP_WashVegetables.tscn"
const PORT: int = 7811

var results: Array[bool] = []
var _lang_was: int = 0


func _ready() -> void:
	print("\n=== VerifyMPRoles ===")
	await get_tree().process_frame
	# Checks [6] and [7] end in change_scene_to_file(), which takes this harness's own scene out
	# of the tree — get_tree() reads null from here on, so the SceneTree is held before they run.
	var tree: SceneTree = get_tree()
	_lang_was = Localization.current_language
	await _run()
	Localization.set_language(_lang_was as Localization.Language)
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	tree.quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _preview(arr: Array, limit: int = 6) -> String:
	var shown: Array = arr.slice(0, limit)
	var s: String = " / ".join(shown)
	if arr.size() > limit:
		s += " / … +%d more" % (arr.size() - limit)
	return s


## Every readable string under a node, in pre-order.
func _texts(node: Node, out: Array[String]) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Label or node is Button or node is RichTextLabel:
		var t: String = str(node.get("text")).strip_edges()
		if t != "":
			out.append(t)
	for child in node.get_children():
		_texts(child, out)


## Every role name the five authored sets can hand a round. Read off LevelSets itself so a
## sixth set added later is covered without editing this harness.
func _authored_roles() -> Array[String]:
	var names: Array[String] = []
	for entry in LevelSets.LEVEL_SETS:
		for field in ["player1_role", "player2_role"]:
			var v: String = str(entry.get(field, "")).strip_edges()
			if v != "" and not names.has(v):
				names.append(v)
	names.sort()
	return names


## The table key the display layer derives from a role id. Mirrors
## MultiplayerMiniGameBase._role_display() rather than importing it, so a change on one
## side shows up as a failure instead of agreeing with itself.
func _role_key(role_id: String) -> String:
	return "mp_role_%s" % role_id.to_snake_case()


func _line(key: String) -> String:
	if Localization and Localization.has_text(key):
		return str(Localization.get_text(key)).strip_edges()
	return ""


func _run() -> void:
	var roles: Array[String] = _authored_roles()
	print("  authored role names (%d): %s" % [roles.size(), ", ".join(roles)])
	_check("[1] premise: every authored level set names both halves of the pair",
			roles.size() >= 10 and LevelSets.LEVEL_SETS.size() >= 5,
			"%d name(s) across %d set(s)" % [roles.size(), LevelSets.LEVEL_SETS.size()])

	# ── the table behind the HUD ──────────────────────────────────────
	Localization.set_language(Localization.Language.ENGLISH)
	await get_tree().process_frame
	var en: Dictionary = {}
	for r in roles:
		en[r] = _line(_role_key(r))
	Localization.set_language(Localization.Language.FILIPINO)
	await get_tree().process_frame
	var tl: Dictionary = {}
	for r in roles:
		tl[r] = _line(_role_key(r))

	var missing: Array[String] = []
	for r in roles:
		if str(en[r]) == "" or str(tl[r]) == "":
			missing.append("%s -> %s" % [r, _role_key(r)])
	_check("[2] every role a round can hand a player is in the translation table",
			missing.is_empty(),
			"%d of %d unreachable by _role_display(): %s" % [missing.size(), roles.size(), _preview(missing)])

	var same: Array[String] = []
	for r in roles:
		if str(en[r]) != "" and str(en[r]) == str(tl[r]):
			same.append("%s=\"%s\"" % [_role_key(r), en[r]])
	_check("[3] every role name reads in the player's language",
			same.is_empty(), "%d byte-identical: %s" % [same.size(), _preview(same)])

	# ── the HUD of a live round, in Filipino ──────────────────────────
	_check("[4] premise: a session is open, which the round shell gates on before it builds",
			GameManager.host_game(PORT),
			"connection_active=%s" % str(NetworkManager.connection_active))
	await _frames(2)
	# The pair the first authored set hands out. Set directly here so this check measures the
	# DISPLAY layer alone; whether the round-start path delivers it is [6] and [7].
	var probe_role: String = str(LevelSets.LEVEL_SETS[0]["player1_role"])
	var probe_partner: String = str(LevelSets.LEVEL_SETS[0]["player2_role"])
	NetworkManager.player_roles = {1: probe_role, 2: probe_partner}
	var packed := load(SCENE) as PackedScene
	var shown: Array[String] = []
	if packed != null:
		var game: Node = packed.instantiate()
		get_tree().root.add_child(game)
		var waited: float = 0.0
		while game.get("hud_layer") == null and waited < 8.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		await _frames(3)
		_texts(game, shown)
		game.queue_free()
		await _frames(2)
	var joined: String = "\n".join(shown)
	var want_mine: String = str(tl.get(probe_role, ""))
	var want_theirs: String = str(tl.get(probe_partner, ""))
	_check("[5] the round HUD names both roles in the player's language, not by their English ids",
			want_mine != "" and want_theirs != ""
				and joined.contains(want_mine) and joined.contains(want_theirs)
				and not joined.contains(probe_role) and not joined.contains(probe_partner),
			"%d label(s); mine \"%s\"=%s, partner \"%s\"=%s, raw English present=%s" % [
				shown.size(), probe_role, str(joined.contains(want_mine)),
				probe_partner, str(joined.contains(want_theirs)),
				str(joined.contains(probe_role) or joined.contains(probe_partner))])

	# ── the two round-start paths ─────────────────────────────────────
	# Both of the calls below end in change_scene_to_file(), which is deferred to the end of the
	# frame and would take this harness's own scene with it. Nothing is awaited from here on, so
	# every read lands before the frame ends.
	var set0: Dictionary = (LevelSets.LEVEL_SETS[0] as Dictionary).duplicate(true)
	var want_pair: Dictionary = {1: str(set0["player1_role"]), 2: str(set0["player2_role"])}
	# The ready gate needs two registered peers. This entry stands in for the client that a real
	# lobby would have; the host half is the one whose player_roles is read back.
	NetworkManager.players[2] = {"player_num": 2, "ready": true, "name": "Harness Stand-in"}
	for pid in NetworkManager.players.keys():
		NetworkManager.players[pid]["ready"] = true

	# ROUND 1: the lobby's hand-off. Probed for arity rather than assumed, so this runs clean
	# against a build whose hand-off cannot carry a level set at all — the point being measured.
	var arity: int = 0
	for m in NetworkManager.get_method_list():
		if str(m.get("name", "")) == "start_multiplayer_game_pair":
			arity = (m.get("args", []) as Array).size()
	NetworkManager.player_roles = {1: "Collector", 2: "User"}
	var args: Array = [str(set0["player1_game"]), str(set0["player2_game"])]
	if arity >= 3:
		args.append(set0)
	NetworkManager.callv("start_multiplayer_game_pair", args)
	var after_first: Dictionary = NetworkManager.player_roles.duplicate()
	_check("[6] the first round starts on the level set's roles, not the connect-time placeholder",
			after_first == want_pair,
			"hand-off takes %d arg(s); player_roles=%s want=%s" % [arity, str(after_first), str(want_pair)])

	# ROUNDS 2+: the body of the round-transition RPC, run after round 1 because that path's own
	# _reset_round_status() clears the ready flags the round-1 gate needs. The host runs this body
	# through call_local and the client runs the identical body on delivery, so what it assigns
	# here is what the client ends the round with.
	NetworkManager.player_roles = {1: "Collector", 2: "User"}
	NetworkManager._load_next_round(set0, 0, 3, 1)
	var after_next: Dictionary = NetworkManager.player_roles.duplicate()
	_check("[7] the round-transition RPC gives the receiving peer the round's roles",
			after_next == want_pair,
			"player_roles=%s want=%s" % [str(after_next), str(want_pair)])

