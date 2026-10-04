# res://scripts/engine/actions/ui/InspectEntityAction.gd
class_name InspectEntityAction
extends GameAction

var location: LocationIdentifier = null
var entity_uuid: String = ""
var definition_id: String = ""
var window_type: StringName = &""
var effect_id: StringName = &""
var should_lock: bool = true

func _init(
	p_location: LocationIdentifier = null,
	p_should_lock: bool = true,
	p_window_type: StringName = &"",
	p_effect_id: StringName = &"",
	p_entity_uuid: String = "",
	p_definition_id: String = ""
) -> void:
	super._init(&"InspectEntityAction")
	location = p_location
	should_lock = p_should_lock
	window_type = p_window_type
	effect_id = p_effect_id
	entity_uuid = p_entity_uuid
	definition_id = p_definition_id

func validate() -> bool:
	if not is_instance_valid(WindowManager):
		return false
	if is_instance_valid(location):
		return true
	if not entity_uuid.is_empty() or not definition_id.is_empty() or not effect_id.is_empty():
		return true
	return false

func execute() -> void:
	if not is_instance_valid(WindowManager):
		return

	var anchor: Control = null
	if is_instance_valid(location):
		anchor = WindowManager.find_view_for_location(location)

	if not is_instance_valid(anchor) and not entity_uuid.is_empty():
		if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
			var loc = GameManager.run_state.get_location_for_uuid(entity_uuid)
			if is_instance_valid(loc):
				location = loc
				anchor = WindowManager.find_view_for_location(location)

	if not is_instance_valid(anchor):
		anchor = WindowManager.get_top_contextual_window()

	if not is_instance_valid(anchor):
		return

	if not effect_id.is_empty():
		var status_def = StatusEffectRegistry.get_definition(effect_id)
		if is_instance_valid(status_def):
			var effect_context = {
				"name_key": status_def.display_name_key,
				"description_key": status_def.description_key
			}
			var populate_ctx = {
				"effect_definition": [effect_context],
				"source_view": anchor
			}
			WindowManager.open_child_contextual_window(&"EffectInspection", anchor, populate_ctx)
		return

	if not definition_id.is_empty():
		var def = Database.get_definition(StringName(definition_id))
		if is_instance_valid(def):
			var populate_ctx = {
				"definition": def,
				"source_view": anchor
			}
			WindowManager.open_child_contextual_window(&"ItemInspection", anchor, populate_ctx)
		return

	if window_type == &"ItemInspection" and is_instance_valid(location) and location.container == C.CONTAINER_EQUIPPED_ITEM:
		var all_instances: Dictionary = {}
		var bm = Engine.get_main_loop().root.find_child("BattleManager", true, false)
		if is_instance_valid(bm) and bm.has_method("get_all_instances"):
			all_instances = bm.get_all_instances()
		elif is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
			all_instances = GameManager.run_state.get_all_instances()

		var item_instance = all_instances.get(location.unit_uuid, null)
		if not is_instance_valid(item_instance) and not entity_uuid.is_empty():
			item_instance = all_instances.get(entity_uuid, null)
		if is_instance_valid(item_instance):
			var populate_ctx = {
				"source_view": anchor,
				"instance": item_instance,
				"location": location
			}
			WindowManager.open_child_contextual_window(&"ItemInspection", anchor, populate_ctx)
			return

	if should_lock and is_instance_valid(GlobalInteractionRouter):
		GlobalInteractionRouter.set("_is_inspection_locked", true)
		GlobalInteractionRouter.set("_locked_entity_view_id", anchor.get_instance_id())

	WindowManager.open_inspection_window(location, anchor)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["location"] = location.to_dict() if is_instance_valid(location) else {}
	d["entity_uuid"] = entity_uuid
	d["definition_id"] = definition_id
	d["window_type"] = String(window_type)
	d["effect_id"] = String(effect_id)
	d["should_lock"] = should_lock
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if data.has("location") and data["location"] is Dictionary and not data["location"].is_empty():
		location = LocationIdentifier.create_from_dict(data["location"])
	entity_uuid = String(data.get("entity_uuid", ""))
	definition_id = String(data.get("definition_id", ""))
	window_type = StringName(data.get("window_type", ""))
	effect_id = StringName(data.get("effect_id", ""))
	should_lock = bool(data.get("should_lock", true))
