extends Node

## ═══════════════════════════════════════════════════════════════════
## SAVEMANAGER PLAY-TIME + LOAD-TRUST HARNESS
## ═══════════════════════════════════════════════════════════════════
## Two defects on SaveManager's persistence path, both measured here.
##
## A. PLAY-TIME OVER-COUNT.  _update_play_time() is
##
##       var current_time = Time.get_unix_time_from_system()   # float
##       var session_duration = current_time - session_start_time
##       player_data.total_play_time += session_duration
##       session_start_time = int(current_time)                # <-- truncates
##
##    session_start_time is declared `int`, so every call re-bases the clock at
##    floor(now) while measuring from the un-truncated now. Each call therefore
##    adds frac(now) seconds that never elapsed — mean 0.5 s, unbounded in count,
##    because _update_play_time() runs on EVERY save_now() and on both
##    _notification() branches (close request, Android pause / focus out).
##    A save-heavy session inflates total_play_time without limit.
##    Measured below by calling it CALLS times inside one frame and comparing the
##    accumulated total against the real elapsed wall time of that loop.
##
##    The same line also changes the VALUE'S TYPE: `int += float` makes
##    player_data.total_play_time a float from the first call onward. That breaks
##    get_play_time_formatted(), whose `total % 3600` is GDScript's integer-only
##    modulo — floats need fmod(). So the formatter is a latent runtime error
##    armed by the first save of every session. It has no callers today, which is
##    the only reason nobody has seen it; the type check and the format check
##    below pin it down before a stats screen finds it the hard way.
##
## B. A WRONG-TYPED FIELD ABORTS THE REST OF THE LOAD.  _merge_data() installed
##    container fields straight off the parsed file:
##
##       high_scores = data.high_scores
##       sp_session_scores = data.sp_session_scores
##
##    Those members are STATICALLY TYPED, so an Array arriving where the Dictionary
##    belongs does not merely store the wrong thing — it raises "Trying to assign
##    value of type 'Array' to a variable of type 'Dictionary'" and aborts
##    _merge_data() on the spot. Every field declared below that line — session
##    scores, unlocked content, achievements, and the accessory/decoration
##    back-fill — was then silently dropped, while player_data, merged above it, was
##    kept. The player boots into a half-loaded profile: droplets and games played
##    intact, leaderboard and unlocks gone. The same abort happens at the last field
##    when an achievement entry is a scalar, because `entry.get("unlocked", …)` is
##    a bad call on an int, and that one takes the back-fill down with it.
##
##    Measured below with a file that is wrong in exactly one field and valid in
##    every field after it, which is what makes the drop observable.
##
##    Also measured here: JSON has a single number type, so every integer field
##    round-trips as a float (games_played 9 -> 9.0). total_play_time feeds
##    get_play_time_formatted()'s integer-only `%`, so a load alone armed that
##    runtime error even without a single save.
##
##    This is shape validation at a file trust boundary — one check where external
##    data enters — not a scattering of null guards at the use sites.
##
## Every negative check has a positive control beside it: the drift check is
## paired with "a real 2 s wait must still be counted" (a fix that counts nothing
## would pass drift and fail that), and the hostile-save check is paired with a
## well-formed save that must survive intact (a fix that wipes everything would
## pass hostile and fail that).
##
## The real user:// save and settings files are copied aside before the hostile
## write and restored in _finish(), including on a failing run.
##
## Run:
##   godot --headless --path . res://tools/VerifySavePersistence.tscn

const SAVE_PATH: String = "user://waterwise_save.json"
const SETTINGS_PATH: String = "user://waterwise_settings.json"
const BAK_SAVE: String = "user://waterwise_save.harness_bak"
const BAK_SETTINGS: String = "user://waterwise_settings.harness_bak"

## Enough calls that the ~0.5 s mean drift per call cannot hide in rounding, few
## enough to stay inside a single frame.
const CALLS: int = 40
## One carry second is legitimate: the fix banks whole seconds and keeps the
## remainder, so the total may sit up to 1 s ahead of the loop's own elapsed time.
const DRIFT_TOLERANCE: float = 1.5
## A real wait long enough that at least 2 whole seconds must be banked.
const REAL_WAIT: float = 2.3

var results: Array = []
var save_existed: bool = false
var settings_existed: bool = false

# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _finish() -> void:
	_restore_user_files()
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

# ── user:// file custody ────────────────────────────────────────────

func _backup_user_files() -> void:
	save_existed = FileAccess.file_exists(SAVE_PATH)
	settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	if save_existed:
		DirAccess.copy_absolute(SAVE_PATH, BAK_SAVE)
	if settings_existed:
		DirAccess.copy_absolute(SETTINGS_PATH, BAK_SETTINGS)
	print("  [custody] save present=%s settings present=%s"
		% [str(save_existed), str(settings_existed)])


func _restore_user_files() -> void:
	if save_existed and FileAccess.file_exists(BAK_SAVE):
		DirAccess.copy_absolute(BAK_SAVE, SAVE_PATH)
		DirAccess.remove_absolute(BAK_SAVE)
	elif not save_existed:
		DirAccess.remove_absolute(SAVE_PATH)
	if settings_existed and FileAccess.file_exists(BAK_SETTINGS):
		DirAccess.copy_absolute(BAK_SETTINGS, SETTINGS_PATH)
		DirAccess.remove_absolute(BAK_SETTINGS)
	elif not settings_existed:
		DirAccess.remove_absolute(SETTINGS_PATH)
	print("  [custody] user:// files restored")


func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

# ── A. play-time accounting ─────────────────────────────────────────

## A non-zero base so the formatter check below has real hours to render, and so
## the "int stayed int" check is about the accounting rather than about zero.
const BASE_SECONDS: int = 7200

func _run_play_time() -> void:
	print("")
	print("── A. play-time accounting ──────────────────────────────")

	# Settle first: the un-measured stretch since _ready() belongs to the session,
	# not to the loop, and banking it here keeps it out of the drift figure.
	SaveManager.save_now()
	SaveManager.player_data["total_play_time"] = BASE_SECONDS

	var wall_start := Time.get_unix_time_from_system()
	for _i in CALLS:
		# The production path, not the private helper: save_now() is what the close
		# request and the Android pause branch both call, and it is what a
		# save-heavy session runs over and over.
		SaveManager.save_now()
	var wall_elapsed := Time.get_unix_time_from_system() - wall_start
	var banked := float(SaveManager.player_data["total_play_time"]) - float(BASE_SECONDS)

	_check("%d saves in one frame did not invent play time" % CALLS,
		banked <= wall_elapsed + DRIFT_TOLERANCE,
		("banked %.2fs of play time across a %.2fs real interval (tolerance %.1fs)"
			+ " — truncating session_start_time re-bases the clock at floor(now)"
			+ " and re-charges frac(now) on every single save")
			% [banked, wall_elapsed, DRIFT_TOLERANCE])

	_check("total_play_time is still an int after the saves",
		typeof(SaveManager.player_data["total_play_time"]) == TYPE_INT,
		("type is %s — `int += float` retypes the field, and"
			+ " get_play_time_formatted()'s `total %% 3600` is integer-only modulo")
			% type_string(typeof(SaveManager.player_data["total_play_time"])))

	# The formatter, called on whatever the accounting actually left behind.
	var total := int(SaveManager.get_total_play_time())
	var expected := "%dh %dm" % [total / 3600, (total % 3600) / 60]
	var formatted := SaveManager.get_play_time_formatted()
	_check("get_play_time_formatted() renders the accumulated total",
		formatted == expected,
		"got \"%s\", expected \"%s\" for %d s" % [formatted, expected, total])


func _run_play_time_control() -> void:
	# The other side of the drift check: time that DID pass must still be counted,
	# so a fix that simply stops accumulating cannot pass this harness.
	var before := int(SaveManager.get_total_play_time())
	SaveManager.save_now()
	var after := int(SaveManager.get_total_play_time())
	_check("control: a real %.1fs wait was banked" % REAL_WAIT,
		after - before >= 2,
		"%d s banked over a %.1f s wait (before=%d after=%d)"
			% [after - before, REAL_WAIT, before, after])

# ── B. load-time trust boundary ─────────────────────────────────────

## Wrong-typed where a container is expected, but WELL-FORMED in every field that
## follows it. That ordering is the whole point: the member vars are statically
## typed, so the bad assignment raises a runtime error that aborts _merge_data()
## and the valid fields below it are what get silently dropped.
##
## A truncated write is a different (already-handled) case: it fails json.parse and
## the load is skipped whole.
func _hostile_save() -> Dictionary:
	return {
		"save_version": 1,
		"player": {"water_droplets": 5, "games_played": 3, "total_play_time": 60},
		"high_scores": [],                                  # <- Array, aborts here
		"sp_session_scores": [10, 20],                      # valid, must survive
		"unlocked": {"characters": ["droppy_blue", "droppy_green"]},
		"achievements": {"first_drop": {"unlocked": true}}   # valid, must survive
	}


## Sentinels the hostile file must overwrite. Without this the real user save loaded
## during SaveManager._ready() would still be in memory and every "did it load"
## check below could pass on residue.
func _plant_sentinels() -> void:
	SaveManager.high_scores = {}
	SaveManager.sp_session_scores = []
	SaveManager.unlocked_content["characters"] = []
	SaveManager.achievements["first_drop"]["unlocked"] = false
	SaveManager.player_data["water_droplets"] = 0
	SaveManager.player_data["total_play_time"] = 0


func _run_hostile_load() -> void:
	print("")
	print("── B. one wrong-typed field must not drop the rest ──────")
	_plant_sentinels()
	_write_save(_hostile_save())
	SaveManager.load_all_data()

	# Merged BEFORE the bad field — this one always loaded, and it is the control
	# that proves the file was read at all.
	_check("control: the save was read (player_data merged)",
		int(SaveManager.player_data.get("water_droplets", -1)) == 5,
		"water_droplets = %s" % str(SaveManager.player_data.get("water_droplets")))

	_check("high_scores stayed a usable Dictionary",
		typeof(SaveManager.high_scores) == TYPE_DICTIONARY,
		"type is %s" % type_string(typeof(SaveManager.high_scores)))

	# Everything below is declared AFTER high_scores in _merge_data.
	_check("sp_session_scores loaded despite the bad field above it",
		SaveManager.get_sp_session_high_score() == 20,
		"scores = %s" % str(SaveManager.sp_session_scores))
	_check("unlocked content loaded despite the bad field above it",
		SaveManager.unlocked_content.get("characters", []).size() == 2,
		"characters = %s" % str(SaveManager.unlocked_content.get("characters")))
	_check("achievements loaded despite the bad field above it",
		SaveManager.is_achievement_unlocked("first_drop"),
		"first_drop = %s" % str(SaveManager.achievements.get("first_drop")))

	# JSON has one number type: 60 comes back as 60.0, and total_play_time feeds an
	# integer modulo in get_play_time_formatted().
	_check("integer player fields came back as ints, not JSON floats",
		typeof(SaveManager.player_data.get("total_play_time")) == TYPE_INT
			and typeof(SaveManager.player_data.get("games_played")) == TYPE_INT,
		"total_play_time=%s games_played=%s"
			% [type_string(typeof(SaveManager.player_data.get("total_play_time"))),
				type_string(typeof(SaveManager.player_data.get("games_played")))])

	# The consequence for gameplay: on an Array base `high_scores[game_id] = {...}`
	# aborts record_game_result(), so a finished game stops being recorded.
	SaveManager.record_game_result("harness_probe", 10, 0.5, 3.0)
	var rec: Dictionary = SaveManager.get_high_score("harness_probe")
	_check("record_game_result() still records after the hostile load",
		int(rec.get("score", -1)) == 10,
		"stored record = %s" % str(rec))


## The other abort site: achievements is the last field merged, so a scalar there
## takes the accessory/decoration back-fill down with it and leaves player_data
## without the keys the character screen reads.
func _run_hostile_achievement() -> void:
	print("")
	print("── B2. a scalar achievement must not skip the back-fill ─")
	SaveManager.player_data.erase("selected_accessory")
	SaveManager.unlocked_content.erase("accessories")
	_write_save({
		"save_version": 1,
		"player": {"water_droplets": 8},
		"achievements": {"first_drop": 7}  # scalar where an entry Dictionary belongs
	})
	SaveManager.load_all_data()

	_check("control: the save was read (player_data merged)",
		int(SaveManager.player_data.get("water_droplets", -1)) == 8,
		"water_droplets = %s" % str(SaveManager.player_data.get("water_droplets")))
	_check("the scalar left the achievement entry intact",
		typeof(SaveManager.achievements.get("first_drop")) == TYPE_DICTIONARY,
		"entry = %s" % str(SaveManager.achievements.get("first_drop")))
	_check("the accessory back-fill still ran after the bad entry",
		SaveManager.player_data.has("selected_accessory")
			and SaveManager.unlocked_content.has("accessories"),
		"selected_accessory=%s accessories=%s"
			% [str(SaveManager.player_data.get("selected_accessory")),
				str(SaveManager.unlocked_content.get("accessories"))])


func _run_good_load() -> void:
	print("")
	print("── B control: a well-formed save must survive intact ────")
	_write_save({
		"save_version": 1,
		"player": {"water_droplets": 42, "games_played": 9, "total_play_time": 123},
		"high_scores": {"catch_rain": {
			"score": 555, "accuracy": 0.9, "best_time": 12.0, "times_played": 4
		}},
		"sp_session_scores": [10, 20],
		"unlocked": {"characters": ["droppy_blue", "droppy_green"]},
		"achievements": {"first_drop": {"unlocked": true}}
	})
	SaveManager.load_all_data()

	var rec: Dictionary = SaveManager.get_high_score("catch_rain")
	_check("control: a valid high score loaded",
		int(rec.get("score", -1)) == 555 and int(rec.get("times_played", -1)) == 4,
		"record = %s" % str(rec))
	_check("control: valid sp_session_scores loaded",
		SaveManager.get_sp_session_high_score() == 20,
		"scores = %s" % str(SaveManager.sp_session_scores))
	_check("control: a valid unlocked achievement loaded",
		SaveManager.is_achievement_unlocked("first_drop"))
	_check("control: valid player_data loaded",
		int(SaveManager.player_data.get("water_droplets", -1)) == 42
			and int(SaveManager.player_data.get("games_played", -1)) == 9,
		"droplets=%s games=%s" % [str(SaveManager.player_data.get("water_droplets")),
			str(SaveManager.player_data.get("games_played"))])


## Language has exactly one owner.
##
## SaveManager.settings used to declare its own "language": "en" alongside
## Localization's user://settings.cfg, and nothing read or updated it: a build
## running in Filipino still wrote "language": "en" into waterwise_settings.json,
## so the human-readable artifact a thesis reviewer opens contradicted the game.
## Asserted at the source, because the stale key survives in existing save files
## (_load_settings copies unknown keys in verbatim) and so cannot be asserted away
## at runtime -- what must stay true is that no NEW install grows a second store
## and no call site reads one.
func _run_language_ownership() -> void:
	print("\n── language ownership ──")
	var src: String = FileAccess.get_file_as_string("res://autoload/SaveManager.gd")
	var in_defaults: bool = false
	var declared: int = 0
	for line in src.split("\n"):
		var code: String = line.strip_edges()
		if code.begins_with("var settings: Dictionary = {"):
			in_defaults = true
			continue
		if in_defaults:
			if code == "}":
				in_defaults = false
			elif code.begins_with("\"language\""):
				declared += 1
	_check("SaveManager declares no second language setting", declared == 0,
		"%d declaration(s) inside var settings" % declared)
	# And nobody asks SaveManager for it. get_setting("language") would read whatever
	# stale value an old save file carried, which is the failure this guards.
	var readers: PackedStringArray = []
	for dir in ["res://autoload", "res://scenes", "res://scripts"]:
		for f in _gd_under(dir):
			var body: String = FileAccess.get_file_as_string(f)
			if body.contains("get_setting(\"language\")") \
					or body.contains("set_setting(\"language\""):
				readers.append(String(f).get_file())
	_check("no call site reads language out of SaveManager", readers.is_empty(),
		"%d site(s): %s" % [readers.size(), ", ".join(readers)])
	# The owner still works: the enum round-trips through user://settings.cfg.
	var before: int = int(Localization.current_language)
	var other: int = 1 - before
	Localization.set_language(other)
	var cfg := ConfigFile.new()
	var ok: int = cfg.load("user://settings.cfg")
	var persisted: int = int(cfg.get_value("Settings", "language", -1)) if ok == OK else -1
	Localization.set_language(before)
	_check("Localization persists the language it was given", persisted == other,
		"wrote %d, settings.cfg holds %d" % [other, persisted])


## Every .gd under one directory, recursively. Kept local so this harness does not
## depend on another tool's sweeper.
func _gd_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var p: String = dir.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_under(p))
		elif name.ends_with(".gd"):
			out.append(p)
		name = d.get_next()
	d.list_dir_end()
	return out
# ── entry point ─────────────────────────────────────────────────────

func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  SAVEMANAGER PLAY-TIME + LOAD-TRUST HARNESS")
	print("═══════════════════════════════════════════════════════════")
	_backup_user_files()
	_run_play_time()
	await get_tree().create_timer(REAL_WAIT).timeout
	_run_play_time_control()
	_run_hostile_load()
	_run_hostile_achievement()
	_run_good_load()
	_run_language_ownership()
	_finish()
