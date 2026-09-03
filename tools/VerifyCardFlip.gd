extends Node

## Does a memory card actually flip, or does it just change?
##
## WHAT WAS THERE
##   WaterMemory._flip_card() set back.visible = false, front.visible = true and
##   replaced the StyleBoxFlat, all in one frame. There was no tween anywhere in the
##   game -- a card's face changed between two frames with nothing to read as a flip,
##   no anticipation, and no reaction on the outcome: a matched pair turned green and
##   a wrong pair was snatched back over in the same frame the mismatch was decided.
##   In a memory game the flip is the whole interaction, so this was the one animation
##   that had to exist and it did not.
##
## WHAT IS ASSERTED
##   [1] the card squeezes through near-zero width and comes back (it is a flip)
##   [2] the face is swapped AT THE HINGE, not on the tap frame (you never see the
##       swap head-on)
##   [3] a matched pair pops past its resting size
##   [4] a wrong pair holds face-up long enough to be read, then reverts
##   [5] the board stays locked for that whole beat
##   [6] pivot_offset is centred, or scale.x slides the card instead of hinging it
##
##   Sampling is by wall clock, not by frame count: headless runs frames as fast as it
##   can, so N frames is not N/60 seconds and a 0.27 s tween would be sampled before
##   it had moved.
##
## Usage:
##   godot --headless --path . res://tools/VerifyCardFlip.tscn

const MEMORY: String = "res://scenes/minigames/WaterMemory.tscn"

var _pass: int = 0
var _fail: int = 0


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


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## Min and max of scale.x over `seconds` of real time, sampled every frame.
func _sample_scale(card: Control, seconds: float) -> Vector2:
	var lo: float = 99.0
	var hi: float = -99.0
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if not is_instance_valid(card):
			break
		lo = minf(lo, card.scale.x)
		hi = maxf(hi, card.scale.x)
		await get_tree().process_frame
	return Vector2(lo, hi)


func _live_round(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _frames(30)
	for _attempt in range(120):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await get_tree().process_frame
		if inst.get("game_active") == true:
			break
	return inst


## Two cards that share an emoji, and two that do not.
func _find_pair(cards: Array, same: bool) -> Array:
	for a in cards:
		if a.get_meta("matched", false):
			continue
		for b in cards:
			if a == b or b.get_meta("matched", false):
				continue
			var eq: bool = str(a.get_meta("emoji", "")) == str(b.get_meta("emoji", "?"))
			if eq == same:
				return [a, b]
	return []



## Every .gd under the given roots, recursively.
func _all_scripts(roots: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for r in roots:
		var d := DirAccess.open(r)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if d.current_is_dir():
				if not f.begins_with("."):
					out.append_array(_all_scripts([String(r).path_join(f)]))
			elif f.ends_with(".gd"):
				out.append(String(r).path_join(f))
			f = d.get_next()
		d.list_dir_end()
	return out

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== DOES A MEMORY CARD ACTUALLY FLIP? ===")
	print("")

	var m: Node = await _live_round(MEMORY)
	var cards: Array = m.get("cards")
	if cards.size() < 4:
		_check("[0] a board was built", false, "%d cards" % cards.size())
		get_tree().quit(1)
		return

	# ── [6] The hinge. ──
	var c0: Control = cards[0]
	_check("[6] the flip pivot is the card centre",
		c0.pivot_offset.is_equal_approx(c0.size * 0.5),
		"pivot_offset=%s size=%s" % [str(c0.pivot_offset), str(c0.size)])

	# ── [1] and [2] The flip itself. ──
	var front0: Node = c0.get_node_or_null("FrontLabel")
	m.call("_on_card_pressed", c0)
	await get_tree().process_frame
	_check("[2] the face is not swapped on the tap frame",
		front0 != null and front0.visible == false,
		"FrontLabel.visible one frame after the tap: %s"
			% (str(front0.visible) if front0 != null else "no FrontLabel"))
	var span: Vector2 = await _sample_scale(c0, 0.45)
	_check("[1] the card squeezes through the hinge and comes back",
		span.x < 0.35 and span.y > 1.03 and absf(c0.scale.x - 1.0) < 0.02,
		"scale.x ranged %.3f .. %.3f, settled at %.3f" % [span.x, span.y, c0.scale.x])
	_check("[2b] and the face is up once the flip has landed",
		front0.visible == true, "FrontLabel.visible after the flip: %s" % str(front0.visible))

	# ── [3] The match pop. ──
	var same: Array = _find_pair(cards, true)
	if same.size() != 2:
		_check("[3] setup: a matching pair exists", false, "none found")
	else:
		var before_pairs: int = int(m.get("pairs_found"))
		m.call("_on_card_pressed", same[0])
		await _wait_real(0.4)
		m.call("_on_card_pressed", same[1])
		# The resolve lands 0.6s later; sample across it and the pop that follows.
		var pop: Vector2 = await _sample_scale(same[0], 1.15)
		_check("[3] a matched pair pops past its resting size",
			pop.y > 1.15 and int(m.get("pairs_found")) == before_pairs + 1,
			"peak scale.x %.3f, pairs_found %d -> %d"
				% [pop.y, before_pairs, int(m.get("pairs_found"))])
		_check("[3b] and settles back to rest",
			absf(float(same[0].scale.x) - 1.0) < 0.03,
			"scale.x settled at %.3f" % float(same[0].scale.x))

	# ── [4] and [5] The mismatch beat. ──
	await _wait_real(0.5)
	var diff: Array = _find_pair(cards, false)
	if diff.size() != 2:
		_check("[4] setup: two non-matching cards exist", false, "none found")
	else:
		var f0: Node = diff[0].get_node_or_null("FrontLabel")
		var f1: Node = diff[1].get_node_or_null("FrontLabel")
		m.call("_on_card_pressed", diff[0])
		await _wait_real(0.4)
		m.call("_on_card_pressed", diff[1])
		# Resolve is at +0.6s; the hold runs to +0.95s. Read inside it.
		await _wait_real(0.78)
		var held: bool = f0.visible and f1.visible
		var locked: bool = m.get("can_flip") == false
		_check("[4] a wrong pair is still face-up after the mismatch is decided",
			held, "fronts visible mid-hold: %s / %s" % [str(f0.visible), str(f1.visible)])
		_check("[5] the board stays locked for the whole hold",
			locked, "can_flip mid-hold: %s" % str(m.get("can_flip")))
		await _wait_real(0.9)
		_check("[4b] then both turn back over",
			f0.visible == false and f1.visible == false,
			"fronts after the hold: %s / %s" % [str(f0.visible), str(f1.visible)])
		_check("[5b] and the board unlocks",
			m.get("can_flip") == true, "can_flip after the hold: %s" % str(m.get("can_flip")))

	m.queue_free()

	# [7] the API pitfall this game tripped over, swept project-wide. get_meta(name,
	# null) looks like a safe read with a null fallback and is not: inside Godot a NIL
	# default is indistinguishable from "no default was given", so the call errors and
	# WaterMemory printed "The object does not have any 'meta' values with the key
	# 'flip_tween'" on the first flip of every card -- 12 times in one 7-minute soak.
	# Nothing crashed, which is exactly why it survived; has_meta() first is the fix.
	var null_default: PackedStringArray = []
	for f in _all_scripts(["res://scenes", "res://scripts", "res://autoload"]):
		var ln: int = 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			ln += 1
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue
			# Plain string match, not RegEx: the pattern only has to spot the literal
			# ", null)" tail on a get_meta( call, and a GDScript string literal cannot
			# carry the escapes a regex for it would need.
			if not code.contains("get_meta("):
				continue
			var tail: String = code.substr(code.find("get_meta(") + 9)
			tail = tail.substr(0, tail.find(")") + 1) if tail.find(")") >= 0 else tail
			if tail.replace(" ", "").ends_with(",null)"):
				null_default.append("%s:%d" % [String(f).get_file(), ln])
	_check("[7] no get_meta(name, null) anywhere in the game code",
		null_default.is_empty(),
		"%d site(s): %s" % [null_default.size(), ", ".join(null_default)])

	await _frames(4)
	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
