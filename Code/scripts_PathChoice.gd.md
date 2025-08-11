<!-- Original: scripts/PathChoice.gd -->

```gdscript
# res://scripts/PathChoice.gd
extends Control

const PathNodeDefinition = preload("res://scripts/PathNodeDefinition.gd")
const NodeViewScene = preload("res://scenes/NodeView.tscn")

@onready var node_container: HBoxContainer = $CenterContainer/HBoxContainer

func _ready():
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.day += 1
		SignalBus.emit_signal("run_data_changed")

	var node_types = ["BATTLE", "SHOP", "REST"]
	node_types.shuffle()

	for i in range(3):
		var node_def = PathNodeDefinition.new()
		node_def.node_type = node_types[i]

		match node_def.node_type:
			"BATTLE":
				node_def.display_name_key = "Battle Node"
			"SHOP":
				node_def.display_name_key = "Shop Node"
			"REST":
				node_def.display_name_key = "Rest Site"

		var node_view = NodeViewScene.instantiate()
		node_view.populate(node_def)
		node_view.node_selected.connect(_on_node_selected)
		node_container.add_child(node_view)

func _on_node_selected(node_def: PathNodeDefinition):
	SignalBus.emit_signal("node_selected", node_def)

```