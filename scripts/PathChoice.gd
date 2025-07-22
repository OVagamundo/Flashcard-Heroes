# res://scripts/PathChoice.gd
extends Control

const PathNodeDefinition = preload("res://scripts/data/PathNodeDefinition.gd")
const NodeViewScene = preload("res://scenes/NodeView.tscn")

@onready var node_container: HBoxContainer = $CenterContainer/HBoxContainer

var _path_nodes: Array = [] # Placeholder for PathNodeDefinition instances

func _ready():
	# Example: Populate with dummy PathNodeDefinitions for now
	for i in range(3):
		var node_def = PathNodeDefinition.new()
		node_def.node_type = "BATTLE" if i == 0 else "SHOP"
		node_def.display_name_key = "Battle Node" if i == 0 else "Shop Node %d" % i
		_path_nodes.append(node_def)

	for node_def in _path_nodes:
		var node_view = NodeViewScene.instantiate()
		node_view.populate(node_def)
		node_view.node_selected.connect(_on_node_selected)
		node_container.add_child(node_view)

func _on_node_selected(node_def):
	if node_def.node_type == "BATTLE":
		EventBus.emit_signal("battle_start_requested")
