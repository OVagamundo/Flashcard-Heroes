<!-- Original: Item.gd -->

```gdscript
extends Control
class_name Item

# Reference to the GachaBallInstance this item represents
var _gacha_instance = null

# UI References
@onready var _name_label: Label = $Panel/Name
@onready var _description_label: Label = $Panel/Description
@onready var _sprite: Sprite2D = $Panel/Sprite2D

# Initialize the item with a GachaBallInstance
func initialize(gacha_instance) -> void:
    if not gacha_instance:
        push_error("Item.initialize() called with null gacha_instance")
        return
        
    _gacha_instance = gacha_instance
    
    # Make sure we have all the necessary UI elements
    if not _name_label or not _description_label or not _sprite:
        push_error("Missing UI elements in Item scene")
        return
    
    _update_display()

# Update the UI elements based on the current GachaBallInstance state
func _update_display() -> void:
    if not _gacha_instance or not _gacha_instance.definition:
        push_error("Item._update_display(): Invalid or missing GachaBallInstance")
        return
    
    _name_label.text = _gacha_instance.get_display_name()
    _description_label.text = _gacha_instance.definition.description_key
    
    # Set the sprite texture if available
    if _gacha_instance.definition.icon_texture:
        _sprite.texture = _gacha_instance.definition.icon_texture
    else:
        push_warning("No icon_texture set for item: ", _gacha_instance.definition.id)

```