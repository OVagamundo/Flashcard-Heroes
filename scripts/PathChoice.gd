# res://scripts/PathChoice.gd
extends Control

const PathNodeDefinition = preload("res://scripts/PathNodeDefinition.gd")
const NodeViewScene = preload("res://scenes/NodeView.tscn")

@onready var node_container: HBoxContainer = $CenterContainer/HBoxContainer

func _ready() -> void:
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.advance_day(1)
	
	var current_day: int = 1
	if is_instance_valid(GameManager.run_state):
		current_day = GameManager.run_state.day
	
	# Check for boss day (every 5th day: 5, 10, 15, 20, 25)
	if current_day > 0 and current_day % 5 == 0:
		var boss_level: int = current_day / 5
		if boss_level >= 1 and boss_level <= 5:
			_setup_boss_node(boss_level)
		else:
			# Past boss 5, show normal nodes (shouldn't happen if game ends at boss 5)
			_setup_normal_nodes()
	else:
		_setup_normal_nodes()

## Sets up a single boss encounter button for boss days.
func _setup_boss_node(boss_level: int) -> void:
	var node_def = PathNodeDefinition.new()
	node_def.node_type = "BATTLE"
	node_def.subtype = "BOSS"
	node_def.display_name_key = "ui.boss"
	node_def.boss_level = boss_level
	node_def.difficulty = boss_level
	
	var node_view = NodeViewScene.instantiate()
	node_view.populate(node_def)
	node_view.node_selected.connect(_on_node_selected)
	node_container.add_child(node_view)

## Sets up the normal 3-option path choice for non-boss days.
func _setup_normal_nodes() -> void:
	var node_types = ["BATTLE", "SHOP", "REST"]
	node_types.shuffle()

	for i in range(3):
		var node_def = PathNodeDefinition.new()
		node_def.node_type = node_types[i]

		match node_def.node_type:
			"BATTLE":
				node_def.display_name_key = "ui.battle_node"
			"SHOP":
				node_def.display_name_key = "ui.shop_node"
			"REST":
				node_def.display_name_key = "ui.rest_node"

		var node_view = NodeViewScene.instantiate()
		node_view.populate(node_def)
		node_view.node_selected.connect(_on_node_selected)
		node_container.add_child(node_view)

func _on_node_selected(node_def: PathNodeDefinition) -> void:
	SignalBus.emit_signal("node_selected", node_def)
