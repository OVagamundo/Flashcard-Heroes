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
			# print("[PathChoice] Loading from save, skipping day advance. Current Day: ", GameManager.run_state.day)
			GameManager.loading_from_save = false
		else:
			GameManager.run_state.advance_day(1)
			# Save checkpoint after day advances
			SaveManager.save_run(GameManager.run_state)
	
	_update_director_run_state(DirectorRunState.Purpose.NODE_GENERATION)
	
	var is_half_deck = false
	if is_instance_valid(GameManager.run_state):
		is_half_deck = GameManager.run_state.is_half_deck
		
	# Check for boss based on deck unlock percentage
	var boss_level: int = GameManager.run_state.bosses_defeated + 1
	var threshold: float = boss_level * 0.2
	var max_bosses: int = 5
	
	if is_half_deck:
		threshold = boss_level * 0.3333
		max_bosses = 3
	
	# Use a small epsilon to handle float precision issues
	if director_run_state.unlock_percentage >= (threshold - 0.001) and boss_level <= max_bosses:
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
	# Create potential node versions
	var types = [
		{"type": "BATTLE", "subtype": "", "name": "ui.battle_node"},
		{"type": "BATTLE", "subtype": "ELITE", "name": "ui.elite_battle_node"},
		{"type": "SHOP", "subtype": "", "name": "ui.shop_node"},
		{"type": "BLACK_MARKET", "subtype": "", "name": "ui.black_market_node"},
		{"type": "REST", "subtype": "", "name": "ui.rest_node"},
		{"type": "DOJO", "subtype": "", "name": "ui.training_grounds_node"},
		{"type": "SURPRISE", "subtype": "", "name": "ui.surprise_node"}
	]
	
	var pool: Array[PathNodeDefinition] = []
	var current_day = 1
	if is_instance_valid(GameManager.run_state):
		current_day = GameManager.run_state.day
		
	for t in types:
		# Calculate base weight according to rules
		var base_w = 50
		if t.type == "BATTLE" and t.subtype == "":
			base_w = 100
		elif t.type == "BATTLE" and t.subtype == "ELITE":
			var is_half = false
			if is_instance_valid(GameManager.run_state):
				is_half = GameManager.run_state.is_half_deck
			var elite_day_threshold = 3 if is_half else 5
			if current_day < elite_day_threshold:
				base_w = 20
			else:
				base_w = 80
				
		# Apply pity system multiplier
		var dict_key = t.type
		if t.subtype != "":
			dict_key += "_" + t.subtype
			
		var last_offered = 0
		if is_instance_valid(GameManager.run_state):
			last_offered = GameManager.run_state.encounter_last_offered_day.get(dict_key, 0)
			
		var days_since = current_day - last_offered
		var final_weight = base_w + (days_since * 20)
		
		# print("[PathChoice] Generated weight for ", dict_key, " -> Base: ", base_w, " Pity: ", days_since * 20, " Final: ", final_weight)
		
		var def = PathNodeDefinition.new()
		def.node_type = t.type
		def.subtype = t.subtype
		def.display_name_key = t.name
		def.base_weight = final_weight
		pool.append(def)
	
	# Draw 3 unique nodes one by one to ensure categorical uniqueness
	var selected_nodes: Array[PathNodeDefinition] = []
	for i in range(3):
		if pool.is_empty():
			break
			
		var drawn = director.draw_item(pool, director_run_state)
		if is_instance_valid(drawn):
			selected_nodes.append(drawn)
			# Filter pool to remove any node with the same type/subtype pair
			var next_pool: Array[PathNodeDefinition] = []
			for p in pool:
				if p.node_type != drawn.node_type or p.subtype != drawn.subtype:
					next_pool.append(p)
			pool = next_pool

	for node_def in selected_nodes:
		if is_instance_valid(GameManager.run_state):
			var dict_key = node_def.node_type
			if node_def.subtype != "":
				dict_key += "_" + node_def.subtype
			GameManager.run_state.encounter_last_offered_day[dict_key] = GameManager.run_state.day
			
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
	await AnimationConstants.create_pausable_timer(get_tree(), SELECTION_TRANSITION_DELAY).timeout
	SignalBus.emit_signal("node_selected", node_def)
