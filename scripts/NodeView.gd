extends Button

signal node_selected(node_def)

var _node_def

func populate(node_def):
	_node_def = node_def
	text = node_def.display_name_key
	# Allow BATTLE, SHOP, and REST nodes to be enabled.
	disabled = not (node_def.node_type in ["BATTLE", "SHOP", "REST"])

func _on_pressed():
	emit_signal("node_selected", _node_def)

func _ready():
	self.pressed.connect(_on_pressed) 