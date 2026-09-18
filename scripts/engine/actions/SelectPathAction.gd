# res://scripts/engine/actions/SelectPathAction.gd
class_name SelectPathAction
extends GameAction

var node_index: int = -1

func _init(p_node_index: int = -1) -> void:
	super._init(&"SelectPathAction")
	node_index = p_node_index

func validate() -> bool:
	if node_index < 0:
		return false
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.run_state):
		return false
	if GameManager.run_state.available_path_nodes.is_empty():
		return false
	if node_index >= GameManager.run_state.available_path_nodes.size():
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
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	node_index = int(data.get("node_index", -1))
