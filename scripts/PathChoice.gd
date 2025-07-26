# res://scripts/PathChoice.gd
extends Control

const PathNodeDefinition = preload("res://scripts/data/PathNodeDefinition.gd")
const NodeViewScene = preload("res://scenes/NodeView.tscn")

@onready var node_container: HBoxContainer = $CenterContainer/HBoxContainer

func _ready():
	# Increment day when path choice scene loads (starts at 0, first load makes it 1)
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.day += 1
		EventBus.emit_signal("run_data_changed")
	
	# Example: Populate with a mix of node types for testing.
	var node_types = ["BATTLE", "SHOP", "BATTLE"]
	node_types.shuffle()

	for i in range(3):
		var node_def = PathNodeDefinition.new()
		node_def.node_type = node_types[i]
		node_def.display_name_key = "Battle Node" if node_types[i] == "BATTLE" else "Shop Node"
		
		var node_view = NodeViewScene.instantiate()
		node_view.populate(node_def)
		# Connect to the NodeView's signal
		node_view.node_selected.connect(_on_node_selected)
		node_container.add_child(node_view)

# This function now correctly routes the node selection to the global EventBus.
func _on_node_selected(node_def: PathNodeDefinition):
	# Emit the generic node_selected signal for GameManager to handle.
	EventBus.emit_signal("node_selected", node_def)
