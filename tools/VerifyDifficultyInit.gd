extends Node

## ═══════════════════════════════════════════════════════════════════
## DIFFICULTY-AT-INIT VERIFICATION (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## MiniGameBase._ready() is a coroutine. A subclass calls super._ready() partway
## through its own _ready(), and that call returns at the base's first `await` —
## so everything the base did after that await happened a frame LATER than the
## rest of the subclass's board construction.
##
## _apply_difficulty_settings() used to sit after the await. Every minigame that
## read a difficulty-tuned value while building its board therefore got the member
## initializer instead of the value the algorithm had chosen:
##
##   • VegetableBath  built 5 veggies for a quota of 3 (two deliveries past the
##                    quota, two rejected end_game(true) calls, score 35 → 65).
##   • PlugTheLeak    laid out the default 3 pipes while max_water_waste and
##                    game_duration were sized for the difficulty's num_pipes.
##   • MudPieMaker    drew the gauge's green zone from the default 35–65 band while
##                    grading against the difficulty band (Easy 25–75, Hard 42–58):
##                    the visible target was not the graded target.
##   • FilterBuilder  built its solution guides from the initializer `true`,
##                    ignoring the algorithm's visual_guidance output.
##   • 14 more games  printed a stale "0 / N" quota on their score label.
##
## The fix moved _load_difficulty_settings() + _apply_difficulty_settings() above
## the await and queued the chaos effects so they still spawn after the board
## exists. This harness asserts the result for every affected game, at every
## difficulty, by booting the real scene and reading the real board.
##
## Difficulty is forced the way the algorithm forces it: assigning
## AdaptiveDifficulty.current_difficulty, which is what get_difficulty_settings()
## reads. No stubbing.
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyDifficultyInit.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

const DIFFICULTIES: PackedStringArray = ["Easy", "Medium", "Hard"]

## scene stem → the member holding the quota its score label prints.
##
## BucketBrigade, CatchTheRain, FixLeak and GreywaterSorter are deliberately
## absent: their scenes run the v2 MicrogameShell scripts, whose HUD prints a bare
## score ("0") instead of a "done / quota" ratio — CatchTheRainV2 shows its quota
## as a rising water level and draws no numeric label at all. There is no ratio
## label to check, and the shell builds its board in _shell_setup() (called from
## _setup_ui(), after the frame wait) so it was never exposed to the ordering bug
## this harness covers. tools/VerifyShellV2.tscn checks those four instead.
const QUOTA_GAMES: Dictionary = {
	"CloudCatcher": "target_plants",
	"CoverTheDrum": "max_allowed_in",
	"FilterBuilder": "target_filters",
	"QuickShower": "target_showers",
	"ScrubToSave": "target_dishes",
	"SpotTheSpeck": "target_correct",
	"SwipeTheSoap": "target_soaps",
	"TimingTap": "target_containers",
	"ToiletTankFix": "target_tanks",
	"TracePipePath": "target_paths",
	"TurnOffTap": "target_taps",
	"VegetableBath": "veggies_to_wash",
	"WaterMemory": "total_pairs",
}


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE DIFFICULTY-AT-INIT VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	for diff in DIFFICULTIES:
		print("")
		print("── %s ──" % diff)
		await _verify_quota_labels(diff)
		await _verify_plug_the_leak(diff)
		await _verify_mud_pie_gauge(diff)
		await _verify_filter_builder_guides(diff)

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("    ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	print("")

	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("    ✗ %s  %s" % [label, detail])


## Boot a minigame with `diff` forced, and stop while the instruction overlay is
## still up — the board is fully built by then and no round has started.
func _boot(stem: String, diff: String) -> Node:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = diff
		AdaptiveDifficulty.progressive_level = 0

	var scene := load("res://scenes/minigames/%s.tscn" % stem) as PackedScene
	if scene == null:
		_check("%s.tscn loads" % stem, false, "load() returned null")
		return null

	var game: Node = scene.instantiate()
	add_child(game)
	# _ready() spans two frames by design (the base awaits one); a few more frames
	# cover the deferred theme refresh.
	for _i in range(6):
		await get_tree().process_frame
	return game


func _teardown(game: Node) -> void:
	if game and is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame


## First Label under `root` whose text contains " / ", depth first.
func _find_ratio_label(root: Node) -> Label:
	for child in root.get_children():
		if child is Label and (child as Label).text.contains(" / "):
			return child
		var found := _find_ratio_label(child)
		if found:
			return found
	return null


## The integer after " / " in a "🥬 Clean: 0 / 3" style label.
func _denominator(text: String) -> int:
	var tail := text.get_slice(" / ", 1)
	var digits := ""
	for c in tail:
		if c >= "0" and c <= "9":
			digits += c
		elif digits != "":
			break
	return int(digits) if digits != "" else -1


func _verify_quota_labels(diff: String) -> void:
	for stem in QUOTA_GAMES:
		var prop: String = QUOTA_GAMES[stem]
		var game: Node = await _boot(stem, diff)
		if game == null:
			continue

		var quota: int = int(game.get(prop))
		var lbl := _find_ratio_label(game)
		if lbl == null:
			_check("%s/%s: score label found" % [stem, diff], false,
				"no Label containing ' / '")
			await _teardown(game)
			continue

		var shown: int = _denominator(lbl.text)
		_check("%s/%s: label shows the graded quota" % [stem, diff],
			shown == quota,
			"label reads \"%s\" (%d) but %s is %d" % [lbl.text, shown, prop, quota])
		await _teardown(game)


## PlugTheLeak builds its pipe row from num_pipes, and derives max_water_waste and
## game_duration from the same number. A board built from the initializer while the
## budget was built from the difficulty is not the game the algorithm asked for.
func _verify_plug_the_leak(diff: String) -> void:
	var game: Node = await _boot("PlugTheLeak", diff)
	if game == null:
		return
	var want: int = int(game.num_pipes)
	var got: int = (game.pipes as Array).size()
	print("    PlugTheLeak %-6s num_pipes=%d pipes built=%d duration=%.1fs waste_cap=%.0f"
		% [diff, want, got, float(game.game_duration), float(game.max_water_waste)])
	_check("PlugTheLeak/%s: a pipe exists per num_pipes" % diff, got == want,
		"built %d pipes for num_pipes=%d" % [got, want])
	await _teardown(game)


## MudPieMaker's green zone is drawn from target_min/target_max; _check_result()
## grades against the same pair. If the draw ran before the difficulty landed, the
## band the player aims at is not the band being graded.
func _verify_mud_pie_gauge(diff: String) -> void:
	var game: Node = await _boot("MudPieMaker", diff)
	if game == null:
		return

	var gauge: Node = game.get("gauge_node")
	var zone := gauge.get_node_or_null("TargetZone") as Polygon2D if gauge else null
	if zone == null:
		_check("MudPieMaker/%s: gauge target zone found" % diff, false,
			"no TargetZone under gauge_node")
		await _teardown(game)
		return

	# Same arithmetic _create_gauge() uses, with its 280px gauge height.
	var gauge_height: float = 280.0
	var pts: PackedVector2Array = zone.polygon
	var drawn_height: float = absf(pts[2].y - pts[0].y)
	var want_height: float = (float(game.target_max) - float(game.target_min)) \
		/ 100.0 * gauge_height
	print("    MudPieMaker %-6s band=%.0f–%.0f → zone %.1fpx (expected %.1fpx)"
		% [diff, float(game.target_min), float(game.target_max), drawn_height,
			want_height])
	_check("MudPieMaker/%s: the drawn band is the graded band" % diff,
		absf(drawn_height - want_height) < 1.0,
		"zone is %.1fpx tall, the %.0f–%.0f band needs %.1fpx"
			% [drawn_height, float(game.target_min), float(game.target_max),
				want_height])
	await _teardown(game)


## FilterBuilder's show_solution_guide comes from difficulty_settings.visual_guidance
## — one of the four adaptive outputs the paper specifies. The guides are built
## during _ready(), so reading the initializer meant Hard silently kept its guides.
func _verify_filter_builder_guides(diff: String) -> void:
	var game: Node = await _boot("FilterBuilder", diff)
	if game == null:
		return

	var want: bool = bool(game.difficulty_settings.get("visual_guidance", true))
	var got: bool = bool(game.show_solution_guide)
	print("    FilterBuilder %-6s visual_guidance=%s show_solution_guide=%s"
		% [diff, want, got])
	_check("FilterBuilder/%s: guides follow the algorithm's visual_guidance" % diff,
		got == want,
		"visual_guidance=%s but show_solution_guide=%s" % [want, got])
	await _teardown(game)
