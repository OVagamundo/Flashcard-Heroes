extends Control

# Node references
@onready var player_units_container: HBoxContainer = $MainContainer/BattleArea/PlayerSide/PlayerUnits
@onready var enemy_units_container: HBoxContainer = $MainContainer/BattleArea/EnemySide/EnemyUnits
@onready var battle_log: TextEdit = $BattleLog

# Input handler reference
var input_handler: Node = null

# Selection state
var selected_unit: Node = null
var selected_slot: Node = null
var is_player_turn: bool = true
var is_awaiting_merge_confirmation: bool = false
@onready var end_turn_button: Button = $MainContainer/Actions/EndTurnButton
@onready var gacha_button: Button = $MainContainer/Actions/GachaButton
@onready var player_health_label: Label = $MainContainer/Header/PlayerInfo/PlayerHealth
@onready var gacha_tokens_label: Label = $MainContainer/Header/PlayerInfo/GachaTokens
@onready var turn_indicator: Label = $MainContainer/Header/TurnIndicator

const MAX_UNITS_PER_SIDE = 6 # As per GDD
const UNIT_SCENE = preload("res://scenes/Unit.tscn")

# Game constants
const MAX_PLAYER_UNITS = 10  # Maximum number of units a player can have

# Gacha system variables
var gacha_tokens: int = 5  # Starting Gacha Tokens as per GDD

# Arrays to hold references to the UnitSlot instances in the scene
var player_lineup_slots: Array[UnitSlot] = []
var player_bench_slots: Array[UnitSlot] = []
var enemy_lineup_slots: Array[UnitSlot] = []

# Arrays to hold actual unit instances
# Using untyped arrays to avoid type system issues
var player_units = [] # Array of Unit
var player_lineup_units = [] # Array of Unit
var enemy_units = [] # Array of Unit

# Merge and selection state
var pending_merge_slot: UnitSlot = null

var UnitInspectionPanel

func _ready() -> void:
	# Initialize player_units with nulls for the maximum number of units
	for i in range(MAX_PLAYER_UNITS):
		player_units.append(null)

	# Get input handler reference
	input_handler = get_node_or_null("/root/InputHandler")
	
	# Initialize the battle state
	is_player_turn = true
	is_awaiting_merge_confirmation = false
	
	# Connect signals
	EventBus.unit_died.connect(_on_unit_died_eventbus)
	EventBus.unit_health_changed.connect(_on_unit_health_changed)
	EventBus.turn_ended.connect(_on_turn_ended)
	
	# Connect input signals
	EventBus.unit_inspection_requested.connect(_on_unit_inspection_requested)
	EventBus.unit_selection_requested.connect(_on_unit_selection_requested)
	EventBus.slot_selected.connect(_on_slot_selected)
	EventBus.end_turn_pressed.connect(_on_end_turn_pressed)
	
	# Initialize UI elements
	if has_node("MainContainer/Actions/EndTurnButton"):
		$MainContainer/Actions/EndTurnButton.pressed.connect(_on_end_turn_button_pressed)
	if has_node("MainContainer/Actions/GachaButton"):
		$MainContainer/Actions/GachaButton.pressed.connect(_on_gacha_pressed)
	
	# Load resources
	UnitInspectionPanel = load("res://scenes/UnitInspectionPanel.tscn")
	setup_battle_scene()
	_spawn_initial_units() # Spawn units after scene setup
	_update_gacha_tokens_display() # Update gacha tokens display
	
	# Disable direct input processing since we're using signals
	set_process_input(false)

func setup_battle_scene() -> void:
	clear_all_slots() # Clear any previous children
	setup_visual_slots() # Populate the slot node arrays
	
	is_player_turn = true
	update_turn_indicator()
	
	# Buttons can be enabled, but their functionality will be placeholder
	if has_node("MainContainer/Actions/EndTurnButton"):
		$MainContainer/Actions/EndTurnButton.disabled = false
	if has_node("MainContainer/Actions/GachaButton"):
		$MainContainer/Actions/GachaButton.disabled = false
	
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
	# Clear any existing slot references and arrays
	player_lineup_slots.clear()
	player_bench_slots.clear()
	enemy_lineup_slots.clear()
	player_lineup_units.clear()
	
	# Setup player lineup slots (all 6 slots in PlayerUnits container)
	setup_slot_container(player_units_container, "PlayerSlot", true, true, player_lineup_slots)
	
	# Setup enemy lineup slots (all 6 slots in EnemyUnits container)
	setup_slot_container(enemy_units_container, "EnemySlot", true, false, enemy_lineup_slots)
	
	# Initialize lineup_units with nulls for each lineup slot (6 slots total)
	for i in range(6):  # Fixed size of 6 slots
		player_lineup_units.append(null)
		
	# Debug: Print slot information
	print("Player lineup slots: ", player_lineup_slots.size())
	print("Player bench slots: ", player_bench_slots.size())
	print("Enemy lineup slots: ", enemy_lineup_slots.size())

# Helper function to set up slots in a container
func setup_slot_container(container: Control, slot_prefix: String, is_lineup: bool, is_player: bool, slot_array: Array) -> void:
	if not container:
		push_error("Container is null for slot prefix: " + slot_prefix)
		return
		
	var child_count = container.get_child_count()
	var slot_controls = []
	
	# Debug: Print container info
	print("Setting up container: ", container.name, " with prefix: ", slot_prefix)
	print("Child count: ", child_count)
	
	# First, collect all slot controls and their numeric indices from node names
	for i in range(child_count):
		var child = container.get_child(i)
		if child is Control and child.name.begins_with(slot_prefix):
			# Extract the slot number from the name (e.g., "PlayerSlot3" -> 3)
			var slot_num_str = child.name.trim_prefix(slot_prefix)
			var slot_num = slot_num_str.to_int()
			
			print("Found slot: ", child.name, " with number: ", slot_num)
			
			# Create a UnitSlot instance for each slot
			var unit_slot = UnitSlot.new()
			unit_slot.slot_id = child.name
			unit_slot.is_lineup_slot = is_lineup
			unit_slot.is_player_slot = is_player
			
			# Add the UnitSlot to the container
			child.add_child(unit_slot)
			
			# Store the slot in the appropriate array
			slot_controls.append({"node": unit_slot, "index": slot_num - 1})  # Convert to 0-based index
		else:
			print("Skipping child: ", child.name, " (type: ", child.get_class(), ")")
	
	# Sort slots by their index to ensure correct order
	slot_controls.sort_custom(func(a, b): return a["index"] < b["index"])
	# Add the sorted slots to the output array
	for slot_data in slot_controls:
		var slot = slot_data["node"]
		slot_array.append(slot)
		print("Added slot ", slot.slot_id, " at index ", slot_array.size() - 1)
		slot.slot_clicked.connect(_on_slot_clicked_for_action)
		
		# Configure the UnitSlot to fill its parent Control but leave room for the floor visual
		slot.anchor_left = 0.0
		slot.anchor_right = 1.0
		slot.anchor_top = 0.0
		slot.anchor_bottom = 1.0
		slot.offset_left = 0
		slot.offset_right = 0
		slot.offset_top = 0
		slot.offset_bottom = 20  # Leave space for the floor visual at the bottom
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.z_index = 1  # Ensure units appear above floor visuals
		
		# Log the slot assignment for debugging
		print("Assigned %s to slot %d" % [slot.slot_id, slot_array.size() - 1])

	# Ensure both teams have consistent slot ordering (index 0 = frontline, higher indices = backline)
	# No need to reverse enemy_lineup_slots anymore as we handle it in the scene setup

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
		var slot_index = enemy_lineup_slots.size() - 1 - i  # Start from highest index (frontline) to lowest (backline)
		if slot_index < 0 or slot_index >= enemy_lineup_slots.size():
			push_warning("Battle._generate_enemy_lineup(): Invalid slot index %d for enemy %d." % [slot_index, i])
			break
		
		var random_enemy_data: UnitData = enemy_options.pick_random()
		if random_enemy_data:
			# Spawn enemies from front to back (highest to lowest index)
			_spawn_unit(random_enemy_data, false, slot_index)
			add_log_message("Spawned enemy '%s' in enemy slot %d (front to back)." % [random_enemy_data.display_name, slot_index])
		else:
			push_warning("Battle._generate_enemy_lineup(): Failed to pick random enemy data.")

func _spawn_unit(unit_data: UnitData, is_player_team: bool, slot_index: int = -1, current_hp: int = -1) -> Unit:
	if not UNIT_SCENE:
		push_error("Battle._spawn_unit(): UNIT_SCENE is not loaded.")
		return null
	if not unit_data:
		push_error("Battle._spawn_unit(): unit_data is null.")
		return null

	var unit_instance = UNIT_SCENE.instantiate()
	if not unit_instance:
		push_error("Battle._spawn_unit(): Failed to instantiate unit.")
		return null

	# Determine which container to add the unit to
	var target_container = player_units_container if is_player_team else enemy_units_container
	if not is_instance_valid(target_container):
		push_error("Battle._spawn_unit(): Invalid target container.")
		unit_instance.queue_free()
		return null

	# Add the unit to the scene tree first
	target_container.add_child(unit_instance)

	# Initialize the unit with data
	var team_color = Color(0.3, 0.7, 1.0) if is_player_team else Color(1.0, 0.4, 0.4)
	unit_instance.initialize(unit_data, is_player_team, team_color)
	
	# Set current HP if provided (for merged units)
	if current_hp > 0:
		unit_instance.current_hp = current_hp

	# If slot_index is provided, assign to that slot
	if slot_index >= 0:
		var target_slots = player_lineup_slots if is_player_team else enemy_lineup_slots
		if slot_index < target_slots.size():
			var target_slot = target_slots[slot_index]
			if is_instance_valid(target_slot):
				# If the slot is occupied, remove the current unit
				if not target_slot.is_empty():
					var old_unit = target_slot.clear_unit()
					if is_instance_valid(old_unit):
						old_unit.queue_free()
				# Only assign if the slot is empty or was just cleared
				if target_slot.is_empty():
					target_slot.assign_unit(unit_instance)
				else:
					push_error("Failed to assign unit to slot: slot not empty after clear")

	# Add to the appropriate units array
	if is_player_team:
		# Find first null slot or add to end
		var slot_found = false
		for i in range(player_units.size()):
			if player_units[i] == null:
				player_units[i] = unit_instance
				slot_found = true
				break
		if not slot_found:
			player_units.append(unit_instance)
		
		# If this is a lineup slot, update player_lineup_units
		if slot_index >= 0 and slot_index < player_lineup_units.size():
			player_lineup_units[slot_index] = unit_instance
	else:
		# For enemies, just append to the array
		enemy_units.append(unit_instance)

	# Update the unit's display
	if is_instance_valid(unit_instance):
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

func _on_end_turn_button_pressed() -> void:
	# Emit signal to be handled by the input handler
	EventBus.emit_signal("end_turn_pressed")

func _on_end_turn_pressed() -> void:
	if not is_player_turn:
		return
		
	# End player turn
	is_player_turn = false
	_clear_selection()
	
	# Disable UI elements
	if has_node("MainContainer/Actions/EndTurnButton"):
		$MainContainer/Actions/EndTurnButton.disabled = true
	if has_node("MainContainer/Actions/GachaButton"):
		$MainContainer/Actions/GachaButton.disabled = true
	
	# Update UI
	update_turn_indicator()
	add_log_message("Your turn has ended. Enemy's turn...")
	
	# Start enemy turn with a small delay
	await get_tree().create_timer(0.5).timeout
	_process_enemy_turn()

func _process_enemy_turn() -> void:
	# Enemy team acts
	add_log_message("Enemy team's turn!")
	await _process_team_turn(enemy_lineup_slots, player_lineup_slots, false)
	
	# Check if combat ended
	if _check_combat_ended():
		return
	
	# Switch back to player's turn
	is_player_turn = true
	update_turn_indicator()
	
	# Re-enable UI elements for player's turn
	if has_node("MainContainer/Actions/EndTurnButton"):
		$MainContainer/Actions/EndTurnButton.disabled = false
	if has_node("MainContainer/Actions/GachaButton"):
		$MainContainer/Actions/GachaButton.disabled = false
	
	add_log_message("Enemy turn ended. Your turn!")

func _process_team_turn(attacking_team: Array, defending_team: Array, is_player_team: bool) -> void:
	# Debug: Print team info
	var team_name = "Player" if is_player_team else "Enemy"
	print("\n=== %s Team's Turn ===" % team_name)
	
	# Print attacking team slots
	var attacking_slots = []
	for i in range(attacking_team.size()):
		if is_instance_valid(attacking_team[i]):
			attacking_slots.append("%d:%s" % [i, attacking_team[i].slot_id])
	print("Attacking team slots (index:slot_id): ", attacking_slots)
	
	# Print defending team slots
	var defending_slots = []
	for i in range(defending_team.size()):
		if is_instance_valid(defending_team[i]):
			defending_slots.append("%d:%s" % [i, defending_team[i].slot_id])
	print("Defending team slots (index:slot_id): ", defending_slots)
	
	# Create a list to track which units have already acted this turn
	var acted_this_turn = {}
	var max_turns = attacking_team.size() * 2  # Safety net: max turns is 2x number of units
	var turn_count = 0
	var units_acted_this_iteration = 0
	
	# Continue processing turns until all units have acted or combat ends
	while true:
		if turn_count >= max_turns:
			print("Warning: Reached maximum number of turns, forcing turn end")
			break
		
		turn_count += 1
		units_acted_this_iteration = 0
		
		# Process units from front to back (highest to lowest index)
		for i in range(attacking_team.size() - 1, -1, -1):
			var slot = attacking_team[i] if i < attacking_team.size() else null
			
			# Skip invalid or empty slots
			if not is_instance_valid(slot) or slot.is_empty():
				continue
				
			var unit = slot.occupying_unit
			
			# Clean up invalid or dead units
			if not is_instance_valid(unit) or unit.current_hp <= 0:
				if is_instance_valid(slot):
					slot.clear_unit()
				continue
			
			# Skip if this unit has already acted this turn
			if acted_this_turn.has(unit):
				continue
			
			# Mark this unit as having acted this turn
			acted_this_turn[unit] = true
			units_acted_this_iteration += 1
			
			# Debug: Print attacker info
			print("\n[Turn %d] %s (slot: %s, index: %d) is attacking" % 
				[turn_count, unit.unit_data.display_name, slot.slot_id, i])
			
			# Find target - frontmost unit in the opposing team
			var target_slot = _find_frontmost_unit(defending_team)
			if not target_slot or not is_instance_valid(target_slot.occupying_unit):
				add_log_message("No valid targets found!")
				continue
				
			var target = target_slot.occupying_unit
			if not is_instance_valid(target) or not is_instance_valid(target.unit_data):
				add_log_message("Invalid target found, skipping attack")
				continue
			
			# Perform the attack
			add_log_message("%s attacks %s!" % [unit.unit_data.display_name, target.unit_data.display_name])
			var damage = unit.unit_data.pwr
			target.take_damage(damage)
			add_log_message("%s deals %d damage to %s" % [unit.unit_data.display_name, damage, target.unit_data.display_name])
			
			# Wait for animation/damage to be applied
			await get_tree().create_timer(0.5).timeout
			
			# Check if target was defeated
			if is_instance_valid(target) and target.current_hp <= 0:
				add_log_message("%s was defeated!" % target.unit_data.display_name)
				EventBus.unit_died.emit(target)
				if is_instance_valid(target_slot):
					target_slot.clear_unit()
				if _check_combat_ended():
					return
			
			# Small delay between unit actions for better visibility
			await get_tree().create_timer(0.3).timeout
		
		# If no units acted in this iteration, we're done
		if units_acted_this_iteration == 0:
			break
	
	# This appears to be a duplicate section of code that was already processed above
	# Removing the duplicate code to prevent execution of the same logic twice

func _find_frontmost_unit(team_slots: Array) -> UnitSlot:
	var frontmost_slot = null
	var highest_position = -1
	
	for slot in team_slots:
		if not is_instance_valid(slot) or slot.is_empty():
			continue
			
		var unit = slot.occupying_unit
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			# Clean up invalid units
			if is_instance_valid(slot) and is_instance_valid(unit) and not is_instance_valid(unit.unit_data):
				slot.clear_unit()
			continue
			
		# Check if this unit is in a more forward position
		if slot.slot_position > highest_position:
			highest_position = slot.slot_position
			frontmost_slot = slot
	
	return frontmost_slot

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
		
	# Determine if this is the player or enemy team
	var is_player_team = unit_array == player_units
	
	# Player team: front is highest index (rightmost)
	# Enemy team: front is lowest index (leftmost)
	var start_idx = unit_array.size() - 1 if is_player_team else 0
	var end_idx = -1 if is_player_team else unit_array.size()
	var step = -1 if is_player_team else 1
	
	for i in range(start_idx, end_idx, step):
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
	if is_instance_valid(selected_unit):
		if selected_unit.has_method("set_selected"):
			selected_unit.set_selected(false)
		elif selected_unit.has_method("update_selection_visual"):
			selected_unit.update_selection_visual(false)
		
	selected_unit = null
	
	if selected_slot and is_instance_valid(selected_slot) and selected_slot.has_method("set_highlight"):
		selected_slot.set_highlight("")
	
	selected_slot = null
	add_log_message("Current unit deselected.")

func handle_unit_click(screen_position: Vector2) -> void:
	# Convert screen position to world position
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = screen_position
	params.collide_with_areas = true
	params.collision_mask = 1  # Adjust collision layer as needed
	
	var result = space_state.intersect_point(params, 1)
	if not result.is_empty():
		var collider = result[0].collider
		if collider is Unit:
			if selected_unit == collider:
				# Clicked the selected unit - inspect it
				inspect_selected_unit()
			else:
				# Select the clicked unit
				_on_unit_selection_requested(collider)
			return
	
	# If we get here, the click wasn't on a unit - clear selection
	_clear_selection()

func inspect_selected_unit() -> void:
	if not selected_unit:
		return
	show_unit_inspection(selected_unit)

func show_unit_inspection(unit: Unit) -> void:
	if not is_instance_valid(unit) or not unit.unit_data:
		return
		
	# Check if we already have an inspection panel open
	var ui_manager = get_node_or_null("/root/UIManager")
	if not ui_manager:
		push_error("UIManager not found!")
		return
		
	# Close if already open
	if ui_manager.current_open_element and ui_manager.current_open_element.name == "UnitInspectionPanel":
		ui_manager.close_current_ui()
		return
	
	# Create the panel and add it to the root viewport
	var inspection_panel = UnitInspectionPanel.instantiate()
	inspection_panel.name = "UnitInspectionPanel"
	
	# Add to the root viewport instead of Battle
	get_tree().root.add_child(inspection_panel)
	
	# Connect closed signal
	if inspection_panel.has_signal("closed"):
		inspection_panel.closed.connect(_on_inspection_panel_closed)
	
	# Show with UIManager
	ui_manager.open_ui(inspection_panel)
	
	# Display unit data
	inspection_panel.display(unit.unit_data, unit.global_position)

func _on_inspection_panel_closed() -> void:
	# Clear selection when inspection panel is closed
	_clear_selection()
	
	# Make sure no unit is selected for inspection anymore
	if selected_unit and selected_unit.has_method("set_selected"):
		selected_unit.set_selected(false)
	selected_unit = null
	selected_slot = null

func _is_click_inside_ui(click_position: Vector2) -> bool:
	# Check if click is inside any UI elements
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = click_position
	params.collision_mask = 1  # UI layer
	var results = space_state.intersect_point(params, 1)
	return not results.is_empty()

func show_merge_swap_popup(unit1: Unit, unit2: Unit, target_slot: UnitSlot) -> void:
	print("\n=== CREATING MERGE/SWAP POPUP ===")
	print("Unit 1: ", unit1.unit_data.id if unit1.unit_data else "No unit data")
	print("Unit 2: ", unit2.unit_data.id if unit2.unit_data else "No unit data")
	print("Target slot: ", target_slot.name if target_slot else "No target slot")
	
	# Set flag to prevent input from clearing selection
	is_awaiting_merge_confirmation = true
	
	# Create a full-screen background to capture clicks
	var bg = ColorRect.new()
	bg.size = get_viewport_rect().size
	bg.color = Color(0, 0, 0, 0.3)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	# Create a panel for the popup
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 100)
	panel.position = get_global_mouse_position()
	panel.size = Vector2(200, 100)
	bg.add_child(panel)
	
	# Ensure panel is within screen bounds
	var viewport_size = get_viewport_rect().size
	panel.position.x = clamp(panel.position.x, 0, viewport_size.x - panel.size.x)
	panel.position.y = clamp(panel.position.y, 0, viewport_size.y - panel.size.y)
	
	# Create merge button
	var merge_btn = Button.new()
	merge_btn.text = "Merge"
	merge_btn.position = Vector2(10, 10)
	merge_btn.size = Vector2(180, 30)
	panel.add_child(merge_btn)
	
	# Create swap button
	var swap_btn = Button.new()
	swap_btn.text = "Swap"
	swap_btn.position = Vector2(10, 50)
	swap_btn.size = Vector2(180, 30)
	panel.add_child(swap_btn)
	
	# Store references to units and slots that we'll need later
	var first_unit = unit1
	var second_unit = unit2
	var first_slot = selected_slot
	
	# Function to clean up the popup
	var cleanup = func():
		is_awaiting_merge_confirmation = false
		if is_instance_valid(bg) and is_instance_valid(bg.get_parent()):
			bg.queue_free()
			_clear_selection()
	
	# Connect merge button
	merge_btn.pressed.connect(
		func():
			print("Merge button pressed")
			if not is_instance_valid(first_unit) or not is_instance_valid(second_unit) or \
			   not is_instance_valid(first_slot) or not is_instance_valid(target_slot) or \
			   first_slot.occupying_unit != first_unit or target_slot.occupying_unit != second_unit:
				print("Invalid merge state, units or slots no longer valid")
				cleanup.call()
				return
				
			var result_unit_id = UnitLibrary.get_merge_result_for_units(first_unit.unit_data, second_unit.unit_data)
			if result_unit_id:
				print("Merge possible with result: ", result_unit_id)
				_show_merge_confirmation(first_unit, second_unit, target_slot, result_unit_id)
			else:
				print("No valid merge result for these units")
				add_log_message("These units cannot be merged!")
			cleanup.call()
	)
	
	# Connect swap button
	swap_btn.pressed.connect(
		func():
			print("Swap button pressed")
			if is_instance_valid(first_unit) and is_instance_valid(second_unit) and \
			   is_instance_valid(first_slot) and is_instance_valid(target_slot) and \
			   first_slot.occupying_unit == first_unit and target_slot.occupying_unit == second_unit:
				_attempt_swap_units(first_unit, first_slot, second_unit, target_slot)
			cleanup.call()
	)
	
	# Close when clicking outside
	bg.gui_input.connect(
		func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				cleanup.call()
	)

# --- Core Logic for Movement and Swapping ---
func _handle_second_click(target_slot: UnitSlot, target_unit: Unit) -> void:
	print("\n=== HANDLE SECOND CLICK ===")
	print("Selected unit: ", selected_unit.unit_data.id if selected_unit and selected_unit.unit_data else "No selected unit")
	print("Target unit: ", target_unit.unit_data.id if target_unit and target_unit.unit_data else "No target unit")
	print("Target slot: ", target_slot.name if target_slot else "No target slot")
	
	if not selected_slot or not selected_unit or not is_instance_valid(selected_unit):
		print("No valid selection, deselecting")
		_deselect_current_unit()
		return

	# If clicked on empty slot, move the unit there
	if target_slot.is_empty():
		print("Target slot is empty, attempting move")
		_attempt_move_to_empty_slot(selected_unit, selected_slot, target_slot)
		_clear_selection()
		return

	# If clicked on another unit
	if target_unit and target_unit != selected_unit:
		print("Target is another unit, checking team")
		# Check if both units are on the same team
		if selected_unit.is_player_team_unit != target_unit.is_player_team_unit:
			print("Different teams, cannot interact")
			add_log_message("Cannot interact with enemy units!")
		else:
			print("Same team, checking merge possibility")
			# Store references before any potential clearing
			var first_unit = selected_unit
			var first_slot = selected_slot
			
			# Check if units can be merged
			var result_unit_id = UnitLibrary.get_merge_result_for_units(first_unit.unit_data, target_unit.unit_data)
			print("Merge result unit ID: ", result_unit_id)
			
			if result_unit_id:
				# Show merge/swap popup - don't clear selection yet
				print("Can merge, showing popup")
				show_merge_swap_popup(first_unit, target_unit, target_slot)
			else:
				# If merge not possible, swap the units
				print("Cannot merge, attempting swap")
				_attempt_swap_units(first_unit, first_slot, target_unit, target_slot)
				_clear_selection()

# --- EventBus Handlers for Unit/Slot Interaction ---
func _unhandled_input(event: InputEvent) -> void:
	# Only handle left mouse button presses
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	# If we have a selected unit and we're not in merge confirmation
	if selected_unit and not is_awaiting_merge_confirmation:
		var mouse_pos = get_global_mouse_position()
		
		# Check if we clicked on the selected unit (for inspection)
		if is_instance_valid(selected_unit) and selected_unit.get_global_rect().has_point(mouse_pos):
			# Let the unit's _input handle this click
			return
		
		# Check if we clicked on another unit or slot
		for unit in player_units:
			if unit != selected_unit and is_instance_valid(unit) and unit.get_global_rect().has_point(mouse_pos):
				# Let the unit's _input handle this click
				return
		
		# If we get here, we didn't click on any unit, so deselect
		_clear_selection()
		
		# Check if we clicked on a slot
		for slot in player_lineup_slots + player_bench_slots:
			if is_instance_valid(slot) and slot.get_global_rect().has_point(mouse_pos):
				# Let the slot's _input handle this click
				return

func _on_unit_selection_requested(unit: Unit) -> void:
	if not is_instance_valid(unit):
		_clear_selection()
		return
		
	if not is_player_turn or is_awaiting_merge_confirmation:
		return

	var clicked_slot = _get_slot_for_unit(unit)
	if not clicked_slot:
		_clear_selection()
		return

	# If we have a selected unit and we're clicking a different unit
	if selected_unit and selected_unit != unit:
		_handle_second_click(clicked_slot, unit)
		return

	# Handle single click on already selected unit (show inspection)
	if selected_unit == unit:
		show_unit_inspection(unit)
	else:
		# First selection - clear any existing selection first
		_clear_selection()
		
		# Select the new unit if it's a player unit
		if unit.is_player_team_unit:
			selected_unit = unit
			selected_slot = clicked_slot
			selected_unit.set_selected(true)
			add_log_message("Selected " + selected_unit.unit_data.display_name)
			
			# Update highlights
			if selected_slot and selected_slot.has_method("set_highlight"):
				selected_slot.set_highlight("selected")
				_update_merge_highlights(unit)

func _on_slot_selected(clicked_slot: UnitSlot) -> void:
	if not is_instance_valid(clicked_slot) or not is_player_turn or is_awaiting_merge_confirmation:
		return

	# Case 1: We have a selected unit
	if selected_unit and selected_slot:
		# If clicking the same slot, deselect
		if clicked_slot == selected_slot:
			_clear_selection()
			return
		
		# If clicking an empty slot, try to move
		if clicked_slot.is_empty():
			_attempt_move_to_empty_slot(selected_unit, selected_slot, clicked_slot)
			_deselect_current_unit()
		# If clicking on another unit, handle merge/swap
		elif clicked_slot.occupying_unit:
			var target_unit = clicked_slot.occupying_unit
			
			# Check if both units are on the same team and can be merged/swapped
			if target_unit.is_player_team_unit:
				print("Clicked occupied slot - checking merge possibility")
				print("Target unit: ", target_unit.unit_data.id if target_unit.unit_data else "No unit data")
				print("Selected unit tier: ", selected_unit.unit_data.tier if selected_unit.unit_data else "No unit data")
				print("Target unit tier: ", target_unit.unit_data.tier if target_unit.unit_data else "No unit data")
				
				if (target_unit.unit_data.tier == selected_unit.unit_data.tier and 
					target_unit.unit_data.tier < 3):  # Max tier is 3
					print("Merge condition met - showing popup")
					print("Unit 1: ", selected_unit.unit_data.id, " Tier: ", selected_unit.unit_data.tier)
					print("Unit 2: ", target_unit.unit_data.id, " Tier: ", target_unit.unit_data.tier)
					# Same tier - show merge/swap popup
					show_merge_swap_popup(selected_unit, target_unit, clicked_slot)
				else:
					print("Merge condition not met - tiers don't match or max tier reached")
					# Different tiers or max tier - just swap
					_attempt_swap_units(selected_unit, selected_slot, target_unit, clicked_slot)
					_deselect_current_unit()
	
	# Case 2: No unit selected yet, select the unit in the clicked slot if there is one
	elif clicked_slot.occupying_unit and clicked_slot.is_player_slot:
		selected_unit = clicked_slot.occupying_unit
		selected_slot = clicked_slot
		selected_slot.set_highlight("selected")
		_update_merge_highlights(selected_unit)
	
	# Case 3: Clicked empty slot with no selection - deselect
	else:
		_deselect_current_unit()


func _show_merge_confirmation(unit1: Unit, unit2: Unit, target_slot: UnitSlot, result_unit_id: String) -> void:
	print("Showing merge confirmation for units: ", unit1.unit_data.id, " and ", unit2.unit_data.id, " -> ", result_unit_id)
	
	var result_data = UnitLibrary.get_unit_data(result_unit_id)
	if not result_data:
		push_error("No result data found for unit ID: " + result_unit_id)
		add_log_message("Error: Could not find data for merged unit type")
		_deselect_current_unit()
		return

	# Set merge state
	pending_merge_slot = target_slot
	is_awaiting_merge_confirmation = true

	# Debug log the merge details
	print("Merge details:")
	print("- Unit 1: ", unit1.unit_data.id, " (HP: ", unit1.current_hp, ")")
	print("- Unit 2: ", unit2.unit_data.id, " (HP: ", unit2.current_hp, ")")
	print("- Result: ", result_unit_id)
	print("- Target slot: ", target_slot.slot_id if target_slot else "None")
	
	# Small delay to allow any UI animations to complete
	await get_tree().create_timer(0.1).timeout
	
	# Perform the merge
	_perform_merge(unit1, unit2, target_slot, result_unit_id, result_data)
	
	# Reset the merge state
	is_awaiting_merge_confirmation = false
	pending_merge_slot = null

func _perform_merge(unit1: Unit, unit2: Unit, target_slot: UnitSlot, result_unit_id: String, result_data: UnitData) -> void:
	print("Performing merge between ", unit1.unit_data.id, " and ", unit2.unit_data.id, " -> ", result_unit_id)
	
	if not is_instance_valid(unit1) or not is_instance_valid(unit2) or not is_instance_valid(target_slot):
		push_error("Invalid unit or slot in merge")
		_clear_selection()
		return

	if not result_data:
		push_error("No result data provided for merge")
		_clear_selection()
		return

	# Find the slots for both units
	var slot1 = _get_slot_for_unit(unit1)
	var slot2 = _get_slot_for_unit(unit2)
	
	if not is_instance_valid(slot1) or not is_instance_valid(slot2):
		push_error("Could not find slots for one or both units")
		_clear_selection()
		return

	# Calculate combined stats
	var combined_hp = unit1.current_hp + unit2.current_hp
	var combined_pwr = unit1.unit_data.pwr + unit2.unit_data.pwr
	combined_pwr = int(combined_pwr * 1.1)

	# Create merged unit data
	var merged_data = result_data.duplicate()
	merged_data.max_hp = combined_hp
	merged_data.pwr = combined_pwr

	# Clear the slots first but keep references to the units
	var removed_unit1 = slot1.clear_unit()
	var removed_unit2 = slot2.clear_unit()

	# Spawn the new unit in the target slot with the combined HP
	var slot_index = player_lineup_slots.find(target_slot)
	if slot_index == -1:
		push_error("Target slot not found in player_lineup_slots")
		_clear_selection()
		return

	# Make sure the target slot is empty
	if not target_slot.is_empty():
		push_error("Target slot is not empty")
		_clear_selection()
		return

	# Spawn the new unit with the combined HP
	var new_unit = _spawn_unit(merged_data, true, slot_index, combined_hp)
	if new_unit:
		print("Successfully spawned merged unit:", new_unit.unit_data.id, " with HP:", new_unit.current_hp)
		
		# Update unit tracking arrays
		if removed_unit1 in player_units:
			player_units.erase(removed_unit1)
		if removed_unit2 in player_units:
			player_units.erase(removed_unit2)
		player_units.append(new_unit)

		# Update lineup units if needed
		if player_lineup_units.has(removed_unit1):
			player_lineup_units[player_lineup_units.find(removed_unit1)] = new_unit
		if player_lineup_units.has(removed_unit2):
			player_lineup_units[player_lineup_units.find(removed_unit2)] = new_unit

		# Emit merged signal
		EventBus.units_merged.emit(unit1, unit2, new_unit)
		
		# Clean up old units safely
		if is_instance_valid(removed_unit1):
			if removed_unit1.is_inside_tree():
				removed_unit1.get_parent().remove_child(removed_unit1)
			removed_unit1.queue_free()
			
		if is_instance_valid(removed_unit2) and removed_unit2 != removed_unit1:
			if removed_unit2.is_inside_tree():
				removed_unit2.get_parent().remove_child(removed_unit2)
			removed_unit2.queue_free()

		add_log_message("Merged " + unit1.unit_data.display_name + " and " + unit2.unit_data.display_name + " into a stronger " + new_unit.unit_data.display_name + "!")
		
		# Force update the display
		if new_unit.has_method("_update_display"):
			new_unit._update_display()
		
	else:
		push_error("Failed to spawn merged unit")
		# Try to restore the original units if possible
		if is_instance_valid(removed_unit1) and is_instance_valid(slot1) and slot1.is_empty():
			slot1.assign_unit(removed_unit1)
		if is_instance_valid(removed_unit2) and is_instance_valid(slot2) and slot2.is_empty():
			slot2.assign_unit(removed_unit2)
	
	_clear_selection()

func _update_merge_highlights(unit_to_highlight: Unit) -> void:
	if not unit_to_highlight:
		return

	for slot in player_lineup_slots:
		if slot == selected_slot:
			slot.set_highlight("selected")
		elif slot.occupying_unit:
			var result = UnitLibrary.get_merge_result_for_units(selected_unit.unit_data, slot.occupying_unit.unit_data)
			slot.set_highlight("merge" if result else "invalid")
		else:
			slot.set_highlight("")

func _clear_selection() -> void:
	# Clear highlights from selected unit
	if selected_unit and is_instance_valid(selected_unit):
		if selected_unit.has_method("set_selected"):
			selected_unit.set_selected(false)
		elif selected_unit.has_method("update_selection_visual"):
			selected_unit.update_selection_visual(false)

	# Clear highlights from selected slot
	if selected_slot and is_instance_valid(selected_slot):
		if selected_slot.has_method("set_highlight"):
			selected_slot.set_highlight("")

	# Clear all references
	var was_selected = selected_unit != null
	selected_unit = null
	selected_slot = null
	is_awaiting_merge_confirmation = false
	pending_merge_slot = null
	
	# Clear any merge highlights from all slots
	for slot in player_lineup_slots:
		if slot and is_instance_valid(slot) and slot.has_method("set_highlight"):
			slot.set_highlight("")

	# Update UI if we had a selection
	if was_selected:
		add_log_message("Selection cleared")

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
		if unit_ref: # If we got something unexpected, try to put it back
			from_slot.assign_unit(unit_ref)
		return false

	# 4. Update Slot References (UnitSlot handles visual parenting)
	to_slot.assign_unit(unit_to_move)

	# 5. Update logical arrays if these are player units
	if unit_to_move.is_player_team_unit:  # Both slots are on the player team
		print("\n=== DEBUG: Updating player unit arrays ===")
		print("Unit to move: ", unit_to_move, " (type: ", typeof(unit_to_move), ")")
		
		# Find the indices of the slots in their respective arrays
		var from_idx = player_lineup_slots.find(from_slot)
		var to_idx = player_lineup_slots.find(to_slot)
		print("From idx: ", from_idx, " | To idx: ", to_idx)

		if from_idx != -1 and to_idx != -1:
			print("Both slots in lineup - swapping positions")
			# Both slots are in the lineup, just swap in the lineup array
			print("Before - player_lineup_units[", to_idx, "]: ", player_lineup_units[to_idx])
			player_lineup_units[to_idx] = unit_to_move
			print("After - player_lineup_units[", to_idx, "]: ", player_lineup_units[to_idx])
			
			print("Before - player_lineup_units[", from_idx, "]: ", player_lineup_units[from_idx])
			player_lineup_units[from_idx] = null
			print("After - player_lineup_units[", from_idx, "]: ", player_lineup_units[from_idx])
			
			# Update the main player_units array to maintain consistency
			var unit_idx = player_units.find(unit_to_move)
			print("Updating player_units[", unit_idx, "]")
			if unit_idx != -1:
				player_units[unit_idx] = unit_to_move  # Keep the same reference, just update position
			
		elif from_idx != -1:
			print("Moving from lineup to bench")
			# Moving from lineup to bench
			player_lineup_units[from_idx] = null
			
			# No need to update player_units as the unit is already there
			# Just ensure it's not null in the array
			var unit_idx = player_units.find(unit_to_move)
			print("Unit idx in player_units: ", unit_idx)
			if unit_idx == -1:  # Shouldn't happen, but just in case
				print("Adding unit to player_units")
				player_units.append(unit_to_move)
			
		elif to_idx != -1:
			print("Moving from bench to lineup")
			# Moving from bench to lineup
			print("Before - player_lineup_units[", to_idx, "]: ", player_lineup_units[to_idx])
			player_lineup_units[to_idx] = unit_to_move
			print("After - player_lineup_units[", to_idx, "]: ", player_lineup_units[to_idx])
			
			# Ensure the unit is in player_units
			var unit_idx = player_units.find(unit_to_move)
			print("Unit idx in player_units: ", unit_idx)
			if unit_idx == -1:  # Shouldn't happen, but just in case
				print("Adding unit to player_units")
				player_units.append(unit_to_move)
		
		print("=== END DEBUG ===\n")

	# 6. Log and Return Success
	add_log_message("Moved %s from %s to %s" % [unit_to_move.get_name_for_log(), from_slot.slot_id, to_slot.slot_id])
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
		if is_instance_valid(temp_unit1): 
			from_slot1.assign_unit(temp_unit1)
		if is_instance_valid(temp_unit2): 
			from_slot2.assign_unit(temp_unit2)
		return false
	
	from_slot1.assign_unit(unit2)
	from_slot2.assign_unit(unit1)
	
	# 5. Update logical arrays if these are player units
	if unit1.is_player_team_unit:  # Both units are on the same team, so just check one
		var slot1_idx = player_lineup_slots.find(from_slot1)
		var slot2_idx = player_lineup_slots.find(from_slot2)
		
		# Update the lineup units array if both slots are in the lineup
		if slot1_idx != -1 and slot2_idx != -1:
			player_lineup_units[slot1_idx] = unit2
			player_lineup_units[slot2_idx] = unit1
		# Handle case where one unit is in lineup and one is on bench
		elif slot1_idx != -1:
			player_lineup_units[slot1_idx] = unit2
			# Ensure unit2 is in player_units
			if player_units.find(unit2) == -1:
				player_units.append(unit2)
		elif slot2_idx != -1:
			player_lineup_units[slot2_idx] = unit1
			# Ensure unit1 is in player_units
			if player_units.find(unit1) == -1:
				player_units.append(unit1)
		
		# Update the main player_units array to maintain consistency
		var unit1_idx = player_units.find(unit1)
		var unit2_idx = player_units.find(unit2)
		
		# If both units are found in player_units, swap them
		if unit1_idx != -1 and unit2_idx != -1:
			var temp = player_units[unit1_idx]
			player_units[unit1_idx] = player_units[unit2_idx]
			player_units[unit2_idx] = temp

	add_log_message("Swapped %s and %s" % [unit1.get_name_for_log(), unit2.get_name_for_log()])
	return true


# --- Signal Handlers ---
func _on_unit_inspection_requested(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
	show_unit_inspection(unit)

func _on_slot_clicked_for_action(slot: UnitSlot) -> void:
	if not is_instance_valid(slot):
		return
	_on_slot_selected(slot)

# --- Existing EventBus Handlers (Modified) ---
func _on_unit_health_changed(unit: Object, new_health: int, old_health: int, max_health: int) -> void:
	# Update health display if needed
	print("Unit health changed: ", unit.unit_data.id if unit.unit_data else "Unknown", " from ", old_health, " to ", new_health)

func _on_turn_ended(turn_owner: String) -> void:
	print("Turn ended for: ", turn_owner)
	# Handle turn end logic here
	if turn_owner == "player":
		# Start enemy turn
		is_player_turn = false
		# Add any enemy turn logic here
	else:
		# Start player turn
		is_player_turn = true
		# Add any player turn start logic here

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
	if selected_unit == unit_died:
		_clear_selection()

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
