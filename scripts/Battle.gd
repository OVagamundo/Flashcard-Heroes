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

# Arrays to hold references to the UnitSlot instances in the scene
var player_lineup_slots: Array[UnitSlot] = []
var enemy_lineup_slots: Array[UnitSlot] = []

# Arrays to hold actual unit instances
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var is_player_turn: bool = true

# Selection state
var selected_unit_instance: Unit = null
var selected_unit_original_slot: UnitSlot = null

func _ready() -> void:
	# Connect button signals (can be kept, but their actions will be simplified)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	gacha_button.pressed.connect(_on_gacha_pressed)
	
	# EventBus connections (can be kept, but signals won't be emitted by battle logic for now)
	# EventBus.unit_spawned.connect(_on_unit_spawned)
	# EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_died.connect(_on_unit_died_eventbus) # Connect to the new handler
	# EventBus.battle_ended.connect(_on_battle_ended)

	EventBus.unit_selected_for_action.connect(_on_unit_selected_for_action)
	EventBus.slot_clicked_for_action.connect(_on_slot_clicked_for_action)
	
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
	# Clear units from player lineup slots
	for slot_node in player_lineup_slots:
		if is_instance_valid(slot_node) and not slot_node.is_empty():
			var unit = slot_node.clear_unit()
			if is_instance_valid(unit):
				unit.queue_free() # Free the unit node itself
	# Clear units from enemy lineup slots
	for slot_node in enemy_lineup_slots:
		if is_instance_valid(slot_node) and not slot_node.is_empty():
			var unit = slot_node.clear_unit()
			if is_instance_valid(unit):
				unit.queue_free()
	
	player_units.clear() # Also clear logical unit arrays
	enemy_units.clear()

# Function to set up UnitSlot instances as children of the existing Control nodes
func setup_visual_slots() -> void:
	# Clear all slot arrays
	player_lineup_slots.clear()
	enemy_lineup_slots.clear()

	# Setup player lineup slots
	setup_slot_container(player_units_container, "PlayerSlot", true, true, player_lineup_slots)
	
	# Setup enemy lineup slots
	setup_slot_container(enemy_units_container, "EnemySlot", true, false, enemy_lineup_slots)

# Helper function to set up slots in a container
func setup_slot_container(container: Control, slot_prefix: String, is_lineup: bool, is_player: bool, slot_array: Array) -> void:
	for i in range(container.get_child_count()):
		var slot_control = container.get_child(i)
		
		# Clear any existing UnitSlot nodes but keep the floor visuals
		var children_to_remove = []
		for child in slot_control.get_children():
			if child is UnitSlot:
				children_to_remove.append(child)
		for child in children_to_remove:
			child.queue_free()
			
		# Create a new UnitSlot instance
		var unit_slot = UnitSlot.new()
		unit_slot.slot_id = "%s%d" % [slot_prefix, i]
		unit_slot.is_lineup_slot = is_lineup
		unit_slot.is_player_slot = is_player
		
		# Add the UnitSlot as a child of the existing Control node
		slot_control.add_child(unit_slot)
		
		# Configure the UnitSlot to fill its parent Control but leave room for the floor visual
		unit_slot.anchor_left = 0.0
		unit_slot.anchor_right = 1.0
		unit_slot.anchor_top = 0.0
		unit_slot.anchor_bottom = 1.0
		unit_slot.offset_left = 0
		unit_slot.offset_right = 0
		unit_slot.offset_top = 0
		unit_slot.offset_bottom = 20  # Leave space for the floor visual at the bottom
		unit_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		unit_slot.z_index = 1  # Ensure units appear above floor visuals
		
			# Add to our array of slot references
		slot_array.append(unit_slot)

	# Reverse enemy_lineup_slots for consistent indexing (0 is front/right for enemy)
	if not enemy_lineup_slots.is_empty():
		enemy_lineup_slots.reverse()
		add_log_message("Battle.setup_visual_slots(): Enemy lineup slots reversed. Index 0 is now their front (typically rightmost visual).")

	# Initialize/resize the logical unit arrays to match the number of UnitSlots
	player_units.resize(player_lineup_slots.size())
	for i in range(player_units.size()):
		player_units[i] = null # This array stores the Unit instance at a logical slot index
	
	enemy_units.resize(enemy_lineup_slots.size())
	for i in range(enemy_units.size()):
		enemy_units[i] = null
	
	add_log_message("Battle.setup_visual_slots(): Setup complete. " + \
		"Player lineup slots: %d, Enemy lineup slots: %d" % [player_lineup_slots.size(), enemy_lineup_slots.size()])

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

	if player_lineup_slots.is_empty():
		push_warning("Battle._spawn_hero_unit(): No player lineup slots available for Hero.")
		return

	# GDD: Hero automatically starts in the backmost available Lineup slot.
	# Assuming player slots are 0 (front/left) to N-1 (back/right).
	var hero_slot_index = player_lineup_slots.size() - 1
	var hero_slot = player_lineup_slots[hero_slot_index]
	
	# Make sure the slot is valid and empty
	if not is_instance_valid(hero_slot):
		push_error("Battle._spawn_hero_unit(): Invalid hero slot at index %d." % hero_slot_index)
		return
		
	if not hero_slot.is_empty():
		push_warning("Battle._spawn_hero_unit(): Hero slot %d is already occupied." % hero_slot_index)
		return

	# Spawn the hero in the lineup
	var hero_unit = _spawn_unit(hero_data, true, hero_slot_index)
	if hero_unit:
		add_log_message("Hero unit '%s' spawned in lineup slot %d." % [hero_data.display_name, hero_slot_index])
	else:
		push_error("Battle._spawn_hero_unit(): Failed to spawn hero unit.")

func _generate_enemy_lineup() -> void:
	if not UnitLibrary:
		push_error("Battle._generate_enemy_lineup(): UnitLibrary autoload not found!")
		return

	var num_enemies = randi_range(3, min(6, enemy_lineup_slots.size())) # 3 to 6 enemies, capped by available slots
	add_log_message("Generating %d enemies." % num_enemies)

	var enemy_options: Array[UnitData] = UnitLibrary.get_enemy_pool_t1()
	if enemy_options.is_empty():
		push_warning("Battle._generate_enemy_lineup(): No T1 enemy types available in UnitLibrary.")
		return

	for i in range(num_enemies):
		if i >= enemy_lineup_slots.size():
			push_warning("Battle._generate_enemy_lineup(): Not enough enemy slots for %d enemies. Stopping at %d." % [num_enemies, i])
			break
		
		var random_enemy_data: UnitData = enemy_options.pick_random()
		if random_enemy_data:
			# Enemies spawn from their front (index 0 of reversed enemy_lineup_slots) to back
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
		push_error("Battle._spawn_unit(): Failed to instantiate unit.")
		return null

	# Add the unit to the scene tree first (needed for some node operations)
	add_child(unit_instance)

	# Initialize the unit with data
	unit_instance.initialize(unit_data, is_player_team, Color(1.0, 1.0, 1.0)) # Default white tint for now

	# Determine which slot container to use based on team
	var target_slot_node: UnitSlot = null
	var team_name = "Player" if is_player_team else "Enemy"
	var slot_array = player_lineup_slots if is_player_team else enemy_lineup_slots
	# Validate slot index
	if slot_index < 0 or slot_index >= slot_array.size():
		push_error("Battle._spawn_unit(): Invalid %s slot_index %d for %s team (valid: 0-%d)." % 
			["lineup", slot_index, team_name, slot_array.size() - 1])
		unit_instance.queue_free()
		return null

	target_slot_node = slot_array[slot_index]

	# Check if the slot is valid and empty
	if not is_instance_valid(target_slot_node):
		push_error("Battle._spawn_unit(): Target lineup slot_node is invalid for %s team, slot %d." % 
			[team_name, slot_index])
		unit_instance.queue_free()
		return null

	if not target_slot_node.is_empty():
		push_warning("Battle._spawn_unit(): Target lineup slot %d for %s team is already occupied." % 
			[slot_index, team_name])
		unit_instance.queue_free()
		return null

	# Assign the unit to the slot
	target_slot_node.assign_unit(unit_instance)

	# Update the appropriate logical unit array
	# Store the unit in the appropriate array
	if is_player_team:
		player_units[slot_index] = unit_instance
	else:
		enemy_units[slot_index] = unit_instance

	# Update the unit's display
	unit_instance._update_display()
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
	add_log_message("Starting combat phase...")
	# Disable UI during combat
	end_turn_button.disabled = true
	gacha_button.disabled = true
	
	# Start combat coroutine
	_process_combat_phase()

func _process_combat_phase() -> void:
	# Player team acts first
	add_log_message("Player team's turn!")
	await _process_team_turn(player_lineup_slots, enemy_lineup_slots, true)
	
	# Check if combat ended
	if _check_combat_ended():
		return
	
	# Enemy team's turn
	add_log_message("Enemy team's turn!")
	await _process_team_turn(enemy_lineup_slots, player_lineup_slots, false)
	
	# Check if combat ended
	if _check_combat_ended():
		return
	
	# End of combat phase
	add_log_message("Combat phase ended.")
	
	# Re-enable UI for next turn
	end_turn_button.disabled = false
	gacha_button.disabled = false

func _process_team_turn(attacking_team: Array, defending_team: Array, is_player_attacking: bool) -> void:
	# Process units from back to front (left to right for player, right to left for enemy)
	var units_to_act = attacking_team.duplicate()
	if not is_player_attacking:
		units_to_act.reverse()
	
	for slot in units_to_act:
		if not is_instance_valid(slot) or slot.is_empty():
			continue
			
		var unit = slot.occupying_unit
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
			
		# Find target - frontmost unit in the opposing team
		var target_slot = _find_frontmost_unit(defending_team, not is_player_attacking)
		if not target_slot or not is_instance_valid(target_slot.occupying_unit):
			add_log_message("No valid targets found!")
			break
			
		var target = target_slot.occupying_unit
		add_log_message("%s attacks %s!" % [unit.unit_data.display_name, target.unit_data.display_name])
		
		# Calculate damage
		var damage = unit.unit_data.pwr
		target.take_damage(damage)
		add_log_message("%s deals %d damage to %s" % [unit.unit_data.display_name, damage, target.unit_data.display_name])
		
		# Small delay between attacks for better visibility
		await get_tree().create_timer(0.5).timeout
		
		# Check if target died
		if target.current_hp <= 0:
			add_log_message("%s was defeated!" % target.unit_data.display_name)
			EventBus.unit_died.emit(target)
			
			# Check if combat ended after this attack
			if _check_combat_ended():
				return

func _find_frontmost_unit(team_slots: Array, reverse_order: bool) -> UnitSlot:
	var slots = team_slots.duplicate()
	if reverse_order:
		slots.reverse()
		
	for slot in slots:
		if is_instance_valid(slot) and not slot.is_empty() and is_instance_valid(slot.occupying_unit):
			if slot.occupying_unit.current_hp > 0:
				return slot
	return null

func _check_combat_ended() -> bool:
	# Check if all enemy units are defeated
	var all_enemies_defeated = true
	for slot in enemy_lineup_slots:
		if is_instance_valid(slot) and not slot.is_empty() and is_instance_valid(slot.occupying_unit):
			if slot.occupying_unit.current_hp > 0:
				all_enemies_defeated = false
				break
	
	if all_enemies_defeated:
		add_log_message("All enemies defeated! Victory!")
		# TODO: Add victory rewards and transition
		return true
	
	# Check if all player units are defeated
	var all_players_defeated = true
	for slot in player_lineup_slots:
		if is_instance_valid(slot) and not slot.is_empty() and is_instance_valid(slot.occupying_unit):
			if slot.occupying_unit.current_hp > 0:
				all_players_defeated = false
				break
	
	if all_players_defeated:
		add_log_message("All player units defeated! Game Over!")
		# TODO: Handle game over
		return true
	
	return false

func _on_gacha_pressed() -> void:
	if not UnitLibrary:
		push_error("Battle._on_gacha_pressed(): UnitLibrary autoload not found!")
		return

	if gacha_tokens < 1:
		add_log_message("Not enough gacha tokens!")
		return

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

	# Try to place in the first available lineup slot
	var placed_in_slot = -1
	for i in range(player_lineup_slots.size()):
		var slot = player_lineup_slots[i]
		if is_instance_valid(slot) and slot.is_empty():
			# Spawn the unit in the lineup
			var unit = _spawn_unit(drawn_unit_data, true, i)
			if unit:
				add_log_message("Gacha unit '%s' placed in lineup slot %d." % [drawn_unit_data.display_name, i])
				placed_in_slot = i
				break

	# Handle case where the unit couldn't be placed
	if placed_in_slot == -1:
		add_log_message("No space in lineup for the new unit.")
		# Optional: Refund the gacha token since we couldn't place the unit
		# gacha_tokens += 1
		# _update_gacha_tokens_display()
		# add_log_message("Gacha token refunded - no space for unit.")

func _update_gacha_tokens_display() -> void:
	if gacha_tokens_label:
		gacha_tokens_label.text = "Tokens: %d" % gacha_tokens

func _get_frontmost_live_unit(unit_array: Array[Unit]) -> Variant:
	if unit_array.is_empty():
		return null
		
	# Check if this is the player or enemy team (commented out as it's not currently used)
	var _is_player_team = unit_array == player_units  # Currently unused, but keeping for potential future use
	
	# For both teams, the frontmost unit is the one with the highest index in their respective arrays
	# because enemy_lineup_slots were already reversed during setup
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

# --- Helper Functions for Selection and Movement ---
func _get_slot_for_unit(unit_to_find: Unit) -> UnitSlot:
	if not is_instance_valid(unit_to_find):
		return null

	# Check player lineup slots
	for slot in player_lineup_slots:
		if is_instance_valid(slot) and slot.occupying_unit == unit_to_find:
			return slot

	# Check enemy lineup slots
	for slot in enemy_lineup_slots:
		if is_instance_valid(slot) and slot.occupying_unit == unit_to_find:
			return slot

	return null

func _deselect_current_unit() -> void:
	if is_instance_valid(selected_unit_instance):
		selected_unit_instance.update_selection_visual(false)
	selected_unit_instance = null
	selected_unit_original_slot = null
	# TODO: Call _highlight_valid_slots(false) when implemented
	add_log_message("Current unit deselected.")


# --- EventBus Handlers for Unit/Slot Interaction ---
func _on_unit_selected_for_action(clicked_unit: Unit) -> void:
	if not is_instance_valid(clicked_unit):
		return

	if not is_player_turn:
		add_log_message("Cannot select unit: Not player's turn.")
		return

	var slot_of_clicked_unit: UnitSlot = _get_slot_for_unit(clicked_unit)
	if not is_instance_valid(slot_of_clicked_unit) or not slot_of_clicked_unit.is_player_slot:
		add_log_message("Cannot select unit: Not a player unit or not in a player slot.")
		return

	add_log_message("Player unit clicked: %s in slot %s" % [clicked_unit.get_name_for_log(), slot_of_clicked_unit.slot_id])

	if selected_unit_instance == clicked_unit:
		# Clicked the already selected unit - deselect it
		add_log_message("Deselecting unit: %s" % clicked_unit.get_name_for_log())
		_deselect_current_unit()
	elif is_instance_valid(selected_unit_instance):
		# Another unit is already selected - this is a unit-on-unit click (attempt swap)
		add_log_message("Attempting swap with selected unit %s and clicked unit %s" % [selected_unit_instance.get_name_for_log(), clicked_unit.get_name_for_log()])
		_attempt_swap_units(selected_unit_instance, selected_unit_original_slot, clicked_unit, slot_of_clicked_unit)
		_deselect_current_unit() # Always deselect after an action attempt
	else:
		# No unit was selected - select this one
		selected_unit_instance = clicked_unit
		selected_unit_original_slot = slot_of_clicked_unit
		selected_unit_instance.update_selection_visual(true)
		add_log_message("Selected unit: %s in slot %s" % [selected_unit_instance.get_name_for_log(), selected_unit_original_slot.slot_id])
		# TODO: Highlight valid target slots for the selected_unit_instance

func _on_slot_clicked_for_action(clicked_slot: UnitSlot) -> void:
	if not is_instance_valid(clicked_slot):
		return

	if not is_player_turn:
		add_log_message("Cannot interact with slot: Not player's turn.")
		return

	if not is_instance_valid(selected_unit_instance):
		add_log_message("Slot %s clicked, but no unit is selected. Ignoring." % clicked_slot.slot_id)
		return

	# Ensure the clicked slot is a player-controllable slot
	if not clicked_slot.is_player_slot:
		add_log_message("Cannot interact with enemy slots directly.")
		return

	add_log_message("Player slot clicked: %s. Selected unit: %s" % [clicked_slot.slot_id, selected_unit_instance.get_name_for_log()])

	if clicked_slot == selected_unit_original_slot:
		# Clicked the original slot of the selected unit - deselect it
		add_log_message("Clicked original slot. Deselecting unit: %s" % selected_unit_instance.get_name_for_log())
		_deselect_current_unit()
	elif clicked_slot.is_empty():
		# Clicked an empty slot - attempt move
		add_log_message("Attempting move to empty slot: %s" % clicked_slot.slot_id)
		_attempt_move_to_empty_slot(selected_unit_instance, selected_unit_original_slot, clicked_slot)
		_deselect_current_unit() # Always deselect after an action attempt
	elif is_instance_valid(clicked_slot.occupying_unit):
		# Clicked an occupied slot - attempt swap
		var target_unit_in_slot = clicked_slot.occupying_unit
		add_log_message("Attempting swap with unit %s in slot %s" % [target_unit_in_slot.get_name_for_log(), clicked_slot.slot_id])
		_attempt_swap_units(selected_unit_instance, selected_unit_original_slot, target_unit_in_slot, clicked_slot)
		_deselect_current_unit() # Always deselect after an action attempt
	else:
		# Should not happen if is_empty() is false and occupying_unit is null, but as a fallback:
		add_log_message("Clicked slot %s has an unexpected state. Deselecting." % clicked_slot.slot_id)
		_deselect_current_unit()


# --- Core Logic for Movement and Swapping ---
func _attempt_move_to_empty_slot(unit_to_move: Unit, from_slot: UnitSlot, to_slot: UnitSlot) -> bool:
	# 1. Validate Inputs & State
	if not is_instance_valid(unit_to_move) or not is_instance_valid(from_slot) or not is_instance_valid(to_slot):
		add_log_message("Move failed: Invalid unit or slot instance(s).")
		return false

	if from_slot.occupying_unit != unit_to_move:
		add_log_message("Move failed: Unit %s is not in the specified from_slot %s." % [unit_to_move.get_name_for_log(), from_slot.slot_id])
		return false

	if not to_slot.is_empty():
		add_log_message("Move failed: Target slot %s is not empty." % to_slot.slot_id)
		return false

	# 2. Hero Constraint Check (using UnitSlot's own check)
	if unit_to_move.unit_data and unit_to_move.unit_data.unit_type_tag == "hero":
		if not to_slot.can_accommodate_hero():
			add_log_message("Move failed: Invalid target slot for unit %s" % unit_to_move.get_name_for_log())
			return false

	# 3. Perform Move (Visual and Slot Logic)
	var unit_ref = from_slot.clear_unit() # Should be unit_to_move
	if unit_ref != unit_to_move: # Should not happen if logic is correct
		push_error("Battle._attempt_move_to_empty_slot: Mismatch in unit cleared from from_slot!")
		# Attempt to recover or fail gracefully
		if is_instance_valid(unit_ref) and not is_instance_valid(from_slot.occupying_unit):
			from_slot.assign_unit(unit_ref) # Put it back if something went wrong
		return false
	
	to_slot.assign_unit(unit_to_move)

	# 4. Update Logical Array (player_units)
	var from_slot_idx = player_lineup_slots.find(from_slot)
	var to_slot_idx = player_lineup_slots.find(to_slot)

	if from_slot_idx == -1 or to_slot_idx == -1:
		add_log_message("Move failed: Could not find one or both slots in player_lineup_slots array. This is a critical error.")
		# Attempt to revert visual move if logical update fails catastrophically
		to_slot.clear_unit()
		from_slot.assign_unit(unit_to_move)
		return false

	player_units[from_slot_idx] = null
	player_units[to_slot_idx] = unit_to_move

	add_log_message("Move successful: %s moved from %s to %s." % [unit_to_move.get_name_for_log(), from_slot.slot_id, to_slot.slot_id])
	return true

func _attempt_swap_units(unit1: Unit, from_slot1: UnitSlot, unit2: Unit, from_slot2: UnitSlot) -> bool:
	# 1. Validate Inputs & State
	if (not is_instance_valid(unit1) or not is_instance_valid(from_slot1) or 
	   not is_instance_valid(unit2) or not is_instance_valid(from_slot2)):
		add_log_message("Swap failed: Invalid unit or slot instance(s).")
		return false

	# Make sure the units are actually in the specified slots
	if from_slot1.occupying_unit != unit1 or from_slot2.occupying_unit != unit2:
		add_log_message("Swap failed: Unit-slot mismatch.")
		return false

	# 2. Check if both units are on the same team (can't swap with enemy units)
	if unit1.is_player_team_unit != unit2.is_player_team_unit:
		add_log_message("Swap failed: Cannot swap units from different teams.")
		return false

	# 3. Check hero constraints for both slots
	if unit1.unit_data.unit_type_tag == "hero" and not from_slot2.can_accommodate_hero():
		add_log_message("Swap failed: Hero unit %s cannot move to slot %s." % [unit1.get_name_for_log(), from_slot2.slot_id])
		return false

	if unit2.unit_data.unit_type_tag == "hero" and not from_slot1.can_accommodate_hero():
		add_log_message("Swap failed: Hero unit %s cannot move to slot %s." % [unit2.get_name_for_log(), from_slot1.slot_id])
		return false

	# 4. Perform the swap
	# First clear both slots
	var temp_unit1 = from_slot1.clear_unit()
	var temp_unit2 = from_slot2.clear_unit()

	# Sanity check
	if temp_unit1 != unit1 or temp_unit2 != unit2:
		push_error("Battle._attempt_swap_units: Mismatch in units cleared from slots!")
		# Attempt to revert
		if is_instance_valid(temp_unit1): from_slot1.assign_unit(temp_unit1)
		if is_instance_valid(temp_unit2): from_slot2.assign_unit(temp_unit2)
		return false
	
	from_slot1.assign_unit(unit2)
	from_slot2.assign_unit(unit1)

	# 5. Update logical arrays if these are player units
	if unit1.is_player_team_unit:  # Both units are on the same team, so just check one
		var slot1_idx = player_lineup_slots.find(from_slot1)
		var slot2_idx = player_lineup_slots.find(from_slot2)

		# If either slot is in the lineup, update the player_units array
		if slot1_idx != -1 and slot2_idx != -1:
			# Both slots are in the lineup, just swap them
			player_units[slot1_idx] = unit2
			player_units[slot2_idx] = unit1
		elif slot1_idx != -1:
			# Only slot1 is in the lineup
			player_units[slot1_idx] = unit2
		elif slot2_idx != -1:
			# Only slot2 is in the lineup
			player_units[slot2_idx] = unit1
		# All slots are lineup slots now

	add_log_message("Swap successful: %s and %s swapped positions." % [unit1.get_name_for_log(), unit2.get_name_for_log()])
	return true


# --- Existing EventBus Handlers (Modified) ---
func _on_unit_died_eventbus(unit_died: Unit) -> void:
	if not is_instance_valid(unit_died):
		return

	var unit_name = unit_died.get_name_for_log()
	add_log_message("EventBus: Unit %s died." % unit_name)

	var slot_of_died_unit: UnitSlot = _get_slot_for_unit(unit_died)

	if is_instance_valid(slot_of_died_unit):
		var team_info = "Player" if slot_of_died_unit.is_player_slot else "Enemy"
		var slot_idx = -1
		
		if slot_of_died_unit.is_player_slot:
			slot_idx = player_lineup_slots.find(slot_of_died_unit)
			if slot_idx != -1 and slot_idx < player_units.size() and player_units[slot_idx] == unit_died:
				player_units[slot_idx] = null
		else: # Enemy unit
			slot_idx = enemy_lineup_slots.find(slot_of_died_unit)
			if slot_idx != -1 and slot_idx < enemy_units.size() and enemy_units[slot_idx] == unit_died:
				enemy_units[slot_idx] = null
		
		slot_of_died_unit.clear_unit()
		add_log_message("Unit %s cleared from %s lineup slot %s. Corresponding logical array updated." % [unit_name, team_info, slot_of_died_unit.slot_id])
	else:
		# Fallback if unit wasn't in a tracked slot (shouldn't happen for units in play)
		push_warning("Battle._on_unit_died_eventbus: Died unit %s was not found in any tracked slot." % unit_name)

	# If the died unit was selected, deselect it
	if selected_unit_instance == unit_died:
		_deselect_current_unit()

	# Visually remove the unit from the scene (queue_free is now handled by clear_unit if it was parented to slot, or here if not)
	if is_instance_valid(unit_died) and not unit_died.is_queued_for_deletion():
		# If clear_unit didn't queue_free it (e.g., it wasn't parented to the slot directly for some reason)
		# or if it wasn't found in a slot, ensure it's freed.
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
