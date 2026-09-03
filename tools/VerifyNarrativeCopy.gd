extends Node

## Does every game in the roster actually have readable, funny, non-bare copy?
##
## WHAT THIS IS FOR
##   The brief asks for short funny readable reactions instead of a bare "FAILED",
##   plus an educational point that survives the joke. Three separate tables feed
##   what the player reads at the end of a round, keyed by game:
##     * MiniGameBase._get_narratives()          intro / win / fail prose
##     * MiniGameBase._get_failure_cutscene_presets()  the icon + one-line reaction
##     * the tally screen, which shows _narrative(key, "fail") CUT AT THE FIRST ". "
##   Nothing checks that a game has an entry. A game added to the roster without one
##   silently falls back to "Mission failed. Retry incoming!" -- which is exactly the
##   bare verdict the brief says to remove, and it is invisible from the outside
##   because it looks like intentional copy.
##
## WHAT IS ASSERTED, for all 24 roster keys
##   [1] a narrative entry exists at all
##   [2] intro / win / fail are all present and non-empty
##   [3] the fail line is a reaction, not a verdict: it is not one of the bare
##       phrases, and it is long enough to carry an image
##   [4] the FIRST SENTENCE -- the only part the tally screen shows -- fits the
##       banner, because everything after the first ". " is dropped on the floor
##   [5] a failure-cutscene preset exists, so the reaction has an icon and a beat
##   [6] the localization keys these lines resolve through are either absent
##       (English fallback, fine) or non-empty in BOTH languages (a key present but
##       blank renders as an empty banner -- see the localized-key shadowing case)
##
## Usage:
##   godot --headless --path . res://tools/VerifyNarrativeCopy.tscn

const PROBE: String = "res://scenes/minigames/WaterMemory.tscn"
## The tally banner is one line of Cubao at 34 px inside a panel that is 0.86 of a
## 1080 px-wide design width; past ~92 characters it wraps to a third line and the
## panel clips it. Measured against the widest existing line rather than guessed.
const MAX_FIRST_SENTENCE: int = 92
## Below this a "reaction" is a verdict with a smiley on it.
const MIN_FAIL_CHARS: int = 24
const BARE: Array = [
	"failed", "fail", "you failed", "game over", "time's up", "times up",
	"you lose", "lose", "mission failed", "mission failed. retry incoming!",
	"try again", "oops", "nope",
]

var _pass: int = 0
var _fail: int = 0


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



## Every .gd under the given roots (a root may itself be a file).
func _all_gd(roots: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for r in roots:
		var rs: String = str(r)
		if rs.ends_with(".gd"):
			out.append(rs)
			continue
		var d := DirAccess.open(rs)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if d.current_is_dir():
				if not f.begins_with("."):
					out.append_array(_all_gd([rs.path_join(f)]))
			elif f.ends_with(".gd"):
				out.append(rs.path_join(f))
			f = d.get_next()
		d.list_dir_end()
	return out

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n=== VerifyNarrativeCopy ===")
	await _frames(10)

	var roster: Array = GameManager.ALL_SINGLEPLAYER_MINIGAMES
	_check("[0] roster reachable", roster.size() >= 20, "%d game(s)" % roster.size())

	# A live MiniGameBase instance, because _get_narratives() and the preset table are
	# instance methods and the tally reads them through _narrative()/_loc(), which go
	# through Localization. A bare .new() would skip the scene setup those rely on.
	var probe: Node = (load(PROBE) as PackedScene).instantiate()
	get_tree().root.add_child(probe)
	await _frames(20)
	if not probe.has_method("_narrative"):
		_check("[0b] probe exposes the copy tables", false,
			"WaterMemory did not load as a MiniGameBase (parse error?)")
		print("\n=== %d passed, %d failed ===" % [_pass, _fail])
		get_tree().quit(1)
		return

	var narr: Dictionary = probe.call("_get_narratives")
	var presets: Dictionary = probe.call("_get_failure_cutscene_presets")

	var missing: PackedStringArray = []
	var incomplete: PackedStringArray = []
	var bare: PackedStringArray = []
	var overlong: PackedStringArray = []
	var no_preset: PackedStringArray = []
	for key in roster:
		var k: String = str(key)
		if not narr.has(k):
			missing.append(k)
			continue
		var entry: Dictionary = narr[k]
		var fields: PackedStringArray = []
		for field in ["intro", "win", "fail"]:
			if str(entry.get(field, "")).strip_edges().is_empty():
				fields.append(field)
		if not fields.is_empty():
			incomplete.append("%s(%s)" % [k, ", ".join(fields)])
		var fail_line: String = str(entry.get("fail", "")).strip_edges()
		if not fail_line.is_empty():
			if BARE.has(fail_line.to_lower().trim_suffix(".")) \
					or fail_line.length() < MIN_FAIL_CHARS:
				bare.append("%s: \"%s\"" % [k, fail_line])
			# Only the first sentence survives _get_failure_cutscene_data().
			var dot: int = fail_line.find(". ")
			var shown: String = fail_line.left(dot) if dot > 0 else fail_line
			if shown.length() > MAX_FIRST_SENTENCE:
				overlong.append("%s: %d chars" % [k, shown.length()])
		if not presets.has(k):
			no_preset.append(k)

	_check("[1] every roster game has narrative copy", missing.is_empty(),
		"%d without an entry: %s" % [missing.size(), ", ".join(missing)])
	_check("[2] intro/win/fail all present", incomplete.is_empty(),
		"%d incomplete: %s" % [incomplete.size(), ", ".join(incomplete)])
	_check("[3] no fail line is a bare verdict", bare.is_empty(),
		"%d bare: %s" % [bare.size(), ", ".join(bare)])
	_check("[4] the shown first sentence fits the banner", overlong.is_empty(),
		"%d over %d chars: %s" % [overlong.size(), MAX_FIRST_SENTENCE, ", ".join(overlong)])
	_check("[5] every roster game has a failure-reaction preset", no_preset.is_empty(),
		"%d without a preset: %s" % [no_preset.size(), ", ".join(no_preset)])

	# [6] the localization side. _loc() falls back to English when the key is absent,
	# which is fine and normal; what is NOT fine is a key that exists and resolves to
	# an empty string, because then the banner renders blank in that language and the
	# English fallback never gets a chance. Checked in both languages by actually
	# switching Localization, since a key can be shadowed per-locale.
	# Both languages, by enum value: set_language() is typed to Localization.Language,
	# so a String argument is a parse error rather than a runtime one.
	var blank: PackedStringArray = []
	var langs: Array = [Localization.Language.ENGLISH, Localization.Language.FILIPINO]
	var original: int = int(Localization.current_language) if Localization else 0
	for lang in langs:
		if Localization:
			Localization.set_language(lang)
			await _frames(2)
		for key in roster:
			var k: String = str(key)
			if not narr.has(k):
				continue
			for field in ["intro", "win", "fail"]:
				var en: String = str((narr[k] as Dictionary).get(field, ""))
				if en.is_empty():
					continue
				var loc_key: String = "narrative_%s_%s" % [k.to_snake_case(), field]
				if Localization == null or not Localization.has_text(loc_key):
					continue  # absent key = English fallback = intended
				if str(Localization.get_text(loc_key)).strip_edges().is_empty():
					blank.append("%s/%s [%s]" % [k, field, lang])
	if Localization and Localization.has_method("set_language"):
		Localization.set_language(original)
		await _frames(2)
	_check("[6] no localized narrative key resolves to blank", blank.is_empty(),
		"%d blank: %s" % [blank.size(), ", ".join(blank)])

	# [7] the bare verdict, swept. The brief replaces "FAILED"/"GAME OVER" with a short
	# funny reaction, and the tables above now cover all 24 games -- but a fossil screen
	# builder that still spells it out is one call away from undoing that.
	# MiniGameBase._show_game_over() was exactly that: unreachable, an 80 px red
	# "GAME OVER!", and removed. This keeps it removed.
	var shouty: PackedStringArray = []
	for f in _all_gd(["res://scenes/minigames", "res://scripts/minigames_v2",
			"res://scripts/MiniGameBase.gd"]):
		var ln: int = 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			ln += 1
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue
			# A console line is not screen text: RainwaterHarvesting prints
			# "TEAM RESULT: FAILED" to stdout for the log, which no player reads.
			if code.begins_with("print(") or code.begins_with("_log(") \
					or code.begins_with("push_"):
				continue
			for phrase in ["GAME OVER!", "FAILED!", "YOU LOSE", "\"FAILED\""]:
				if code.contains(phrase):
					shouty.append("%s:%d %s" % [String(f).get_file(), ln, phrase])
	_check("[7] no bare-verdict screen text in the singleplayer path",
		shouty.is_empty(), "%d site(s): %s" % [shouty.size(), ", ".join(shouty)])


	# [8] the path the screen actually reads, end to end, for one of the three games that
	# had no preset. _get_failure_cutscene_data() keys off the probe's OWN script, so
	# WaterMemory answers for itself: the icon and animation must now be its own, and the
	# line must be the narrative reaction cut at the first sentence -- not the generic
	# "Mission failed. Retry incoming!" fallback.
	var fcd: Dictionary = probe.call("_get_failure_cutscene_data")
	# The expectation has to come from the LOCALIZED narrative, not from the hardcoded
	# English table. _narrative() reads narrative_<key>_<field> and falls back to the
	# table, so comparing against the table alone only holds while the run boots in
	# English -- and the boot language comes from user://settings.cfg, which the identity
	# soak leaves on Filipino. That is how this check passed for two windows and then
	# failed without the product changing: it was asserting a save-state coincidence.
	const WM_FAIL_KEY: String = "narrative_water_memory_fail"
	var want_raw: String = str((narr.get("WaterMemory", {}) as Dictionary).get("fail", ""))
	var localized: bool = Localization != null and Localization.has_text(WM_FAIL_KEY)
	if localized:
		want_raw = Localization.get_text(WM_FAIL_KEY)
	var want_line: String = want_raw
	var dot_i: int = want_line.find(". ")
	if dot_i > 0:
		want_line = want_line.left(dot_i)
	_check("[8] WaterMemory's failure beat reads its own icon, motion and line",
		str(fcd.get("icon", "")) == "🃏" and str(fcd.get("anim", "")) == "shake"
			and str(fcd.get("line", "")) == want_line,
		"icon=%s anim=%s line=\"%s\" (want \"%s\" from %s, lang=%s)"
			% [str(fcd.get("icon", "")), str(fcd.get("anim", "")),
			str(fcd.get("line", "")), want_line,
			"Localization" if localized else "the English table",
			str(Localization.current_language) if Localization else "?"])

	# [9] the objective itself, for all 24 games in both languages. The brief's first
	# pillar is a clear objective, and for a microgame collection that is ONE line, not a
	# three-step tutorial (only 8 games have an authored tutorial and adding 16 more would
	# fight the "short and fast" pillar). What must hold is that the line exists, says
	# what to DO, and says it in whichever language is set: MiniGameBase defaults
	# game_instruction_text to "TAP TO START!", which states no objective at all, so a
	# game that forgets to set it fails open and looks deliberate.
	# The list is the harness's own vocabulary, not a project rule: an entry missing
	# here is a false positive, so it covers every imperative the 24 games and both
	# locales actually use. Checked against the failing run that seeded it.
	const VERBS: Array = ["TAP", "HOLD", "SWIPE", "DRAG", "TILT", "MOVE", "SHAKE",
		"PRESS", "CATCH", "FIX", "PATCH", "DRAW", "TRACE", "RUB", "SCRUB", "PASS",
		"MATCH", "FOLLOW", "POUR", "FILL", "STOP", "CHECK", "COVER", "CLOSE", "SORT",
		"WRING", "RINSE", "PLUG", "TURN", "KEEP", "COLLECT", "AVOID", "RELEASE",
		"I-TAP", "IGALAW", "HAWAKAN", "PINDUTIN", "IWASAN", "PUNUIN", "I-DRAG",
		"HILAHIN", "SALUHIN", "AYUSIN", "TAKPAN", "PILIIN", "LINISIN", "BUKSAN",
		"ISARA", "IHULOG", "IPASA", "KUSKUSIN", "PIGAIN", "BANLAWAN", "SUNDAN",
		"IPARES", "TAPALAN", "TINGNAN", "PANATILIHIN", "PIGILAN", "BUHUSAN",
		"HALUIN", "DILIGAN", "I-SLIDE", "PIGA"]
	var no_line: PackedStringArray = []
	var default_line: PackedStringArray = []
	var no_verb: PackedStringArray = []
	# game -> {"en": text, "tl": text}. [9d] reads this: an instruction that is
	# byte-identical in both locales is hardcoded English, which is how four v2 games
	# and four legacy ones shipped an untranslated banner under a translated title.
	var by_lang: Dictionary = {}
	# game -> {"en": title, "tl": title} and the same for the resolved minigame theme
	# id. [10] and [11] read these: the HUD title must FOLLOW the language while the
	# theme the title feeds into must NOT, because ThemeManager resolves the theme by
	# substring-matching that same string (MiniGameBase._build_theme_lookup_text).
	var title_by_lang: Dictionary = {}
	var theme_by_lang: Dictionary = {}
	var rendered: int = 0
	var not_rendered: PackedStringArray = []
	for lang2 in [Localization.Language.ENGLISH, Localization.Language.FILIPINO]:
		Localization.set_language(lang2)
		await _frames(2)
		for key in roster:
			var k2: String = str(key)
			var p2: String = "res://scenes/minigames/%s.tscn" % k2
			if not ResourceLoader.exists(p2):
				no_line.append("%s (no scene)" % k2)
				continue
			var g2: Node = (load(p2) as PackedScene).instantiate()
			get_tree().root.add_child(g2)
			await _frames(6)
			var txt: String = str(g2.get("game_instruction_text")).strip_edges()
			var tag: String = "%s[%s]" % [k2, "en" if lang2 == Localization.Language.ENGLISH else "tl"]
			# [9e] does the line reach the SCREEN? MiniGameBase builds the intro overlay's
			# instruction Label with Label.new() and never names it, so match on the text:
			# a Label carrying this exact string proves the property was rendered and not
			# just assigned. Counted, not asserted per game, because a game whose intro is
			# routed through the cutscene bridge has no overlay to find at this point.
			if not txt.is_empty() and _has_label_with(g2, txt):
				rendered += 1
			else:
				not_rendered.append(tag)
			var lcode: String = "en" if lang2 == Localization.Language.ENGLISH else "tl"
			if not by_lang.has(k2):
				by_lang[k2] = {}
			(by_lang[k2] as Dictionary)[lcode] = txt
			# The title as the HUD would show it, plus the theme id the SAME string resolves
			# to. Resolved through the game's own _build_theme_lookup_text() rather than a
			# copy of it, because [11] is a claim about what ThemeManager really returns in
			# play, not about a rule restated in the harness.
			if not title_by_lang.has(k2):
				title_by_lang[k2] = {}
				theme_by_lang[k2] = {}
			(title_by_lang[k2] as Dictionary)[lcode] = str(g2.get("game_name")).strip_edges()
			var lookup: String = ""
			if g2.has_method("_build_theme_lookup_text"):
				lookup = str(g2.call("_build_theme_lookup_text"))
			var tid: String = "?"
			if ThemeManager and ThemeManager.has_method("get_minigame_theme_id_for_name"):
				tid = str(ThemeManager.get_minigame_theme_id_for_name(lookup))
			(theme_by_lang[k2] as Dictionary)[lcode] = tid
			if txt.is_empty():
				no_line.append(tag)
			elif txt == "TAP TO START!":
				default_line.append(tag)
			else:
				var upper: String = txt.to_upper()
				var found: bool = false
				for v in VERBS:
					if upper.contains(str(v)):
						found = true
						break
				if not found:
					no_verb.append("%s: \"%s\"" % [tag, txt.replace("\n", " / ")])
			# Detach, let the parked coroutine notice, then free.
			#
			# The round is still blocked on the instruction overlay here, so
			# MiniGameBase._wait_for_input() is parked on `await get_tree().process_frame`. Freeing
			# the node destroys the tree connection that would have resumed it, and the orphaned
			# GDScriptFunctionState is never released - one per game instantiated, named by
			# `Orphan StringName: _wait_for_input` in a --verbose exit dump. Detaching first and
			# spending one frame lets the loop resume, see is_inside_tree() go false and return.
			get_tree().root.remove_child(g2)
			await _frames(1)
			g2.free()
	Localization.set_language(original)
	await _frames(2)
	_check("[9a] every game states an objective", no_line.is_empty(),
		"%d empty: %s" % [no_line.size(), ", ".join(no_line)])
	_check("[9b] no game falls back to the base default", default_line.is_empty(),
		"%d on \"TAP TO START!\": %s" % [default_line.size(), ", ".join(default_line)])
	_check("[9c] every objective names an action", no_verb.is_empty(),
		"%d without a verb: %s" % [no_verb.size(), ", ".join(no_verb)])
	# [9d] the instruction must actually follow the language. A hardcoded English
	# literal passes [9a]-[9c] perfectly — it exists, it is not the base default and it
	# names an action — while a Filipino player reads an English banner under a
	# translated title. Byte-equality across the two locales is the discriminator, and
	# no game in the roster legitimately renders the same instruction in both.
	var untranslated: PackedStringArray = []
	for k3 in by_lang:
		var pair: Dictionary = by_lang[k3]
		if not (pair.has("en") and pair.has("tl")):
			continue
		if str(pair["en"]) == str(pair["tl"]):
			untranslated.append("%s: \"%s\"" % [str(k3), str(pair["en"]).replace("\n", " / ")])
	_check("[9d] every objective changes with the language", untranslated.is_empty(),
		"%d identical in en and tl: %s" % [untranslated.size(), ", ".join(untranslated)])
	# Measured at 48/48 (24 games x 2 locales), so this is an equality, not a floor:
	# every game builds the intro overlay and the Label really carries the instruction,
	# which is what makes [9a]-[9d] statements about text a player can read rather than
	# about a property nobody displays. Expected count comes from the roster so adding
	# a 25th game does not silently lower the bar.
	var want_rendered: int = roster.size() * 2
	_check("[9e] the objective reaches the intro overlay", rendered == want_rendered,
		"%d/%d rendered; %d without a matching Label: %s"
			 % [rendered, want_rendered, not_rendered.size(), ", ".join(not_rendered)])
	# [10] the HUD title must follow the language too. FIX 58 translated the objective
	# banner and left the title alone, so a Filipino player read "TIMING TAP" above
	# "I-HOLD para punuin ang lalagyan!". Byte-equality across locales is the same
	# discriminator [9d] uses, and no roster title is legitimately identical in both.
	var same_title: PackedStringArray = []
	var missing_title: PackedStringArray = []
	for k4 in title_by_lang:
		var tp: Dictionary = title_by_lang[k4]
		if not (tp.has("en") and tp.has("tl")):
			continue
		var ten: String = str(tp["en"])
		var ttl: String = str(tp["tl"])
		if ten.is_empty() or ttl.is_empty():
			missing_title.append(str(k4))
		elif ten == ttl:
			same_title.append("%s: \"%s\"" % [str(k4), ten])
	_check("[10] every title changes with the language",
		same_title.is_empty() and missing_title.is_empty(),
		"%d identical in en and tl: %s%s" % [same_title.size(), ", ".join(same_title),
			("" if missing_title.is_empty() else "; %d with an empty title: %s"
				% [missing_title.size(), ", ".join(missing_title)])])
	# [11] and the theme must NOT. ThemeManager.get_minigame_theme_id_for_name matches
	# keywords by substring against game_name + scene basename, and its buckets are
	# ordered, so a translated title that happens to contain an EARLIER bucket's keyword
	# would repaint the game a different colour in Filipino only. The scene basename in
	# the lookup text is what keeps this stable -- this asserts it stayed that way.
	var theme_drift: PackedStringArray = []
	for k5 in theme_by_lang:
		var hp: Dictionary = theme_by_lang[k5]
		if not (hp.has("en") and hp.has("tl")):
			continue
		if str(hp["en"]) != str(hp["tl"]):
			theme_drift.append("%s: en=%s tl=%s" % [str(k5), str(hp["en"]), str(hp["tl"])])
	_check("[11] the minigame theme does NOT change with the language",
		theme_drift.is_empty(),
		"%d drifted: %s" % [theme_drift.size(), ", ".join(theme_drift)])
	# Detach and spend a frame before freeing, so the parked _wait_for_input() coroutine can return.
	get_tree().root.remove_child(probe)
	await _frames(1)
	probe.free()
	await _frames(3)
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## True if any Label under root carries exactly this text. Used by [9e]: the intro
## overlay's instruction Label is created with Label.new() and left unnamed, so the
## text is the only handle on it.
func _has_label_with(root: Node, want: String) -> bool:
	for c in root.get_children():
		if c is Label and str((c as Label).text).strip_edges() == want:
			return true
		if _has_label_with(c, want):
			return true
	return false
