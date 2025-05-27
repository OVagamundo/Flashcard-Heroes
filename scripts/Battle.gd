extends Control

@onready var player_units_container: GridContainer = $MainContainer/BattleArea/PlayerSide/PlayerUnits
@onready var enemy_units_container: GridContainer = $MainContainer/BattleArea/EnemySide/EnemyUnits
@onready var battle_log: TextEdit = $MainContainer/BattleLog
@onready var end_turn_button: Button = $MainContainer/Actions/EndTurnButton
@onready var gacha_button: Button = $MainContainer/Actions/GachaButton
@onready var player_health_label: Label = $MainContainer/Header/PlayerInfo/PlayerHealth
@onready var gacha_tokens_label: Label = $MainContainer/Header/PlayerInfo/GachaTokens
@onready var turn_indicator: Label = $MainContainer/Header/TurnIndicator

var player_units: Array = []
var enemy_units: Array = []
var is_player_turn: bool = true

func _ready() -> void:
	# Connect signals
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	gacha_button.pressed.connect(_on_gacha_pressed)
	
	# Connect to EventBus signals
	EventBus.unit_spawned.connect(_on_unit_spawned)
	EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.battle_ended.connect(_on_battle_ended)
	
	# Initialize battle
	start_battle()

func start_battle() -> void:
	# Clear any existing units
	clear_units()
	
	# Reset turn state
	is_player_turn = true
	update_turn_indicator()
	
	# Enable/disable buttons
	end_turn_button.disabled = false
	gacha_button.disabled = true
	
	# Add initial units (placeholders for now)
	# TODO: Replace with actual unit spawning logic
	add_log_message("Battle started!")

func clear_units() -> void:
	# Clear player units
	for child in player_units_container.get_children():
		child.queue_free()
	player_units.clear()
	
	# Clear enemy units
	for child in enemy_units_container.get_children():
		child.queue_free()
	enemy_units.clear()

func update_turn_indicator() -> void:
	if is_player_turn:
		turn_indicator.text = "Your Turn"
		turn_indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green
	else:
		turn_indicator.text = "Enemy Turn"
		turn_indicator.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))  # Red

func add_log_message(message: String) -> void:
	var timestamp = "[%s] " % Time.get_time_string_from_system()
	if battle_log.text.is_empty():
		battle_log.text = timestamp + message
	else:
		battle_log.text += "\n" + timestamp + message
	battle_log.scroll_vertical = INF  # Auto-scroll to bottom

# Button Handlers
func _on_end_turn_pressed() -> void:
	if not is_player_turn:
		return
	
	add_log_message("Ending player turn...")
	is_player_turn = false
	update_turn_indicator()
	
	# Disable buttons during enemy turn
	end_turn_button.disabled = true
	gacha_button.disabled = true
	
	# Process enemy turn
	await get_tree().create_timer(1.0).timeout  # Simulate enemy thinking
	enemy_turn()

func _on_gacha_pressed() -> void:
	# TODO: Implement gacha logic
	add_log_message("Pulling from gacha...")
	# For now, just add a token and update the button
	EventBus.gacha_result_received.emit(["placeholder_unit"])

# Battle Logic
func enemy_turn() -> void:
	add_log_message("Enemy's turn!")
	
	# Simple AI: Attack with each enemy unit
	for enemy in enemy_units:
		if player_units.size() > 0:
			var target = player_units[0]  # Simple target selection
			# TODO: Implement actual attack logic
			add_log_message("Enemy attacks!")
			await get_tree().create_timer(0.5).timeout
	
	# End enemy turn
	is_player_turn = true
	update_turn_indicator()
	end_turn_button.disabled = false
	gacha_button.disabled = false
	add_log_message("Your turn!")

# Event Handlers
func _on_unit_spawned(unit: Node2D) -> void:
	add_log_message("Unit spawned: %s" % unit.name)

func _on_unit_damaged(unit: Node2D, amount: int) -> void:
	add_log_message("%s took %d damage!" % [unit.name, amount])

func _on_unit_died(unit: Node2D) -> void:
	add_log_message("%s was defeated!" % unit.name)

func _on_battle_ended(victory: bool) -> void:
	if victory:
		add_log_message("Victory!")
	else:
		add_log_message("Defeat!")
	
	# Disable controls
	end_turn_button.disabled = true
	gacha_button.disabled = true
	
	# Return to path choice after a delay
	await get_tree().create_timer(3.0).timeout
	GameManager.change_scene("path_choice")
