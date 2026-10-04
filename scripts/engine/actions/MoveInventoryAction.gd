# res://scripts/engine/actions/MoveInventoryAction.gd
class_name MoveInventoryAction
extends GameAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier
var interaction_type: String = "CLICK"
var drop_pos: Vector2 = Vector2.ZERO

func _init(p_source_loc: LocationIdentifier = null, p_target_loc: LocationIdentifier = null, p_interaction_type: String = "CLICK", p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	super._init(&"MoveInventoryAction")
	source_loc = p_source_loc
	target_loc = p_target_loc
	interaction_type = p_interaction_type
	drop_pos = p_drop_pos

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
	InventoryManager._on_try_inventory_action(source_loc, target_loc, interaction_type, drop_pos)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_loc"] = source_loc.to_dict() if is_instance_valid(source_loc) else {}
	d["target_loc"] = target_loc.to_dict() if is_instance_valid(target_loc) else {}
	d["interaction_type"] = interaction_type
	d["drop_pos"] = [drop_pos.x, drop_pos.y]
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if data.has("source_loc") and data["source_loc"] is Dictionary:
		source_loc = LocationIdentifier.create_from_dict(data["source_loc"])
	if data.has("target_loc") and data["target_loc"] is Dictionary:
		target_loc = LocationIdentifier.create_from_dict(data["target_loc"])
	interaction_type = String(data.get("interaction_type", "CLICK"))
	if data.has("drop_pos") and data["drop_pos"] is Array and data["drop_pos"].size() == 2:
		drop_pos = Vector2(data["drop_pos"][0], data["drop_pos"][1])
