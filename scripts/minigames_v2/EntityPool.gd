class_name EntityPool
extends RefCounted

## Fixed-size object pool. Every node is created ONCE in setup(), before the
## microgame loop starts; gameplay only acquires/releases pre-built nodes and
## toggles visibility. No instantiate(), no queue_free(), no Array growth after
## setup — the free-list is a pre-sized int stack, so acquire/release are O(1)
## with zero allocation (thesis constraint: flat heap, no GC spikes on the
## Moto G6).
##
## Release convention: callers never erase() from tracked collections. A
## microgame keeps `active_indices: PackedInt64Array` (fixed cap) and uses
## swap-remove, or simply iterates the pool and skips invisible items.

var capacity: int = 0
var active_count: int = 0

var _items: Array[Node] = []
## Pre-sized LIFO of free indices. Push/pop with an explicit top pointer so
## there is no per-operation array resizing.
var _free: PackedInt64Array = PackedInt64Array()
var _free_top: int = -1
var _container: Node = null
const META_POOL_IDX: String = "_pool_idx"


## Build all pooled nodes up front. `factory` receives the index and must
## return a fully-built Node (visuals included — build everything here, since
## this runs before the game loop).
func setup(factory: Callable, count: int, container: Node) -> void:
	capacity = count
	active_count = 0
	_container = container
	_items.resize(count)
	_free.resize(count)
	_free_top = count - 1
	for i in range(count):
		var node: Node = factory.call(i)
		node.visible = false
		node.set_meta(META_POOL_IDX, i)
		container.add_child(node)
		_items[i] = node
		_free[i] = count - 1 - i  # fills so acquire() pops 0,1,2,...


## Take a node out of the pool. Returns null when exhausted — callers must
## treat the capacity as the game's hard entity cap (by design: the loop can
## never grow memory mid-round).
func acquire() -> Node:
	if _free_top < 0:
		return null
	var idx: int = _free[_free_top]
	_free_top -= 1
	active_count += 1
	var node: Node = _items[idx]
	node.visible = true
	return node


## Return a node obtained from acquire(). O(1), no allocation.
func release(node: Node) -> void:
	if node.has_meta(META_POOL_IDX):
		_release_index(int(node.get_meta(META_POOL_IDX)))


## Fast path when the caller tracked the index itself.
func release_index(idx: int) -> void:
	if idx < 0 or idx >= capacity:
		return
	_release_index(idx)


func _release_index(idx: int) -> void:
	var node: Node = _items[idx]
	if not node.visible:
		return  # double release guard
	node.visible = false
	_free_top += 1
	_free[_free_top] = idx
	active_count -= 1


## Release everything (between rounds).
func release_all() -> void:
	for i in range(capacity):
		_release_index(i)


func get_item(idx: int) -> Node:
	if idx < 0 or idx >= capacity:
		return null
	return _items[idx]
