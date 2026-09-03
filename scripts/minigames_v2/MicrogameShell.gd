class_name MicrogameShell
extends MiniGameBase

## DWTD-style shell for the v2 microgame rehaul. Extends MiniGameBase so the
## existing flow (instruction tap → game → tally → cartoon outro → next game),
## difficulty loading, pause and AutoPlay all keep working untouched.
##
## What this shell adds on top of the legacy base:
##   * DWTD HUD   — massive full-width timer bar (green→red, aggressive pulse),
##                  huge score counter with elastic punch, combo popper.
##   * Verb flash — after the player taps the instruction card, one giant
##                  single-verb word pops for exactly VERB_FLASH_SEC before the
##                  timer starts (thesis: "flashes for exactly one second").
##   * Input layer— one full-screen Control with fat hitboxes. Touch events are
##                  forwarded to _shell_tap/_shell_drag/_shell_release the frame
##                  they arrive; positions are set directly (no lerp smoothing),
##                  entirely decoupled from _process. No Area2D / physics.
##   * Feedback   — record_hit()/record_miss() give subclasses one-line juice:
##                  score punch + pop, or shake + red flash + combo reset.
##
## Memory contract for subclasses: build ALL nodes in _shell_setup() via
## _make_pool(); during the loop only acquire()/release() pooled nodes. Never
## .new() a Node, never queue_free(), never append() inside the hot path.

## How long the single-verb instruction stays on screen before the timer runs.
const VERB_FLASH_SEC: float = 1.0
## Pop-in overshoot and fade-out of the verb card. The pop-in runs CONCURRENTLY
## with the hold (it is never awaited), so only the fade has to be subtracted to
## make the card's total on-screen life come to VERB_FLASH_SEC.
const VERB_POP_SEC: float = 0.34
const VERB_FADE_SEC: float = 0.1

## DWTD HUD geometry.
const BAR_HEIGHT_FRAC: float = 0.045
const BAR_PULSE_RATE: float = 9.0    # Hz of the urgency pulse
const BAR_PULSE_DEPTH: float = 0.30  # brightness swing of the pulse

## Massive, forgiving input: taps within this extra radius still count.
const HIT_FUDGE_RADIUS: float = 26.0

## Failure feedback intensity (passed to Juice.shake).
const SHAKE_STRENGTH: float = 14.0

var shell_hud_layer: CanvasLayer
var shell_bar_fill: StyleBoxFlat
var shell_score_label: Label
var shell_combo_label: Label
var shell_verb_overlay: Control
var shell_verb_label: Label
var shell_flash_rect: ColorRect
var shell_input_layer: Control
var shell_pause_button: Button

var _bar_phase: float = 0.0

# ── Subclass hooks ─────────────────────────────────────────────────────────

## Return the single action verb shown for the 1 s flash ("TAP", "SWIPE", …).
## Defaults to the first word of game_instruction_text.
func _shell_verb() -> String:
	var t: String = game_instruction_text.strip_edges()
	var space := t.find(" ")
	return (t.substr(0, space) if space > 0 else t).to_upper()


## Called once during _setup_ui; build pools, entities, backdrops here.
func _shell_setup() -> void:
	pass


## Called the frame the timer actually starts (after the verb flash).
func _shell_start() -> void:
	pass


# ── Flow overrides ─────────────────────────────────────────────────────────

func _setup_ui() -> void:
	# Base builds the legacy HUD, pause menu and cutscene player. Keep them
	# (pause + tally screens depend on them), then bury the thin legacy bar
	# under the DWTD layer and repoint the base's HUD references at it so base
	# _process()/end_game() drive OUR nodes.
	super._setup_ui()
	_shell_build_hud()
	# Retire the legacy strip rather than only covering it. _shell_build_hud() has just
	# repointed score_label/combo_label at the shell nodes, so nothing on the row below
	# is read any more - and while it stayed visible its title kept rasterising behind
	# an opaque layer-20 bar, which is a draw nobody ever sees.
	if hud_top_row != null:
		hud_top_row.visible = false
	_shell_build_flash()
	_shell_build_verb_overlay()
	_shell_build_input_layer()
	_shell_setup()


func start_game() -> void:
	# Thesis pillar: instructions flash for exactly one second before the game
	# starts. super.start_game() arms the timer, so it must run only after the
	# flash completes. game_active is still false here — nothing is live yet.
	if not game_active:
		await _shell_play_verb_flash()
	super.start_game()
	_shell_start()


func _process(delta) -> void:
	super._process(delta)
	if not game_active:
		return
	_shell_process_bar(delta)

# ── HUD construction (once, in _setup_ui) ──────────────────────────────────

func _shell_content_scale() -> float:
	var vp := get_viewport_rect().size
	return clampf(minf(vp.x / 1152.0, vp.y / 648.0), 0.75, 3.0)


func _shell_build_hud() -> void:
	var cs := _shell_content_scale()
	var vp := get_viewport_rect().size
	shell_hud_layer = CanvasLayer.new()
	shell_hud_layer.name = "ShellHUD"
	shell_hud_layer.layer = 20
	add_child(shell_hud_layer)

	# ── Massive screen-spanning timer bar ──
	var bar_holder := Control.new()
	bar_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar_holder.offset_bottom = vp.y * BAR_HEIGHT_FRAC
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_hud_layer.add_child(bar_holder)

	var bar := ProgressBar.new()
	bar.name = "ShellTimerBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	bar.add_theme_stylebox_override("background", bg)
	shell_bar_fill = StyleBoxFlat.new()
	shell_bar_fill.bg_color = HUD_GREEN
	bar.add_theme_stylebox_override("fill", shell_bar_fill)
	bar_holder.add_child(bar)
	# Repoint the BASE class HUD references so base _process drives this bar
	# (it writes .value in tenths buckets) and end_game() reads it sanely.
	timer_bar = bar

	# ── Huge playful score counter, top-right ──
	shell_score_label = Label.new()
	shell_score_label.text = "0"
	shell_score_label.add_theme_font_size_override("font_size", int(64.0 * cs))
	shell_score_label.add_theme_color_override("font_color", Color.WHITE)
	shell_score_label.add_theme_color_override("font_outline_color", HUD_INK)
	shell_score_label.add_theme_constant_override("outline_size", int(10 * cs))
	shell_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# PRESET_TOP_RIGHT zeroes both offsets, so with the default grow direction
	# (END) the label's rect starts AT the right edge and expands off-screen —
	# only the left arc of the "0" was visible as a clipped "C" sliver. Grow
	# BEGIN keeps the right edge pinned at offset_right and expands leftward.
	shell_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	shell_score_label.offset_right = -24.0 * cs
	shell_score_label.offset_top = vp.y * BAR_HEIGHT_FRAC + 12.0 * cs
	shell_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Capture the legacy score label BEFORE repointing the var — it must be
	# hidden below (it ghosts through the shell bar's 0.92-alpha background).
	var legacy_score_label := score_label
	shell_hud_layer.add_child(shell_score_label)
	score_label = shell_score_label

	# ── Combo popper, centred under the bar ──
	shell_combo_label = Label.new()
	shell_combo_label.text = ""
	shell_combo_label.add_theme_font_size_override("font_size", int(44.0 * cs))
	shell_combo_label.add_theme_color_override("font_color", HUD_COMBO)
	shell_combo_label.add_theme_color_override("font_outline_color", HUD_INK)
	shell_combo_label.add_theme_constant_override("outline_size", int(8 * cs))
	shell_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell_combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shell_combo_label.offset_top = vp.y * BAR_HEIGHT_FRAC + 8.0 * cs
	shell_combo_label.offset_bottom = shell_combo_label.offset_top + 60.0 * cs
	shell_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_hud_layer.add_child(shell_combo_label)
	combo_label = shell_combo_label

	# The legacy HUD is superseded; hide its nodes but keep the objects alive
	# (pause menu, tally screens and AutoPlay still reference them).
	# The legacy score label sits on hud_layer (layer 1) UNDER the shell bar,
	# but the shell bar's background is only 0.92 alpha — the old "0" ghosted
	# through the dark drained region at the top-right corner.
	if legacy_score_label:
		legacy_score_label.visible = false
	if timer_label:
		timer_label.visible = false
	if mistakes_label:
		mistakes_label.visible = false

	# ── Pause: fat, always-on-top glyph in THIS layer (20) ──
	# The legacy "II" lives in the base info row (layer 1), where the massive
	# timer bar visually buried it (playtest bug #3). Hide it and rebuild a
	# big, high-contrast one up here so it is always visible and tappable.
	if pause_button:
		pause_button.visible = false
	shell_pause_button = Button.new()
	shell_pause_button.text = "II"
	shell_pause_button.flat = true
	shell_pause_button.add_theme_font_size_override("font_size", int(30.0 * cs))
	shell_pause_button.add_theme_color_override("font_color", Color.WHITE)
	shell_pause_button.add_theme_color_override("font_hover_color", HUD_COMBO)
	shell_pause_button.add_theme_color_override("font_pressed_color", HUD_COMBO)
	shell_pause_button.add_theme_color_override("font_outline_color", HUD_INK)
	shell_pause_button.add_theme_constant_override("outline_size", int(8 * cs))
	shell_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	shell_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	# A mouse click gives the button keyboard focus; the default focus stylebox
	# then paints a white rectangle around it (probe frame f0240). Clicks still
	# work with FOCUS_NONE.
	shell_pause_button.focus_mode = Control.FOCUS_NONE
	shell_pause_button.pressed.connect(_on_pause_pressed)
	shell_pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shell_pause_button.offset_left = -92.0 * cs
	shell_pause_button.offset_top = -2.0 * cs
	shell_pause_button.offset_right = -20.0 * cs
	shell_pause_button.offset_bottom = 66.0 * cs
	shell_hud_layer.add_child(shell_pause_button)


func _shell_build_flash() -> void:
	shell_flash_rect = ColorRect.new()
	shell_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell_flash_rect.color = Color(1, 1, 1, 0)
	shell_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_hud_layer.add_child(shell_flash_rect)


func _shell_build_verb_overlay() -> void:
	var cs := _shell_content_scale()
	shell_verb_overlay = Control.new()
	shell_verb_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell_verb_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_verb_overlay.visible = false
	shell_verb_overlay.modulate.a = 0.0
	shell_hud_layer.add_child(shell_verb_overlay)

	shell_verb_label = Label.new()
	shell_verb_label.text = _shell_verb()
	shell_verb_label.add_theme_font_size_override("font_size", int(150.0 * cs))
	shell_verb_label.add_theme_color_override("font_color", Color.WHITE)
	shell_verb_label.add_theme_color_override("font_outline_color", HUD_INK)
	shell_verb_label.add_theme_constant_override("outline_size", int(18 * cs))
	shell_verb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell_verb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shell_verb_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell_verb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_verb_overlay.add_child(shell_verb_label)


func _shell_build_input_layer() -> void:
	# One full-screen Control receives every touch. Sits at the BOTTOM of the
	# scene (below HUD CanvasLayer), so the pause button on hud_layer wins.
	# NOTE: deliberately NO anchors preset - this Control is a child of the
	# minigame's Node2D root, where anchors have no layout reference (parent
	# area size is 0) and full-rect anchors silently produced a 0x0 rect that
	# swallowed NO input at all (playtest: taps/swipes dead in every v2 game).
	# Pin the rect to the viewport explicitly instead.
	shell_input_layer = Control.new()
	shell_input_layer.name = "ShellInput"
	shell_input_layer.position = Vector2.ZERO
	shell_input_layer.size = get_viewport_rect().size
	shell_input_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	shell_input_layer.gui_input.connect(_on_shell_gui_input)
	add_child(shell_input_layer)
	move_child(shell_input_layer, 0)


# ── Verb flash (exactly VERB_FLASH_SEC) ────────────────────────────────────

func _shell_play_verb_flash() -> void:
	shell_verb_label.text = _shell_verb()
	shell_verb_overlay.visible = true
	# Pop in with overshoot…
	shell_verb_label.pivot_offset = shell_verb_label.size * 0.5
	shell_verb_label.scale = Vector2.ONE * 0.2
	var tw := shell_verb_overlay.create_tween()
	tw.tween_property(shell_verb_overlay, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(shell_verb_label, "scale", Vector2.ONE, VERB_POP_SEC) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if AudioManager:
		AudioManager.play_whoosh()
	# …hold for the remainder of exactly one second, then drop out.
	#
	# round_delay(), not a raw create_timer(): the positional default of
	# create_timer(sec, process_always = true) kept this counting while the tree was
	# paused, so backgrounding the app during the verb card (MobileUIManager sets
	# get_tree().paused on focus loss) let the flash finish and super.start_game()
	# arm the round behind the pause. This site sat in scripts/minigames_v2/, which
	# the FIX-42 sweep over scenes/minigames/ never looked at.
	#
	# VERB_FADE_SEC, not VERB_POP_SEC: `tw` above is never awaited, so the pop-in
	# overlaps this hold instead of preceding it. Subtracting the pop-in as well left
	# the card up for 0.34 + 0.66 - 0.34 = 0.76s, so the one game-design pillar with a
	# number attached to it — "the verb flashes for exactly one second" — was short by
	# a quarter of its span in all four v2 games. Only the fade-out is sequential.
	var hold: float = VERB_FLASH_SEC - VERB_FADE_SEC
	if hold > 0.0:
		await round_delay(hold)
	var out := shell_verb_overlay.create_tween()
	out.tween_property(shell_verb_overlay, "modulate:a", 0.0, VERB_FADE_SEC)
	await out.finished
	shell_verb_overlay.visible = false


# ── Timer bar hot path (arithmetic only — no allocation) ───────────────────

func _shell_process_bar(delta: float) -> void:
	if shell_bar_fill == null or timer_bar == null:
		return
	var ratio: float = clampf(timer_bar.value / maxf(timer_bar.max_value, 0.001), 0.0, 1.0)
	# Green → red continuously; Color is a stack struct, not a heap object.
	var c := HUD_GREEN.lerp(HUD_RED, 1.0 - ratio)
	# Aggressive pulse in the final 30 %: brightness oscillation only — no
	# tween, no layout change, three multiplies per frame.
	if ratio < 0.3:
		_bar_phase += delta * TAU * BAR_PULSE_RATE
		var pulse := 1.0 + sin(_bar_phase) * BAR_PULSE_DEPTH
		c = Color(minf(c.r * pulse, 1.0), minf(c.g * pulse, 1.0), minf(c.b * pulse, 1.0))
	shell_bar_fill.bg_color = c


## ── Contact ownership for the input layer ──────────────────────────────────
##
## One contact drives the microgame. Every contact used to be routed into the same
## _shell_tap/_shell_drag/_shell_release trio, which broke the one v2 game that
## carries something between tap and release: in GreywaterSorterV2 a second
## finger's release dropped the bucket held under the first, and mid-screen drops
## are scored as lost.
const NO_TOUCH_INDEX: int = -1
var _shell_touch_index: int = NO_TOUCH_INDEX

## emulate_mouse_from_touch defaults to true, so on Android every finger ALSO
## arrives as an InputEventMouseButton and both branches ran: one tap called
## _shell_tap twice and one lift called _shell_release twice. All four current v2
## _shell_tap bodies happen to be idempotent - FixLeakV2 checks the "fixed" meta,
## BucketBrigadeV2 finds bucket_at_person[i] already null, GreywaterSorterV2
## returns while holding, CatchTheRainV2 just re-sends the same paddle position -
## so this was latent rather than visible. It is still a trap for the next game
## whose tap is not idempotent. Once a real touch is seen the emulated pair is
## ignored for good; on desktop this stays false and the mouse drives everything.
var _shell_saw_touch: bool = false

# ── Input layer (event-driven — no _process polling) ───────────────────────

func _on_shell_gui_input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		_shell_saw_touch = true
		if t.pressed:
			if _shell_touch_index != NO_TOUCH_INDEX:
				return
			_shell_touch_index = t.index
			_shell_tap(t.position)
		elif t.index == _shell_touch_index:
			_shell_touch_index = NO_TOUCH_INDEX
			_shell_release(t.position)
	elif event is InputEventScreenDrag:
		var dg := event as InputEventScreenDrag
		_shell_saw_touch = true
		if _shell_touch_index == NO_TOUCH_INDEX:
			_shell_touch_index = dg.index
		if dg.index != _shell_touch_index:
			return
		_shell_drag(_shell_map_drag(dg.position))
	elif event is InputEventMouseButton:
		if _shell_saw_touch:
			return
		var m := event as InputEventMouseButton
		if m.pressed:
			_shell_tap(m.position)
		else:
			_shell_release(m.position)
	elif event is InputEventMouseMotion:
		if _shell_saw_touch:
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_shell_drag(_shell_map_drag((event as InputEventMouseMotion).position))


## Honour the algorithm's `control_reverse` chaos effect (Hard only) by mirroring
## drag input horizontally: the finger goes right, the thing being dragged goes
## left. MiniGameBase sets `controls_reversed` from that effect and its comment says
## "child classes should check controls_reversed to invert input" — before this,
## nothing in the project read the flag, so one of the five Hard chaos effects was
## inert.
##
## Drags only. A tap has no direction to reverse, so mirroring _shell_tap would
## just misplace the hit — that is broken aim, not a reversed control.
func _shell_map_drag(pos: Vector2) -> Vector2:
	if not controls_reversed:
		return pos
	return Vector2(get_viewport_rect().size.x - pos.x, pos.y)


## Overridable input hooks. Positions are viewport-local; subclasses move
## pooled entities DIRECTLY in these — never lerp toward them in _process.
func _shell_tap(_pos: Vector2) -> void:
	pass


func _shell_drag(_pos: Vector2) -> void:
	pass


func _shell_release(_pos: Vector2) -> void:
	pass


## Fat-hitbox test: |p - centre| <= radius + HIT_FUDGE_RADIUS. Deliberately a
## plain distance check — no physics server, no Area2D, no narrow phase.
static func hit_test(p: Vector2, centre: Vector2, radius: float) -> bool:
	var r := radius + HIT_FUDGE_RADIUS
	return p.distance_squared_to(centre) <= r * r


# ── One-line feedback API ──────────────────────────────────────────────────

## A correct action: hand it to the base, then add the juice. One call.
##
## record_action(true) already owns ALL the bookkeeping — total_actions,
## correct_actions, combo_streak, max_combo, the 10 + floor(streak/3)*5 award and
## both label texts (score_label/combo_label were repointed at the shell's own
## labels in _shell_build_hud, so the base writes THESE nodes). This function used
## to repeat three of those on top:
##   * current_score += points  → every hit scored 11 instead of 10, so the four
##     v2 games were the only ones in the collection scoring differently, and
##     CatchTheRainV2 had to keep a private quota counter to work around it.
##   * combo_streak += 1        → the streak advanced twice per hit: the popper
##     read "x2" after a single catch, and the combo bonus, max_combo and the
##     end-of-round tally all inflated with it.
##   * mistakes_made += 1 (below) → double-counted, which corrupts the thesis
##     score E = m/(m+5) and therefore the value fed to AdaptiveDifficulty.
## So: state belongs to record_action, presentation belongs here.
func record_hit(pop_node: Node2D = null) -> void:
	record_action(true)
	if shell_score_label:
		Juice.punch_label(shell_score_label)
	if shell_combo_label and combo_streak >= 2:
		Juice.punch_label(shell_combo_label, 1.25)
	if pop_node:
		Juice.pop(pop_node)


## A wrong action: mistake, combo reset, aggressive shake + red flash.
## record_action(false) owns mistakes_made, the combo reset, the difficulty-scaled
## time penalty and the mistake sound (play_damage) — a play_failure() here landed
## a second sting on the same frame. See record_hit() for the full split.
func record_miss(pop_node: Node2D = null) -> void:
	record_action(false)
	Juice.shake(self, SHAKE_STRENGTH, 0.3)
	if shell_flash_rect:
		Juice.flash(shell_flash_rect, Color(0.93, 0.29, 0.26, 0.35), 0.3)
	if pop_node:
		Juice.squash(pop_node)


## Pool factory helper. `factory(idx) -> Node` must return a BUILT node.
func _make_pool(factory: Callable, size: int) -> EntityPool:
	var pool := EntityPool.new()
	var fx := Node2D.new()
	fx.name = "Pool_%d" % get_child_count()
	add_child(fx)
	pool.setup(factory, size, fx)
	return pool
