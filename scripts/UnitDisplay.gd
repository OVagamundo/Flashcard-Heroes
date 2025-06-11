extends PanelContainer

var _instance: GachaBallInstance

@onready var icon_rect = $VBoxContainer/Icon
@onready var hp_label = $VBoxContainer/HPLabel
@onready var pwr_label = $VBoxContainer/PwrLabel

func display_instance(inst: GachaBallInstance) -> void:
    _instance = inst
    var definition = Database.get_gachaball_definition(inst.definition_id)

    if not definition:
        print("Error: Could not find definition for instance: " + inst.definition_id)
        return

    icon_rect.texture = definition.icon_texture
    update_stats()

    # Connect to instance signals if it has any, for dynamic updates.
    # For now, stats are updated manually by BattleManager if needed.

func update_stats() -> void:
    if not is_instance_valid(_instance):
        return
    hp_label.text = "HP: %d" % _instance.current_hp
    pwr_label.text = "PWR: %d" % _instance.current_pwr

func get_instance() -> GachaBallInstance:
    return _instance
