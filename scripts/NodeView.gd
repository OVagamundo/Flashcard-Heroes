extends TextureButton
class_name NodeView

signal node_selected(node_def)

@onready var label: Label = $Label

var _node_def

# Texture paths
const CARD_TEXTURES = {
	"BATTLE": "res://assets/ui/textures/BattlePath.png",
	"SHOP": "res://assets/ui/textures/ShopCard.png",
	"REST": "res://assets/ui/textures/RestPath.png",
	"BOSS": "res://assets/ui/textures/BossPath.png",
	"ELITE": "res://assets/ui/textures/EliteBattlePath.png"
}

func populate(node_def) -> void:
	if not label:
		label = $Label
		
	_node_def = node_def
	# Use translation for the display name
	if node_def.boss_level > 0:
		# Boss node: format with boss level
		label.text = tr(node_def.display_name_key) % node_def.boss_level
	else:
		# Normal node: just translate the key
		label.text = tr(node_def.display_name_key)
	
	# Set placeholder color based on node type
	var bg_color = Color(0.2, 0.2, 0.2) # Default grey
	var type = node_def.node_type
	if type == "BATTLE":
		if node_def.subtype == "BOSS":
			bg_color = Color(0.4, 0.1, 0.4) # Boss Purple
		elif node_def.subtype == "ELITE":
			bg_color = Color(0.5, 0.2, 0.3) # Elite Dark Red/Purple
		else:
			bg_color = Color(0.6, 0.2, 0.2) # Battle Red
	elif type == "SHOP":
		bg_color = Color(0.5, 0.4, 0.2) # Shop Brown/Gold
	elif type == "REST":
		bg_color = Color(0.2, 0.3, 0.6) # Rest Blue
	
	var bg_rect = get_node_or_null("BackgroundColor")
	if bg_rect:
		bg_rect.color = bg_color
		bg_rect.visible = true

	# Load texture based on node type
	var tex_path = ""
	if node_def.node_type == "BATTLE":
		if node_def.subtype == "BOSS":
			tex_path = CARD_TEXTURES["BOSS"]
		elif node_def.subtype == "ELITE":
			tex_path = CARD_TEXTURES["ELITE"]
		else:
			tex_path = CARD_TEXTURES["BATTLE"]
	elif CARD_TEXTURES.has(node_def.node_type):
		tex_path = CARD_TEXTURES[node_def.node_type]

	if not tex_path.is_empty():
		var tex = load(tex_path)
		if tex:
			texture_normal = tex
			# Ensure it expands
			ignore_texture_size = true
			stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			# Hide dynamic label as text is baked into the texture
			label.visible = false
			# Hide placeholder background if we have a texture
			if bg_rect:
				bg_rect.visible = false
		else:
			# If texture path defined but loading failed, ensure label is visible
			label.visible = true
	else:
		# No texture path, ensure label is visible
		label.visible = true
	
	# Allow BATTLE, SHOP, and REST nodes to be enabled.
	disabled = not (node_def.node_type in ["BATTLE", "SHOP", "REST"])

func _on_pressed() -> void:
	emit_signal("node_selected", _node_def)

func _ready() -> void:
	self.pressed.connect(_on_pressed)
