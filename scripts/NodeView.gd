extends Button

signal node_selected(node_def)

var _node_def

func populate(node_def) -> void:
	_node_def = node_def
	# Use translation for the display name
	if node_def.boss_level > 0:
		# Boss node: format with boss level
		text = tr(node_def.display_name_key) % node_def.boss_level
	else:
		# Normal node: just translate the key
		text = tr(node_def.display_name_key)
	# Allow BATTLE, SHOP, and REST nodes to be enabled.
	disabled = not (node_def.node_type in ["BATTLE", "SHOP", "REST"])

func _on_pressed() -> void:
	emit_signal("node_selected", _node_def)

func _ready() -> void:
	self.pressed.connect(_on_pressed)