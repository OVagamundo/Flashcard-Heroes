# res://scripts/engine/actions/ConfirmSwapAction.gd
class_name ConfirmSwapAction
extends GameAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier

func _init(p_source_loc: LocationIdentifier = null, p_target_loc: LocationIdentifier = null) -> void:
	super._init(&"ConfirmSwapAction")
	source_loc = p_source_loc
	target_loc = p_target_loc

func validate() -> bool:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	var source_instance: GachaBallInstance = GameManager.get_instance_from_location(source_loc)
	var target_instance: GachaBallInstance = GameManager.get_instance_from_location(target_loc)
	if source_instance == null or target_instance == null:
		return false
	return InventoryManager.is_valid_placement(source_instance, target_loc) and InventoryManager.is_valid_placement(target_instance, source_loc)

func execute() -> void:
	InventoryManager._on_choice_made(&"SWAP", source_loc, target_loc, &"")

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
