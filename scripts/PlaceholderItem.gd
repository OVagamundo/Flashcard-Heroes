extends PanelContainer

@onready var item_sprite: TextureRect = $ItemSprite

func display_instance(instance_data: Resource):
	# Assuming instance_data is a GachaBallDefinition or similar
	# and has a 'texture' property or a way to get the icon.
	# For now, let's assume it has an 'icon' property that is a Texture2D.
	# If it's a GachaBallDefinition, it might have an associated unit sprite.
	
	# This is a placeholder for actual data display logic.
	# You'll need to adapt this based on the actual structure of your GachaBallDefinition/Instance.
	
	if instance_data and instance_data.has("icon_texture"):
		item_sprite.texture = instance_data.icon_texture
	else:
		# Fallback to a default or clear the texture if no icon is found
		item_sprite.texture = null
