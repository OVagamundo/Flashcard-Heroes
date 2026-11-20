# res://scripts/ui/LocationViewRegistry.gd
class_name LocationViewRegistry
extends RefCounted

## O(1) bidirectional registry mapping logical LocationIdentifier keys to live UI Controls.
## Replaces full-SceneTree BFS scans in WindowManager.find_view_for_location().
## Preserves parent-first (SlotView before child GachaBallView) resolution priority.

var _key_to_views: Dictionary = {} # String -> Array[Dictionary] ({view: Control, is_container: bool})
var _view_id_to_key: Dictionary = {} # int (instance_id) -> String


static func make_key(loc: LocationIdentifier) -> String:
	if not is_instance_valid(loc):
		return ""
	return "%s:%d:%s" % [String(loc.container), loc.index, loc.unit_uuid]


func register_view(loc: LocationIdentifier, view: Control, is_container: bool = false) -> void:
	if not is_instance_valid(view):
		return
	unregister_view(view)
	var key: String = make_key(loc)
	if key.is_empty():
		return
	var bucket: Array = _key_to_views.get(key, [])
	for existing: Variant in bucket:
		if existing is Dictionary and existing.get("view") == view:
			existing["is_container"] = is_container
			_view_id_to_key[view.get_instance_id()] = key
			return
	bucket.append({"view": view, "is_container": is_container})
	_key_to_views[key] = bucket
	_view_id_to_key[view.get_instance_id()] = key


func unregister_view(view: Control) -> void:
	if not is_instance_valid(view):
		return
	var view_id: int = view.get_instance_id()
	if not _view_id_to_key.has(view_id):
		return
	var old_key: String = String(_view_id_to_key[view_id])
	_view_id_to_key.erase(view_id)
	if not _key_to_views.has(old_key):
		return
	var bucket: Array = _key_to_views[old_key]
	for i: int in range(bucket.size() - 1, -1, -1):
		var entry: Variant = bucket[i]
		if entry is Dictionary and entry.get("view") == view:
			bucket.remove_at(i)
	if bucket.is_empty():
		_key_to_views.erase(old_key)


func find_view(loc: LocationIdentifier) -> Control:
	var key: String = make_key(loc)
	if key.is_empty() or not _key_to_views.has(key):
		return null
	var bucket: Array = _key_to_views[key]
	var fallback_view: Control = null
	for i: int in range(bucket.size() - 1, -1, -1):
		var entry: Variant = bucket[i]
		if not (entry is Dictionary):
			bucket.remove_at(i)
			continue
		var candidate: Variant = entry.get("view")
		if not is_instance_valid(candidate) or not (candidate is Control):
			bucket.remove_at(i)
			continue
		var ctrl := candidate as Control
		if ctrl.is_queued_for_deletion() or not ctrl.is_inside_tree():
			if ctrl.is_queued_for_deletion():
				_view_id_to_key.erase(ctrl.get_instance_id())
				bucket.remove_at(i)
			continue
		if bool(entry.get("is_container", false)):
			return ctrl
		if fallback_view == null:
			fallback_view = ctrl
	if bucket.is_empty():
		_key_to_views.erase(key)
	return fallback_view


func clear() -> void:
	_key_to_views.clear()
	_view_id_to_key.clear()
