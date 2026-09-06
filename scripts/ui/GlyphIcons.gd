extends RefCounted

## Bundled replacements for the few UI glyphs the game used to take from the system
## emoji font.
##
## Font coverage for emoji varies wildly across Android versions, and the Moto E5 Plus
## (Android 8 / SDK 26) in the test matrix has no glyph for several of the ones this
## project reached for - they render as "tofu" boxes. Two of those were on controls, not
## just in logs: the co-op HUD pause button used "⏸"/"▶" (MiniGame_BucketBrigade,
## MiniGame_GreywaterSort, MiniGame_WaterHarvest) or an empty string where the glyph had
## already been stripped (MultiplayerMiniGameBase, MiniGame_LeafSort, MiniGame_Rain).
##
## An unlabeled pause button is not only ugly. It is an invisible ~50-unit hit area in
## the top-right corner of a tap-driven minigame, and gameplay taps landing on it are
## half of what produced the pause/resume storm in session_2026-09-05T00-27-36.json.
##
## Drawn in code rather than shipped as PNGs so there is no import step and no texture
## to keep in sync: the shapes are two bars and a triangle. Cached per size, because the
## HUD rebuilds these on every round.

const ICON_SIZE := 40

static var _cache: Dictionary = {}


## "⏸" — two vertical bars.
static func pause(size: int = ICON_SIZE, color: Color = Color.WHITE) -> ImageTexture:
	var key := "pause_%d_%s" % [size, color.to_html(false)]
	if _cache.has(key):
		return _cache[key]

	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bar_w := maxi(2, int(round(size * 0.18)))
	var gap := maxi(2, int(round(size * 0.14)))
	var top := int(round(size * 0.2))
	var bottom := size - top
	var left_x := int(round(size * 0.5)) - gap / 2 - bar_w
	var right_x := int(round(size * 0.5)) + gap / 2
	for y in range(top, bottom):
		for x in range(bar_w):
			img.set_pixel(left_x + x, y, color)
			img.set_pixel(right_x + x, y, color)

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## "▶" — a right-pointing triangle.
static func play(size: int = ICON_SIZE, color: Color = Color.WHITE) -> ImageTexture:
	var key := "play_%d_%s" % [size, color.to_html(false)]
	if _cache.has(key):
		return _cache[key]

	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var top := int(round(size * 0.18))
	var bottom := size - top
	var left := int(round(size * 0.26))
	var right := int(round(size * 0.80))
	var span := float(bottom - top)
	for y in range(top, bottom):
		# Half-height at this row, as a fraction of the triangle's depth.
		var t: float = abs(float(y) - (float(top) + span * 0.5)) / (span * 0.5)
		var x_end := int(round(float(right) - (float(right - left) * t)))
		for x in range(left, maxi(left, x_end)):
			img.set_pixel(x, y, color)

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Applies the pause or play glyph to a button as an ICON, clearing any text so a
## missing font glyph can never be what the player sees.
static func apply_pause_glyph(button: Button, showing_pause: bool) -> void:
	if button == null:
		return
	button.text = ""
	button.icon = pause() if showing_pause else play()
	button.expand_icon = true
