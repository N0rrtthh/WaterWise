extends Control
## ═══════════════════════════════════════════════════════════════════
## CHARACTER OUTCOME NARRATIVE CUTSCENE  (DWTD-style)
## Animated water droplet character with particles, screen effects,
## and context-aware win/lose narrative sequences.
## ═══════════════════════════════════════════════════════════════════

signal cutscene_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var character_label: Label = $CharacterDisplay
@onready var context_label: Label = $ContextDisplay
@onready var bg_color: ColorRect = $BackgroundColor

var success: bool = false
var game_key: String = ""
var anim_options: Dictionary = {"speed": 1.0, "distance": 1.0}

# Procedural VFX nodes created at runtime
var _particles: Array[Node] = []
var _flash_rect: ColorRect = null
var _vignette: ColorRect = null
var _outcome_banner: Label = null

func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback

func _ready() -> void:
	_setup_animation_player()

func configure(is_success: bool, key: String, options: Dictionary = {}) -> void:
	success = is_success
	game_key = key
	anim_options = options
	_setup_animation_player()
	_populate_narrative()

func _populate_narrative() -> void:
	var narrative_data = _get_narrative_for_key(game_key, success)

	if success:
		bg_color.color = Color(0.03, 0.18, 0.08, 0.88)
	else:
		bg_color.color = Color(0.20, 0.04, 0.04, 0.90)

	character_label.text = narrative_data["character"]
	character_label.add_theme_font_size_override("font_size", 120)
	# Center pivot so scaling animates from center, not top-left
	character_label.pivot_offset = character_label.size / 2.0

	context_label.text = narrative_data["context"]
	context_label.add_theme_font_size_override("font_size", 34)
	context_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	context_label.add_theme_constant_override("outline_size", 6)
	context_label.add_theme_color_override(
		"font_color",
		Color(0.85, 1.0, 0.9) if success else Color(1.0, 0.6, 0.5)
	)
	context_label.pivot_offset = context_label.size / 2.0

func play_cutscene() -> void:
	if AudioManager:
		if success:
			AudioManager.play_success()
			AudioManager.play_music("outcome_win", 0.2)
		else:
			AudioManager.play_failure()
			AudioManager.play_music("outcome_fail", 0.2)

	# Build cinematic layers BEFORE starting the animation
	_build_cinematic_layers()

	if not animation_player.has_animation("narrative"):
		_build_animation()

	if animation_player.has_animation("narrative"):
		animation_player.play("narrative")
		# Fire tween-based VFX in parallel
		_run_parallel_vfx()
		await animation_player.animation_finished
	else:
		_run_parallel_vfx()
		await get_tree().create_timer(3.5).timeout

	_cleanup_vfx()
	cutscene_finished.emit()

# ── Cinematic VFX Layer Setup ──────────────────────────────────────

func _build_cinematic_layers() -> void:
	var vp_size = get_viewport_rect().size

	# Full-screen white flash on impact
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	# Vignette overlay for dramatic framing
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0, 0, 0, 0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# Outcome banner (big text behind character)
	_outcome_banner = Label.new()
	_outcome_banner.text = (
		_loc("outcome_nice", "NICE!")
		if success
		else _loc("outcome_oops", "OOPS!")
	)
	_outcome_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outcome_banner.set_anchors_preset(Control.PRESET_CENTER)
	_outcome_banner.add_theme_font_size_override("font_size", 160)
	_outcome_banner.add_theme_color_override(
		"font_color",
		Color(1, 1, 0.3, 0) if success else Color(1, 0.3, 0.2, 0)
	)
	_outcome_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_outcome_banner.add_theme_constant_override("outline_size", 14)
	_outcome_banner.pivot_offset = Vector2(200, 80)
	_outcome_banner.position = Vector2(vp_size.x / 2 - 200, vp_size.y * 0.15)
	_outcome_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_outcome_banner)
	move_child(_outcome_banner, bg_color.get_index() + 1)

	# Procedural floating particles (bubbles for win, drips for lose)
	_spawn_ambient_particles(vp_size)

func _spawn_ambient_particles(vp_size: Vector2) -> void:
	var count = 18 if success else 12
	for i in count:
		var p = ColorRect.new()
		var sz = randf_range(4, 14) if success else randf_range(3, 8)
		p.size = Vector2(sz, sz)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.0

		if success:
			p.color = Color(
				randf_range(0.4, 0.7),
				randf_range(0.85, 1.0),
				randf_range(0.5, 1.0),
				0.7
			)
		else:
			p.color = Color(
				randf_range(0.3, 0.6),
				randf_range(0.3, 0.5),
				randf_range(0.6, 0.9),
				0.5
			)

		p.position = Vector2(
			randf_range(40, vp_size.x - 40),
			randf_range(vp_size.y * 0.3, vp_size.y * 0.9)
		)
		p.rotation = randf_range(0, TAU)
		add_child(p)
		_particles.append(p)

func _run_parallel_vfx() -> void:
	var speed = max(0.5, float(anim_options.get("speed", 1.0)))
	var length = 3.5 / speed

	# ── SCREEN SHAKE on entry (impact feel) ──
	# Use character_label offset instead of moving self (which breaks full-rect layout)
	var shake_target = character_label if character_label else self
	var shake_base = shake_target.position
	if success:
		var jolt = create_tween()
		jolt.tween_property(shake_target, "position", shake_base + Vector2(6, -4), 0.03)
		jolt.tween_property(shake_target, "position", shake_base + Vector2(-4, 6), 0.03)
		jolt.tween_property(shake_target, "position", shake_base + Vector2(3, -2), 0.02)
		jolt.tween_property(shake_target, "position", shake_base, 0.02)
	else:
		var shake = create_tween()
		shake.tween_property(shake_target, "position", shake_base + Vector2(10, 8), 0.03)
		shake.tween_property(shake_target, "position", shake_base + Vector2(-12, -6), 0.03)
		shake.tween_property(shake_target, "position", shake_base + Vector2(8, -10), 0.03)
		shake.tween_property(shake_target, "position", shake_base + Vector2(-6, 8), 0.03)
		shake.tween_property(shake_target, "position", shake_base + Vector2(4, -3), 0.02)
		shake.tween_property(shake_target, "position", shake_base + Vector2(-2, 2), 0.02)
		shake.tween_property(shake_target, "position", shake_base, 0.02)

	# ── Flash on entry (brighter, punchier) ──
	if _flash_rect:
		var ft = create_tween()
		ft.tween_property(_flash_rect, "color:a", 0.6 if success else 0.5, 0.05)
		ft.tween_property(_flash_rect, "color:a", 0.0, 0.2)
		# Second flash for dramatic emphasis
		ft.tween_interval(0.3)
		ft.tween_property(_flash_rect, "color:a", 0.2, 0.04)
		ft.tween_property(_flash_rect, "color:a", 0.0, 0.15)

	# ── Vignette pulse (more dramatic) ──
	if _vignette:
		var vt = create_tween()
		vt.tween_property(_vignette, "color:a", 0.35, length * 0.1)
		vt.tween_property(_vignette, "color:a", 0.15, length * 0.4)
		vt.tween_property(_vignette, "color:a", 0.25, length * 0.1)
		vt.tween_property(_vignette, "color:a", 0.0, length * 0.25)

	# ── Banner pop-in (bigger, bouncier) ──
	if _outcome_banner:
		_outcome_banner.scale = Vector2(0.1, 0.1)
		_outcome_banner.rotation = -0.3 if success else 0.15
		var bt = create_tween()
		# Overshoot pop
		bt.tween_property(
			_outcome_banner, "scale", Vector2(1.3, 1.3), 0.2
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		bt.tween_property(
			_outcome_banner, "rotation", 0.08 if success else -0.05, 0.15
		)
		bt.tween_property(
			_outcome_banner, "scale", Vector2(0.9, 0.9), 0.08
		)
		bt.tween_property(
			_outcome_banner, "scale", Vector2(1.0, 1.0), 0.06
		)
		bt.tween_property(_outcome_banner, "rotation", 0.0, 0.08)

		# Wobble the banner during hold
		var wobble = create_tween()
		wobble.tween_interval(0.5)
		var wobble_loop = wobble.set_loops(3)
		wobble_loop.tween_property(_outcome_banner, "rotation", 0.04, 0.12)
		wobble_loop.tween_property(_outcome_banner, "rotation", -0.04, 0.12)
		wobble_loop.tween_property(_outcome_banner, "rotation", 0.0, 0.08)

		# Alpha
		var ba = create_tween()
		ba.tween_property(_outcome_banner, "modulate:a", 0.85, 0.15)
		var ba2 = create_tween()
		ba2.tween_interval(length * 0.6)
		ba2.tween_property(_outcome_banner, "modulate:a", 0.0, length * 0.2)

	# ── Ambient particles (more energetic) ──
	for p in _particles:
		var delay = randf_range(0.05, 0.4)
		var dur = randf_range(1.5, 2.8)
		var drift = randf_range(-80, 80)
		var rise = randf_range(100, 260)

		var pt = create_tween()
		pt.tween_interval(delay)
		pt.set_parallel(true)
		pt.tween_property(p, "modulate:a", randf_range(0.5, 0.9), 0.2)
		pt.tween_property(p, "position:y", p.position.y - rise, dur).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "position:x", p.position.x + drift, dur)
		pt.tween_property(p, "rotation", p.rotation + randf_range(-2, 2), dur)
		# Scale pulse for sparkle effect
		pt.tween_property(p, "scale", Vector2(1.5, 1.5), dur * 0.3).set_ease(Tween.EASE_OUT)

		var pf = create_tween()
		pf.tween_interval(delay + dur * 0.5)
		pf.tween_property(p, "modulate:a", 0.0, dur * 0.4)
		pf.tween_property(p, "scale", Vector2(0.3, 0.3), dur * 0.4)

func _cleanup_vfx() -> void:
	for p in _particles:
		if is_instance_valid(p):
			p.queue_free()
	_particles.clear()
	if is_instance_valid(_flash_rect):
		_flash_rect.queue_free()
	if is_instance_valid(_vignette):
		_vignette.queue_free()
	if is_instance_valid(_outcome_banner):
		_outcome_banner.queue_free()

# ── Animation Builder ──────────────────────────────────────────────

func _setup_animation_player() -> void:
	if not animation_player:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)

func _build_animation() -> void:
	var speed = max(0.5, float(anim_options.get("speed", 1.0)))
	var length = 3.5 / speed
	var in_t = length * 0.12
	var hold_t = length * 0.70
	var out_t = length * 0.90

	var anim := Animation.new()
	anim.length = length

	# Background fade in/out
	var bg_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(bg_track, NodePath("BackgroundColor:modulate:a"))
	anim.track_insert_key(bg_track, 0.0, 0.0)
	anim.track_insert_key(bg_track, in_t, 1.0)
	anim.track_insert_key(bg_track, out_t, 1.0)
	anim.track_insert_key(bg_track, length, 0.0)

	# Character entrance based on outcome
	if success:
		_add_success_character_animation(anim, in_t, hold_t, out_t, length)
	else:
		_add_failure_character_animation(anim, in_t, hold_t, out_t, length)

	# Context text fade with stagger
	var ctx_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ctx_track, NodePath("ContextDisplay:modulate:a"))
	anim.track_insert_key(ctx_track, 0.0, 0.0)
	anim.track_insert_key(ctx_track, in_t * 1.8, 0.0)
	anim.track_insert_key(ctx_track, in_t * 2.8, 1.0)
	anim.track_insert_key(ctx_track, out_t, 1.0)
	anim.track_insert_key(ctx_track, length, 0.0)

	# Context slide-up entrance
	var ctx_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ctx_pos, NodePath("ContextDisplay:position:y"))
	var ctx_base_y = context_label.position.y if context_label else 60.0
	anim.track_insert_key(ctx_pos, 0.0, ctx_base_y + 30)
	anim.track_insert_key(ctx_pos, in_t * 2.8, ctx_base_y)

	if not animation_player or not is_instance_valid(animation_player):
		push_error("AnimationPlayer not found in CharacterOutcomeNarrative")
		return

	var library: AnimationLibrary = null
	if animation_player.has_animation_library(""):
		library = animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	if library.has_animation("narrative"):
		library.remove_animation("narrative")
	library.add_animation("narrative", anim)

func _add_success_character_animation(
	anim: Animation, in_t: float, hold_t: float, out_t: float, length: float
) -> void:
	# Pop in from below with EXTREME elastic overshoot
	var char_scale := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(char_scale, NodePath("CharacterDisplay:scale"))
	anim.track_insert_key(char_scale, 0.0, Vector2(0.05, 0.05))
	# Rocket stretch upward
	anim.track_insert_key(char_scale, in_t * 0.3, Vector2(0.6, 1.8))
	# Overshoot pop (way bigger than before)
	anim.track_insert_key(char_scale, in_t * 0.6, Vector2(1.5, 1.5))
	# Squash back hard
	anim.track_insert_key(char_scale, in_t * 0.8, Vector2(1.6, 0.5))
	# Spring up
	anim.track_insert_key(char_scale, in_t * 1.0, Vector2(0.7, 1.4))
	# Settle wiggle
	anim.track_insert_key(char_scale, in_t * 1.3, Vector2(1.15, 0.85))
	anim.track_insert_key(char_scale, in_t * 1.6, Vector2(0.92, 1.08))
	anim.track_insert_key(char_scale, in_t * 1.9, Vector2(1.0, 1.0))
	# Happy dance squash-stretch loop (exaggerated)
	anim.track_insert_key(char_scale, hold_t * 0.2, Vector2(1.2, 0.7))
	anim.track_insert_key(char_scale, hold_t * 0.28, Vector2(0.7, 1.3))
	anim.track_insert_key(char_scale, hold_t * 0.36, Vector2(1.15, 0.8))
	anim.track_insert_key(char_scale, hold_t * 0.44, Vector2(0.85, 1.15))
	anim.track_insert_key(char_scale, hold_t * 0.52, Vector2(1.0, 1.0))
	# Exit with dramatic horizontal stretch
	anim.track_insert_key(char_scale, out_t, Vector2(1.8, 0.2))
	anim.track_insert_key(char_scale, length, Vector2(0.0, 0.0))

	# Celebratory rotation — bigger swings + spin
	var char_rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(char_rot, NodePath("CharacterDisplay:rotation"))
	anim.track_insert_key(char_rot, 0.0, -0.6)
	anim.track_insert_key(char_rot, in_t * 0.3, 0.3)
	anim.track_insert_key(char_rot, in_t * 0.6, -0.15)
	anim.track_insert_key(char_rot, in_t * 1.0, 0.08)
	anim.track_insert_key(char_rot, in_t * 1.4, 0.0)
	# Wiggle dance
	anim.track_insert_key(char_rot, hold_t * 0.22, 0.15)
	anim.track_insert_key(char_rot, hold_t * 0.32, -0.15)
	anim.track_insert_key(char_rot, hold_t * 0.42, 0.1)
	anim.track_insert_key(char_rot, hold_t * 0.52, -0.08)
	anim.track_insert_key(char_rot, hold_t * 0.6, 0.0)

func _add_failure_character_animation(
	anim: Animation, in_t: float, hold_t: float, out_t: float, length: float
) -> void:
	# SPLAT from above — extreme cartoon impact
	var char_scale := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(char_scale, NodePath("CharacterDisplay:scale"))
	# Falling stretch
	anim.track_insert_key(char_scale, 0.0, Vector2(0.4, 2.0))
	# TOTAL PANCAKE on impact
	anim.track_insert_key(char_scale, in_t * 0.4, Vector2(2.0, 0.25))
	# Jelly rebound — tall and thin
	anim.track_insert_key(char_scale, in_t * 0.65, Vector2(0.5, 1.8))
	# Secondary squash
	anim.track_insert_key(char_scale, in_t * 0.85, Vector2(1.4, 0.6))
	# Wobble settle
	anim.track_insert_key(char_scale, in_t * 1.05, Vector2(0.8, 1.2))
	anim.track_insert_key(char_scale, in_t * 1.3, Vector2(1.1, 0.9))
	anim.track_insert_key(char_scale, in_t * 1.6, Vector2(1.0, 1.0))
	# Dizzy wobble during hold
	anim.track_insert_key(char_scale, hold_t * 0.25, Vector2(1.12, 0.88))
	anim.track_insert_key(char_scale, hold_t * 0.4, Vector2(0.88, 1.12))
	anim.track_insert_key(char_scale, hold_t * 0.55, Vector2(1.06, 0.94))
	anim.track_insert_key(char_scale, hold_t * 0.7, Vector2(1.0, 1.0))
	# Deflate exit — sad shrink
	anim.track_insert_key(char_scale, out_t * 0.8, Vector2(0.9, 0.9))
	anim.track_insert_key(char_scale, out_t, Vector2(0.2, 0.2))
	anim.track_insert_key(char_scale, length, Vector2(0.0, 0.0))

	# Violent shake → dizzy sway (bigger swings)
	var char_rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(char_rot, NodePath("CharacterDisplay:rotation"))
	anim.track_insert_key(char_rot, 0.0, 0.0)
	# Impact shake — rapid violent swings
	anim.track_insert_key(char_rot, in_t * 0.42, -0.35)
	anim.track_insert_key(char_rot, in_t * 0.52, 0.38)
	anim.track_insert_key(char_rot, in_t * 0.62, -0.28)
	anim.track_insert_key(char_rot, in_t * 0.72, 0.22)
	anim.track_insert_key(char_rot, in_t * 0.82, -0.12)
	anim.track_insert_key(char_rot, in_t * 0.92, 0.06)
	anim.track_insert_key(char_rot, in_t * 1.2, 0.0)
	# Slow dizzy rock
	anim.track_insert_key(char_rot, hold_t * 0.25, 0.1)
	anim.track_insert_key(char_rot, hold_t * 0.45, -0.1)
	anim.track_insert_key(char_rot, hold_t * 0.65, 0.05)
	anim.track_insert_key(char_rot, hold_t * 0.8, 0.0)

	# Vertical drop-bounce (more dramatic)
	var char_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(char_pos, NodePath("CharacterDisplay:position:y"))
	var base_y = character_label.position.y if character_label else 0.0
	anim.track_insert_key(char_pos, 0.0, base_y - 120)
	anim.track_insert_key(char_pos, in_t * 0.4, base_y + 20)
	anim.track_insert_key(char_pos, in_t * 0.65, base_y - 15)
	anim.track_insert_key(char_pos, in_t * 0.85, base_y + 8)
	anim.track_insert_key(char_pos, in_t * 1.1, base_y - 3)
	anim.track_insert_key(char_pos, in_t * 1.3, base_y)

func _get_narrative_for_key(key: String, is_success: bool) -> Dictionary:
	var narratives = {
		"FilterBuilder": {
			"win": {
				"character": "💧→🧪→😋",
				"context": "Built perfect filter stack\nClean water! Delicious! ✨"
			},
			"lose": {
				"character": "💧→❌→🤮",
				"context": "Wrong layer order\nMurky water! Blech! 💧"
			}
		},
		"FixLeak": {
			"win": {
				"character": "💦→🔧→✋",
				"context": "Sealed the leak instantly\nWater stops flowing! ✨"
			},
			"lose": {
				"character": "💦➡️💦➡️💦",
				"context": "Leak keeps spraying\nWater keeps wasting! 💧"
			}
		},
		"CatchTheRain": {
			"win": {
				"character": "🌧️→🪣→😊",
				"context": "Rain captured perfectly\nTank filling up! ✨"
			},
			"lose": {
				"character": "🌧️→💨→😞",
				"context": "Rain escaped everywhere\nTank stays empty! 💧"
			}
		},
		"RiceWashRescue": {
			"win": {
				"character": "🍚💧→♻️→😋",
				"context": "Rice water saved for reuse\nZero waste! ✨"
			},
			"lose": {
				"character": "🍚💧→🌊→😱",
				"context": "Rice water lost to drain\nWater wasted! 💧"
			}
		},
		"VegetableBath": {
			"win": {
				"character": "🥬💧→♻️→😊",
				"context": "Veggie rinse captured\nWater reused! ✨"
			},
			"lose": {
				"character": "🥬💧→🌊→😭",
				"context": "Too much rinse water used\nWasted away! 💧"
			}
		},
		"GreywaterSorter": {
			"win": {
				"character": "💧→✓→🏠",
				"context": "Greywater sorted correctly\nReady to reuse! ✨"
			},
			"lose": {
				"character": "💧→❌→🏠",
				"context": "Streams got contaminated\nCan't reuse it! 💧"
			}
		},
		"WringItOut": {
			"win": {
				"character": "🧽💧→👊→💧",
				"context": "Every drop saved from sponge\nNothing wasted! ✨"
			},
			"lose": {
				"character": "🧽💧→😅→💧💧",
				"context": "Sponge still dripping\nDrops lost! 💧"
			}
		},
		"ThirstyPlant": {
			"win": {
				"character": "🌱🍗→💧→🌿",
				"context": "Plant watered perfectly\nHappy and thriving! ✨"
			},
			"lose": {
				"character": "🌱🍗→❌→🥀",
				"context": "Over/under watered\nPlant unhappy! 💧"
			}
		},
		"MudPieMaker": {
			"win": {
				"character": "💧🌍→🥧→😋",
				"context": "Mud mix ratio perfect\nZero waste! ✨"
			},
			"lose": {
				"character": "💧🌍→❌→🤨",
				"context": "Wrong consistency\nMessed up! 💧"
			}
		},
		"CoverTheDrum": {
			"win": {
				"character": "🛢️🔓→🔒→✓",
				"context": "Drum covered in time\nWater protected! ✨"
			},
			"lose": {
				"character": "🛢️🔓→😱→❌",
				"context": "Drum got contaminated\nToo late! 💧"
			}
		},
		"SpotTheSpeck": {
			"win": {
				"character": "💧🔍→✓→😊",
				"context": "All specks spotted and removed\nCrystal clear! ✨"
			},
			"lose": {
				"character": "💧🔍→😔→❌",
				"context": "A speck got through\nImpure water! 💧"
			}
		},
		"RainwaterHarvesting": {
			"win": {
				"character": "☔→🪣→😊",
				"context": "Rainwater harvested perfectly\nTankfilled! ✨"
			},
			"lose": {
				"character": "☔→💨→😞",
				"context": "Harvest timing missed\nTank empty! 💧"
			}
		},
		"WaterPlant": {
			"win": {
				"character": "🚰🌱→💧💧→🌿",
				"context": "Watering rhythm locked in\nPlant thriving! ✨"
			},
			"lose": {
				"character": "🚰🌱→❌→🥀",
				"context": "Pattern timing off\nPlant wilting! 💧"
			}
		},
		"PlugTheLeak": {
			"win": {
				"character": "💦→🔧→✋",
				"context": "Pipe plugged under pressure\nFixed! ✨"
			},
			"lose": {
				"character": "💦→❌→💦",
				"context": "Plug didn't hold\nStill leaking! 💧"
			}
		},
		"SwipeTheSoap": {
			"win": {
				"character": "🧼💧→⏱️→✓",
				"context": "Soap swipe efficient and fast\nWater saved! ✨"
			},
			"lose": {
				"character": "🧼💧→⏱️❌→💧",
				"context": "Swipe took too long\nWater wasted! 💧"
			}
		},
		"QuickShower": {
			"win": {
				"character": "🚿⏱️→✓→😊",
				"context": "Shower sprint complete\nSuper quick! ✨"
			},
			"lose": {
				"character": "🚿⏱️→❌→😴",
				"context": "Shower ran way too long\nToo slow! 💧"
			}
		},
		"ToiletTankFix": {
			"win": {
				"character": "🚽⚙️→💧→✓",
				"context": "Tank calibrated perfectly\nNo excess flush! ✨"
			},
			"lose": {
				"character": "🚽⚙️→❌→🌊",
				"context": "Tank still overflowing\nWater wasted! 💧"
			}
		},
		"TracePipePath": {
			"win": {
				"character": "🧭💧→✓→😊",
				"context": "Pipe path traced cleanly\nFlow optimized! ✨"
			},
			"lose": {
				"character": "🧭💧→❌→😕",
				"context": "Pipe route got lost\nFlow blocked! 💧"
			}
		},
		"ScrubToSave": {
			"win": {
				"character": "🧽💧→⏱️→😊",
				"context": "Scrub pattern water-wise\nSpotless and dry! ✨"
			},
			"lose": {
				"character": "🧽💧→❌→💧",
				"context": "Scrub wasted water\nStill soaking! 💧"
			}
		},
		"BucketBrigade": {
			"win": {
				"character": "🪣👥→✓→😊",
				"context": "Relay team nailed handoff\nWater delivered! ✨"
			},
			"lose": {
				"character": "🪣👥→💦→😞",
				"context": "Relay dropped the buckets\nWater spilled! 💧"
			}
		},
		"TimingTap": {
			"win": {
				"character": "🎯💧→⏱️→✓",
				"context": "Tap timing perfect\nZero extra drip! ✨"
			},
			"lose": {
				"character": "🎯💧→❌→💧",
				"context": "Timing missed the beat\nDripping away! 💧"
			}
		},
		"TurnOffTap": {
			"win": {
				"character": "🚰➡️✋→😊",
				"context": "Tap cut off right on cue\nOn the dot! ✨"
			},
			"lose": {
				"character": "🚰➡️➡️➡️",
				"context": "Tap stayed running\nWater wasted! 💧"
			}
		}
	}

	var key_narrative = narratives.get(key, {})
	var outcome_key = "win" if is_success else "lose"
	var key_slug = key.to_snake_case().to_lower()
	if key_narrative.has(outcome_key):
		var localized_narrative = key_narrative[outcome_key].duplicate(true)
		localized_narrative["character"] = _loc(
			"narrative_%s_%s_character" % [key_slug, outcome_key],
			str(localized_narrative.get("character", ""))
		)
		localized_narrative["context"] = _loc(
			"narrative_%s_%s_context" % [key_slug, outcome_key],
			str(localized_narrative.get("context", ""))
		)
		return localized_narrative

	# Fallback
	return {
		"character": _loc(
			"narrative_default_%s_character" % outcome_key,
			"😎" if is_success else "😵"
		),
		"context": _loc(
			"narrative_default_%s_context" % outcome_key,
			"Mission complete!\n✨ Water saved! ✨"
			if is_success
			else "Mission failed...\n💧 Retry! 💧"
		)
	}
