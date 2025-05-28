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
	
	# Initialize battle visuals
	setup_battle_scene()
	_spawn_initial_units() # Spawn units after scene setup

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

	# Ensure player_slot_nodes are in the visual order (right-to-left for player if HBox is LTR)
	# If your HBoxContainer for player units is standard (adds left to right), 
	# and you want slot_nodes[0] to be the rightmost (front), then reverse.
	# This depends on your specific scene setup for player_units_container children order.
	# Assuming player_slot_nodes[0] should be the front-most (often rightmost for player side)
	# If not, player_slot_nodes.reverse() might be needed here or how you iterate it.

	add_log_message("Found %d player slots and %d enemy slots." % [player_slot_nodes.size(), enemy_slot_nodes.size()])

func _spawn_unit(unit_data: UnitData, is_player_team: bool, slot_index: int):
	# Mark the function as async since we'll be using await
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

	# Add to the scene
	target_slot_node.add_child(unit_instance)
	
	# Initialize the unit
	unit_instance.initialize(unit_data, is_player_team, team_tint)
	
	# Add to the appropriate team array
	if is_player_team:
		player_units[slot_index] = unit_instance
	else:
		enemy_units[slot_index] = unit_instance

	# Connect signals
	unit_instance.unit_died.connect(_on_unit_died_eventbus)
	EventBus.unit_spawned.emit(unit_instance, is_player_team, slot_index)

	call_deferred("_finalize_unit_position", unit_instance, target_slot_node)
	return unit_instance

func _finalize_unit_position(unit: Unit, slot_node: Control) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(slot_node):
		push_warning("Battle._finalize_unit_position: Unit or slot_node is invalid.")
		return

	# Get the floor node (should be the first child of the slot)
	var floor_node = slot_node.get_child(0) if slot_node.get_child_count() > 0 else null
	if floor_node and floor_node is Control: # Assuming floor is also a Control node like ColorRect
		var unit_scaled_size = unit.size * unit.scale
		# Center horizontally in the slot
		unit.position.x = (slot_node.size.x / 2.0) - (unit_scaled_size.x / 2.0)
		# Position the unit so its bottom is aligned with the bottom of the slot_node.
		# Try with origin at top-left first, then adjust if unit's origin is center.
		unit.position.y = slot_node.size.y - unit_scaled_size.y # Assumes unit origin is top-left
		# If unit origin is center, it should be: slot_node.size.y - (unit_scaled_size.y / 2.0)
		add_log_message("Unit '%s' finalized position at X: %f, Y: %f (Slot Bottom: %f, Unit ScaledSize: %s)" % [unit.name if unit.name else 'Unknown', unit.position.x, unit.position.y, slot_node.size.y, str(unit_scaled_size)])
	else:
		# Fallback: position at bottom of slot even if floor_node (child 0) is not found or not a Control node
		var unit_scaled_size = unit.size * unit.scale # Ensure unit_scaled_size is defined in this scope too
		unit.position.x = (slot_node.size.x / 2.0) - (unit_scaled_size.x / 2.0)
		unit.position.y = slot_node.size.y - unit_scaled_size.y # Assumes unit origin is top-left
		add_log_message("Unit '%s' (no floor node) finalized position at X: %f, Y: %f (Slot Bottom: %f, Unit ScaledSize: %s)" % [unit.name if unit.name else 'Unknown', unit.position.x, unit.position.y, slot_node.size.y, str(unit_scaled_size)])

func _spawn_initial_units():
	if not OFFENSIVE_T1_UNIT_DATA:
		push_error("Battle._spawn_initial_units(): OFFENSIVE_T1_UNIT_DATA not loaded.")
		return

	add_log_message("Spawning initial units...")
	# Spawn 2 player units (Offensive T1)
	var player_units_spawned_count = 0
	var player_units_to_spawn = [
		{"data": OFFENSIVE_T1_UNIT_DATA, "slot": 0},
		{"data": OFFENSIVE_T1_UNIT_DATA, "slot": 1}
	]
	
	for unit_info in player_units_to_spawn:
		if player_units_spawned_count < MAX_UNITS_PER_SIDE and unit_info.slot < player_slot_nodes.size():
			var new_unit = _spawn_unit(unit_info.data, true, unit_info.slot)
			if is_instance_valid(new_unit):
				player_units_spawned_count += 1
		else:
			add_log_message("Could not spawn player unit in slot %d. Max units or invalid slot." % unit_info.slot)
			break
	
	# If player_units[0] should correspond to player_slot_nodes[0] (e.g., rightmost/frontmost)
	# and _spawn_unit appends, and you spawned in order 0, 1, ...
	# then reversing player_units makes player_units[0] the last one spawned (e.g. into slot 1 if 2 units)
	# This needs careful thought based on your HBoxContainer order and desired logical front.
	# Let's keep the reverse for now, assuming player_units[0] should be the unit in the highest player slot index that was filled.
	if player_units.size() > 1:
		player_units.reverse()

	# Spawn 3 enemy units (Offensive T1)
	var enemy_units_spawned_count = 0
	var enemy_units_to_spawn = [
		{"data": OFFENSIVE_T1_UNIT_DATA, "slot": 0},
		{"data": OFFENSIVE_T1_UNIT_DATA, "slot": 1},
		{"data": OFFENSIVE_T1_UNIT_DATA, "slot": 2}
	]

	for unit_info in enemy_units_to_spawn:
		if enemy_units_spawned_count < MAX_UNITS_PER_SIDE and unit_info.slot < enemy_slot_nodes.size():
			var new_unit = _spawn_unit(unit_info.data, false, unit_info.slot)
			if is_instance_valid(new_unit):
				enemy_units_spawned_count += 1
		else:
			add_log_message("Could not spawn enemy unit in slot %d. Max units or invalid slot." % unit_info.slot)
			break
	
	# Enemy units are typically frontmost at index 0 (leftmost for HBoxContainer), 
	# and if spawned into enemy_slot_nodes[0], enemy_slot_nodes[1] etc., 
	# and _spawn_unit appends, then enemy_units[0] is the unit in enemy_slot_nodes[0]. No reverse needed.

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

func _get_frontmost_live_unit(unit_array: Array[Unit]) -> Variant:
	for unit in unit_array:
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
	add_log_message("Battle ended. Player %s." % ["won" if player_won else "lost"])
	end_turn_button.disabled = true
	gacha_button.disabled = true # Or other relevant UI changes
	var message = "Player Won!" if player_won else "Player Lost!"
	turn_indicator.text = "Battle Over: %s" % message
	if player_won:
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright Green
	else:
		turn_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Bright Red
