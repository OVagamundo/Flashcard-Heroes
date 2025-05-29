extends Control

@onready var player_units_container: HBoxContainer = $MainContainer/BattleArea/PlayerSide/PlayerUnits
@onready var enemy_units_container: HBoxContainer = $MainContainer/BattleArea/EnemySide/EnemyUnits
@onready var battle_log: TextEdit = $MainContainer/BattleLog
@onready var end_turn_button: Button = $MainContainer/Actions/EndTurnButton
@onready var gacha_button: Button = $MainContainer/Actions/GachaButton
@onready var player_health_label: Label = $MainContainer/Header/PlayerInfo/PlayerHealth
@onready var gacha_tokens_label: Label = $MainContainer/Header/PlayerInfo/GachaTokens
@onready var turn_indicator: Label = $MainContainer/Header/TurnIndicator

const MAX_UNITS_PER_SIDE = 6 # As per GDD
const UNIT_SCENE = preload("res://scenes/Unit.tscn")

# Gacha system variables
var gacha_tokens: int = 5  # Starting Gacha Tokens as per GDD

# Arrays to hold references to the slot Node2D or Control nodes in the scene
var player_slot_nodes: Array[Node] = []
var enemy_slot_nodes: Array[Node] = []

# Arrays to hold actual unit instances
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var is_player_turn: bool = true

func _ready() -> void:
	# Connect button signals (can be kept, but their actions will be simplified)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	gacha_button.pressed.connect(_on_gacha_pressed)
	
	# EventBus connections (can be kept, but signals won't be emitted by battle logic for now)
	# EventBus.unit_spawned.connect(_on_unit_spawned)
	# EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_died.connect(_on_unit_died_eventbus) # Connect to the new handler
	# EventBus.battle_ended.connect(_on_battle_ended)
	
	# Initialize battle visuals and gacha system
	setup_battle_scene()
	# _initialize_gacha_pool() # Removed, UnitLibrary is used directly
	_spawn_initial_units() # Spawn units after scene setup
	_update_gacha_tokens_display() # Renamed from _update_coin_display

func setup_battle_scene() -> void:
	clear_all_slots() # Clear any previous children
	setup_visual_slots() # Populate the slot node arrays
	
	is_player_turn = true
	update_turn_indicator()
	
	# Buttons can be enabled, but their functionality will be placeholder
	end_turn_button.disabled = false 
	gacha_button.disabled = false
	
	add_log_message("Battle scene initialized. Lineup slots displayed.")

func clear_all_slots() -> void:
	# Clear units from player slots
	for slot_node in player_slot_nodes:
		if is_instance_valid(slot_node):
			for child in slot_node.get_children():
				if is_instance_valid(child) and child is Unit:
					child.queue_free()
	# Clear units from enemy slots
	for slot_node in enemy_slot_nodes:
		if is_instance_valid(slot_node):
			for child in slot_node.get_children():
				if is_instance_valid(child) and child is Unit:
					child.queue_free()
	
	player_units.clear() # Also clear logical unit arrays
	enemy_units.clear()

# New function to get references to the slot nodes from the scene
func setup_visual_slots() -> void:
	player_slot_nodes.clear()
	enemy_slot_nodes.clear()

	# Setup player slots
	for i in range(player_units_container.get_child_count()):
		var slot_node = player_units_container.get_child(i)
		if is_instance_valid(slot_node):
			player_slot_nodes.append(slot_node)
		else:
			push_warning("Battle.setup_visual_slots(): Invalid player slot node at index %d" % i)

	# Setup enemy slots
	for i in range(enemy_units_container.get_child_count()):
		var slot_node = enemy_units_container.get_child(i)
		if is_instance_valid(slot_node):
			enemy_slot_nodes.append(slot_node)
		else:
			push_warning("Battle.setup_visual_slots(): Invalid enemy slot node at index %d" % i)

	# Reverse enemy_slot_nodes if populated, to make index 0 the rightmost visual slot
	# This assumes EnemyUnitContainer (HBoxContainer) lays out children Left-to-Right,
	# and we want to mirror player's LTR spawning by having enemies spawn effectively RTL.
	if not enemy_slot_nodes.is_empty():
		enemy_slot_nodes.reverse()
		add_log_message("Battle.setup_visual_slots(): Enemy slots reversed. Index 0 is now rightmost.")

	# Initialize/resize the logical unit arrays to match the number of visual slots
	player_units.resize(player_slot_nodes.size())
	for i in range(player_units.size()):
		player_units[i] = null
	
	enemy_units.resize(enemy_slot_nodes.size())
	for i in range(enemy_units.size()):
		enemy_units[i] = null
	
	add_log_message("Battle.setup_visual_slots(): Setup complete. Player slots: %d, Enemy slots: %d (logical count after potential reverse)" % [player_slot_nodes.size(), enemy_slot_nodes.size()])

func _spawn_initial_units() -> void:
	_spawn_hero_unit()
	_generate_enemy_lineup()

func _spawn_hero_unit() -> void:
	if not UnitLibrary:
		push_error("Battle._spawn_hero_unit(): UnitLibrary autoload not found!")
		return

	var hero_data: UnitData = UnitLibrary.get_unit_data("hero")
	if not hero_data:
		push_error("Battle._spawn_hero_unit(): Could not retrieve Hero data from UnitLibrary.")
		return

	if player_slot_nodes.is_empty():
		push_warning("Battle._spawn_hero_unit(): No player slots available for Hero.")
		return

	# GDD: Hero automatically starts in the backmost available Lineup slot.
	# Assuming player slots are 0 (front/left) to N-1 (back/right).
	var hero_slot_index = player_slot_nodes.size() - 1 
	_spawn_unit(hero_data, true, hero_slot_index)
	add_log_message("Hero unit '%s' spawned in slot %d." % [hero_data.display_name, hero_slot_index])

func _generate_enemy_lineup() -> void:
	if not UnitLibrary:
		push_error("Battle._generate_enemy_lineup(): UnitLibrary autoload not found!")
		return

	var num_enemies = randi_range(3, min(6, enemy_slot_nodes.size())) # 3 to 6 enemies, capped by available slots
	add_log_message("Generating %d enemies." % num_enemies)

	var enemy_options: Array[UnitData] = UnitLibrary.get_enemy_pool_t1()
	if enemy_options.is_empty():
		push_warning("Battle._generate_enemy_lineup(): No T1 enemy types available in UnitLibrary.")
		return

	for i in range(num_enemies):
		if i >= enemy_slot_nodes.size():
			push_warning("Battle._generate_enemy_lineup(): Not enough enemy slots for %d enemies. Stopping at %d." % [num_enemies, i])
			break
		
		var random_enemy_data: UnitData = enemy_options.pick_random()
		if random_enemy_data:
			# Enemies spawn from their front (index 0 of reversed enemy_slot_nodes) to back
			_spawn_unit(random_enemy_data, false, i)
			add_log_message("Spawned enemy '%s' in enemy slot %d." % [random_enemy_data.display_name, i])
		else:
			push_warning("Battle._generate_enemy_lineup(): Failed to pick random enemy data.")

func _spawn_unit(unit_data: UnitData, is_player_team: bool, slot_index: int):
	if not UNIT_SCENE:
		push_error("Battle._spawn_unit(): UNIT_SCENE is not loaded.")
		return null
	if not unit_data:
		push_error("Battle._spawn_unit(): unit_data is null.")
		return null

	var unit_instance: Unit = UNIT_SCENE.instantiate() as Unit
	if not unit_instance:
		push_error("Battle._spawn_unit(): Failed to instantiate UNIT_SCENE.")
		return null

	var target_slot_node: Control
	var team_tint: Color

	if is_player_team:
		if slot_index < 0 or slot_index >= player_slot_nodes.size():
			push_error("Battle._spawn_unit(): Invalid player slot_index %d (max %d)." % [slot_index, player_slot_nodes.size() -1])
			unit_instance.queue_free()
			return null
		target_slot_node = player_slot_nodes[slot_index]
		team_tint = Color(0.7, 0.7, 1.0) # Light blue for player
		unit_instance.name = "PlayerUnit_%d" % slot_index
	else:
		if slot_index < 0 or slot_index >= enemy_slot_nodes.size():
			push_error("Battle._spawn_unit(): Invalid enemy slot_index %d (max %d)." % [slot_index, enemy_slot_nodes.size() -1])
			unit_instance.queue_free()
			return null
		target_slot_node = enemy_slot_nodes[slot_index]
		team_tint = Color(1.0, 0.7, 0.7) # Light red for enemy
		unit_instance.name = "EnemyUnit_%d" % slot_index

	if not is_instance_valid(target_slot_node):
		push_error("Battle._spawn_unit(): Target slot_node is invalid for team %s, slot %d." % [("player" if is_player_team else "enemy"), slot_index])
		unit_instance.queue_free()
		return null

	# Clear any existing unit from the target slot
	for child in target_slot_node.get_children():
		if is_instance_valid(child) and child is Unit:
			child.queue_free()

	# Add to the scene as a child of the slot node
	target_slot_node.add_child(unit_instance)
	
	# Set proper anchoring to ensure the unit moves with window resizing
	# Configure anchors first - this is key for proper responsive layout
	unit_instance.anchor_left = 0.0
	unit_instance.anchor_top = 1.0  # Anchor top to bottom of parent (like floor)
	unit_instance.anchor_right = 1.0 # Stretch horizontally
	unit_instance.anchor_bottom = 1.0 # Anchor bottom to bottom of parent
	
	# Set margins to position correctly relative to anchors
	unit_instance.offset_left = 0 # Left edge at parent's left
	unit_instance.offset_right = 0 # Right edge at parent's right
	unit_instance.offset_bottom = 0 # Bottom edge at parent's bottom
	unit_instance.offset_top = -unit_instance.custom_minimum_size.y # Top edge based on unit's height
	
	# Make it grow from the bottom (like the floor rectangle)
	unit_instance.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Initialize the unit after setting anchors
	unit_instance.initialize(unit_data, is_player_team, team_tint)
	
	add_log_message("Unit '%s' anchored to bottom of slot with responsive layout" % [unit_instance.name])
	
	# Add to the appropriate team array
	if is_player_team:
		player_units[slot_index] = unit_instance
	else:
		enemy_units[slot_index] = unit_instance

	# Connect signals
	unit_instance.unit_died.connect(_on_unit_died_eventbus)
	EventBus.unit_spawned.emit(unit_instance, is_player_team, slot_index)

	# No need for deferred positioning since we're using anchors
	return unit_instance

# This function is no longer needed since we're using anchors for positioning
# Keeping it as a stub for compatibility with any existing calls
func _finalize_unit_position(unit: Unit, slot_node: Control) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(slot_node):
		push_warning("Battle._finalize_unit_position: Unit or slot_node is invalid.")
		return
	
	# Units now use anchors for positioning, so no manual position calculation is needed
	add_log_message("Unit '%s' positioned using anchors (Control.PRESET_BOTTOM_WIDE)" % [unit.name if unit.name else 'Unknown'])

func _on_end_turn_pressed() -> void:
	add_log_message("End Turn pressed. Placeholder.")
	# Basic turn toggle for now
	is_player_turn = not is_player_turn
	update_turn_indicator()
	# Actual combat logic will go here in the future

func _on_gacha_pressed() -> void:
	if not UnitLibrary:
		push_error("Battle._on_gacha_pressed(): UnitLibrary autoload not found!")
		return

	if gacha_tokens >= 1:
		gacha_tokens -= 1
		_update_gacha_tokens_display()
		
		var gacha_options: Array[UnitData] = UnitLibrary.get_gacha_pool_t1()
		if gacha_options.is_empty():
			add_log_message("Gacha pool is empty!")
			return

		var drawn_unit_data: UnitData = gacha_options.pick_random()
		
		if not drawn_unit_data:
			add_log_message("Failed to draw unit from gacha (pool might be okay, but pick_random failed).")
			return

		add_log_message("Gacha draw: %s" % drawn_unit_data.display_name)

		var placed_in_slot = -1
		# Try to place in the first available player slot (front to back)
		for i in range(player_units.size()):
			if player_units[i] == null: # Check if logical slot is empty
				# Check if visual slot node is valid before spawning
				if i < player_slot_nodes.size() and is_instance_valid(player_slot_nodes[i]):
					_spawn_unit(drawn_unit_data, true, i)
					add_log_message("Gacha unit '%s' placed in player slot %d." % [drawn_unit_data.display_name, i])
					placed_in_slot = i
					break
				else:
					push_warning("Battle._on_gacha_pressed(): Player slot node %d is invalid, cannot place unit." % i)
					# Potentially try next slot or handle error
		
		if placed_in_slot == -1:
			add_log_message("No empty player slots to place gacha unit.")
			# Optional: refund token or handle full bench
			# gacha_tokens += 1 
			# _update_gacha_tokens_display()
	else:
		add_log_message("Not enough Gacha Tokens (requires 1). Have: %d" % gacha_tokens)

func _update_gacha_tokens_display() -> void:
	if gacha_tokens_label:
		gacha_tokens_label.text = "Tokens: %d" % gacha_tokens

func _get_frontmost_live_unit(unit_array: Array[Unit]) -> Variant:
	if unit_array.is_empty():
		return null
		
	# Check if this is the player or enemy team
	var is_player_team = unit_array == player_units
	
	# For both teams, the frontmost unit is the one with the highest index in their respective arrays
	# because enemy_slot_nodes were already reversed during setup
	for i in range(unit_array.size() - 1, -1, -1):
		var unit = unit_array[i]
		if is_instance_valid(unit) and unit.current_hp > 0:
			return unit
			
	return null

func update_turn_indicator() -> void:
	if end_turn_button.disabled: # Battle is over
		return
		
	if player_units.is_empty() and enemy_units.is_empty():
		# This condition might be met briefly during setup if called before _spawn_initial_units
		turn_indicator.text = "Preparing Battle..."
		turn_indicator.add_theme_color_override("font_color", Color.WHITE) # Neutral color
		return

	if is_player_turn:
		turn_indicator.text = "Player's Turn"
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) # Green
	else:
		turn_indicator.text = "Enemy's Turn"
		turn_indicator.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2)) # Red

func add_log_message(message: String) -> void:
	var timestamp = "[%s] " % Time.get_time_string_from_system(false) # Corrected: removed extra arg
	if battle_log.text.is_empty():
		battle_log.text = timestamp + message
	else:
		battle_log.text += "\n" + timestamp + message
	battle_log.scroll_vertical = INF

func _on_unit_died_eventbus(unit_died: Unit) -> void:
	if not is_instance_valid(unit_died):
		return

	var unit_name = unit_died.get_name_for_log() # Use the helper for consistent naming
	add_log_message("EventBus: Unit %s died." % unit_name)

	var unit_parent_slot = unit_died.get_parent() # The slot node

	var removed_from_player = false
	if player_units.has(unit_died):
		player_units.erase(unit_died)
		removed_from_player = true

	var removed_from_enemy = false
	if enemy_units.has(unit_died):
		enemy_units.erase(unit_died)
		removed_from_enemy = true

	if removed_from_player:
		add_log_message("%s removed from player units." % unit_name)
	if removed_from_enemy:
		add_log_message("%s removed from enemy units." % unit_name)
	
	# Visually remove the unit from the scene
	if is_instance_valid(unit_died):
		unit_died.queue_free()

	# Optional: Add a placeholder or 'empty' visual back to the unit_parent_slot if needed
	# For example, if you had a 'tombstone' or 'empty slot' visual to show.
	# if is_instance_valid(unit_parent_slot):
	#    pass # logic to restore slot visual if it was changed by unit presence

	# Check for win/loss conditions only if the battle isn't already marked as ended
	if not end_turn_button.disabled:
		if player_units.is_empty() and not enemy_units.is_empty():
			add_log_message("All player units defeated! Enemy wins!")
			EventBus.battle_ended.emit(false) # Player lost
			_end_battle_actions(false)
		elif enemy_units.is_empty() and not player_units.is_empty():
			add_log_message("All enemy units defeated! Player wins!")
			EventBus.battle_ended.emit(true) # Player won
			_end_battle_actions(true)
		elif player_units.is_empty() and enemy_units.is_empty():
			# This case could happen if the last units on both sides die simultaneously
			add_log_message("All units defeated! It's a draw!")
			EventBus.battle_ended.emit(false) # Consider a draw as a loss or specific state
			_end_battle_actions(false)

func _end_battle_actions(player_won: bool) -> void:
	end_turn_button.disabled = true
	gacha_button.disabled = true
	
	# Don't reset coins here since we want to keep them during battle
	# They'll be reset when a new battle starts
	
	if player_won:
		add_log_message("Victory!")
	else:
		add_log_message("Defeat!")
	add_log_message("Battle ended. Player %s." % ["won" if player_won else "lost"])
	var message = "Player Won!" if player_won else "Player Lost!"
	turn_indicator.text = "Battle Over: %s" % message
	if player_won:
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright Green
	else:
		turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Bright Red
