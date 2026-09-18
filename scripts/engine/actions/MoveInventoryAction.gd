# res://scripts/engine/actions/MoveInventoryAction.gd
class_name MoveInventoryAction
extends GameAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier

func _init(p_source_loc: LocationIdentifier = null, p_target_loc: LocationIdentifier = null) -> void:
	super._init(&"MoveInventoryAction")
	source_loc = p_source_loc
	target_loc = p_target_loc

func validate() -> bool:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	if not is_instance_valid(InventoryManager):
		return false
	var source_inst = InventoryManager._get_instance_at_location(source_loc)
	if not is_instance_valid(source_inst):
		return false
	return true

func execute() -> void:
	InventoryManager._on_try_inventory_action(source_loc, target_loc)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_loc"] = source_loc.to_dict() if is_instance_valid(source_loc) else {}
	d["target_loc"] = target_loc.to_dict() if is_instance_valid(target_loc) else {}
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if data.has("source_loc") and data["source_loc"] is Dictionary:
		source_loc = LocationIdentifier.create_from_dict(data["source_loc"])
	if data.has("target_loc") and data["target_loc"] is Dictionary:
		target_loc = LocationIdentifier.create_from_dict(data["target_loc"])
