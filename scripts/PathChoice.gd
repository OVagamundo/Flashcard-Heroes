extends Control

@export var encounter_definition: EnemyEncounterDefinition

func _ready() -> void:
    var battle_node_button = $HBoxContainer/BattleNodeButton
    if battle_node_button:
        battle_node_button.pressed.connect(_on_battle_node_button_pressed)
    else:
        print("Error: BattleNodeButton not found in PathChoice scene.")

func _on_battle_node_button_pressed() -> void:
    if encounter_definition:
        EventBus.battle_start_requested.emit(encounter_definition)
    else:
        print("Error: No encounter definition set for this path choice.")
