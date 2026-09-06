extends Node

## Does the "Large Touch Targets" accessibility toggle do anything?
##
## THE DEFECT
##   Reported as "the toggle does nothing". Everything around it looked wired: Settings
##   builds the checkbox, AccessibilityManager.set_large_touch_targets() persists the key
##   through SaveManager, MobileUIManager._wants_large_touch_targets() reads it back, and
##   the handler re-runs adapt_scene_for_mobile() on the live scene. The dead part was
##   arithmetic in the middle. _resolve_button_min_size() raised the target to a FIXED
##   Vector2(120, 80) canvas units when the toggle was on, and then raised it again to the
##   48dp floor - and on a phone the 48dp floor is the bigger of the two:
##
##     Moto E5 Plus  402.5 dpi, ratio 1.0  ->  48dp = 121 units   off: 121x121  on: 121x121
##     Poco X3       394.6 dpi, ratio 1.0  ->  48dp = 119 units   off: 119x119  on: 120x119
##
##   Both reported devices, both states, the same size. The toggle was only ever visible on
##   the 9.7in tablet profile, whose floor is 75 units. A fixed pair of canvas units cannot
##   express "bigger than the minimum" on a screen whose minimum is stated in dp, so the
##   fix is a second DP floor - LARGE_TOUCH_TARGET_DP = 64dp - run through the same
##   production conversion.
##
##   Two things went with it. The growth was ONE-WAY: it grew from the button's live
##   custom_minimum_size, and max(current, smaller_floor) is current, so turning the toggle
##   back off left every button big until its scene was rebuilt. And a compact list row -
##   every Settings checkbox is one - fell through to a BOTH-AXES floor once the toggle was
##   on, which is the 126x126-square regression COMPACT_ROW_META was created to prevent.
##
## WHAT IS MEASURED HERE
##   1. that the old design really was inert on the reported devices, so the rows below are
##      not passing vacuously against a defect that was never there.
##   2. that the resolved minimum now grows on both reported devices, through the product's
##      own dp conversion rather than arithmetic repeated here.
##   3. that a real button grows when the toggle goes on and SHRINKS BACK when it goes off,
##      driven through _on_node_added() - the entry point 80 runtime-built buttons use.
##   4. that a button whose script authored something larger than the floor keeps its own
##      size, in both states. This is the risk the authored-size meta introduces.
##   5. that a later write by the button's owner becomes the new baseline instead of being
##      clobbered by the next adaptation pass.
##   6. that a compact row grows in HEIGHT ONLY and never becomes a square.
##   7. that Settings' own checkbox writes the setting and re-lays-out the live scene.
##   8. that the pass is idempotent - three applies, one size.
##   9. that none of it reaches the desktop path, and that single player's base class did
##      not acquire a dependency on the toggle.
##
## NOT MEASURED HERE (needs the physical device)
##   That 64dp is comfortable rather than merely larger, and the reported dpi of the two
##   phones. The clipping and overlap cost of the bigger floor across all seven device
##   profiles is measured separately by:
##       godot --path . tools/AuditMobileUI.tscn -- --large-targets
##
## Usage:
##   godot --headless --path . res://tools/VerifyLargeTouchTargets.tscn
##
## Headless is fine here: every measurement is a custom_minimum_size WRITE plus the dp
## conversion, not an on-screen rect, and the headless canvas puts _stretch_ratio() at 1.0
## which is what both reported phones report anyway.

const SETTINGS_SCENE: String = "res://scenes/ui/Settings.tscn"
const SETTING_KEY: String = "large_touch_targets"

## The two devices the reports came from, by name in AuditMobileUI's DEVICES table. Their
## dpi is read from there rather than restated, so this harness cannot drift from the audit.
const REPORTED: Array[String] = ["Moto E5 Plus", "Poco X3"]

## The fixed canvas-unit pair the old code used for "large". Kept only so row 1 can show it
## was already below the 48dp floor on the reported hardware.
const OLD_LARGE_PAIR: Vector2 = Vector2(120.0, 80.0)

## An effective dpi - device dpi divided by the stretch ratio, which is what the production
## conversion actually divides by - chosen to reproduce the units the two 4.5in profiles resolved
## to in tools/AuditMobileUI.tscn: 64dp * (490/160) = 196 units, and 48dp * (490/160) = 147.
## Those are exactly the numbers printed for WVGA 4.5in and qHD 4.5in, and 196 is the size whose
## title screen showed four accidental-touch pairs. The pin is stated as one number rather than
## reconstructed from a device entry so this harness never re-implements the stretch arithmetic.
const SMALL_SCREEN_EFFECTIVE_DPI: float = 490.0

## Absurdly dense, so that the 48dp floor ALONE (300 units) is larger than the ceiling. Used for
## the one row that proves the ceiling cannot pull a target below the standard.
const DENSE_SCREEN_EFFECTIVE_DPI: float = 1000.0

## The largest resolved target AuditMobileUI measured with zero overlaps and zero clipping on the
## title screen - the HD 5.0in profile's 177 units. The ceiling has to sit at or under it, which
## is the whole reason 0.16 was picked; restated here so the harness fails if someone raises the
## fraction past what has actually been measured.
const LARGEST_CLEAN_UNITS: float = 177.0

var _pass: int = 0
var _fail: int = 0

var _mui: Node = null
var _save: Node = null
var _saved_setting: Variant = null
var _saved_dpi_override: float = 0.0
var _saved_debug_mobile: bool = false


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


## The floor the production code resolves right now, at whatever profile is pinned.
func _resolved() -> Vector2:
	_mui.call("invalidate_button_min_size_cache")
	return _mui.call("_resolve_button_min_size")


## Flip the toggle WITHOUT persisting it. SaveManager.set_setting() writes
## waterwise_settings.json, and a test run must not leave the player's own accessibility
## preference flipped; the one row that does go through the real handler is the Settings
## scene row, and the original value is restored at the end of the run.
func _set_toggle(on: bool) -> void:
	_save.settings[SETTING_KEY] = on
	var acc := get_node_or_null("/root/AccessibilityManager")
	if acc:
		acc.large_touch_targets = on
	_mui.call("invalidate_button_min_size_cache")


## Pin one device profile through the production conversion's own override, the way
## tools/AuditMobileUI.gd and tools/VerifyTouchTargets.gd do. dpi comes from the audit's
## table so there is one source for it.
##
## The pinned number is spent as an EFFECTIVE dpi: _dp_to_canvas_units() divides by the live
## stretch ratio, so a device dpi handed straight through only lands on the unit counts the
## audit published while that ratio is 1.0. It is 1.0 headless - the documented mode above -
## and it is NOT 1.0 if this harness is run windowed, where the OS hands back a work-area-sized
## window (~1040 tall on this desktop, ratio 0.96) and every measured size comes out ~4% large:
## 64dp read 204 units instead of 196 and the audit-parity row failed on the window, not on the
## product. Multiplying by the ratio cancels that division, so every row reads the same in both
## modes rather than only in the one the header names.
func _pin_profile(dpi: float) -> void:
	var ratio: float = maxf(float(_mui.call("_stretch_ratio")), 0.0001)
	_mui.set("debug_dpi_override", dpi * ratio)
	_mui.call("invalidate_button_min_size_cache")


func _dpi_of(device_name: String) -> float:
	var audit := load("res://tools/AuditMobileUI.gd") as GDScript
	var devices: Array = audit.get_script_constant_map().get("DEVICES", [])
	var helper: Node = audit.new()
	var out: float = 0.0
	for d in devices:
		if str(d.get("name", "")) == device_name:
			out = float(helper.call("_dpi", d))
			break
	helper.free()
	return out


## A throwaway button that has never met this manager, with the minimum its script authored.
func _fresh_button(authored: Vector2, compact: bool = false) -> Button:
	var b := Button.new()
	b.text = "X"
	b.custom_minimum_size = authored
	if compact:
		b.set_meta(_mui.COMPACT_ROW_META, true)
	return b


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Large Touch Targets: does the toggle change anything a finger can feel? ===")

	_mui = get_node_or_null("/root/MobileUIManager")
	_save = get_node_or_null("/root/SaveManager")
	if _mui == null or _save == null:
		print("  FAIL  autoload missing (MobileUIManager=%s SaveManager=%s)"
			% [_mui != null, _save != null])
		get_tree().quit(1)
		return

	_saved_setting = _save.get_setting(SETTING_KEY, false)
	_saved_dpi_override = float(_mui.get("debug_dpi_override"))
	_saved_debug_mobile = bool(_mui.get("debug_mobile_mode"))

	# Force the mobile path: every floor in this file is mobile-only by design, and
	# is_mobile is recomputed inside _detect_platform(), which the debug entry point re-runs.
	if _mui.has_method("enable_debug_mobile_mode"):
		_mui.call("enable_debug_mobile_mode", true)
	else:
		_mui.set("debug_mobile_mode", true)
		if _mui.has_method("_detect_platform"):
			_mui.call("_detect_platform")
	await _frames(2)
	_check("MobileUIManager is on its mobile path, so the floors are live",
		bool(_mui.get("is_mobile")), "is_mobile=%s" % bool(_mui.get("is_mobile")))

	await _defect_was_real()
	await _floor_grows()
	await _large_floor_cap()
	await _live_button_round_trip()
	await _authored_larger_is_kept()
	await _owner_write_becomes_baseline()
	await _compact_row_axis()
	await _idempotence()
	await _settings_row()
	await _desktop_untouched()
	_static_isolation()

	# Hand the environment back exactly as it was found. The Settings row above went through
	# the product's real handler, which persists, so this restore has to persist too.
	_mui.set("debug_dpi_override", _saved_dpi_override)
	_save.set_setting(SETTING_KEY, _saved_setting)
	var acc := get_node_or_null("/root/AccessibilityManager")
	if acc:
		acc.large_touch_targets = bool(_saved_setting)
	_mui.set("debug_mobile_mode", _saved_debug_mobile)
	if _mui.has_method("_detect_platform"):
		_mui.call("_detect_platform")
	_mui.call("invalidate_button_min_size_cache")
	await _frames(2)
	_check("the run left the saved preference as it found it",
		bool(_save.get_setting(SETTING_KEY, false)) == bool(_saved_setting),
		"%s on disk, %s restored" % [bool(_saved_setting), bool(_save.get_setting(SETTING_KEY, false))])

	print("")
	print("  -- on-device rows, not measurable here --")
	print("     that 64dp is comfortable rather than merely larger, and the dpi the two")
	print("     phones actually report. The clipping and overlap cost of the bigger floor")
	print("     is measured by: godot --path . tools/AuditMobileUI.tscn -- --large-targets")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## Row 1. The vacuity guard for the whole file: on the reported hardware the 48dp floor is
## ALREADY bigger than the fixed 120x80 pair the old code called "large", so the old toggle
## resolved to the same size in both states. If this row ever fails, the defect this harness
## describes is not the defect the code has.
func _defect_was_real() -> void:
	print("")
	print("  -- was the old design actually inert? --")
	for device_name in REPORTED:
		var dpi: float = _dpi_of(device_name)
		_check("%s is in the audit's device table, so its dpi is not invented here"
			% device_name, dpi > 0.0, "dpi=%.1f" % dpi)
		if dpi <= 0.0:
			continue
		_pin_profile(dpi)
		# The 48dp floor, from the production conversion.
		var min_floor: float = float(_mui.call("_dp_to_canvas_units", _mui.MIN_TOUCH_TARGET_DP))
		# What the OLD code resolved to in each state, using its own two inputs: the authored
		# mobile_button_min_size when off, the fixed pair when on, each then raised to the
		# 48dp floor. The claim is not that the two were bit-identical everywhere - on the
		# Poco X3 the fixed 120 beats the 119-unit floor by one unit on one axis - but that
		# the difference was never something a finger could find.
		var authored: Vector2 = Vector2(_mui.get("mobile_button_min_size"))
		var old_off := Vector2(maxf(authored.x, min_floor), maxf(authored.y, min_floor))
		var old_on := Vector2(maxf(OLD_LARGE_PAIR.x, min_floor), maxf(OLD_LARGE_PAIR.y, min_floor))
		var moved: float = (old_on - old_off).length()
		_check("%s: the old toggle moved the target by %.0f units - the 48dp floor (%.0f) had"
			% [device_name, moved, min_floor]
			+ " already passed the fixed %s pair" % str(OLD_LARGE_PAIR),
			moved <= 2.0,
			"old off %.0fx%.0f, old on %.0fx%.0f" % [old_off.x, old_off.y, old_on.x, old_on.y])


## Row 2. The fix itself, at both reported profiles, through the product's own conversion.
func _floor_grows() -> void:
	print("")
	print("  -- does the resolved minimum grow now? --")
	for device_name in REPORTED:
		var dpi: float = _dpi_of(device_name)
		if dpi <= 0.0:
			continue
		_pin_profile(dpi)
		_set_toggle(false)
		var off: Vector2 = _resolved()
		_set_toggle(true)
		var on: Vector2 = _resolved()
		_check("%s: the minimum grows on BOTH axes with the toggle on" % device_name,
			on.x > off.x and on.y > off.y,
			"off %.0fx%.0f -> on %.0fx%.0f (+%.0f%%)"
				% [off.x, off.y, on.x, on.y, 100.0 * (on.y / maxf(off.y, 1.0) - 1.0)])
		# Growth has to be worth a finger noticing, not a rounding artefact. 64/48 is a
		# third; anything under a fifth would be the old defect with extra steps.
		_check("%s: the growth is at least a fifth, not a rounding artefact" % device_name,
			on.y >= off.y * 1.2,
			"%.0f -> %.0f units" % [off.y, on.y])
		# The number is the production dp conversion of LARGE_TOUCH_TARGET_DP, not a
		# hardcoded pair - the whole point of the fix.
		var large_floor: float = float(
			_mui.call("_dp_to_canvas_units", _mui.LARGE_TOUCH_TARGET_DP))
		_check("%s: it lands on the %ddp conversion, not on a fixed unit pair"
			% [device_name, int(_mui.LARGE_TOUCH_TARGET_DP)],
			is_equal_approx(on.y, large_floor),
			"resolved %.0f, _dp_to_canvas_units(%.0f)=%.0f"
				% [on.y, _mui.LARGE_TOUCH_TARGET_DP, large_floor])
		_set_toggle(false)


## Row 2b. The ceiling on the request, which exists because the 64dp floor did not fit
## everywhere. tools/AuditMobileUI.tscn -- --large-targets found four accidental-touch pairs on
## the title screen at the two 4.5in profiles, where 64dp resolves to 196 canvas units: the
## top-right icon strip grows down from the top edge, the PLAY/MULTIPLAYER column grows up from
## the bottom, and at that size they meet. Nothing overlapped at 177 units or less, so the
## request is capped just under that. These rows measure that the cap bites where it has to,
## does NOT bite on either reported device, and can never pull a target below 48dp.
func _large_floor_cap() -> void:
	print("")
	print("  -- the ceiling on the large request --")
	# The ceiling is derived here the way the constant documents it - a fraction of the AUTHORED
	# base height out of ProjectSettings - and NOT by calling _large_target_floor_units(). That
	# helper returns min(64dp-at-this-screen, ceiling), so at any profile where the cap does not
	# bite it reports the device's own floor instead of the cap: read once before the pin below,
	# it handed back the previous group's Poco X3 value of 158 and three rows compared to that.
	var base_height: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var ceiling: float = ceilf(base_height * _mui.LARGE_TOUCH_TARGET_MAX_CANVAS_FRACTION)
	_pin_profile(SMALL_SCREEN_EFFECTIVE_DPI)
	_set_toggle(true)
	var uncapped: float = float(
		_mui.call("_dp_to_canvas_units", _mui.LARGE_TOUCH_TARGET_DP))
	var small_floor: float = float(
		_mui.call("_dp_to_canvas_units", _mui.MIN_TOUCH_TARGET_DP))
	# Restating the product's arithmetic inside a harness is only safe if the two are checked
	# against each other. At this pin the cap bites, so the helper's min() must land exactly on
	# it - which is also what proves the number below is the cap and not a device's own floor.
	var helper_here: float = float(_mui.call("_large_target_floor_units"))
	_check("the product's own floor helper lands on that ceiling where the cap bites",
		is_equal_approx(helper_here, ceiling),
		"_large_target_floor_units() -> %.0f units; ceiling derived here %.0f (%.2f x %d)"
			% [helper_here, ceiling, _mui.LARGE_TOUCH_TARGET_MAX_CANVAS_FRACTION,
				int(base_height)])
	# Vacuity guard: if 64dp already fitted at this profile there would be nothing to cap and
	# every row below would pass without the ceiling doing anything.
	_check("a 4.5in-class screen really does ask for more than the ceiling allows",
		uncapped > ceiling,
		"64dp wants %.0f units, ceiling is %.0f (%.2f x the authored %d-unit height)"
			% [uncapped, ceiling, _mui.LARGE_TOUCH_TARGET_MAX_CANVAS_FRACTION,
				int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))])
	# Within one unit, not exactly: _pin_profile() multiplies by the stretch ratio that
	# _dp_to_canvas_units() then divides out, and the division is ceilf()'d, so a value landing
	# on 147.0000001 comes back as 148. One unit of float noise on 147 is not what this row is
	# about - it is about the pin standing in for the audit's 4.5in profiles at all.
	_check("the pin reproduces the units the audit measured on those profiles",
		absf(uncapped - 196.0) <= 1.0 and absf(small_floor - 147.0) <= 1.0,
		"48dp -> %.0f units, 64dp -> %.0f units (audit printed 147 and 196)"
			% [small_floor, uncapped])
	var capped: Vector2 = _resolved()
	_check("the resolved minimum is held at the ceiling, not at the raw 64dp size",
		is_equal_approx(capped.y, ceiling) and is_equal_approx(capped.x, ceiling),
		"resolved %.0fx%.0f, ceiling %.0f, uncapped %.0f"
			% [capped.x, capped.y, ceiling, uncapped])
	_check("the ceiling sits at or under the largest size measured overlap-free",
		ceiling <= LARGEST_CLEAN_UNITS,
		"ceiling %.0f units vs %.0f measured clean on the title screen"
			% [ceiling, LARGEST_CLEAN_UNITS])
	# A cap that cancelled the feature on small screens would be the original defect again.
	_check("the toggle still buys a small screen something a finger can feel",
		capped.y > small_floor * 1.1,
		"48dp floor %.0f -> capped large floor %.0f (+%.0f%%)"
			% [small_floor, capped.y, 100.0 * (capped.y / maxf(small_floor, 1.0) - 1.0)])
	_set_toggle(false)
	var off_small: Vector2 = _resolved()
	_check("with the toggle off the ceiling changes nothing at all",
		is_equal_approx(off_small.y, small_floor),
		"resolved %.0f, 48dp floor %.0f" % [off_small.y, small_floor])

	# The reported hardware is on the other side of the ceiling: it must still get the full 64dp.
	for device_name in REPORTED:
		var dpi: float = _dpi_of(device_name)
		if dpi <= 0.0:
			continue
		_pin_profile(dpi)
		_set_toggle(true)
		var want: float = float(_mui.call("_dp_to_canvas_units", _mui.LARGE_TOUCH_TARGET_DP))
		var got: Vector2 = _resolved()
		_check("%s: the ceiling does not bite - the full %ddp floor is still resolved"
			% [device_name, int(_mui.LARGE_TOUCH_TARGET_DP)],
			is_equal_approx(got.y, want) and want <= ceiling,
			"resolved %.0f, 64dp wants %.0f, ceiling %.0f" % [got.y, want, ceiling])
		_set_toggle(false)

	# And the standard outranks the ceiling: on a screen dense enough that 48dp alone exceeds it,
	# the floor is the standard, not the cap.
	_pin_profile(DENSE_SCREEN_EFFECTIVE_DPI)
	_set_toggle(true)
	var dense_min: float = float(
		_mui.call("_dp_to_canvas_units", _mui.MIN_TOUCH_TARGET_DP))
	var dense: Vector2 = _resolved()
	_check("where 48dp alone exceeds the ceiling the standard wins",
		dense_min > ceiling and is_equal_approx(dense.y, dense_min),
		"48dp -> %.0f units, ceiling %.0f, resolved %.0f" % [dense_min, ceiling, dense.y])
	_set_toggle(false)


## Row 3. A real button, through the entry point the product uses for the 80 buttons its
## scripts build at runtime - and back again. The return trip is the half that was broken:
## growth read the button's live minimum, so the smaller floor could never win.
func _live_button_round_trip() -> void:
	print("")
	print("  -- one button, toggle on, toggle off --")
	_pin_profile(_dpi_of(REPORTED[0]))
	_set_toggle(false)
	var b := _fresh_button(Vector2(100.0, 50.0))
	add_child(b)
	await _frames(2)
	var off_size: Vector2 = b.custom_minimum_size
	var off_floor: Vector2 = _resolved()
	_check("with the toggle off the button sits on the 48dp floor",
		is_equal_approx(off_size.y, off_floor.y),
		"custom_minimum_size %.0fx%.0f, floor %.0fx%.0f"
			% [off_size.x, off_size.y, off_floor.x, off_floor.y])

	_set_toggle(true)
	_mui.call("_apply_button_min_size", b, _resolved())
	var on_size: Vector2 = b.custom_minimum_size
	_check("turning the toggle ON grows that same button",
		on_size.y > off_size.y,
		"%.0fx%.0f -> %.0fx%.0f" % [off_size.x, off_size.y, on_size.x, on_size.y])

	_set_toggle(false)
	_mui.call("_apply_button_min_size", b, _resolved())
	var back_size: Vector2 = b.custom_minimum_size
	_check("turning it OFF again shrinks the button back to where it was",
		back_size.is_equal_approx(off_size),
		"%.0fx%.0f -> %.0fx%.0f (was %.0fx%.0f)"
			% [on_size.x, on_size.y, back_size.x, back_size.y, off_size.x, off_size.y])
	b.queue_free()
	await _frames(1)


## Row 4. The risk the authored-size meta introduces. A script that asks for 400x200 has to
## keep 400x200: the floor only ever raises a minimum, it must never lower one.
func _authored_larger_is_kept() -> void:
	print("")
	print("  -- a button bigger than the floor keeps its own size --")
	_pin_profile(_dpi_of(REPORTED[0]))
	var authored := Vector2(400.0, 200.0)
	for state in [false, true]:
		_set_toggle(state)
		var b := _fresh_button(authored)
		add_child(b)
		await _frames(2)
		_mui.call("_apply_button_min_size", b, _resolved())
		_check("toggle %s: an authored %s minimum is not shrunk to the floor"
			% ["on " if state else "off", str(authored)],
			b.custom_minimum_size.x >= authored.x and b.custom_minimum_size.y >= authored.y,
			"custom_minimum_size %.0fx%.0f, floor %s"
				% [b.custom_minimum_size.x, b.custom_minimum_size.y, str(_resolved())])
		b.queue_free()
		await _frames(1)
	_set_toggle(false)


## Row 5. The other half of that meta: once the button's owner writes a new minimum AFTER
## the manager has written one - which is what a script sizing its own button after
## add_child() does - the owner's number is the baseline the next pass grows from, not
## something to be clobbered back down to the floor.
func _owner_write_becomes_baseline() -> void:
	print("")
	print("  -- a later write by the button's owner is respected --")
	_pin_profile(_dpi_of(REPORTED[0]))
	_set_toggle(false)
	var b := _fresh_button(Vector2(80.0, 40.0))
	add_child(b)
	await _frames(2)
	var after_floor: Vector2 = b.custom_minimum_size
	# The owner speaks second, asking for something wider than the floor.
	var owner_wants := Vector2(after_floor.x + 220.0, after_floor.y + 40.0)
	b.custom_minimum_size = owner_wants
	_mui.call("_apply_button_min_size", b, _resolved())
	_check("a minimum written after the floor pass survives the next pass",
		b.custom_minimum_size.is_equal_approx(owner_wants),
		"owner asked %.0fx%.0f, ended %.0fx%.0f"
			% [owner_wants.x, owner_wants.y, b.custom_minimum_size.x, b.custom_minimum_size.y])
	b.queue_free()
	await _frames(1)


## Row 6. The regression next door. COMPACT_ROW_META exists because a both-axes floor turned
## every Settings checkbox into a 126x126 square and pushed six accessibility rows through
## the bottom of the card. The old code exempted those rows only while the toggle was OFF, so
## the state this item is about was the state that broke the layout. A row grows in height
## only, and its width stays whatever its scene asked for.
func _compact_row_axis() -> void:
	print("")
	print("  -- a compact list row must not become a square --")
	_pin_profile(_dpi_of(REPORTED[0]))
	var authored := Vector2(0.0, 56.0)  # what Settings._normalize_toggle() authors
	_set_toggle(false)
	var off_row := _fresh_button(authored, true)
	add_child(off_row)
	await _frames(2)
	_mui.call("_apply_button_min_size", off_row, _resolved())
	_check("toggle off: the row keeps the height its scene authored",
		is_equal_approx(off_row.custom_minimum_size.y, authored.y),
		"custom_minimum_size %.0fx%.0f, authored %.0fx%.0f"
			% [off_row.custom_minimum_size.x, off_row.custom_minimum_size.y,
				authored.x, authored.y])

	_set_toggle(true)
	var floor_now: Vector2 = _resolved()
	_mui.call("_apply_button_min_size", off_row, floor_now)
	_check("toggle on: the row grows in height",
		off_row.custom_minimum_size.y > authored.y,
		"%.0f -> %.0f units (floor %.0f)"
			% [authored.y, off_row.custom_minimum_size.y, floor_now.y])
	_check("toggle on: its WIDTH is left where its scene put it, so it is not a square",
		is_equal_approx(off_row.custom_minimum_size.x, authored.x),
		"custom_minimum_size %.0fx%.0f - a square would be %.0fx%.0f"
			% [off_row.custom_minimum_size.x, off_row.custom_minimum_size.y,
				floor_now.x, floor_now.y])

	_set_toggle(false)
	_mui.call("_apply_button_min_size", off_row, _resolved())
	_check("toggle off again: the row returns to its authored height",
		is_equal_approx(off_row.custom_minimum_size.y, authored.y),
		"ended %.0fx%.0f" % [off_row.custom_minimum_size.x, off_row.custom_minimum_size.y])
	off_row.queue_free()
	await _frames(1)


## Row 7. Three applies, one size. The manager re-runs this pass on every scene change, every
## resize and every node_added, so a pass that accumulated would walk a button off its layout.
func _idempotence() -> void:
	print("")
	print("  -- the pass does not compound --")
	_pin_profile(_dpi_of(REPORTED[0]))
	_set_toggle(true)
	var b := _fresh_button(Vector2(100.0, 50.0))
	add_child(b)
	await _frames(2)
	var first: Vector2 = b.custom_minimum_size
	for _i in range(3):
		_mui.call("_apply_button_min_size", b, _resolved())
	_check("three further applies leave the same minimum",
		b.custom_minimum_size.is_equal_approx(first),
		"%.0fx%.0f after one, %.0fx%.0f after four"
			% [first.x, first.y, b.custom_minimum_size.x, b.custom_minimum_size.y])
	b.queue_free()
	_set_toggle(false)
	await _frames(1)


## Every BaseButton under a node, split by whether it is a compact list row.
func _buttons_under(root: Node, compact: bool) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton and (n as BaseButton).has_meta(_mui.COMPACT_ROW_META) == compact:
			out.append(n as BaseButton)
		for c in n.get_children():
			stack.append(c)
	return out


## Row 8. The player's actual path: press the checkbox in Settings and the screen you are
## looking at re-lays-out under your finger. Driven through the checkbox's own toggled signal
## and the product's handler, which is also the only place in this run that writes to disk.
func _settings_row() -> void:
	print("")
	print("  -- Settings' own checkbox, through its real handler --")
	_pin_profile(_dpi_of(REPORTED[0]))
	_set_toggle(false)

	var scene: Node = load(SETTINGS_SCENE).instantiate()
	get_tree().root.add_child(scene)
	# The handler re-adapts get_tree().current_scene, so the slot has to be handed over -
	# this harness holds it otherwise and the re-layout would land on the wrong node.
	var prev_current: Node = get_tree().current_scene
	get_tree().current_scene = scene
	await _frames(10)

	var box: CheckBox = scene.get("large_targets_check") as CheckBox
	_check("the Settings screen still has a Large Touch Targets checkbox",
		box != null, "large_targets_check=%s" % str(box))
	if box == null:
		get_tree().current_scene = prev_current
		scene.queue_free()
		return
	_check("it is wired to the product's handler, not left dangling",
		box.is_connected("toggled", Callable(scene, "_on_large_targets_toggled")),
		"toggled connections: %d" % box.get_signal_connection_list("toggled").size())

	var standalone: Array[BaseButton] = _buttons_under(scene, false)
	var rows: Array[BaseButton] = _buttons_under(scene, true)
	_check("the screen has standalone buttons and compact rows to measure",
		standalone.size() > 0 and rows.size() > 0,
		"%d standalone, %d compact rows" % [standalone.size(), rows.size()])
	var before: Dictionary = {}
	for b in standalone:
		before[b.get_instance_id()] = b.custom_minimum_size

	# The press.
	box.set_pressed(true)
	await _frames(6)

	_check("pressing it writes the setting the rest of the game reads",
		bool(_save.get_setting(SETTING_KEY, false)),
		"%s = %s" % [SETTING_KEY, str(_save.get_setting(SETTING_KEY, false))])
	var large_floor: Vector2 = _resolved()
	var grew: int = 0
	for b in standalone:
		if b.custom_minimum_size.y > Vector2(before[b.get_instance_id()]).y:
			grew += 1
	_check("the screen under your finger re-laid-out: %d of %d standalone buttons grew"
		% [grew, standalone.size()], grew > 0,
		"large floor %.0fx%.0f" % [large_floor.x, large_floor.y])
	var squared: int = 0
	for r in rows:
		if r.custom_minimum_size.x >= large_floor.x:
			squared += 1
	_check("and none of its %d compact rows was squared off in the process" % rows.size(),
		squared == 0,
		"%d rows reached the floor's full width (%.0f units)" % [squared, large_floor.x])

	box.set_pressed(false)
	await _frames(6)
	_check("unpressing it puts the setting back",
		not bool(_save.get_setting(SETTING_KEY, false)),
		"%s = %s" % [SETTING_KEY, str(_save.get_setting(SETTING_KEY, false))])
	var shrank: int = 0
	for b in standalone:
		if b.custom_minimum_size.is_equal_approx(Vector2(before[b.get_instance_id()])):
			shrank += 1
	_check("and every standalone button is back at the size it had before the press",
		shrank == standalone.size(),
		"%d of %d restored" % [shrank, standalone.size()])

	get_tree().current_scene = prev_current
	scene.queue_free()
	await _frames(2)


## Row 9. Single player and desktop are shared code. The touch floor is mobile-only by
## design - _on_node_added() returns immediately when is_mobile is false - so a desktop build
## must be unable to tell the toggle exists. This is the "do not regress single player" check
## for this item: the same button, the same toggle, no change.
func _desktop_untouched() -> void:
	print("")
	print("  -- the desktop path cannot see the toggle --")
	_mui.set("debug_mobile_mode", false)
	_mui.set("debug_dpi_override", 0.0)
	if _mui.has_method("_detect_platform"):
		_mui.call("_detect_platform")
	await _frames(2)
	var desktop: bool = not bool(_mui.get("is_mobile"))
	_check("this environment reports itself as not-mobile, so the row can mean something",
		desktop, "is_mobile=%s" % bool(_mui.get("is_mobile")))

	var authored := Vector2(100.0, 50.0)
	_set_toggle(true)
	var b := _fresh_button(authored)
	add_child(b)
	await _frames(2)
	_check("with the toggle ON a desktop button keeps exactly its authored minimum",
		b.custom_minimum_size.is_equal_approx(authored),
		"custom_minimum_size %.0fx%.0f, authored %.0fx%.0f"
			% [b.custom_minimum_size.x, b.custom_minimum_size.y, authored.x, authored.y])
	b.queue_free()
	_set_toggle(false)
	await _frames(1)

	# Put the mobile path back for the restore block, which reads it.
	if _mui.has_method("enable_debug_mobile_mode"):
		_mui.call("enable_debug_mobile_mode", true)
	await _frames(2)


## Strip comments before searching source, so the prose explaining a removed dependency is
## not mistaken for the dependency.
func _code_of(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var out := ""
	while not f.eof_reached():
		var line := f.get_line()
		var hash_at := line.find("#")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		out += line + "\n"
	f.close()
	return out


## Row 10. Where the toggle is allowed to be read from. The accessibility floor belongs to
## MobileUIManager; single player's base class must not have grown its own opinion about it,
## which is what would make the two paths drift.
func _static_isolation() -> void:
	print("")
	print("  -- who is allowed to read this setting --")
	var sp := _code_of("res://scripts/MiniGameBase.gd")
	_check("single player's base class does not read the setting itself",
		sp.find(SETTING_KEY) < 0 and sp.find("LARGE_TOUCH_TARGET_DP") < 0,
		"scripts/MiniGameBase.gd mentions it in code: %s"
			% str(sp.find(SETTING_KEY) >= 0 or sp.find("LARGE_TOUCH_TARGET_DP") >= 0))
	var mp := _code_of("res://scripts/multiplayer/MultiplayerMiniGameBase.gd")
	_check("neither does the multiplayer base class",
		mp.find(SETTING_KEY) < 0 and mp.find("LARGE_TOUCH_TARGET_DP") < 0,
		"scripts/multiplayer/MultiplayerMiniGameBase.gd mentions it in code: %s"
			% str(mp.find(SETTING_KEY) >= 0 or mp.find("LARGE_TOUCH_TARGET_DP") >= 0))
	# The one number the fix turns on, in the one place it belongs.
	var mui_src := _code_of("res://autoload/MobileUIManager.gd")
	# Both floors are dp constants put through the SAME conversion, so neither can drift into a
	# hardcoded unit count that is only right on one screen. This row used to look for a shared
	# "floor_dp" local; that local is gone, because the large size now converts one level down
	# inside _large_target_floor_units() where it also has to be capped.
	var large_converted: bool = mui_src.find("_dp_to_canvas_units(LARGE_TOUCH_TARGET_DP)") >= 0
	var min_converted: bool = mui_src.find("_dp_to_canvas_units(MIN_TOUCH_TARGET_DP)") >= 0
	_check("both touch floors are dp constants run through MobileUIManager's own conversion",
		large_converted and min_converted,
		"64dp converted: %s; 48dp converted: %s" % [large_converted, min_converted])
