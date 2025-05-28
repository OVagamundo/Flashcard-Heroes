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
# const UNIT_SCENE = preload("res://scenes/Unit.tscn") # Will be used later

# Will hold references to the slot containers
var player_slot_nodes: Array[Node] = []
var enemy_slot_nodes: Array[Node] = []
var is_player_turn: bool = true

# TEST_UNITS constant and related logic removed for this step

func _ready() -> void:
	# Connect button signals (can be kept, but their actions will be simplified)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	gacha_button.pressed.connect(_on_gacha_pressed)
	
	# EventBus connections (can be kept, but signals won't be emitted by battle logic for now)
	# EventBus.unit_spawned.connect(_on_unit_spawned)
	# EventBus.unit_damaged.connect(_on_unit_damaged)
	# EventBus.unit_died.connect(_on_unit_died)
	# EventBus.battle_ended.connect(_on_battle_ended)
	
	# Initialize battle visuals
	setup_battle_scene()

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
		for child_node in container.get_children():
			child_node.queue_free()
	player_slot_nodes.clear()
	enemy_slot_nodes.clear()

func setup_visual_slots() -> void:
	# Clear any existing references
	player_slot_nodes.clear()
	enemy_slot_nodes.clear()
	
	# Get all slot containers (they should be pre-made in the scene)
	for i in range(1, MAX_UNITS_PER_SIDE + 1):
		# Player slots
		var player_slot = player_units_container.get_node_or_null("PlayerSlot" + str(i))
		if player_slot:
			player_slot_nodes.append(player_slot)
			
		# Enemy slots
		var enemy_slot = enemy_units_container.get_node_or_null("EnemySlot" + str(i))
		if enemy_slot:
			enemy_slot_nodes.append(enemy_slot)
	
	# Log the setup
	add_log_message("Visual slots set up. Found %d player slots and %d enemy slots" % 
		[player_slot_nodes.size(), enemy_slot_nodes.size()])

# Temporarily simplify button actions
func _on_end_turn_pressed() -> void:
	is_player_turn = not is_player_turn
	update_turn_indicator()
	add_log_message("Turn ended. Current turn: %s" % ["Player" if is_player_turn else "Enemy"])

func _on_gacha_pressed() -> void:
	add_log_message("Gacha button pressed. (Functionality pending unit implementation)")

# Comment out unit-specific logic for now
# func spawn_unit(unit_data: UnitResource, is_player_team: bool) -> Unit:
# 	 return null

# func _on_unit_clicked(unit: Unit) -> void:
# 	 pass

# func _on_unit_hovered(unit: Unit, is_hovered: bool) -> void:
# 	 pass

# func select_unit(unit: Unit) -> void:
# 	 pass

# func deselect_unit() -> void:
# 	 pass

func update_turn_indicator() -> void:
	if is_player_turn:
		turn_indicator.text = "Player Lineup Setup"
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) # Green
	else:
		turn_indicator.text = "Enemy Lineup Setup" # Or just keep it simple
		turn_indicator.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2)) # Red

func add_log_message(message: String) -> void:
	var timestamp = "[%s] " % Time.get_time_string_from_system(false, true)
	if battle_log.text.is_empty():
		battle_log.text = timestamp + message
	else:
		battle_log.text += "\n" + timestamp + message
	battle_log.scroll_vertical = INF

# Event Handlers (kept for structure, but mostly inactive for now)
# func _on_unit_spawned(unit_node: Node2D) -> void:
# 	 add_log_message("Event: Unit spawned - %s (Placeholder)" % unit_node.name)

# func _on_unit_damaged(unit_node: Node2D, amount: int) -> void:
# 	 add_log_message("Event: Unit damaged - %s, Amount: %d (Placeholder)" % [unit_node.name, amount])

# func _on_unit_died(unit_node: Node2D) -> void:
# 	 add_log_message("Event: Unit died - %s (Placeholder)" % unit_node.name)

# func _on_battle_ended(victory: bool) -> void:
# 	 add_log_message("Event: Battle ended. Victory: %s (Placeholder)" % victory)
# 	 # Potentially disable buttons here too
# 	 end_turn_button.disabled = true
# 	 gacha_button.disabled = true
