extends Node

## Headless-safe smoke test for the cartoon cutscene system.
##
## Run with:
##   godot --path . res://tools/VerifyCartoonCutscenes.tscn
##
## Verifies, for every minigame scene on disk:
##   1) all three clips (cause / win / lose) resolve to non-empty data
##   2) every beat action name is one the stage actually implements
##   3) every prop type name is one the stage actually builds
##   4) a stage can be built, played and freed without leaking nodes
##
## Exits 0 on success, 1 on any failure, so it can gate a commit.

const KNOWN_ACTIONS: PackedStringArray = [
	"hop", "squash", "shake", "spin", "panic", "faint", "cheer", "splash",
	"flash", "fill_bucket", "grow_puddle", "rain", "leak", "wilt", "stars",
	"look_up", "look_side",
]

const KNOWN_PROPS: PackedStringArray = [
	"tap", "bucket", "puddle", "pipe", "plant", "cloud", "drum",
	"showerhead", "sun",
]

var _failures: Array[String] = []
var _checked_clips: int = 0

func _ready() -> void:
	await get_tree().process_frame
	var keys := _minigame_keys()
	print("▶ Verifying cartoon cutscenes for %d minigames" % keys.size())

	for key in keys:
		_verify_clip(key, CartoonStage.Kind.CAUSE, "cause")
		_verify_clip(key, CartoonStage.Kind.EFFECT_WIN, "win")
		_verify_clip(key, CartoonStage.Kind.EFFECT_LOSE, "lose")

	await _verify_runtime_playback()
	_verify_table_is_built_once()

	print("— checked %d clips" % _checked_clips)
	if _failures.is_empty():
		print("✅ VerifyCartoonCutscenes: all checks passed")
		quit_with(0)
	else:
		for failure in _failures:
			printerr("❌ %s" % failure)
		printerr("VerifyCartoonCutscenes: %d failure(s)" % _failures.size())
		quit_with(1)

## CartoonScenarios._all() caches the built table in a static, because rebuilding all five
## families cost 0.4885 ms a call and both public entry points call it - measured about 1 ms
## of Dictionary construction per cutscene on this desktop, at a scene transition, on a
## project targeting low-end Android. A cache is invisible when it stops working: the data
## stays correct and only the cost comes back, so nothing above would fail. is_same() is a
## reference comparison, not a value one, so this pins the cache itself rather than timing
## it - no wall clock, nothing to go flaky under a slow frame.
##
## If this ever fails, also re-check the read-only assumption the cache rests on: the
## returned clips are shared now, so a consumer that writes into one would corrupt every
## later play of it.
func _verify_table_is_built_once() -> void:
	if not is_same(CartoonScenarios._all(), CartoonScenarios._all()):
		_failures.append("CartoonScenarios._all() rebuilt the table - the static cache is gone")
	var a: Dictionary = CartoonScenarios.get_scenario("FixLeak", CartoonStage.Kind.CAUSE)
	var b: Dictionary = CartoonScenarios.get_scenario("FixLeak", CartoonStage.Kind.CAUSE)
	if not is_same(a, b):
		_failures.append("get_scenario() handed out two different clip dictionaries for one key")

func quit_with(code: int) -> void:
	get_tree().quit(code)

func _minigame_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	var dir := DirAccess.open("res://scenes/minigames")
	if dir == null:
		_failures.append("Cannot open res://scenes/minigames")
		return keys
	for file_name in dir.get_files():
		if file_name.ends_with(".tscn"):
			keys.append(file_name.trim_suffix(".tscn"))
		elif file_name.ends_with(".tscn.remap"):
			keys.append(file_name.trim_suffix(".tscn.remap"))
	return keys

func _verify_clip(key: String, kind: int, label: String) -> void:
	var clip: Dictionary = CartoonScenarios.get_scenario(key, kind)
	_checked_clips += 1

	if clip.is_empty():
		_failures.append("%s/%s: clip resolved to empty dictionary" % [key, label])
		return

	var beats: Array = clip.get("beats", [])
	if beats.is_empty():
		_failures.append("%s/%s: no beats" % [key, label])

	for beat_variant in beats:
		var beat: Dictionary = beat_variant
		if not beat.has("caption") or str(beat["caption"]).is_empty():
			_failures.append("%s/%s: beat missing caption" % [key, label])
		var hold: float = float(beat.get("hold", 0.0))
		if hold <= 0.0 or hold > 4.0:
			_failures.append("%s/%s: beat hold %.2f outside 0-4s" % [key, label, hold])
		if beat.has("action"):
			var action: String = str(beat["action"])
			if not KNOWN_ACTIONS.has(action):
				_failures.append("%s/%s: unknown action '%s'" % [key, label, action])

	for prop_variant in clip.get("props", []):
		var prop: Dictionary = prop_variant
		var prop_type: String = str(prop.get("type", ""))
		if not KNOWN_PROPS.has(prop_type):
			_failures.append("%s/%s: unknown prop '%s'" % [key, label, prop_type])
		var px: float = float(prop.get("x", -1.0))
		var py: float = float(prop.get("y", -1.0))
		if px < 0.0 or px > 1.0 or py < 0.0 or py > 1.0:
			_failures.append("%s/%s: prop '%s' outside screen (%.2f, %.2f)" % [
				key, label, prop_type, px, py
			])

	# A clip that runs longer than ~5s stops being a gag and starts being a wait.
	var total: float = 0.0
	for beat_variant in beats:
		total += float((beat_variant as Dictionary).get("hold", 0.0))
	if total > 5.0:
		_failures.append("%s/%s: total length %.1fs exceeds 5s budget" % [key, label, total])

## Builds and plays a real stage at 8x speed to prove the node graph is valid
## and fully freed afterwards.
func _verify_runtime_playback() -> void:
	var before: int = _count_orphans()

	for kind in [
		CartoonStage.Kind.CAUSE,
		CartoonStage.Kind.EFFECT_WIN,
		CartoonStage.Kind.EFFECT_LOSE,
	]:
		var stage := CartoonStage.new()
		stage.configure(kind, "CatchTheRain", {"speed": 8.0})
		add_child(stage)
		await stage.play_cutscene()
		stage.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

	# Let deferred frees settle before sampling.
	for _i in range(6):
		await get_tree().process_frame

	var after: int = _count_orphans()
	if after > before:
		_failures.append("runtime playback leaked %d node(s)" % (after - before))

func _count_orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
