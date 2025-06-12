extends Node

func _ready():
    # Create placeholder textures directory if it doesn't exist
    var dir = DirAccess.open("res://assets")
    if not dir:
        DirAccess.make_dir_absolute("res://assets")
    
    # Create unit placeholder
    var unit_tex = create_placeholder_texture(Color.ROYAL_BLUE, Vector2(64, 64))
    unit_tex.save_png("res://assets/placeholder_unit.png")
    
    # Create item placeholder
    var item_tex = create_placeholder_texture(Color.CRIMSON, Vector2(48, 48))
    item_tex.save_png("res://assets/placeholder_item.png")
    
    print("Placeholder textures created successfully!")
    get_tree().quit()

func create_placeholder_texture(color: Color, size: Vector2) -> ImageTexture:
    var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    image.fill(color)
    
    # Add a border
    var border_color = color.lightened(0.5) if color.v < 0.5 else color.darkened(0.5)
    image.lock()
    for x in size.x:
        image.set_pixel(x, 0, border_color)
        image.set_pixel(x, size.y - 1, border_color)
    for y in size.y:
        image.set_pixel(0, y, border_color)
        image.set_pixel(size.x - 1, y, border_color)
    image.unlock()
    
    var texture = ImageTexture.create_from_image(image)
    return texture
