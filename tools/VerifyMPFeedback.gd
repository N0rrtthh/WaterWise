extends Node

## Does a co-op round react to a hit and a miss the way a single-player round does?
##
## THE DEFECT
##   Reported as "multiplayer feels flat next to single player". It is literal, not a
##   matter of taste. A grep for play_collect / play_damage / Juice. / create_tween across
##   the twelve live MP_*.gd rounds returns exactly ONE tween in the whole family
##   (MP_WaterPlants' water splash). Everything the base class supplied was driven by
##   NETWORK traffic - the score label punches when the G-Counter syncs, LivesLabel recoils
##   when the host broadcasts a life - so the peer that actually caught the drop heard
##   nothing, saw no impact on the thing it caught with, and got no tint or shake when one
##   of three shared lives went. Single player has all four through MicrogameShell.
##
##   The fix hooks the two funnels every one of the twelve rounds already routes through -
##   add_score() and report_miss_to_host() - so no game can be missed, and takes an
##   optional Node2D for "the thing that should visibly react".
##
## WHAT IS MEASURED HERE
##   1. that all twelve live rounds reach those funnels at all, and that the reacting-node
##      argument is wired at the call sites rather than merely available.
##   2. the hit cue: the collect sting really reaches the audio pool, the passed node
##      squashes and returns exactly to its base scale, and the screen does NOT tint (a
##      full-screen blend per caught drop is the single most expensive thing that could be
##      put on the legacy phone's frame, and single player does not tint on success either).
##   3. the miss cue: damage sting, red tint, camera shake, node recoil.
##   4. that the shake moves the CAMERA and not the scene root. Every live MP scene is a
##      Node2D with Camera2D as a CHILD, so displacing the root moves the world and the
##      viewport by the same vector - a root shake is exactly invisible. This is why
##      Juice.shake(self) was not used, and it is checked rather than assumed.
##   5. that a second miss landing INSIDE the first shake still returns the camera home.
##      JuiceEffects.screen_shake() re-reads camera.offset as its return target, so a
##      restart mid-shake adopts a displaced position as "home" and parks the camera
##      off-centre for the rest of the round. MP_CatchTheRain reports a miss every third
##      dropped drop, so this is the normal case, not an edge case.
##   6. that the cue allocates once, not per event: ten misses must leave the HUD layer with
##      the same number of children as one, and a hit must allocate nothing at all.
##   7. that the full-screen tint cannot eat taps, and draws above the panels the subclasses
##      add to the same layer.
##   8. that the accessibility settings still hold: shake off means the camera does not move,
##      while the sting and the tint - which are not motion - still land; reduced motion
##      shortens the tint instead of ignoring the setting.
##   9. that none of it is networked and none of it can swallow the award: the points still
##      land, the shared lives are untouched by the cue itself, and the crossing hit that
##      ends the round still gets its sting.
##
## Usage:
##   godot --headless --path . res://tools/VerifyMPFeedback.tscn

const PORT: int = 7813
const SPECIMEN: String = "res://scenes/multiplayer/MP_CatchTheRain.tscn"

var results: Array = []
var game: MultiplayerMiniGameBase = null
var _scene_before: Node = null
var _shake_was: bool = true
var _reduced_was: bool = false
var _sfx_volume_was: float = 1.0


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== VerifyMPFeedback — hit and miss cues in a co-op round ===")

	_source_coverage()

	if not await _open_specimen():
		print("  RESULT: %d passed, %d failed" % [results.count(true), results.count(false) + 1])
		get_tree().quit(1)
		return

	await _hit_cue()
	await _miss_cue()
	await _shake_target()
	await _allocation_and_input()
	await _accessibility_gates()
	await _award_is_not_swallowed()

	await _teardown()
	var failed: int = results.count(false)
	print("")
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


## ═══════════════════════════════════════════════════════════════════════════════
## 1. Coverage: every live round reaches the funnels
## ═══════════════════════════════════════════════════════════════════════════════
## Read off LevelSets rather than off a glob of scripts/multiplayer, because LevelSets is
## what the lobby actually launches: the five MiniGame_*.gd in the same folder are the
## legacy family, reachable only from DebugMultiplayer, and they have their own effects
## layer. A game that is in the folder but not in a level set cannot be played.
func _source_coverage() -> void:
	print("")
	print("  -- all twelve live rounds reach the shared funnels --")
	var scripts: Array[String] = []
	for level_set in LevelSets.LEVEL_SETS:
		for key in ["player1_game", "player2_game"]:
			var scene_path: String = str(level_set.get(key, ""))
			if scene_path == "":
				continue
			var script_path: String = scene_path.replace("scenes/", "scripts/").replace(".tscn", ".gd")
			if not scripts.has(script_path):
				scripts.append(script_path)

	var scored: Array[String] = []
	var missed: Array[String] = []
	var with_node: Array[String] = []
	var unreadable: Array[String] = []
	for path in scripts:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			unreadable.append(path)
			continue
		var src: String = f.get_as_text()
		f.close()
		var name := path.get_file()
		# Comments in these files quote the funnels while explaining old payouts, so the
		# match has to be a call and not a mention: every real site is indented code.
		for line in src.split("\n"):
			var code: String = line.strip_edges()
			if code.begins_with("#") or code.begins_with("##"):
				continue
			if code.contains("add_score(") and not scored.has(name):
				scored.append(name)
			if code.contains("report_miss_to_host(") and not missed.has(name):
				missed.append(name)
			if not with_node.has(name):
				var hit_node: bool = code.contains("add_score(") \
					and (code.contains(", true, ") or code.contains(", false, "))
				var miss_node: bool = code.contains("report_miss_to_host(") \
					and not code.contains("report_miss_to_host()")
				if hit_node or miss_node:
					with_node.append(name)

	_check("every live round is readable, so this count means something",
		unreadable.is_empty() and scripts.size() == 12,
		"%d scenes in LevelSets, %d unreadable %s" % [scripts.size(), unreadable.size(), str(unreadable)])
	_check("all twelve live rounds award through add_score(), so all twelve get the hit cue",
		scored.size() == scripts.size(),
		"%d of %d: missing %s" % [scored.size(), scripts.size(), str(_missing(scripts, scored))])
	# MP_FilterWater has no failure state of its own — nothing is dropped, missed or timed
	# out in it — so it is the one round with no miss funnel to hook. Named rather than
	# counted, so a game that LOSES its miss path is not read as this known exception.
	_check("eleven of the twelve charge a miss, the twelfth having no failure state at all",
		missed.size() == 11 and not missed.has("MP_FilterWater.gd"),
		"%d charge a miss; without one: %s" % [missed.size(), str(_missing(scripts, missed))])
	_check("the reacting-node argument is wired at the call sites, not just available",
		with_node.size() >= 10,
		"%d of %d rounds pass a node on at least one site" % [with_node.size(), scripts.size()])


func _missing(all: Array, have: Array) -> Array:
	var out: Array = []
	for path in all:
		var name: String = str(path).get_file()
		if not have.has(name):
			out.append(name)
	return out


## ═══════════════════════════════════════════════════════════════════════════════
## Specimen setup
## ═══════════════════════════════════════════════════════════════════════════════
## MP_CatchTheRain is the specimen because it is the round the report came from and because
## it has both halves of the shape under test: a persistent Area2D (the bucket) that the
## action visibly lands on, and the Camera2D-as-a-child layout every live MP scene has.
##
## The round is opened by hand rather than through the lobby: the base gates on
## connection_active, which host_game() satisfies on its own, and it normally waits behind
## an instruction overlay for a tap that headless cannot deliver.
func _open_specimen() -> bool:
	print("")
	print("  -- opening MP_CatchTheRain --")
	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	# The pool has to be audible for a missing sting to be measurable at all. Restored in
	# _teardown() together with the two accessibility settings this file flips.
	_sfx_volume_was = AudioManager.sfx_volume
	if AudioManager.sfx_volume <= 0.0:
		AudioManager.sfx_volume = 0.5
	_shake_was = bool(SaveManager.get_setting("screen_shake", true))
	_reduced_was = bool(SaveManager.get_setting("reduced_motion", false))
	AccessibilityManager.set_screen_shake_enabled(true)
	AccessibilityManager.set_reduced_motion(false)

	var packed := load(SPECIMEN) as PackedScene
	if packed == null:
		_check("MP_CatchTheRain loads", false, SPECIMEN)
		return false
	game = packed.instantiate() as MultiplayerMiniGameBase
	get_tree().root.add_child(game)
	# The shared-target broadcast closes a round through get_tree().current_scene; see the
	# same handover in VerifyMPHouseholdChores for what happens without it.
	_scene_before = get_tree().current_scene
	get_tree().current_scene = game
	NetworkManager.clear_shared_target()
	var waited: float = 0.0
	while waited < 8.0 and game.get("bucket") == null:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1

	var bucket: Node = game.get("bucket")
	var cam: Camera2D = get_viewport().get_camera_2d()
	_check("the round built its bucket, which is the node the cue is asked to react on",
		bucket != null and bucket is Node2D,
		"bucket=%s" % ("<null>" if bucket == null else bucket.get_class()))
	# If the scene's camera is not the viewport's current camera, _fx_camera_shake() has
	# nothing to move and every shake row below would pass vacuously.
	_check("the scene's Camera2D is the viewport's current camera, so a shake has a target",
		cam != null and game.is_ancestor_of(cam),
		"camera=%s, inside the round=%s"
			% ["<null>" if cam == null else str(cam.name),
				str(cam != null and game.is_ancestor_of(cam))])
	# The camera really is a CHILD of the shaken world, which is why the root cannot be the
	# thing that shakes. Recorded here so the reason for check 4 is in the log.
	_check("the camera is a child of the scene root, so a root shake would be invisible",
		cam != null and cam.get_parent() == game,
		"camera parent=%s" % ("<null>" if cam == null else str(cam.get_parent().name)))

	game.game_active = true
	# The quota is switched off for the body of this run: add_score() ends the round the
	# moment the TEAM total crosses it, and the cue checks need the round to stay open. One
	# check below turns it back on deliberately.
	game.win_quota = 0
	NetworkManager.reset_g_counter()
	await _frames(2)
	return bucket != null and bucket is Node2D and cam != null


## The exact AudioStreamWAV a given sting resolves to. AudioManager caches generated streams
## by (wave, freq, duration), so this is the same INSTANCE play_sfx() assigns to a pooled
## player - identity, not a guess about whether something audible happened.
func _sting_stream(sfx_type: int) -> AudioStream:
	var def: Dictionary = AudioManager.sfx_definitions[sfx_type]
	return AudioManager._generate_sfx(float(def["freq"]), float(def["duration"]), str(def["wave"]))


func _clear_sfx_pool() -> void:
	for player in AudioManager.sfx_players:
		player.stop()
		player.stream = null


func _pool_holds(stream: AudioStream) -> int:
	var n: int = 0
	for player in AudioManager.sfx_players:
		if player.stream == stream:
			n += 1
	return n


## ═══════════════════════════════════════════════════════════════════════════════
## 2. The hit cue
## ═══════════════════════════════════════════════════════════════════════════════
func _hit_cue() -> void:
	print("")
	print("  -- a hit --")
	var bucket: Node2D = game.get("bucket")
	var base: Vector2 = Juice.base_scale(bucket)
	var hud_before: int = _hud_child_count()

	_clear_sfx_pool()
	var score_before: int = int(game.local_score)
	game.add_score(5, true, bucket)

	# Read before yielding: Juice.squash() writes the flattened scale on the spot and only
	# the return leg is tweened, so this is the frame the impact is visible on.
	var flat: Vector2 = bucket.scale
	_check("a hit puts the collect sting on the audio pool",
		_pool_holds(_sting_stream(AudioManager.SFXType.COLLECT)) == 1,
		"collect streams on the pool: %d of %d players"
			% [_pool_holds(_sting_stream(AudioManager.SFXType.COLLECT)),
				AudioManager.sfx_players.size()])
	_check("the node the action landed on is squashed the same frame",
		not flat.is_equal_approx(base),
		"bucket scale %s against a base of %s" % [str(flat), str(base)])
	_check("the award still lands - the cue runs first and cannot swallow it",
		int(game.local_score) == score_before + 5,
		"local_score %d -> %d" % [score_before, int(game.local_score)])

	# No tint on success. Single player does not tint on a hit either, and a full-screen
	# blend per caught drop is the most expensive thing that could be added to the legacy
	# phone's frame - the P2 device already misses its budget at 25.3 avg FPS.
	var flash: ColorRect = game._fx_flash
	_check("a hit does not tint the screen",
		flash == null or is_zero_approx(flash.color.a),
		"flash rect %s" % ("not built yet" if flash == null else "alpha %.3f" % flash.color.a))
	_check("a hit allocates nothing on the HUD layer",
		_hud_child_count() == hud_before,
		"HUD children %d -> %d" % [hud_before, _hud_child_count()])

	await get_tree().create_timer(0.55).timeout
	_check("the squash returns the node exactly to its base scale",
		bucket.scale.is_equal_approx(base),
		"bucket scale %s against a base of %s" % [str(bucket.scale), str(base)])

	# Ten hits in a row, one per frame: the elastic return is 0.3 s, so every one of these
	# restarts a live tween. Juice keeps one tween slot per property and rebases on the
	# cached base scale, so the node must still land exactly home rather than drifting.
	for _i in range(10):
		game.add_score(5, true, bucket)
		await get_tree().process_frame
	await get_tree().create_timer(0.55).timeout
	_check("ten hits inside each other's animations still leave the node exactly home",
		bucket.scale.is_equal_approx(base),
		"bucket scale %s after 10 rapid hits, base %s" % [str(bucket.scale), str(base)])

	# MP_FilterWater pays twice on one frame: five points for the particle, then a bonus for
	# the unit that particle completed. Two copies of one sting started on the same frame do
	# not read as louder, they phase against each other and read as a glitch.
	_clear_sfx_pool()
	game.add_score(5, true, null)
	game.add_score(20, false, null)
	_check("two awards on one frame sting once, not twice",
		_pool_holds(_sting_stream(AudioManager.SFXType.COLLECT)) == 1,
		"collect streams on the pool after a paired award: %d"
			% _pool_holds(_sting_stream(AudioManager.SFXType.COLLECT)))
	await get_tree().process_frame
	_clear_sfx_pool()
	game.add_score(5, true, null)
	_check("the next frame stings again, so the guard is per frame and not once per round",
		_pool_holds(_sting_stream(AudioManager.SFXType.COLLECT)) == 1,
		"collect streams on the pool a frame later: %d"
			% _pool_holds(_sting_stream(AudioManager.SFXType.COLLECT)))


func _hud_child_count() -> int:
	var layer: CanvasLayer = game.hud_layer
	return 0 if layer == null else layer.get_child_count()


## ═══════════════════════════════════════════════════════════════════════════════
## 3. The miss cue
## ═══════════════════════════════════════════════════════════════════════════════
## _juice_miss() is called directly here rather than through report_miss_to_host(), which
## also drains a shared team life: three of those and GameManager announces the team lost
## and tears the round down under the harness. The funnel itself is exercised once, in
## _award_is_not_swallowed(), with team_lives put back afterwards.
func _miss_cue() -> void:
	print("")
	print("  -- a miss --")
	var bucket: Node2D = game.get("bucket")
	var base: Vector2 = Juice.base_scale(bucket)

	_clear_sfx_pool()
	game._juice_miss(bucket)

	# Read before yielding: Juice.flash() sets the colour on the spot and tweens only the
	# fade, so this is the frame the tint is at full strength on.
	var flash: ColorRect = game._fx_flash
	var alpha_now: float = 0.0 if flash == null else flash.color.a
	var flat: Vector2 = bucket.scale

	_check("a miss puts the damage sting on the audio pool",
		_pool_holds(_sting_stream(AudioManager.SFXType.DAMAGE)) == 1,
		"damage streams on the pool: %d of %d players"
			% [_pool_holds(_sting_stream(AudioManager.SFXType.DAMAGE)),
				AudioManager.sfx_players.size()])
	_check("a miss tints the screen red at once, not after a delay",
		flash != null and alpha_now > 0.0 and flash.color.r > flash.color.b,
		"tint %s" % ("<no rect>" if flash == null else str(flash.color)))
	_check("the node that let it through recoils",
		not flat.is_equal_approx(base),
		"bucket scale %s against a base of %s" % [str(flat), str(base)])

	# The tint lives on the HUD CanvasLayer, not in the Node2D world. A Control parented to
	# a co-op scene root is drawn in WORLD space: it would neither cover the screen nor keep
	# covering it once the camera moved - the trap attach_hud_panel() already documents.
	_check("the tint hangs off the HUD CanvasLayer, not off the Node2D world",
		flash != null and flash.get_parent() == game.hud_layer,
		"parent=%s" % ("<no rect>" if flash == null else str(flash.get_parent().name)))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_check("the tint actually covers the screen",
		flash != null and flash.size.x >= vp.x - 1.0 and flash.size.y >= vp.y - 1.0,
		"rect %s in a %s viewport" % ["<none>" if flash == null else str(flash.size), str(vp)])

	await get_tree().create_timer(0.6).timeout
	_check("the tint fades all the way back to invisible",
		flash != null and is_zero_approx(flash.color.a),
		"alpha %.3f" % (-1.0 if flash == null else flash.color.a))
	_check("the recoil returns the node exactly to its base scale",
		bucket.scale.is_equal_approx(base),
		"bucket scale %s against a base of %s" % [str(bucket.scale), str(base)])


## ═══════════════════════════════════════════════════════════════════════════════
## 4. What the shake actually moves, and whether it comes home
## ═══════════════════════════════════════════════════════════════════════════════
## Every live co-op scene is a Node2D root with the Camera2D as its CHILD, so displacing the
## root displaces the camera by the same vector and the shake is exactly invisible - world
## and viewport move together and every pixel lands where it already was. Both halves are
## measured: the camera has to move, and the root has to not.
##
## The steps are ~0.05 s each, which a once-per-frame sample can walk straight past, so the
## clock is slowed for the duration of this section (see the same trick in the tween
## harnesses). Restored in _teardown() as well as here, in case a check below fails out.
func _shake_target() -> void:
	print("")
	print("  -- what the shake moves --")
	var cam: Camera2D = get_viewport().get_camera_2d()
	var root_home: Vector2 = game.position
	var scale_was: float = Engine.time_scale
	Engine.time_scale = 0.1

	game._fx_camera_home_set = false
	cam.offset = Vector2.ZERO
	game._juice_miss(null)
	var home: Vector2 = game._fx_camera_home
	var cam_peak: float = 0.0
	var root_peak: float = 0.0
	for _i in range(120):
		await get_tree().process_frame
		cam_peak = maxf(cam_peak, (cam.offset - home).length())
		root_peak = maxf(root_peak, (game.position - root_home).length())

	_check("a miss moves the camera",
		cam_peak > 1.0,
		"peak camera displacement %.2f units from a home of %s" % [cam_peak, str(home)])
	_check("a miss does NOT move the scene root, where the shake would be invisible",
		root_peak < 0.01,
		"peak root displacement %.4f units" % root_peak)

	# A second miss landing inside the first shake. JuiceEffects.screen_shake() reads
	# camera.offset live as the value to return to, so a restart mid-shake adopts a displaced
	# position as "home" and parks the camera off-centre for the rest of the round.
	# MP_CatchTheRain charges a miss on every drop that reaches the floor, so overlapping
	# shakes are the normal case here rather than an edge case.
	# Each restart has to land while the previous shake is genuinely still running, or the
	# row below passes without ever reproducing the situation. Counted rather than assumed:
	# headless runs uncapped, so a frame count is not a duration.
	var overlaps: int = 0
	for _i in range(3):
		game._juice_miss(null)
		await _frames(6)
		if game._fx_shake_tween != null and game._fx_shake_tween.is_valid():
			overlaps += 1
	game._juice_miss(null)
	_check("the restarts really did land inside a running shake",
		overlaps == 3, "%d of 3 restarts found the previous shake still running" % overlaps)
	
	# Waited out in REAL time rather than in frames. Six steps of motion_time(0.3)/6 at a
	# time_scale of 0.1 is about three seconds of wall clock, and 400 uncapped headless frames
	# are not that long: the first version of this row reported a camera 1.1 units from home
	# with the return leg still in flight, which is the harness running out of patience and not
	# the shake failing to come back.
	var settled: bool = false
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if game._fx_shake_tween == null or not game._fx_shake_tween.is_valid():
			settled = true
			break
	_check("overlapping shakes still return the camera exactly home",
		settled and cam.offset.is_equal_approx(home),
		"offset %s against a home of %s (shake finished=%s)"
			% [str(cam.offset), str(home), str(settled)])
	_check("the home the shake returns to is the offset the round started with",
		home.is_equal_approx(Vector2.ZERO),
		"stored home %s" % str(home))

	Engine.time_scale = scale_was


## ═══════════════════════════════════════════════════════════════════════════════
## 5. Cost per event, and whether the tint can eat taps
## ═══════════════════════════════════════════════════════════════════════════════
## MultiplayerMiniGameEffects._flash_screen() - the legacy family's version of this - builds a
## fresh ColorRect per event and queue_free()s it after: a Node allocation, a Control layout
## pass and a full-screen blend per miss, on a phone already at 25.3 avg FPS and 23.5% dropped
## frames. Ten misses through the pooled rect must leave the HUD layer exactly as one did.
func _allocation_and_input() -> void:
	print("")
	print("  -- cost per event, and input --")
	var before: int = _hud_child_count()
	for _i in range(10):
		game._juice_miss(null)
		await get_tree().process_frame
	_check("ten misses allocate nothing on the HUD layer beyond the one pooled rect",
		_hud_child_count() == before,
		"HUD children %d -> %d over 10 misses" % [before, _hud_child_count()])

	var flash: ColorRect = game._fx_flash
	_check("the tint cannot eat taps",
		flash != null and flash.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"mouse_filter=%s" % ("<no rect>" if flash == null else str(flash.mouse_filter)))
	# Subclasses add their own panels to this layer at times _fx_flash_rect() cannot know, so
	# tree order cannot decide who draws last. z_index can, and this is the check that says so.
	var highest_sibling: int = -1000
	for child in game.hud_layer.get_children():
		if child != flash and child is CanvasItem:
			highest_sibling = maxi(highest_sibling, (child as CanvasItem).z_index)
	_check("the tint draws above the panels the subclasses put on the same layer",
		flash != null and flash.z_index > highest_sibling,
		"tint z_index=%d, highest sibling z_index=%d"
			% [-1 if flash == null else flash.z_index, highest_sibling])
	# Only one, whatever the route in. _fx_flash_rect() is reached from every miss and from
	# nothing else, but a second rect parked at alpha 0 would be invisible in a screenshot
	# and would still cost a full-screen blend per frame it faded on.
	var rects: int = 0
	for child in game.hud_layer.get_children():
		if child.name == "FeedbackFlash":
			rects += 1
	_check("there is exactly one tint rect in the round",
		rects == 1, "FeedbackFlash children: %d" % rects)
	await get_tree().create_timer(0.6).timeout


## ═══════════════════════════════════════════════════════════════════════════════
## 6. The accessibility settings still hold
## ═══════════════════════════════════════════════════════════════════════════════
## "Reduce screen shake" has to win over the new cue, and it has to win over the MOTION only:
## a player who turned the shake off did not ask to stop hearing the round or to stop seeing
## that they were hit. Both halves are measured, because switching off the whole cue would
## look identical to a passing shake check.
func _accessibility_gates() -> void:
	print("")
	print("  -- accessibility gates --")
	var cam: Camera2D = get_viewport().get_camera_2d()

	AccessibilityManager.set_screen_shake_enabled(false)
	await _frames(2)
	_clear_sfx_pool()
	game._fx_camera_home_set = false
	cam.offset = Vector2.ZERO
	game._juice_miss(null)
	var moved: float = 0.0
	for _i in range(30):
		await get_tree().process_frame
		moved = maxf(moved, cam.offset.length())
	var flash: ColorRect = game._fx_flash
	_check("with the shake off the camera does not move at all",
		moved < 0.01, "peak camera displacement %.4f units" % moved)
	_check("with the shake off the sting still lands - it is not motion",
		_pool_holds(_sting_stream(AudioManager.SFXType.DAMAGE)) == 1,
		"damage streams on the pool: %d"
			% _pool_holds(_sting_stream(AudioManager.SFXType.DAMAGE)))
	_check("with the shake off the tint still lands, so a hit is still legible",
		flash != null and flash.color.a > 0.0,
		"tint alpha %.3f" % (-1.0 if flash == null else flash.color.a))
	AccessibilityManager.set_screen_shake_enabled(true)
	await get_tree().create_timer(0.6).timeout

	# Reduced motion SHORTENS animations rather than removing them: get_animation_speed()
	# returns 3.0, so JuiceEffects.motion_time(0.3) - which is what _juice_miss() spends on
	# the tint - comes out at 0.1 s. Sampled at 0.15 s, that is a tint already gone under
	# reduced motion and one still visibly fading at normal speed. Measuring both sides is
	# what makes this a check on the setting rather than on the number 0.15.
	AccessibilityManager.set_reduced_motion(true)
	await _frames(2)
	game._juice_miss(null)
	await get_tree().create_timer(0.15).timeout
	var reduced_alpha: float = 0.0 if flash == null else flash.color.a
	AccessibilityManager.set_reduced_motion(false)
	await _frames(2)
	game._juice_miss(null)
	await get_tree().create_timer(0.15).timeout
	var normal_alpha: float = 0.0 if flash == null else flash.color.a
	_check("reduced motion shortens the tint instead of ignoring the setting",
		is_zero_approx(reduced_alpha) and normal_alpha > 0.0,
		"alpha at 0.15 s: %.3f reduced, %.3f normal (motion_time(0.3)=%.3f reduced)"
			% [reduced_alpha, normal_alpha, 0.3 / 3.0])
	await get_tree().create_timer(0.6).timeout


## ═══════════════════════════════════════════════════════════════════════════════
## 7. None of it is networked, and none of it can swallow the award
## ═══════════════════════════════════════════════════════════════════════════════
## The cue is deliberately LOCAL: a life lost by the partner does not sting on this screen,
## only on theirs. That is a decision (see _juice_miss()'s docstring) and it is only safe if
## the cue itself sends nothing - a sting that touched the G-Counter or the shared lives would
## be a scoring bug wearing a feedback costume. And because the cue is fired FIRST inside both
## funnels, the last thing checked is that firing it cannot cost the round its points.
func _award_is_not_swallowed() -> void:
	print("")
	print("  -- the cue is local, and the award still lands --")
	var total_before: int = NetworkManager.get_total_score()
	var lives_before: int = GameManager.team_lives
	game._juice_hit(null)
	game._juice_miss(null)
	await _frames(2)
	_check("a cue on its own does not touch the shared score",
		NetworkManager.get_total_score() == total_before,
		"team total %d -> %d" % [total_before, NetworkManager.get_total_score()])
	_check("a cue on its own does not touch the shared lives",
		GameManager.team_lives == lives_before,
		"team_lives %d -> %d" % [lives_before, GameManager.team_lives])

	# The funnel itself, once: the miss cue has to be on the path that actually charges the
	# team, not on a parallel one a game could forget to call.
	_clear_sfx_pool()
	game.report_miss_to_host()
	await _frames(2)
	_check("the real miss funnel both charges the team and stings",
		GameManager.team_lives == lives_before - 1
			and _pool_holds(_sting_stream(AudioManager.SFXType.DAMAGE)) == 1,
		"team_lives %d -> %d, damage streams %d"
			% [lives_before, GameManager.team_lives,
				_pool_holds(_sting_stream(AudioManager.SFXType.DAMAGE))])
	GameManager.team_lives = lives_before
	await get_tree().create_timer(0.6).timeout

	# The crossing point. add_score() can END THE ROUND on this very call, which is why the
	# cue is fired before the score is added rather than after: the last drop of a round the
	# players just won is the one that most needs to be heard, and a cue placed after the
	# quota check would be dead code on exactly that event.
	var bucket: Node2D = game.get("bucket")
	NetworkManager.clear_shared_target()
	game.win_quota = NetworkManager.get_round_score() + 5
	_clear_sfx_pool()
	game.add_score(5, true, bucket)
	var stung: int = _pool_holds(_sting_stream(AudioManager.SFXType.COLLECT))
	await _frames(4)
	_check("the quota-crossing hit still gets its sting",
		stung == 1, "collect streams on the pool for the winning point: %d" % stung)
	_check("and that hit really did end the round, so the check above was the crossing one",
		not bool(game.game_active),
		"game_active=%s at quota %d with a team total of %d"
			% [str(game.game_active), game.win_quota, NetworkManager.get_round_score()])


## ═══════════════════════════════════════════════════════════════════════════════
## Teardown
## ═══════════════════════════════════════════════════════════════════════════════
## AccessibilityManager.set_screen_shake_enabled() and set_reduced_motion() both PERSIST
## through SaveManager, so a run that flipped them and exited would leave the player's own
## settings changed on disk. sfx_volume and Engine.time_scale are restored for the same
## reason - process state that outlives this function if the round is reused.
func _teardown() -> void:
	Engine.time_scale = 1.0
	AccessibilityManager.set_screen_shake_enabled(_shake_was)
	AccessibilityManager.set_reduced_motion(_reduced_was)
	AudioManager.sfx_volume = _sfx_volume_was
	_clear_sfx_pool()
	if game != null and is_instance_valid(game):
		# current_scene back FIRST: freeing the node it points at leaves the tree holding a
		# freed pointer, and the next harness in the same process reads it.
		get_tree().current_scene = _scene_before
		get_tree().root.remove_child(game)
		game.free()
	NetworkManager.clear_shared_target()
	GameManager.disconnect_multiplayer()
	await _frames(2)
