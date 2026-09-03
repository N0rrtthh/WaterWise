extends Control

## DEV TOOL — Game Lab (Settings → Dev Mode → 🧪 Game Lab).
##
## A sandbox for playing any minigame on demand to judge whether the mechanic and
## its difficulty feel right, WITHOUT the round counting for anything:
##   * 25 single-player games and 12 co-op games, tagged SP / MP.
##   * Pick the tier the round runs at (Easy / Medium / Hard) instead of waiting
##     for the algorithm to hand you one.
##   * A readout of how the selected game FAILS at that tier - a clock of N
##     seconds, or a budget of N tries - read off the real game, not a table.
##   * The outcome of the last sandbox round, so a run can be judged immediately.
##
## WHAT "WILL NOT REFLECT ON THE MAIN GAME" MEANS HERE
## Every sink refuses a sandbox round at its own entry point, so the isolation
## does not depend on this screen remembering to ask for it. See the SANDBOX
## block in autoload/GameManager.gd for the list. Concretely, a Lab round does
## not touch: the save file (droplets, high scores, unlocks, play time), the
## session score or lives, the exported session JSON, AdaptiveDifficulty's
## rolling window, or CoopAdaptation's. The tier chosen here is parked and handed
## back on the way out.
##
## Multiplayer is NOT simulated. The co-op games need a real second peer, so the
## MP list stays unplayable until a session is actually connected, and the Lab
## says so instead of pretending. Only the host can start a round, which is the
## same authority rule the shipped round advance follows.

const SP_DIR := "res://scenes/minigames"
const MP_DIR := "res://scenes/multiplayer"
const TIERS := ["Easy", "Medium", "Hard"]

## Games whose scene root is not a MiniGameBase, so the fail-mode probe cannot
## instantiate them off-screen. Playing them still works.
const PROBE_SKIP := ["RainwaterHarvesting"]

var game_list: ItemList
var tier_buttons: Array[Button] = []
var play_button: Button
var probe_label: Label
var result_label: Label
var status_label: Label
var back_button: Button
var probe_host: SubViewport

var _entries: Array[Dictionary] = []
var _tier: String = "Medium"
var _probe_gen: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Open at the tier the session is actually on, so the first thing tried is the
	# difficulty the player is really experiencing. Coming back from a sandbox round
	# this is the tier that round was played at, which keeps the buttons steady
	# instead of snapping them to the default. enter_sandbox() parks the real tier,
	# so nothing here leaks into the session.
	if AdaptiveDifficulty:
		var live_tier := str(AdaptiveDifficulty.current_difficulty)
		if live_tier in TIERS:
			_tier = live_tier
	if GameManager:
		GameManager.enter_sandbox(_tier)

	_build_ui()
	_collect_games()
	_refresh_tier_buttons()
	_show_last_result()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.1, 0.15)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "GAME LAB — try any minigame, nothing is recorded"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var note := Label.new()
	note.text = "Sandbox: no droplets, no lives, no high scores, no session log, "
	note.text += "and the difficulty algorithm does not learn from these rounds."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	column.add_child(note)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)

	# -- Left: every playable game, single-player and co-op --
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.55
	body.add_child(left)

	var list_caption := Label.new()
	list_caption.text = "Games (tap one)"
	list_caption.add_theme_font_size_override("font_size", 18)
	left.add_child(list_caption)

	game_list = ItemList.new()
	game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_list.add_theme_font_size_override("font_size", 20)
	game_list.item_selected.connect(_on_game_selected)
	left.add_child(game_list)

	# -- Right: tier, fairness readout, play, last result --
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.45
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)

	var tier_caption := Label.new()
	tier_caption.text = "Difficulty to play at"
	tier_caption.add_theme_font_size_override("font_size", 18)
	right.add_child(tier_caption)

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	right.add_child(tier_row)
	for tier_name in TIERS:
		var tb := Button.new()
		tb.text = tier_name.to_upper()
		tb.custom_minimum_size = Vector2(0, 56)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 20)
		var picked: String = tier_name
		tb.pressed.connect(func() -> void: _on_tier_pressed(picked))
		tier_row.add_child(tb)
		tier_buttons.append(tb)

	probe_label = Label.new()
	probe_label.text = "How it can be lost: select a game."
	probe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probe_label.add_theme_font_size_override("font_size", 16)
	probe_label.custom_minimum_size = Vector2(0, 96)
	right.add_child(probe_label)

	play_button = Button.new()
	play_button.text = "> PLAY IN SANDBOX"
	play_button.custom_minimum_size = Vector2(0, 64)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	right.add_child(play_button)

	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.7))
	right.add_child(result_label)

	status_label = Label.new()
	status_label.text = "Select a game."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	right.add_child(status_label)

	back_button = Button.new()
	back_button.text = "< Back to Settings"
	back_button.custom_minimum_size = Vector2(0, 56)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.pressed.connect(_on_back)
	column.add_child(back_button)

	# Off-screen host for the fairness probe. A minigame reports its own fail
	# mode only once it has been instantiated and has run its difficulty pass,
	# so the readout below the tier buttons asks the real game instead of
	# repeating a table that could drift out of date. UPDATE_DISABLED because
	# nothing here is ever drawn.
	probe_host = SubViewport.new()
	probe_host.size = Vector2i(320, 180)
	probe_host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	probe_host.disable_3d = true
	add_child(probe_host)


func _collect_games() -> void:
	_entries.clear()
	game_list.clear()
	for game_name in _scan_dir(SP_DIR):
		_entries.append({"name": game_name, "mp": false,
			"path": "%s/%s.tscn" % [SP_DIR, game_name]})
		game_list.add_item("SP  %s" % game_name)
	var mp_names: Array = []
	if GameManager:
		mp_names = GameManager.multiplayer_minigames
	for game_name in mp_names:
		var path: String = "%s/%s.tscn" % [MP_DIR, game_name]
		if not ResourceLoader.exists(path):
			continue
		_entries.append({"name": game_name, "mp": true, "path": path})
		game_list.add_item("MP  %s" % game_name.trim_prefix("MP_"))
	status_label.text = "%d games listed. Select one." % _entries.size()


func _scan_dir(dir_path: String) -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return names
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".tscn"):
			names.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


func _refresh_tier_buttons() -> void:
	for i in range(tier_buttons.size()):
		var is_current: bool = TIERS[i] == _tier
		tier_buttons[i].disabled = is_current
		tier_buttons[i].text = ("* %s" % TIERS[i].to_upper()) if is_current \
			else TIERS[i].to_upper()


func _on_tier_pressed(tier_name: String) -> void:
	if AudioManager:
		AudioManager.play_click()
	_tier = tier_name
	if GameManager:
		GameManager.set_sandbox_tier(_tier)
	_refresh_tier_buttons()
	var sel := game_list.get_selected_items()
	if sel.size() > 0:
		_probe_selected(sel[0])


func _on_game_selected(index: int) -> void:
	play_button.disabled = false
	_probe_selected(index)


## Instantiate the selected game off-screen and report how a round of it ENDS at
## the current tier. Read straight after add_child(): MiniGameBase._ready() runs
## its difficulty pass before its first await, so fail_mode / attempts_max /
## game_duration are already final, and the instance can be dropped before it
## builds a board, starts music or waits for input.
func _probe_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var entry: Dictionary = _entries[index]
	var game_name: String = entry["name"]
	_probe_gen += 1
	var gen: int = _probe_gen

	if entry["mp"]:
		probe_label.text = "Co-op round: ends when both players finish their side. "
		probe_label.text += "Needs a real second player."
		_update_play_button(entry)
		return
	if game_name in PROBE_SKIP:
		probe_label.text = "%s: cannot be inspected off-screen, but it plays." % game_name
		_update_play_button(entry)
		return

	var packed := load(entry["path"]) as PackedScene
	if packed == null:
		probe_label.text = "%s: scene will not load." % game_name
		return
	var inst := packed.instantiate()
	if not inst.has_method("use_attempt_budget"):
		inst.free()
		probe_label.text = "%s: not a MiniGameBase game." % game_name
		_update_play_button(entry)
		return

	if GameManager:
		GameManager.set_sandbox_tier(_tier)
	probe_host.add_child(inst)
	var mode: String = str(inst.get("fail_mode"))
	var tries: int = int(inst.get("attempts_max"))
	var clock: float = float(inst.get("game_duration"))
	var nominal: float = float(inst.get("_nominal_duration"))
	var penalty: float = float(inst.get("mistake_time_penalty"))
	inst.queue_free()
	await get_tree().process_frame
	if gen != _probe_gen:
		return

	var lines: Array[String] = []
	if mode == "attempts":
		lines.append("Ends on MISTAKES: %d wrong tries allowed." % tries)
		var ceiling_note: String = "Clock %.0fs is only an anti-hang ceiling"
		ceiling_note += " - running it out still ends the round, but you are"
		ceiling_note += " meant to finish long before."
		lines.append(ceiling_note % clock)
		lines.append("(This game's timed length at %s would have been %.0fs.)" % [
			_tier, nominal])
	else:
		lines.append("Ends on the CLOCK: %.0fs." % clock)
		lines.append("Each mistake costs %.0fs off that clock." % penalty)
	probe_label.text = "\n".join(lines)
	_update_play_button(entry)


## Whether the selected entry can actually be started right now, and what the
## button does if it cannot. Co-op is never simulated: without a live session
## and host authority the button offers the lobby instead of a fake partner.
func _update_play_button(entry: Dictionary) -> void:
	if not entry["mp"]:
		play_button.disabled = false
		play_button.text = "> PLAY IN SANDBOX"
		status_label.text = "%s at %s. Starts straight in - no intro clip." % [
			entry["name"], _tier]
		return

	var live: bool = GameManager != null and GameManager.is_multiplayer_session_ready()
	var host: bool = GameManager != null and GameManager.is_host
	if live and host:
		play_button.disabled = false
		play_button.text = "> START CO-OP ROUND"
		status_label.text = "Both players are connected. This starts the round on "
		status_label.text += "both devices; co-op difficulty comes from CoopAdaptation, "
		status_label.text += "not from the tier buttons."
	elif live:
		play_button.disabled = true
		play_button.text = "> HOST ONLY"
		status_label.text = "Connected, but only the host can start a round - ask the "
		status_label.text += "host device to pick the game."
	else:
		play_button.disabled = false
		play_button.text = "> OPEN CO-OP LOBBY"
		status_label.text = "Co-op needs a real second player, so the Lab will not "
		status_label.text += "start this alone. Connect two devices in the lobby, then "
		status_label.text += "come back here and pick a co-op game. Opening the lobby "
		status_label.text += "leaves the sandbox."


func _on_play_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	var sel := game_list.get_selected_items()
	if sel.is_empty():
		status_label.text = "Select a game first."
		return
	var entry: Dictionary = _entries[sel[0]]
	var game_name: String = entry["name"]

	if entry["mp"]:
		_start_coop(game_name)
		return

	if GameManager == null:
		status_label.text = "GameManager is missing; cannot launch."
		return
	# Sandbox mode is already on (entered in _ready), so every sink is refusing
	# writes before the round even loads. The tier is re-asserted here because the
	# probe instantiates games, and a game is free to read the tier again.
	GameManager.enter_sandbox(_tier)
	GameManager.set_game_mode(GameManager.GameMode.SINGLE_PLAYER)
	GameManager.pending_next_minigame_name = game_name
	# Straight to the round rather than through _start_intro_cutscene_for_game():
	# the intro clips already have their own viewer (Settings -> Beat Viewer), and
	# what is being judged here is the mechanic.
	GameManager.launch_pending_minigame()


func _start_coop(game_name: String) -> void:
	if GameManager == null:
		status_label.text = "GameManager is missing; cannot launch."
		return
	if not GameManager.is_multiplayer_session_ready():
		GameManager.exit_sandbox()
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
		return
	if not GameManager.start_multiplayer_round_named(game_name):
		status_label.text = "%s refused to start - see the console warning." % game_name


## The outcome of the round that just came back to the Lab. GameManager.
## complete_minigame() fills sandbox_last_result and returns before recording
## anything, so this is the only place the round is reported at all.
func _show_last_result() -> void:
	if GameManager == null or GameManager.sandbox_last_result.is_empty():
		result_label.text = ""
		return
	var r: Dictionary = GameManager.sandbox_last_result
	var verdict: String = "WON" if bool(r.get("was_successful", false)) else "LOST"
	var lines: Array[String] = []
	lines.append("Last sandbox round: %s - %s at %s" % [
		str(r.get("game_name", "?")), verdict, str(r.get("difficulty", "?"))])
	lines.append("accuracy %.0f%%   mistakes %d   best combo %d" % [
		float(r.get("accuracy", 0.0)) * 100.0,
		int(r.get("mistakes", 0)),
		int(r.get("best_combo", 0))])
	lines.append("score %d   time on task %.1fs   (not recorded anywhere)" % [
		int(r.get("score", 0)), float(r.get("reaction_time", 0)) / 1000.0])
	result_label.text = "\n".join(lines)


func _on_back() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.exit_sandbox()
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")
