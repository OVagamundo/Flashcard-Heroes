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
const UNIT_SCENE = preload("res://scenes/Unit.tscn") # Will be used later
const OFFENSIVE_T1_UNIT_DATA = preload("res://scripts/OffensiveT1UnitData.tres")

# Will hold references to the slot containers
var player_slot_nodes: Array[Node] = []
var enemy_slot_nodes: Array[Node] = []
var is_player_turn: bool = true

# Arrays to hold actual unit instances
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

func _ready() -> void:
	# Connect button signals (can be kept, but their actions will be simplified)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	gacha_button.pressed.connect(_on_gacha_pressed)
	
	# EventBus connections (can be kept, but signals won't be emitted by battle logic for now)
	# EventBus.unit_spawned.connect(_on_unit_spawned)
	# EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_died.connect(_on_unit_died_eventbus) # Connect to the new handler
	# EventBus.battle_ended.connect(_on_battle_ended)
	
	# Initialize battle visuals
	setup_battle_scene()
	_spawn_initial_units() # Spawn units after scene setup

func setup_battle_scene() -> void:
	clear_all_slots() # Clear any previous children
	setup_visual_slots()
	
	is_player_turn = true
	update_turn_indicator()
	
	# Buttons can be enabled, but their functionality will be placeholder
	end_turn_button.disabled = false 
	gacha_button.disabled = false
	
	add_log_message("Battle scene initialized. Lineup slots displayed.")

func clear_all_slots() -> void:
	for container in [player_units_container, enemy_units_container]:
		if not is_instance_valid(container):
			push_warning("clear_all_slots(): Invalid container provided.")
			continue
		for slot_node in container.get_children(): # These are PlayerSlotX/EnemySlotX nodes (VBoxContainers)
			if not is_instance_valid(slot_node):
				continue
			# Iterate over a copy of children array because queue_free modifies it
			for unit_candidate in slot_node.get_children().duplicate(): 
				if is_instance_valid(unit_candidate) and unit_candidate is Unit:
					unit_candidate.queue_free() # Only remove actual Unit instances
	player_slot_nodes.clear()
	enemy_slot_nodes.clear()
	player_units.clear() # Also clear logical unit arrays
	enemy_units.clear()

func setup_visual_slots() -> void:
	# Clear any existing references
	player_slot_nodes.clear()
	enemy_slot_nodes.clear()
	
	var temp_player_slots: Array[Node] = []
	# Get all slot containers (they should be pre-made in the scene)
	for i in range(1, MAX_UNITS_PER_SIDE + 1):
		# Player slots (collect them in natural order first)
		var player_slot = player_units_container.get_node_or_null("PlayerSlot" + str(i))
		if player_slot:
			temp_player_slots.append(player_slot)
			
		# Enemy slots (collected in natural L-R order, assuming EnemySlot1 is frontmost for enemy)
		var enemy_slot = enemy_units_container.get_node_or_null("EnemySlot" + str(i))
		if enemy_slot:
			enemy_slot_nodes.append(enemy_slot)

	# Reverse the player slots so index 0 is the rightmost (e.g., PlayerSlot6)
	player_slot_nodes = temp_player_slots.duplicate() # Make a copy
	player_slot_nodes.reverse()
	
	# Log the setup
	add_log_message("Visual slots set up. Found %d player slots and %d enemy slots." % 
		[player_slot_nodes.size(), enemy_slot_nodes.size()])
	
	# For debugging, print the order:
	# print("Player Slots Order (index 0 should be frontmost/rightmost):")
	# for i in range(player_slot_nodes.size()):
	# 	print("  Player Slot Index ", i, ": ", player_slot_nodes[i].name)
	# print("Enemy Slots Order (index 0 should be frontmost/leftmost):")
	# for i in range(enemy_slot_nodes.size()):
	# 	print("  Enemy Slot Index ", i, ": ", enemy_slot_nodes[i].name)

func _spawn_unit(unit_data: UnitData, is_player_team: bool, slot_index: int) -> Unit:
	if not UNIT_SCENE:
		push_error("Battle._spawn_unit(): UNIT_SCENE is not loaded.")
		return null
	if not unit_data:
		push_error("Battle._spawn_unit(): unit_data is null.")
		return null

	var unit_instance: Unit = UNIT_SCENE.instantiate()
	if not unit_instance:
		push_error("Battle._spawn_unit(): Failed to instantiate UNIT_SCENE.")
		return null

	# Define tint colors for player and enemy units
	var player_tint = Color(0.7, 0.7, 1.0, 0.8) # Light blueish tint
	var enemy_tint = Color(1.0, 0.7, 0.7, 0.8) # Light reddish tint
	var tint_to_apply = player_tint if is_player_team else enemy_tint

	unit_instance.initialize(unit_data, is_player_team, tint_to_apply) # Initialize with data, team, and color

	var target_container_slots: Array[Node]
	var target_unit_array: Array[Unit]
	var unit_name_prefix: String

	if is_player_team:
		target_container_slots = player_slot_nodes
		target_unit_array = player_units
		unit_name_prefix = "PlayerUnit_"
		unit_instance.set_meta("team", "player")
	else:
		target_container_slots = enemy_slot_nodes
		target_unit_array = enemy_units
		unit_name_prefix = "EnemyUnit_"
		unit_instance.set_meta("team", "enemy")

	if slot_index >= 0 and slot_index < target_container_slots.size():
		var slot_node = target_container_slots[slot_index]
		# Clear any existing UNIT in the slot before adding the new one
		for child in slot_node.get_children():
			if child is Unit: # Check if the child is a Unit instance
				child.queue_free()
		
		slot_node.add_child(unit_instance)
		unit_instance.name = "%s%s_%d" % [unit_name_prefix, unit_data.unit_name.replace(" ", ""), slot_index + 1]
		target_unit_array.append(unit_instance)
		
		# Apply team-specific appearance (moved from Unit.gd for central control)
		if not is_player_team: # Enemy
			unit_instance.self_modulate = Color(1, 0.8, 0.8)  # Slight red tint
		
		EventBus.unit_spawned.emit(unit_instance)
		add_log_message("Spawned %s in %s slot %d" % [unit_instance.name, "player" if is_player_team else "enemy", slot_index + 1])
		return unit_instance
	else:
		push_error("Battle._spawn_unit(): Invalid slot_index %d for team %s (slots available: %d)" % [slot_index, "player" if is_player_team else "enemy", target_container_slots.size()])
		unit_instance.queue_free() # Clean up unparented instance
		return null

func _spawn_initial_units() -> void:
	if not OFFENSIVE_T1_UNIT_DATA:
		push_error("Battle._spawn_initial_units(): OFFENSIVE_T1_UNIT_DATA not loaded.")
		return

	add_log_message("Spawning initial units...")
	# Spawn 2 player units (Offensive T1)
	for i in range(2):
		if i < player_slot_nodes.size():
			_spawn_unit(OFFENSIVE_T1_UNIT_DATA, true, i)
		else:
			add_log_message("Warning: Not enough player slots to spawn unit %d" % (i+1))
			
	# Spawn 3 enemy units (Offensive T1)
	for i in range(3):
		if i < enemy_slot_nodes.size():
			_spawn_unit(OFFENSIVE_T1_UNIT_DATA, false, i)
		else:
			add_log_message("Warning: Not enough enemy slots to spawn unit %d" % (i+1))
	update_turn_indicator() # Update indicator after units are potentially spawned

# Temporarily simplify button actions
func _on_end_turn_pressed() -> void:
	if end_turn_button.disabled:
		return

	if is_player_turn:
		add_log_message("Player's turn actions:")
		var any_player_action_taken = false
		# Iterate over a shallow copy in case the array is modified (e.g., a unit dies from counter-attack)
		for acting_player_unit in player_units.duplicate(false):
			if not is_instance_valid(acting_player_unit) or acting_player_unit.current_hp <= 0:
				continue # Skip dead or invalid units

			var target_enemy_unit = _get_frontmost_live_unit(enemy_units) # Get current frontmost enemy

			if target_enemy_unit:
				add_log_message("Player Unit %s attacks Enemy Unit %s." % [acting_player_unit.get_name_for_log(), target_enemy_unit.get_name_for_log()])
				acting_player_unit.perform_basic_attack(target_enemy_unit)
				any_player_action_taken = true
				# If target_enemy_unit dies, _on_unit_died_eventbus handles removal.
				# The next iteration's _get_frontmost_live_unit will find the new front.
			else:
				add_log_message("Player Unit %s has no live enemy units to target." % acting_player_unit.get_name_for_log())
				break # No more enemies, player turn actions can stop
		
		if not any_player_action_taken and player_units.size() > 0:
			add_log_message("No player units could act this turn.")
		elif player_units.is_empty() and not end_turn_button.disabled: # Check disabled to avoid log if battle just ended
			add_log_message("No player units remaining to act.")

		is_player_turn = false
	else: # Enemy's turn
		add_log_message("Enemy's turn actions:")
		var any_enemy_action_taken = false
		# Iterate over a shallow copy for safety
		for acting_enemy_unit in enemy_units.duplicate(false):
			if not is_instance_valid(acting_enemy_unit) or acting_enemy_unit.current_hp <= 0:
				continue # Skip dead or invalid units

			var target_player_unit = _get_frontmost_live_unit(player_units) # Get current frontmost player unit

			if target_player_unit:
				add_log_message("Enemy Unit %s attacks Player Unit %s." % [acting_enemy_unit.get_name_for_log(), target_player_unit.get_name_for_log()])
				acting_enemy_unit.perform_basic_attack(target_player_unit)
				any_enemy_action_taken = true
			else:
				add_log_message("Enemy Unit %s has no live player units to target." % acting_enemy_unit.get_name_for_log())
				break # No more player units, enemy turn actions can stop

		if not any_enemy_action_taken and enemy_units.size() > 0:
			add_log_message("No enemy units could act this turn.")
		elif enemy_units.is_empty() and not end_turn_button.disabled:
			add_log_message("No enemy units remaining to act.")
		
		is_player_turn = true
	
	update_turn_indicator()

func _on_gacha_pressed() -> void:
	add_log_message("Gacha button pressed. (Functionality pending unit implementation)")

func _get_frontmost_live_unit(unit_array: Array[Unit]) -> Unit:
	for unit in unit_array:
		if is_instance_valid(unit) and unit.current_hp > 0:
			return unit
	return null

func update_turn_indicator() -> void:
	if end_turn_button.disabled: # Battle is over
		return
		
	if player_units.is_empty() and enemy_units.is_empty() and not player_slot_nodes.is_empty():
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
	add_log_message("Battle ended. Player %s." % ["won" if player_won else "lost"])
	end_turn_button.disabled = true
	gacha_button.disabled = true # Or other relevant UI changes
	var message = "Player Won!" if player_won else "Player Lost!"
	turn_indicator.text = "Battle Over: %s" % message
	if player_won:
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright Green
	else:
		turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Bright Red
