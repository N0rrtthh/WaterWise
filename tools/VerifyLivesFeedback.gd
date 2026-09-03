extends Node

## FIX 29 + FIX 63 — the "you lost a life" feedback on LivesLabel, in BOTH multiplayer
## minigame families. Single process: the MP base's _ready() only requires
## NetworkManager.connection_active, which a lone host satisfies, and
## team_lives_updated is emitted locally, so no second peer is needed here.
##
## [1]-[5]  FIX 29 — MultiplayerMiniGameBase._on_team_lives_updated
##   The recoil used to be five `position:x` tweens. LivesLabel sits inside an
##   HBoxContainer inside another HBoxContainer, and a Control in a container does not
##   own its position — the container rewrites it on the next layout pass — and every
##   keyframe captured `position.x` at tween-BUILD time, so a re-layout part way through
##   left the tween driving toward a stale coordinate. Rather than assert that from the
##   documentation, [3] and [4] MEASURE it: with the tween killed so nothing else can
##   move anything, a hand displacement of `position` is erased by one forced layout
##   pass while `rotation_degrees`/`scale` — the channels the fix uses — survive it.
##
## [6]-[10]  FIX 63 — animate_life_lost in MiniGame_Rain and in the
##   MultiplayerMiniGameEffects base it overrides. Found this pass. `var original_scale
##   = lives_label.scale` was read at tween-BUILD time and used as the return target,
##   and the punch already running was never killed. Rain reports a miss for every drop
##   that reaches the floor and drops land in batches, so a second life lost inside the
##   0.6 s punch returned the label to a mid-punch ~1.2-1.4 instead of to rest; that
##   value became the next capture, so it ratcheted upward and stayed oversized for the
##   rest of the round. An HBoxContainer sizes its children but never scales them, so
##   nothing downstream corrected it — the glyphs overdrew the neighbouring ScoreLabel.

const MP_GAME: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const RAIN_GAME: String = "res://scripts/multiplayer/MiniGame_Rain.tscn"
const LEAF_GAME: String = "res://scripts/multiplayer/MiniGame_LeafSort.tscn"
const BASE_SCRIPT: String = "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Port chosen so this harness cannot collide with VerifyMultiplayer (7777) or
## VerifyMPScoring (7788) if they are ever run concurrently.
const PORT: int = 7799

## The clock is SLOWED, not sped up: the FIX 29 punch is built from 0.07-0.12 s steps,
## and once-per-frame polling at the ~70 fps a headless run reaches would sample a
## 0.08 s step barely five times. At 0.25x each step gets ~20 frames.
const TIME_SCALE: float = 0.25

## Rest values. Both labels are authored at scale 1 and modulate WHITE, and the fix
## rebases on these literals instead of reading the live property, so they are also
## the values the animation must return to.
const REST_SCALE: Vector2 = Vector2.ONE
const EPS: float = 0.01

## The FIX 29 recoil reaches -9 deg / +7 deg and squashes to (1.35, 0.75). A run that
## measures less than a third of that is not animating those channels at all.
const MIN_ROT_DEG: float = 3.0
const MIN_SCALE_DEV: float = 0.1

## Hand displacement used to prove who owns `position`. Larger than any sub-pixel
## layout rounding, small enough to stay inside the bar.
const NUDGE_PX: float = 40.0

## When the second punch starts: 0.15 s into the first, which is inside the 0.1-0.2 s
## window where `scale` is ramping 1.0 -> 1.4, so the pre-fix capture is a mid-punch
## value rather than rest. The whole punch is 0.1 + 0.3 + 0.2 = 0.6 s.
const OVERLAP_AT: float = 0.15
const PUNCH_TOTAL: float = 0.6

var _pass: int = 0
var _fail: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


## Wall-clock wait, so TIME_SCALE does not stretch the settle pauses.
func _secs(s: float) -> void:
	await _tree().create_timer(s, true, false, true).timeout


## Waits `s` seconds of ANIMATION time, which is the unit the tween durations are in.
func _anim_secs(s: float) -> void:
	await _tree().create_timer(s / TIME_SCALE, true, false, true).timeout


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("    PASS  %s" % label)
	else:
		_fail += 1
		print("    FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


## The text of one function's body, for the regression guards. A grep would answer
## "does the word appear in the file", which is not the claim: `position` is legitimately
## tweened elsewhere in these files (the root-level screen shake), so the sweep has to be
## scoped to the one function.
func _fn_body(path: String, fname: String) -> String:
	var txt: String = FileAccess.get_file_as_string(path)
	if txt == "":
		return ""
	var out: String = ""
	var inside: bool = false
	for line in txt.split("\n"):
		if line.begins_with("func "):
			if inside:
				break
			inside = line.begins_with("func " + fname + "(")
			continue
		if inside:
			out += line + "\n"
	return out


## Instantiate a real game scene as a CHILD of this node rather than as the scene root,
## so this harness survives to report even if the game changes scenes.
func _spawn(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var game: Node = packed.instantiate()
	add_child(game)
	return game


func _find_lives(game: Node) -> Label:
	var direct: Node = game.get_node_or_null("UI/TopBar/LivesLabel")
	if direct is Label:
		return direct as Label
	var hud: Node = game.get("hud_layer")
	if hud != null:
		var found: Node = (hud as Node).find_child("LivesLabel", true, false)
		if found is Label:
			return found as Label
	return null


func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) < EPS and absf(a.y - b.y) < EPS


func _case_fix29() -> void:
	print("  [FIX 29 + FIX 64] MultiplayerMiniGameBase HUD feedback")
	var game: Node = _spawn(MP_GAME)
	if game == null:
		_check("[1] the MP game scene loaded", false, MP_GAME)
		return
	# The base _ready() awaits a frame, checks the connection, then builds the HUD.
	await _secs(1.5)
	var lbl: Label = _find_lives(game)
	if lbl == null:
		_check("[1] LivesLabel exists in the HUD the base built", false, "not found under hud_layer")
		game.queue_free()
		return
	_check("[1] LivesLabel exists in the HUD the base built", true, str(lbl.get_path()))
	var parent: Container = lbl.get_parent() as Container
	_check("[2] LivesLabel is inside a Container, so it does not own its own transform",
		parent != null, "parent=%s (%s)" % [str(lbl.get_parent().name), lbl.get_parent().get_class()])
	if parent == null:
		game.queue_free()
		return
	
	# Drive the real signal handler and sample every frame of the recoil.
	lbl.rotation_degrees = 0.0
	lbl.scale = REST_SCALE
	var recoil_rest_x: float = lbl.position.x
	game._on_team_lives_updated(2)
	var max_rot: float = 0.0
	var max_dev: float = 0.0
	var max_pos: float = 0.0
	var deadline: int = Time.get_ticks_msec() + int(1000.0 * PUNCH_TOTAL / TIME_SCALE)
	while Time.get_ticks_msec() < deadline:
		await _tree().process_frame
		max_rot = maxf(max_rot, absf(lbl.rotation_degrees))
		max_dev = maxf(max_dev, maxf(absf(lbl.scale.x - 1.0), absf(lbl.scale.y - 1.0)))
		max_pos = maxf(max_pos, absf(lbl.position.x - recoil_rest_x))
	_check("[3] the recoil really rotates the label", max_rot >= MIN_ROT_DEG,
		"peak |rotation| = %.3f deg, floor %.1f" % [max_rot, MIN_ROT_DEG])
	_check("[4] the recoil really squashes the label", max_dev >= MIN_SCALE_DEV,
		"peak |scale - 1| = %.3f, floor %.2f" % [max_dev, MIN_SCALE_DEV])
	# The discriminating claim for FIX 29: the recoil must not write the one channel the
	# container rewrites underneath it. [6] proves the container wins that fight.
	_check("[4] the recoil never writes the container-owned position channel",
		max_pos < 0.5, "peak |position.x - rest| = %.3f px" % max_pos)
	
	# Who owns the label's transform? The recoil is over, so nothing is animating.
	# Displace all three channels by hand; the control condition first, with no layout
	# pass, so that whatever the forced pass changes cannot be blamed on some other
	# writer in the scene.
	await _secs(0.5)
	var rest_pos: Vector2 = lbl.position
	var rest_rot: float = lbl.rotation_degrees
	var rest_scale: Vector2 = lbl.scale
	lbl.position.x = rest_pos.x + NUDGE_PX
	lbl.rotation_degrees = rest_rot + 12.0
	lbl.scale = rest_scale * 1.25
	await _frames(3)
	_check("[5] control: with no layout pass all three hand-written channels persist",
		absf(lbl.position.x - (rest_pos.x + NUDGE_PX)) < 0.5
			and absf(lbl.rotation_degrees - (rest_rot + 12.0)) < EPS
			and _near(lbl.scale, rest_scale * 1.25),
		"pos.x=%.2f rot=%.3f scale=%s" % [lbl.position.x, lbl.rotation_degrees, str(lbl.scale)])
	
	# One forced pass. This is the measurement FIX 29 rests on — and it also shows the
	# fix's own channels are container-owned: Container.fit_child_in_rect writes the
	# child's rect and then resets rotation to 0 and scale to (1,1). FIX 29 is still
	# right, because the recoil ENDS at exactly those values (checked at [7]) whereas the
	# old position:x shake ended at a coordinate captured before the pass; but it means a
	# sort landing mid-recoil costs a frame, which is what FIX 64 removes.
	parent.queue_sort()
	await _frames(3)
	_check("[6] one layout pass erases position, rotation AND scale — the container owns all three",
		absf(lbl.position.x - rest_pos.x) < 0.5
			and absf(lbl.rotation_degrees) < EPS
			and _near(lbl.scale, REST_SCALE),
		"after sort: pos.x=%.2f (nudged %.2f, rest %.2f) rot=%.3f (set %.3f) scale=%s (set %s)" % [
			lbl.position.x, rest_pos.x + NUDGE_PX, rest_pos.x, lbl.rotation_degrees,
			rest_rot + 12.0, str(lbl.scale), str(rest_scale * 1.25)])
	
	# A sort mid-recoil must leave NO residue once the recoil ends. This is the check the
	# pre-FIX-29 position:x shake fails: its keyframes hold a coordinate captured at
	# build time, so the pass moves the label and the tween then drives it back to the
	# stale x and leaves it there.
	game._on_team_lives_updated(1)
	await _anim_secs(0.10)
	parent.queue_sort()
	await _anim_secs(PUNCH_TOTAL)
	await _secs(0.5)
	_check("[7] a layout pass mid-recoil leaves no residue once it settles",
		absf(lbl.position.x - rest_pos.x) < 0.5
			and absf(lbl.rotation_degrees) < 0.05
			and _near(lbl.scale, REST_SCALE),
		"settled: pos.x=%.2f (rest %.2f) rot=%.3f scale=%s" % [
			lbl.position.x, rest_pos.x, lbl.rotation_degrees, str(lbl.scale)])
	
	# Regression guard, not a measurement: keep the handler off the container-owned
	# position channel. Scoped to the one function because `position` is legitimately
	# tweened elsewhere in this file.
	var body: String = _fn_body(BASE_SCRIPT, "_on_team_lives_updated")
	_check("[8] the handler body was read and tweens no quoted position property",
		body.length() > 0 and not body.contains('"position'), "%d chars scanned" % body.length())
	
	# ── FIX 64: does writing a new score still re-sort the bar? ────────────────────
	var score_lbl: Label = (game.get("hud_layer") as Node).find_child("ScoreLabel", true, false) as Label
	if score_lbl == null:
		_check("[9] ScoreLabel exists in the HUD", false, "not found")
		game.queue_free()
		return
	var score_parent: Container = score_lbl.get_parent() as Container
	var sorts: Array[int] = [0]
	score_parent.sort_children.connect(func() -> void: sorts[0] += 1)
	var lives_sorts: Array[int] = [0]
	parent.sort_children.connect(func() -> void: lives_sorts[0] += 1)
	await _frames(3)
	sorts[0] = 0
	lives_sorts[0] = 0
	var text_before: String = score_lbl.text
	var minw_before: float = score_lbl.get_combined_minimum_size().x
	game._on_team_score_updated(12345)
	await _frames(4)
	var minw_after: float = score_lbl.get_combined_minimum_size().x
	_check("[9] the score text really grew, so the reserve is under load",
		score_lbl.text != text_before and score_lbl.text.contains("12345"),
		"'%s' -> '%s'" % [text_before, score_lbl.text])
	_check("[9] a five-digit score does not change ScoreLabel's minimum width",
		absf(minw_after - minw_before) < 0.5,
		"min width %.1f -> %.1f px" % [minw_before, minw_after])
	_check("[10] writing the score re-sorts nothing, so the pop it starts is not clipped",
		sorts[0] == 0, "sort_children fired %d time(s) on ScoreLabel's container, %d on LivesLabel's" % [
			sorts[0], lives_sorts[0]])
	game.queue_free()
	await _frames(2)
## a live-path reproduction and the report has to say which.
func _case_fix63(path: String, who: String, note: String) -> void:
	print("  [FIX 63] animate_life_lost — %s" % who)
	print("           %s" % note)
	var game: Node = _spawn(path)
	if game == null:
		_check("[11] the scene loaded", false, path)
		return
	await _secs(1.5)
	var lbl: Label = _find_lives(game)
	if lbl == null:
		_check("[11] LivesLabel found at UI/TopBar/LivesLabel", false, path)
		game.queue_free()
		return
	if not game.has_method("animate_life_lost"):
		_check("[11] the scene exposes animate_life_lost()", false, path)
		game.queue_free()
		return
	_check("[11] LivesLabel found and animate_life_lost() is reachable", true, str(lbl.get_path()))
	_check("[11] it is inside a Container, which sizes but never scales its children",
		lbl.get_parent() is Container,
		"parent=%s (%s)" % [str(lbl.get_parent().name), lbl.get_parent().get_class()])
	
	# One punch on its own. This passed before the fix too — the defect needs an overlap.
	lbl.scale = REST_SCALE
	lbl.modulate = Color.WHITE
	game.animate_life_lost()
	await _anim_secs(PUNCH_TOTAL + 0.2)
	await _secs(0.4)
	_check("[12] one punch returns the label to rest scale",
		_near(lbl.scale, REST_SCALE), "settled at %s" % str(lbl.scale))
	
	# THE reproduction: a second life lost while the first punch is still running.
	game.animate_life_lost()
	await _anim_secs(OVERLAP_AT)
	var mid: Vector2 = lbl.scale
	game.animate_life_lost()
	await _anim_secs(PUNCH_TOTAL + 0.2)
	await _secs(0.4)
	_check("[13] a second life lost mid-punch still returns to rest",
		_near(lbl.scale, REST_SCALE),
		"scale was %.4f when the second punch started, settled at %.4f (rest 1.0000)" % [
			mid.x, lbl.scale.x])
	
	# Three in 0.45 s, which is what a batch of drops landing together produces.
	for _i in range(3):
		game.animate_life_lost()
		await _anim_secs(OVERLAP_AT)
	await _anim_secs(PUNCH_TOTAL + 0.2)
	await _secs(0.4)
	_check("[14] three punches inside 0.45 s do not ratchet the scale up",
		_near(lbl.scale, REST_SCALE), "settled at %.4f (rest 1.0000)" % lbl.scale.x)
	_check("[14] and the tint returned to white",
		absf(lbl.modulate.r - 1.0) < EPS and absf(lbl.modulate.g - 1.0) < EPS,
		"modulate=%s" % str(lbl.modulate))
	game.queue_free()
	await _frames(2)


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	print("=== VerifyLivesFeedback (time_scale %.2f) ===" % TIME_SCALE)
	await _frames(2)
	var served: bool = NetworkManager.create_server(PORT)
	print("  lone host on port %d -> %s (the MP base refuses to build a HUD without one)" % [
		PORT, str(served)])
	await _secs(0.6)
	await _case_fix29()
	await _case_fix63(RAIN_GAME, "MiniGame_Rain override",
		"live path: Rain calls this from _on_life_lost on every life lost")
	await _case_fix63(LEAF_GAME, "MultiplayerMiniGameEffects base",
		"base-class guard: no game calls the inherited version today")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	Engine.time_scale = 1.0
	await _frames(2)
	_tree().quit(1 if _fail > 0 else 0)
