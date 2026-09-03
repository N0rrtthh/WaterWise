extends Node

## Does a headless process leave the player's auto-play preferences alone?
##
## This gate exists because of a measured incident, not a hypothetical. A 72-harness suite
## run ended with seven harnesses reporting failures they did not have: tools/VerifyGameIdentity
## enabled the shipped bot through set_auto_play_enabled(true) - taking the persisting default -
## and then hit its own 240 s timeout, so the restore in its report_and_quit() never ran. The
## flag stayed true inside user://waterwise_settings.json, and the 38 harnesses that booted
## after it (alphabetically from VerifyGlyphCoverage on) all started with AutoNav playing the
## game underneath the thing they were measuring. Whatever they concluded was about the bot.
##
## The fix is not "remember to pass persist=false". It is AutoPlayManager._may_persist(),
## which refuses the write when DisplayServer is headless, because a headless process is
## never a player. This harness deliberately makes the original mistake - the persisting
## default, plus set_auto_play_duration(), which never had a persist argument at all - and
## asserts the settings file does not move while the in-memory flags still do (a harness has
## to be able to switch the bot on; that part must keep working).
##
## Run: Godot_v4.7.2 --headless --path . tools/VerifySettingsLeak.tscn

const SETTINGS_PATH := "user://waterwise_settings.json"

var _pass := 0
var _fail := 0
var _original: PackedByteArray = PackedByteArray()

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s%s" % [label, "   " + detail if detail != "" else ""])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "   " + detail if detail != "" else ""])

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _file_md5() -> String:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return "<absent>"
	return FileAccess.get_md5(SETTINGS_PATH)

func _disk_value(key: String) -> Variant:
	# Read the FILE, not SaveManager's in-memory dictionary: set_setting() updates that
	# dictionary before it ever decides whether to write, so asking SaveManager would
	# report the write as having happened even when the guard refused it.
	if not FileAccess.file_exists(SETTINGS_PATH):
		return null
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return (parsed as Dictionary).get(key, null)

func _ready() -> void:
	await _frames(2)
	print("\n=== SETTINGS LEAK: can a headless run rewrite the player's preferences? ===")

	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm == null:
		print("  REFUSING: AutoPlayManager is not in the tree.")
		get_tree().quit(2)
		return

	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		_original = f.get_buffer(f.get_length())
		f.close()

	var driver := DisplayServer.get_name()
	_check("this really is a headless process", driver == "headless",
		"DisplayServer = %s" % driver)
	if apm.has_method("_may_persist"):
		_check("_may_persist() refuses here", not apm._may_persist(), "the guard is armed")
	else:
		_check("AutoPlayManager exposes _may_persist()", false, "guard missing entirely")

	var before_md5 := _file_md5()
	var before_flag: Variant = _disk_value("auto_play_enabled")
	var before_dur: Variant = _disk_value("auto_play_duration")
	print("  on disk before: enabled=%s duration=%s md5=%s"
		% [str(before_flag), str(before_dur), before_md5])

	# The original mistake, verbatim: the persisting default.
	apm.set_auto_play_enabled(true)
	await _frames(2)
	_check("the in-memory flag still flips, so harnesses keep working",
		bool(apm.auto_play_enabled) == true, "auto_play_enabled=true in memory")
	_check("but the flag did NOT reach the settings file",
		_disk_value("auto_play_enabled") == before_flag,
		"on disk: %s (was %s)" % [str(_disk_value("auto_play_enabled")), str(before_flag)])

	# set_auto_play_duration() never had a persist argument at all, so the guard is the
	# only thing standing between a harness and the player's 8-minute leftover.
	if apm.has_method("set_auto_play_duration"):
		apm.set_auto_play_duration(9.0)
		await _frames(2)
		_check("the in-memory duration still changes",
			abs(float(apm.auto_play_duration) - 540.0) < 0.01,
			"auto_play_duration=%.1f s in memory" % float(apm.auto_play_duration))
		_check("but the duration did NOT reach the settings file",
			_disk_value("auto_play_duration") == before_dur,
			"on disk: %s (was %s)" % [str(_disk_value("auto_play_duration")), str(before_dur)])

	# A hard save is the other way the flag could travel: it writes the whole settings
	# dictionary, which set_setting() has already been allowed to update in memory.
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("_save_settings"):
		# _save_settings() is the private writer set_setting() itself calls. Reaching for it
		# directly is the point: it proves the guard also keeps the in-memory settings
		# dictionary clean, so the next legitimate write (a language change, say) cannot
		# carry the bot's state to disk as a passenger.
		sm._save_settings()
		await _frames(2)
		_check("an explicit settings write still does not publish the bot's state",
			_disk_value("auto_play_enabled") == before_flag
			and _disk_value("auto_play_duration") == before_dur,
			"enabled=%s duration=%s" % [str(_disk_value("auto_play_enabled")),
				str(_disk_value("auto_play_duration"))])

	_check("the settings file is byte-identical after all of it",
		_file_md5() == before_md5, "%s vs %s" % [_file_md5(), before_md5])

	# Leave the process the way a well-behaved harness would.
	apm.set_auto_play_enabled(false, false)

	# Backstop: if anything above did get through, put the player's bytes back rather than
	# leaving this run's residue behind - including when this gate is run as a negative
	# control with the guard removed on purpose.
	if _file_md5() != before_md5 and not _original.is_empty():
		var w := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if w:
			w.store_buffer(_original)
			w.close()
		print("  (restored the original settings bytes: md5 now %s)" % _file_md5())

	print("\n  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
