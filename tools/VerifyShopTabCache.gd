extends Node

## Does a shop tab switch still rebuild the whole tab?
##
## THE DEFECT
##   "Shop tab switching lags." _update_display() used to queue_free() every card and
##   construct the tab again on every click. The Minigames tab is the worst of the four:
##   24 PanelContainer cards, each holding a font-size-48 emoji Label plus a styled
##   Button, so one tab tap cost ~100 node constructions, 24 StyleBoxFlat allocations, a
##   fresh text-shaping pass per emoji glyph, and then _animate_grid_reveal() starting
##   one Tween per card. On the Moto E5 Plus (SDK 26) that is a visible stall.
##
## WHAT "FIXED" HAS TO MEAN
##   Not "feels faster". A cached tab must hand back THE SAME NODES - so this harness
##   compares instance ids across a switch away and back, which no amount of a faster
##   rebuild can fake. It also samples card alpha immediately after a warm switch,
##   because _animate_grid_reveal() drives every card from modulate.a = 0.0; if the
##   reveal ran, the alpha dips, and that dip is the tween storm the report was about.
##
## AND THE RISK THE CACHE INTRODUCES
##   A cache that never invalidates shows stale prices. Cases 6-8 buy a character
##   through the real _on_buy_character() handler and assert the card that comes back is
##   a NEW node that no longer offers to sell what the player already owns, and that a
##   language switch drops every tab.
##
## Usage:
##   godot --headless --path . res://tools/VerifyShopTabCache.tscn

const SHOP: String = "res://scenes/ui/UnlockablesScreen.tscn"
const TABS: Array[String] = ["characters", "minigames", "accessories", "decorations"]

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
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame


## Instance ids of a grid's cards. Identity, not count: a rebuild produces the same
## number of cards, so only the ids can tell a cache from a fast rebuild.
func _ids(grid: Node) -> Array[int]:
	var out: Array[int] = []
	if grid == null or not is_instance_valid(grid):
		return out
	for c in grid.get_children():
		out.append(c.get_instance_id())
	return out


func _subtree_nodes(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _subtree_nodes(c)
	return total


## Clicks a tab the way the button does, then lets _update_display()'s two awaits and
## the reveal tween settle.
func _switch(shop: Node, tab: String) -> void:
	match tab:
		"characters":
			shop._on_characters_tab()
		"minigames":
			shop._on_minigames_tab()
		"accessories":
			shop._on_accessories_tab()
		"decorations":
			shop._on_decorations_tab()
	await _frames(14)


func _grid(shop: Node, tab: String) -> Node:
	var g = shop._tab_grids.get(tab)
	return g if (g != null and is_instance_valid(g)) else null


## Which tabs are on screen. Exactly one must be.
func _visible_tabs(shop: Node) -> Array[String]:
	var out: Array[String] = []
	for tab in shop._tab_grids.keys():
		var g = shop._tab_grids[tab]
		if g != null and is_instance_valid(g) and g.visible:
			out.append(str(tab))
	return out


## True when this card is still offering to sell something - a "💧 <cost>" button.
func _card_sells(card: Node) -> bool:
	for n in card.find_children("*", "Button", true, false):
		if str((n as Button).text).begins_with("💧"):
			return true
	return false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Shop tab cache ===")

	var shop: Node = (load(SHOP) as PackedScene).instantiate()
	get_tree().root.add_child(shop)
	await _frames(24)

	# --- 1. cold build ------------------------------------------------------------
	var g_char := _grid(shop, "characters")
	_check(
		"cold open builds the characters grid",
		g_char != null and g_char.get_child_count() > 0,
		"cards: %d" % (g_char.get_child_count() if g_char else -1)
	)
	var ids_char := _ids(g_char)

	# --- 2. switching away keeps the built grid alive, hidden ---------------------
	await _switch(shop, "minigames")
	var g_mini := _grid(shop, "minigames")
	g_char = _grid(shop, "characters")
	_check(
		"switching away hides the old grid instead of freeing it",
		g_char != null and not g_char.visible,
		"characters grid %s" % ("hidden" if (g_char and not g_char.visible) else "GONE or still visible")
	)
	_check(
		"the new tab builds its own grid",
		g_mini != null and g_mini.get_child_count() > 0,
		"minigame cards: %d" % (g_mini.get_child_count() if g_mini else -1)
	)
	var on_screen := _visible_tabs(shop)
	_check(
		"exactly one grid is on screen",
		on_screen.size() == 1 and on_screen[0] == "minigames",
		"visible: %s" % str(on_screen)
	)

	# --- 3. the warm switch: same nodes, no rebuild -------------------------------
	var nodes_before := _subtree_nodes(shop)
	await _switch(shop, "characters")
	var nodes_after := _subtree_nodes(shop)
	var ids_back := _ids(_grid(shop, "characters"))
	_check(
		"coming back re-uses the same card instances",
		ids_back == ids_char and ids_char.size() > 0,
		"%d cards before, %d after, identical: %s"
			% [ids_char.size(), ids_back.size(), str(ids_back == ids_char)]
	)
	_check(
		"a warm switch constructs no nodes",
		nodes_after == nodes_before,
		"scene node count %d -> %d" % [nodes_before, nodes_after]
	)

	# --- 4. and starts no reveal tweens ------------------------------------------
	# _animate_grid_reveal() drops every card to modulate.a = 0.0 before tweening it
	# back, so a single sample below 1.0 on the frames right after the switch means the
	# per-card tween storm ran again.
	await _switch(shop, "minigames")
	shop._on_characters_tab()
	var min_alpha := 1.0
	for _i in range(8):
		await _frames(1)
		var g := _grid(shop, "characters")
		if g == null:
			continue
		for c in g.get_children():
			if c is Control:
				min_alpha = minf(min_alpha, (c as Control).modulate.a)
	_check(
		"a warm switch runs no per-card reveal animation",
		min_alpha > 0.999,
		"lowest card alpha seen after the switch: %.3f" % min_alpha
	)
	await _frames(10)

	# --- 5. repeated switching neither leaks grids nor grows the scene ------------
	# One priming pass first: accessories and decorations have not been opened yet, and
	# their cold build is supposed to construct nodes. Sampling before that would have
	# counted the legitimate first build as churn.
	for tab in TABS:
		await _switch(shop, tab)
	var nodes_pre_churn := _subtree_nodes(shop)
	for _round in range(3):
		for tab in TABS:
			await _switch(shop, tab)
	_check(
		"12 tab switches leave at most one grid per tab",
		shop._tab_grids.size() <= TABS.size(),
		"grids cached: %d for %d tabs" % [shop._tab_grids.size(), TABS.size()]
	)
	var nodes_post_churn := _subtree_nodes(shop)
	# Every tab is built by now, so this whole loop must construct nothing at all.
	_check(
		"12 tab switches over built tabs construct nothing",
		nodes_post_churn == nodes_pre_churn,
		"scene node count %d -> %d" % [nodes_pre_churn, nodes_post_churn]
	)

	# --- 6/7. a purchase must not be able to show a stale card -------------------
	await _switch(shop, "characters")
	var locked_id := ""
	for d in shop.characters_data:
		if not bool(d["unlocked"]):
			locked_id = str(d["id"])
			break
	if locked_id == "":
		_check("a locked character exists to buy", false, "every character already unlocked")
	else:
		var save_mgr := get_node_or_null("/root/SaveManager")
		var cost := 0
		for d in shop.characters_data:
			if str(d["id"]) == locked_id:
				cost = int(d["cost"])
		if save_mgr and save_mgr.has_method("add_droplets"):
			save_mgr.add_droplets(cost + 100)
		elif get_node_or_null("/root/GameManager"):
			get_node_or_null("/root/GameManager").water_droplets = cost + 100

		var ids_pre_buy := _ids(_grid(shop, "characters"))
		shop._on_buy_character(locked_id)
		await _frames(16)
		var g_after := _grid(shop, "characters")
		var ids_post_buy := _ids(g_after)
		_check(
			"a purchase invalidates the cached tab",
			ids_post_buy.size() > 0 and ids_post_buy != ids_pre_buy,
			"cards rebuilt: %s (%d -> %d)"
				% [str(ids_post_buy != ids_pre_buy), ids_pre_buy.size(), ids_post_buy.size()]
		)
		# The point of invalidating: the card for what was just bought must stop
		# offering to sell it.
		var still_selling := 0
		var unlocked_now := 0
		for d in shop.characters_data:
			if bool(d["unlocked"]):
				unlocked_now += 1
		if g_after:
			for c in g_after.get_children():
				if _card_sells(c):
					still_selling += 1
		var expected_selling: int = shop.characters_data.size() - unlocked_now
		_check(
			"no card offers to sell an item the player now owns",
			still_selling == expected_selling,
			"%d cards priced, %d characters still locked" % [still_selling, expected_selling]
		)

	# --- 8. a language switch drops every tab ------------------------------------
	await _switch(shop, "minigames")
	var ids_mini_pre := _ids(_grid(shop, "minigames"))
	shop._on_language_changed("tl")
	await _frames(16)
	var ids_mini_post := _ids(_grid(shop, "minigames"))
	_check(
		"a language switch rebuilds the visible tab",
		ids_mini_post.size() > 0 and ids_mini_post != ids_mini_pre,
		"%d -> %d cards, rebuilt: %s"
			% [ids_mini_pre.size(), ids_mini_post.size(), str(ids_mini_post != ids_mini_pre)]
	)
	_check(
		"a language switch leaves no other tab cached with old text",
		shop._tab_grids.size() == 1 and shop._tab_grids.has("minigames"),
		"cached after the switch: %s" % str(shop._tab_grids.keys())
	)

	shop.queue_free()
	await _frames(4)

	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
