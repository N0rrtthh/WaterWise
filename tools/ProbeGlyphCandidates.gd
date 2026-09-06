extends Node

## Can this character be used in on-screen text at all?
##
## WHY THIS EXISTS
##   VerifyGlyphCoverage answers the question backwards: it scans the characters the game already
##   uses and reports the ones no bundled font has. That list is the residue of the Android 8 tofu
##   fix - 16 characters whose only supplier is an operating-system font, so they are boxes on a
##   device whose system fonts are old or absent. Replacing them means picking substitutes, and a
##   substitute picked by eye is exactly how the original defect got in: every emoji in this project
##   looked fine on the developer machine because Segoe UI Emoji answered for all of them.
##
##   So candidates are measured before they are written into a label. Each one is shaped through
##   ThemeDB.fallback_font - the chain a Control with no font override draws with, which is what
##   every one of these labels is - with the operating system's fonts refused.
##
## READING THE OUTPUT
##   REACHABLE means a font inside the build supplies it and the production chain finds it; safe to
##   put on screen. MISSING means it would be a hex box on the reported device, whatever it looks
##   like here.
##
## Usage:
##   godot --headless --path . res://tools/ProbeGlyphCandidates.tscn

const PROBE_PX: int = 34

## Left column: a character the game uses today that no bundled font has. Right column: the
## candidates to replace it with, best first. Bare names in the comment, since the point of the
## file is that these characters cannot be trusted to render in every editor either.
const CANDIDATES: Array = [
	["✓", ["✅", "✔"], "check mark: 8 UI sites"],
	["✗", ["❌", "✖"], "ballot x"],
	["✕", ["❌", "✖"], "multiplication x: close buttons"],
	["●", ["⚫", "•"], "black circle: page dots"],
	["○", ["⚪", "◦"], "white circle: soap bubbles"],
	["♪", ["\U01F3B5", "\U01F3B6"], "eighth note"],
	["♩", ["\U01F3B5"], "quarter note"],
	["♫", ["\U01F3B6"], "beamed notes"],
	["✦", ["✨", "⭐"], "black four-pointed star"],
	["→", ["➡"], "rightwards arrow"],
	["←", ["⬅"], "leftwards arrow"],
	["❚", ["⏸"], "heavy vertical bar: pause marker"],
]

var _reachable: int = 0
var _missing: int = 0


func _ready() -> void:
	_run.call_deferred()


## The production chain with the operating system taken away and its own fallbacks intact.
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


## font_rid, not the glyph index: when nothing in the chain supplies a character TextServerAdvanced
## clears font_rid and puts the codepoint into `index`, so an index == 0 test misses the hex box.
func _supplier_or_empty(font: Font, text: String) -> String:
	var tl := TextLine.new()
	tl.add_string(text, font, PROBE_PX)
	var ts := TextServerManager.get_primary_interface()
	ts.shaped_text_shape(tl.get_rid())
	var glyphs: Array = ts.shaped_text_get_glyphs(tl.get_rid())
	if glyphs.is_empty():
		return ""
	for g in glyphs:
		var rid: RID = g.get("font_rid", RID())
		if not rid.is_valid() or int(g.get("index", 0)) == 0:
			return ""
	for g in glyphs:
		var rid2: RID = g.get("font_rid", RID())
		if rid2.is_valid():
			var nm: String = ts.font_get_name(rid2)
			return nm if nm != "" else "<unnamed>"
	return ""


func _run() -> void:
	print("")
	print("=== Glyph candidates, measured against the chain an un-overridden Control draws with ===")
	var default_font: Font = ThemeDB.fallback_font
	if default_font == null:
		print("  ThemeDB.fallback_font is null; nothing to measure")
		get_tree().quit(1)
		return
	var offline: Font = _offline(default_font)

	for row in CANDIDATES:
		var current: String = str(row[0])
		var subs: Array = row[1]
		var note: String = str(row[2])
		var cur_supplier: String = _supplier_or_empty(offline, current)
		print("")
		print("  U+%04X  %s" % [current.unicode_at(0), note])
		print("    in use today: %s" % ("REACHABLE via " + cur_supplier if cur_supplier != ""
			else "MISSING from every bundled font"))
		for s in subs:
			var sup: String = _supplier_or_empty(offline, str(s))
			var cps: Array[String] = []
			for i in range(str(s).length()):
				cps.append("U+%04X" % str(s).unicode_at(i))
			if sup != "":
				_reachable += 1
				print("    candidate %s  REACHABLE via %s" % [" ".join(cps), sup])
			else:
				_missing += 1
				print("    candidate %s  MISSING" % " ".join(cps))

	print("")
	print("RESULT: %d candidate(s) reachable, %d missing" % [_reachable, _missing])
	get_tree().quit(0)
