# res://scripts/engine/actions/ConfirmMergeAction.gd
class_name ConfirmMergeAction
extends GameAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier
var recipe_id: StringName = &""

func _init(p_source_loc: LocationIdentifier = null, p_target_loc: LocationIdentifier = null, p_recipe_id: StringName = &"") -> void:
	super._init(&"ConfirmMergeAction")
	source_loc = p_source_loc
	target_loc = p_target_loc
	recipe_id = p_recipe_id

func validate() -> bool:
	return is_instance_valid(source_loc) and is_instance_valid(target_loc) and not recipe_id.is_empty()

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
