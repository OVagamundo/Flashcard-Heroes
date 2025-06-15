extends Control
class_name Unit

# Reference to the GachaBallInstance this unit represents
var _gacha_instance = null

# UI References
@onready var _name_label: Label = $Panel/Label
@onready var _hp_label: Label = $Panel/HP
@onready var _sprite: Sprite2D = $Panel/Sprite2D

# Initialize the unit with a GachaBallInstance
func initialize(gacha_instance) -> void:
    _gacha_instance = gacha_instance
    _update_display()

# Update the UI elements based on the current GachaBallInstance state
func _update_display() -> void:
    if not _gacha_instance:
        return
        
    _name_label.text = _gacha_instance.definition.display_name
    _hp_label.text = "HP: %d/%d" % [_gacha_instance.current_hp, _gacha_instance.definition.max_hp]
    
    # TODO: Update sprite when we have the actual sprites
    # _sprite.texture = load(_gacha_instance.definition.sprite_path)
