extends Node

## Is the multiplayer waiting room's top text on the screen, and can the rows below it be
## reached?
##
## THE DEFECT
##   Reported as "multiplayer waiting-room top status text clipped, with no way to scroll".
##   The waiting room stacks seven rows in one column - status, player list, ready,
##   auto play, start, disconnect, leaderboard (the last two are built in code, not in the
##   .tscn) - and on mobile five of them are BaseButtons, whose minimum height
##   MobileUIManager raises to the 48dp touch floor. That floor is density-dependent:
##   121 canvas units at 402 dpi, 168 at 560. Measured on the Moto E5 Plus shape as host,
##   the column's minimum height came to 1114 units on a 1080-unit screen.
##
##   What turned that overflow into CLIPPED TOP TEXT rather than a long screen: a Control
##   clamps its own size UP to its combined minimum size, so the column's minimum
##   propagated out through the PanelContainer to MultiplayerLobby's full-rect
##   MarginContainer - and that MarginContainer's grow_vertical is GROW_DIRECTION_BOTH, so
##   Godot split the 124 units of overflow across BOTH edges. The whole screen was pushed
##   up: at 402 dpi the column started 17 units above y=0 and at 560 dpi 134 units above
##   it, taking the title and the status line off the top, while the leaderboard row hung
##   off the bottom. Nothing in the scene scrolled, so neither end was recoverable.
##
##   Why no headless sweep caught it: a headless DisplayServer reports no dpi, so
##   _dp_to_canvas_units falls back to the mdpi baseline of 160, where the floor is 60
##   units and the same column fits with room to spare. The defect exists only at real
##   phone densities - which is where the report came from.
##
## THE FIX UNDER TEST
##   The column now lives in a ScrollContainer (WaitingScroll). With vertical scrolling
##   enabled a ScrollContainer contributes NO minimum height, so the column stops
##   propagating its height outward, the screen stops growing past its edges, and the rows
##   that do not fit become scrollable instead of lost. Horizontal scrolling stays
##   DISABLED so the column still publishes its minimum WIDTH, and the inner VBox expands
##   in both axes so the authored centre alignment still centres whenever there is room.
##
## WHAT IS MEASURED HERE
##   1. that the defect is still reproducible: switching this one ScrollContainer back to
##      SCROLL_MODE_DISABLED restores the exact pre-fix minimum propagation, and at the
##      reported densities the screen really does climb above y=0. Without this row every
##      check below could pass on a layout that never had the problem.
##   2. that the top text - title, subtitle and the status line the report named - is
##      fully on screen at both reported device shapes across a density band, in both
##      roles, measured through the accumulated canvas transform.
##   3. that the screen itself no longer extends past either edge.
##   4. that every row below the fold is REACHABLE: scrolling to the end brings the last
##      row fully into view, no row is taller than the scroll viewport, and moving focus
##      to an off-screen row scrolls it in (which is what a player's keyboard or gamepad
##      does).
##   5. that where the column does fit, nothing changed: no scrollbar, and the content
##      still centred the way the scene authored it.
##   6. that the column still publishes its minimum WIDTH, so nothing is squeezed
##      sideways in exchange for the vertical fix.
##   7. that desktop - the same screen, unscaled - is untouched.
##
## NOT MEASURED HERE (needs the physical device)
##   The dpi the Moto E5 Plus actually reports, and that a finger drag scrolls the column.
##   Densities are injected through MobileUIManager.debug_dpi_override, the same value the
##   production conversion reads, and a band is swept rather than one number bet on.
##   Reachability is proven here through the scroll value and through focus, not touch.
##
## Usage:
##   godot --headless --path . res://tools/VerifyWaitingRoomFit.tscn

const LOBBY: String = "res://scenes/ui/MultiplayerLobby.tscn"
const PANEL_PATH: String = "MarginContainer/VBoxContainer/WaitingPanel"
const SCROLL_PATH: String = PANEL_PATH + "/WaitingScroll"
const COLUMN_PATH: String = SCROLL_PATH + "/VBoxContainer"
const MARGIN_PATH: String = "MarginContainer"
const OUTER_PATH: String = "MarginContainer/VBoxContainer"

## The two reported devices at the densities their panels imply, plus the mdpi fallback
## that made this invisible headless, plus a denser case where even the scroll has to work
## hard.
const CASES: Array = [
	{"n": "mdpi fallback (what headless sees)", "w": 2160, "h": 1080, "dpi": 160.0,
		"reported": false},
	{"n": "Moto E5 Plus 2160x1080, 268 dpi", "w": 2160, "h": 1080, "dpi": 268.0,
		"reported": false},
	{"n": "Moto E5 Plus 2160x1080, 402 dpi", "w": 2160, "h": 1080, "dpi": 402.0,
		"reported": true},
	{"n": "Poco X3 2400x1080, 395 dpi", "w": 2400, "h": 1080, "dpi": 395.0,
		"reported": true},
	{"n": "xxxhdpi stress 2160x1080, 560 dpi", "w": 2160, "h": 1080, "dpi": 560.0,
		"reported": false},
]

var _pass: int = 0
var _fail: int = 0
var _mui: Node = null
var _reproduced: int = 0


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


## Where a Control actually lands on the glass. get_global_rect() pairs a TRANSFORMED
## position with an UNTRANSFORMED size - the blind spot that let the QUIT-button clipping
## ship - so the size is scaled by the same transform as the origin.
func _glass(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale())


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


## Become a device: window shape, then the density that shape ships with, then mobile mode.
## The button-min cache has to be invalidated between densities or the first case's 48dp
## floor is reused for every later one.
func _stage_device(w: int, h: int, dpi: float) -> void:
	get_window().size = Vector2i(w, h)
	await _frames(4)
	_mui.debug_dpi_override = dpi
	if _mui.has_method("invalidate_button_min_size_cache"):
		_mui.invalidate_button_min_size_cache()
	_mui.enable_debug_mobile_mode(true)
	await _frames(2)


## Stage the waiting room the way the game reaches it, in one role.
func _stage_lobby(as_host: bool) -> Node:
	GameManager.is_host = as_host
	var lobby: Node = load(LOBBY).instantiate()
	get_tree().root.add_child(lobby)
	# The mobile pass resolves its target through current_scene, and the safe-area write
	# lands on this scene's MarginContainer. change_scene_to_file() is not an option: this
	# harness IS current_scene and would free itself mid-run.
	get_tree().current_scene = lobby
	await _frames(4)
	_mui.adapt_scene_for_mobile(lobby)
	await _frames(4)
	lobby.call("_show_waiting_panel")
	# The host's status line is TWO lines - "waiting for player" plus the IP - which is 81
	# units tall against 39 for one, and the client's Start button carries a long disabled
	# label. Both are set by production code paths (_on_host_pressed,
	# _update_start_button_state); reproduced here because the column's height depends on
	# them and the harness never connects a real peer.
	var status: Label = lobby.get_node(COLUMN_PATH + "/StatusLabel") as Label
	if as_host:
		status.text = "Waiting for player to join...\nYour IP: 192.168.1.100"
	else:
		status.text = "Connected! Waiting for host to start..."
	lobby.call("_update_start_button_state")
	await _frames(45)
	return lobby


## The rows of the waiting column, in the order a player reads them. Includes the two rows
## the script builds at runtime (LeaderboardButton, MPDurationRow), which is where the last
## 170 units of the overflow came from.
func _rows(column: Control) -> Array[Control]:
	var out: Array[Control] = []
	for child in column.get_children():
		var c := child as Control
		if c != null and c.is_visible_in_tree():
			out.append(c)
	return out


## Every visible Control in the scene that is NOT inside the scroll viewport. These have no
## scrolling to fall back on, so they must be fully on screen - the title and the subtitle
## live here.
func _outside_scroll(lobby: Node, scroll: Node) -> Array[Control]:
	var out: Array[Control] = []
	for node in lobby.find_children("*", "Control", true, false):
		var c := node as Control
		if c == null or not c.is_visible_in_tree():
			continue
		if c == scroll or scroll.is_ancestor_of(c):
			continue
		if c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		out.append(c)
	return out


func _fully_inside(inner: Rect2, outer: Rect2, slack: float = 0.5) -> bool:
	return (
		inner.position.y >= outer.position.y - slack
		and inner.end.y <= outer.end.y + slack
		and inner.position.x >= outer.position.x - slack
		and inner.end.x <= outer.end.x + slack
	)


## One density x one role. Reproduce the defect on this exact staged screen, restore the
## fix, then measure.
func _case(c: Dictionary, as_host: bool, autoplay: bool) -> void:
	await _stage_device(int(c["w"]), int(c["h"]), float(c["dpi"]))
	var lobby: Node = await _stage_lobby(as_host)
	var scroll: ScrollContainer = lobby.get_node(SCROLL_PATH) as ScrollContainer
	var column: Control = lobby.get_node(COLUMN_PATH) as Control
	var panel: Control = lobby.get_node(PANEL_PATH) as Control
	var margin: Control = lobby.get_node(MARGIN_PATH) as Control
	var outer: Control = lobby.get_node(OUTER_PATH) as Control
	var status: Control = lobby.get_node(COLUMN_PATH + "/StatusLabel") as Control

	if autoplay:
		# The real path: _sync_auto_play_state() is what reveals MPDurationRow, and with no
		# peer connected it cannot start a game (_are_all_players_ready needs two peers).
		lobby.call("_sync_auto_play_state", true)
		await _frames(20)

	var role: String = "host" if as_host else "client"
	var vp: Vector2 = _vp()
	var floor_h: float = float(_mui._resolve_button_min_size().y)
	var col_min: float = column.get_combined_minimum_size().y
	var page_h: float = scroll.size.y
	var rows: Array[Control] = _rows(column)
	var fits: bool = col_min <= page_h + 0.5
	print("")
	print("  -- %s, %s%s --" % [str(c["n"]), role, " + AutoPlay" if autoplay else ""])
	print("     viewport %.0fx%.0f units, 48dp floor %.0f units, %d rows"
		% [vp.x, vp.y, floor_h, rows.size()])
	print("     column minimum height %.0f vs %.0f units of panel: %s"
		% [col_min, page_h, "fits" if fits else "OVERFLOWS by %.0f" % (col_min - page_h)])

	# --- reproduction: put this one property back the way it was before the fix ---
	# Disabling vertical scrolling is exactly what restores the pre-fix minimum-size
	# propagation, so this measures the defect on the same staged screen rather than
	# reconstructing it arithmetically (the real pre-fix top edge also depended on the
	# safe-area offsets, which a calculation would have to guess).
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	await _frames(8)
	var pre_top: float = _glass(outer).position.y
	var pre_min: float = outer.get_combined_minimum_size().y
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	await _frames(8)
	print("     pre-fix shape (scrolling off): screen top y=%.1f, screen minimum height %.0f"
		% [pre_top, pre_min])
	if not fits:
		var climbed: bool = pre_top < -0.5
		if climbed:
			_reproduced += 1
		_check(
			"with the fix reverted this shape really does clip the top (guards a vacuous pass)",
			climbed,
			"screen top y=%.1f with scrolling disabled, %.1f with it enabled"
				% [pre_top, _glass(outer).position.y]
		)

	await _fit_checks(lobby, scroll, column, panel, margin, outer, status, rows, page_h, fits)

	get_tree().current_scene = null
	lobby.queue_free()
	await _frames(4)


## Everything that must be true of the fixed layout at this shape.
func _fit_checks(
	lobby: Node, scroll: ScrollContainer, column: Control, panel: Control, margin: Control,
	outer: Control, status: Control, rows: Array[Control], page_h: float, fits: bool
) -> void:
	var vp: Vector2 = _vp()
	var screen: Rect2 = Rect2(Vector2.ZERO, vp)
	var scroll_rect: Rect2 = _glass(scroll)

	scroll.scroll_vertical = 0
	await _frames(4)

	# 3. The screen stopped growing past its own edges. This is the defect's mechanism
	#    measured directly: the column's height no longer reaches the full-rect
	#    MarginContainer, whose GROW_DIRECTION_BOTH was splitting the overflow across the
	#    top and bottom edges.
	var margin_rect: Rect2 = _glass(margin)
	var outer_rect: Rect2 = _glass(outer)
	_check(
		"the screen does not extend past the top or bottom edge any more",
		margin_rect.position.y >= -0.5 and margin_rect.end.y <= vp.y + 0.5
			and outer_rect.position.y >= -0.5,
		"MarginContainer y=%.1f..%.1f and the column below it starts at y=%.1f, in a %.0f-unit screen"
			% [margin_rect.position.y, margin_rect.end.y, outer_rect.position.y, vp.y]
	)
	_check(
		"the screen no longer inherits the column's height as its own minimum",
		outer.get_combined_minimum_size().y <= vp.y + 0.5,
		"screen minimum height %.0f vs %.0f units available"
			% [outer.get_combined_minimum_size().y, vp.y]
	)

	# 2. The reported symptom. The status line is the text that was cut off; the title and
	#    subtitle sit outside the scroll and have nothing to fall back on at all.
	_check(
		"the status line the report named is fully on screen",
		_fully_inside(_glass(status), screen) and _fully_inside(_glass(status), scroll_rect),
		"StatusLabel %s in a %.0fx%.0f screen, scroll viewport %s"
			% [str(_glass(status)), vp.x, vp.y, str(scroll_rect)]
	)
	var stranded: Array[String] = []
	for c in _outside_scroll(lobby, scroll):
		if not _fully_inside(_glass(c), screen):
			stranded.append("%s %s" % [c.name, str(_glass(c))])
	_check(
		"every control outside the scroll - title, subtitle, the panel itself - is fully on screen",
		stranded.is_empty(),
		"off screen: %s" % ("none" if stranded.is_empty() else ", ".join(stranded))
	)

	# 6. The vertical fix must not have been bought with a horizontal squeeze: horizontal
	#    scrolling is disabled precisely so the column still publishes its minimum WIDTH.
	_check(
		"the column's minimum WIDTH still reaches the panel (nothing squeezed sideways)",
		panel.get_combined_minimum_size().x >= column.get_combined_minimum_size().x - 0.5,
		"panel min width %.0f vs column min width %.0f"
			% [panel.get_combined_minimum_size().x, column.get_combined_minimum_size().x]
	)
	var wide: Array[String] = []
	for c in rows:
		var r: Rect2 = _glass(c)
		if r.position.x < -0.5 or r.end.x > vp.x + 0.5:
			wide.append("%s x=%.0f..%.0f" % [c.name, r.position.x, r.end.x])
	_check(
		"no row runs off the side",
		wide.is_empty(),
		"%s (screen %.0f wide)" % ["none" if wide.is_empty() else ", ".join(wide), vp.x]
	)

	# 4. Reachability. A row taller than the viewport can never be shown whole however far
	#    the player scrolls, so that is checked before the scrolling itself.
	var too_tall: Array[String] = []
	for c in rows:
		if _glass(c).size.y > page_h + 0.5:
			too_tall.append("%s %.0f units" % [c.name, _glass(c).size.y])
	_check(
		"no single row is taller than the scroll viewport",
		too_tall.is_empty(),
		"%s (viewport %.0f units)" % ["none" if too_tall.is_empty() else ", ".join(too_tall), page_h]
	)

	var first: Control = rows[0]
	var last: Control = rows[rows.size() - 1]
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	_check(
		"at the top of the scroll the first row is whole",
		_fully_inside(_glass(first), scroll_rect),
		"%s %s in scroll viewport %s" % [first.name, str(_glass(first)), str(scroll_rect)]
	)
	scroll.scroll_vertical = int(bar.max_value)
	await _frames(6)
	_check(
		"at the end of the scroll the last row is whole",
		_fully_inside(_glass(last), scroll_rect),
		"%s %s in scroll viewport %s (scroll_vertical=%d of %d)"
			% [last.name, str(_glass(last)), str(scroll_rect), scroll.scroll_vertical,
				int(bar.max_value)]
	)
	scroll.scroll_vertical = 0
	await _frames(6)

	if fits:
		# 5. Where the column already fitted, the screen must look exactly as it did before
		#    the fix: no scrollbar, and the rows still centred the way the scene authored
		#    them (alignment = 1). A ScrollContainer honours a child's EXPAND flags, so the
		#    column still fills the panel and still centres inside it - measured rather
		#    than assumed, because if it did not the fix would have silently top-aligned
		#    every screen that was fine.
		_check(
			"where the column fits there is no scrollbar",
			not bar.visible,
			"v-scrollbar visible=%s, max=%.0f page=%.0f"
				% [bar.visible, bar.max_value, bar.page]
		)
		var gap_top: float = _glass(first).position.y - scroll_rect.position.y
		var gap_bottom: float = scroll_rect.end.y - _glass(last).end.y
		_check(
			"where the column fits the rows are still centred as authored",
			absf(gap_top - gap_bottom) <= 2.0,
			"%.1f units above the first row, %.1f below the last" % [gap_top, gap_bottom]
		)
	else:
		_check(
			"where the column overflows the scrollbar is there to say so",
			bar.visible and bar.max_value > bar.page,
			"v-scrollbar visible=%s, max=%.0f page=%.0f"
				% [bar.visible, bar.max_value, bar.page]
		)
		# What a keyboard or a gamepad does. follow_focus is the reason a player who tabs
		# to the leaderboard row is taken to it instead of pressing a button they cannot
		# see; it is also the only reachability path this harness can drive without touch.
		var focusable: Control = null
		for c in rows:
			if c.focus_mode == Control.FOCUS_ALL:
				focusable = c
		if focusable != null and not _fully_inside(_glass(focusable), scroll_rect):
			var before: int = scroll.scroll_vertical
			focusable.grab_focus()
			await _frames(8)
			_check(
				"moving focus to a row below the fold scrolls it into view",
				_fully_inside(_glass(focusable), scroll_rect),
				"%s %s in scroll viewport %s (scroll_vertical %d -> %d)"
					% [focusable.name, str(_glass(focusable)), str(scroll_rect), before,
						scroll.scroll_vertical]
			)
			focusable.release_focus()
			scroll.scroll_vertical = 0
			await _frames(4)


## The fix is three properties on one node, and each of them is load-bearing. If a later
## scene edit clears one, the checks above could still pass at the density that happened to
## be swept while the shape quietly reverted.
func _config_check() -> void:
	await _stage_device(2160, 1080, 402.0)
	var lobby: Node = await _stage_lobby(true)
	var scroll: ScrollContainer = lobby.get_node(SCROLL_PATH) as ScrollContainer
	var column: Control = lobby.get_node(COLUMN_PATH) as Control
	print("")
	print("  -- the shape of the fix itself --")
	_check(
		"the waiting column is inside a ScrollContainer that scrolls vertically",
		scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
		"vertical_scroll_mode=%d" % scroll.vertical_scroll_mode
	)
	_check(
		"horizontal scrolling is DISABLED, so the column still publishes its minimum width",
		scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"horizontal_scroll_mode=%d" % scroll.horizontal_scroll_mode
	)
	_check(
		"follow_focus is on, so keyboard and gamepad focus can reach the rows below the fold",
		scroll.follow_focus,
		"follow_focus=%s" % scroll.follow_focus
	)
	_check(
		"the column still expands in both axes, so the authored centring survives",
		(column.size_flags_horizontal & Control.SIZE_EXPAND) != 0
			and (column.size_flags_vertical & Control.SIZE_EXPAND) != 0,
		"size_flags h=%d v=%d" % [column.size_flags_horizontal, column.size_flags_vertical]
	)
	get_tree().current_scene = null
	lobby.queue_free()
	await _frames(4)


## Desktop is the same scene at the same resolution with none of the mobile pass applied,
## and it was never broken. It has to come out of this unchanged: content centred, no
## scrollbar, nothing off any edge.
func _desktop_check() -> void:
	get_window().size = Vector2i(1920, 1080)
	await _frames(4)
	_mui.debug_dpi_override = 0.0
	_mui.invalidate_button_min_size_cache()
	_mui.enable_debug_mobile_mode(false)
	await _frames(2)
	var lobby: Node = load(LOBBY).instantiate()
	get_tree().root.add_child(lobby)
	get_tree().current_scene = lobby
	await _frames(4)
	lobby.call("_show_waiting_panel")
	await _frames(45)
	var scroll: ScrollContainer = lobby.get_node(SCROLL_PATH) as ScrollContainer
	var column: Control = lobby.get_node(COLUMN_PATH) as Control
	var outer: Control = lobby.get_node(OUTER_PATH) as Control
	var rows: Array[Control] = _rows(column)
	var scroll_rect: Rect2 = _glass(scroll)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var vp: Vector2 = _vp()
	print("")
	print("  -- desktop 1920x1080, mobile pass off (no regression) --")
	_check(
		"the desktop case really is running without the mobile pass",
		not _mui.is_mobile,
		"is_mobile=%s" % _mui.is_mobile
	)
	_check(
		"the whole screen is on screen",
		_fully_inside(_glass(outer), Rect2(Vector2.ZERO, vp)),
		"screen %s in %.0fx%.0f" % [str(_glass(outer)), vp.x, vp.y]
	)
	_check(
		"desktop shows no scrollbar",
		not bar.visible,
		"max=%.0f page=%.0f" % [bar.max_value, bar.page]
	)
	var gap_top: float = _glass(rows[0]).position.y - scroll_rect.position.y
	var gap_bottom: float = scroll_rect.end.y - _glass(rows[rows.size() - 1]).end.y
	_check(
		"desktop rows are still centred in the panel",
		absf(gap_top - gap_bottom) <= 2.0,
		"%.1f units above the first row, %.1f below the last" % [gap_top, gap_bottom]
	)
	get_tree().current_scene = null
	lobby.queue_free()
	await _frames(4)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Multiplayer waiting room: top text on screen, rows below it reachable ===")

	_mui = get_node_or_null("/root/MobileUIManager")
	if _mui == null:
		print("  FAIL  MobileUIManager autoload missing")
		get_tree().quit(1)
		return

	await _config_check()

	# Both roles at every density: the host carries a two-line status with its IP, the
	# client a long disabled Start label, and the two columns are different heights.
	for c in CASES:
		await _case(c, true, false)
		await _case(c, false, false)

	# AutoPlay on adds an eighth row (the duration spinbox) at the reported density.
	await _case(CASES[2], true, true)

	print("")
	_check(
		"the defect was reproduced at both reported device shapes",
		_reproduced >= 2,
		"%d shapes climbed above the top edge with the fix reverted" % _reproduced
	)

	await _desktop_check()

	if AutoPlayManager:
		AutoPlayManager.set_mp_auto_play_enabled(false)
	GameManager.is_host = false
	_mui.debug_dpi_override = 0.0
	_mui.invalidate_button_min_size_cache()

	print("")
	print("  -- on-device rows, not measurable headless --")
	print("     1. the dpi the Moto E5 Plus actually reports. Densities here are injected")
	print("        through MobileUIManager.debug_dpi_override, which the production")
	print("        conversion reads; a headless DisplayServer reports none and falls back")
	print("        to mdpi 160, where this column fits - which is exactly why every earlier")
	print("        headless sweep passed. A band of densities is swept rather than one")
	print("        number bet on.")
	print("     2. that a finger drag scrolls the waiting column. Reachability is proven")
	print("        here through the scroll value and through focus, not through touch.")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
