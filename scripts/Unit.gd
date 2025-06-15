extends TextureRect
class_name Unit

# Reference to the GachaBallInstance this unit represents
var _gacha_instance = null

# Initialize the unit with a GachaBallInstance
func initialize(gacha_instance) -> void:
    if not gacha_instance:
        push_error("Unit.initialize() called with null gacha_instance")
        return
        
    _gacha_instance = gacha_instance
    _update_display()

# Update the UI elements based on the current GachaBallInstance state
func _update_display() -> void:
    if not _gacha_instance or not _gacha_instance.definition:
        push_error("Unit._update_display(): Invalid or missing GachaBallInstance")
        return
    
    # Set the sprite texture if available
    if _gacha_instance.definition.icon_texture:
        self.texture = _gacha_instance.definition.icon_texture
    else:
        push_warning("No icon_texture set for unit: ", _gacha_instance.definition.id)
