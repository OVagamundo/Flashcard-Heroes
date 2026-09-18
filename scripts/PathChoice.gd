# res://scripts/PathChoice.gd
extends Control

const NodeViewScene = preload("res://scenes/NodeView.tscn")
const SELECTION_TRANSITION_DELAY: float = 0.12

@onready var node_container: HBoxContainer = $CenterContainer/HBoxContainer
var _selection_locked: bool = false
var _node_views: Array[NodeView] = []

func _ready() -> void:
	# AUDIO HOOK: Path Choice BGM
	Audio.play_music(SoundRegistry.BGM_PATHCHOICE)
	
	var nodes: Array[PathNodeDefinition] = []
	if is_instance_valid(GameManager.run_state):
		nodes = GameManager.run_state.available_path_nodes
	
	for node_def in nodes:
		var node_view = NodeViewScene.instantiate()
		node_view.populate(node_def)
		_register_node_view(node_view)
	
	# Show path choice tutorial (1 page)
	TutorialManager.show_tutorial(&"path_choice_intro", [
		{"text": tr("tutorial.path_choice_1")}
	], node_container)

func _register_node_view(node_view: NodeView) -> void:
	node_view.node_selected.connect(_on_node_selected)
	node_container.add_child(node_view)
	_node_views.append(node_view)

func _on_node_selected(node_def: PathNodeDefinition) -> void:
	if _selection_locked:
		return
	_selection_locked = true
	for node_view in _node_views:
		if is_instance_valid(node_view):
			node_view.disabled = true
	await AnimationConstants.create_pausable_timer(get_tree(), SELECTION_TRANSITION_DELAY).timeout
	var idx = -1
	if is_instance_valid(GameManager.run_state):
		idx = GameManager.run_state.available_path_nodes.find(node_def)
	if idx != -1 and is_instance_valid(ActionQueue):
		var action := SelectPathAction.new(idx)
		ActionQueue.request(action)
	else:
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.available_path_nodes.clear()
		SignalBus.emit_signal("node_selected", node_def)
