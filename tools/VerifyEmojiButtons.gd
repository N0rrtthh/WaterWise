extends Node

## Do the reported emoji actually draw, on a device whose system fonts supply nothing?
##
## THE DEFECT
##   Reported as "unicode emoji render as unknown-character boxes on Android 8", with the five
##   top-right buttons of the home screen named. The glyphs were never missing -
##   fonts/NotoEmoji.ttf ships in the build and has all five. ThemeManager attached it as a
##   fallback to the two bundled DISPLAY fonts only, and those five buttons set
##   theme_override_font_sizes and no font at all, so they draw through ThemeDB.fallback_font -
##   whose fallback list was EMPTY. Godot's last resort is an operating-system font: on Windows
##   that is Segoe UI Emoji, which answers everything and hid the bug for the whole project; on
##   the Moto E5 Plus it answers with a 2017-era emoji font or with nothing, and you get the box.
##
## WHY THIS HARNESS EXISTS ALONGSIDE VerifyGlyphCoverage
##   That one probes FONT RESOURCES: it can say NotoEmoji is reachable from ThemeDB.fallback_font.
##   It cannot say the BUTTON reaches ThemeDB.fallback_font, which is the other half of the claim -
##   a scene edit adding a font override, or a theme somewhere in the middle of the tree, would
##   move these buttons onto a chain the font-level run never looked at. So this one instantiates
##   the real InitialScreen.tscn and asks each Button for the font it will draw with, through
##   get_theme_font(), the same resolution the renderer performs.
##
## WHAT IS MEASURED
##   1. the five reported buttons are still there, still carrying the reported emoji.
##   2. none of them has a font override, so the default chain really is their fix site.
##   3. every codepoint of every one of those labels resolves to a real glyph in a real font with
##      the OS step switched off - shaped as one run, the way the label is, so the U+FE0F
##      variation selectors three of them carry are seen exactly as the shaper sees them.
##   4. the same check FAILS with the fallback chain stripped back off. Without this row every
##      row above would pass on a build where the fix was reverted, because Windows would answer.
##   5. a bare Label with no font override - most of the minigames are this - reaches the emoji
##      font too, so the fix is not specific to Buttons or to this scene.
##   6. installing the fallback twice does not stack duplicate entries onto a chain the text
##      server walks on every shaped run.
##
## NOT MEASURED HERE (needs the physical device)
##   That Android 8 own font stack is what was failing. Headless-on-Windows cannot be an Android 8
##   device; it can only be a machine whose system fonts are refused, which is the honest model of
##   one. The on-device row is the five buttons showing glyphs rather than boxes.
##
## Usage:
##   godot --headless --path . res://tools/VerifyEmojiButtons.tscn

const HOME: String = "res://scenes/ui/InitialScreen.tscn"
const EMOJI_FONT_PATH: String = "res://fonts/NotoEmoji.ttf"
const PROBE_PX: int = 34

## The five buttons named in the report, with the codepoints each is authored with. Written as
## codepoints rather than pasted glyphs so the variation selectors are visible: U+FE0F is what
## asks for the emoji presentation of a character that also has a text form, and it is exactly the
## kind of thing a shaper can drop silently.
const REPORTED: Array = [
	["UI/TopRight/StoreButton", [0x1F6CD, 0xFE0F], "shopping bags"],
	["UI/TopRight/LeaderboardButton", [0x1F3C6], "trophy"],
	["UI/TopRight/RoadmapButton", [0x1F5FA, 0xFE0F], "world map"],
	["UI/TopRight/CustomizeButton", [0x1F464], "bust in silhouette"],
	["UI/TopRight/SettingsButton", [0x2699, 0xFE0F], "gear"],
]

var _pass: int = 0
var _fail: int = 0
var _home: Node = null


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


func _to_text(codepoints: Array) -> String:
	var s: String = ""
	for cp in codepoints:
		s += String.chr(int(cp))
	return s


func _hex(text: String) -> String:
	var parts: Array[String] = []
	for i in range(text.length()):
		parts.append("U+%04X" % text.unicode_at(i))
	return " ".join(parts)


## The same font with the operating system taken away and its own fallback chain left intact - the
## legacy-Android model. Recursive, because a fallback font carries the flag too.
func _offline(font: Font, depth: int = 0) -> Font:
	var p: Font = font.duplicate()
	if p is FontFile:
		(p as FontFile).allow_system_fallback = false
	elif p is SystemFont:
		(p as SystemFont).allow_system_fallback = false
	var chain: Array[Font] = []
	if depth < 4:
		for sub in font.fallbacks:
			if sub is Font:
				chain.append(_offline(sub as Font, depth + 1))
	p.fallbacks = chain
	return p


## The same font offline AND with its fallbacks thrown away: what these buttons had before the fix.
## Used only by the vacuity row.
func _offline_bare(font: Font) -> Font:
	var p: Font = font.duplicate()
	if p is FontFile:
		(p as FontFile).allow_system_fallback = false
	elif p is SystemFont:
		(p as SystemFont).allow_system_fallback = false
	p.fallbacks = [] as Array[Font]
	return p


## Which parts of `text` this font chain cannot draw. Shaped as one run, the way the label is.
##
## The signal is font_rid, not the glyph index: when nothing in the chain supplies a character
## TextServerAdvanced clears font_rid and puts the codepoint itself into `index`, so an index == 0
## test would miss the hex box entirely.
func _boxes(font: Font, text: String) -> Array[String]:
	var bad: Array[String] = []
	var tl := TextLine.new()
	tl.add_string(text, font, PROBE_PX)
	var ts := TextServerManager.get_primary_interface()
	ts.shaped_text_shape(tl.get_rid())
	var glyphs: Array = ts.shaped_text_get_glyphs(tl.get_rid())
	if glyphs.is_empty():
		bad.append("nothing shaped at all")
		return bad
	for g in glyphs:
		var rid: RID = g.get("font_rid", RID())
		var idx: int = int(g.get("index", 0))
		if not rid.is_valid():
			bad.append("U+%04X drawn as a hex box" % idx)
		elif idx == 0:
			bad.append("notdef at character %d" % int(g.get("start", -1)))
	return bad


## Which font actually answered for `text` - evidence that the glyph came from the bundled file
## rather than from somewhere unexamined.
func _supplier(font: Font, text: String) -> String:
	var tl := TextLine.new()
	tl.add_string(text, font, PROBE_PX)
	var ts := TextServerManager.get_primary_interface()
	ts.shaped_text_shape(tl.get_rid())
	for g in ts.shaped_text_get_glyphs(tl.get_rid()):
		var rid: RID = g.get("font_rid", RID())
		if rid.is_valid():
			var nm: String = ts.font_get_name(rid)
			return nm if nm != "" else "<unnamed>"
	return "<nothing>"


func _chain_names(font: Font) -> String:
	if font == null:
		return "<none>"
	var names: Array[String] = []
	for f in font.fallbacks:
		if f is Font:
			var rp: String = (f as Font).resource_path
			names.append(rp.get_file() if rp != "" else (f as Font).get_class())
	return "[%s]" % ", ".join(names)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Emoji on the five reported home-screen buttons ===")

	var tm: Node = get_node_or_null("/root/ThemeManager")
	_check("ThemeManager autoload is up (it owns the fallback wiring)", tm != null)
	var emoji_font: Font = null
	if ResourceLoader.exists(EMOJI_FONT_PATH):
		emoji_font = load(EMOJI_FONT_PATH)
	_check("the emoji font ships in the build", emoji_font != null, EMOJI_FONT_PATH)
	if emoji_font == null or tm == null:
		print("")
		print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
		get_tree().quit(1)
		return

	# The root cause stated directly: the chain a Control with no font override draws through.
	var default_font: Font = ThemeDB.fallback_font
	var default_chain: Array = default_font.fallbacks if default_font else []
	_check(
		"ThemeDB.fallback_font - what an un-overridden Control draws with - has a fallback chain",
		default_font != null and not default_chain.is_empty(),
		"chain: %s" % _chain_names(default_font)
	)
	_check(
		"the emoji font is in that chain",
		emoji_font in default_chain,
		"looking for %s in %s" % [EMOJI_FONT_PATH.get_file(), _chain_names(default_font)]
	)

	_home = load(HOME).instantiate()
	get_tree().root.add_child(_home)
	await _frames(4)

	_button_rows()
	_bare_label_row(emoji_font)
	_idempotence_row(tm, default_font)

	if _home:
		_home.queue_free()
	await _frames(2)

	print("")
	print("  -- on-device row, not measurable headless --")
	print("     The five buttons must show glyphs rather than boxes on the Moto E5 Plus. This run")
	print("     models that device as a machine whose system fonts are refused, which is the")
	print("     closest an x86 headless build can get to being one.")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## The reported buttons, one at a time: is it there, is it un-overridden, and does the chain it
## resolves to draw its label with the OS refused?
func _button_rows() -> void:
	for entry in REPORTED:
		var path: String = str(entry[0])
		var want: String = _to_text(entry[1])
		var name: String = str(entry[2])
		print("")
		print("  -- %s (%s, %s) --" % [path.get_file(), name, _hex(want)])

		var btn := _home.get_node_or_null(path) as Button
		_check("the button is still in the scene", btn != null, path)
		if btn == null:
			continue
		_check(
			"it still carries the reported emoji",
			btn.text == want,
			"text is %s (%s)" % [_hex(btn.text), btn.text]
		)
		# If a future edit gives this button its own font, the fix moves to that font and every
		# row below stops describing the shipped build - so this is asserted, not assumed.
		_check(
			"it has no font override, so the default chain is its fix site",
			not btn.has_theme_font_override("font"),
			"has_theme_font_override(font) = %s" % btn.has_theme_font_override("font")
		)

		# get_theme_font() is the renderer resolution: overrides, then themes up the tree, then the
		# default theme, then ThemeDB.fallback_font. Whatever comes back is what draws.
		var resolved: Font = btn.get_theme_font("font")
		_check("a font resolves for it at all", resolved != null)
		if resolved == null:
			continue

		var offline: Font = _offline(resolved)
		var bad: Array[String] = _boxes(offline, btn.text)
		_check(
			"its label draws with no system font available",
			bad.is_empty(),
			"supplied by %s%s" % [
				_supplier(offline, btn.text),
				"" if bad.is_empty() else "; boxes: " + ", ".join(bad)]
		)
		# Vacuity guard. Every row above passes on a reverted build too, because Segoe UI Emoji
		# answers on this machine - unless the pre-fix shape is shown to fail here.
		var bare: Array[String] = _boxes(_offline_bare(resolved), btn.text)
		_check(
			"and would NOT draw with the fallback chain removed (the pre-fix shape)",
			not bare.is_empty(),
			"with an empty chain: %s" % ("still drew - this row is vacuous" if bare.is_empty()
				else ", ".join(bare))
		)


## Not a Button, not this scene, no overrides at all: the shape most minigame labels have. If the
## fix were somehow specific to Buttons or to InitialScreen, this is the row that would say so.
func _bare_label_row(emoji_font: Font) -> void:
	print("")
	print("  -- a bare Label with nothing overridden --")
	var lbl := Label.new()
	lbl.text = _to_text([0x1F3C6]) + _to_text([0x1F4A7])
	add_child(lbl)
	var resolved: Font = lbl.get_theme_font("font")
	_check("a font resolves for a plain Label", resolved != null)
	if resolved != null:
		var offline: Font = _offline(resolved)
		var bad: Array[String] = _boxes(offline, lbl.text)
		_check(
			"a plain Label draws emoji with no system font available",
			bad.is_empty(),
			"%s supplied by %s%s" % [_hex(lbl.text), _supplier(offline, lbl.text),
				"" if bad.is_empty() else "; boxes: " + ", ".join(bad)]
		)
	lbl.queue_free()


## ThemeManager patches CACHED resources, so a second run of the installer - a harness spinning the
## autoload up again, an editor reload - would append the same font a second time and leave the text
## server walking a longer chain on every shaped run for the life of the process.
func _idempotence_row(tm: Node, default_font: Font) -> void:
	print("")
	print("  -- installing it twice --")
	var before: int = default_font.fallbacks.size()
	tm.call("_install_emoji_fallback")
	tm.call("_install_emoji_fallback")
	var after: int = default_font.fallbacks.size()
	_check(
		"installing the fallback again does not lengthen the chain",
		after == before,
		"chain length %d -> %d: %s" % [before, after, _chain_names(default_font)]
	)
	# A font must never appear twice even if the total happens to match.
	var seen: Array = []
	var dupes: Array[String] = []
	for f in default_font.fallbacks:
		if f in seen:
			dupes.append(str((f as Font).resource_path))
		seen.append(f)
	_check(
		"no font appears twice in the chain",
		dupes.is_empty(),
		"duplicates: %s" % ("none" if dupes.is_empty() else ", ".join(dupes))
	)
	# A font that is its own fallback is an infinite chain; the guard against it is cheap and the
	# consequence is not.
	var self_ref: bool = default_font in default_font.fallbacks
	_check(
		"the chain does not contain the font itself",
		not self_ref,
		"self-reference: %s" % self_ref
	)
