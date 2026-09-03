extends Node
## Does the algorithm's chaos_effects output actually reach the games?
##
## AdaptiveDifficulty publishes a chaos_effects list per tier (Easy: none,
## Medium: screen_shake_mild, Hard: five effects). MiniGameBase queues that list
## in _apply_difficulty_settings() and drains it in _ready() once the board exists.
## A subclass that overrides _apply_difficulty_settings() WITHOUT calling super()
## never fills the queue, so the algorithm's decision is silently dropped for that
## game - the tier changes its numbers but not its chaos.
##
## Measured here rather than read off the source: each game is instantiated at Hard,
## and the queue is read synchronously right after add_child() (MiniGameBase applies
## difficulty before its first await), then again after the drain frame.
##
## Easy is the control: the paper specifies no chaos there, so a harness that
## reported "queued" for every game at every tier would be measuring nothing.
##
## Run: Godot_v4.7.2 --headless --path . tools/VerifyChaosEffects.tscn

const SP_DIR := "res://scenes/minigames"

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s%s" % [label, "" if detail == "" else "   " + detail])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if detail == "" else "   " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _games() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(SP_DIR)
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


## One game at one tier. Returns [queued_at_ready, asked_for, drained_after] or
## an empty array when the scene is not a MiniGameBase.
func _measure(game_name: String, tier: String) -> Array:
	var path := "%s/%s.tscn" % [SP_DIR, game_name]
	if not ResourceLoader.exists(path):
		return []
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad:
		ad.current_difficulty = tier
	var packed := load(path) as PackedScene
	if packed == null:
		return []
	var inst := packed.instantiate()
	if not inst.has_method("_activate_pending_chaos_effects"):
		inst.free()
		return []
	get_tree().root.add_child(inst)
	# Read before any await: _ready() has run its difficulty pass and is parked on
	# its first process_frame, so the queue is still full.
	var queued: int = (inst.get("_pending_chaos_effects") as Array).size()
	var asked: int = (inst.get("chaos_effects_active") as Array).size()
	await _frames(4)
	var left: int = -1
	if is_instance_valid(inst):
		left = (inst.get("_pending_chaos_effects") as Array).size()
		inst.queue_free()
	await _frames(3)
	return [queued, asked, left]


func _ready() -> void:
	print("=== CHAOS EFFECT DELIVERY GATE ===")
	await _frames(2)
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		# Nothing here is a real round, and instantiating 25 games would otherwise
		# leave 25 rounds' worth of noise in the save and the session log.
		gm.enter_sandbox("Hard")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad == null:
		_check("AdaptiveDifficulty present", false)
		get_tree().quit(1)
		return

	var hard_expected: int = (ad.DIFFICULTY_SETTINGS["Hard"]["chaos_effects"] as Array).size()
	var easy_expected: int = (ad.DIFFICULTY_SETTINGS["Easy"]["chaos_effects"] as Array).size()
	print("  (the algorithm asks for %d effects at Hard, %d at Easy)" % [
		hard_expected, easy_expected])
	print("")
	print("-- Hard: every game must queue what the algorithm asked for")
	var skipped: Array[String] = []
	for game_name in _games():
		var m: Array = await _measure(game_name, "Hard")
		if m.is_empty():
			skipped.append(game_name)
			continue
		_check("%s queues the algorithm's chaos" % game_name,
			int(m[0]) == hard_expected and int(m[1]) == hard_expected,
			"queued %d of %d asked" % [int(m[0]), int(m[1])])
		_check("%s drains the queue once its board exists" % game_name, int(m[2]) == 0,
			"%d left" % int(m[2]))

	print("")
	print("-- Easy: the control - the paper specifies no chaos there")
	# Two games that build very differently, one from each side of the sweep above.
	for game_name in ["TracePipePath", "VegetableBath"]:
		var m: Array = await _measure(game_name, "Easy")
		if m.is_empty():
			continue
		_check("%s queues nothing at Easy" % game_name,
			int(m[0]) == easy_expected and int(m[1]) == easy_expected,
			"queued %d, asked %d" % [int(m[0]), int(m[1])])

	if not skipped.is_empty():
		print("")
		print("  (not MiniGameBase, not measurable off-screen: %s)" % ", ".join(skipped))
	if gm:
		gm.exit_sandbox()
	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
