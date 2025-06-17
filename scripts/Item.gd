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
    
    # Set the sprite texture if available
    if _gacha_instance.definition.icon_texture:
        self.texture = _gacha_instance.definition.icon_texture
        self.visible = true
    else:
        # Fallback to tier-based textures if icon_texture is not set
        var texture_path: String
        match _gacha_instance.definition.tier:
            1:
                texture_path = "res://assets/images/ItemSprites/Tier1Item.png"
            2:
                texture_path = "res://assets/images/ItemSprites/Tier2Item.png"
            3:
                texture_path = "res://assets/images/ItemSprites/Tier3Item.png"
            _: # Default case
                texture_path = "res://assets/placeholders/item_circle.tres"
        
        var texture = load(texture_path)
        if texture:
            self.texture = texture
            self.visible = true
        else:
            push_error("Failed to load fallback texture: ", texture_path)
            self.visible = false
