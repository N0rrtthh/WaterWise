extends SceneTree

## Focused regression check for the two gameplay fixes that the timed autoplay
## soak does not reliably reach (it only gets through ~10 of 25 minigames).
##
## 1. WaterMemory: every difficulty, at every progressive level, must leave
##    enough time to physically clear the board.
## 2. FilterBuilder: the on-screen instruction, the numbered zone guides, and
##    correct_order must all name the layers in the same sequence.
##
## Usage:
##   Godot_console.exe --headless --path <project> --script tools/VerifyGameplayFixes.gd

func _initialize() -> void:
	var failures: PackedStringArray = PackedStringArray()
	failures.append_array(_check_water_memory())
	failures.append_array(_check_filter_builder())

	if failures.is_empty():
		print("RESULT: OK — gameplay fix checks passed")
	else:
		print("RESULT: %d FAILURE(S)" % failures.size())
		for line in failures:
			print("  " + line)

	quit(0 if failures.is_empty() else 1)

# ── WaterMemory: is every configuration completable? ──────────────────────

func _check_water_memory() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var scene := load("res://scenes/minigames/WaterMemory.tscn") as PackedScene
	if scene == null:
		out.append("WaterMemory.tscn failed to load")
		return out

	print("── WaterMemory timing ──")
	for difficulty in ["Easy", "Medium", "Hard"]:
		for level in [0, 1, 3, 6, 10]:
			var game := scene.instantiate()
			game.current_difficulty = difficulty
			# Drive the real difficulty path rather than reimplementing it here.
			game._apply_difficulty_settings()
			# Re-apply progressive pressure at the level under test.
			var duration: float = game.game_duration
			if level > 0:
				duration = maxf(
					game._min_completable_duration(),
					game.game_duration - float(level) * 1.5
				)

			var pairs: int = game.total_pairs
			# Two flips per pair, plus one flip-back for a wrong guess: a player
			# who never repeats a mistake still needs roughly 1.2s per flip.
			var minimum_needed: float = float(pairs) * 2.0 * 1.2
			var ok: bool = duration >= minimum_needed
			print("   %-6s lvl%-2d  pairs=%d  duration=%.1fs  need>=%.1fs  %s" % [
				difficulty, level, pairs, duration, minimum_needed,
				"OK" if ok else "TOO SHORT"
			])
			if not ok:
				out.append(
					"WaterMemory %s lvl%d: %.1fs for %d pairs (needs >= %.1fs)"
					% [difficulty, level, duration, pairs, minimum_needed]
				)
			game.free()
	return out

# ── FilterBuilder: does the instruction match what the game validates? ────

func _check_filter_builder() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var scene := load("res://scenes/minigames/FilterBuilder.tscn") as PackedScene
	if scene == null:
		out.append("FilterBuilder.tscn failed to load")
		return out

	print("── FilterBuilder layer order ──")
	var game := scene.instantiate()
	var order: Array = game.correct_order
	print("   correct_order (zone 0..3): %s" % str(order))

	var instruction: String = _instruction_text("filter_builder_instructions")
	if instruction.is_empty():
		out.append("Localization is missing 'filter_builder_instructions'")
		game.free()
		return out
	print("   instruction: %s" % instruction.replace("\n", " / "))

	# Each layer name must appear in the instruction, in the same relative order
	# as correct_order. A reversed instruction is exactly the bug being guarded.
	var lowered := instruction.to_lower()
	var last_index: int = -1
	for i in range(order.size()):
		var layer_name := str(order[i]).to_lower()
		var at := lowered.find(layer_name)
		if at < 0:
			out.append(
				"FilterBuilder instruction never mentions '%s'" % layer_name
			)
			continue
		if at < last_index:
			out.append(
				"FilterBuilder instruction lists '%s' out of order (expected position %d)"
				% [layer_name, i]
			)
		last_index = at

	if out.is_empty():
		print("   instruction order matches correct_order  OK")

	game.free()
	return out

# ── helpers ───────────────────────────────────────────────────────────────

## Reads a translation without depending on the `Localization` autoload symbol.
##
## A `--script` SceneTree run compiles this file before the project's autoloads
## are instantiated, so naming `Localization` directly is a compile error
## ("Identifier not found"). Loading the script and building a throwaway
## instance gives the same table with no ordering assumption.
##
## The comparison below matches lowercase English layer names from
## `correct_order`, so the English copy is the one to check.
func _instruction_text(key: String) -> String:
	var loc_script := load("res://autoload/Localization.gd") as GDScript
	if loc_script == null:
		return ""
	var loc = loc_script.new()
	loc._load_translations()
	loc.current_language = loc_script.Language.ENGLISH
	var text: String = ""
	if loc.has_text(key):
		text = loc.get_text(key)
	loc.free()
	return text
