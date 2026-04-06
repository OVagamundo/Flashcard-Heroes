# res://scripts/PathChoice.gd
extends Control

const NodeViewScene = preload("res://scenes/NodeView.tscn")
const SELECTION_TRANSITION_DELAY: float = 0.12

@onready var node_container: HBoxContainer = $CenterContainer/HBoxContainer
var _selection_locked: bool = false
var _node_views: Array[NodeView] = []

var director: WeightedPoolDirector = WeightedPoolDirector.new()
var director_run_state: DirectorRunState = DirectorRunState.new()

func _update_director_run_state(purpose: int = DirectorRunState.Purpose.ANY) -> void:
	if is_instance_valid(GameManager.run_state):
		director_run_state.current_day = GameManager.run_state.day
		director_run_state.player_gold = GameManager.run_state.gold
		director_run_state.unlock_percentage = GameManager.run_state.get_deck_unlock_percentage()
		director_run_state.current_purpose = purpose as DirectorRunState.Purpose

func _ready() -> void:
	# AUDIO HOOK: Path Choice BGM
	Audio.play_music(SoundRegistry.BGM_PATHCHOICE)
	
	if is_instance_valid(GameManager.run_state):
		if GameManager.loading_from_save:
			print("[PathChoice] Loading from save, skipping day advance. Current Day: ", GameManager.run_state.day)
			GameManager.loading_from_save = false
		else:
			GameManager.run_state.advance_day(1)
			# Save checkpoint after day advances
			SaveManager.save_run(GameManager.run_state)
	
	_update_director_run_state(DirectorRunState.Purpose.NODE_GENERATION)
	
	# Check for boss based on deck unlock percentage (every 20%: 20%, 40%, 60%, 80%, 100%)
	var boss_level: int = GameManager.run_state.bosses_defeated + 1
	var threshold: float = boss_level * 0.2
	
	# Use a small epsilon to handle float precision issues
	if director_run_state.unlock_percentage >= (threshold - 0.001) and boss_level <= 5:
		_setup_boss_node(boss_level)
	else:
		_setup_normal_nodes()
	
	# Show path choice tutorial (1 page)
	TutorialManager.show_tutorial(&"path_choice_intro", [
		{"text": tr("tutorial.path_choice_1")}
	], node_container)

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
	_register_node_view(node_view)

## Sets up the normal 3-option path choice for non-boss days.
func _setup_normal_nodes() -> void:
	var pool: Array[PathNodeDefinition] = []
	
	# Create a pool of potential node types
	var types = [
		{"type": "BATTLE", "subtype": "", "name": "ui.battle_node", "weight": 100},
		{"type": "BATTLE", "subtype": "ELITE", "name": "ui.elite_battle_node", "weight": 30},
		{"type": "SHOP", "subtype": "", "name": "ui.shop_node", "weight": 50},
		{"type": "REST", "subtype": "", "name": "ui.rest_node", "weight": 50}
	]
	
	for t in types:
		var def = PathNodeDefinition.new()
		def.node_type = t.type
		def.subtype = t.subtype
		def.display_name_key = t.name
		def.base_weight = t.weight
		pool.append(def)
	
	# Use Director to draw 3 unique nodes
	var selected_nodes = director.draw_unique_items(pool, director_run_state, 3)

	for node_def in selected_nodes:
		var node_view = NodeViewScene.instantiate()
		node_view.populate(node_def)
		_register_node_view(node_view)

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
	await get_tree().create_timer(SELECTION_TRANSITION_DELAY).timeout
	SignalBus.emit_signal("node_selected", node_def)
