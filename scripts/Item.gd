extends TextureRect
class_name Item

# Reference to the GachaBallInstance this item represents
var _gacha_instance = null

# Initialize the item with a GachaBallInstance
func initialize(gacha_instance) -> void:
    if not gacha_instance:
        push_error("Item.initialize() called with null gacha_instance")
        return
        
    _gacha_instance = gacha_instance
    _update_display()

# Update the UI elements based on the current GachaBallInstance state
func _update_display() -> void:
    if not _gacha_instance or not _gacha_instance.definition:
        push_error("Item._update_display(): Invalid or missing GachaBallInstance")
        return
    
    # Set the sprite texture to the placeholder circle
    self.texture = preload("res://assets/placeholders/item_circle.tres")

    # Modulate the color based on tier
    match _gacha_instance.definition.tier:
        1:
            self.modulate = Color.GREEN
        2:
            self.modulate = Color.BLUE
        3:
            self.modulate = Color.PURPLE
        _: # Default case
            self.modulate = Color.WHITE
