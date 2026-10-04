# res://scripts/engine/actions/ui/SelectEntityAction.gd
class_name SelectEntityAction
extends GameAction

var location: LocationIdentifier = null
var entity_uuid: String = ""

func _init(p_location: LocationIdentifier = null, p_entity_uuid: String = "") -> void:
	super._init(&"SelectEntityAction")
	location = p_location
	entity_uuid = p_entity_uuid

func validate() -> bool:
	return is_instance_valid(location) or not entity_uuid.is_empty()

func execute() -> void:
	if is_instance_valid(GlobalInteractionRouter):
		GlobalInteractionRouter.apply_select_entity(location, entity_uuid)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["location"] = location.to_dict() if is_instance_valid(location) else {}
	d["entity_uuid"] = entity_uuid
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if data.has("location") and data["location"] is Dictionary and not data["location"].is_empty():
		location = LocationIdentifier.create_from_dict(data["location"])
	entity_uuid = String(data.get("entity_uuid", ""))
