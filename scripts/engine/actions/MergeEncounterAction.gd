# res://scripts/engine/actions/MergeEncounterAction.gd
class_name MergeEncounterAction
extends GameAction

## Dispatched when confirming a merge during a Merge Encounter (costs gold).
## Distinct from ConfirmMergeAction which is free (combat/non-encounter).

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier
var recipe_id: StringName = &""

func _init(p_source_loc: LocationIdentifier = null, p_target_loc: LocationIdentifier = null, p_recipe_id: StringName = &"") -> void:
	super._init(&"MergeEncounterAction")
	source_loc = p_source_loc
	target_loc = p_target_loc
	recipe_id = p_recipe_id

func validate() -> bool:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc) or recipe_id.is_empty():
		return false
	if not is_instance_valid(GameManager.run_state):
		return false
	var cost: int = 5
	if "merge_encounter_cost" in GameManager.run_state:
		cost = GameManager.run_state.merge_encounter_cost
	return GameManager.run_state.gold >= cost

func execute() -> void:
	InventoryManager._on_choice_made(&"MERGE", source_loc, target_loc, recipe_id)

func yields_for_visuals() -> bool:
	return not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_loc"] = source_loc.to_dict() if is_instance_valid(source_loc) else {}
	d["target_loc"] = target_loc.to_dict() if is_instance_valid(target_loc) else {}
	d["recipe_id"] = String(recipe_id)
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if data.has("source_loc") and data["source_loc"] is Dictionary:
		source_loc = LocationIdentifier.create_from_dict(data["source_loc"])
	if data.has("target_loc") and data["target_loc"] is Dictionary:
		target_loc = LocationIdentifier.create_from_dict(data["target_loc"])
	recipe_id = StringName(data.get("recipe_id", ""))
