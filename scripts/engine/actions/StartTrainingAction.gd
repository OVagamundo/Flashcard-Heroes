# res://scripts/engine/actions/StartTrainingAction.gd
class_name StartTrainingAction
extends GameAction

var target_unit_uuid: String = ""
var stat_type: String = "" # "hp" or "pwr"
var interaction_type: String = "CLICK"
var drop_pos: Vector2 = Vector2.ZERO

const TRAIN_COST_GOLD: int = 5

func _init(p_target_unit_uuid: String = "", p_stat_type: String = "", p_interaction_type: String = "CLICK", p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	super._init(&"StartTrainingAction")
	target_unit_uuid = p_target_unit_uuid
	stat_type = p_stat_type
	interaction_type = p_interaction_type
	drop_pos = p_drop_pos

func validate() -> bool:
	if target_unit_uuid.is_empty() or (stat_type != "hp" and stat_type != "pwr"):
		return false
	if not is_instance_valid(GameManager.run_state):
		return false
	if GameManager.run_state.gold < TRAIN_COST_GOLD:
		return false
	var instance: GachaBallInstance = GameManager.run_state.get_instance_by_uuid(target_unit_uuid)
	if not is_instance_valid(instance):
		return false
	var definition: Resource = instance.get_definition()
	if not is_instance_valid(definition) or definition.category != &"UNIT":
		return false
	var location: LocationIdentifier = GameManager.run_state.get_location_for_uuid(target_unit_uuid)
	return is_instance_valid(location) and String(location.container).begins_with("RunInventoryT")

func execute() -> void:
	# Synchronous model state mutation for both visual and headless execution
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.spend_gold(TRAIN_COST_GOLD)
		GameManager.run_state.current_room_tokens = 0
		GameManager.run_state.is_training_active = true
		GameManager.run_state.training_unit_uuid = target_unit_uuid
		GameManager.run_state.training_stat = stat_type

	var utg = Engine.get_main_loop().root.find_child("UnitTrainingGround", true, false)
	if is_instance_valid(utg) and not ActionQueue.is_headless_mode() and utg.has_method("execute_start_training_visuals"):
		utg.execute_start_training_visuals(target_unit_uuid, stat_type, drop_pos)
	else:
		if is_instance_valid(GameManager.run_state):
			FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func yields_for_visuals() -> bool:
	var utg = Engine.get_main_loop().root.find_child("UnitTrainingGround", true, false)
	return is_instance_valid(utg) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["target_unit_uuid"] = target_unit_uuid
	d["stat_type"] = stat_type
	d["interaction_type"] = interaction_type
	d["drop_pos"] = [drop_pos.x, drop_pos.y]
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	target_unit_uuid = String(data.get("target_unit_uuid", ""))
	stat_type = String(data.get("stat_type", ""))
	interaction_type = String(data.get("interaction_type", "CLICK"))
	if data.has("drop_pos") and data["drop_pos"] is Array and data["drop_pos"].size() == 2:
		drop_pos = Vector2(data["drop_pos"][0], data["drop_pos"][1])
