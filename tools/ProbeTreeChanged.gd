extends Node

## ═══════════════════════════════════════════════════════════════════
## SceneTree.tree_changed FAN-OUT PROBE
## ═══════════════════════════════════════════════════════════════════
## AccessibilityManager._connect_scene_events() picks its scene-change hook like
## this:
##
##     if get_tree().has_signal("current_scene_changed"):
##         ... connect to it ...
##     else:
##         get_tree().tree_changed.connect(_on_tree_changed)
##
## Two things to establish before touching it, because both are guesses otherwise:
##   1. whether SceneTree actually has "current_scene_changed" on this engine
##      build — if it does not, the first branch is dead code and every session
##      runs on tree_changed;
##   2. how often tree_changed fires during real gameplay. It is emitted on EVERY
##      node add and remove anywhere in the tree, so a minigame that spawns and
##      frees droplets emits it continuously, and the handler runs on the main
##      thread inside the 16.6 ms frame budget of the thesis's low-end target.
##
## The probe connects its own counter with the same body shape as the handler
## under test and reports emissions/second plus the total time that body spent.
## No claim about the handler being too expensive is made here — the numbers are
## the point.
##
## Run:
##   godot --headless --path . res://tools/ProbeTreeChanged.tscn

const SCENE: String = "res://scenes/minigames/CatchTheRain.tscn"
const SAMPLE_SECONDS: float = 6.0

var fires: int = 0
var body_usec: int = 0
var adds: int = 0
var _last_scene: Node = null
var _detached: bool = false

func _ready() -> void:
	if not _detached:
		# change_scene_to_file() frees the outgoing current_scene, which for a
		# tool-scene launch is this node.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "TreeChangedProbe"
		get_tree().root.add_child.call_deferred(twin)
		return
	_boot()


func _boot() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  tree_changed FAN-OUT PROBE")
	print("═══════════════════════════════════════════════════════════")
	var tree := get_tree()
	print("  SceneTree.has_signal(\"current_scene_changed\") = %s"
		% str(tree.has_signal("current_scene_changed")))
	print("  AccessibilityManager connected to tree_changed = %s"
		% str(tree.tree_changed.is_connected(
			Callable(AccessibilityManager, "_on_tree_changed"))))

	# _wait_for_input() returns after 0.8 s when auto-play is on, which is the only
	# headless way past "tap to start". The field is set directly rather than through
	# set_auto_play_enabled() so the probe does not write the user's settings file.
	AutoPlayManager.auto_play_enabled = true
	tree.change_scene_to_file(SCENE)
	await tree.create_timer(1.0).timeout
	print("  scene up: %s" % str(tree.current_scene.scene_file_path if tree.current_scene else "<null>"))

	# The overlay only clears once _wait_for_input() returns; before that the game
	# spawns nothing and a zero reading would say nothing about gameplay.
	var mg := tree.current_scene
	if mg == null:
		print("  !! no scene; the sample would be vacuous")
	else:
		print("  waiting out the tap-to-start bypass — game_active = %s" % str(mg.get("game_active")))
	await tree.create_timer(2.0).timeout

	tree.node_added.connect(_count_added)
	tree.tree_changed.connect(_count)
	var t0 := Time.get_ticks_usec()
	await tree.create_timer(SAMPLE_SECONDS).timeout
	var elapsed_usec := Time.get_ticks_usec() - t0
	tree.tree_changed.disconnect(_count)
	tree.node_added.disconnect(_count_added)

	var per_sec := float(fires) / (float(elapsed_usec) / 1_000_000.0)
	print("")
	print("  control: nodes added   : %d (a zero here makes the sample vacuous)" % adds)
	print("  emissions              : %d over %.2f s" % [fires, float(elapsed_usec) / 1e6])
	print("  emissions/second       : %.1f" % per_sec)
	print("  handler-body total     : %.2f ms" % (float(body_usec) / 1000.0))
	print("  handler-body share     : %.4f %% of wall time"
		% (100.0 * float(body_usec) / float(elapsed_usec)))
	print("  per 16.6 ms frame      : %.1f emissions, %.3f µs of handler"
		% [per_sec * 0.0166, float(body_usec) / (float(elapsed_usec) / 16600.0)])
	print("═══════════════════════════════════════════════════════════")
	print("")
	tree.quit(0)


## Same shape as AccessibilityManager._on_tree_changed: the guards, the
## current_scene fetch and the comparison. The deferred re-apply is deliberately
## NOT called — this measures the per-emission cost, not the scene-change cost.
func _count() -> void:
	var t0 := Time.get_ticks_usec()
	fires += 1
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			var current := tree.current_scene
			if current != _last_scene:
				_last_scene = current
	body_usec += Time.get_ticks_usec() - t0


## Control: tree_changed is emitted on node add/remove, so if nothing was added
## during the window the emission count says nothing about gameplay.
func _count_added(_n: Node) -> void:
	adds += 1
