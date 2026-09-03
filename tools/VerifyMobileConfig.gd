extends Node

## ═══════════════════════════════════════════════════════════════════
## "ONE BAD KEY MUST NOT DROP THE REST OF THE CONFIG" HARNESS
## ═══════════════════════════════════════════════════════════════════
## MobileUIManager.load_config_file() reads 17 knobs out of a user-writable
## ConfigFile (user://mobile_ui_config.cfg, loaded on boot by
## _load_config_if_exists) straight into statically-typed @export members:
##
##     mobile_ui_scale = config.get_value("scaling", "ui_scale", mobile_ui_scale)
##
## get_value() returns whatever Variant is in the file. A wrong-typed value does
## not merely store the wrong number — assigning it to a typed member raises
## "Trying to assign value of type X to a variable of type Y", which ABORTS
## load_config_file(). Every knob below the offending line keeps its default, the
## trailing `return true` never runs, and the caller discards the result, so the
## whole thing is silent. This is the same defect class already fixed in
## SaveManager._merge_data(); this file is even more exposed, because a config of
## tuning knobs paired with a public save_config_file() is meant to be hand-edited.
##
## Measured here, in this order:
##   1. control — a well-formed config is fully adopted (so a fix that rejects
##      everything cannot pass).
##   2. a config whose FIRST key is wrong-typed and whose remaining keys are all
##      valid: the valid ones must still be adopted, and the bad one must fall
##      back to its default rather than take the file down with it.
##   3. the float-into-int case on its own (target_fps = 41.7), which is the one
##      a hand-edit produces most easily.
##
## Every knob is restored around each case, and the user's real config file is
## backed up and put back even if the run fails.
##
## Run:
##   godot --headless --path . res://tools/VerifyMobileConfig.tscn

const CFG_PATH: String = "user://mobile_ui_config.cfg"
const BAK_PATH: String = "user://mobile_ui_config.harness_bak"
const PROBE_PATH: String = "user://mobile_ui_config.harness_probe.cfg"

var results: Array = []
var had_real_cfg: bool = false
## Every knob load_config_file() touches, so a case can be run from a known state
## and the fallout of an abort is visible field by field.
var _knobs: PackedStringArray = [
	"mobile_ui_scale", "mobile_font_scale", "mobile_game_object_scale",
	"mobile_collectible_scale", "mobile_button_min_size",
	"mobile_touch_target_min_size", "mobile_button_spacing_vertical",
	"mobile_button_spacing_horizontal", "mobile_safe_area_margin",
	"mobile_edge_dead_zone", "mobile_particle_reduction", "mobile_max_tweens",
	"mobile_target_fps", "mobile_game_speed_reduction",
	"mobile_timing_window_increase", "mobile_spawn_rate_reduction",
	"mobile_drag_smoothing_increase",
]
var _defaults: Dictionary = {}


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MOBILE-CONFIG TRUST-BOUNDARY HARNESS")
	print("═══════════════════════════════════════════════════════════")
	for k in _knobs:
		_defaults[k] = MobileUIManager.get(k)
	_backup()
	_run_good_config()
	_run_one_bad_first_key()
	_run_float_into_int()
	_restore_knobs()
	_restore_backup()
	_finish()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _backup() -> void:
	had_real_cfg = FileAccess.file_exists(CFG_PATH)
	if had_real_cfg:
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(CFG_PATH),
			ProjectSettings.globalize_path(BAK_PATH))
	print("  real config present: %s" % str(had_real_cfg))


func _restore_backup() -> void:
	var probe := ProjectSettings.globalize_path(PROBE_PATH)
	if FileAccess.file_exists(PROBE_PATH):
		DirAccess.remove_absolute(probe)
	if had_real_cfg and FileAccess.file_exists(BAK_PATH):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(BAK_PATH),
			ProjectSettings.globalize_path(CFG_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK_PATH))


## Put every knob back to the value it had at boot, so each case starts from the
## same place and an adopted value is unambiguously from THIS case's file.
func _restore_knobs() -> void:
	for k in _knobs:
		MobileUIManager.set(k, _defaults[k])


func _write_cfg(values: Array) -> void:
	# values: [[section, key, value], ...] written in the order given.
	var cfg := ConfigFile.new()
	for v in values:
		cfg.set_value(v[0], v[1], v[2])
	var err := cfg.save(PROBE_PATH)
	if err != OK:
		_check("could write the probe config", false, error_string(err))


## Control. A file whose every value is the right type must be adopted whole,
## including the last key written — otherwise "the tail survived" below proves
## nothing and a fix that simply refuses bad files could pass by refusing all of them.
func _run_good_config() -> void:
	print("")
	print("[1] a well-formed config is adopted whole")
	_restore_knobs()
	_write_cfg([
		["scaling", "ui_scale", 2.25],
		["sizes", "button_min_size", Vector2(111, 66)],
		["performance", "target_fps", 24],
		["gameplay", "drag_smoothing_increase", 3.5],
	])
	var ok: bool = MobileUIManager.load_config_file(PROBE_PATH) == true
	_check("load_config_file() reported success", ok)
	_check("first key adopted (ui_scale = 2.25)",
		is_equal_approx(MobileUIManager.mobile_ui_scale, 2.25),
		"got %s" % str(MobileUIManager.mobile_ui_scale))
	_check("a Vector2 key adopted (button_min_size = 111x66)",
		MobileUIManager.mobile_button_min_size.is_equal_approx(Vector2(111, 66)),
		"got %s" % str(MobileUIManager.mobile_button_min_size))
	_check("an int key adopted (target_fps = 24)",
		MobileUIManager.mobile_target_fps == 24,
		"got %s" % str(MobileUIManager.mobile_target_fps))
	_check("the LAST key adopted (drag_smoothing_increase = 3.5)",
		is_equal_approx(MobileUIManager.mobile_drag_smoothing_increase, 3.5),
		"got %s" % str(MobileUIManager.mobile_drag_smoothing_increase))


## The defect. ui_scale is read first, so a String there is the earliest possible
## abort point; every other key in the file is well-formed and must survive it.
func _run_one_bad_first_key() -> void:
	print("")
	print("[2] one wrong-typed key must not drop the 16 valid keys after it")
	_restore_knobs()
	var default_scale: float = float(_defaults["mobile_ui_scale"])
	_write_cfg([
		["scaling", "ui_scale", "big"],                        # <- String, aborts here
		["scaling", "font_scale", 1.9],                        # valid, must survive
		["sizes", "touch_target_min_size", Vector2(96, 96)],   # valid, must survive
		["performance", "max_tweens", 4],                      # valid, must survive
		["gameplay", "drag_smoothing_increase", 2.5],          # valid, must survive
	])
	MobileUIManager.load_config_file(PROBE_PATH)
	_check("the bad key fell back to its default (ui_scale)",
		is_equal_approx(MobileUIManager.mobile_ui_scale, default_scale),
		"got %s, default is %s"
			% [str(MobileUIManager.mobile_ui_scale), str(default_scale)])
	_check("the key right after it still loaded (font_scale = 1.9)",
		is_equal_approx(MobileUIManager.mobile_font_scale, 1.9),
		"got %s" % str(MobileUIManager.mobile_font_scale))
	_check("a later Vector2 key still loaded (touch_target_min_size = 96x96)",
		MobileUIManager.mobile_touch_target_min_size.is_equal_approx(Vector2(96, 96)),
		"got %s" % str(MobileUIManager.mobile_touch_target_min_size))
	_check("a later int key still loaded (max_tweens = 4)",
		MobileUIManager.mobile_max_tweens == 4,
		"got %s" % str(MobileUIManager.mobile_max_tweens))
	_check("the last key still loaded (drag_smoothing_increase = 2.5)",
		is_equal_approx(MobileUIManager.mobile_drag_smoothing_increase, 2.5),
		"got %s" % str(MobileUIManager.mobile_drag_smoothing_increase))


## The hand-edit that is easiest to make by accident: a decimal in an int knob.
## Whatever GDScript does with float -> int here, the file must still load and the
## value must end up a usable int.
func _run_float_into_int() -> void:
	print("")
	print("[3] a decimal in an int knob (target_fps = 41.7)")
	_restore_knobs()
	_write_cfg([
		["performance", "target_fps", 41.7],
		["gameplay", "spawn_rate_reduction", 0.35],   # after it, must survive
	])
	MobileUIManager.load_config_file(PROBE_PATH)
	_check("target_fps is an int",
		typeof(MobileUIManager.mobile_target_fps) == TYPE_INT,
		"type = %s value = %s"
			% [type_string(typeof(MobileUIManager.mobile_target_fps)),
				str(MobileUIManager.mobile_target_fps)])
	_check("the key after it still loaded (spawn_rate_reduction = 0.35)",
		is_equal_approx(MobileUIManager.mobile_spawn_rate_reduction, 0.35),
		"got %s" % str(MobileUIManager.mobile_spawn_rate_reduction))


func _finish() -> void:
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	get_tree().quit(1 if failed > 0 else 0)
