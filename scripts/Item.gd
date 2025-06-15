extends Control
class_name Item

# Reference to the GachaBallInstance this item represents
var _gacha_instance = null

# UI References
@onready var _name_label: Label = $Panel/Label
@onready var _description_label: Label = $Panel/Description
@onready var _sprite: Sprite2D = $Panel/Sprite2D

# Initialize the item with a GachaBallInstance
func initialize(gacha_instance) -> void:
    _gacha_instance = gacha_instance
    _update_display()

# Update the UI elements based on the current GachaBallInstance state
func _update_display() -> void:
    if not _gacha_instance:
        return
        
    _name_label.text = _gacha_instance.definition.display_name
    _description_label.text = _gacha_instance.definition.description
    
    # TODO: Update sprite when we have the actual sprites
    # _sprite.texture = load(_gacha_instance.definition.sprite_path)
