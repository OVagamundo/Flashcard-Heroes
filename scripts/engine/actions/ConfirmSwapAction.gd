extends GameAction
class_name ConfirmSwapAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier

func _init(p_source_loc: LocationIdentifier, p_target_loc: LocationIdentifier) -> void:
	source_loc = p_source_loc
	target_loc = p_target_loc

func is_valid() -> bool:
	if source_loc == null or target_loc == null: return false
	
	var source_instance = GameManager.get_instance_from_location(source_loc)
	var target_instance = GameManager.get_instance_from_location(target_loc)
	if source_instance == null or target_instance == null: return false
	
	return InventoryManager.is_valid_placement(source_instance, target_loc) and InventoryManager.is_valid_placement(target_instance, source_loc)

func execute() -> void:
	# perform_swap already triggers its own visual feedback via inventory_action_completed
	if InventoryManager.has_method("perform_swap"):
		InventoryManager.perform_swap(source_loc, target_loc)
	
	if not yields_for_visuals():
		finish_visuals()

func yields_for_visuals() -> bool:
	# The swap doesn't need to block ActionQueue for long, the individual slots handle their own animations
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "ConfirmSwapAction",
		"source_loc": source_loc.to_dict() if is_instance_valid(source_loc) and source_loc.has_method("to_dict") else {},
		"target_loc": target_loc.to_dict() if is_instance_valid(target_loc) and target_loc.has_method("to_dict") else {}
	}
