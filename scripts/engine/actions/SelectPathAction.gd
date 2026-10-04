# res://scripts/engine/actions/SelectPathAction.gd
class_name SelectPathAction
extends GameAction

var node_index: int = -1
var expected_node_type: String = ""
var expected_subtype: String = ""
var expected_encounter_id: String = ""
var expected_boss_level: int = -1
var expected_difficulty: int = -1

func _init(p_node_index: int = -1, expected_node: Dictionary = {}) -> void:
	super._init(&"SelectPathAction")
	node_index = p_node_index
	expected_node_type = String(expected_node.get("node_type", ""))
	expected_subtype = String(expected_node.get("subtype", ""))
	expected_encounter_id = String(expected_node.get("encounter_id", ""))
	expected_boss_level = int(expected_node.get("boss_level", -1))
	expected_difficulty = int(expected_node.get("difficulty", -1))

func validate() -> bool:
	if node_index < 0:
		return false
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.run_state):
		return false
	if GameManager.run_state.available_path_nodes.is_empty():
		return false
	if node_index >= GameManager.run_state.available_path_nodes.size():
		return false
	var node_def: PathNodeDefinition = GameManager.run_state.available_path_nodes[node_index]
	if not expected_node_type.is_empty() and String(node_def.node_type) != expected_node_type:
		return false
	if not expected_subtype.is_empty() and String(node_def.subtype) != expected_subtype:
		return false
	if not expected_encounter_id.is_empty() and String(node_def.encounter_id) != expected_encounter_id:
		return false
	if expected_boss_level >= 0 and node_def.boss_level != expected_boss_level:
		return false
	if expected_difficulty >= 0 and node_def.difficulty != expected_difficulty:
		return false
	return true

func execute() -> void:
	var node_def = GameManager.run_state.available_path_nodes[node_index]
	GameManager.run_state.available_path_nodes.clear()
	GameManager._on_node_selected(node_def)

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["node_index"] = node_index
	d["expected_node_type"] = expected_node_type
	d["expected_subtype"] = expected_subtype
	d["expected_encounter_id"] = expected_encounter_id
	d["expected_boss_level"] = expected_boss_level
	d["expected_difficulty"] = expected_difficulty
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	node_index = int(data.get("node_index", -1))
	expected_node_type = String(data.get("expected_node_type", ""))
	expected_subtype = String(data.get("expected_subtype", ""))
	expected_encounter_id = String(data.get("expected_encounter_id", ""))
	expected_boss_level = int(data.get("expected_boss_level", -1))
	expected_difficulty = int(data.get("expected_difficulty", -1))
